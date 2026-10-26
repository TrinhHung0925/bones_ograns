// Per-part PBR materials with procedural surface detail. No textures: bone
// pores, muscle fibres and organ mottling come from object-space value noise
// injected into three's standard/physical shaders. The same injection adds a
// fresnel rim (selection / flash / game glows) and view-dependent opacity for
// see-through parts.
//
// Every material of one kind shares one compiled program: the procedural code
// is selected by defines and `customProgramCacheKey`, while per-part values
// (fibre direction, rim colour) live in uniforms.

import * as THREE from 'three';

export const KIND = { BONE: 0, MUSCLE: 1, ORGAN: 2, VESSEL: 3, NERVE: 4, SKIN: 5, TENDON: 6 };

/** Shared by every material, so switching quality is just a recompile. */
const settings = { detail: true };

// Base colours are sRGB hex; three converts them to linear.
const ORGAN_COLORS = [
  [/liver|hepat|caudate lobe/i, 0x7c2b24],
  [/biliary|bile|hepatic duct|cystic duct|gallbladder/i, 0x5f8a3e],
  [/spleen/i, 0x6b2537],
  [/pancrea/i, 0xe2b089],
  [/kidney/i, 0x8c3a2e],
  [/ureter|urethra|bladder/i, 0xd9a48c],
  [/stomach|esophag|duoden|jejun|ile|colon|rectum|cecum|appendix|taeni|intestin/i, 0xe0998a],
  [/mesent|mesocolon|mesoappendix|omentum/i, 0xf0d39c],
  [/tongue/i, 0xc85a5f],
  [/gingiva|lip/i, 0xd4787a],
  [/gland|thymus|pituitary/i, 0xd59a7c],
  [/bronch|trachea|epiglottis|conus|ligament|membrane|cartilage/i, 0xe8c9c0],
  [/lung|lobe/i, 0xe7a1a8],
  [/brain|gyrus|cerebr|cerebell|lobule|cortex|nucleus|thalamus|colliculus|hippocamp|amygdala|pons|medulla|insula|corpus callosum|fornix|capsule|putamen|pallidus|commissure|body|habenula|white matter/i, 0xe3b9b1],
  [/ventricle|aqueduct|canal|foramen|choroid plexus/i, 0x9ec6e0],
  [/sclera|vitreous|lens|cornea|chamber/i, 0xf2ece6],
  [/iris/i, 0x4f7a9e],
  [/retina|choroid/i, 0xa8483f],
  [/testis|epididym|prostate|vesicle|deferent|penis|glans|corpus/i, 0xd48f8c],
  [/heart|ventricle|atrium|valve|papillary|leaflet|cusp|myocard/i, 0xa3302c],
];

const SYSTEM_DEFAULT = {
  digestive: 0xe0998a,
  respiratory: 0xe7a1a8,
  urinary: 0x9c4a3c,
  reproductive: 0xd48f8c,
  endocrine: 0xd08a6c,
  sensory: 0xe9dcd2,
  other: 0x6b2537,
};

const VEIN_RE = /vein|venous|sinus|vena/i;
const TOOTH_RE = /tooth|incisor|canine|molar|premolar|dent/i;
const CARTILAGE_RE = /cartilage|disc|menisc|symphysis|labrum/i;
const TENDON_RE = /tendon|aponeuros|retinaculum|fascia|interosseous membrane|ligament|sheath/i;

