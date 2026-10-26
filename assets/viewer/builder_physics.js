// Physics and scoring of the creative bone builder ("Xếp xương sáng tạo").
// Pure module: no DOM, no three.js scene, so the exact same code runs in the
// viewer and in a headless node harness (used to tune the constants below).
//
// Model
// - Every piece (a merged group of bone meshes) is described by surface
//   samples in its own local frame (the pivot at the piece's home bounding-box
//   centre, axes = body axes). The samples drive stacking (heightmap), contact
//   detection and the measurements; the rigid body uses a few tight boxes
//   fitted to the samples (compound shape), which keeps cannon-es fast.
// - Pieces that touch are glued by breakable lock constraints. A joint's
//   strength grows with the contact area; anatomical neighbours (femur–pelvis,
//   tibia–femur…) are stronger.
// - The sturdiness test is fully deterministic: fixed time step, fixed step
//   count, no wall-clock input, and a seeded PRNG for the quake phases. So
//   the same layout always gives the same result, on every device.
//
// Score (see `structureMetric` and `scoreFor`)
//   metric = U · H0 · K · (0.5 + 0.5·J) · C
//     U  share of all pieces in the main structure (largest glued cluster),
//        so leaving pieces out is never a cheap win;
//     H0 height of the main structure as built (metres);
//     K  height kept: the mean over the whole test of H(t)/H0 (capped at 1),
//        so a structure that stands longer keeps more of its height;
//     J  share of the main structure's joints that survive;
//     C  1 when the structure's centre of mass ends over its original floor
//        footprint, down to 0.6 the further it slid or toppled away.
//   score = round(100 · metric / baselineMetric), uncapped, where the
//   baseline is the same test run on the anatomical standing skeleton.

import * as CANNON from 'cannon-es';

/** Tunables. Change BUILDER_VERSION whenever a change alters results, so cached baselines are recomputed. */
export const BUILDER_VERSION = 1;

export const SIM = {
  dt: 1 / 60,
  iterations: 24,
  duration: 7.0,
  settleEnd: 1.2,
  /** Floor shake in growing steps: [start, end, amplitude (m)]. */
  quake: [
    [1.2, 2.2, 0.004],
    [2.2, 3.2, 0.008],
    [3.2, 4.2, 0.013],
  ],
  quakeHz: 2.5,
  ballAt: 4.4,
  ballRadius: 0.11,
  /** Ball mass as a share of the total mass of all pieces. */
  ballMassRatio: 0.35,
  ballDrop: 0.45,
  /** Mass per m² of bone surface (a shell of cortical bone a few mm thick). */
  surfaceDensity: 12,
  friction: 0.7,
  restitution: 0.05,
  maxSpeed: 7,
  maxSpin: 18,
  /** Height samples for K, every this many steps. */
  sampleEvery: 6,
  seed: 0x5eed,
};

/** Joint strength: force (N) per m² of contact, torque (N·m) per m³ (area^1.5). */
export const JOINT = {
  cell: 0.012,
  sigmaF: 2.4e6,
  sigmaT: 9.0e6,
  minArea: 4e-4,
  neighbourBonus: 1.6,
  /** Steps a joint must stay overloaded before it cracks (filters solver noise)… */
  overSteps: 2,
  /** …unless a single step overloads it this much (a hard impact). */
  snapLoad: 1.6,
};

export const SAMPLE_CELL = 0.008;
export const FLOOR_CONTACT = 0.015;

// ---- Small maths -------------------------------------------------------------

/** Deterministic PRNG (mulberry32). */
export function prng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const clamp = (x, a, b) => Math.min(b, Math.max(a, x));

/** Rotates (x,y,z) by quaternion q = [x,y,z,w] into out[o..o+2]. */
function rotate(q, x, y, z, out, o) {
  const qx = q[0], qy = q[1], qz = q[2], qw = q[3];
  const tx = 2 * (qy * z - qz * y);
  const ty = 2 * (qz * x - qx * z);
  const tz = 2 * (qx * y - qy * x);
  out[o] = x + qw * tx + (qy * tz - qz * ty);
  out[o + 1] = y + qw * ty + (qz * tx - qx * tz);
  out[o + 2] = z + qw * tz + (qx * ty - qy * tx);
}

