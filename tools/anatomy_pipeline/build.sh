#!/usr/bin/env bash
# Rebuilds assets/anatomy from BodyParts3D 4.0 (CC BY-SA 2.1 JP) plus the
# structures it lacks from Z-Anatomy (CC BY-SA 4.0; its non-commercial inner
# ear and kidney models are excluded by build_zanatomy.mjs).
# Raw downloads (~150MB zipped, ~450MB unpacked, +230MB FBX) go to ./raw, which is gitignored.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RAW="$HERE/raw"
OUT="$HERE/../../assets/anatomy"
BASE=https://dbarchive.biosciencedbc.jp/data/bodyparts3d/LATEST
ZBASE=https://raw.githubusercontent.com/LluisV/Z-Anatomy/PC-Version/Resources/Models/FBX

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
mkdir -p "$RAW/zanatomy"
for f in SkeletalSystem100 Joints100 MuscularSystem100 CardioVascular41 \
         LymphoidOrgans100 NervousSystem100 VisceralSystem100; do
  [ -f "$RAW/zanatomy/$f.fbx" ] || curl -fL -o "$RAW/zanatomy/$f.fbx" "$ZBASE/$f.fbx"
done

(cd "$HERE" && npm ci --silent)
python3 -I "$HERE/build_index.py" "$RAW" "$RAW/elements.json"
node --max-old-space-size=8192 "$HERE/build_zanatomy.mjs" "$RAW" "$RAW/elements.json" "$RAW/za_parts.json"
rm -rf "$OUT/models"
node "$HERE/build_glb.mjs" "$RAW" "$RAW/elements.json" "$OUT" "$RAW/za_parts.json" | grep -E 'parts=|parts.json'
python3 -I "$HERE/build_names_vi.py"