/** Material preset for a part, from its system and English name. */
function preset(system, name) {
  switch (system) {
    case 'skeletal':
      if (TOOTH_RE.test(name)) {
        return { kind: KIND.BONE, color: 0xf3eee2, roughness: 0.28, clearcoat: 0.6, clearcoatRoughness: 0.15 };
      }
      if (CARTILAGE_RE.test(name)) {
        return { kind: KIND.ORGAN, color: 0xd9e0e2, roughness: 0.35, clearcoat: 0.7, clearcoatRoughness: 0.2, sheen: 0.4, sheenColor: 0xcfe3ff };
      }
      return { kind: KIND.BONE, color: 0xe6d8bc, roughness: 0.66 };
    case 'muscular':
      if (TENDON_RE.test(name)) {
        return { kind: KIND.TENDON, color: 0xe8ddcb, roughness: 0.38, clearcoat: 0.35, clearcoatRoughness: 0.3, sheen: 0.6, sheenColor: 0xffffff };
      }
      return { kind: KIND.MUSCLE, color: 0x8a211d, roughness: 0.5, clearcoat: 0.25, clearcoatRoughness: 0.35, sheen: 0.6, sheenColor: 0xff8a7a, sheenRoughness: 0.45 };
    case 'cardiovascular': {
      if (/heart|ventricle|atrium|valve|papillary|leaflet|cusp|myocard|septum|trabecul/i.test(name)) {
        return { kind: KIND.ORGAN, color: 0xa3302c, roughness: 0.42, clearcoat: 0.8, clearcoatRoughness: 0.2 };
      }
      const vein = VEIN_RE.test(name);
      return { kind: KIND.VESSEL, color: vein ? 0x2f56b5 : 0xc4262b, roughness: 0.33, clearcoat: 0.75, clearcoatRoughness: 0.18 };
    }
    case 'nervous':
      if (/nerve|plexus|ganglion|cord|root|ramus|trunk|cauda/i.test(name) && !/choroid plexus/i.test(name)) {
        return { kind: KIND.NERVE, color: 0xf0cf5e, roughness: 0.45, clearcoat: 0.3, clearcoatRoughness: 0.3, sheen: 0.5, sheenColor: 0xfff2b0 };
      }
      return organPreset(system, name);
    case 'integumentary':
      if (/hair|eyebrow/i.test(name)) return { kind: KIND.SKIN, color: 0x3a2a22, roughness: 0.6 };
      return { kind: KIND.SKIN, color: 0xe7b594, roughness: 0.5, sheen: 0.5, sheenColor: 0xffd6c0, sheenRoughness: 0.5 };
    default:
      return organPreset(system, name);
  }
}

function organPreset(system, name) {
  const match = ORGAN_COLORS.find(([re]) => re.test(name));
  return {
    kind: KIND.ORGAN,
    color: match ? match[1] : SYSTEM_DEFAULT[system] ?? 0xd09080,
    roughness: 0.42,
    clearcoat: 0.85,
    clearcoatRoughness: 0.18,
  };
}

/**
 * Principal axis of a mesh's vertices (power iteration on the covariance),
 * used as the fibre direction of muscles. Returns an orthonormal basis.
 */
function principalBasis(geometry) {
  const pos = geometry.attributes.position;
  const n = pos.count;
  const stride = Math.max(1, Math.floor(n / 1500));
  let mx = 0, my = 0, mz = 0, c = 0;
  for (let i = 0; i < n; i += stride) { mx += pos.getX(i); my += pos.getY(i); mz += pos.getZ(i); c++; }
  mx /= c; my /= c; mz /= c;
  let xx = 0, xy = 0, xz = 0, yy = 0, yz = 0, zz = 0;
  for (let i = 0; i < n; i += stride) {
    const x = pos.getX(i) - mx, y = pos.getY(i) - my, z = pos.getZ(i) - mz;
    xx += x * x; xy += x * y; xz += x * z; yy += y * y; yz += y * z; zz += z * z;
  }
  const v = new THREE.Vector3(1, 1, 1).normalize();
  for (let k = 0; k < 24; k++) {
    v.set(xx * v.x + xy * v.y + xz * v.z, xy * v.x + yy * v.y + yz * v.z, xz * v.x + yz * v.y + zz * v.z);
    if (v.lengthSq() < 1e-20) { v.set(0, 1, 0); break; }
    v.normalize();
  }
  const helper = Math.abs(v.y) < 0.9 ? new THREE.Vector3(0, 1, 0) : new THREE.Vector3(1, 0, 0);
  const u = new THREE.Vector3().crossVectors(v, helper).normalize();
  const w = new THREE.Vector3().crossVectors(v, u);
  return { axis: v, u, w };
}

