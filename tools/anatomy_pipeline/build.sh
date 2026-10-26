#!/usr/bin/env bash
# Rebuilds assets/anatomy from BodyParts3D 4.0 (CC BY-SA 2.1 JP).
# Raw downloads (~150MB zipped, ~450MB unpacked) go to ./raw, which is gitignored.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RAW="$HERE/raw"
OUT="$HERE/../../assets/anatomy"
BASE=https://dbarchive.biosciencedbc.jp/data/bodyparts3d/LATEST

mkdir -p "$RAW"
for f in isa_inclusion_relation_list.txt isa_element_parts.txt \
         partof_inclusion_relation_list.txt partof_element_parts.txt; do
  [ -f "$RAW/$f" ] || curl -fL -o "$RAW/$f" "$BASE/$f"
done
if [ ! -d "$RAW/isaobj" ]; then
  curl -fL -o "$RAW/isa_obj.zip" "$BASE/isa_BP3D_4.0_obj_99.zip"
  unzip -q "$RAW/isa_obj.zip" -d "$RAW/isaobj"
  rm "$RAW/isa_obj.zip"
fi

(cd "$HERE" && npm ci --silent)
python3 -I "$HERE/build_index.py" "$RAW" "$RAW/elements.json"
rm -rf "$OUT/models"
node "$HERE/build_glb.mjs" "$RAW" "$RAW/elements.json" "$OUT" | grep -E 'parts=|parts.json'
