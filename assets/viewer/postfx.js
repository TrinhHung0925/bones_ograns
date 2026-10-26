// Rendering pipeline: image-based lighting, ACES tone mapping, progressive
// ambient occlusion and a soft contact shadow under the body.
//
// AO strategy: while anything moves (orbit, tweens, game animations) frames go
// straight to the canvas with no post-processing. Once the view has been still
// for IDLE_MS, one frame runs GTAO (half resolution, denoised) through an
// EffectComposer, and a few cheap follow-up frames fade the cached AO in. The
// next movement drops back to direct rendering, so interaction never pays for
// AO. Quality 'low' (or a GPU without float render targets) skips all of it.

import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { GTAOPass } from 'three/addons/postprocessing/GTAOPass.js';
import { Pass, FullScreenQuad } from 'three/addons/postprocessing/Pass.js';

const IDLE_MS = 140;
const AO_SCALE = 0.5;
const AO_FADE = [0.35, 0.6, 0.82, 1];

/** AO multiply + tone mapping + sRGB, un-premultiplying the linear buffer. */
class FinalPass extends Pass {
  constructor(aoTexture) {
    super();
    this.uniforms = {
      tDiffuse: { value: null },
      tAO: { value: aoTexture },
      uAO: { value: 0 },
      toneMappingExposure: { value: 1 },
    };
    this.material = new THREE.RawShaderMaterial({
      uniforms: this.uniforms,
      defines: { ACES_FILMIC_TONE_MAPPING: '' },
      vertexShader: /* glsl */`
        precision highp float;
        uniform mat4 modelViewMatrix;
        uniform mat4 projectionMatrix;
        attribute vec3 position;
        attribute vec2 uv;
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }`,
      fragmentShader: /* glsl */`
        precision highp float;
        uniform sampler2D tDiffuse;
        uniform sampler2D tAO;
        uniform float uAO;
        #include <tonemapping_pars_fragment>
        #include <colorspace_pars_fragment>
        varying vec2 vUv;
        void main() {
          vec4 c = texture2D(tDiffuse, vUv);
          float a = clamp(c.a, 0.0, 1.0);
          vec3 col = a > 0.0001 ? c.rgb / a : vec3(0.0);
          float ao = texture2D(tAO, vUv).r;
          col *= mix(1.0, ao, uAO);
          col = ACESFilmicToneMapping(col);
          col = sRGBTransferOETF(vec4(col, 1.0)).rgb;
          gl_FragColor = vec4(col * a, a);
        }`,
      depthTest: false,
      depthWrite: false,
      blending: THREE.NoBlending,
    });
    this.quad = new FullScreenQuad(this.material);
  }

  render(renderer, writeBuffer, readBuffer) {
    this.uniforms.tDiffuse.value = readBuffer.texture;
    this.uniforms.toneMappingExposure.value = renderer.toneMappingExposure;
    renderer.setRenderTarget(this.renderToScreen ? null : writeBuffer);
    this.quad.render(renderer);
  }
}

export class Pipeline {
  constructor(renderer, scene, camera) {
    this.renderer = renderer;
    this.scene = scene;
    this.camera = camera;
    this.quality = 'high';
    this.composer = null;
    this.aoStep = -1;      // index into AO_FADE while fading in, -1 = idle/off
    this.lastActive = 0;
    this.aoSupported = renderer.capabilities.isWebGL2 &&
      (renderer.extensions.has('EXT_color_buffer_float') || renderer.extensions.has('EXT_color_buffer_half_float'));

    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.8;
    renderer.outputColorSpace = THREE.SRGBColorSpace;

    const pmrem = new THREE.PMREMGenerator(renderer);
    const room = new RoomEnvironment();
    scene.environment = pmrem.fromScene(room, 0.04).texture;
    scene.environmentIntensity = 0.35;
    room.dispose?.();
    pmrem.dispose();

    // Key light rides with the camera; a cool violet back light rims the
    // silhouette so parts separate from the dark background.
    this.key = new THREE.DirectionalLight(0xfff4e8, 1.9);
    this.key.position.set(-0.8, 0.6, 0.5);
    camera.add(this.key);
    this.rim = new THREE.DirectionalLight(0xb7a6ff, 1.6);
    this.rim.position.set(0.5, 0.35, -1);
    camera.add(this.rim);
    scene.add(new THREE.HemisphereLight(0xdfe4ff, 0x2a2140, 0.35));

    this.shadow = new ContactShadow(renderer, scene);
  }