// ---- Shader code -------------------------------------------------------------

const NOISE_GLSL = /* glsl */`
varying vec3 vObjPos;
uniform vec3 uRimColor;
uniform float uRimPower;
uniform float uFill;
uniform vec4 uTint;
uniform float uEdgeAlpha;
#ifdef ANAT_DETAIL
uniform vec3 uFiberAxis;
uniform vec3 uFiberU;
uniform vec3 uFiberW;
float anatHash(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.zyx + 31.32);
  return fract((p.x + p.y) * p.z);
}
float anatNoise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(mix(anatHash(i), anatHash(i + vec3(1, 0, 0)), f.x),
        mix(anatHash(i + vec3(0, 1, 0)), anatHash(i + vec3(1, 1, 0)), f.x), f.y),
    mix(mix(anatHash(i + vec3(0, 0, 1)), anatHash(i + vec3(1, 0, 1)), f.x),
        mix(anatHash(i + vec3(0, 1, 1)), anatHash(i + vec3(1, 1, 1)), f.x), f.y),
    f.z);
}
// Fades a feature of [size] metres out once a pixel covers it, so detail never
// shimmers when zoomed out; it appears as the camera gets close.
float anatFade(float size, float px) {
  return 1.0 - smoothstep(size * 0.3, size * 1.1, px);
}
vec3 anatBump(vec3 surfPos, vec3 surfNorm, float h, float faceDirection) {
  vec3 sx = dFdx(surfPos);
  vec3 sy = dFdy(surfPos);
  vec3 r1 = cross(sy, surfNorm);
  vec3 r2 = cross(surfNorm, sx);
  float det = dot(sx, r1) * faceDirection;
  vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
  return normalize(abs(det) * surfNorm - grad);
}
#endif
`;

// Computes albedo tint (anatTint), roughness offset (anatRough) and a height
// in metres (anatHeight) for the bump. Runs right after <color_fragment>.
const DETAIL_GLSL = /* glsl */`
float anatHeight = 0.0;
float anatRough = 0.0;
#ifdef ANAT_DETAIL
{
  vec3 p = vObjPos;
  float px = length(fwidth(p));
  #if ANAT_KIND == 0
    // Bone: soft yellowish blotches, fine porous pits and grain.
    float blotch = anatNoise(p * 38.0) * 0.6 + anatNoise(p * 95.0) * 0.4;
    float grain = anatNoise(p * 420.0);
    float pits = smoothstep(0.62, 0.86, anatNoise(p * 900.0 + 7.0));
    float fGrain = anatFade(0.0024, px);
    float fPits = anatFade(0.0011, px);
    diffuseColor.rgb *= mix(vec3(1.03, 1.0, 0.97), vec3(0.86, 0.79, 0.66), smoothstep(0.35, 0.85, blotch));
    diffuseColor.rgb *= 1.0 - 0.07 * grain * fGrain - 0.22 * pits * fPits;
    anatRough = 0.10 * (blotch - 0.5) + 0.12 * pits * fPits;
    anatHeight = (grain - 0.5) * 0.00018 * fGrain - pits * 0.00022 * fPits;
  #elif ANAT_KIND == 1
    // Muscle: fascicles and fibres running along the muscle's long axis.
    vec3 q = vec3(dot(p, uFiberU), dot(p, uFiberW), dot(p, uFiberAxis));
    float fasc = anatNoise(vec3(q.xy * 260.0, q.z * 7.0));
    float fibre = anatNoise(vec3(q.xy * 1100.0, q.z * 26.0) + 3.1);
    float tone = anatNoise(p * 30.0);
    float fFasc = anatFade(0.004, px);
    float fFibre = anatFade(0.0011, px);
    float groove = smoothstep(0.25, 0.6, fasc);
    diffuseColor.rgb *= mix(0.86, 1.08, tone);
    diffuseColor.rgb *= mix(1.0, 0.8 + 0.2 * groove, fFasc);
    diffuseColor.rgb *= 1.0 + (fibre - 0.5) * 0.18 * fFibre;
    anatRough = -0.12 * (fibre - 0.5) * fFibre + 0.08 * (1.0 - groove) * fFasc;
    anatHeight = (groove - 0.5) * 0.0005 * fFasc + (fibre - 0.5) * 0.00012 * fFibre;
  #elif ANAT_KIND == 6
    // Tendon: tight silvery collagen bands.
    vec3 q = vec3(dot(p, uFiberU), dot(p, uFiberW), dot(p, uFiberAxis));
    float band = anatNoise(vec3(q.xy * 900.0, q.z * 16.0));
    float fBand = anatFade(0.0012, px);
    diffuseColor.rgb *= 1.0 + (band - 0.5) * 0.18 * fBand;
    anatHeight = (band - 0.5) * 0.00012 * fBand;
  #elif ANAT_KIND == 2 || ANAT_KIND == 3 || ANAT_KIND == 4 || ANAT_KIND == 5
    // Soft tissue: gentle mottling and a fine wet bumpiness.
    float mott = anatNoise(p * 45.0) * 0.65 + anatNoise(p * 140.0) * 0.35;
    float fine = anatNoise(p * 650.0);
    float fFine = anatFade(0.0016, px);
    diffuseColor.rgb *= mix(0.9, 1.08, mott);
    anatRough = 0.08 * (mott - 0.5);
    anatHeight = (fine - 0.5) * 0.00012 * fFine + (mott - 0.5) * 0.0003 * anatFade(0.008, px);
  #endif
}
#endif
`;

