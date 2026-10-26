// 3D anatomy viewer. Rendering, picking and camera, plus the drag-and-snap
// mechanics of the assembly game; app logic (levels, scoring) lives in
// Flutter, which drives this page through `window.anatomy.call(...)` and
// receives events on the `Bridge` JavaScript channel.
//
// Look: per-part procedural PBR materials (materials.js), image-based
// lighting, ACES tone mapping, idle-time ambient occlusion and a contact
// shadow (postfx.js). Game sounds are synthesised in sfx.js.

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
import { createPartMaterial, setDetail, setGlow } from './materials.js';
import { Pipeline } from './postfx.js';
import { sfx } from './sfx.js';

const SELECT_GLOW = new THREE.Color(0x4fb6ff);
// Low because hundreds of ghosted layers stack up in front of the selection.
const GHOST_OPACITY = 0.07;
// Skin would hide everything else, so it is always drawn see-through.
const SKIN_OPACITY = 0.26;

const post = (msg) => window.Bridge?.postMessage(JSON.stringify(msg));

let quality = 'high';
const pixelRatio = () => Math.min(window.devicePixelRatio, quality === 'low' ? 1.5 : 2);

const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(pixelRatio());
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.01, 50);
scene.add(camera);
const pipeline = new Pipeline(renderer, scene, camera);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.12;
controls.screenSpacePanning = true;
controls.minDistance = 0.08;
controls.maxDistance = 8;
// Pinch and wheel zoom toward the fingers/cursor, like zooming a photo.
controls.zoomToCursor = true;
controls.zoomSpeed = 1.15;

const HOME = { target: new THREE.Vector3(0, 0, 0), position: new THREE.Vector3(0, 0.05, 3.4) };
camera.position.copy(HOME.position);
controls.target.copy(HOME.target);

const loader = new GLTFLoader().setMeshoptDecoder(MeshoptDecoder);

/** system -> { group, loading: Promise, visible } */
const systems = new Map();
/** part id -> { mesh, system, state: 'visible' | 'hidden' | 'ghost' } */
const parts = new Map();
/** Every part material, for quality switches. */
const materials = [];
let selectedId = null;
const flashes = new Map();

function baseOpacity(part) {
  if (part.state === 'ghost') return GHOST_OPACITY;
  return part.system === 'integumentary' ? SKIN_OPACITY : 1;
}

function applyVisual(part) {
  const { mesh } = part;
  const mat = mesh.material;
  const visible = part.state !== 'hidden';
  const opacity = baseOpacity(part);
  // The contact shadow only depends on which solid parts show.
  if (mesh.visible !== visible || mat.transparent !== opacity < 1) pipeline.shadow.markDirty();
  mesh.visible = visible;
  mat.transparent = opacity < 1;
  mat.opacity = opacity;
  mat.depthWrite = opacity === 1;
  const flash = flashes.get(mesh.name);
  if (part.piece) {
    // Assembly pieces get their glow from the game loop (held/snap/hint).
  } else if (flash) {
    setGlow(mat, flash.color, 1.6, 0.6, 0.55);
  } else if (mesh.name === selectedId) {
    setGlow(mat, SELECT_GLOW, 2.2, 0.2, 0.3);
  } else {
    setGlow(mat, null);
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
      obj.material = createPartMaterial(system, name, obj.geometry);
      materials.push(obj.material);
      // Parts loading in mid-game stay out of the assembly scene.
      const hidden = assembly && !assembly.memberIds.has(id);
      const part = { mesh: obj, system, state: hidden ? 'hidden' : 'visible' };
      parts.set(id, part);
      applyVisual(part);
    });
    group.visible = entry.visible;
    entry.group = group;
    scene.add(group);
    pipeline.shadow.markDirty();
    requestRender();
    post({ type: 'systemLoaded', system });
  }).catch((err) => {
    systems.delete(system);
    post({ type: 'error', message: `Không tải được ${system}: ${err}` });
  });
  return entry.loading;
}

function setQuality(level) {
  quality = level === 'low' ? 'low' : 'high';
  setDetail(quality === 'high', materials);
  pipeline.setQuality(quality);
  renderer.setPixelRatio(pixelRatio());
  renderer.setSize(window.innerWidth, window.innerHeight);
  pipeline.setSize();
  requestRender();
}

// ---- Camera animation -------------------------------------------------------

let tween = null;
/** Slow 360° orbit after a big level is completed. */
let tour = null;

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

