"""Redraws the floor labels of the app's 3D floor-change view, robustly.

flutter test draws these labels (TextStyle with no family) as box glyphs.
The view cross-fades labels and the lift shaft can hide some boxes, so:
  1. every row of box glyphs is found in every frame;
  2. a row is named only where it is complete (11 boxes = GROUND FLOOR,
     10 boxes = FIRST FLOOR), and that name is carried to the same label in
     nearby frames by tracking its right end (the last letter is always
     visible) and baseline;
  3. every box row is erased; text is drawn only when the name is known,
     right-anchored at the glyph pitch, in the label's own colour (so fading
     labels fade).
Input: frames/sonar (raw capture). Output: frames_fixed/sonar for 9..128.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

W = Path(__file__).resolve().parent
FONT = "C:/Users/Sai/develop/flutter/bin/cache/artifacts/material_fonts/roboto-bold.ttf"
FRAMES = range(9, 129)


def detect(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    gs = np.maximum(g, 1)
    mint = (g > 14) & (r / gs > 0.72) & (b / gs > 0.62) & (r / gs < 0.95)
    solid = ndimage.binary_opening(mint, structure=np.ones((7, 7)))
    lab, _ = ndimage.label(solid)
    boxes = []
    for sl in ndimage.find_objects(lab):
        if sl is None:
            continue
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 12 <= hh <= 36 and 10 <= ww <= 36:
            boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
    rows = []
    for q in sorted(boxes, key=lambda q: (q[1], q[0])):
        for row in rows:
            if abs(q[1] - row[0][1]) < 8 and abs(q[0] - row[-1][0]) < 260:
                row.append(q)
                break
        else:
            rows.append([q])
    out = []
    for rw in rows:
        if len(rw) < 2:
            continue
        rw.sort()
        xs = [q[0] for q in rw]
        steps = [b2 - b1 for b1, b2 in zip(xs, xs[1:]) if 28 < b2 - b1 < 40]
        pitch = float(np.median(steps)) if steps else 33.6
        contiguous = all(28 < b2 - b1 < 2.5 * pitch for b1, b2 in zip(xs, xs[1:]))
        y0, y1 = min(q[1] for q in rw), max(q[3] for q in rw)
        sel = np.zeros(a.shape[:2], bool)
        for q in rw:
            sel[q[1]:q[3], q[0]:q[2]] = True
        ink = a[sel & solid].mean(axis=0) if (sel & solid).any() else np.array([199, 233, 192])
        out.append(dict(n=len(rw), right=max(q[2] for q in rw), last=max(xs), y0=y0, y1=y1, pitch=pitch,
                        bw=int(np.median([q[2] - q[0] for q in rw])), contiguous=contiguous, ink=ink, name=None))
    return out, mint


frames = {}
anchors = {"GROUND FLOOR": {}, "FIRST FLOOR": {}}
for f in FRAMES:
    a = np.asarray(Image.open(W / f"frames/sonar/{f:04d}.png").convert("RGB")).astype(np.float32)
    rows, mint = detect(a)
    frames[f] = (a, rows, mint)
    for rw in rows:
        # an anchor: the whole label seen, every box at the regular pitch
        name = {11: "GROUND FLOOR", 10: "FIRST FLOOR"}.get(rw["n"])
        if name and rw["contiguous"] and 32 <= rw["pitch"] <= 36:
            rw["name"] = name
            anchors[name][f] = rw


def _row(name, last, y0, y1, ink, n):
    return dict(name=name, n=n, last=int(round(last)), right=int(round(last)) + 32, y0=int(round(y0)),
                y1=int(round(y1)), pitch=34.0, bw=32, contiguous=True, ink=np.asarray(ink, float))


# Each label moves smoothly, but wireframe lines crossing its boxes break
# the detection in some frames. Between two anchors (at most 25 frames
# apart) the label is interpolated, so it never jumps.
for f in FRAMES:
    a, rows, mint = frames[f]
    tracked = []
    for name, an in anchors.items():
        n = len(name.replace(" ", ""))
        if f in an:
            tracked.append(an[f])
            continue
        before = [g for g in an if g < f]
        after = [g for g in an if g > f]
        if not before or not after:
            continue
        p, q = max(before), min(after)
        if q - p > 25:
            continue
        t = (f - p) / (q - p)
        lp = lambda k: an[p][k] + (an[q][k] - an[p][k]) * t
        row = _row(name, lp("last"), lp("y0"), lp("y1"), lp("ink"), n)
        # a partial detection of this label (its right end is visible) gives
        # the true position; the interpolation only fills in what is missing
        near = [r for r in rows if r["name"] is None and r["n"] >= 3
                and abs(r["right"] - row["right"]) < 15 and abs(r["y0"] - row["y0"]) < 30]
        if near:
            r = min(near, key=lambda r: abs(r["right"] - row["right"]) + abs(r["y0"] - row["y0"]))
            row.update(last=r["right"] - 32, right=r["right"], y0=r["y0"], y1=r["y1"])
        tracked.append(row)
    # untracked box rows: only a few frames where a label fades in or out
    extra = []
    for rw in rows:
        if rw["name"]:
            continue
        overlaps = any(abs(rw["y0"] - o["y0"]) < 24 and rw["right"] > o["last"] - 11 * 34 - 20
                       and rw["right"] < o["right"] + 40 for o in tracked)
        # boxes of a tracked label (erased, its text is drawn from the track),
        # or a real partial label; tiny faint rows elsewhere are wireframe
        if overlaps or rw["n"] >= 4:
            extra.append(rw)
    frames[f] = (a, tracked + extra, mint)

# 14-26: FIRST FLOOR fades in, so wireframe lines hide some of its boxes.
# Its right end and baseline are taken from each frame's detection; a value
# that jumps away from both neighbours is replaced by their average.
FADE_IN = range(13, 27)
pts = {}
for f in range(13, 28):
    if f in anchors["FIRST FLOOR"]:
        pts[f] = anchors["FIRST FLOOR"][f]
    else:
        rws = [r for r in frames[f][1] if r["name"] is None and r["n"] >= 4]
        if rws:
            pts[f] = rws[0]
# 13: the label's first, faintest frame (not detectable): one step back
pts[13] = dict(pts[14], y0=2 * pts[14]["y0"] - pts[15]["y0"], y1=2 * pts[14]["y1"] - pts[15]["y1"],
               right=2 * pts[14]["right"] - pts[15]["right"], ink=pts[14]["ink"] * 0.6)
right = {f: float(r["right"]) for f, r in pts.items()}
for f in FADE_IN:
    if f - 1 in right and f + 1 in right:
        mid = (right[f - 1] + right[f + 1]) / 2
        if abs(right[f] - mid) > 8:
            right[f] = mid
for f in FADE_IN:
    a, rows, mint = frames[f]
    rows = [r for r in rows if r["name"] != "FIRST FLOOR"]  # GROUND FLOOR, and box rows to erase
    r = pts[f]
    rows.append(_row("FIRST FLOOR", right[f] - 32, r["y0"], r["y1"], r["ink"], 10))
    frames[f] = (a, rows, mint)

# 114-115: the outgoing GROUND FLOOR label is nearly faded out and crosses
# under FIRST FLOOR; it is erased, not redrawn, so the labels never overlap.
for f, t in ((114, 1 / 3), (115, 2 / 3)):
    a, rows, mint = frames[f]
    g0 = anchors["GROUND FLOOR"][113]
    rows.append(_row(None, g0["last"] - 3 * t * 3, 1546 + (1500 - 1546) * t, 1546 + (1500 - 1546) * t + 31,
                     [20, 26, 20], 11))

stats = {"drawn": 0, "erased_only": 0}
for f in FRAMES:
    a, rows, mint = frames[f]
    a = a.copy()
    draws = []
    for rw in rows:
        text = rw["name"]
        cells = len(text) if text else rw["n"] + 1
        start = int(round(rw["last"] - (cells - 1) * rw["pitch"]))
        x0, x1 = max(0, start - 8), min(a.shape[1], rw["right"] + 8)
        y0c, y1c = max(0, rw["y0"] - (12 if text is None else 6)), min(a.shape[0], rw["y1"] + (12 if text is None else 4))
        reg = a[y0c:y1c, x0:x1, :3]
        rg, gg, bb = reg[..., 0], np.maximum(reg[..., 1], 1), reg[..., 2]
        # faint (fading) glyph pixels too, not only the solid ones
        m = mint[y0c:y1c, x0:x1] | ((reg[..., 1] > 9) & (rg / gg > 0.68) & (bb / gg > 0.55) & (rg / gg < 0.97))
        bg = np.median(reg[~m], axis=0) if (~m).any() else np.array([4, 7, 4])
        reg[ndimage.binary_dilation(m, iterations=2)] = bg
        if text:
            draws.append((text, start, (rw["y0"] + rw["y1"]) / 2, rw["y1"] - rw["y0"], tuple(int(v) for v in rw["ink"])))
            stats["drawn"] += 1
        else:
            stats["erased_only"] += 1
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(out)
    for text, x0, cy, box_h, ink in draws:
        size = round(box_h / 0.8)
        font = ImageFont.truetype(FONT, size)
        x = x0
        for ch in text:
            d.text((x, cy), ch, font=font, fill=ink, anchor="lm")
            x += d.textlength(ch, font=font) + size * 0.125
    out.save(W / f"frames_fixed/sonar/{f:04d}.png")
print(stats)