function injectShader(shader, kind) {
  shader.uniforms.uRimColor = shader.uniforms.uRimColor ?? { value: new THREE.Color(0, 0, 0) };
  shader.vertexShader = shader.vertexShader
    .replace('#include <common>', '#include <common>\nvarying vec3 vObjPos;')
    .replace('#include <begin_vertex>', '#include <begin_vertex>\nvObjPos = position;');
  shader.fragmentShader = shader.fragmentShader
    .replace('#include <common>', `#include <common>\n${NOISE_GLSL}`)
    .replace('#include <color_fragment>', `#include <color_fragment>\n${DETAIL_GLSL}\ndiffuseColor.rgb = mix(diffuseColor.rgb, uTint.rgb, uTint.a);`)
    .replace('#include <roughnessmap_fragment>', '#include <roughnessmap_fragment>\nroughnessFactor = clamp(roughnessFactor + anatRough, 0.04, 1.0);')
    .replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
#ifdef ANAT_DETAIL
normal = anatBump(-vViewPosition, normal, anatHeight, faceDirection);
#endif`)
    .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
{
  vec3 viewDir = normalize(vViewPosition);
  float facing = clamp(abs(dot(normal, viewDir)), 0.0, 1.0);
  totalEmissiveRadiance += uRimColor * (uFill + pow(1.0 - facing, uRimPower) * 2.2);
}`)
    .replace('#include <opaque_fragment>', `#ifndef OPAQUE
{
  // See-through parts read as glassy shells: denser at grazing angles.
  float facing = clamp(abs(dot(normal, normalize(vViewPosition))), 0.0, 1.0);
  float edge = pow(1.0 - facing, 2.0);
  diffuseColor.a = clamp(diffuseColor.a * mix(1.0, mix(0.45, 2.6, edge), uEdgeAlpha), 0.0, 1.0);
}
#endif
#include <opaque_fragment>`);
}

/**
 * Creates the material for one part. [geometry] is used to orient muscle
 * fibres. Returned materials carry `userData.anat` with the rim uniforms.
 */
