// Adds the Z-Anatomy structures that BodyParts3D lacks (joints and
// cartilages, lymph nodes, lungs, brain parts, nerves, bursae…).
//
// Z-Anatomy (CC BY-SA 4.0) is derived from BodyParts3D, so most of its meshes
// duplicate parts we already have. Those are dropped by name and by geometry;
// only new structures are kept, warped into the app frame so that they sit on
// the BodyParts3D skeleton, simplified, and written to a cache that
// build_glb.mjs merges into the per-system GLBs. Existing parts are untouched.
//
// Usage: node --max-old-space-size=8192 build_zanatomy.mjs <raw_dir> <elements_json> <out_json>
// Writes <out_json> (part list) and <out_json without .json>.bin (geometry).

import fs from 'node:fs';
import path from 'node:path';
import * as THREE from 'three';
import { MeshoptSimplifier } from 'meshoptimizer';

globalThis.self = globalThis;
globalThis.window = globalThis;
const { FBXLoader } = await import('three/examples/jsm/loaders/FBXLoader.js');

const [rawDir, elementsJson, outJson] = process.argv.slice(2);
const ZDIR = path.join(rawDir, 'zanatomy');
const FILES = [
  'SkeletalSystem100',
  'Joints100',
  'MuscularSystem100',
  'CardioVascular41',
  'LymphoidOrgans100',
  'NervousSystem100',
  'VisceralSystem100',
];

// ---------------------------------------------------------------------------
// Licence exclusions. Z-Anatomy's licence lists two non-commercial reference
// models that must never ship: "Anatomy of the Inner Ear" (Univ. of Dundee,
// CC-BY-NC-SA) and "Kidney" (Lissie Cowley, CC-BY-NC).
// ---------------------------------------------------------------------------
const LICENCE_EXCLUDE = [
  {
    why: 'inner ear (Univ. of Dundee, CC-BY-NC-SA)',
    // The cochlear and vestibular nerves end inside the inner-ear model and
    // are excluded with it; the vestibulocochlear nerve trunk stays.
    test: (m) => m.path.includes('Internal_earg') ||
      /^(cochlea|vestibul(e|ar_nerve)|semicircular|labyrinth|utricle|saccule|endolymph|perilymph|modiolus|spiral_(lamina|ganglion|organ)|organ_of_corti)/i
        .test(m.name),
  },
  {
    why: 'kidney model (L. Cowley, CC-BY-NC)',
    test: (m) => /kidney|renal_(pelvis|sinus|papilla|pyramid|column|cortex|medulla)|intrarenal|calyx|calyces|(anterior|posterior)_branch_of_renal_artery/i
      .test(m.name),
  },
];

// Structures that are not shipped, with the reason. Each rule is tested
// against "<file>/<group path>/<mesh name>".
const SKIP = [
  [/\/(Cross_Section|Take_a_picture|Medulla-path)[^/]*$|-profile$|\?/, 'helper object'],
  [/\/(Pleura|Greater_omentum|Spinal_dura|Mucosa_of_stomach|Mesocolon)$/, 'occluding sheet / duplicate lining'],
  [/^MuscularSystem100\/Fasciaeg\/(?!.*\/[^/]*(retinaculum|ligament|arch|Palmar_aponeurosis|Plantar_aponeurosis)[^/]*$)/,
    'fascia sheet (would wrap and hide the muscles)'],
  [/^NervousSystem100\/.*\/[^/]*(sulcus|sulci|Lat_Fis|Sulcus_interm)[^/]*$/i, 'sulcus surface strip'],
  [/\/Triradiate_cartilage[lr]$/, 'growth cartilage (not adult anatomy)'],
  [/Spinal_cordg\/(?!.*\/White_matter_of_spinal_cord$)/, 'internal subdivision of the spinal cord (tracts, horns, nuclei)'],
];

