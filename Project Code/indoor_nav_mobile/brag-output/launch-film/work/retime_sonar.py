"""Retimes the app's own 3D floor-change frames to the narration.

The app's FloorChangeView (lib/ui/floor_change_view.dart) plays 4.2 s in
three phases: swing into the side view (0-30%), travel up the lift
(30-70%), swing back over the new floor (70-100%). The capture holds that
animation in frames ~7.5-133.5 (after the overlay's 0.25 s fade-in; the
frames after 133 are the overlay fading out, which are dropped).

Each phase is stretched to the words that describe it (word times measured
with speech recognition on the voice files):
  g1 "...the app shows you exactly how you get there, in 3D."  -> sonar appears at "the app"
  g2 "Watch the floor map rise into 3D,"  -> phase 1
     "as your dot rides the lift up"      -> phase 2
     "to the next floor."                 -> phase 3
Frames are blended between neighbours for smooth slow motion.

Writes composition/assets/clips/sonar_sync.mp4 and work/sonar_sync.json.
"""
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

W = Path(__file__).resolve().parent
ROOT = W.parent / "composition"


def dur(p):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)],
                                capture_output=True, text=True, check=True).stdout)


G1, GAP = 0.0, 0.25            # g1 at 0 (scene-relative offsets added by the builder)
D1 = dur(ROOT / "assets/vo/g1.wav")
G2 = G1 + D1 + GAP
PAD = 0.12                      # silence before speech in each voice file
SON = G1 + PAD + 2.0            # "the app shows you"
P1 = G2 + PAD + 2.44            # "as your dot rides the lift up"
P2 = G2 + PAD + 4.42            # "to the next floor"
END = G2 + PAD + 5.1 + 0.9      # settle on the new floor a moment after the line
SRC = [8.0, 7.5 + 0.30 * 126, 7.5 + 0.70 * 126, 132.0]   # source frame at each phase boundary
OUT = [SON, P1, P2, END]
FPS = 30
n = int(round((END - SON) * FPS))
frames_dir = W / "frames_fixed/sonar"
out_dir = W / "sonar_sync"
out_dir.mkdir(exist_ok=True)
for f in out_dir.glob("*.png"):
    f.unlink()
cache = {}


def frame(i):
    if i not in cache:
        im = Image.open(frames_dir / f"{i:04d}.png").convert("RGB").crop((0, 520, 1080, 1960))
        cache[i] = np.asarray(im).astype(np.float32)
    return cache[i]


for k in range(n):
    t = SON + k / FPS
    s = float(np.interp(t, OUT, SRC))
    i0 = int(np.floor(s))
    w = s - i0
    a = frame(i0) if w < 1e-3 else frame(i0) * (1 - w) + frame(min(i0 + 1, 139)) * w
    Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(out_dir / f"{k:04d}.png")
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS), "-i", str(out_dir / "%04d.png"),
                "-vf", "format=yuv420p", "-c:v", "libx264", "-crf", "14", "-preset", "slow", "-g", "5", "-keyint_min", "5",
                "-movflags", "+faststart", str(ROOT / "assets/clips/sonar_sync.mp4")], check=True)
info = {"son": round(SON, 3), "p1": round(P1, 3), "p2": round(P2, 3), "end": round(END, 3), "gap": GAP, "frames": n}
(W / "sonar_sync.json").write_text(json.dumps(info, indent=1))
print(info, "phase speeds (x real):",
      [round((SRC[j + 1] - SRC[j]) / FPS / (OUT[j + 1] - OUT[j]), 2) for j in range(3)])