function stepTour(now) {
  if (!tour) return false;
  if (now < tour.start || tween) return true;
  if (!tour.offset) tour.offset = camera.position.clone().sub(controls.target);
  const t = Math.min(1, (now - tour.start) / tour.duration);
  const k = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
  camera.position.copy(controls.target)
    .add(tour.offset.clone().applyAxisAngle(camera.up, k * Math.PI * 2));
  if (t >= 1) tour = null;
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
  tour = null;
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

// ---- Assembly game ----------------------------------------------------------
// The level's pieces are scattered around their true positions, which stay
// marked by faint "ghost" slots. Dragging a piece onto its own slot snaps it
// in place. A piece is either one part or a rigid group of parts (e.g. a whole
// hand); its meshes hang off a pivot at the piece's bounding-box centre so it
// moves and rotates about itself. Meshes go back to their system groups when
// the game ends.

const SLOT_COLOR = new THREE.Color(0x9d8cff);
const HINT_COLOR = new THREE.Color(0xffcb4c);
const HELD_GLOW = new THREE.Color(0x7a66ff);
const SNAP_GLOW = new THREE.Color(0x3edc8b);
const WRONG_GLOW = new THREE.Color(0xff5c7a);
const WIN_GLOW = new THREE.Color(0xffcb4c);
const MAGNET_COLOR = new THREE.Color(0x7dffb6);
const HELD_SCALE = 1.08;
const SNAP_MS = 340;
const HINT_MS = 2600;
const MIN_SNAP_PX = 28;
const MAGNET_RANGE = 1.5;
const COMBO_MS = 4000;
/** Levels with more pieces use the packed layout, hint zoom and win tour. */
const BIG_LEVEL = 12;
const NO_ROTATION = new THREE.Quaternion();

const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
const easeInOutCubic = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const easeOutBack = (t) => 1 + 2.70158 * Math.pow(t - 1, 3) + 1.70158 * Math.pow(t - 1, 2);
const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

/**
 * Active session, null outside the game:
 * { pieces: Map<id, piece>, memberIds, meshToPiece, center, basis, group
 *   (slots), drag, completeAt, big, combo, lastSnap }
 */
let assembly = null;
/** Particle bursts in flight, also used for the win celebration. */
const bursts = [];

/** Fresnel-like see-through shell: faint fill, brighter silhouette edges. */
function slotMaterial() {
  return new THREE.ShaderMaterial({
    uniforms: { uColor: { value: SLOT_COLOR.clone() }, uOpacity: { value: 1 } },
    vertexShader: `
      varying vec3 vNormal;
      varying vec3 vView;
      void main() {
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        vNormal = normalize(normalMatrix * normal);
        vView = normalize(-mv.xyz);
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uOpacity;
      varying vec3 vNormal;
      varying vec3 vView;
      void main() {
        float rim = 1.0 - abs(dot(normalize(vNormal), normalize(vView)));
        gl_FragColor = vec4(uColor, (0.05 + 0.5 * pow(rim, 2.5)) * uOpacity);
        #include <colorspace_fragment>
      }`,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
  });
}

const sparkTexture = (() => {
  const size = 64;
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.35, 'rgba(255,255,255,0.55)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  return new THREE.CanvasTexture(canvas);
})();

/** Additive sparks flying out of [center]; [radius] sets speed and size. */
function burst(center, radius, color, count = 34, duration = 750) {
  const positions = new Float32Array(count * 3);
  const velocities = [];
  for (let i = 0; i < count; i++) {
    const v = new THREE.Vector3().randomDirection().multiplyScalar(radius * (0.9 + Math.random() * 1.6));
    velocities.push(v);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const material = new THREE.PointsMaterial({
    color,
    map: sparkTexture,
    size: Math.max(radius * 0.32, (assembly?.radius ?? 0.2) * 0.025),
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  const points = new THREE.Points(geometry, material);
  points.position.copy(center);
  points.renderOrder = 3;
  points.frustumCulled = false;
  scene.add(points);
  bursts.push({ points, velocities, start: performance.now(), duration });
  requestRender();
}

function stepBursts(now) {
  for (let i = bursts.length - 1; i >= 0; i--) {
    const b = bursts[i];
    const t = Math.min(1, (now - b.start) / b.duration);
    const k = easeOutCubic(t);
    const attr = b.points.geometry.attributes.position;
    b.velocities.forEach((v, j) => attr.setXYZ(j, v.x * k, v.y * k - 0.3 * v.length() * t * t, v.z * k));
    attr.needsUpdate = true;
    b.points.material.opacity = 1 - t * t;
    if (t >= 1) {
      scene.remove(b.points);
      b.points.geometry.dispose();
      b.points.material.dispose();
      bursts.splice(i, 1);
    }
  }
  return bursts.length > 0;
}

/**
 * Camera right/up/back vectors for a view from direction [dir]. Screen up
 * stays world up (OrbitControls assumes camera.up never changes), so [dir]
 * must not be straight up or down.
 */
function viewBasis(dir) {
  const back = dir.clone().normalize();
  const right = new THREE.Vector3().crossVectors(camera.up, back).normalize();
  const up = new THREE.Vector3().crossVectors(back, right);
  return { right, up, back };
}

/** Animates the camera so every sphere in [items] fits the viewport. */
function fitSpheres(items, basis, duration = 700) {
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity, maxZ = -Infinity;
  const origin = items[0].pos;
  const d = new THREE.Vector3();
  for (const { pos, r } of items) {
    d.subVectors(pos, origin);
    const x = d.dot(basis.right), y = d.dot(basis.up), z = d.dot(basis.back);
    minX = Math.min(minX, x - r); maxX = Math.max(maxX, x + r);
    minY = Math.min(minY, y - r); maxY = Math.max(maxY, y + r);
    maxZ = Math.max(maxZ, z + r);
  }
  const center = origin.clone()
    .addScaledVector(basis.right, (minX + maxX) / 2)
    .addScaledVector(basis.up, (minY + maxY) / 2);
  const tanV = Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2);
  const tanH = tanV * camera.aspect;
  const distance = Math.max((maxX - minX) / 2 / tanH, (maxY - minY) / 2 / tanV) * 1.06 + maxZ;
  animateCamera(center, center.clone().addScaledVector(basis.back, distance), duration);
}

/** Screen position (CSS px) of a world point. */
function toScreen(point) {
  const v = point.clone().project(camera);
  const rect = renderer.domElement.getBoundingClientRect();
  return { x: (v.x + 1) / 2 * rect.width, y: (1 - v.y) / 2 * rect.height };
}

function projectedRadius(point, radius) {
  const rect = renderer.domElement.getBoundingClientRect();
  const distance = Math.max(point.distanceTo(camera.position), 1e-4);
  return radius * (rect.height / 2) / (distance * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2));
}

/** How close (px) a dropped piece must be to a slot to count as "on" it. */
function snapRadius(piece) {
  return Math.max(MIN_SNAP_PX, 0.35 * projectedRadius(piece.home, piece.radius));
}

/** Builds a piece from one or more loaded parts ([members]: [{id, part}]). */
function makePiece(id, members) {
  const box = new THREE.Box3();
  for (const { part } of members) {
    const { mesh } = part;
    if (!mesh.geometry.attributes.normal) mesh.geometry.computeVertexNormals();
    mesh.updateWorldMatrix(true, false);
    box.expandByObject(mesh);
  }
  const home = box.getCenter(new THREE.Vector3());
  const radius = box.getBoundingSphere(new THREE.Sphere()).radius;
  // One material per piece, shared by all of the piece's ghost meshes.
  const slotMat = slotMaterial();
  const slot = new THREE.Group();
  const pivot = new THREE.Group();
  pivot.position.copy(home);
  scene.add(pivot);
  pivot.updateMatrixWorld(true);
  const piece = {
    id, pivot, slot, slotMat, home, radius, box,
    members: [],
    snapped: false,
    held: false,
    scale: 1,
    anim: null,     // position/rotation tween
    pop: 0,         // start time of the snap "pop"
    glow: null,     // { color, start, duration, peak }
    hintUntil: 0,
    slotFade: 0,    // start time of the slot fading out
    magnet: 0,      // 0..1 pull towards its slot while dragged
  };
  for (const { id: partId, part } of members) {
    const { mesh } = part;
    const ghost = new THREE.Mesh(mesh.geometry, slotMat);
    ghost.matrixAutoUpdate = false;
    ghost.matrix.copy(mesh.matrixWorld);
    ghost.renderOrder = 2;
    slot.add(ghost);
    piece.members.push({
      id: partId,
      part,
      mesh,
      original: {
        parent: mesh.parent,
        position: mesh.position.clone(),
        quaternion: mesh.quaternion.clone(),
        scale: mesh.scale.clone(),
      },
    });
    pivot.attach(mesh);
    part.piece = piece;
    part.state = 'visible';
    applyVisual(part);
  }
  return piece;
}

function releasePiece(piece) {
  for (const { mesh, original, part } of piece.members) {
    original.parent.add(mesh);
    mesh.position.copy(original.position);
    mesh.quaternion.copy(original.quaternion);
    mesh.scale.copy(original.scale);
    delete part.piece;
    setGlow(mesh.material, null);
  }
  scene.remove(piece.pivot);
  piece.slotMat.dispose();
}

/** Tweens a piece's pivot to [pos]/[quat]; [onDone] runs when it arrives. */
function movePiece(piece, pos, quat, duration, ease, delay = 0, onDone = null) {
  piece.anim = {
    fromPos: piece.pivot.position.clone(),
    fromQuat: piece.pivot.quaternion.clone(),
    pos: pos.clone(),
    quat: quat.clone(),
    start: performance.now() + delay,
    duration,
    ease,
    onDone,
  };
  requestRender();
}

/**
 * Places pieces on an ellipse around the level (shaped like the viewport),
 * keeping each piece on roughly the same side it came from. Used for small
 * levels; big ones use [packedTargets].
 */
function scatterTargets(list, center, basis) {
  const d = new THREE.Vector3();
  let hw = 0, hh = 0, maxR = 0;
  const angles = new Map();
  for (const p of list) {
    d.subVectors(p.home, center);
    const x = d.dot(basis.right), y = d.dot(basis.up);
    hw = Math.max(hw, Math.abs(x));
    hh = Math.max(hh, Math.abs(y));
    maxR = Math.max(maxR, p.radius);
    angles.set(p, Math.atan2(y, x));
  }
  const gap = Math.max(maxR * 1.1, 0.3 * Math.max(hw, hh));
  let a = hw + gap, b = hh + gap;
  if (a / b < camera.aspect) a = b * camera.aspect;
  else b = a / camera.aspect;
  const sorted = [...list].sort((p, q) => angles.get(p) - angles.get(q));
  const step = (Math.PI * 2) / sorted.length;
  const start = angles.get(sorted[0]);
  const twoRings = sorted.length > 12;
  const spots = sorted.map((p, i) => {
    const theta = start + i * step + (Math.random() - 0.5) * step * 0.5;
    const ring = twoRings ? (i % 2 ? 1.2 : 0.97) : 1.05;
    return { p, x: Math.cos(theta) * a * ring, y: Math.sin(theta) * b * ring, r: p.radius * 0.75 };
  });
  relaxSpots(spots, hw, hh);
  const targets = new Map(spots.map(({ p, x, y }) => {
    const pos = center.clone()
      .addScaledVector(basis.right, x)
      .addScaledVector(basis.up, y)
      .addScaledVector(basis.back, (Math.random() - 0.5) * gap * 0.6);
    const axis = new THREE.Vector3().randomDirection();
    const quat = new THREE.Quaternion().setFromAxisAngle(axis, 0.7 + Math.random() * 1.5);
    return [p, { pos, quat }];
  }));
  const fit = [];
  for (const [p, { pos }] of targets) fit.push({ pos: p.home, r: p.radius }, { pos, r: p.radius });
  return { targets, fit };
}

/**
 * Pushes overlapping scattered pieces apart (in the screen plane) while
 * keeping them outside the level's own [hw] x [hh] footprint.
 */
function relaxSpots(spots, hw, hh) {
  for (let iter = 0; iter < 40; iter++) {
    let moved = false;
    for (let i = 0; i < spots.length; i++) {
      for (let j = i + 1; j < spots.length; j++) {
        const s = spots[i], t = spots[j];
        const dx = t.x - s.x, dy = t.y - s.y;
        const dist = Math.hypot(dx, dy) || 1e-6;
        const overlap = s.r + t.r - dist;
        if (overlap <= 0) continue;
        const push = overlap / 2 / dist;
        s.x -= dx * push; s.y -= dy * push;
        t.x += dx * push; t.y += dy * push;
        moved = true;
      }
    }
    for (const s of spots) {
      const e = Math.hypot(s.x / (hw + s.r), s.y / (hh + s.r));
      if (e < 1) {
        s.x /= Math.max(e, 0.2);
        s.y /= Math.max(e, 0.2);
        moved = true;
      }
    }
    if (!moved) break;
  }
}

/** Half extents of a world box seen in the basis' screen plane. */
function screenExtents(box, basis) {
  const c = box.getCenter(new THREE.Vector3());
  const corner = new THREE.Vector3();
  let hx = 0, hy = 0;
  for (let i = 0; i < 8; i++) {
    corner.set(i & 1 ? box.max.x : box.min.x, i & 2 ? box.max.y : box.min.y, i & 4 ? box.max.z : box.min.z).sub(c);
    hx = Math.max(hx, Math.abs(corner.dot(basis.right)));
    hy = Math.max(hy, Math.abs(corner.dot(basis.up)));
  }
  return { hx, hy };
}

/**
 * Layout for big levels (e.g. a whole skeleton): every piece gets a free
 * rectangle around the body's silhouette, as close as possible to where it
 * belongs (hands beside the hands, skull above the head...). The frame keeps
 * the viewport's aspect and grows until everything fits, so the camera can
 * show the whole layout on a portrait phone.
 */
function packedTargets(list, center, basis) {
  const rel = new THREE.Vector3();
  const items = list.map((p) => {
    rel.subVectors(p.home, center);
    const { hx, hy } = screenExtents(p.box, basis);
    // Mostly an in-plane spin, so the footprint stays predictable.
    const spin = (Math.random() < 0.5 ? -1 : 1) * (0.25 + Math.random() * 0.45);
    const c = Math.abs(Math.cos(spin)), s = Math.abs(Math.sin(spin));
    return {
      p, spin,
      hx: hx, hy: hy,
      wx: (c * hx + s * hy) * 1.04,
      wy: (s * hx + c * hy) * 1.04,
      x: rel.dot(basis.right), y: rel.dot(basis.up),
    };
  });
  let bx0 = Infinity, bx1 = -Infinity, by0 = Infinity, by1 = -Infinity;
  for (const it of items) {
    bx0 = Math.min(bx0, it.x - it.hx); bx1 = Math.max(bx1, it.x + it.hx);
    by0 = Math.min(by0, it.y - it.hy); by1 = Math.max(by1, it.y + it.hy);
  }
  const bodyH = by1 - by0, bodyW = bx1 - bx0;
  const pad = Math.max(bodyH, bodyW) * 0.012;
  const body = { x0: bx0 - pad * 2, x1: bx1 + pad * 2, y0: by0 - pad * 2, y1: by1 + pad * 2 };
  const fcx = (bx0 + bx1) / 2, fcy = (by0 + by1) / 2;
  const aspect = camera.aspect;
  const sorted = [...items].sort((a, b) => b.wx * b.wy - a.wx * a.wy);
  let H = Math.max(bodyH * 1.12, (bodyW * 1.12) / aspect);
  let placed = null;
  for (let attempt = 0; attempt < 40 && !placed; attempt++, H *= 1.07) {
    const W = H * aspect;
    const rects = [body];
    const step = Math.min(W, H) / 48;
    const out = new Map();
    let ok = true;
    for (const it of sorted) {
      const xs = [], ys = [];
      for (let x = fcx - W / 2 + it.wx; x <= fcx + W / 2 - it.wx; x += step) xs.push(x);
      for (let y = fcy - H / 2 + it.wy; y <= fcy + H / 2 - it.wy; y += step) ys.push(y);
      const cands = [];
      for (const x of xs) for (const y of ys) {
        cands.push({ x, y, d: (x - it.x) ** 2 + (y - it.y) ** 2 });
      }
      cands.sort((a, b) => a.d - b.d);
      let spot = null;
      for (const c of cands) {
        const r = { x0: c.x - it.wx - pad, x1: c.x + it.wx + pad, y0: c.y - it.wy - pad, y1: c.y + it.wy + pad };
        if (rects.every((o) => r.x1 <= o.x0 || r.x0 >= o.x1 || r.y1 <= o.y0 || r.y0 >= o.y1)) {
          spot = { c, r };
          break;
        }
      }
      if (!spot) { ok = false; break; }
      rects.push(spot.r);
      out.set(it, spot.c);
    }
    if (ok) placed = out;
  }
  const targets = new Map();
  const fit = [];
  let x0 = body.x0, x1 = body.x1, y0 = body.y0, y1 = body.y1;
  for (const it of items) {
    const c = placed?.get(it) ?? { x: it.x * 2, y: it.y * 2 };
    x0 = Math.min(x0, c.x - it.wx); x1 = Math.max(x1, c.x + it.wx);
    y0 = Math.min(y0, c.y - it.wy); y1 = Math.max(y1, c.y + it.wy);
    const pos = center.clone()
      .addScaledVector(basis.right, c.x)
      .addScaledVector(basis.up, c.y)
      .addScaledVector(basis.back, (Math.random() - 0.5) * Math.min(it.wx, it.wy));
    const tilt = new THREE.Quaternion().setFromAxisAngle(
      basis.right.clone().multiplyScalar(Math.random() - 0.5).addScaledVector(basis.up, Math.random() - 0.5).normalize(),
      Math.random() * 0.35,
    );
    const quat = new THREE.Quaternion().setFromAxisAngle(basis.back, it.spin).multiply(tilt);
    targets.set(it.p, { pos, quat });
  }
  // Fit the used area (as two corner "spheres" of zero radius plus depth).
  const corner = (x, y) => center.clone().addScaledVector(basis.right, x).addScaledVector(basis.up, y);
  fit.push({ pos: corner(x0, y0), r: 0.001 }, { pos: corner(x1, y1), r: 0.001 });
  return { targets, fit };
}

/** Normalises assemblyStart's list: ids or {id, parts} groups. */
function pieceSpecs(list) {
  const used = new Set();
  const specs = [];
  for (const entry of list ?? []) {
    const spec = typeof entry === 'string'
      ? { id: entry, parts: [entry] }
      : { id: String(entry?.id), parts: Array.isArray(entry?.parts) ? entry.parts : [] };
    const members = [];
    for (const partId of spec.parts) {
      const part = parts.get(partId);
      if (!part || used.has(partId)) continue;
      used.add(partId);
      members.push({ id: partId, part });
    }
    if (members.length) specs.push({ id: spec.id, members });
  }
  return specs;
}

function startAssembly(list, options) {
  endAssembly(false);
  tour = null;
  const specs = pieceSpecs(list);
  const memberIds = new Set(specs.flatMap((s) => s.members.map((m) => m.id)));
  for (const [id, part] of parts) {
    if (memberIds.has(id)) continue;
    part.state = 'hidden';
    applyVisual(part);
  }
  if (specs.length === 0) {
    post({ type: 'error', message: 'Assembly level has no loaded parts' });
    return;
  }
  const group = new THREE.Group();
  scene.add(group);
  const pieces = new Map();
  const meshToPiece = new Map();
  for (const spec of specs) {
    const piece = makePiece(spec.id, spec.members);
    group.add(piece.slot);
    pieces.set(spec.id, piece);
    for (const m of piece.members) meshToPiece.set(m.mesh, piece);
  }
  const box = new THREE.Box3();
  for (const p of pieces.values()) box.union(p.box);
  const center = box.getCenter(new THREE.Vector3());
  const basis = viewBasis(new THREE.Vector3().fromArray(options.view ?? [0, 0, 1]));
  const radius = box.getBoundingSphere(new THREE.Sphere()).radius;
  const big = pieces.size > BIG_LEVEL;
  assembly = {
    pieces, memberIds, meshToPiece, group, center, basis, radius, big,
    drag: null, completeAt: 0, combo: 0, lastSnap: 0,
    // Dozens of stacked ghosts would read as a solid block, so big levels dim them.
    slotBase: big ? 0.55 : 1,
    overview: null,     // camera framing the whole layout (big levels)
    hintZoom: null,     // piece whose hint moved the camera, until it returns
  };
  for (const p of pieces.values()) p.slotMat.uniforms.uOpacity.value = assembly.slotBase;
  pipeline.shadow.setEnabled(false);

  // Show the finished region for a moment, then blow it apart.
  const list2 = [...pieces.values()];
  const { targets, fit } = big ? packedTargets(list2, center, basis) : scatterTargets(list2, center, basis);
  const introMs = options.introMs ?? 650;
  for (const [p, { pos, quat }] of targets) {
    const delay = introMs + Math.random() * (big ? 380 : 280);
    movePiece(p, pos, quat, big ? 1000 : 900, easeInOutCubic, delay);
  }
  if (big) {
    // Show the assembled body first, then pull back to the whole layout.
    fitSpheres([{ pos: center, r: radius }], basis, 600);
    setTimeout(() => {
      if (assembly?.pieces !== pieces) return;
      fitSpheres(fit, basis, 1000);
      assembly.overview = { target: tween.target.clone(), position: tween.position.clone() };
    }, introMs);
  } else {
    fitSpheres(fit, basis, 600);
  }
  setTimeout(() => {
    if (assembly?.pieces === pieces) sfx.whoosh();
  }, introMs);
  post({ type: 'assemblyReady', count: pieces.size });
}

function endAssembly(resetView = true) {
  if (!assembly) return;
  if (assembly.drag) controls.enabled = true;
  for (const piece of assembly.pieces.values()) releasePiece(piece);
  scene.remove(assembly.group);
  assembly = null;
  tour = null;
  for (const part of parts.values()) {
    part.state = 'visible';
    applyVisual(part);
  }
  for (const b of bursts.splice(0)) {
    scene.remove(b.points);
    b.points.geometry.dispose();
    b.points.material.dispose();
  }
  pipeline.shadow.setEnabled(true);
  if (resetView) {
    animateCamera(HOME.target.clone(), HOME.position.clone());
  }
  requestRender();
}

function remainingCount() {
  let n = 0;
  for (const p of assembly.pieces.values()) if (!p.snapped) n++;
  return n;
}

function snapPiece(piece) {
  const now = performance.now();
  piece.snapped = true;
  piece.magnet = 0;
  piece.slotFade = now;
  assembly.combo = now - assembly.lastSnap <= COMBO_MS ? assembly.combo + 1 : 1;
  assembly.lastSnap = now;
  const combo = assembly.combo;
  if (assembly.hintZoom === piece) setTimeout(() => assembly?.hintZoom === piece && returnFromHint(), SNAP_MS + 500);
  movePiece(piece, piece.home, NO_ROTATION, SNAP_MS, easeOutCubic, 0, () => {
    const t = performance.now();
    piece.pop = t;
    piece.glow = { color: SNAP_GLOW, start: t, duration: 1000, peak: 0.9 };
    burst(piece.home, piece.radius, 0x7dffb6);
    sfx.snap(combo);
    if (assembly && !assembly.completeAt && remainingCount() === 0) celebrate();
  });
  post({ type: 'pieceSnapped', id: piece.id, remaining: remainingCount() });
  if (combo >= 2) post({ type: 'combo', count: combo });
}

function celebrate() {
  const { pieces, center, basis, radius, big } = assembly;
  const now = performance.now();
  // A golden wave rolling out from the centre.
  for (const p of pieces.values()) {
    const delay = 250 + (p.home.distanceTo(center) / Math.max(radius, 1e-3)) * 450;
    p.glow = { color: WIN_GLOW, start: now + delay, duration: 900, peak: 0.7 };
  }
  setTimeout(() => {
    if (!assembly) return;
    burst(center, radius * 0.9, 0xffd966, 90, 1300);
    burst(center, radius * 0.6, 0x9d8cff, 60, 1100);
  }, 250);
  fitSpheres([...pieces.values()].map((p) => ({ pos: p.home, r: p.radius })), basis, 900);
  // Big models get a slow turntable while Flutter shows its dialog.
  if (big) tour = { start: now + 950, duration: 4200, offset: null };
  assembly.completeAt = now;
  sfx.complete();
  post({ type: 'assemblyComplete' });
}

function showHint(id) {
  if (!assembly) return;
  const open = [...assembly.pieces.values()].filter((p) => !p.snapped);
  if (open.length === 0) return;
  const piece = assembly.pieces.get(id)?.snapped === false
    ? assembly.pieces.get(id)
    : open[Math.floor(Math.random() * open.length)];
  piece.hintUntil = performance.now() + HINT_MS;
  // Hinted slots draw on top so even buried slots (e.g. inside the skull) show.
  piece.slotMat.depthTest = false;
  for (const ghost of piece.slot.children) ghost.renderOrder = 4;
  if (assembly.big) {
    // Big layouts: ease the camera so the piece and its slot fill the view;
    // it eases back to the overview when the hint ends (see returnFromHint).
    assembly.hintZoom = piece;
    const r = Math.max(piece.radius * 1.4, assembly.radius * 0.18);
    const dir = camera.position.clone().sub(controls.target).normalize();
    fitSpheres([
      { pos: piece.pivot.position.clone(), r },
      { pos: piece.home.clone(), r },
    ], viewBasis(dir), 800);
  }
  sfx.hint();
  requestRender();
  post({ type: 'hintShown', id: piece.id });
}

/** Glow of a piece right now; returns whether it is changing. */
function updatePieceVisual(piece, now) {
  let animating = false;
  let color = null, strength = 0, fill = 0.3;
  if (piece.held) { color = HELD_GLOW; strength = 0.75; fill = 0.25; }
  const glow = piece.glow;
  if (glow && now >= glow.start) {
    const t = (now - glow.start) / glow.duration;
    if (t >= 1) piece.glow = null;
    else { color = glow.color; strength = glow.peak * 1.4 * (1 - t) * (1 - t); fill = 0.45; }
  }
  if (glow) animating = true;
  const slotUniforms = piece.slotMat.uniforms;
  if (now < piece.hintUntil) {
    const pulse = 0.5 + 0.5 * Math.sin(now / 130);
    if (!piece.snapped) { color = HINT_COLOR; strength = 0.3 + 0.6 * pulse; fill = 0.35; }
    slotUniforms.uColor.value.copy(HINT_COLOR);
    slotUniforms.uOpacity.value = 1.6 + 1.6 * pulse;
    animating = true;
  } else if (piece.hintUntil) {
    piece.hintUntil = 0;
    slotUniforms.uColor.value.copy(SLOT_COLOR);
    slotUniforms.uOpacity.value = assembly.slotBase;
    piece.slotMat.depthTest = true;
    if (assembly.hintZoom === piece && !piece.held) returnFromHint();
    for (const ghost of piece.slot.children) ghost.renderOrder = 2;
    animating = true;
  } else if (!piece.snapped) {
    // Magnet range: the slot brightens and turns green as the piece nears it.
    const m = piece.magnet;
    slotUniforms.uColor.value.copy(SLOT_COLOR).lerp(MAGNET_COLOR, m);
    slotUniforms.uOpacity.value = assembly.slotBase + 3.2 * m;
  }
  if (piece.slotFade) {
    const t = Math.min(1, (now - piece.slotFade) / SNAP_MS);
    slotUniforms.uOpacity.value = Math.min(slotUniforms.uOpacity.value, 1 - t);
    if (t >= 1) piece.slot.visible = false;
    else animating = true;
  }
  for (const { mesh } of piece.members) setGlow(mesh.material, color, strength, fill);
  return animating;
}

/** Eases back to the whole-layout view after a hint zoomed in. */
function returnFromHint() {
  const overview = assembly?.overview;
  assembly.hintZoom = null;
  if (!overview || assembly.completeAt) return;
  animateCamera(overview.target.clone(), overview.position.clone(), 800);
}

function stepAssembly(now) {
  let animating = stepBursts(now);
  if (!assembly) return animating;
  for (const piece of assembly.pieces.values()) {
    const anim = piece.anim;
    if (anim && now >= anim.start) {
      const t = anim.duration > 0 ? Math.min(1, (now - anim.start) / anim.duration) : 1;
      const k = anim.ease ? anim.ease(t) : t;
      piece.pivot.position.lerpVectors(anim.fromPos, anim.pos, k);
      piece.pivot.quaternion.slerpQuaternions(anim.fromQuat, anim.quat, k);
      if (t >= 1) {
        piece.anim = null;
        anim.onDone?.();
      }
      animating = true;
    } else if (anim) {
      animating = true;
    }
    // Smoothly lift held pieces, then add the snap "pop" on top.
    const target = piece.held ? HELD_SCALE : 1;
    if (Math.abs(piece.scale - target) > 0.002) {
      piece.scale += (target - piece.scale) * 0.3;
      animating = true;
    } else {
      piece.scale = target;
    }
    let pop = 1;
    if (piece.pop) {
      const t = (now - piece.pop) / 320;
      if (t >= 1) piece.pop = 0;
      else {
        pop = 1 + 0.14 * Math.sin(Math.PI * t);
        animating = true;
      }
    }
    piece.pivot.scale.setScalar(piece.scale * pop);
    if (updatePieceVisual(piece, now)) animating = true;
  }
  return animating;
}

// ---- Assembly input ---------------------------------------------------------
// Capture-phase listeners run before OrbitControls' own (registered earlier on
// the same element), so a touch on a loose piece drags it instead of orbiting.

const canvas = renderer.domElement;
const dragPlane = new THREE.Plane();
const downPointers = new Set();

function rayFrom(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  pointer.set(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
  raycaster.setFromCamera(pointer, camera);
  return raycaster.ray;
}

/** Loose piece under the finger; small pieces get a forgiving touch radius. */
function pickPiece(clientX, clientY) {
  scene.updateMatrixWorld();
  const loose = [...assembly.pieces.values()].filter((p) => !p.snapped);
  rayFrom(clientX, clientY);
  const meshes = [];
  for (const p of loose) for (const m of p.members) meshes.push(m.mesh);
  const hit = raycaster.intersectObjects(meshes, false)[0];
  if (hit) return assembly.meshToPiece.get(hit.object);
  const rect = canvas.getBoundingClientRect();
  const x = clientX - rect.left, y = clientY - rect.top;
  let best = null, bestDist = Infinity;
  for (const p of loose) {
    const s = toScreen(p.pivot.position);
    const dist = Math.hypot(s.x - x, s.y - y);
    const reach = Math.max(22, projectedRadius(p.pivot.position, p.radius) * 0.6);
    if (dist < reach && dist < bestDist) {
      best = p;
      bestDist = dist;
    }
  }
  return best;
}

function dragPoint(e) {
  return rayFrom(e.clientX, e.clientY).intersectPlane(dragPlane, new THREE.Vector3());
}

canvas.addEventListener('pointerdown', (e) => {
  // A primary pointer starts a fresh gesture, so drop ids whose up we missed.
  if (e.isPrimary) downPointers.clear();
  downPointers.add(e.pointerId);
  // Only a single finger grabs; a second one belongs to pinch/orbit.
  if (!assembly || assembly.drag || assembly.completeAt || downPointers.size > 1) return;
  const piece = pickPiece(e.clientX, e.clientY);
  if (!piece) return;
  e.stopImmediatePropagation();
  e.preventDefault();
  canvas.setPointerCapture(e.pointerId);
  controls.enabled = false;
  piece.anim = null;
  piece.held = true;
  piece.magnet = 0;
  dragPlane.setFromNormalAndCoplanarPoint(camera.getWorldDirection(new THREE.Vector3()), piece.pivot.position);
  const hit = dragPoint(e) ?? piece.pivot.position.clone();
  assembly.drag = {
    piece,
    pointerId: e.pointerId,
    offset: piece.pivot.position.clone().sub(hit),
    fromPos: piece.pivot.position.clone(),
    fromQuat: piece.pivot.quaternion.clone(),
  };
  sfx.grab();
  requestRender();
  post({ type: 'pieceGrabbed', id: piece.id });
}, { capture: true });

canvas.addEventListener('pointermove', (e) => {
  const drag = assembly?.drag;
  if (!drag || e.pointerId !== drag.pointerId) return;
  e.stopImmediatePropagation();
  const hit = dragPoint(e);
  if (hit) {
    const piece = drag.piece;
    const raw = hit.add(drag.offset);
    // Magnet: inside MAGNET_RANGE x the snap radius, ease towards the slot.
    const s = toScreen(raw), home = toScreen(piece.home);
    const dist = Math.hypot(s.x - home.x, s.y - home.y);
    const snapPx = snapRadius(piece);
    const m = smoothstep(snapPx * MAGNET_RANGE, snapPx * 0.25, dist);
    if (m > 0 && piece.magnet === 0) sfx.magnet();
    piece.magnet = m;
    piece.pivot.position.copy(raw).lerp(piece.home, 0.5 * m);
  }
  requestRender();
}, { capture: true });

function onPointerEnd(e) {
  downPointers.delete(e.pointerId);
  const drag = assembly?.drag;
  if (!drag || e.pointerId !== drag.pointerId) return;
  e.stopImmediatePropagation();
  assembly.drag = null;
  controls.enabled = true;
  const piece = drag.piece;
  piece.held = false;
  piece.magnet = 0;
  requestRender();
  if (assembly.hintZoom === piece && performance.now() >= piece.hintUntil) {
    setTimeout(() => assembly?.hintZoom === piece && !piece.snapped && returnFromHint(), 600);
  }
  if (e.type === 'pointercancel') return;
  const at = toScreen(piece.pivot.position);
  const own = toScreen(piece.home);
  if (Math.hypot(at.x - own.x, at.y - own.y) <= snapRadius(piece)) {
    snapPiece(piece);
    return;
  }
  // Dropped on someone else's slot: bounce back to where it was picked up.
  let wrong = null, wrongDist = Infinity;
  for (const other of assembly.pieces.values()) {
    if (other === piece || other.snapped) continue;
    const s = toScreen(other.home);
    const dist = Math.hypot(at.x - s.x, at.y - s.y);
    if (dist <= snapRadius(other) && dist < wrongDist) {
      wrong = other;
      wrongDist = dist;
    }
  }
  if (!wrong) return;
  piece.glow = { color: WRONG_GLOW, start: performance.now(), duration: 700, peak: 0.9 };
  movePiece(piece, drag.fromPos, drag.fromQuat, 480, easeOutBack);
  sfx.wrong();
  post({ type: 'pieceWrong', id: piece.id, slotId: wrong.id });
}

canvas.addEventListener('pointerup', onPointerEnd, { capture: true });
canvas.addEventListener('pointercancel', onPointerEnd, { capture: true });

// ---- Commands from Flutter --------------------------------------------------

const commands = {
  async setSystemVisible(system, visible) {
    if (visible) await loadSystem(system);
    const entry = systems.get(system);
    if (!entry) return;
    entry.visible = visible;
    if (entry.group) entry.group.visible = visible;
    pipeline.shadow.markDirty();
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
  /** Moves the camera toward (factor < 1) or away from the orbit target. */
  zoomBy(factor) {
    // Start from where a running tween ends, so quick repeated taps compound.
    const target = (tween ? tween.target : controls.target).clone();
    const offset = (tween ? tween.position : camera.position).clone().sub(target);
    const distance = THREE.MathUtils.clamp(offset.length() * factor, controls.minDistance, controls.maxDistance);
    offset.setLength(distance);
    animateCamera(target, target.clone().add(offset), 260);
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
  // Assembly game. The level's systems must be visible (loaded) first.
  // Pieces are part ids or {id, parts: [ids]} rigid groups.
  assemblyStart(pieces, options = {}) {
    startAssembly(pieces, options ?? {});
  },
  assemblyHint(id = null) {
    showHint(id);
  },
  assemblyEnd() {
    endAssembly();
  },
  setSoundEnabled(enabled) {
    sfx.setEnabled(enabled !== false);
  },
  setQuality(level) {
    setQuality(level);
  },
};

// Commands run one after another, so e.g. a `focus` sent right after
// `setSystemVisible` waits until that system's model has loaded. Quality and
// sound settings skip the queue so they apply even while models load.
let queue = Promise.resolve();
const IMMEDIATE = new Set(['setSoundEnabled', 'setQuality']);

window.anatomy = {
  call(message) {
    const fn = commands[message.cmd];
    if (!fn) {
      post({ type: 'error', message: `Unknown command ${message.cmd}` });
      return;
    }
    if (IMMEDIATE.has(message.cmd)) {
      try {
        fn(...(message.args ?? []));
      } catch (err) {
        post({ type: 'error', message: String(err) });
      }
      return;
    }
    queue = queue
      .then(() => fn(...(message.args ?? [])))
      .catch((err) => post({ type: 'error', message: String(err) }));
  },
  /** Internals for automated tests and tuning; not part of the bridge API. */
  debug: { THREE, renderer, scene, camera, controls, pipeline, parts, requestRender: () => requestRender(), sfxState: () => (sfx.ctx ? `${sfx.ctx.state} enabled=${sfx.enabled}` : 'none') },
  /** Screen positions of assembly pieces and slots, for automated tests. */
  assemblyDebug() {
    if (!assembly) return [];
    scene.updateMatrixWorld();
    return [...assembly.pieces.values()].map((p) => ({
      id: p.id,
      snapped: p.snapped,
      piece: toScreen(p.pivot.position),
      slot: toScreen(p.home),
      snapPx: snapRadius(p),
    }));
  },
};

// ---- Render loop ------------------------------------------------------------

let renderRequested = true;
function requestRender() {
  renderRequested = true;
}

controls.addEventListener('change', requestRender);
// Once the player moves the camera, hints stop pulling it back to the overview.
controls.addEventListener('start', () => {
  if (assembly) assembly.hintZoom = null;
});
window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  pipeline.setSize();
  requestRender();
});

renderer.setAnimationLoop((now) => {
  // Bitwise OR so every step always runs.
  const animating = stepTween(now) | stepTour(now) | stepAssembly(now);
  controls.update();
  if (animating || renderRequested) {
    renderRequested = false;
    pipeline.renderActive(now);
  } else {
    pipeline.renderIdle(now);
  }
});

post({ type: 'ready' });