export function createPartMaterial(system, name, geometry) {
  const p = preset(system, name);
  const physical = (p.clearcoat ?? 0) > 0 || (p.sheen ?? 0) > 0;
  const Ctor = physical ? THREE.MeshPhysicalMaterial : THREE.MeshStandardMaterial;
  const mat = new Ctor({
    color: p.color,
    roughness: p.roughness,
    metalness: 0,
    side: system === 'integumentary' ? THREE.FrontSide : THREE.DoubleSide,
    envMapIntensity: p.kind === KIND.BONE ? 0.85 : 1.0,
  });
  if (physical) {
    mat.userData.full = {
      clearcoat: p.clearcoat ?? 0,
      clearcoatRoughness: p.clearcoatRoughness ?? 0.2,
      sheen: p.sheen ?? 0,
    };
    mat.clearcoatRoughness = p.clearcoatRoughness ?? 0.2;
    if (p.sheen) {
      mat.sheenColor.set(p.sheenColor ?? 0xffffff);
      mat.sheenRoughness = p.sheenRoughness ?? 0.5;
    }
  }
  const anat = {
    kind: p.kind,
    uniforms: {
      uRimColor: { value: new THREE.Color(0, 0, 0) },
      uRimPower: { value: 2.4 },
      uFill: { value: 0 },
      uTint: { value: new THREE.Vector4(0, 0, 0, 0) },
      uEdgeAlpha: { value: system === 'integumentary' ? 1 : 0.85 },
      uFiberAxis: { value: new THREE.Vector3(0, 1, 0) },
      uFiberU: { value: new THREE.Vector3(1, 0, 0) },
      uFiberW: { value: new THREE.Vector3(0, 0, 1) },
    },
  };
  if (p.kind === KIND.MUSCLE || p.kind === KIND.TENDON) {
    const { axis, u, w } = principalBasis(geometry);
    anat.uniforms.uFiberAxis.value.copy(axis);
    anat.uniforms.uFiberU.value.copy(u);
    anat.uniforms.uFiberW.value.copy(w);
  }
  mat.userData.anat = anat;
  mat.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, anat.uniforms);
    injectShader(shader, p.kind);
  };
  applyQuality(mat);
  return mat;
}

function applyQuality(mat) {
  const anat = mat.userData.anat;
  mat.defines = { ANAT_KIND: anat.kind };
  if (settings.detail) mat.defines.ANAT_DETAIL = '';
  const key = `anat${anat.kind}${settings.detail ? 'd' : ''}`;
  mat.customProgramCacheKey = () => key;
  const full = mat.userData.full;
  if (full) {
    // Clearcoat and sheen are the expensive physical lobes; low quality drops them.
    mat.clearcoat = settings.detail ? full.clearcoat : 0;
    mat.sheen = settings.detail ? full.sheen : 0;
  }
  mat.needsUpdate = true;
}

/** Turns procedural detail and the costly physical lobes on or off. */
export function setDetail(enabled, materials) {
  if (settings.detail === enabled) return;
  settings.detail = enabled;
  for (const mat of materials) applyQuality(mat);
}

/**
 * Selection/flash/game glow: a fresnel rim of [color] x [strength] plus a flat
 * emission of [fill] times that colour, and the albedo pulled [tint] (0..1)
 * towards it. A null colour clears it.
 */
export function setGlow(mat, color, strength = 1, fill = 0.25, tint = 0) {
  const u = mat.userData.anat?.uniforms;
  if (!u) return;
  if (!color || strength <= 0) {
    u.uRimColor.value.setRGB(0, 0, 0);
    u.uFill.value = 0;
    u.uTint.value.w = 0;
    return;
  }
  u.uRimColor.value.set(color).multiplyScalar(strength);
  u.uFill.value = fill;
  // Albedo tint keeps the colour readable on bright parts (bone) after tone mapping.
  _c.set(color);
  u.uTint.value.set(_c.r, _c.g, _c.b, tint);
}
const _c = new THREE.Color();
