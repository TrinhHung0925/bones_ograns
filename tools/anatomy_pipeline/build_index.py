"""Builds parts.json from the BodyParts3D 4.0 "is_a" dataset.

Each OBJ element file represents one FMA concept (see its header). This script
assigns every element to a body system using the FMA is_a and part_of trees.

Usage: python3 build_index.py <raw_dir> <out_parts_json>
"""

import collections
import glob
import json
import os
import re
import sys

# Order matters: the first system whose rule matches wins.
SYSTEMS = [
    'skeletal',
    'muscular',
    'cardiovascular',
    'nervous',
    'respiratory',
    'digestive',
    'urinary',
    'reproductive',
    'endocrine',
    'sensory',
    'integumentary',
    'other',
]

# part_of tree roots -> system.
PARTOF_SYSTEM = {
    'cardiovascular system': 'cardiovascular',
    'vasculature of body': 'cardiovascular',
    'nervous system': 'nervous',
    'respiratory system': 'respiratory',
    'alimentary system': 'digestive',
    'urinary system': 'urinary',
    'genital system': 'reproductive',
    'endocrine system': 'endocrine',
}

# Name patterns -> system, checked before anything else to fix FMA misplacements.
NAME_OVERRIDES = [
    (r'hepatovenous segment|caudate lobe of liver|biliary', 'digestive'),
    (r'branches of thoracic aorta', 'cardiovascular'),
    # FMA files the calcaneal tendon under skeletal ligaments; it belongs with its muscles.
    (r'\btendon\b', 'muscular'),
]

# Name patterns -> system, the last resort for parts the FMA trees leave out.
NAME_SYSTEM = [
    (r'epiglottis|conus elasticus|thyrohyoid|vocal ligament|cricothyroid', 'respiratory'),
    (r'skin|hair|eyebrow|^lip$', 'integumentary'),
    (r'eyeball|choroid$|corona ciliaris|cornea|iris|lacrimal|lens|retina\b|sclera'
     r'|vitreous|tarsal plate|check ligament|common tendinous ring|external ear', 'sensory'),
    (r'sternum|manubrium|xiphoid|costal cartilage', 'skeletal'),
    (r'arter|vein|venous|palmar arch|wall of ventricle', 'cardiovascular'),
    (r'nerve|thalamus|choroid plexus|tentorium|interventricular|interpeduncular', 'nervous'),
    (r'inteross|lumbrical|levatores|intertransversarii|interspinales|trapezius'
     r'|tendon|tendinous|iliotibial|linea alba|retinaculum|raphe|interosseous membrane', 'muscular'),
    (r'penis|testis|epididymis|deferent|seminal', 'reproductive'),
    (r'liver|hepat|sublingual|pharyn|oesophag', 'digestive'),
    (r'thymus', 'endocrine'),
]

# is_a ancestors -> system, checked when part_of gives no answer.
ISA_SYSTEM = [
    ('bone organ', 'skeletal'),
    ('tooth', 'skeletal'),
    ('muscle organ', 'muscular'),
    ('head of muscle organ', 'muscular'),
    ('zone of muscle organ', 'muscular'),
    ('region of vascular tree organ', 'cardiovascular'),
    ('heart', 'cardiovascular'),
    ('segment of neuraxis', 'nervous'),
    ('segment of neural tree organ', 'nervous'),
    ('cell part cluster of neuraxis', 'nervous'),
    ('segment of tracheobronchial tree', 'respiratory'),
    ('lung', 'respiratory'),
    ('zone of small intestine', 'digestive'),
    ('cartilage organ', 'skeletal'),
    ('ligament organ', 'skeletal'),
]


def read_tsv(path):
    with open(path, encoding='utf-8') as f:
        return [line.rstrip('\n').split('\t') for line in list(f)[1:]]


def ancestors(parents, concept):
    seen = set()
    stack = [concept]
    while stack:
        for p in parents.get(stack.pop(), ()):
            if p not in seen:
                seen.add(p)
                stack.append(p)
    return seen


def main(raw_dir, out_path):
    names = {}
    isa_parents = collections.defaultdict(set)
    for p, pn, c, cn in read_tsv(os.path.join(raw_dir, 'isa_inclusion_relation_list.txt')):
        isa_parents[c].add(p)
        names[p], names[c] = pn, cn
    partof_parents = collections.defaultdict(set)
    for p, pn, c, cn in read_tsv(os.path.join(raw_dir, 'partof_inclusion_relation_list.txt')):
        partof_parents[c].add(p)
        names[p], names[c] = pn, cn
    # Element -> part_of concepts that contain it.
    partof_concepts = collections.defaultdict(set)
    for c, n, fj in read_tsv(os.path.join(raw_dir, 'partof_element_parts.txt')):
        partof_concepts[fj].add(c)
        names[c] = n
    # Element -> every is_a concept that contains it (already transitively closed).
    isa_concepts = collections.defaultdict(set)
    concept_size = collections.Counter()
    for c, n, fj in read_tsv(os.path.join(raw_dir, 'isa_element_parts.txt')):
        isa_concepts[fj].add(c)
        concept_size[c] += 1
        names[c] = n

    parts = []
    for path in sorted(glob.glob(os.path.join(raw_dir, 'isaobj', '*', '*.obj'))):
        header = {}
        with open(path, encoding='utf-8', errors='replace') as f:
            for _, line in zip(range(30), f):
                m = re.match(r'#\s*([^:]+?)\s*:\s*(.*)', line.strip())
                if m:
                    header[m.group(1)] = m.group(2)
        fj = os.path.splitext(os.path.basename(path))[0]
        # Some headers are blank: fall back to the most specific is_a concept.
        concept = header.get('Concept ID') or min(
            isa_concepts[fj], key=lambda c: (concept_size[c], c))
        name = header.get('English name') or names[concept]

        partof_names = set()
        for c in partof_concepts.get(fj, ()):
            partof_names |= {names.get(a) for a in ancestors(partof_parents, c) | {c}}
        isa_names = {names.get(c) for c in isa_concepts[fj]}
        isa_names |= {names.get(a) for a in ancestors(isa_parents, concept) | {concept}}

        system = None
        for pattern, sys_ in NAME_OVERRIDES:
            if re.search(pattern, name, re.IGNORECASE):
                system = sys_
                break
        # Bones and muscles first: part_of puts some of them under organ systems.
        for key, sys_ in ISA_SYSTEM[:5]:
            if system is None and key in isa_names:
                system = sys_
                break
        if system is None:
            for key, sys_ in PARTOF_SYSTEM.items():
                if key in partof_names:
                    system = sys_
                    break
        if system is None:
            for key, sys_ in ISA_SYSTEM:
                if key in isa_names:
                    system = sys_
                    break
        if system is None:
            for pattern, sys_ in NAME_SYSTEM:
                if re.search(pattern, name, re.IGNORECASE):
                    system = sys_
                    break
        parts.append({
            'id': fj,
            'fma': concept,
            'name': name[:1].upper() + name[1:],
            'system': system or 'other',
            'file': os.path.relpath(path, raw_dir),
        })

    counts = collections.Counter(p['system'] for p in parts)
    for s in SYSTEMS:
        print(f'{s:15} {counts.get(s, 0)}')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(parts, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