/** Local samples to world for pose (pos, quat). */
export function worldSamples(samples, pos, quat, out = new Float32Array(samples.length)) {
  for (let i = 0; i < samples.length; i += 3) {
    rotate(quat, samples[i], samples[i + 1], samples[i + 2], out, i);
    out[i] += pos[0];
    out[i + 1] += pos[1];
    out[i + 2] += pos[2];
  }
  return out;
}

const voxKey = (ix, iy, iz) => ((ix + 1024) * 2048 + (iy + 1024)) * 2048 + (iz + 1024);

// ---- Shape preparation -----------------------------------------------------

/**
 * Surface samples of a piece in its local frame, about one per SAMPLE_CELL³
 * voxel: every vertex plus points filling large triangles.
 * [meshes]: [{ position: Float32Array (xyz), index: Uint32Array|Uint16Array|null,
 *              matrix: number[16] (column-major, mesh → piece local) }].
 */
export function sampleSurface(meshes, cell = SAMPLE_CELL) {
  const seen = new Map();
  const inv = 1 / cell;
  const add = (x, y, z) => {
    const k = voxKey(Math.floor(x * inv), Math.floor(y * inv), Math.floor(z * inv));
    if (!seen.has(k)) seen.set(k, [x, y, z]);
  };
  const v = new Float64Array(9);
  for (const { position, index, matrix: m } of meshes) {
    const count = position.length / 3;
    const tx = new Float32Array(position.length);
    for (let i = 0; i < count; i++) {
      const x = position[i * 3], y = position[i * 3 + 1], z = position[i * 3 + 2];
      tx[i * 3] = m[0] * x + m[4] * y + m[8] * z + m[12];
      tx[i * 3 + 1] = m[1] * x + m[5] * y + m[9] * z + m[13];
      tx[i * 3 + 2] = m[2] * x + m[6] * y + m[10] * z + m[14];
      add(tx[i * 3], tx[i * 3 + 1], tx[i * 3 + 2]);
    }
    const tris = index ? index.length / 3 : count / 3;
    for (let t = 0; t < tris; t++) {
      for (let c = 0; c < 3; c++) {
        const vi = index ? index[t * 3 + c] : t * 3 + c;
        v[c * 3] = tx[vi * 3]; v[c * 3 + 1] = tx[vi * 3 + 1]; v[c * 3 + 2] = tx[vi * 3 + 2];
      }
      const e0 = Math.hypot(v[3] - v[0], v[4] - v[1], v[5] - v[2]);
      const e1 = Math.hypot(v[6] - v[3], v[7] - v[4], v[8] - v[5]);
      const e2 = Math.hypot(v[0] - v[6], v[1] - v[7], v[2] - v[8]);
      const n = Math.ceil(Math.max(e0, e1, e2) / cell);
      if (n < 2) continue;
      for (let i = 0; i <= n; i++) {
        for (let j = 0; i + j <= n; j++) {
          const a = i / n, b = j / n, c = 1 - a - b;
          add(
            v[0] * a + v[3] * b + v[6] * c,
            v[1] * a + v[4] * b + v[7] * c,
            v[2] * a + v[5] * b + v[8] * c,
          );
        }
      }
    }
  }
  const out = new Float32Array(seen.size * 3);
  let o = 0;
  // Map iteration follows insertion order, which is deterministic.
  for (const p of seen.values()) {
    out[o++] = p[0]; out[o++] = p[1]; out[o++] = p[2];
  }
  return out;
}

/**
 * Compound collision shape: the piece's local bounding box cut into up to 6
 * cells along its long axes, each replaced by the tight box of its samples.
 * Returns { boxes: [{c:[x,y,z], h:[x,y,z]}], mass, volume }; the mass
 * follows the surface area (samples are about one per SAMPLE_CELL²).
 */