// Z-Anatomy meshes that are parts or variants of structures BodyParts3D
// already has under another name (curated synonym table).
const SAME_AS_EXISTING = [
  // Whole organs that BodyParts3D models in its own subdivisions.
  [/\/Cerebellumg\//, 'cerebellum'],
  [/\/Telencephalong\/(Frontal|Parietal|Temporal|Occipital|Limbic)_lobeg\/|\/Insulag\/|White_matter_of_telencephalon/,
    'cerebral gyri / white matter'],
  [/\/(Corpus_striatumg|Basal_forebraing)\/|\/Septal_nuclei$|\/Septum_pellucidum$|\/Hippocampal_commissure$/, 'basal nuclei / septum'],
  [/\/Brainstemg\//, 'midbrain, pons and medulla oblongata (and their nuclei)'],
  [/\/Choroid_plexus[lr]$|\/Fornix[lr]$/, 'choroid plexus / fornix'],
  [/\/(Heartg|Arteries_of_heartg|Cardiac_veinsg)\//, 'heart walls, cavities, valves and coronary vessels'],
  [/\/(Pulmonary_arteriesg|Pulmonary_veinsg)\//, 'pulmonary vessels'],
  [/\/Inferior_vena_cava_\(/, 'inferior vena cava'],
  [/\/Tracheobronchial_treeg\//, 'trachea and bronchial tree'],
  [/\/Digestive_systemg\/Liver($|\/)/, 'liver (hepatovenous segments)'],
  [/\/(Jejunum|Gingiva|Taeniae_colij|Omental_taenia|Free_taenia|Mesocolic_taenia|Meso-appendix)$/, 'small intestine / gingiva / taeniae'],
  [/\/Eyeballg\//, 'eyeball'],
  [/\/(Adenohypophysis|Neurohypophysis)$/, 'pituitary gland'],
  [/\/Thymusg?\//, 'thymus'],
  // Muscles BodyParts3D names differently or keeps as one set.
  [/\/(Iliocostalis|Longissimus|Splenius|Semispinalis|Spinalis)_colli_muscle[lr]?$/, 'cervical part of the muscle'],
  [/\/Interspinales_\w+_muscles[lr]$|\/Levatores_(breves|longi)_costarum[lr]$|\/Rotatores[lr]$/, 'set of short back muscles'],
  [/\/(Palmar|Dorsal)_interossei_muscles(_of_hand)?[lr]$|\/Lumbrical_muscles_of_(hand|foot)[lr]$|\/Plantar_interossei_muscles[lr]$/,
    'set of interossei / lumbricals'],
  [/\/(Anterior|Posterior)_belly_of_digastric_muscle[lr]$|\/Intermediate_tendon_of_digastric_muscle[lr]$/, 'digastric'],
  [/_part_of_thyro-arytenoid_muscle[lr]$|\/Ary-epiglottic_part_of_oblique_arytenoid_muscle[lr]$/, 'laryngeal muscle'],
  [/_head_of_extensor_carpi_ulnaris[lr]$|_head_of_flexor_digitorum_superficialis[lr]$|_head_of_pronator_teres[lr]$/,
    'forearm muscle'],
  [/\/Deep_head_of_flexor_pollicis_brevis[lr]$/, 'flexor pollicis brevis'],
  [/_parts_of_lateral_intertransversarii_lumborum_muscles[lr]$/, 'lumbar intertransversarius'],
  [/\/(External_anal_sphincter|Pubo-analis_muscle|Tendinous_arch_of_levator_ani|Longus_colli_muscle)[lr]$/, 'pelvic / neck muscle'],
  [/\/External_abdominal_oblique_muscle[lr]$/, 'external oblique'],
  [/\/Flexor_digiti_minimi_of_(foot|hand)[lr]$|\/Quadratus_plantae_muscle[lr]$/, 'short muscle of hand / foot'],
  [/\/(Superior|Inferior)_tarsus[lr]$/, 'tarsal plate'],
  [/\/(Scapular_spinal_part_of_deltoid_muscle|(Clavicular|Sternocostal)_head_of_pectoralis_major_muscle)[lr]$/, 'shoulder muscle part'],
  // Vessels that BodyParts3D has as a set, a trunk or as named branches.
  [new RegExp(`/(${[
    'Gastroduodenal_artery', 'Ileal_branch_of_ileocolic_artery', 'Inferior_phrenic_artery', 'Marginal_artery',
    'Posterior_cerebral_artery', 'Superficial_palmar_arch', 'Calcaneal_branches_of_posterior_tibial_artery',
    'Common_plantar_digital_arteries', 'Proper_plantar_digital_arteries', 'Common_palmar_digital_arteries',
    'Proper_palmar_digital_arteries', 'Dorsal_metacarpal_arteries', 'Middle_collateral_artery',
    'Radial_collateral_artery', 'Palmar_digital_veins', 'Plantar_digital_veins', 'Perforating_veins',
    'Plantar_venous_arch', 'Temporo-occipital_branch', 'Posterior_temporal_branch', 'Anterior_temporal_branch',
    'Branch_to_angular_gyrus', 'Thoraco-acromial_artery', 'Ulnar_recurrent_artery', 'Brachial_veins',
  ].join('|')})[lr]?$`), 'vessel set / trunk / branch'],
];

// Kept although they overlap an existing part of similar extent (checked by hand).
const KEEP = /\/(Sigmoid_colon|Multifidus_(colli|thoracis|lumborum)_muscle[lr]|Plantar_aponeurosis[lr]|Quadrangular_membrane[lr])$/;

// BodyParts3D names some structures differently; applied before matching names.
const SYNONYMS = [
  [/\bdisc\b/g, 'disk'], [/oesophag/g, 'esophag'], [/caec/g, 'cec'], [/coeliac/g, 'celiac'],
  [/\bsuprarenal gland\b/g, 'adrenal gland'], [/\bvermiform appendix\b/g, 'appendix'],
  [/\bseminal gland\b/g, 'seminal vesicle'], [/\bductus deferens\b/g, 'deferent duct'],
  [/\bmamillary\b/g, 'mammillary'], [/\bhypophysis\b/g, 'pituitary gland'],
  [/\bamygdaloid body\b/g, 'amygdala'], [/\bmanubrium of sternum\b/g, 'manubrium'],
  [/\b(atlas|axis) \(c[12]\)/g, '$1'], [/\bpineal gland\b/g, 'pineal body'],
  [/\bvertebra ([ctl])(\d+)\b/g, (_, r, n) => `${ORD[n - 1]} ${REGION[r]} vertebra`],
  [/\bintervertebral dis[ck] c2-c3\b/g, 'intervertebral disk of axis'],
  [/\bintervertebral dis[ck] ([ctl])(\d+)-[ctls]\d+\b/g,
    (_, r, n) => `intervertebral disk of ${ORD[n - 1]} ${REGION[r]} vertebra`],
  [/\bcostal cartilage of (\w+) rib\b/g, '$1 costal cartilage'],
  [/\bgreat toe\b/g, 'big toe'], [/\bhemi-azygos\b/g, 'hemiazygos'],
  [/\baortic arch\b/g, 'arch of aorta'], [/^thoracic aorta$/g, 'descending thoracic aorta'],
  [/\bbrachiocephalic trunk\b/g, 'brachiocephalic artery'],
  [/\bstria medullaris thalami\b/g, 'stria medullaris of thalamus'],
  [/\(([ivx]+)\)/g, ''], // cranial nerve numerals
  [/\barteries\b/g, 'artery'], [/\bveins\b/g, 'vein'], [/\bnerves\b/g, 'nerve'], [/\bnodes\b/g, 'node'],
  [/\bligaments\b/g, 'ligament'],
  // Bones of hands and feet, carpals and teeth (used as alignment anchors).
  [/\b(first|second|third|fourth|fifth) finger of (hand|foot)\b/g, (_, n, w) => ({
    hand: { first: 'thumb', second: 'index finger', third: 'middle finger', fourth: 'ring finger', fifth: 'little finger' },
    foot: { first: 'big toe', second: 'second toe', third: 'third toe', fourth: 'fourth toe', fifth: 'little toe' },
  })[w][n]],
  [/\b(scaphoid|lunate|pisiform|trapezium|trapezoid|capitate|hamate) bone\b/g, '$1'],
  [/\btriquetrum bone\b/g, 'triquetral'], [/\bnavicular bone$/g, 'navicular bone of foot'],
  [/\bethmoid bone\b/g, 'ethmoid'], [/\bsesamoid bones of foot\b/g, 'sesamoid bone of foot'],
  [/\binferior nasal concha bone\b/g, 'inferior nasal concha'],
  [/\b(upper|lower) medial incisor\b/g, '$1 central secondary incisor tooth'],
  [/\b(upper|lower) lateral incisor\b/g, '$1 lateral secondary incisor tooth'],
  [/\b(upper|lower) canine\b/g, '$1 secondary canine tooth'],
  [/\b(upper|lower) (first|second) (premolar|molar)( tooth)?\b/g, '$1 $2 secondary $3 tooth'],
];
// Skeletal-file groups that may contribute new non-bone parts (never 'skeletal').
const SKELETAL_FILE_SYSTEM = [
  [/^Auditory_ossiclesg/, 'sensory'],
  [/^(Laryngeal_cartilagesg|Nasal_cartilagesg)/, 'respiratory'],
  [/^Thoracic_skeletong\/Costal_cartilagesg/, 'joint'],
];

// Fraction of triangles kept and max relative error, per system. Z-Anatomy
// meshes are dense (nerves and muscles ~2.3M triangles each), so they are cut
// harder than BodyParts3D; every part keeps at least MIN_TRIS.
const SYSTEM_SIMPLIFY = {
  joint: [0.5, 0.002],
  lymphatic: [0.3, 0.003],
  muscular: [0.3, 0.002],
  nervous: [0.25, 0.002],
  cardiovascular: [0.35, 0.002],
  respiratory: [0.4, 0.002],
  digestive: [0.4, 0.002],
  sensory: [0.5, 0.002],
  endocrine: [0.5, 0.002],
  reproductive: [0.5, 0.002],
  urinary: [0.5, 0.002],
};
const MIN_TRIS = 60;
const MAX_TRIS_PER_PART = 8000;

// ---------------------------------------------------------------------------
// BodyParts3D, in the app frame (same transform as build_glb.mjs).
// ---------------------------------------------------------------------------
const CENTER = [0, -100, 790];
function readObj(file) {
  const pos = [];
  const idx = [];
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (line.startsWith('v ')) {
      const [, x, y, z] = line.trim().split(/\s+/).map(Number);
      pos.push((x - CENTER[0]) / 1000, (z - CENTER[2]) / 1000, -(y - CENTER[1]) / 1000);
    } else if (line.startsWith('f ')) {
      const f = line.trim().split(/\s+/).slice(1).map((t) => parseInt(t, 10) - 1);
      for (let i = 1; i + 1 < f.length; i++) idx.push(f[0], f[i], f[i + 1]);
    }
  }
  return { pos, idx };
}

function bbox(pos) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < pos.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      if (pos[i + k] < min[k]) min[k] = pos[i + k];
      if (pos[i + k] > max[k]) max[k] = pos[i + k];
    }
  }
  return { min, max };
}
const center = (b) => b.min.map((v, k) => (v + b.max[k]) / 2);
const extent = (b) => b.min.map((v, k) => b.max[k] - v);
function boxIoU(a, b) {
  let inter = 1;
  for (let k = 0; k < 3; k++) {
    const d = Math.min(a.max[k], b.max[k]) - Math.max(a.min[k], b.min[k]);
    if (d <= 0) return 0;
    inter *= d;
  }
  const va = extent(a).reduce((x, y) => x * y, 1);
  const vb = extent(b).reduce((x, y) => x * y, 1);
  return inter / (va + vb - inter);
}
function boxUnion(boxes) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (const b of boxes) {
    for (let k = 0; k < 3; k++) {
      min[k] = Math.min(min[k], b.min[k]);
      max[k] = Math.max(max[k], b.max[k]);
    }
  }
  return { min, max };
}

function loadBp3d() {
  const parts = new Map();
  for (const el of JSON.parse(fs.readFileSync(elementsJson, 'utf8'))) {
    if (!parts.has(el.fma)) parts.set(el.fma, { id: el.fma, name: el.name, system: el.system, pos: [], idx: [] });
    const part = parts.get(el.fma);
    const obj = readObj(path.join(rawDir, el.file));
    const base = part.pos.length / 3;
    for (const p of obj.pos) part.pos.push(p);
    for (const i of obj.idx) part.idx.push(base + i);
  }
  const list = [...parts.values()];
  list.forEach((p, i) => {
    p.index = i + 1;
    p.pos = new Float32Array(p.pos);
    p.idx = new Uint32Array(p.idx);
    p.box = bbox(p.pos);
  });
  return list;
}

// ---------------------------------------------------------------------------
// Z-Anatomy FBX meshes, welded, in Z-Anatomy coordinates (cm, Y up).
// ---------------------------------------------------------------------------
// Drops unused vertices: rewrites idx in place, returns the packed positions.
function compact(idx, positions) {
  const [remap, count] = MeshoptSimplifier.compactMesh(idx);
  const out = new Float32Array(count * 3);
  for (let v = 0; v < remap.length; v++) {
    const d = remap[v];
    if (d === 0xffffffff) continue;
    out[d * 3] = positions[v * 3];
    out[d * 3 + 1] = positions[v * 3 + 1];
    out[d * 3 + 2] = positions[v * 3 + 2];
  }
  return out;
}

async function loadFbx(file) {
  const buf = fs.readFileSync(path.join(ZDIR, `${file}.fbx`));
  const root = new FBXLoader().parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength), '');
  root.updateMatrixWorld(true);
  const meshes = [];
  const v = new THREE.Vector3();
  root.traverse((o) => {
    if (!o.isMesh) return;
    const g = o.geometry;
    const src = g.attributes.position;
    if (!src || src.count < 3) return;
    if ((g.index ? g.index.count : src.count) % 3) return; // lines and points
    const raw = new Float32Array(src.count * 3);
    for (let i = 0; i < src.count; i++) {
      v.fromBufferAttribute(src, i).applyMatrix4(o.matrixWorld);
      raw[i * 3] = v.x;
      raw[i * 3 + 1] = v.y;
      raw[i * 3 + 2] = v.z;
    }
    let idx = g.index ? Uint32Array.from(g.index.array) : Uint32Array.from({ length: src.count }, (_, i) => i);
    // Weld identical positions so the simplifier and smooth normals see one surface.
    const remap = MeshoptSimplifier.generatePositionRemap(raw, 3);
    idx = idx.map((i) => remap[i]);
    const pos = compact(idx, raw);
    const ancestors = [];
    for (let p = o.parent; p && p !== root; p = p.parent) ancestors.unshift(p.name);
    meshes.push({
      file,
      name: o.name,
      path: ancestors.join('/'),
      parentIsMesh: !!o.parent?.isMesh,
      pos,
      idx,
    });
  });
  return meshes;
}

// ---------------------------------------------------------------------------
// Names.
// ---------------------------------------------------------------------------
const tokens = (s) => s.toLowerCase().replace(/[()*,'.]/g, ' ').split(/[\s_]+/).filter(Boolean);

// Splits a Z-Anatomy mesh name into base name and side ('l', 'r' or null).
function makeSideParser(allMeshes, bpParts) {
  const vocab = new Set();
  for (const p of bpParts) tokens(p.name).forEach((t) => vocab.add(t));
  const names = new Set(allMeshes.map((m) => `${m.file}/${m.name}`));
  for (const m of allMeshes) {
    const t = tokens(m.name);
    t.slice(0, -1).forEach((x) => vocab.add(x));
    for (const g of m.path.split('/')) if (g.endsWith('g')) tokens(g.slice(0, -1)).forEach((x) => vocab.add(x));
  }
  return (m) => {
    const n = m.name;
    const c = n.slice(-1);
    const other = { l: 'r', r: 'l' }[c];
    if (other) {
      if (names.has(`${m.file}/${n.slice(0, -1)}${other}`) || /\)[lr]$/.test(n)) return { base: n.slice(0, -1), side: c };
      const last = tokens(n).pop() ?? '';
      if (!vocab.has(last) && vocab.has(last.slice(0, -1))) return { base: n.slice(0, -1), side: c };
    }
    // An unsuffixed mesh whose sided twin exists: take the side from its position.
    if (names.has(`${m.file}/${n}l`) || names.has(`${m.file}/${n}r`)) return { base: n, side: 'x' };
    return { base: n, side: null };
  };
}

const RENAME = { 'White matter of spinal cord': 'Spinal cord' };

function displayBase(base) {
  let s = base.replace(/\*/g, '').replace(/_+/g, ' ').replace(/\s+/g, ' ').trim();
  if (/^\(.*\)$/.test(s)) s = s.slice(1, -1).trim();
  // BodyParts3D style: "Left latissimus dorsi", not "... dorsi muscle".
  s = s.replace(/ muscle$/, '').replace(/ muscle \(/, ' (');
  return RENAME[s] ?? s;
}

function displayName(base, side) {
  const s = displayBase(base);
  if (!side || /\b(left|right)\b/i.test(s)) return s[0].toUpperCase() + s.slice(1);
  const lower = /^[A-Z][a-z]/.test(s) ? s[0].toLowerCase() + s.slice(1) : s;
  return `${side === 'l' ? 'Left' : 'Right'} ${lower}`;
}

const slug = (s) => s.replace(/[^A-Za-z0-9]+/g, '_').replace(/^_+|_+$/g, '');

const ORD = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth',
  'tenth', 'eleventh', 'twelfth'];
const REGION = { c: 'cervical', t: 'thoracic', l: 'lumbar' };
const STOP = new Set(['of', 'the', 'muscle', 'muscles', 'proper']);

function normKey(englishName) {
  let s = englishName.toLowerCase().replace(/[*,']/g, ' ').replace(/_/g, ' ');
  for (const [re, to] of SYNONYMS) s = s.replace(re, to);
  let side = '';
  const out = [];
  for (const t of s.replace(/[()]/g, ' ').replace(/-/g, ' ').split(/\s+/)) {
    if (!t || STOP.has(t)) continue;
    if ((t === 'left' || t === 'right') && !side) side = t;
    else out.push(t);
  }
  return `${side}|${out.sort().join(' ')}`;
}

// ---------------------------------------------------------------------------
// Alignment: global affine fit on shared parts, then a smooth local warp so
// new structures follow the BodyParts3D bones they attach to.
// ---------------------------------------------------------------------------
function solve4(A, b) {
  // Gaussian elimination with partial pivoting on a 4x4 system.
  const M = A.map((row, i) => [...row, b[i]]);
  for (let c = 0; c < 4; c++) {
    let p = c;
    for (let r = c + 1; r < 4; r++) if (Math.abs(M[r][c]) > Math.abs(M[p][c])) p = r;
    [M[c], M[p]] = [M[p], M[c]];
    for (let r = 0; r < 4; r++) {
      if (r === c) continue;
      const f = M[r][c] / M[c][c];
      for (let k = c; k < 5; k++) M[r][k] -= f * M[c][k];
    }
  }
  return M.map((row, i) => row[4] / row[i]);
}

function fitAffine(src, dst) {
  const AtA = Array.from({ length: 4 }, () => [0, 0, 0, 0]);
  const Atb = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
  for (let i = 0; i < src.length; i++) {
    const a = [...src[i], 1];
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) AtA[r][c] += a[r] * a[c];
      for (let k = 0; k < 3; k++) Atb[k][r] += a[r] * dst[i][k];
    }
  }
  const rows = Atb.map((b) => solve4(AtA, b));
  return (p) => rows.map((r) => r[0] * p[0] + r[1] * p[1] + r[2] * p[2] + r[3]);
}

function fitSimilarity(src, dst) {
  // Z-Anatomy and the app share axis directions: uniform scale + translation.
  const n = src.length;
  const ms = [0, 1, 2].map((k) => src.reduce((s, p) => s + p[k], 0) / n);
  const md = [0, 1, 2].map((k) => dst.reduce((s, p) => s + p[k], 0) / n);
  let num = 0, den = 0;
  for (let i = 0; i < n; i++) {
    for (let k = 0; k < 3; k++) {
      num += (src[i][k] - ms[k]) * (dst[i][k] - md[k]);
      den += (src[i][k] - ms[k]) ** 2;
    }
  }
  const s = num / den;
  return { s, apply: (p) => p.map((v, k) => s * (v - ms[k]) + md[k]) };
}

// Inverse-distance (power 4) interpolation of landmark residuals.
function makeWarp(landmarks, eps = 0.004) {
  const n = landmarks.length;
  const P = new Float64Array(n * 3), D = new Float64Array(n * 3);
  landmarks.forEach((l, i) => {
    for (let k = 0; k < 3; k++) { P[i * 3 + k] = l.at[k]; D[i * 3 + k] = l.d[k]; }
  });
  const e2 = eps * eps;
  return (p) => {
    let sw = 0, dx = 0, dy = 0, dz = 0;
    for (let i = 0; i < n; i++) {
      const x = P[i * 3] - p[0], y = P[i * 3 + 1] - p[1], z = P[i * 3 + 2] - p[2];
      const r2 = x * x + y * y + z * z + e2;
      const w = 1 / (r2 * r2);
      sw += w; dx += w * D[i * 3]; dy += w * D[i * 3 + 1]; dz += w * D[i * 3 + 2];
    }
    return [dx / sw, dy / sw, dz / sw];
  };
}

// Samples a warp on a regular grid for fast trilinear lookup.
function gridWarp(warp, box, h) {
  const o = box.min.map((v) => v - 2 * h);
  const n = box.max.map((v, k) => Math.ceil((v + 2 * h - o[k]) / h) + 1);
  const g = new Float32Array(n[0] * n[1] * n[2] * 3);
  for (let z = 0; z < n[2]; z++) {
    for (let y = 0; y < n[1]; y++) {
      for (let x = 0; x < n[0]; x++) {
        const d = warp([o[0] + x * h, o[1] + y * h, o[2] + z * h]);
        const i = ((z * n[1] + y) * n[0] + x) * 3;
        g[i] = d[0]; g[i + 1] = d[1]; g[i + 2] = d[2];
      }
    }
  }
  return (p) => {
    const f = [0, 1, 2].map((k) => Math.min(Math.max((p[k] - o[k]) / h, 0), n[k] - 1.001));
    const i0 = f.map(Math.floor);
    const t = f.map((v, k) => v - i0[k]);
    const out = [0, 0, 0];
    for (let c = 0; c < 8; c++) {
      const ix = i0[0] + (c & 1), iy = i0[1] + ((c >> 1) & 1), iz = i0[2] + ((c >> 2) & 1);
      const w = (c & 1 ? t[0] : 1 - t[0]) * ((c >> 1) & 1 ? t[1] : 1 - t[1]) * ((c >> 2) & 1 ? t[2] : 1 - t[2]);
      const j = ((iz * n[1] + iy) * n[0] + ix) * 3;
      out[0] += w * g[j]; out[1] += w * g[j + 1]; out[2] += w * g[j + 2];
    }
    return out;
  };
}

// Landmarks of a mesh: its box centre and the six extreme vertices.
function landmarksOf(pos, transform = (p) => p) {
  const ext = Array.from({ length: 6 }, () => null);
  const val = [Infinity, -Infinity, Infinity, -Infinity, Infinity, -Infinity];
  for (let i = 0; i < pos.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      const v = pos[i + k];
      if (v < val[k * 2]) { val[k * 2] = v; ext[k * 2] = i; }
      if (v > val[k * 2 + 1]) { val[k * 2 + 1] = v; ext[k * 2 + 1] = i; }
    }
  }
  const b = bbox(pos);
  return [transform(center(b)), ...ext.map((i) => transform([pos[i], pos[i + 1], pos[i + 2]]))];
}

// ---------------------------------------------------------------------------
// Occupancy grid of BodyParts3D: which voxels are inside a part, and which
// hold part surface. Used to recognise Z meshes that duplicate (or sit inside)
// an existing part.
// ---------------------------------------------------------------------------
function makeGrid(box, h) {
  const o = box.min.map((v) => v - 4 * h);
  const n = box.max.map((v, k) => Math.ceil((v + 4 * h - o[k]) / h));
  const voxel = (x, y, z) => {
    const ix = Math.floor((x - o[0]) / h), iy = Math.floor((y - o[1]) / h), iz = Math.floor((z - o[2]) / h);
    if (ix < 0 || iy < 0 || iz < 0 || ix >= n[0] || iy >= n[1] || iz >= n[2]) return -1;
    return (iz * n[1] + iy) * n[0] + ix;
  };
  return { o, n, h, voxel, size: n[0] * n[1] * n[2] };
}

// Calls fn(voxel) for every voxel whose centre is inside the closed mesh
// (ray parity along +X; rows with an odd number of hits are ignored).
function voxelize(grid, pos, idx, fn) {
  const { o, n, h } = grid;
  const rows = new Map();
  for (let t = 0; t < idx.length; t += 3) {
    const a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
    const ay = pos[a + 1], az = pos[a + 2], by = pos[b + 1], bz = pos[b + 2], cy = pos[c + 1], cz = pos[c + 2];
    const y0 = Math.max(0, Math.ceil((Math.min(ay, by, cy) - o[1]) / h - 0.5));
    const y1 = Math.min(n[1] - 1, Math.floor((Math.max(ay, by, cy) - o[1]) / h - 0.5));
    const z0 = Math.max(0, Math.ceil((Math.min(az, bz, cz) - o[2]) / h - 0.5));
    const z1 = Math.min(n[2] - 1, Math.floor((Math.max(az, bz, cz) - o[2]) / h - 0.5));
    if (y0 > y1 || z0 > z1) continue;
    const det = (by - ay) * (cz - az) - (cy - ay) * (bz - az);
    if (Math.abs(det) < 1e-14) continue;
    for (let iy = y0; iy <= y1; iy++) {
      const py = o[1] + (iy + 0.5) * h;
      for (let iz = z0; iz <= z1; iz++) {
        const pz = o[2] + (iz + 0.5) * h;
        const u = ((py - ay) * (cz - az) - (cy - ay) * (pz - az)) / det;
        const w = ((by - ay) * (pz - az) - (py - ay) * (bz - az)) / det;
        if (u < 0 || w < 0 || u + w > 1) continue;
        const x = pos[a] + u * (pos[b] - pos[a]) + w * (pos[c] - pos[a]);
        const key = iz * n[1] + iy;
        let row = rows.get(key);
        if (!row) rows.set(key, (row = []));
        row.push(x);
      }
    }
  }
  for (const [key, xs] of rows) {
    if (xs.length % 2) continue;
    xs.sort((p, q) => p - q);
    for (let i = 0; i < xs.length; i += 2) {
      const x0 = Math.max(0, Math.ceil((xs[i] - o[0]) / h - 0.5));
      const x1 = Math.min(n[0] - 1, Math.floor((xs[i + 1] - o[0]) / h - 0.5));
      for (let ix = x0; ix <= x1; ix++) fn(key * n[0] + ix);
    }
  }
}

// Calls fn(voxel) for sample points spread over every triangle.
function surfaceVoxels(grid, pos, idx, fn) {
  const step = grid.h / 2;
  for (let t = 0; t < idx.length; t += 3) {
    const a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
    const len = Math.max(
      Math.hypot(pos[b] - pos[a], pos[b + 1] - pos[a + 1], pos[b + 2] - pos[a + 2]),
      Math.hypot(pos[c] - pos[a], pos[c + 1] - pos[a + 1], pos[c + 2] - pos[a + 2]),
      Math.hypot(pos[c] - pos[b], pos[c + 1] - pos[b + 1], pos[c + 2] - pos[b + 2]),
    );
    const k = Math.max(1, Math.ceil(len / step));
    for (let i = 0; i <= k; i++) {
      for (let j = 0; i + j <= k; j++) {
        const u = i / k, w = j / k, s = 1 - u - w;
        const v = grid.voxel(
          s * pos[a] + u * pos[b] + w * pos[c],
          s * pos[a + 1] + u * pos[b + 1] + w * pos[c + 1],
          s * pos[a + 2] + u * pos[b + 2] + w * pos[c + 2],
        );
        if (v >= 0) fn(v);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Main.
// ---------------------------------------------------------------------------
await MeshoptSimplifier.ready;
const t0 = Date.now();
const log = (...a) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s]`, ...a);

const bp = loadBp3d();
log(`BodyParts3D: ${bp.length} parts`);
const bpByKey = new Map();
for (const p of bp) {
  const k = normKey(p.name);
  if (!bpByKey.has(k)) bpByKey.set(k, p);
}
const bpNameKeys = new Set(bpByKey.keys());

let meshes = [];
for (const file of FILES) {
  const list = await loadFbx(file);
  log(`${file}: ${list.length} meshes`);
  meshes.push(...list);
}

const report = { licence: [], skipped: new Map(), duplicate: [], notSkeletal: [], merged: [] };
const skip = (m, why) => {
  if (!report.skipped.has(why)) report.skipped.set(why, []);
  report.skipped.get(why).push(m.name);
};

// 1. Drop labels and helpers, licence-excluded and unwanted structures.
const sideOf = makeSideParser(meshes, bp);
meshes = meshes.filter((m) => {
  const tris = m.idx.length / 3;
  if (tris < 20) return false; // label quads and empty helpers
  if (/j$/.test(m.name)) return false; // text labels
  const parent = m.path.split('/').pop() ?? '';
  if (/i$/.test(m.name) && parent.endsWith('s') && m.name.slice(0, -1) === parent.slice(0, -1)) return false;
  if (m.file === 'SkeletalSystem100' && m.parentIsMesh) return false; // muscle attachment markers
  for (const ex of LICENCE_EXCLUDE) {
    if (ex.test(m)) {
      report.licence.push(`${m.name} (${m.file}: ${ex.why})`);
      return false;
    }
  }
  m.full = `${m.file}/${m.path}/${m.name}`;
  for (const [re, why] of SKIP) if (re.test(m.full)) return skip(m, why), false;
  return true;
});

// 2. Names, sides, and the global alignment from parts both sources share.
for (const m of meshes) {
  const { base, side } = sideOf(m);
  m.base = base;
  m.zbox = bbox(m.pos);
  m.side = side === 'x' ? (center(m.zbox)[0] > 0 ? 'l' : 'r') : side;
  m.name_en = displayName(base, m.side);
  m.key = normKey(m.name_en);
  m.match = bpByKey.get(m.key) ?? null;
  // BodyParts3D sometimes keeps one unsided part for a paired Z-Anatomy mesh.
  m.matchUnsided = m.match ? null : bpByKey.get(`|${m.key.split('|')[1]}`) ?? null;
  m.sameAs = SAME_AS_EXISTING.find(([re]) => re.test(m.full))?.[1] ?? null;
}

const skeletalPairs = meshes.filter((m) => m.file === 'SkeletalSystem100' && m.match?.system === 'skeletal');
const sim = fitSimilarity(skeletalPairs.map((m) => center(m.zbox)), skeletalPairs.map((m) => center(m.match.box)));
const affine = fitAffine(skeletalPairs.map((m) => center(m.zbox)), skeletalPairs.map((m) => center(m.match.box)));
const rms = (errs) => Math.sqrt(errs.reduce((s, e) => s + e * e, 0) / errs.length);
const pct = (errs, q) => [...errs].sort((a, b) => a - b)[Math.floor(q * (errs.length - 1))];
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const errOf = (f) => skeletalPairs.map((m) => dist(f(center(m.zbox)), center(m.match.box)) * 1000);
const eSim = errOf(sim.apply);
const eAff = errOf(affine);
if (process.env.ZA_DEBUG) skeletalPairs.forEach((m, i) => console.log('pair', m.name, '=', m.match.name, eSim[i].toFixed(1)));
log(`alignment on ${skeletalPairs.length} shared bones (box centres):`);
log(`  similarity (scale ${(sim.s * 100).toFixed(4)} cm->m %): rms ${rms(eSim).toFixed(1)} mm, max ${Math.max(...eSim).toFixed(1)} mm`);
log(`  affine: rms ${rms(eAff).toFixed(1)} mm, max ${Math.max(...eAff).toFixed(1)} mm`);

// Landmarks: shared bones (centre + extremes) and other shared parts of a
// consistent size (centre only). Their residuals after the affine fit drive
// the local warp.
const landmarks = [];
const anchorParts = [];
for (const m of meshes) {
  if (!m.match || m.match.system === 'integumentary') continue;
  const za = landmarksOf(m.pos, affine);
  const bb = landmarksOf(m.match.pos);
  const ez = extent(bbox(m.pos.map((v) => v))), eb = extent(m.match.box);
  const zs = ez.map((v) => v * sim.s);
  const ok = zs.every((v, k) => v / eb[k] > 0.7 && v / eb[k] < 1.4) && dist(za[0], bb[0]) < 0.04;
  if (!ok) continue;
  const isBone = m.match.system === 'skeletal';
  const n = isBone ? 7 : 1;
  const group = anchorParts.length;
  anchorParts.push({ m, isBone, group });
  for (let i = 0; i < n; i++) landmarks.push({ at: za[i], d: bb[i].map((v, k) => v - za[i][k]), group, isBone });
}
// Leave-one-out check on the bones: how far is each bone's centre from its
// BodyParts3D twin when the warp is built without that bone?
const loo = [];
for (const a of anchorParts.filter((x) => x.isBone)) {
  const warp = makeWarp(landmarks.filter((l) => l.group !== a.group));
  const p = affine(center(a.m.zbox));
  const d = warp(p);
  loo.push(dist(p.map((v, k) => v + d[k]), center(a.m.match.box)) * 1000);
}
log(`  local warp from ${landmarks.length} landmarks on ${anchorParts.length} shared parts:`);
log(`  leave-one-out on ${loo.length} bones: rms ${rms(loo).toFixed(1)} mm, median ${pct(loo, 0.5).toFixed(1)} mm, p90 ${pct(loo, 0.9).toFixed(1)} mm`);
const allBox = boxUnion(bp.map((p) => p.box));
const warp = gridWarp(makeWarp(landmarks), allBox, 0.01);
{
  const fit = anchorParts.filter((x) => x.isBone).map((a) => {
    const p = affine(center(a.m.zbox));
    const d = warp(p);
    return dist(p.map((v, k) => v + d[k]), center(a.m.match.box)) * 1000;
  });
  log(`  after warp, shared bones: rms ${rms(fit).toFixed(1)} mm, max ${Math.max(...fit).toFixed(1)} mm`);
}
const toApp = (p) => {
  const q = affine(p);
  const d = warp(q);
  return [q[0] + d[0], q[1] + d[1], q[2] + d[2]];
};
for (const m of meshes) {
  const out = new Float32Array(m.pos.length);
  for (let i = 0; i < m.pos.length; i += 3) {
    const q = toApp([m.pos[i], m.pos[i + 1], m.pos[i + 2]]);
    out[i] = q[0]; out[i + 1] = q[1]; out[i + 2] = q[2];
  }
  m.pos = out;
  m.box = bbox(out);
}

// 3. Occupancy of BodyParts3D at 2 mm.
const grid = makeGrid(allBox, 0.002);
const inside = new Uint16Array(grid.size);
const surface = new Uint16Array(grid.size);
for (const p of bp) {
  if (p.system === 'integumentary') continue;
  voxelize(grid, p.pos, p.idx, (v) => { if (!inside[v]) inside[v] = p.index; });
  surfaceVoxels(grid, p.pos, p.idx, (v) => { surface[v] = p.index; });
}
log('BodyParts3D occupancy grid ready');

function overlap(m) {
  // Volume of the Z mesh inside BodyParts3D parts.
  let vox = 0, inVox = 0;
  const owners = new Map();
  voxelize(grid, m.pos, m.idx, (v) => {
    vox++;
    if (inside[v]) {
      inVox++;
      owners.set(inside[v], (owners.get(inside[v]) ?? 0) + 1);
    }
  });
  // Vertices on a BodyParts3D surface, and strictly inside a part.
  const nv = m.pos.length / 3;
  const stride = Math.max(1, Math.floor(nv / 1500));
  let samples = 0, near = 0, deep = 0;
  const nearOwners = new Map();
  const { n } = grid;
  for (let i = 0; i < nv; i += stride) {
    const v = grid.voxel(m.pos[i * 3], m.pos[i * 3 + 1], m.pos[i * 3 + 2]);
    if (v < 0) continue;
    samples++;
    if (surface[v]) {
      near++;
      nearOwners.set(surface[v], (nearOwners.get(surface[v]) ?? 0) + 1);
    }
    if (inside[v] && inside[v - 1] && inside[v + 1] && inside[v - n[0]] && inside[v + n[0]] &&
        inside[v - n[0] * n[1]] && inside[v + n[0] * n[1]]) {
      deep++;
      owners.set(inside[v], (owners.get(inside[v]) ?? 0) + 1);
    }
  }
  const top = (map, frac, total) => [...map.entries()].filter(([, c]) => c >= frac * total).map(([i]) => bp[i - 1]);
  const touched = [...new Set([...top(owners, 0.15, inVox + deep), ...top(nearOwners, 0.15, near)])]
    .filter((p) => compatible(m.system, p.system));
  return {
    vox,
    contain: vox ? inVox / vox : 0,
    near: samples ? near / samples : 0,
    deep: samples ? deep / samples : 0,
    touched,
    iou: touched.length
      ? Math.max(boxIoU(m.box, boxUnion(touched.map((p) => p.box))), ...touched.map((p) => boxIoU(m.box, p.box)))
      : 0,
  };
}

// 4. Keep only what BodyParts3D lacks: drop meshes matching an existing part
// by name, by the synonym table, or by geometry (a compatible existing part of
// about the same extent that the mesh overlaps).
function compatible(zSystem, bpSystem) {
  return zSystem === bpSystem ||
    (bpSystem === 'skeletal' && ['joint', 'respiratory', 'sensory'].includes(zSystem)) ||
    (bpSystem === 'muscular' && zSystem === 'joint') ||
    (zSystem === 'lymphatic' && ['other', 'endocrine'].includes(bpSystem));
}
const kept = [];
for (const m of meshes) {
  m.system = systemOf(m);
  if (m.match || m.matchUnsided) {
    report.duplicate.push(`${m.name_en} = ${(m.match ?? m.matchUnsided).name} (name)`);
    continue;
  }
  if (m.sameAs) {
    report.duplicate.push(`${m.name_en} ~ ${m.sameAs} (synonym table)`);
    continue;
  }
  if (!m.system) {
    report.notSkeletal.push(m.name_en);
    continue;
  }
  const o = overlap(m);
  m.overlap = o;
  const tubular = m.system === 'cardiovascular' || m.system === 'nervous';
  const why = !KEEP.test(m.full) && o.iou >= (tubular ? 0.45 : 0.5) &&
    (o.contain >= 0.4 || o.near >= 0.5 || o.deep >= 0.4) && 'overlaps an existing part of the same extent';
  if (why) {
    report.duplicate.push(`${m.name_en} ~ ${o.touched.map((p) => p.name).join(' + ') || '?'} (${why}; ` +
      `contain ${o.contain.toFixed(2)} deep ${o.deep.toFixed(2)} near ${o.near.toFixed(2)} iou ${o.iou.toFixed(2)})`);
    continue;
  }
  kept.push(m);
}
log(`kept ${kept.length} of ${meshes.length} candidate meshes`);

// 5. Systems.
function systemOf(m) {
  const top = m.path.split('/')[0] ?? '';
  switch (m.file) {
    case 'SkeletalSystem100':
      for (const [re, sys] of SKELETAL_FILE_SYSTEM) if (re.test(m.path)) return sys;
      return null; // bones are never added
    case 'Joints100':
      return top.startsWith('Laryngeal_joints') ? 'respiratory' : 'joint';
    case 'MuscularSystem100':
      return 'muscular';
    case 'CardioVascular41':
      return 'cardiovascular';
    case 'LymphoidOrgans100':
      return 'lymphatic';
    case 'NervousSystem100':
      return top.startsWith('Sense_organs') ? 'sensory' : 'nervous';
    case 'VisceralSystem100':
      if (top.startsWith('Digestive_system') || top.startsWith('Abdominopelvic_cavity')) return 'digestive';
      if (top.startsWith('Respiratory_system')) return 'respiratory';
      if (top.startsWith('Urinary_system')) return 'urinary';
      if (top.startsWith('Endocrine_glands')) return 'endocrine';
      if (top.startsWith('Genital_systems')) return 'reproductive';
      return null;
    default:
      return null;
  }
}

const parts = new Map();
for (const m of kept) {
  const system = m.system;
  const id = `ZA_${slug(displayBase(m.base))}${m.side ? `_${m.side}` : ''}`;
  if (parts.has(id)) {
    const p = parts.get(id);
    if (boxIoU(p.box, m.box) > 0.5) continue; // same structure twice
    p.pieces.push(m);
    p.box = boxUnion([p.box, m.box]);
    report.merged.push(`${m.name} -> ${id}`);
    continue;
  }
  parts.set(id, { id, name: m.name_en, system, pieces: [m], box: m.box });
}

// The nucleus pulposus is the core of its intervertebral disc: one part.
for (const [id, p] of parts) {
  const lv = /^ZA_Nucleus_pulposus_(.+)$/.exec(id);
  if (!lv) continue;
  parts.delete(id);
  const disc = parts.get(`ZA_Intervertebral_disc_${lv[1]}`);
  if (disc) {
    disc.pieces.push(...p.pieces);
    report.merged.push(`${p.name} -> ${disc.id}`);
  } else {
    report.duplicate.push(`${p.name} (inside an existing intervertebral disk)`);
  }
}

// 6. Simplify and write the cache.
const meta = [];
const chunks = [];
let offset = 0;
const stats = new Map();
for (const p of [...parts.values()].sort((a, b) => a.system.localeCompare(b.system) || a.name.localeCompare(b.name))) {
  const pos = [];
  const idx = [];
  for (const m of p.pieces) {
    const base = pos.length / 3;
    for (const v of m.pos) pos.push(v);
    for (const i of m.idx) idx.push(base + i);
  }
  const positions = new Float32Array(pos);
  let indices = new Uint32Array(idx);
  const [ratio, error] = SYSTEM_SIMPLIFY[p.system];
  const tris = indices.length / 3;
  const target = Math.max(MIN_TRIS, Math.min(MAX_TRIS_PER_PART, Math.round(tris * ratio)));
  if (target < tris) {
    [indices] = MeshoptSimplifier.simplify(indices, positions, 3, target * 3, error, ['Prune']);
  }
  const outIdx = Uint32Array.from(indices);
  const outPos = compact(outIdx, positions);
  if (outIdx.length === 0) continue;
  const posBytes = Buffer.from(outPos.buffer);
  const idxBytes = Buffer.from(outIdx.buffer);
  meta.push({
    id: p.id,
    name: p.name,
    system: p.system,
    positions: [offset, outPos.length],
    indices: [offset + posBytes.length, outIdx.length],
  });
  chunks.push(posBytes, idxBytes);
  offset += posBytes.length + idxBytes.length;
  const s = stats.get(p.system) ?? { parts: 0, before: 0, after: 0 };
  s.parts++; s.before += tris; s.after += outIdx.length / 3;
  stats.set(p.system, s);
}
fs.writeFileSync(outJson.replace(/\.json$/, '.bin'), Buffer.concat(chunks));
fs.writeFileSync(outJson, JSON.stringify(meta, null, 1));

// 7. Report.
console.log('\nZ-Anatomy parts added (triangles before -> after simplification):');
for (const [sys, s] of [...stats].sort()) {
  console.log(`  ${sys.padEnd(15)} parts=${String(s.parts).padStart(4)} tris ${s.before} -> ${s.after}`);
}
console.log(`\nLicence exclusions (${report.licence.length}):`);
for (const l of report.licence) console.log(`  ${l}`);
console.log(`\nSkipped by rule:`);
for (const [why, list] of report.skipped) console.log(`  ${why} (${list.length}): ${list.slice(0, 12).join(', ')}${list.length > 12 ? ', …' : ''}`);
console.log(`\nNot added because they would be skeletal (${report.notSkeletal.length}): ${report.notSkeletal.join(', ')}`);
console.log(`Duplicates of BodyParts3D parts: ${report.duplicate.length}`);
console.log(`Merged pieces: ${report.merged.length}`);
if (process.env.ZA_VERBOSE) {
  fs.writeFileSync(outJson.replace(/\.json$/, '.report.txt'), [
    '# duplicates', ...report.duplicate,
    '# merged', ...report.merged,
    '# kept', ...meta.map((p) => {
      const m = parts.get(p.id)?.pieces[0];
      const o = m?.overlap;
      return `${p.system}\t${p.id}\t${p.name}\t${o ? `contain ${o.contain.toFixed(2)} deep ${o.deep.toFixed(2)} near ${o.near.toFixed(2)} iou ${o.iou.toFixed(2)} ~ ${o.touched.map((t) => t.name).join(' + ')}` : ''}`;
    }),
  ].join('\n'));
}
