// Converts BodyParts3D OBJ elements into one compressed GLB per body system,
// plus the parts index the app reads.
//
// Usage: node build_glb.mjs <raw_dir> <parts_json> <out_assets_dir>

import fs from 'node:fs';
import path from 'node:path';
import { Document, NodeIO } from '@gltf-transform/core';
import { EXTMeshoptCompression, KHRMeshQuantization } from '@gltf-transform/extensions';
import { meshopt, simplify, weld } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptSimplifier } from 'meshoptimizer';

const [rawDir, partsJson, outDir] = process.argv.slice(2);

// BodyParts3D is in millimetres, Z up, anterior towards -Y.
// The app wants metres, Y up, anterior towards +Z, body centred on the origin.
const CENTER = [0, -100, 790];
const toApp = (x, y, z) => [
  (x - CENTER[0]) / 1000,
  (z - CENTER[2]) / 1000,
  -(y - CENTER[1]) / 1000,
];

// Fraction of triangles kept per system; small parts keep more via the error bound.
const SIMPLIFY_RATIO = {
  skeletal: 0.4,
  muscular: 0.15,
  cardiovascular: 0.15,
  nervous: 0.15,
  default: 0.2,
};

// Max simplification error (relative to each part's size). The skeleton
// is what players zoom into most, so it keeps finer surface detail (muscles
// get theirs from procedural fibres in the viewer instead).
const SIMPLIFY_ERROR = {
  skeletal: 0.0008,
  default: 0.002,
};

function readObj(file) {
  const positions = [];
  const indices = [];
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (line.startsWith('v ')) {
      const [, x, y, z] = line.trim().split(/\s+/).map(Number);
      const [ax, ay, az] = toApp(x, y, z);
      positions.push(ax, ay, az);
    } else if (line.startsWith('f ')) {
      const idx = line.trim().split(/\s+/).slice(1).map((t) => parseInt(t, 10) - 1);
      for (let i = 1; i + 1 < idx.length; i++) indices.push(idx[0], idx[i], idx[i + 1]);
    }
  }
  return { positions, indices };
}

// Area-weighted smooth normals. gltf-transform's normals() unwelds into flat shading.
function smoothNormals() {
  return (doc) => {
    for (const mesh of doc.getRoot().listMeshes()) {
      for (const prim of mesh.listPrimitives()) {
        const pos = prim.getAttribute('POSITION').getArray();
        const idx = prim.getIndices().getArray();
        const n = new Float32Array(pos.length);
        for (let t = 0; t < idx.length; t += 3) {
          const a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
          const ux = pos[b] - pos[a], uy = pos[b + 1] - pos[a + 1], uz = pos[b + 2] - pos[a + 2];
          const vx = pos[c] - pos[a], vy = pos[c + 1] - pos[a + 1], vz = pos[c + 2] - pos[a + 2];
          const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
          for (const v of [a, b, c]) { n[v] += nx; n[v + 1] += ny; n[v + 2] += nz; }
        }
        for (let v = 0; v < n.length; v += 3) {
          const len = Math.hypot(n[v], n[v + 1], n[v + 2]) || 1;
          n[v] /= len; n[v + 1] /= len; n[v + 2] /= len;
        }
        prim.setAttribute('NORMAL', doc.createAccessor().setType('VEC3').setArray(n)
          .setBuffer(doc.getRoot().listBuffers()[0]));
      }
    }
  };
}

function groupParts(elements) {
  const parts = new Map();
  for (const el of elements) {
    if (!parts.has(el.fma)) {
      parts.set(el.fma, { id: el.fma, name: el.name, system: el.system, files: [] });
    }
    parts.get(el.fma).files.push(el.file);
  }
  return [...parts.values()];
}

async function buildSystem(system, parts) {
  const doc = new Document();
  const buffer = doc.createBuffer();
  const scene = doc.createScene(system);
  const material = doc.createMaterial(system);

  for (const part of parts) {
    const positions = [];
    const indices = [];
    for (const file of part.files) {
      const obj = readObj(path.join(rawDir, file));
      const base = positions.length / 3;
      for (const p of obj.positions) positions.push(p);
      for (const i of obj.indices) indices.push(base + i);
    }
    const prim = doc.createPrimitive()
      .setAttribute('POSITION', doc.createAccessor().setType('VEC3')
        .setArray(new Float32Array(positions)).setBuffer(buffer))
      .setIndices(doc.createAccessor().setType('SCALAR')
        .setArray(new Uint32Array(indices)).setBuffer(buffer))
      .setMaterial(material);
    const mesh = doc.createMesh(part.id).addPrimitive(prim);
    scene.addChild(doc.createNode(part.id).setMesh(mesh).setExtras({ name: part.name }));
  }

  await MeshoptEncoder.ready;
  await MeshoptSimplifier.ready;
  await doc.transform(
    weld(),
    simplify({
      simplifier: MeshoptSimplifier,
      ratio: SIMPLIFY_RATIO[system] ?? SIMPLIFY_RATIO.default,
      error: SIMPLIFY_ERROR[system] ?? SIMPLIFY_ERROR.default,
    }),
    smoothNormals(),
    meshopt({ encoder: MeshoptEncoder, level: 'medium' }),
  );

  const io = new NodeIO()
    .registerExtensions([EXTMeshoptCompression, KHRMeshQuantization])
    .registerDependencies({ 'meshopt.encoder': MeshoptEncoder });
  const out = path.join(outDir, 'models', `${system}.glb`);
  await io.write(out, doc);

  let triangles = 0;
  for (const mesh of doc.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) triangles += prim.getIndices().getCount() / 3;
  }
  const kb = Math.round(fs.statSync(out).size / 1024);
  console.log(`${system.padEnd(15)} parts=${parts.length} tris=${triangles} size=${kb}KB`);
}

const elements = JSON.parse(fs.readFileSync(partsJson, 'utf8'));
const parts = groupParts(elements);
fs.mkdirSync(path.join(outDir, 'models'), { recursive: true });

const bySystem = new Map();
for (const part of parts) {
  if (!bySystem.has(part.system)) bySystem.set(part.system, []);
  bySystem.get(part.system).push(part);
}
for (const [system, list] of bySystem) await buildSystem(system, list);

const index = parts.map(({ id, name, system }) => ({ id, name, system }));
fs.writeFileSync(path.join(outDir, 'parts.json'), JSON.stringify(index));
console.log(`parts.json: ${index.length} parts`);
