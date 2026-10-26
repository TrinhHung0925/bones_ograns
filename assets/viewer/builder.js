// Creative bone builder ("Xếp xương sáng tạo"): pieces of the skeleton lie on
// a floor; the player drags them across it (they stack onto whatever is
// below), rotates them, then runs a physics sturdiness test. Physics, joints
// and scoring live in builder_physics.js; this module owns the scene, input
// and playback. Created by viewer.js with its shared rendering context.

import * as THREE from 'three';
import {
  HeightField, undersideProfile, worldSamples, shapeOf, touchingPairs, runSturdinessTest, scoreFor,
} from './builder_physics.js';

const SELECT_GLOW = new THREE.Color(0x4fb6ff);
const DRAG_GLOW = new THREE.Color(0x7a66ff);
const LIFT = 0.03;
const FLOOR_RADIUS = 1.6;
const MOVE_MS = 260;
/** Pieces whose centre is within this radius of the middle count as "placed". */
const BUILD_RADIUS = 0.32;

/**
 * Anatomical neighbours by piece id (the medium skeleton groups of
 * assembly_level.dart); their joints are stronger, and in the anatomical
 * reference they are always joined. `{s}` = right/left.
 */
const NEIGHBOUR_TEMPLATES = [
  ['g_skull', 'g_mandible'], ['g_skull', 'g_cervical'], ['g_cervical', 'g_thoracic'], ['g_thoracic', 'g_lumbar'],
  ['g_lumbar', 'g_pelvis'], ['g_thoracic', 'g_rib_cage'], ['g_rib_cage', 'g_clavicle_{s}'],
  ['g_clavicle_{s}', 'g_scapula_{s}'], ['g_scapula_{s}', 'g_rib_cage'], ['g_scapula_{s}', 'g_humerus_{s}'],
  ['g_humerus_{s}', 'g_forearm_{s}'], ['g_forearm_{s}', 'g_hand_{s}'], ['g_pelvis', 'g_femur_{s}'],
  ['g_femur_{s}', 'g_patella_{s}'], ['g_femur_{s}', 'g_leg_{s}'], ['g_patella_{s}', 'g_leg_{s}'], ['g_leg_{s}', 'g_foot_{s}'],
];
const NAMED_NEIGHBOURS = NEIGHBOUR_TEMPLATES.flatMap(([a, b]) =>
  a.includes('{s}') || b.includes('{s}')
    ? ['right', 'left'].map((side) => [a.replace('{s}', side), b.replace('{s}', side)])
    : [[a, b]]);

const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);

/** Floor disc with a fading grid, drawn under the contact shadow. */
function makeFloor(y) {
  const material = new THREE.ShaderMaterial({
    uniforms: { uRadius: { value: FLOOR_RADIUS } },
    vertexShader: `
      varying vec2 vXZ;
      void main() {
        vXZ = position.xz;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }`,
    fragmentShader: `
      uniform float uRadius;
      varying vec2 vXZ;
      float grid(float size, float width) {
        vec2 g = abs(fract(vXZ / size - 0.5) - 0.5) / fwidth(vXZ / size);
        return 1.0 - min(min(g.x, g.y) / width, 1.0);
      }
      void main() {
        float r = length(vXZ) / uRadius;
        float fade = 1.0 - smoothstep(0.55, 1.0, r);
        vec3 base = vec3(0.16, 0.13, 0.33);
        float build = 1.0 - smoothstep(0.30, 0.32, length(vXZ));
        vec3 col = base + vec3(0.1, 0.09, 0.2) * grid(0.1, 1.0) + vec3(0.18, 0.16, 0.35) * grid(0.5, 1.2);
        col += vec3(0.25, 0.2, 0.05) * build * 0.35;
        gl_FragColor = vec4(col, 0.92 * fade);
        #include <colorspace_fragment>
      }`,
    transparent: true,
    depthWrite: false,
  });
  const mesh = new THREE.Mesh(new THREE.CircleGeometry(FLOOR_RADIUS, 72).rotateX(-Math.PI / 2), material);
  mesh.position.y = y - 0.002;
  mesh.renderOrder = -2;
  mesh.userData.noAO = true;
  return mesh;
}

