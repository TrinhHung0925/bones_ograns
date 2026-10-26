// 3D anatomy viewer. Rendering, picking and camera only: all app logic lives
// in Flutter, which drives this page through `window.anatomy.call(...)` and
// receives events on the `Bridge` JavaScript channel.

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';

const SYSTEM_COLORS = {
  skeletal: 0xe9dfc9,
  muscular: 0xb8483e,
  cardiovascular: 0xc8323a,
  nervous: 0xf0c94c,
  respiratory: 0xe59aa8,
  digestive: 0xd9906c,
  urinary: 0xd1a94f,
  reproductive: 0xc97c9c,
  endocrine: 0x9d7fd6,
  sensory: 0x7fb7da,
  integumentary: 0xe2b79d,
  other: 0x9aa4ae,
};
const VEIN_COLOR = 0x3f63c9;
const SELECT_EMISSIVE = new THREE.Color(0x2f7bff).multiplyScalar(0.55);
// Low because hundreds of ghosted layers stack up in front of the selection.
const GHOST_OPACITY = 0.07;
// Skin would hide everything else, so it is always drawn see-through.
const SKIN_OPACITY = 0.28;

const post = (msg) => window.Bridge?.postMessage(JSON.stringify(msg));

const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.01, 50);
scene.add(new THREE.HemisphereLight(0xffffff, 0x4a5566, 1.6));
const headlight = new THREE.DirectionalLight(0xffffff, 1.6);
headlight.position.set(0.3, 0.4, 1);
camera.add(headlight);
scene.add(camera);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.12;
controls.screenSpacePanning = true;
controls.minDistance = 0.08;
controls.maxDistance = 8;

const HOME = { target: new THREE.Vector3(0, 0, 0), position: new THREE.Vector3(0, 0.05, 3.4) };
camera.position.copy(HOME.position);
controls.target.copy(HOME.target);

const loader = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);

/** system -> { group, loading: Promise, visible } */
const systems = new Map();
/** part id -> { mesh, system, state: 'visible' | 'hidden' | 'ghost' } */
const parts = new Map();
let selectedId = null;
const flashes = new Map();

function baseOpacity(part) {
  if (part.state === 'ghost') return GHOST_OPACITY;
  return part.system === 'integumentary' ? SKIN_OPACITY : 1;
}

function applyVisual(part) {
  const { mesh } = part;
  const mat = mesh.material;
  mesh.visible = part.state !== 'hidden';
  const opacity = baseOpacity(part);
  mat.transparent = opacity < 1;
  mat.opacity = opacity;
  mat.depthWrite = opacity === 1;
  const flash = flashes.get(mesh.name);
  if (flash) {
    mat.emissive.set(flash.color).multiplyScalar(0.6);
  } else if (mesh.name === selectedId) {
    mat.emissive.copy(SELECT_EMISSIVE);
  } else {
    mat.emissive.setRGB(0, 0, 0);
  }
  // Transparent parts render after opaque ones so ghosts never hide solids.
  mesh.renderOrder = mat.transparent ? 1 : 0;
  requestRender();
}

function loadSystem(system) {
  let entry = systems.get(system);
  if (entry) return entry.loading;
  entry = { group: null, visible: true, loading: null };
  systems.set(system, entry);
  post({ type: 'systemLoading', system });
  entry.loading = loader.loadAsync(`../anatomy/models/${system}.glb`).then((gltf) => {
    const group = gltf.scene;
    group.name = system;
    group.traverse((obj) => {
      if (!obj.isMesh) return;
      // Single-primitive nodes load as the mesh itself, named by part id.
      const id = obj.name;
      const name = obj.userData.name ?? '';
      const isVein = system === 'cardiovascular' && /vein|venous|sinus/i.test(name);
      obj.material = new THREE.MeshStandardMaterial({
        color: isVein ? VEIN_COLOR : SYSTEM_COLORS[system] ?? SYSTEM_COLORS.other,
        roughness: system === 'skeletal' ? 0.75 : 0.55,
        metalness: 0,
        side: system === 'integumentary' ? THREE.FrontSide : THREE.DoubleSide,
      });
      const part = { mesh: obj, system, state: 'visible' };
      parts.set(id, part);
      applyVisual(part);
    });
    group.visible = entry.visible;
    entry.group = group;
    scene.add(group);
    requestRender();
    post({ type: 'systemLoaded', system });
  }).catch((err) => {
    systems.delete(system);
    post({ type: 'error', message: `Không tải được ${system}: ${err}` });
  });
  return entry.loading;
}

// ---- Camera animation -------------------------------------------------------

let tween = null;

function animateCamera(target, position, duration = 550) {
  tween = {
    fromTarget: controls.target.clone(),
    fromPosition: camera.position.clone(),
    target,
    position,
    start: performance.now(),
    duration,
  };
  requestRender();
}

