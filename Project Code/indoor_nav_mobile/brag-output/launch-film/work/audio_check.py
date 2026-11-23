"""Checks the rendered film's soundtrack for dropouts.

Builds a reference mix straight from the <audio> clips in composition/
index.html with ffmpeg (delay, trim, volume, fades), then compares the
render's loudness envelope with it in 50 ms windows. A window where the
reference has sound but the render is near-silent is a dropout.

Usage: python audio_check.py <rendered.mp4>
"""
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

COMP = Path(__file__).resolve().parent.parent / "composition"
html = (COMP / "index.html").read_text(encoding="utf-8")
total = float(re.search(r'data-composition-id="main"[^>]*data-duration="([\d.]+)"', html).group(1))
clips = []
for tag in re.findall(r"<audio [^>]+>", html):
    attr = dict(re.findall(r'([\w-]+)="([^"]*)"', tag))
    clips.append(attr)

SR = 16000


def decode(path, extra=()):
    out = subprocess.run(["ffmpeg", "-v", "error", *extra, "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32)


mix = np.zeros(int(total * SR) + SR, np.float32)
for c in clips:
    start, dur = float(c["data-start"]), float(c.get("data-duration", 0) or 0)
    ms = float(c.get("data-media-start", 0))
    x = decode(COMP / c["src"], ["-ss", str(ms), "-t", str(dur)]) * float(c.get("data-volume", 1))
    n = len(x)
    fi, fo = float(c.get("data-fade-in", 0)), float(c.get("data-fade-out", 0))
    env = np.ones(n, np.float32)
    if fi:
        k = min(n, int(fi * SR)); env[:k] = np.linspace(0, 1, k)
    if fo:
        k = min(n, int(fo * SR)); env[n - k:] = np.linspace(1, 0, k)
    i = int(start * SR)
    mix[i:i + n] += (x * env)[: len(mix) - i]

ren = decode(sys.argv[1])
W = int(0.05 * SR)
m = min(len(ren), len(mix)) // W
rr = np.sqrt((ren[: m * W].reshape(m, W) ** 2).mean(1) + 1e-12)
rm = np.sqrt((mix[: m * W].reshape(m, W) ** 2).mean(1) + 1e-12)
drop = (rm > 0.01) & (rr < rm * 0.15)
print(f"render {len(ren) / SR:.2f}s, reference {total:.2f}s, windows {m}")
print("dropout windows:", int(drop.sum()))
for i in np.where(drop)[0][:40]:
    print(f"  {i * 0.05:6.2f}s  ref {20 * np.log10(rm[i]):6.1f} dB  render {20 * np.log10(rr[i]):6.1f} dB")
corr = np.corrcoef(rr, rm)[0, 1]
print(f"envelope correlation: {corr:.3f}")
peak = np.abs(ren).max()
print(f"render peak {20 * np.log10(peak + 1e-9):.1f} dBFS")
