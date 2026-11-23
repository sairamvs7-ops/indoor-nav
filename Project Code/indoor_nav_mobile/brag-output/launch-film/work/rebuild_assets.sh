#!/usr/bin/env bash
# Rebuilds every app clip and still in composition/assets from the captured
# frames: redraw labels (patch_labels.py), then crop and encode.
set -e
cd "$(dirname "$0")"
A=../composition/assets
rm -rf frames_fixed
python patch_labels.py frames frames_fixed
enc() { ffmpeg -loglevel error -y -framerate 30 -i "frames_fixed/$1/%04d.png" -vf "$2,format=yuv420p" -c:v libx264 -crf 14 -preset slow -g 5 -keyint_min 5 -movflags +faststart "$A/clips/$3.mp4"; }
MAP="crop=1024:576:28:1280"
for s in located pref_stepfree pref_avoidlifts pref_fastest; do enc $s "$MAP" ${s}_map; done
enc first_floor "crop=1024:540:28:1286" first_floor_map
enc sonar "crop=1080:1440:0:520" sonar_big
enc walk "scale=720:1600:flags=lanczos" walk
python - <<'EOF'
from PIL import Image
F, U = "frames_fixed/", "../composition/assets/ui/"
def crop(src, box, dst): Image.open(F + src + ".png").convert("RGB").crop(box).save(U + dst + ".png")
def full(src, dst): Image.open(F + src + ".png").convert("RGB").resize((720, 1600), Image.LANCZOS).save(U + dst + ".png")
crop("nav_start", (28, 935, 1052, 1511), "start_map")
crop("located/0119", (28, 1280, 1052, 1856), "located_map_last")
crop("pref_fastest/0074", (28, 1280, 1052, 1856), "fastest_map_last")
crop("first_floor/0059", (28, 1286, 1052, 1826), "first_floor_map_last")
crop("arrived", (28, 992, 1052, 1532), "arrived_map")
for s in ["home", "picker_open", "picker_1", "picker_10", "picker_104", "destination", "steps", "walk_sheet", "at_lift", "arrived", "editor_map", "editor_map_guide"]:
    full(s, s)
full("located/0030", "located_toast"); full("located/0119", "located_end"); full("walk/0059", "walk_last")
print("stills done")
EOF
echo rebuilt