export function buildBoxes(samples) {
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < samples.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      lo[k] = Math.min(lo[k], samples[i + k]);
      hi[k] = Math.max(hi[k], samples[i + k]);
    }
  }
  const ext = [0, 1, 2].map((k) => Math.max(hi[k] - lo[k], 1e-3));
  const minE = Math.max(Math.min(...ext), 0.02);
  const div = ext.map((e) => clamp(Math.round(e / (minE * 1.6)), 1, 3));
  while (div[0] * div[1] * div[2] > 6) {
    const k = div.indexOf(Math.max(...div));
    div[k]--;
  }
  const cells = new Map();
  const n = samples.length / 3;
  for (let i = 0; i < samples.length; i += 3) {
    let key = 0;
    for (let k = 0; k < 3; k++) {
      const c = clamp(Math.floor(((samples[i + k] - lo[k]) / ext[k]) * div[k]), 0, div[k] - 1);
      key = key * 4 + c;
    }
    let cell = cells.get(key);
    if (!cell) {
      cell = { lo: [Infinity, Infinity, Infinity], hi: [-Infinity, -Infinity, -Infinity], n: 0 };
      cells.set(key, cell);
    }
    cell.n++;
    for (let k = 0; k < 3; k++) {
      cell.lo[k] = Math.min(cell.lo[k], samples[i + k]);
      cell.hi[k] = Math.max(cell.hi[k], samples[i + k]);
    }
  }
  const boxes = [];
  let volume = 0;
  for (const cell of [...cells.entries()].sort((a, b) => a[0] - b[0]).map((e) => e[1])) {
    // Stray slivers (a few samples) would add useless boxes.
    if (cell.n < Math.max(4, n * 0.015)) continue;
    const h = [0, 1, 2].map((k) => Math.max((cell.hi[k] - cell.lo[k]) / 2, 0.008));
    const c = [0, 1, 2].map((k) => (cell.hi[k] + cell.lo[k]) / 2);
    boxes.push({ c, h });
    volume += 8 * h[0] * h[1] * h[2];
  }
  if (boxes.length === 0) {
    const h = ext.map((e) => Math.max(e / 2, 0.008));
    boxes.push({ c: [0, 1, 2].map((k) => (hi[k] + lo[k]) / 2), h });
    volume = 8 * h[0] * h[1] * h[2];
  }
  const area = n * SAMPLE_CELL * SAMPLE_CELL;
  return { boxes, volume, mass: Math.max(0.05, area * SIM.surfaceDensity) };
}

// ---- Stacking ---------------------------------------------------------------
// Pieces are dropped straight down onto whatever is below: a heightfield of
// the other pieces' surface samples (max y per floor cell) against the
// dropped piece's underside.

export const STACK_CELL = 0.015;

/** Max surface height per (x, z) cell of a set of pieces. */
export class HeightField {
  constructor(cell = STACK_CELL) {
    this.cell = cell;
    this.inv = 1 / cell;
    this.map = new Map();
  }

  /** Adds world-space samples (flat xyz array). */
  add(world) {
    const inv = this.inv;
    for (let i = 0; i < world.length; i += 3) {
      const k = (Math.floor(world[i] * inv) + 32768) * 65536 + (Math.floor(world[i + 2] * inv) + 32768);
      const y = world[i + 1];
      const old = this.map.get(k);
      if (old === undefined || y > old) this.map.set(k, y);
    }
  }

  /**
   * Lowest pivot height at (x, z) for a piece whose underside is [profile]
   * (pivot-relative xyz, see `undersideProfile`) so it rests on the field or
   * on the floor at [floorY].
   */
  restY(profile, x, z, floorY) {
    const inv = this.inv;
    let y = -Infinity;
    for (let i = 0; i < profile.length; i += 3) {
      const dy = profile[i + 1];
      y = Math.max(y, floorY - dy);
      const k = (Math.floor((x + profile[i]) * inv) + 32768) * 65536 + (Math.floor((z + profile[i + 2]) * inv) + 32768);
      const top = this.map.get(k);
      if (top !== undefined && top - dy > y) y = top - dy;
    }
    return y;
  }
}

/**
 * Underside of a piece in orientation [quat]: per half-cell column (around
 * the pivot) the lowest sample, as pivot-relative xyz. Enough for `restY`.
 */
export function undersideProfile(samples, quat, cell = STACK_CELL / 2) {
  const rot = worldSamples(samples, [0, 0, 0], quat);
  const inv = 1 / cell;
  const low = new Map();
  for (let i = 0; i < rot.length; i += 3) {
    const k = (Math.floor(rot[i] * inv) + 32768) * 65536 + (Math.floor(rot[i + 2] * inv) + 32768);
    const old = low.get(k);
    if (old === undefined || rot[i + 1] < rot[old + 1]) low.set(k, i);
  }
  const out = new Float32Array(low.size * 3);
  let o = 0;
  for (const i of low.values()) {
    out[o++] = rot[i]; out[o++] = rot[i + 1]; out[o++] = rot[i + 2];
  }
  return out;
}

// ---- Contacts and joints -----------------------------------------------------