function stepTween(now) {
  if (!tween) return false;
  const t = Math.min(1, (now - tween.start) / tween.duration);
  const k = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
  controls.target.lerpVectors(tween.fromTarget, tween.target, k);
  camera.position.lerpVectors(tween.fromPosition, tween.position, k);
  if (t >= 1) tween = null;
  return true;
}

function focusPart(id) {
  const part = parts.get(id);
  if (!part) return;
  const sphere = new THREE.Box3().setFromObject(part.mesh).getBoundingSphere(new THREE.Sphere());
  const fov = THREE.MathUtils.degToRad(camera.fov);
  const fit = Math.min(fov, 2 * Math.atan(Math.tan(fov / 2) * camera.aspect));
  const distance = Math.max(sphere.radius / Math.sin(fit / 2) * 1.4, controls.minDistance * 2);
  const dir = camera.position.clone().sub(controls.target).normalize();
  animateCamera(sphere.center.clone(), sphere.center.clone().addScaledVector(dir, distance));
}

// ---- Picking ----------------------------------------------------------------

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

function pick(clientX, clientY) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.set(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
  raycaster.setFromCamera(pointer, camera);
  const candidates = [];
  for (const part of parts.values()) {
    // Ghosted parts and skin are see-through, so taps pass through them.
    if (part.state !== 'visible' || part.system === 'integumentary') continue;
    if (!systems.get(part.system)?.visible) continue;
    candidates.push(part.mesh);
  }
  const hit = raycaster.intersectObjects(candidates, false)[0];
  return hit ? hit.object.name : null;
}

let down = null;
let activePointers = 0;
let lastTap = { id: undefined, time: 0 };

renderer.domElement.addEventListener('pointerdown', (e) => {
  activePointers++;
  down = activePointers === 1 ? { x: e.clientX, y: e.clientY, time: performance.now() } : null;
});
renderer.domElement.addEventListener('pointerup', (e) => {
  activePointers = Math.max(0, activePointers - 1);
  if (!down) return;
  const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
  const elapsed = performance.now() - down.time;
  down = null;
  if (moved > 8 || elapsed > 400) return;
  const id = pick(e.clientX, e.clientY);
  const now = performance.now();
  const doubleTap = id && id === lastTap.id && now - lastTap.time < 320;
  lastTap = { id, time: now };
  post({ type: doubleTap ? 'doubleTap' : 'tap', id });
});
renderer.domElement.addEventListener('pointercancel', () => {
  activePointers = Math.max(0, activePointers - 1);
  down = null;
});

// ---- Commands from Flutter --------------------------------------------------

const commands = {
  async setSystemVisible(system, visible) {
    if (visible) await loadSystem(system);
    const entry = systems.get(system);
    if (!entry) return;
    entry.visible = visible;
    if (entry.group) entry.group.visible = visible;
    requestRender();
  },
  select(id) {
    const previous = parts.get(selectedId);
    selectedId = id;
    if (previous) applyVisual(previous);
    const part = parts.get(id);
    if (part) applyVisual(part);
  },
  setPartState(id, state) {
    const part = parts.get(id);
    if (!part) return;
    part.state = state;
    applyVisual(part);
  },
  isolate(id) {
    for (const [partId, part] of parts) {
      if (!systems.get(part.system)?.visible) continue;
      part.state = partId === id ? 'visible' : 'ghost';
      applyVisual(part);
    }
  },
  showAll() {
    for (const part of parts.values()) {
      part.state = 'visible';
      applyVisual(part);
    }
  },
  focus(id) {
    focusPart(id);
  },
  resetCamera() {
    animateCamera(HOME.target.clone(), HOME.position.clone());
  },
  flash(id, color, ms = 900) {
    const part = parts.get(id);
    if (!part) return;
    clearTimeout(flashes.get(id)?.timer);
    const timer = setTimeout(() => {
      flashes.delete(id);
      applyVisual(part);
    }, ms);
    flashes.set(id, { color, timer });
    applyVisual(part);
  },
};

// Commands run one after another, so e.g. a `focus` sent right after
// `setSystemVisible` waits until that system's model has loaded.
let queue = Promise.resolve();

window.anatomy = {
  call(message) {
    const fn = commands[message.cmd];
    if (!fn) {
      post({ type: 'error', message: `Unknown command ${message.cmd}` });
      return;
    }
    queue = queue
      .then(() => fn(...(message.args ?? [])))
      .catch((err) => post({ type: 'error', message: String(err) }));
  },
};

// ---- Render loop ------------------------------------------------------------

let renderRequested = true;
function requestRender() {
  renderRequested = true;
}

controls.addEventListener('change', requestRender);
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  requestRender();
});

renderer.setAnimationLoop((now) => {
  const animating = stepTween(now);
  controls.update();
  if (animating || renderRequested) {
    renderRequested = false;
    renderer.render(scene, camera);
  }
});

post({ type: 'ready' });