  setQuality(level) {
    this.quality = level === 'low' ? 'low' : 'high';
    this.aoStep = -1;
    if (this.quality === 'low' && this.composer) {
      this.composer.dispose();
      this.gtao.dispose();
      this.composer = null;
    }
    this.shadow.setResolution(this.quality === 'low' ? 256 : 512);
  }

  get aoEnabled() {
    return this.quality === 'high' && this.aoSupported;
  }

  ensureComposer() {
    if (this.composer) return;
    const { renderer, scene, camera } = this;
    const size = renderer.getDrawingBufferSize(new THREE.Vector2());
    const target = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: 4 });
    const composer = new EffectComposer(renderer, target);
    composer.addPass(new RenderPass(scene, camera));
    const gtao = new GTAOPass(scene, camera, Math.ceil(size.x * AO_SCALE), Math.ceil(size.y * AO_SCALE));
    gtao.output = GTAOPass.OUTPUT.Off;
    gtao.needsSwap = false;
    gtao.updateGtaoMaterial({ radius: 0.085, distanceExponent: 1.4, thickness: 0.18, scale: 2.0, samples: 12 });
    gtao.updatePdMaterial({ radius: 8, samples: 16 });
    const setSize = gtao.setSize.bind(gtao);
    gtao.setSize = (w, h) => setSize(Math.ceil(w * AO_SCALE), Math.ceil(h * AO_SCALE));
    // See-through parts (ghosts, skin, slots, shadow) must not occlude.
    gtao._overrideVisibility = function () {
      const cache = this._visibilityCache;
      this.scene.traverse((o) => {
        if (!o.visible) return;
        if (o.isPoints || o.isLine || o.isSprite || (o.isMesh && (o.material.transparent || o.userData.noAO))) {
          o.visible = false;
          cache.push(o);
        }
      });
    };
    composer.addPass(gtao);
    this.final = new FinalPass(gtao.gtaoMap);
    composer.addPass(this.final);
    composer.setPixelRatio(1);
    composer.setSize(size.x, size.y);
    this.composer = composer;
    this.gtao = gtao;
  }

  setSize(width, height) {
    this.aoStep = -1;
    if (!this.composer) return;
    const size = this.renderer.getDrawingBufferSize(new THREE.Vector2());
    this.composer.setSize(size.x, size.y);
  }

  /** Something changed: drop AO and render directly. */
  renderActive(now) {
    this.lastActive = now;
    this.aoStep = this.aoEnabled ? 0 : -1;
    this.shadow.updateIfDirty();
    this.renderer.render(this.scene, this.camera);
  }

  /** Called on frames with nothing new; refines with AO once idle. */
  renderIdle(now) {
    if (this.aoStep < 0 || !this.aoEnabled) return;
    if (now - this.lastActive < IDLE_MS) return;
    this.ensureComposer();
    this.gtao.enabled = this.aoStep === 0;
    this.final.uniforms.uAO.value = AO_FADE[this.aoStep];
    this.composer.render();
    this.aoStep = this.aoStep + 1 < AO_FADE.length ? this.aoStep + 1 : -1;
  }
}