/** Voxel set (cell JOINT.cell) and bounds of world samples. */
function voxelize(world) {
  const inv = 1 / JOINT.cell;
  const set = new Set();
  const list = [];
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < world.length; i += 3) {
    const ix = Math.floor(world[i] * inv), iy = Math.floor(world[i + 1] * inv), iz = Math.floor(world[i + 2] * inv);
    const k = voxKey(ix, iy, iz);
    if (set.has(k)) continue;
    set.add(k);
    list.push(ix, iy, iz);
    lo[0] = Math.min(lo[0], ix); lo[1] = Math.min(lo[1], iy); lo[2] = Math.min(lo[2], iz);
    hi[0] = Math.max(hi[0], ix); hi[1] = Math.max(hi[1], iy); hi[2] = Math.max(hi[2], iz);
  }
  return { set, list, lo, hi };
}

/** Voxels of [a] with a voxel of [b] within [r] cells; returns count and their centroid (cells). */
function touching(a, b, r) {
  let count = 0, sx = 0, sy = 0, sz = 0;
  const L = a.list;
  for (let i = 0; i < L.length; i += 3) {
    const x = L[i], y = L[i + 1], z = L[i + 2];
    if (x < b.lo[0] - r || x > b.hi[0] + r || y < b.lo[1] - r || y > b.hi[1] + r || z < b.lo[2] - r || z > b.hi[2] + r) continue;
    let hit = false;
    for (let dx = -r; dx <= r && !hit; dx++) {
      for (let dy = -r; dy <= r && !hit; dy++) {
        for (let dz = -r; dz <= r; dz++) {
          if (b.set.has(voxKey(x + dx, y + dy, z + dz))) { hit = true; break; }
        }
      }
    }
    if (hit) { count++; sx += x; sy += y; sz += z; }
  }
  return { count, c: count ? [sx / count, sy / count, sz / count] : null };
}

/** World-space oriented boxes of a piece: [{c, axes:[[3],[3],[3]], h}]. */
function worldBoxes(piece) {
  const q = piece.quat;
  const axes = [[1, 0, 0], [0, 1, 0], [0, 0, 1]].map(([x, y, z]) => {
    const o = [0, 0, 0];
    rotate(q, x, y, z, o, 0);
    return o;
  });
  return piece.shape.boxes.map(({ c, h }) => {
    const w = [0, 0, 0];
    rotate(q, c[0], c[1], c[2], w, 0);
    return { c: [w[0] + piece.pos[0], w[1] + piece.pos[1], w[2] + piece.pos[2]], axes, h };
  });
}

const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];

/** Separating-axis test of two oriented boxes, with [margin] of slack. */
function obbOverlap(A, B, margin) {
  const d = [B.c[0] - A.c[0], B.c[1] - A.c[1], B.c[2] - A.c[2]];
  const axes = [...A.axes, ...B.axes];
  for (const a of A.axes) for (const b of B.axes) {
    const c = cross(a, b);
    if (dot(c, c) > 1e-8) axes.push(c);
  }
  for (const ax of axes) {
    const len = Math.sqrt(dot(ax, ax));
    const ra = A.h[0] * Math.abs(dot(A.axes[0], ax)) + A.h[1] * Math.abs(dot(A.axes[1], ax)) + A.h[2] * Math.abs(dot(A.axes[2], ax));
    const rb = B.h[0] * Math.abs(dot(B.axes[0], ax)) + B.h[1] * Math.abs(dot(B.axes[1], ax)) + B.h[2] * Math.abs(dot(B.axes[2], ax));
    if (Math.abs(dot(d, ax)) > ra + rb - margin * len) return false;
  }
  return true;
}

const pairKey = (a, b) => (a < b ? `${a}|${b}` : `${b}|${a}`);

/**
 * Joints of a layout. [pieces]: [{id, shape:{samples, boxes}, pos, quat}].
 * A pair is joined when their surfaces touch (within a voxel; two for
 * anatomical neighbours) or their collision boxes overlap. With
 * [forceNeighbours] (the anatomical reference) every neighbour pair is
 * joined. Returns [{a, b, area, neighbour, pivot:[x,y,z], fmax, tmax}].
 */
