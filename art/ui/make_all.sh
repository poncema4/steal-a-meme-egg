#!/usr/bin/env bash
# Renders every character, egg and HUD icon as a sticker icon into art/ui/<kind>/<Name>.png (512 px, transparent).
# Usage: art/ui/make_all.sh        (needs Blender at ~/tools/blender-4.5.14-linux-x64 and the models built: python3 art/brick/build.py)
set -u
cd "$(dirname "$0")/../.."
B=~/tools/blender-4.5.14-linux-x64/blender
TMP=${TMPDIR:-/tmp}/sme-portraits; mkdir -p $TMP
python3 - <<'PY' > $TMP/list.txt
import sys
sys.path.insert(0, "art/brick")
import pets, eggs, icons
for n in pets.RECIPES: print("Pets", n)
for n in eggs.TIERS: print("Eggs", n)
for n in icons.RECIPES: print("Icons", n)
PY
while read kind name; do
  mkdir -p art/ui/$kind
  [ -f art/renders/models/$name.json ] || { echo "no model $name"; continue; }
  nice -n 12 $B -b -P scripts/preview/portrait.py -- art/renders/models/$name.json $TMP/$name.png 20 12 768 >/dev/null 2>&1
  python3 art/ui/stylize.py $TMP/$name.png art/ui/$kind/$name.png 512 && echo "done $kind/$name"
done < $TMP/list.txt