/** 9-tap separable gaussian; `dir` is the texel step (x or y). */
const BlurShader = {
  uniforms: { tDiffuse: { value: null }, dir: { value: new THREE.Vector2() } },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }`,
  fragmentShader: /* glsl */`
    uniform sampler2D tDiffuse;
    uniform vec2 dir;
    varying vec2 vUv;
    void main() {
      vec4 sum = texture2D(tDiffuse, vUv) * 0.2270270270;
      sum += texture2D(tDiffuse, vUv + dir * 1.3846153846) * 0.3162162162;
      sum += texture2D(tDiffuse, vUv - dir * 1.3846153846) * 0.3162162162;
      sum += texture2D(tDiffuse, vUv + dir * 3.2307692308) * 0.0702702703;
      sum += texture2D(tDiffuse, vUv - dir * 3.2307692308) * 0.0702702703;
      gl_FragColor = sum;
    }`,
};

// ---- Contact shadow ---------------------------------------------------------
// Renders the scene's solid parts from below into a small texture (darker the
// closer to the floor), blurs it, and lays it on a plane under the feet. It is
// camera-independent, so it only re-renders when the visible parts change.

class ContactShadow {
  constructor(renderer, scene) {
    this.renderer = renderer;
    this.scene = scene;
    this.size = 512;
    this.dirty = false;
    this.enabled = true;
    this.target = new THREE.WebGLRenderTarget(this.size, this.size);
    this.target.texture.generateMipmaps = false;
    this.blurTarget = new THREE.WebGLRenderTarget(this.size, this.size);
    this.blurTarget.texture.generateMipmaps = false;
    this.height = 0.35;
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, this.height);
    this.camera.rotation.x = Math.PI / 2;

    this.depthMaterial = new THREE.MeshDepthMaterial({ side: THREE.DoubleSide });
    this.depthMaterial.onBeforeCompile = (shader) => {
      shader.uniforms.darkness = { value: 1.6 };
      shader.fragmentShader = `uniform float darkness;\n${shader.fragmentShader.replace(
        'gl_FragColor = vec4( vec3( 1.0 - fragCoordZ ), opacity );',
        'gl_FragColor = vec4( vec3( 0.0 ), ( 1.0 - fragCoordZ ) * darkness );',
      )}`;
    };

    this.blurMaterial = new THREE.ShaderMaterial(BlurShader);
    this.blurMaterial.depthTest = false;
    this.quad = new FullScreenQuad(this.blurMaterial);

    const planeMat = new THREE.MeshBasicMaterial({
      map: this.target.texture,
      transparent: true,
      opacity: 0.85,
      depthWrite: false,
      toneMapped: false,
    });
    planeMat.color.setRGB(0.04, 0.02, 0.1);
    this.plane = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), planeMat);
    // The texture is rendered looking up; flip it to read from above.
    this.plane.scale.set(1, 1, -1);
    this.plane.userData.noAO = true;
    this.plane.renderOrder = -1;
    this.plane.visible = false;
    scene.add(this.plane);
  }

  setResolution(size) {
    if (size === this.size) return;
    this.size = size;
    this.target.setSize(size, size);
    this.blurTarget.setSize(size, size);
    this.dirty = true;
  }

  markDirty() {
    this.dirty = true;
  }

  setEnabled(enabled) {
    this.enabled = enabled;
    if (!enabled) this.plane.visible = false;
    else this.dirty = true;
  }

  updateIfDirty() {
    if (!this.dirty) return;
    this.dirty = false;
    if (!this.enabled) return;
    const { renderer, scene, plane } = this;
    plane.visible = false;
    scene.updateMatrixWorld();
    // Bounds of solid, visible meshes.
    const box = new THREE.Box3();
    const hidden = [];
    scene.traverseVisible((o) => {
      if (!o.isMesh && !o.isPoints) return;
      if (o.isPoints || o.material.transparent || o.userData.noAO) {
        o.visible = false;
        hidden.push(o);
        return;
      }
      if (!o.geometry.boundingBox) o.geometry.computeBoundingBox();
      box.union(o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld));
    });
    if (box.isEmpty()) {
      for (const o of hidden) o.visible = true;
      return;
    }
    const center = box.getCenter(new THREE.Vector3());
    const extent = Math.max(box.max.x - box.min.x, box.max.z - box.min.z) * 0.5 + 0.12;
    const floor = box.min.y - 0.004;
    const cam = this.camera;
    cam.left = -extent; cam.right = extent; cam.top = extent; cam.bottom = -extent;
    cam.position.set(center.x, floor, center.z);
    cam.near = 0;
    cam.far = this.height;
    cam.updateProjectionMatrix();
    cam.updateMatrixWorld();

    const clearColor = renderer.getClearColor(new THREE.Color());
    const clearAlpha = renderer.getClearAlpha();
    const target = renderer.getRenderTarget();
    const autoClear = renderer.autoClear;
    const env = scene.environment;
    scene.overrideMaterial = this.depthMaterial;
    scene.environment = null;
    renderer.setClearColor(0x000000, 0);
    renderer.autoClear = true;
    renderer.setRenderTarget(this.target);
    renderer.render(scene, cam);
    scene.overrideMaterial = null;
    scene.environment = env;
    for (const o of hidden) o.visible = true;

    // Two separable blur rounds, widening each time.
    const u = this.blurMaterial.uniforms;
    for (const amount of [2.2, 1.1]) {
      u.tDiffuse.value = this.target.texture;
      u.dir.value.set(amount / this.size, 0);
      renderer.setRenderTarget(this.blurTarget);
      this.quad.render(renderer);
      u.tDiffuse.value = this.blurTarget.texture;
      u.dir.value.set(0, amount / this.size);
      renderer.setRenderTarget(this.target);
      this.quad.render(renderer);
    }

    renderer.setRenderTarget(target);
    renderer.setClearColor(clearColor, clearAlpha);
    renderer.autoClear = autoClear;

    plane.position.set(center.x, floor, center.z);
    plane.scale.set(extent * 2, 1, -extent * 2);
    plane.visible = true;
  }
}