export function detectJoints(pieces, neighbours = [], { forceNeighbours = false } = {}) {
  const nset = new Set(neighbours.map(([a, b]) => pairKey(a, b)));
  const vox = pieces.map((p) => voxelize(worldSamples(p.shape.samples, p.pos, p.quat)));
  const boxes = pieces.map(worldBoxes);
  const joints = [];
  for (let i = 0; i < pieces.length; i++) {
    for (let j = i + 1; j < pieces.length; j++) {
      const A = vox[i], B = vox[j];
      const neighbour = nset.has(pairKey(pieces[i].id, pieces[j].id));
      const r = neighbour ? 2 : 1;
      const apart = A.hi[0] + r < B.lo[0] || B.hi[0] + r < A.lo[0] || A.hi[1] + r < B.lo[1] ||
        B.hi[1] + r < A.lo[1] || A.hi[2] + r < B.lo[2] || B.hi[2] + r < A.lo[2];
      let area = 0;
      let pivot = null;
      if (!apart) {
        const ab = touching(A, B, r);
        const ba = touching(B, A, r);
        area = Math.min(ab.count, ba.count) * JOINT.cell * JOINT.cell;
        if (ab.c && ba.c) pivot = [0, 1, 2].map((k) => ((ab.c[k] + ba.c[k]) / 2 + 0.5) * JOINT.cell);
      }
      let overlap = false;
      if (area === 0) {
        outer: for (const a of boxes[i]) for (const b of boxes[j]) {
          if (obbOverlap(a, b, 0.002)) { overlap = true; break outer; }
        }
      }
      if (area === 0 && !overlap && !(forceNeighbours && neighbour)) continue;
      if (!pivot) pivot = [0, 1, 2].map((k) => (pieces[i].pos[k] + pieces[j].pos[k]) / 2);
      const eff = Math.max(area, JOINT.minArea);
      const bonus = neighbour ? JOINT.neighbourBonus : 1;
      joints.push({
        a: i, b: j, area, neighbour, pivot,
        fmax: JOINT.sigmaF * eff * bonus,
        tmax: JOINT.sigmaT * Math.pow(eff, 1.5) * bonus,
      });
    }
  }
  return joints;
}

/** Largest glued cluster (by piece count, then mass): indices. */
function mainCluster(n, joints, masses) {
  const parent = [...Array(n).keys()];
  const find = (x) => (parent[x] === x ? x : (parent[x] = find(parent[x])));
  for (const j of joints) parent[find(j.a)] = find(j.b);
  const groups = new Map();
  for (let i = 0; i < n; i++) {
    const r = find(i);
    if (!groups.has(r)) groups.set(r, []);
    groups.get(r).push(i);
  }
  let best = null, bestKey = -1;
  for (const g of groups.values()) {
    const key = g.length * 1e6 + g.reduce((s, i) => s + masses[i], 0);
    if (key > bestKey) { bestKey = key; best = g; }
  }
  return best ?? [];
}

/** Convex hull (xz) by monotone chain; points as [[x,z]]. */
function hull2(points) {
  const p = [...points].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (p.length < 3) return p;
  const crossZ = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [], upper = [];
  for (const q of p) {
    while (lower.length >= 2 && crossZ(lower[lower.length - 2], lower[lower.length - 1], q) <= 0) lower.pop();
    lower.push(q);
  }
  for (let i = p.length - 1; i >= 0; i--) {
    const q = p[i];
    while (upper.length >= 2 && crossZ(upper[upper.length - 2], upper[upper.length - 1], q) <= 0) upper.pop();
    upper.push(q);
  }
  return lower.slice(0, -1).concat(upper.slice(0, -1));
}