function extents(samples) {
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < samples.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      lo[k] = Math.min(lo[k], samples[i + k]);
      hi[k] = Math.max(hi[k], samples[i + k]);
    }
  }
  return [0, 1, 2].map((k) => hi[k] - lo[k]);
}

/** Orientation lying on its biggest face with the long side along x. */
function flatQuat(samples) {
  const e = extents(samples);
  const min = e.indexOf(Math.min(...e));
  const q = new THREE.Quaternion();
  if (min === 0) q.setFromAxisAngle(new THREE.Vector3(0, 0, 1), Math.PI / 2);
  else if (min === 2) q.setFromAxisAngle(new THREE.Vector3(1, 0, 0), Math.PI / 2);
  const r = extents(worldSamples(samples, [0, 0, 0], q.toArray()));
  if (r[2] > r[0]) q.premultiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.PI / 2));
  return q;
}

export function createBuilder(ctx) {
  const { scene, camera, controls, canvas, parts, pipeline, post, requestRender, burst, sfx, setGlow, applyVisual, animateCamera, rayFrom } = ctx;

  /** Active session, or null. */
  let game = null;

  function poseOf(piece) {
    return { pos: piece.pivot.position.clone(), quat: piece.pivot.quaternion.clone() };
  }

  function snapshot() {
    return game.pieces.map(poseOf);
  }

  function pushUndo() {
    game.undo = snapshot();
  }

  /** Posts builderChanged; [poses] = where pieces are heading (default: now). */
  function changed(poses = null) {
    let placed = 0;
    game.pieces.forEach((p, i) => {
      const pos = poses ? poses[i].pos : p.anim ? p.anim.pos : p.pivot.position;
      if (Math.hypot(pos.x, pos.z) <= BUILD_RADIUS) placed++;
    });
    post({ type: 'builderChanged', placed, canUndo: !!game.undo });
  }

  /** Tweens every piece to [poses] (array aligned with game.pieces). */
  function moveAll(poses, duration = 450) {
    game.pieces.forEach((p, i) => movePiece(p, poses[i].pos, poses[i].quat, duration));
  }

  function movePiece(piece, pos, quat, duration = MOVE_MS) {
    piece.anim = {
      fromPos: piece.pivot.position.clone(), fromQuat: piece.pivot.quaternion.clone(),
      pos: pos.clone(), quat: quat.clone(), start: performance.now(), duration,
    };
    requestRender();
  }

  function finishAnims() {
    for (const p of game.pieces) {
      if (!p.anim) continue;
      p.pivot.position.copy(p.anim.pos);
      p.pivot.quaternion.copy(p.anim.quat);
      p.anim = null;
    }
  }

  function samplesWorld(piece, pos = piece.pivot.position, quat = piece.pivot.quaternion) {
    return worldSamples(piece.shape.samples, pos.toArray(), quat.toArray());
  }

  /** Heightfield of every piece except [skip]. */
  function fieldWithout(skip) {
    const field = new HeightField();
    for (const p of game.pieces) {
      if (p === skip) continue;
      const pose = p.anim ? { pos: p.anim.pos, quat: p.anim.quat } : poseOf(p);
      field.add(samplesWorld(p, pose.pos, pose.quat));
    }
    return field;
  }

  function restingPose(piece, x, z, quat, field = fieldWithout(piece)) {
    const profile = undersideProfile(piece.shape.samples, quat.toArray());
    const y = field.restY(profile, x, z, game.floorY);
    return { pos: new THREE.Vector3(x, y, z), quat: quat.clone() };
  }

  function updateGlow() {
    for (const p of game.pieces) {
      const color = game.drag?.piece === p ? DRAG_GLOW : game.selected === p ? SELECT_GLOW : null;
      for (const m of p.members) setGlow(m.mesh.material, color, color ? 0.8 : 0, 0.3);
    }
    requestRender();
  }

  function select(piece) {
    if (game.selected === piece) return;
    game.selected = piece;
    updateGlow();
    post({ type: 'builderSelected', id: piece?.id ?? null });
  }

  /**
   * Pieces on two elliptic rings around the empty build area, lying flat,
   * long side pointing out. Deeper than wide, so it fits a portrait screen
   * seen from the front.
   */
  function startLayout() {
    const n = game.pieces.length;
    const order = [...game.pieces].sort((a, b) => b.shape.samples.length - a.shape.samples.length);
    const field = new HeightField();
    const poses = new Map();
    order.forEach((piece, k) => {
      // Stride through the slots so the biggest pieces end up far apart.
      const stride = [7, 9, 11, 5, 3].find((m) => n % m !== 0 && m < n) ?? 1;
      const a = (((k * stride) % n) / n) * Math.PI * 2 + 0.2;
      const outer = k % 2 === 0;
      const rx = outer ? 0.68 : 0.5, rz = outer ? 1.08 : 0.78;
      const x = Math.cos(a) * rx, z = Math.sin(a) * rz;
      const quat = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -Math.atan2(z, x)).multiply(piece.flat);
      const pose = restingPose(piece, x, z, quat, field);
      field.add(samplesWorld(piece, pose.pos, pose.quat));
      poses.set(piece, pose);
    });
    return game.pieces.map((p) => poses.get(p));
  }

  /** Camera seeing the whole layout from the front and above, for any aspect. */
  function frameFloor(duration) {
    const fov = THREE.MathUtils.degToRad(camera.fov) / 2;
    const tanV = Math.tan(fov), tanH = tanV * camera.aspect;
    const elev = THREE.MathUtils.degToRad(52);
    const dist = Math.max(1.1 / tanH, 1.25 / tanV) * 0.95;
    const target = new THREE.Vector3(0, game.floorY + 0.1, 0.05);
    const pos = target.clone().add(new THREE.Vector3(0, Math.sin(elev), Math.cos(elev)).multiplyScalar(dist));
    animateCamera(target, pos, duration);
  }

  function anatomicalLayout() {
    return game.pieces.map((p) => ({ pos: p.home.clone(), quat: new THREE.Quaternion() }));
  }

  /**
   * Metric of the anatomical reference: the same test, headless, on the
   * standing skeleton (home poses, neighbours always joined). Deterministic
   * (fixed step, fixed seed) and ~0.2 s, so it is computed once per session;
   * score = round(100 × metric / baseline). Pieces must be at home.
   */
  async function computeBaseline() {
    const r = await runSturdinessTest({
      pieces: game.pieces.map((p) => ({ id: p.id, object3d: p.pivot })),
      neighbours: game.neighbours, floorY: game.floorY, animate: false, seed: 1, forceNeighbours: true,
    });
    for (const p of game.pieces) {
      p.pivot.position.copy(p.home);
      p.pivot.quaternion.identity();
    }
    return r.metric;
  }

  /** [list]: [{id, name, partIds}] whose systems are already loaded. */
  async function start(list) {
    end(false);
    const used = new Set();
    const specs = [];
    for (const entry of list ?? []) {
      const members = [];
      for (const id of entry.partIds ?? entry.parts ?? []) {
        const part = parts.get(id);
        if (!part || used.has(id)) continue;
        used.add(id);
        members.push({ id, part });
      }
      if (members.length) specs.push({ id: String(entry.id), members });
    }
    for (const [id, part] of parts) {
      if (used.has(id)) continue;
      part.state = 'hidden';
      applyVisual(part);
    }
    if (specs.length === 0) {
      post({ type: 'error', message: 'Builder has no loaded parts' });
      return;
    }
    scene.updateMatrixWorld(true);
    const pieces = specs.map(({ id, members }) => {
      const box = new THREE.Box3();
      for (const { part } of members) box.expandByObject(part.mesh);
      const home = box.getCenter(new THREE.Vector3());
      const pivot = new THREE.Group();
      pivot.position.copy(home);
      scene.add(pivot);
      pivot.updateMatrixWorld(true);
      const piece = { id, pivot, home, members: [], shape: null, anim: null };
      for (const { id: partId, part } of members) {
        const { mesh } = part;
        piece.members.push({
          id: partId, part, mesh,
          original: { parent: mesh.parent, position: mesh.position.clone(), quaternion: mesh.quaternion.clone(), scale: mesh.scale.clone() },
        });
        pivot.attach(mesh);
        part.piece = piece;
        part.state = 'visible';
        applyVisual(part);
      }
      piece.shape = shapeOf(pivot);
      piece.flat = flatQuat(piece.shape.samples);
      return piece;
    });
    let floorY = Infinity;
    for (const p of pieces) {
      const s = p.shape.samples;
      for (let i = 1; i < s.length; i += 3) floorY = Math.min(floorY, s[i] + p.home.y);
    }
    const floor = makeFloor(floorY);
    scene.add(floor);
    game = {
      pieces, floorY, floor,
      neighbours: [],
      meshToPiece: new Map(pieces.flatMap((p) => p.members.map((m) => [m.mesh, p]))),
      selected: null, drag: null, undo: null, test: null, ball: null, preTest: null, down: null,
      polar: [controls.minPolarAngle, controls.maxPolarAngle],
    };
    controls.maxPolarAngle = 1.45;
    // Anatomical neighbours: the known skeleton pairs plus anything that
    // touches broadly (≥ 20 cm²) in the standing pose.
    const ids = new Set(pieces.map((p) => p.id));
    game.neighbours = [
      ...NAMED_NEIGHBOURS.filter(([a, b]) => ids.has(a) && ids.has(b)),
      ...touchingPairs(pieces.map((p) => ({ id: p.id, object3d: p.pivot })), 0.002),
    ];
    const session = game;
    const baseline = await computeBaseline();
    if (game !== session) return;
    game.baseline = baseline;
    game.startPoses = startLayout();
    moveAll(game.startPoses, 900);
    pipeline.shadow.markDirty();
    frameFloor(900);
    post({ type: 'builderReady', baseline: game.baseline, pieceCount: pieces.length });
    changed(game.startPoses);
  }

  /** Stops a running test (if any) and removes the ball; pieces stay where they are. */
  function stopTest() {
    if (!game?.test) return;
    game.test.aborted = true;
    game.test = null;
    if (game.ball) {
      scene.remove(game.ball);
      game.ball.geometry.dispose();
      game.ball.material.dispose();
      game.ball = null;
    }
    game.floor.position.x = game.floor.position.z = 0;
  }

  function end(resetView = true) {
    if (!game) return;
    stopTest();
    if (game.drag) controls.enabled = true;
    for (const piece of game.pieces) {
      for (const { mesh, original, part } of piece.members) {
        original.parent.add(mesh);
        mesh.position.copy(original.position);
        mesh.quaternion.copy(original.quaternion);
        mesh.scale.copy(original.scale);
        delete part.piece;
        setGlow(mesh.material, null);
      }
      scene.remove(piece.pivot);
    }
    scene.remove(game.floor);
    game.floor.geometry.dispose();
    game.floor.material.dispose();
    [controls.minPolarAngle, controls.maxPolarAngle] = game.polar;
    game = null;
    for (const part of parts.values()) {
      part.state = 'visible';
      applyVisual(part);
    }
    pipeline.shadow.markDirty();
    if (resetView) ctx.resetCamera();
    requestRender();
  }

  // ---- Editing commands -------------------------------------------------------

  const editable = () => game && !game.test && !game.drag;

  function rotate(axis, degrees) {
    if (!editable() || !game.selected) return;
    finishAnims();
    pushUndo();
    const piece = game.selected;
    const dir = new THREE.Vector3(axis === 'x' ? 1 : 0, axis === 'y' ? 1 : 0, axis === 'z' ? 1 : 0);
    const quat = new THREE.Quaternion().setFromAxisAngle(dir, THREE.MathUtils.degToRad(degrees)).multiply(piece.pivot.quaternion);
    const pose = restingPose(piece, piece.pivot.position.x, piece.pivot.position.z, quat);
    movePiece(piece, pose.pos, pose.quat);
    sfx.grab();
    changed();
  }

  function undo() {
    if (!editable() || !game.undo) return;
    finishAnims();
    const poses = game.undo;
    game.undo = null;
    moveAll(poses, 320);
    changed(poses);
  }

  function reset() {
    if (!game) return;
    stopTest();
    finishAnims();
    pushUndo();
    select(null);
    moveAll(game.startPoses, 700);
    frameFloor(700);
    sfx.whoosh();
    changed(game.startPoses);
  }

  function anatomical() {
    if (!game) return;
    stopTest();
    finishAnims();
    pushUndo();
    select(null);
    const poses = anatomicalLayout();
    moveAll(poses, 800);
    // Step back so the standing skeleton fits.
    const tanV = Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2);
    const target = new THREE.Vector3(0, game.floorY + 0.85, 0);
    const dist = Math.max(1.05 / tanV, 0.75 / (tanV * camera.aspect));
    animateCamera(target, target.clone().add(new THREE.Vector3(0, 0.35, 1).normalize().multiplyScalar(dist)), 800);
    sfx.whoosh();
    changed(poses);
  }

  /** After a test: back to the layout as it was before it. */
  function edit() {
    if (!game) return;
    stopTest();
    if (game.preTest) {
      moveAll(game.preTest, 500);
      changed(game.preTest);
    }
  }

  async function runTest() {
    if (!editable()) return;
    finishAnims();
    select(null);
    game.preTest = snapshot();
    const session = game;
    const run = { aborted: false, done: false, frames: 0 };
    game.test = run;
    const r = await runSturdinessTest({
      pieces: game.pieces.map((p) => ({ id: p.id, object3d: p.pivot })),
      neighbours: game.neighbours,
      floorY: game.floorY,
      animate: true,
      seed: 1,
      abort: () => run.aborted || game !== session,
      onPhase: (phase) => post({ type: 'builderTesting', phase }),
      onFrame: () => {
        if (++run.frames % 4 === 0) pipeline.shadow.markDirty();
        requestRender();
      },
      onFloor: (x, z) => {
        game.floor.position.x = x;
        game.floor.position.z = z;
      },
      onBreak: (at) => {
        burst(new THREE.Vector3().fromArray(at), 0.06, 0xffb347, 18, 600);
        sfx.crack(1);
      },
      onBall: ({ pos, quat, radius }) => {
        if (!game.ball) {
          game.ball = new THREE.Mesh(
            new THREE.SphereGeometry(radius, 32, 16),
            new THREE.MeshStandardMaterial({ color: 0x8b93a8, metalness: 0.85, roughness: 0.3 }),
          );
          scene.add(game.ball);
          sfx.whoosh();
        }
        game.ball.position.fromArray(pos);
        game.ball.quaternion.fromArray(quat);
      },
      onImpact: (at) => {
        sfx.thud();
        burst(new THREE.Vector3().fromArray(at), 0.12, 0xffd966, 30, 800);
      },
    });
    if (!r || game !== session || game.test !== run) return;
    run.done = true;
    pipeline.shadow.markDirty();
    post({ type: 'builderResult', score: scoreFor(r.metric, game.baseline), baseline: game.baseline, ...r });
  }

  // ---- Per-frame update ---------------------------------------------------------

  function step(now) {
    if (!game) return false;
    let animating = false;
    if (game.test && !game.test.done) animating = true;
    for (const p of game.pieces) {
      const a = p.anim;
      if (!a) continue;
      const t = Math.min(1, (now - a.start) / a.duration);
      const k = easeOutCubic(t);
      p.pivot.position.lerpVectors(a.fromPos, a.pos, k);
      p.pivot.quaternion.slerpQuaternions(a.fromQuat, a.quat, k);
      if (t >= 1) {
        p.anim = null;
        pipeline.shadow.markDirty();
      }
      animating = true;
    }
    return animating;
  }

  // ---- Input ----------------------------------------------------------------------

  const downPointers = new Set();
  const plane = new THREE.Plane();
  const raycaster = ctx.raycaster;

  function pickPiece(x, y) {
    scene.updateMatrixWorld();
    rayFrom(x, y);
    const meshes = game.pieces.flatMap((p) => p.members.map((m) => m.mesh));
    const hit = raycaster.intersectObjects(meshes, false)[0];
    return hit ? { piece: game.meshToPiece.get(hit.object), point: hit.point } : null;
  }

  function planePoint(e) {
    return rayFrom(e.clientX, e.clientY).intersectPlane(plane, new THREE.Vector3());
  }

  canvas.addEventListener('pointerdown', (e) => {
    if (e.isPrimary) downPointers.clear();
    downPointers.add(e.pointerId);
    if (!game) return;
    game.down = downPointers.size === 1 ? { x: e.clientX, y: e.clientY } : null;
    if (!editable() || downPointers.size > 1) return;
    const hit = pickPiece(e.clientX, e.clientY);
    if (!hit) return;
    e.stopImmediatePropagation();
    e.preventDefault();
    canvas.setPointerCapture(e.pointerId);
    controls.enabled = false;
    finishAnims();
    const piece = hit.piece;
    plane.set(new THREE.Vector3(0, 1, 0), -hit.point.y);
    game.drag = {
      piece, pointerId: e.pointerId, moved: false,
      undo: snapshot(),
      offset: piece.pivot.position.clone().sub(hit.point),
      from: poseOf(piece),
      field: fieldWithout(piece),
      profile: undersideProfile(piece.shape.samples, piece.pivot.quaternion.toArray()),
    };
    select(piece);
    updateGlow();
    sfx.grab();
  }, { capture: true });

  canvas.addEventListener('pointermove', (e) => {
    const drag = game?.drag;
    if (!drag || e.pointerId !== drag.pointerId) return;
    e.stopImmediatePropagation();
    if (!drag.moved && game.down && Math.hypot(e.clientX - game.down.x, e.clientY - game.down.y) < 6) return;
    drag.moved = true;
    const hit = planePoint(e);
    if (!hit) return;
    const p = hit.add(drag.offset);
    const r = Math.hypot(p.x, p.z);
    const max = FLOOR_RADIUS - 0.1;
    if (r > max) { p.x *= max / r; p.z *= max / r; }
    const y = drag.field.restY(drag.profile, p.x, p.z, game.floorY);
    drag.piece.pivot.position.set(p.x, y + LIFT, p.z);
    requestRender();
  }, { capture: true });

  function onPointerEnd(e) {
    downPointers.delete(e.pointerId);
    if (!game) return;
    const drag = game.drag;
    if (!drag || e.pointerId !== drag.pointerId) {
      // A tap on empty floor clears the selection.
      if (game.down && e.type === 'pointerup' && editable() &&
        Math.hypot(e.clientX - game.down.x, e.clientY - game.down.y) < 6 && !pickPiece(e.clientX, e.clientY)) {
        select(null);
      }
      game.down = null;
      return;
    }
    e.stopImmediatePropagation();
    game.drag = null;
    game.down = null;
    controls.enabled = true;
    const piece = drag.piece;
    if (drag.moved && e.type === 'pointerup') {
      game.undo = drag.undo;
      const p = piece.pivot.position;
      const y = drag.field.restY(drag.profile, p.x, p.z, game.floorY);
      movePiece(piece, new THREE.Vector3(p.x, y, p.z), piece.pivot.quaternion, 140);
      sfx.snap(1);
      changed();
    } else {
      movePiece(piece, drag.from.pos, drag.from.quat, 120);
    }
    updateGlow();
  }

  canvas.addEventListener('pointerup', onPointerEnd, { capture: true });
  canvas.addEventListener('pointercancel', onPointerEnd, { capture: true });

  return {
    get active() {
      return game !== null;
    },
    start, end, rotate, undo, reset, anatomical, edit, runTest, step,
    /** Piece pivots, for automated tests. */
    debugPieces: () => (game ? game.pieces.map((p) => ({ id: p.id, pivot: p.pivot })) : []),
  };
}
