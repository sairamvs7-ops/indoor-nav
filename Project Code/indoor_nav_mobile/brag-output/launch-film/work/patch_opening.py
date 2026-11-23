"""One-off edit of build_scenes.py: new opening scene in the app's map style,
and the vector marker. Kept for the record; build_scenes.py is the source."""
from pathlib import Path

p = Path(__file__).parent / "build_scenes.py"
s = p.read_text(encoding="utf-8")
a = s.index("# ---------------------------------------------------------------- 1 problem")
b = s.index("# ---------------------------------------------------------------- 2 intro")
new = (Path(__file__).parent / "opening_scene.py.txt").read_text(encoding="utf-8")
s = s[:a] + new + s[b:]
s = s.replace('<img src="assets/img/marker13.png" alt="" style="width:100%; height:100%; display:block; image-rendering:pixelated">',
              '<img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block">')
s = s.replace("width:380px; height:380px; background:#fff; padding:34px;", "width:380px; height:380px; background:#fff; padding:8px;")
s = s.replace("width:250px; height:250px; background:#fff; padding:22px;", "width:250px; height:250px; background:#fff; padding:6px;")
s = s.replace('background:#fff; padding:12px; box-sizing:border-box">', 'background:#fff; padding:0; box-sizing:border-box">')
p.write_text(s, encoding="utf-8")
print("svg refs:", s.count("marker13.svg"), "png refs:", s.count("marker13.png"))