/** Distance from (x,z) to outside a convex polygon; 0 when inside. */
function outsideDistance(poly, x, z) {
  if (poly.length === 0) return Infinity;
  if (poly.length < 3) {
    return Math.min(...poly.map(([px, pz]) => Math.hypot(px - x, pz - z)));
  }
  let inside = true;
  let best = Infinity;
  for (let i = 0; i < poly.length; i++) {
    const [ax, az] = poly[i], [bx, bz] = poly[(i + 1) % poly.length];
    if ((bx - ax) * (z - az) - (bz - az) * (x - ax) < 0) inside = false;
    const ex = bx - ax, ez = bz - az;
    const t = clamp(((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez || 1), 0, 1);
    best = Math.min(best, Math.hypot(ax + ex * t - x, az + ez * t - z));
  }
  return inside ? 0 : best;
}

// ---- The sturdiness test -----------------------------------------------------

/**
 * One run of the test. Create it, call step() until `done` (each call is one
 * fixed step), then read `metrics`. `frames[k]` holds the poses after step k
 * (pieces, then the ball, then the floor offset) for playback.
 *
 * [pieces]: [{id, shape:{samples, boxes, mass}, pos:[3], quat:[4]}].
 */
export class StructureTest {
  constructor(pieces, { floorY, neighbours = [], forceNeighbours = false, record = true } = {}) {
    this.pieces = pieces;
    this.floorY = floorY;
    this.record = record;
    this.stepIndex = 0;
    this.totalSteps = Math.round(SIM.duration / SIM.dt);
    this.done = false;
    this.impactStep = -1;
    this.frames = [];
    this.rand = prng(SIM.seed);
    this.quakePhase = [this.rand() * Math.PI * 2, this.rand() * Math.PI * 2];

    const world = new CANNON.World({ gravity: new CANNON.Vec3(0, -9.81, 0) });
    world.broadphase = new CANNON.SAPBroadphase(world);
    world.solver.iterations = SIM.iterations;
    world.defaultContactMaterial.friction = SIM.friction;
    world.defaultContactMaterial.restitution = SIM.restitution;
    world.allowSleep = false;
    this.world = world;

    const floor = new CANNON.Body({ type: CANNON.Body.KINEMATIC, mass: 0 });
    floor.addShape(new CANNON.Plane());
    floor.quaternion.setFromEuler(-Math.PI / 2, 0, 0);
    floor.position.set(0, floorY, 0);
    world.addBody(floor);
    this.floor = floor;

    this.totalMass = 0;
    this.bodies = pieces.map((p) => {
      const body = new CANNON.Body({ mass: p.shape.mass, linearDamping: 0.04, angularDamping: 0.08 });
      for (const { c, h } of p.shape.boxes) {
        body.addShape(new CANNON.Box(new CANNON.Vec3(h[0], h[1], h[2])), new CANNON.Vec3(c[0], c[1], c[2]));
      }
      body.position.set(p.pos[0], p.pos[1], p.pos[2]);
      body.quaternion.set(p.quat[0], p.quat[1], p.quat[2], p.quat[3]);
      world.addBody(body);
      this.totalMass += p.shape.mass;
      return body;
    });

    this.joints = detectJoints(pieces, neighbours, { forceNeighbours });
    const tmpA = new CANNON.Vec3(), tmpB = new CANNON.Vec3();
    for (const j of this.joints) {
      const A = this.bodies[j.a], B = this.bodies[j.b];
      const c = new CANNON.LockConstraint(A, B);
      // Glue at the contact patch rather than half-way between the centres.
      const p = new CANNON.Vec3(j.pivot[0], j.pivot[1], j.pivot[2]);
      A.pointToLocalFrame(p, tmpA);
      B.pointToLocalFrame(p, tmpB);
      c.pivotA.copy(tmpA);
      c.pivotB.copy(tmpB);
      c.collideConnected = false;
      world.addConstraint(c);
      j.constraint = c;
      j.broken = false;
      j.brokenStep = -1;
      j.over = 0;
    }

    this.ball = null;
    this.ballMass = SIM.ballMassRatio * this.totalMass;

    // Measurements as built.
    const masses = pieces.map((p) => p.shape.mass);
    this.main = mainCluster(pieces.length, this.joints, masses);
    this.mainSet = new Set(this.main);
    this.mainJoints = this.joints.filter((j) => this.mainSet.has(j.a) && this.mainSet.has(j.b));
    const support = [];
    let top = -Infinity;
    for (const i of this.main) {
      const w = worldSamples(pieces[i].shape.samples, pieces[i].pos, pieces[i].quat);
      for (let k = 0; k < w.length; k += 3) {
        top = Math.max(top, w[k + 1]);
        if (w[k + 1] < floorY + FLOOR_CONTACT) support.push([w[k], w[k + 2]]);
      }
    }
    this.h0 = Math.max(top - floorY, 0.01);
    this.supportHull = hull2(support);
    this.heightSum = 0;
    this.heightCount = 0;
    this._sampleHeight();
    this._recordFrame();
  }

  /** Floor x/z offset at time t: growing sinusoidal steps, zero between stages. */
  floorOffset(t) {
    let x = 0, z = 0;
    for (const [a, b, amp] of SIM.quake) {
      if (t < a || t > b) continue;
      const u = t - a;
      // Fade in/out over 0.15 s so the floor never jerks.
      const env = Math.min(1, u / 0.15, (b - t) / 0.15);
      const w = 2 * Math.PI * SIM.quakeHz;
      x = amp * env * Math.sin(w * u + this.quakePhase[0]) ;
      z = 0.6 * amp * env * Math.sin(w * 1.27 * u + this.quakePhase[1]);
    }
    return [x, z];
  }

  get time() {
    return this.stepIndex * SIM.dt;
  }

  /** Current phase: 'settle' | 'quake' | 'ball' | 'done'. */
  get phase() {
    const t = this.time;
    if (this.done) return 'done';
    if (t < SIM.settleEnd) return 'settle';
    if (t < SIM.ballAt) return 'quake';
    return 'ball';
  }

  /** Top of the main structure above the floor (m). */
  _height() {
    let top = -Infinity;
    const q = [0, 0, 0, 1], p = [0, 0, 0];
    for (const i of this.main) {
      const b = this.bodies[i];
      q[0] = b.quaternion.x; q[1] = b.quaternion.y; q[2] = b.quaternion.z; q[3] = b.quaternion.w;
      p[0] = b.position.x; p[1] = b.position.y; p[2] = b.position.z;
      const s = this.pieces[i].shape.samples;
      // The top is decided by the highest samples; checking every one is cheap enough.
      for (let k = 0; k < s.length; k += 3) {
        const x = s[k], y = s[k + 1], z = s[k + 2];
        const ty = 2 * (q[2] * x - q[0] * z);
        const tx = 2 * (q[1] * z - q[2] * y);
        const tz = 2 * (q[0] * y - q[1] * x);
        const wy = y + q[3] * ty + (q[2] * tx - q[0] * tz) + p[1];
        if (wy > top) top = wy;
      }
    }
    return Math.max(0, top - this.floorY);
  }

  _sampleHeight() {
    this.heightSum += Math.min(1, this._height() / this.h0);
    this.heightCount++;
  }

  _recordFrame() {
    if (!this.record) return;
    const n = this.bodies.length;
    const f = new Float32Array((n + 1) * 7 + 2);
    for (let i = 0; i < n; i++) {
      const b = this.bodies[i];
      f.set([b.position.x, b.position.y, b.position.z, b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w], i * 7);
    }
    const ball = this.ball;
    if (ball) {
      f.set([ball.position.x, ball.position.y, ball.position.z, ball.quaternion.x, ball.quaternion.y, ball.quaternion.z, ball.quaternion.w], n * 7);
    } else {
      f.set([0, -1000, 0, 0, 0, 0, 1], n * 7);
    }
    f[(n + 1) * 7] = this.floor.position.x;
    f[(n + 1) * 7 + 1] = this.floor.position.z;
    this.frames.push(f);
  }

  _spawnBall() {
    // Above the highest point of the main structure.
    let best = null;
    const q = [0, 0, 0, 1], p = [0, 0, 0];
    for (const i of this.main) {
      const b = this.bodies[i];
      q[0] = b.quaternion.x; q[1] = b.quaternion.y; q[2] = b.quaternion.z; q[3] = b.quaternion.w;
      p[0] = b.position.x; p[1] = b.position.y; p[2] = b.position.z;
      const w = worldSamples(this.pieces[i].shape.samples, p, q);
      for (let k = 0; k < w.length; k += 3) {
        if (!best || w[k + 1] > best[1]) best = [w[k], w[k + 1], w[k + 2]];
      }
    }
    best ??= [0, this.floorY, 0];
    const ball = new CANNON.Body({ mass: this.ballMass, linearDamping: 0.01 });
    ball.addShape(new CANNON.Sphere(SIM.ballRadius));
    ball.position.set(best[0], best[1] + SIM.ballRadius + SIM.ballDrop, best[2]);
    this.world.addBody(ball);
    this.ball = ball;
  }

  /** Advances one fixed step; returns the joints that broke during it. */
  step() {
    if (this.done) return [];
    const dt = SIM.dt;
    const t = this.time;
    // Kinematic floor: velocity that lands exactly on next step's offset.
    const [nx, nz] = this.floorOffset(t + dt);
    this.floor.velocity.set((nx - this.floor.position.x) / dt, 0, (nz - this.floor.position.z) / dt);
    if (!this.ball && t + 1e-9 >= SIM.ballAt) this._spawnBall();

    this.world.step(dt);
    this.stepIndex++;

    for (const b of this.bodies) {
      const v = b.velocity.length();
      if (v > SIM.maxSpeed) b.velocity.scale(SIM.maxSpeed / v, b.velocity);
      const w = b.angularVelocity.length();
      if (w > SIM.maxSpin) b.angularVelocity.scale(SIM.maxSpin / w, b.angularVelocity);
    }

    const broke = [];
    for (const j of this.joints) {
      if (j.broken) continue;
      const c = j.constraint;
      const f = Math.hypot(c.equationX.multiplier, c.equationY.multiplier, c.equationZ.multiplier);
      const tq = Math.hypot(c.rotationalEquation1.multiplier, c.rotationalEquation2.multiplier, c.rotationalEquation3.multiplier);
      j.load = Math.max(f / j.fmax, tq / j.tmax);
      j.over = j.load > 1 ? j.over + 1 : 0;
      if (j.over >= JOINT.overSteps || j.load > JOINT.snapLoad) {
        this.world.removeConstraint(c);
        j.broken = true;
        j.brokenStep = this.stepIndex;
        // Where the crack shows: the glue point, carried by body A.
        const p = new CANNON.Vec3();
        this.bodies[j.a].pointToWorldFrame(c.pivotA, p);
        j.crackAt = [p.x, p.y, p.z];
        broke.push(j);
      }
    }

    if (this.ball && this.impactStep < 0) {
      for (const c of this.world.contacts) {
        const other = c.bi === this.ball ? c.bj : c.bj === this.ball ? c.bi : null;
        if (other && other !== this.floor) {
          this.impactStep = this.stepIndex;
          break;
        }
      }
    }

    if (this.stepIndex % SIM.sampleEvery === 0) this._sampleHeight();
    this._recordFrame();
    if (this.stepIndex >= this.totalSteps) this._finish();
    return broke;
  }

  /** Runs to the end (used for the baseline); returns the metrics. */
  runToEnd() {
    while (!this.done) this.step();
    return this.metrics;
  }

  _finish() {
    this.done = true;
    const n = this.pieces.length;
    const hEnd = this._height();
    const K = this.heightSum / Math.max(1, this.heightCount);
    const survived = this.mainJoints.filter((j) => !j.broken).length;
    const J = this.mainJoints.length ? survived / this.mainJoints.length : 1;
    let mx = 0, mz = 0, m = 0;
    for (const i of this.main) {
      const b = this.bodies[i];
      mx += b.position.x * b.mass;
      mz += b.position.z * b.mass;
      m += b.mass;
    }
    mx /= m || 1;
    mz /= m || 1;
    // A little slack: the footprint hull is sampled.
    const d = Math.max(0, outsideDistance(this.supportHull, mx, mz) - 0.03);
    const C = d === 0 ? 1 : clamp(1 - 1.5 * d, 0.6, 1);
    const U = this.main.length / Math.max(1, n);
    this.metrics = {
      U, H0: this.h0, hEnd, K, J, C,
      joints: this.mainJoints.length,
      broken: this.mainJoints.length - survived,
      used: this.main.length,
      pieces: n,
      metric: structureMetric({ U, H0: this.h0, K, J, C }),
    };
  }

  dispose() {
    for (const j of this.joints) if (!j.broken) this.world.removeConstraint(j.constraint);
    for (const b of [...this.world.bodies]) this.world.removeBody(b);
    this.bodies = [];
    this.frames = [];
  }
}

/** The structure's metric (see the header comment). */
export function structureMetric({ U, H0, K, J, C }) {
  return U * H0 * K * (0.5 + 0.5 * J) * C;
}

/** Score relative to the anatomical baseline; 100 = the standing skeleton. No cap. */
export function scoreFor(metric, baseline) {
  if (!(baseline > 0)) return 0;
  return Math.round((100 * metric) / baseline);
}

/** Short signature of the pieces' shapes, so a cached baseline is only reused for the same model data. */
export function shapeSignature(pieces) {
  let h = 2166136261 ^ BUILDER_VERSION;
  const mix = (v) => {
    h ^= Math.round(v * 1000) | 0;
    h = Math.imul(h, 16777619) >>> 0;
  };
  for (const p of pieces) {
    for (const ch of p.id) mix(ch.charCodeAt(0) / 1000);
    mix(p.shape.samples.length / 3000);
    for (const b of p.shape.boxes) { b.c.forEach(mix); b.h.forEach(mix); }
    p.pos.forEach(mix);
  }
  return `v${BUILDER_VERSION}-${h.toString(16)}`;
}
