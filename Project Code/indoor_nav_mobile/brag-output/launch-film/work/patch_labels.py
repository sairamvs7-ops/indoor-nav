"""Redraws the labels Flutter's test engine drew as boxes.

`flutter test` renders any text that names no font family in its built-in
box font (FlutterTest). Two of the app's painters label things that way:
room names on the generated map (GeneratedMapPainter._label) and the floor
names in the sonar view (FloorChangeView). On a phone both use the system
font, Roboto. This pass erases the boxes and draws the same text in Roboto
at the size the painter asked for:

* room labels: positions and text come from <frame>.labels.json, written by
  capture_film_test.dart by re-running the painter's own label layout;
* sonar labels: the boxes are found by colour (sonarSoft, #C7E9C0) and
  shape, and are "GROUND FLOOR" / "FIRST FLOOR" (the sample's two floors),
  told apart by their letter count.

Usage: python patch_labels.py <frames_dir> <out_dir>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

FONT_DIR = Path("C:/Users/Sai/develop/flutter/bin/cache/artifacts/material_fonts")
BOLD = FONT_DIR / "roboto-bold.ttf"
MEDIUM = FONT_DIR / "roboto-bold.ttf" if False else FONT_DIR / "roboto-medium.ttf"


def lum(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def wrap(draw, text, font, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font) <= max_w or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines[:2]


def patch_rooms(img, labels):
    a = np.asarray(img).astype(np.float32).copy()
    h, w = a.shape[:2]
    jobs = []
    for lab in labels:
        x0, y0, x1, y1 = lab["box"]
        pad = lab.get("pad", 3)
        x0, y0 = int(max(0, x0 - pad)), int(max(0, y0 - pad))
        x1, y1 = int(min(w, x1 + pad)), int(min(h, y1 + pad))
        if x1 - x0 < 4 or y1 - y0 < 4:
            continue
        reg = a[y0:y1, x0:x1, :3]
        if "ink" in lab:
            ink = np.array(lab["ink"], dtype=np.float32)
            dist = np.abs(reg - ink).sum(axis=2)
            mask = dist < 150
            if lab.get("pad", 3) == 0:  # inside a marker circle only
                yy, xx = np.mgrid[0 : reg.shape[0], 0 : reg.shape[1]]
                cy, cx = (reg.shape[0] - 1) / 2, (reg.shape[1] - 1) / 2
                mask &= (yy - cy) ** 2 + (xx - cx) ** 2 <= (min(reg.shape[:2]) / 2) ** 2
            if mask.mean() < 0.08 or mask.all():
                continue
            bg = np.median(reg[~mask], axis=0)
            reg[ndimage.binary_dilation(mask, iterations=1)] = bg
            a[y0:y1, x0:x1, :3] = reg
            jobs.append((lab, tuple(int(v) for v in ink)))
            continue
        L = lum(reg)
        dark = np.percentile(L, 8)
        bright = np.percentile(L, 95)
        if bright - dark < 40:
            continue  # no boxes visible here (clipped or covered)
        mask = L < (dark + bright) / 2
        if mask.mean() < 0.12:
            continue
        ink = reg[mask].mean(axis=0)
        bg = np.median(reg[L > (dark + bright) / 2 + 10], axis=0) if (L > (dark + bright) / 2 + 10).any() else np.median(reg[~mask], axis=0)
        mask = ndimage.binary_dilation(mask, iterations=1)
        reg[mask] = bg
        a[y0:y1, x0:x1, :3] = reg
        jobs.append((lab, tuple(int(v) for v in ink)))
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(out)
    for lab, ink in jobs:
        # Shrink until every line fits inside the room, like the painter does.
        size = max(6, round(lab["fontPx"]))
        while True:
            font = ImageFont.truetype(str(MEDIUM), size)
            lines = wrap(d, lab["text"], font, lab["maxWidthPx"])
            if size <= 8 or max(d.textlength(l, font=font) for l in lines) <= lab["maxWidthPx"]:
                break
            size -= 1
        lab = {**lab, "fontPx": size}
        lh = lab["fontPx"] * 1.17
        cx, cy = lab["centre"]
        top = cy - lh * len(lines) / 2
        for i, line in enumerate(lines):
            d.text((cx, top + lh * (i + 0.5)), line, font=font, fill=ink, anchor="mm")
    return out


SONAR_NAMES = {11: "GROUND FLOOR", 10: "FIRST FLOOR"}


def patch_sonar(img):
    """Floor-name labels in the sonar view (FIRST FLOOR above, GROUND FLOOR
    below). The lift shaft can merge or hide some of the box glyphs, so a
    label is anchored on its right-most box (always the last letter) and the
    fixed glyph pitch, then every label pixel on that baseline is cleared."""
    a = np.asarray(img).astype(np.float32).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    gs = np.maximum(g, 1)
    mint = (g > 14) & (r / gs > 0.72) & (b / gs > 0.62) & (r / gs < 0.95)  # includes fading labels
    solid = ndimage.binary_opening(mint, structure=np.ones((7, 7)))
    lab, _ = ndimage.label(solid)
    boxes = []
    for sl in ndimage.find_objects(lab):
        if sl is None:
            continue
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if 14 <= hh <= 40 and 10 <= ww <= 40:
            boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
    # group by baseline
    rows = []
    for q in sorted(boxes, key=lambda q: q[1]):
        for row in rows:
            if abs(q[1] - row[0][1]) < 8:
                row.append(q)
                break
        else:
            rows.append([q])
    rows = [sorted(rw) for rw in rows if len(rw) >= 3]
    if not rows:
        return img
    rows.sort(key=lambda rw: rw[0][1])  # top first
    if len(rows) >= 2:
        names = ["FIRST FLOOR", "GROUND FLOOR"] + [None] * (len(rows) - 2)
    else:
        n = len(rows[0])
        names = ["GROUND FLOOR" if n == 11 else "FIRST FLOOR" if n == 10 else None]
    draws = []
    for rw, text in zip(rows, names):
        if text is None:
            continue
        xs = [q[0] for q in rw]
        steps = [b2 - b1 for b1, b2 in zip(xs, xs[1:]) if 25 < b2 - b1 < 45]
        pitch = float(np.median(steps)) if steps else 33.6
        bw = int(np.median([q[2] - q[0] for q in rw]))
        y0, y1 = min(q[1] for q in rw), max(q[3] for q in rw)
        last = max(xs)
        start = int(round(last - (len(text) - 1) * pitch))
        x0, x1 = max(0, start - 6), min(a.shape[1], last + bw + 6)
        y0c, y1c = max(0, y0 - 3), min(a.shape[0], y1 + 3)
        m = mint[y0c:y1c, x0:x1]
        reg = a[y0c:y1c, x0:x1, :3]
        if not m.any():
            continue
        ink = reg[solid[y0c:y1c, x0:x1]].mean(axis=0) if solid[y0c:y1c, x0:x1].any() else reg[m].mean(axis=0)
        bg = np.median(reg[~m], axis=0) if (~m).any() else np.array([4, 7, 4])
        reg[ndimage.binary_dilation(m, iterations=2)] = bg
        draws.append((text, start, (y0 + y1) / 2, y1 - y0, tuple(int(v) for v in ink)))
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(out)
    for text, x0, cy, box_h, ink in draws:
        size = round(box_h / 0.8)
        font = ImageFont.truetype(str(BOLD), size)
        x = x0
        for ch in text:
            d.text((x, cy), ch, font=font, fill=ink, anchor="lm")
            x += d.textlength(ch, font=font) + size * 0.125
    return out


def main(src, dst):
    src, dst = Path(src), Path(dst)
    for png in sorted(src.rglob("*.png")):
        rel = png.relative_to(src)
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        img = Image.open(png).convert("RGB")
        meta = png.with_suffix(".labels.json")
        in_sonar = rel.parts[0] == "sonar"
        # Only where the map is on show (not under the scanner or the sonar overlay).
        if meta.exists() and rel.stem != 'scanner' and np.asarray(img).mean() > 90:
            img = patch_rooms(img, json.loads(meta.read_text()))
        if in_sonar or rel.parts[0] == "first_floor":
            img = patch_sonar(img)
        img.save(out)
    print("patched", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
