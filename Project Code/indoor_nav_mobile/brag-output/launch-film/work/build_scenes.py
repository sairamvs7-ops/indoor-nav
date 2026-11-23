"""Writes the Indoor Nav launch film's HyperFrames project.

One scene per file in composition/compositions/, the root composition in
composition/index.html with every narration line, the music and the sound
effects on their own lanes. Re-run after changing timings here; scene files
are plain HTML and can also be edited by hand afterwards (then don't re-run).

Phone screens are real renders of the app (work/capture_film_test.dart),
see ASSET_REQUIREMENTS.md.
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "composition"
COMP = ROOT / "compositions"
COMP.mkdir(parents=True, exist_ok=True)


def dur(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(ROOT / path)],
        capture_output=True, text=True, check=True)
    return round(float(out.stdout.strip()), 3)


# ---------------------------------------------------------------- timeline
SCENES = [  # id, start, duration
    ("problem", 0.0, 10.0),
    ("intro", 10.0, 5.8),
    ("marker", 15.8, 10.2),
    ("routing", 26.0, 18.0),
    ("sonar", 44.0, 13.0),
    ("guidance", 57.0, 9.0),
    ("offline", 66.0, 14.2),
    ("evolution", 80.2, 7.4),
    ("closing", 87.6, 10.0),
]
TOTAL = 97.6

VOICE = [("vo01", 0.6), ("vo02", 5.4), ("vo03", 10.3), ("vo04", 16.0), ("vo05", 21.2), ("vo06", 26.2),
         ("vo07", 28.6), ("vo08", 36.0), ("vo09", 44.2), ("vo10", 51.8), ("vo11", 57.2), ("vo12", 61.8),
         ("vo13", 67.8), ("vo14", 74.3), ("vo15", 80.4), ("vo16", 85.3), ("vo17", 87.9), ("vo18", 93.9)]

SFX = [  # time, file, volume
    (5.8, "switch_002", 0.35), (9.6, "card-shove-1", 0.3), (25.6, "card-shove-1", 0.3), (79.8, "card-shove-1", 0.3), (7.6, "drop_002", 0.45),
    (10.3, "card-slide-1", 0.35), (10.6, "impactSoft_medium_001", 0.45),
    (16.8, "impactWood_medium_001", 0.75), (16.82, "card-place-2", 0.45), (20.4, "card-slide-1", 0.32),
    (23.4, "click_003", 0.55), (23.45, "impactSoft_medium_002", 0.42),
    (26.6, "click2", 0.3), (27.0, "click2", 0.3), (27.4, "click2", 0.3), (28.2, "select_008", 0.45),
    (28.8, "card-slide-1", 0.28),
    (36.4, "click_003", 0.45), (38.9, "click_003", 0.45), (41.4, "click_003", 0.45), (41.6, "drop_002", 0.38),
    # beat-locked: the sonar drop lands on the track's strong cue (media 61.10 s) at 46.80 s
    (46.8, "impactSoft_heavy_003", 0.55), (46.8, "bong_001", 0.5), (48.0, "bong_001", 0.28),
    (51.47, "card-slide-1", 0.28), (53.6, "drop_002", 0.38),
    (57.8, "click2", 0.4), (59.8, "bong_001", 0.3), (61.8, "switch_002", 0.4),
    (62.9, "footstep_wood_002", 0.25), (63.6, "footstep_wood_002", 0.22), (64.3, "footstep_wood_002", 0.2),
    (66.0, "impactSoft_medium_001", 0.4), (68.2, "switch_002", 0.5),
    (69.7, "drop_002", 0.32), (70.6, "drop_002", 0.32), (71.5, "drop_002", 0.32), (72.6, "drop_002", 0.32),
    (77.3, "card-place-2", 0.3), (77.6, "card-slide-1", 0.38),
    (80.6, "card-place-2", 0.32), (81.5, "card-place-2", 0.32), (82.6, "card-place-2", 0.32),
    (85.0, "impactSoft_heavy_003", 0.4), (85.4, "impactWood_medium_001", 0.6),
    (87.9, "drop_002", 0.3), (92.1, "select_008", 0.35), (93.9, "impactBell_heavy_000", 0.5),
]

MUSIC = "assets/music/happy-beats-business-moves-vol-12-by-ende-dot-app.mp3"

# ---------------------------------------------------------------- shared look
CSS = """
#root { position: absolute; inset: 0; overflow: hidden; font-family: Roboto, sans-serif; color: #22301A; }
.bg { position: absolute; inset: 0; background-color: #E5D9C2;
  background-image: linear-gradient(rgba(88,107,69,0.075) 1px, transparent 1px),
                    linear-gradient(90deg, rgba(88,107,69,0.075) 1px, transparent 1px);
  background-size: 54px 54px; }
.kicker { font-size: 28px; font-weight: 700; letter-spacing: 0.16em; text-transform: uppercase; color: #586B45; }
.h1 { font-size: 104px; font-weight: 900; letter-spacing: -0.04em; line-height: 0.98; color: #22301A; }
.h2 { font-size: 64px; font-weight: 800; letter-spacing: -0.03em; line-height: 1.04; color: #22301A; }
.body { font-size: 30px; font-weight: 400; line-height: 1.35; color: #4A5340; }
.green { color: #005A32; }
.olive { color: #586B45; }
.phone { position: absolute; width: 468px; height: 1006px; }
.phone .bezel { position: absolute; inset: 0; border-radius: 60px; background: #161A12;
  box-shadow: 0 40px 80px rgba(34,48,26,0.28), 0 8px 18px rgba(34,48,26,0.18); }
.phone .screen { position: absolute; left: 14px; top: 14px; width: 440px; height: 978px;
  border-radius: 46px; overflow: hidden; background: #E5D9C2; }
.phone .screen > img, .phone .screen > video { position: absolute; left: 0; top: 0; width: 440px; height: 978px; object-fit: cover; }
.chip { display: inline-flex; align-items: center; gap: 14px; padding: 16px 28px; border-radius: 999px;
  border: 2px solid #586B45; background: #F4EDDF; font-size: 30px; font-weight: 700; color: #586B45; }
.chip.on { background: #586B45; color: #FFFFFF; }
.pill { display: inline-block; padding: 8px 18px; border-radius: 999px; font-size: 28px; font-weight: 800;
  letter-spacing: 0.12em; text-transform: uppercase; }
.w { display: inline-block; overflow: hidden; vertical-align: top; padding-bottom: 0.1em; margin-bottom: -0.1em; }
.wi { display: inline-block; }
.card { position: absolute; background: #F4EDDF; border-radius: 28px; box-shadow: 0 18px 40px rgba(34,48,26,0.16); }
"""

COMPASS = ('<svg viewBox="0 0 24 24" width="{s}" height="{s}"><path fill="{c}" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 '
           '10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-5.5-2.5l7.51-3.49L17.5 '
           '6.5 9.99 9.99 6.5 17.5zm5.5-6.6c.61 0 1.1.49 1.1 1.1s-.49 1.1-1.1 1.1-1.1-.49-1.1-1.1.49-1.1 1.1-1.1z"/></svg>')


def phone(pid, x, y, screens, extra=""):
    """screens: list of (id, src, start, duration, kind) inside one phone."""
    items = []
    for sid, src, start, d, kind in screens:
        if kind == "video":
            items.append(f'<video id="{sid}" class="clip" data-start="{start}" data-duration="{d}" '
                         f'data-track-index="2" muted playsinline src="{src}"></video>')
        else:
            items.append(f'<img id="{sid}" class="clip" data-start="{start}" data-duration="{d}" '
                         f'data-track-index="2" src="{src}" alt="">')
    PHONES.append(pid)
    return (f'<div id="{pid}" class="phone" style="left:{x}px; top:{y}px"><div id="{pid}-f" style="position:absolute; inset:0">'
            f'<div id="{pid}-bezel" class="bezel"></div><div class="screen">{"".join(items)}{extra}</div></div></div>')


PHONES = []


def K(text):
    """Kinetic headline markup: words in masks. '|' breaks a line, *word* is green."""
    out = []
    for li, line in enumerate(text.split("|")):
        if li:
            out.append("<br>")
        for w in line.split(" "):
            green = w.startswith("*")
            w = w.strip("*")
            cls = ' class="wi green"' if green else ' class="wi"'
            out.append(f'<span class="w"><span{cls}>{w}</span></span> ')
    return "".join(out).strip()


def kin(sel, t, stagger=0.07):
    """Reveal a K() headline word by word, rising out of its masks."""
    return (f'    tl.set("{sel}", {{ opacity: 1 }}, {t});\n'
            f'    tl.fromTo("{sel} .wi", {{ yPercent: 115 }}, {{ yPercent: 0, duration: 0.7, ease: "expo.out", stagger: {stagger} }}, {t});\n')


def scene(sid, dur_s, body, script, css="", wipe_in=False, wipe_out=False):
    """One scene file. Adds the shared depth layer (two soft drifting glows),
    a gentle float on every phone, and optional brand-green act wipes."""
    phones, PHONES[:] = list(PHONES), []
    extra = ""
    extra += '    tl.fromTo("#bl1", { x: -60, y: 0 }, { x: 80, y: 40, duration: %s, ease: "sine.inOut" }, 0);\n' % dur_s
    extra += '    tl.fromTo("#bl2", { x: 40, y: 20 }, { x: -70, y: -30, duration: %s, ease: "sine.inOut" }, 0);\n' % dur_s
    reps = max(0, int(dur_s / 2.4) - 1)
    for pid in phones:
        extra += f'    tl.fromTo("#{pid}-f", {{ y: 0 }}, {{ y: -12, duration: 2.4, ease: "sine.inOut", yoyo: true, repeat: {reps} }}, 0);\n'
    wipe = ""
    if wipe_in:
        wipe += '<div id="wipe-in" style="position:absolute; inset:0; background:#005A32; z-index:50"></div>'
        extra += '    tl.fromTo("#wipe-in", { xPercent: 0 }, { xPercent: 101, duration: 0.55, ease: "expo.inOut" }, 0);\n'
    if wipe_out:
        wipe += '<div id="wipe-out" style="position:absolute; inset:0; background:#005A32; z-index:50"></div>'
        extra += f'    tl.fromTo("#wipe-out", {{ xPercent: -101 }}, {{ xPercent: 0, duration: 0.4, ease: "expo.in" }}, {dur_s - 0.42:.2f});\n'
    html = f"""<template>
  <style>
{CSS}
{css}
  </style>
  <div id="root" data-composition-id="{sid}" data-width="1920" data-height="1080" data-duration="{dur_s}">
    <div class="bg"></div>
    <div id="bl1" data-layout-ignore style="position:absolute; left:-200px; top:-260px; width:1100px; height:1100px; border-radius:50%; background:radial-gradient(circle, rgba(88,107,69,0.16), rgba(88,107,69,0) 65%)"></div>
    <div id="bl2" data-layout-ignore style="position:absolute; left:1100px; top:380px; width:1100px; height:1100px; border-radius:50%; background:radial-gradient(circle, rgba(0,90,50,0.10), rgba(0,90,50,0) 65%)"></div>
{body}
    {wipe}
  </div>
  <script>
    const tl = gsap.timeline({{ paused: true }});
{extra}{script}
    window.__timelines["{sid}"] = tl;
  </script>
</template>
"""
    (COMP / f"{sid}.html").write_text(html, encoding="utf-8")


def show(sel, t, y=24, d=0.55, ease="power3.out"):
    return (f'    tl.fromTo("{sel}", {{ opacity: 0, y: {y} }}, '
            f'{{ opacity: 1, y: 0, duration: {d}, ease: "{ease}" }}, {t});\n')


def hide(sel, t, d=0.35):
    return f'    tl.to("{sel}", {{ opacity: 0, duration: {d}, ease: "power2.in" }}, {t});\n'


# ---------------------------------------------------------------- 1 problem
# One floor only: the sample's ground floor, drawn the way the app draws a
# generated map (GeneratedMapPainter, light MapStyle) from the reviewed
# regions that dump_test.dart wrote to regions.json. The lost dot wanders
# along this floor's real corridor centreline.
REG = json.loads((Path(__file__).parent / "regions.json").read_text())
g0 = REG["floor0"]
SC = 1080 / 770
MAP_H = 445 * SC


def poly(o):
    return " ".join(f"{x * SC:.1f},{y * SC:.1f}" for x, y in o)


names = {n["region"]: n["name"] for n in g0["nodes"] if n["region"]}
msvg = [f'<svg width="1080" height="{MAP_H:.0f}" viewBox="0 0 1080 {MAP_H:.0f}"><rect width="1080" height="{MAP_H:.0f}" fill="#FBF6EC"/>']
regs = [r for r in g0["regions"] if r["kind"] != "ignored"]
for r in sorted(regs, key=lambda r: r["kind"] != "corridor"):
    pts = poly(r["outline"])
    if r["kind"] == "corridor":
        msvg.append(f'<polygon points="{pts}" fill="#F1E8D4" stroke="#C9B993" stroke-width="3"/>')
    elif r["kind"] == "stairs":
        x0, y0, x1, y1 = [v * SC for v in r["bbox"]]
        cid = "st-" + r["id"]
        msvg.append(f'<clipPath id="{cid}"><polygon points="{pts}"/></clipPath>')
        msvg.append(f'<polygon points="{pts}" fill="rgba(183,121,31,0.14)"/>')
        steps = "".join(f'<line x1="{x0:.0f}" y1="{y0 + k * 14:.1f}" x2="{x1:.0f}" y2="{y0 + k * 14:.1f}"/>'
                        for k in range(1, int((y1 - y0) / 14) + 1))
        msvg.append(f'<g clip-path="url(#{cid})" stroke="#B7791F" stroke-width="3">{steps}</g>')
        msvg.append(f'<polygon points="{pts}" fill="none" stroke="#B7791F" stroke-width="4"/>')
    else:
        msvg.append(f'<polygon points="{pts}" fill="#E3E8D3" stroke="#586B45" stroke-width="4" stroke-linejoin="round"/>')
for r in regs:
    nm = names.get(r["id"])
    if not nm:
        continue
    x0, y0, x1, y1 = [v * SC for v in r["bbox"]]
    fs = min(28, max(18, min(x1 - x0, y1 - y0) / 5))
    words = nm.split(" ")
    lines = [nm] if len(nm) * fs * 0.55 < (x1 - x0) * 0.9 else [" ".join(words[:-1]), words[-1]]
    cy = (y0 + y1) / 2 + 10 - (len(lines) - 1) * fs * 0.6
    for i, ln in enumerate(lines):
        msvg.append(f'<text x="{(x0 + x1) / 2:.1f}" y="{cy + i * fs * 1.2:.1f}" text-anchor="middle" font-family="Roboto" '
                    f'font-weight="700" font-size="{fs:.0f}" fill="#2B3320">{ln}</text>')
msvg.append("</svg>")
corr = max((r for r in g0["regions"] if r["kind"] == "corridor"),
           key=lambda r: (r["bbox"][2] - r["bbox"][0]) * (r["bbox"][3] - r["bbox"][1]))
main = max(corr["paths"], key=len)
MX, MY = 740, 250  # the map's top-left on screen (inside its card)


def at(f):
    x, y = main[min(int(len(main) * f), len(main) - 1)]
    return MX + x * SC - 22, MY + y * SC - 22


# Lost: up and down the main corridor of this one floor (drawing pixels).
WALK = [(110, 150), (210, 222), (390, 224), (300, 222), (520, 224), (610, 222), (450, 224), (650, 236), (540, 222)]
path = [(MX + x * SC - 22, MY + y * SC - 22) for x, y in WALK]
body = f"""
    <div id="p-card" class="card" data-layout-ignore style="left:{MX - 20}px; top:{MY - 20}px; width:1120px; height:{MAP_H + 40:.0f}px; padding:20px">
      {''.join(msvg)}
    </div>
    <div id="p-floor" class="kicker" style="position:absolute; left:{MX}px; top:{MY + MAP_H + 36:.0f}px">Ground Floor</div>
    <div id="p-dotwrap" style="position:absolute; left:0; top:0; width:1920px; height:1080px">
      <div id="p-dot" data-layout-allow-overflow style="position:absolute; left:0; top:0; width:44px; height:44px; opacity:0">
        <div style="position:absolute; inset:-22px; border-radius:50%; background:rgba(29,78,216,0.18)"></div>
        <div style="position:absolute; inset:0; border-radius:50%; background:#1D4ED8; border:5px solid #fff; box-shadow:0 4px 10px rgba(0,0,0,0.25)"></div>
        <div id="p-q" style="position:absolute; left:40px; top:-62px; width:56px; height:56px; border-radius:50%; background:#F4EDDF; color:#DC2626; font-size:38px; font-weight:900; display:flex; align-items:center; justify-content:center; box-shadow:0 6px 14px rgba(0,0,0,0.18); opacity:0">?</div>
      </div>
    </div>
    <div id="p-target" class="card" style="left:120px; top:180px; padding:22px 34px">
      <div class="kicker">Looking for</div>
      <div style="font-size:44px; font-weight:800; margin-top:6px">Room 104 <span class="olive" style="font-weight:500">· First Floor</span></div>
    </div>
    <div id="p-gps" class="card" style="left:120px; top:390px; padding:20px 30px; display:flex; align-items:center; gap:18px; opacity:0">
      <svg width="44" height="44" viewBox="0 0 24 24"><path fill="#586B45" d="M12 8c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm8.94 3A8.994 8.994 0 0 0 13 3.06V1h-2v2.06A8.994 8.994 0 0 0 3.06 11H1v2h2.06A8.994 8.994 0 0 0 11 20.94V23h2v-2.06A8.994 8.994 0 0 0 20.94 13H23v-2h-2.06zM12 19c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z"/></svg>
      <div style="position:relative; width:420px; height:44px">
        <div id="p-gps-a" style="position:absolute; left:0; top:2px; font-size:34px; font-weight:700; color:#586B45">Searching for GPS<span id="p-d1">.</span><span id="p-d2">.</span><span id="p-d3">.</span></div>
        <div id="p-gps-b" style="position:absolute; left:0; top:2px; font-size:34px; font-weight:800; color:#DC2626; opacity:0">No GPS signal indoors</div>
      </div>
    </div>
    <div id="p-head" class="h1" style="position:absolute; left:120px; top:650px; width:600px; opacity:0">{K("GPS stops|at the *door.*")}</div>
"""
script = '    tl.fromTo("#p-card", { scale: 1.0, transformOrigin: "60% 50%" }, { scale: 1.04, duration: 10, ease: "none" }, 0);\n'
script += f'    tl.set("#p-dot", {{ x: {path[0][0]:.0f}, y: {path[0][1]:.0f}, opacity: 1 }}, 0);\n'
t = 1.0
for (x, y) in path[1:]:
    script += f'    tl.to("#p-dot", {{ x: {x:.0f}, y: {y:.0f}, duration: 0.8, ease: "power1.inOut" }}, {t:.2f});\n'
    t += 0.9
script += '    tl.fromTo("#p-q", { opacity: 0, scale: 0.4 }, { opacity: 1, scale: 1, duration: 0.4, ease: "back.out(2)" }, 2.0);\n'
script += show("#p-gps", 1.6)
script += '    tl.set(["#p-d1", "#p-d2", "#p-d3"], { opacity: 0.25 }, 0);\n'
for i, t0 in enumerate([2.0, 2.3, 2.6, 3.2, 3.5, 3.8, 4.4, 4.7, 5.0]):
    d = f"#p-d{i % 3 + 1}"
    script += f'    tl.to("{d}", {{ opacity: 1, duration: 0.15 }}, {t0});\n'
    script += f'    tl.to("{d}", {{ opacity: 0.25, duration: 0.15 }}, {t0 + 0.3:.2f});\n'
script += hide("#p-gps-a", 5.75, 0.2)
script += '    tl.fromTo("#p-gps-b", { opacity: 0, x: -12 }, { opacity: 1, x: 0, duration: 0.3, ease: "power2.out" }, 5.85);\n'
script += kin("#p-head", 7.6, 0.08)
scene("problem", 10.0, body, script, wipe_out=True)

# ---------------------------------------------------------------- 2 intro
body = f"""
    <div id="i-mark" style="position:absolute; left:150px; top:300px; display:flex; align-items:center; gap:30px; opacity:0">
      {COMPASS.format(s=150, c="#005A32")}
      <div style="font-size:150px; font-weight:900; letter-spacing:-0.045em; color:#005A32">Indoor Nav</div>
    </div>
    <div id="i-tag" class="h2" style="position:absolute; left:156px; top:520px; opacity:0">{K("Find your way indoors")}</div>
    <div id="i-src" style="position:absolute; left:158px; top:620px; font-size:28px; color:#586B45; opacity:0">— the app's own home screen</div>
    {phone("i-phone", 1200, 37, [("i-home", "assets/ui/home.png", 0, 5.8, "img")])}
"""
script = '    tl.fromTo("#i-phone", { y: 260, opacity: 0, rotation: 4 }, { y: 0, opacity: 1, rotation: 0, duration: 0.9, ease: "expo.out" }, 0.3);\n'
script += '    tl.fromTo("#i-mark", { opacity: 0, scale: 0.92, transformOrigin: "left center" }, { opacity: 1, scale: 1, duration: 0.7, ease: "expo.out" }, 0.6);\n'
script += kin("#i-tag", 1.3) + show("#i-src", 2.0, 10)
script += '    tl.to("#i-phone", { y: -26, duration: 4.4, ease: "sine.inOut" }, 1.3);\n'
scene("intro", 5.8, body, script, wipe_in=True)

# ---------------------------------------------------------------- 3 marker
# Scanner frame inside the 396x880 screen (measured from the real scanner screen).
KS = 440 / 396
# The app's scan frame: x 240-839, y 700-1299 in the 1080x2400 render.
R = 440 / 1080
fx, fy, fw, fh = 240 * R, 700 * R, 600 * R, 600 * R
mk = 150
mx, my = fx + (fw - mk) / 2, fy + (fh - mk) / 2
# The test camera is black, so the viewfinder shows a composited wall with the
# printed marker in the scan frame; the app's real scanner overlay (frame,
# close button, hint) sits on top with its black preview made transparent.
extra = f"""<div id="m-cam" class="clip" data-start="4.4" data-duration="3.8" data-track-index="3"
        style="position:absolute; left:0; top:0; width:440px; height:978px; overflow:hidden;
        background:radial-gradient(ellipse 420px 620px at 50% 38%, #E2D6BE, #B9AB8E 75%, #8E826B)">
        <div id="m-mk" style="position:absolute; left:{mx:.1f}px; top:{my:.1f}px; width:{mk}px; height:{mk}px; box-shadow:0 8px 18px rgba(0,0,0,0.25)">
          <img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block"></div></div>
      <img id="m-ui" class="clip" data-start="4.4" data-duration="3.8" data-track-index="4" src="assets/ui/scanner_ui.png" alt=""
        style="position:absolute; left:0; top:0; width:440px; height:978px">
      <div id="m-lock" class="clip" data-start="7.5" data-duration="0.7" data-track-index="5"
        style="position:absolute; left:{fx:.1f}px; top:{fy:.1f}px; width:{fw:.0f}px; height:{fh:.0f}px; border:5px solid #C7E9C0; border-radius:22px; box-shadow:0 0 24px rgba(199,233,192,0.9)"></div>"""
body = f"""
    <div id="m-wall" style="position:absolute; left:110px; top:90px; width:760px; height:640px; border-radius:26px;
      background:linear-gradient(160deg,#F4EDDF,#EADFC9); box-shadow: inset 0 0 0 2px rgba(88,107,69,0.12)"></div>
    <div id="m-paper" style="position:absolute; left:300px; top:170px; width:380px; height:380px; background:#fff; padding:8px; box-sizing:border-box;
      box-shadow:0 22px 44px rgba(34,48,26,0.22); opacity:0">
      <img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block">
    </div>
    <div id="m-label" style="position:absolute; left:300px; top:568px; width:520px; opacity:0">
      <div class="kicker">Printed ArUco marker</div>
      <div style="font-size:30px; font-weight:700; margin-top:8px">Marker 13 · Entry 1</div>
    </div>
    <div id="m-tag" class="card" style="left:300px; top:660px; padding:18px 26px; opacity:0">
      <div class="kicker">Read on the phone</div>
      <div style="font-size:28px; font-weight:800; margin-top:4px">OpenCV · no network</div>
    </div>
    <div id="m-head" class="h2" style="position:absolute; left:150px; top:800px; width:960px; opacity:0">{K("Scan a marker.|*Know* *where* *you* *are.*")}</div>
    {phone("m-phone", 1300, 37, [("m-here", "assets/ui/located_toast.png", 8.2, 2.0, "img")], extra)}
"""
script = '    tl.fromTo("#m-paper", { opacity: 0, scale: 1.4, rotation: -11 }, { opacity: 1, scale: 1, rotation: -3, duration: 0.32, ease: "power4.in" }, 0.68);\n'
script += '    tl.fromTo("#m-paper", { y: 0 }, { y: 4, duration: 0.12, yoyo: true, repeat: 1, ease: "power1.out" }, 1.0);\n'
script += show("#m-label", 1.6)
script += '    tl.fromTo("#m-phone", { x: 520, opacity: 0 }, { x: 0, opacity: 1, duration: 0.9, ease: "expo.out" }, 4.4);\n'
script += '    tl.fromTo("#m-mk", { x: 8, y: -6, rotation: 2.5 }, { x: -3, y: 3, rotation: -0.5, duration: 3.0, ease: "sine.inOut" }, 4.4);\n'
script += show("#m-tag", 6.0, 14)
script += '    tl.fromTo("#m-lock", { opacity: 0, scale: 1.12 }, { opacity: 1, scale: 1, duration: 0.25, ease: "back.out(2)" }, 7.5);\n'
script += kin("#m-head", 8.1, 0.05)
scene("marker", 10.2, body, script, wipe_out=True)

# ---------------------------------------------------------------- 4 routing
# The phone's own map region (x 28-1052, y 1280-1856 of the 1080x2400 render)
# flies out of the phone to fill the frame, so the real route is legible.
PX, PY = 726, 37                     # phone position in this scene
RS = 440 / 1080                      # render px -> screen px
MAPX, MAPY = PX + 14 + 28 * RS, PY + 14 + 1280 * RS
MAPW = 1024 * RS
BX, BY, BW, BH = 240, 210, 1440, 810  # the big map panel
screens = [
    ("r-p0", "assets/ui/picker_open.png", 0, 0.6, "img"), ("r-p1", "assets/ui/picker_1.png", 0.6, 0.4, "img"),
    ("r-p2", "assets/ui/picker_10.png", 1.0, 0.4, "img"), ("r-p3", "assets/ui/picker_104.png", 1.4, 0.8, "img"),
    ("r-dest", "assets/ui/destination.png", 2.2, 1.4, "img"),
]
nodes = {"S": (60, 230), "a": (170, 120), "b": (180, 300), "c": (300, 210), "d": (310, 60), "e": (420, 300),
         "f": (440, 140), "g": (560, 220), "G": (660, 110)}
edges = [("S", "a"), ("S", "b"), ("a", "c"), ("b", "c"), ("a", "d"), ("c", "f"), ("c", "e"), ("d", "f"), ("e", "g"), ("f", "g"), ("f", "G"), ("g", "G")]
best = [("S", "a"), ("a", "c"), ("c", "f"), ("f", "G")]
svg = ['<svg width="1440" height="720" viewBox="0 0 720 360">',
       '<defs><clipPath id="r-clip"><rect x="0" y="0" width="720" height="360"/></clipPath></defs><g clip-path="url(#r-clip)">',
       '<circle id="r-fs" cx="60" cy="230" r="10" fill="rgba(29,78,216,0.10)" stroke="#1D4ED8" stroke-width="1.5"/>',
       '<circle id="r-fg" cx="660" cy="110" r="10" fill="rgba(220,38,38,0.08)" stroke="#DC2626" stroke-width="1.5"/></g>']
for a, b in edges:
    (x1, y1), (x2, y2) = nodes[a], nodes[b]
    svg.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#C9B993" stroke-width="3" stroke-linecap="round"/>')
for i, (a, b) in enumerate(best):
    (x1, y1), (x2, y2) = nodes[a], nodes[b]
    L = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
    svg.append(f'<line id="r-b{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#005A32" stroke-width="7" stroke-linecap="round" '
               f'stroke-dasharray="{L:.1f}" stroke-dashoffset="{L:.1f}"/>')
for n, (x, y) in nodes.items():
    fill = "#1D4ED8" if n == "S" else "#DC2626" if n == "G" else "#F4EDDF"
    svg.append(f'<circle cx="{x}" cy="{y}" r="{13 if n in "SG" else 9}" fill="{fill}" stroke="#586B45" stroke-width="2.5"/>')
svg.append('<text x="60" y="275" text-anchor="middle" font-family="Roboto" font-weight="800" font-size="16" fill="#1D4ED8">YOU</text>')
svg.append('<text x="660" y="80" text-anchor="middle" font-family="Roboto" font-weight="800" font-size="16" fill="#DC2626">ROOM 104</text>')
svg.append("</svg>")
chips = "".join(f'<span id="r-c{i}" class="chip" style="font-size:28px; padding:12px 24px">{t}</span>'
                for i, t in enumerate(["Fastest", "Step-free", "Avoid lifts"]))
body = f"""
    {phone("r-phone", PX, PY, screens)}
    <div id="r-a" style="position:absolute; left:120px; top:380px; width:560px; opacity:0">
      <div class="kicker">Destination</div>
      <div id="r-ah" class="h2" style="margin-top:16px; font-size:72px">{K("Search for|where you're|going.")}</div>
    </div>
    <div id="r-big" class="card" style="left:{BX}px; top:{BY}px; width:{BW}px; height:{BH}px; overflow:hidden; opacity:0">
      <video id="r-loc" class="clip" data-start="2.6" data-duration="4.0" data-track-index="3" muted playsinline src="assets/clips/located_map.mp4" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover"></video>
      <video id="r-sf" class="clip" data-start="10.4" data-duration="2.5" data-track-index="3" muted playsinline src="assets/clips/pref_stepfree_map.mp4" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover"></video>
      <video id="r-al" class="clip" data-start="12.9" data-duration="2.5" data-track-index="3" muted playsinline src="assets/clips/pref_avoidlifts_map.mp4" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover"></video>
      <video id="r-fa" class="clip" data-start="15.4" data-duration="2.5" data-track-index="3" muted playsinline src="assets/clips/pref_fastest_map.mp4" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover"></video>
      <img id="r-hold" class="clip" data-start="6.6" data-duration="3.8" data-track-index="3" src="assets/ui/fastest_map_last.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover">
    </div>
    <div id="r-graph" class="card" style="left:{BX}px; top:{BY}px; width:{BW}px; height:{BH}px; opacity:0; display:flex; flex-direction:column; align-items:center; justify-content:center">
      {''.join(svg)}
    </div>
    <div id="r-b" style="position:absolute; left:{BX}px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Routing · on the device</div>
      <div id="r-bh" class="h2" style="margin-top:10px; font-size:60px">{K("The shortest way, *worked* *out* *on* *the* *phone.*")}</div>
    </div>
    <div id="r-g" style="position:absolute; left:{BX}px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Corrected bidirectional Dijkstra</div>
      <div id="r-gh" class="h2" style="margin-top:10px; font-size:60px">{K("One search from you. One from the room. *They* *meet.*")}</div>
    </div>
    <div id="r-c" style="position:absolute; left:{BX}px; top:70px; width:1500px; opacity:0; display:flex; align-items:flex-end; justify-content:space-between">
      <div><div class="kicker">Route preferences</div>
        <div id="r-q" class="h2" style="margin-top:10px; font-size:60px">{K("Can everyone find their way?")}</div></div>
      <div style="display:flex; gap:14px; margin-bottom:6px">{chips}</div>
    </div>
    <div id="r-note" class="card" style="left:{BX + BW - 560}px; top:{BY + BH - 110}px; padding:16px 26px; font-size:28px; font-weight:700; opacity:0">Avoid lifts → the route takes Stairs 2</div>
    <div id="r-d" style="position:absolute; left:{BX}px; top:70px; width:1500px; opacity:0">
      <div id="r-dh" class="h2" style="font-size:64px">{K("One building. Multiple floors. *Intelligent* *routing.*")}</div>
    </div>
"""
k0 = MAPW / BW
script = '    tl.fromTo("#r-phone", { y: 60, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6, ease: "expo.out" }, 0);\n'
script += show("#r-a", 0.1, 0, 0.01) + kin("#r-ah", 0.15)
script += hide("#r-a", 2.3, 0.3)
# the map flies out of the phone (beat: the route starts drawing)
script += f'    tl.fromTo("#r-big", {{ opacity: 0, x: {MAPX - BX:.1f}, y: {MAPY - BY:.1f}, scale: {k0:.4f}, transformOrigin: "0 0", borderRadius: 4 }}, ' \
          f'{{ opacity: 1, x: 0, y: 0, scale: 1, borderRadius: 28, duration: 0.9, ease: "expo.inOut" }}, 2.6);\n'
script += '    tl.to("#r-phone", { opacity: 0, scale: 1.25, duration: 0.7, ease: "power2.in" }, 2.6);\n'
script += show("#r-b", 3.2, 0, 0.01) + kin("#r-bh", 3.25, 0.05)
script += '    tl.fromTo("#r-big", { scale: 1 }, { scale: 1.035, duration: 3.6, ease: "none" }, 3.5);\n'
script += hide("#r-b", 6.6, 0.3) + hide("#r-big", 6.7, 0.4)
script += '    tl.fromTo("#r-graph", { opacity: 0, scale: 0.97 }, { opacity: 1, scale: 1, duration: 0.5, ease: "expo.out" }, 6.8);\n'
script += show("#r-g", 6.9, 0, 0.01) + kin("#r-gh", 6.95, 0.05)
script += '    tl.fromTo("#r-fs", { attr: { r: 10 } }, { attr: { r: 330 }, duration: 2.0, ease: "power1.out" }, 7.2);\n'
script += '    tl.fromTo("#r-fg", { attr: { r: 10 } }, { attr: { r: 330 }, duration: 2.0, ease: "power1.out" }, 7.2);\n'
for i in range(4):
    script += f'    tl.to("#r-b{i}", {{ strokeDashoffset: 0, duration: 0.3, ease: "power1.inOut" }}, {8.6 + i * 0.3:.2f});\n'
script += hide("#r-g", 10.0, 0.3) + hide("#r-graph", 10.0, 0.3)
script += '    tl.to("#r-big", { opacity: 1, scale: 1, duration: 0.4, ease: "expo.out" }, 10.2);\n'
script += show("#r-c", 10.2, 0, 0.01) + kin("#r-q", 10.25, 0.05)
script += '    tl.set("#r-c0", { backgroundColor: "#586B45", color: "#FFFFFF" }, 10.2);\n'
for t, on, off in [(10.4, "#r-c1", "#r-c0"), (12.9, "#r-c2", "#r-c1"), (15.4, "#r-c0", "#r-c2")]:
    script += f'    tl.to("{on}", {{ backgroundColor: "#586B45", color: "#FFFFFF", scale: 1.06, duration: 0.18 }}, {t});\n'
    script += f'    tl.to("{on}", {{ scale: 1, duration: 0.25 }}, {t + 0.18:.2f});\n'
    script += f'    tl.to("{off}", {{ backgroundColor: "#F4EDDF", color: "#586B45", duration: 0.18 }}, {t});\n'
script += show("#r-note", 13.4, 16, 0.4) + hide("#r-note", 15.2, 0.25)
script += hide("#r-c", 15.4, 0.3)
script += show("#r-d", 15.6, 0, 0.01) + kin("#r-dh", 15.65, 0.06)
scene("routing", 18.0, body, script, wipe_in=True)

# ---------------------------------------------------------------- 5 sonar
# The camera dives into the phone; the app's own floor-change view, cropped
# to its content (y 520-1960 of the render), fills the frame height.
rings = "".join(f'<div id="s-ring{i}" style="position:absolute; left:960px; top:540px; width:400px; height:400px; margin:-200px 0 0 -200px; border-radius:50%; border:3px solid #89E900; opacity:0"></div>' for i in range(3))
body = f"""
    <div id="s-night" style="position:absolute; inset:0; background:radial-gradient(ellipse 900px 700px at 960px 540px, #0B1408, #040704 70%); opacity:0"></div>
    {rings}
    <div id="s-glow" style="position:absolute; left:960px; top:540px; width:1200px; height:1200px; margin:-600px 0 0 -600px; border-radius:50%; background:radial-gradient(circle, rgba(137,233,0,0.22), rgba(137,233,0,0) 62%); opacity:0"></div>
    <video id="s-big" class="clip" data-start="2.8" data-duration="4.67" data-track-index="3" muted playsinline src="assets/clips/sonar_big.mp4"
      style="position:absolute; left:555px; top:0; width:810px; height:1080px; object-fit:cover; -webkit-mask-image:radial-gradient(ellipse 46% 52% at 50% 50%, #000 70%, transparent 100%); mask-image:radial-gradient(ellipse 46% 52% at 50% 50%, #000 70%, transparent 100%)"></video>
    {phone("s-phone", 726, 37, [("s-lift", "assets/ui/at_lift.png", 0, 2.9, "img")])}
    <div id="s-title" style="position:absolute; left:0; width:1920px; top:56px; text-align:center; font-size:30px; font-weight:800; letter-spacing:0.02em; color:#89E900; opacity:0">Lift up to First Floor</div>
    <div id="s-note" style="position:absolute; left:0; width:1920px; top:1012px; text-align:center; letter-spacing:0.14em; text-transform:uppercase; color:#C7E9C0; font-size:24px; font-weight:700; opacity:0">The app's own 3D floor-change view</div>
    <div id="s-ff" class="card" style="left:240px; top:220px; width:1440px; height:759px; overflow:hidden; opacity:0">
      <video id="s-ffv" class="clip" data-start="7.47" data-duration="2.0" data-track-index="3" muted playsinline src="assets/clips/first_floor_map.mp4" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover"></video>
      <img id="s-ffl" class="clip" data-start="9.47" data-duration="3.53" data-track-index="3" src="assets/ui/first_floor_map_last.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover">
    </div>
    <div id="s-head" style="position:absolute; left:240px; top:70px; width:1500px; opacity:0">
      <div class="kicker">First Floor · Room 104</div>
      <div id="s-hh" class="h2" style="margin-top:10px; font-size:64px">{K("Navigation doesn't stop at the *next* *floor.*")}</div>
    </div>
"""
script = '    tl.fromTo("#s-phone", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }, 0);\n'
script += '    tl.fromTo("#s-phone", { scale: 1 }, { scale: 1.08, duration: 2.1, ease: "sine.inOut" }, 0.1);\n'
script += '    tl.fromTo("#s-night", { opacity: 0 }, { opacity: 1, duration: 0.6, ease: "power2.in" }, 2.2);\n'
script += '    tl.to("#s-phone", { scale: 2.8, opacity: 0, duration: 0.6, ease: "expo.in" }, 2.25);  // dive into the screen\n'
script += '    tl.fromTo("#s-big", { opacity: 0, scale: 1.15 }, { opacity: 1, scale: 1, duration: 0.5, ease: "expo.out" }, 2.8);  // beat-locked: 46.80s\n'
script += '    tl.fromTo("#s-glow", { opacity: 0 }, { opacity: 1, duration: 0.5 }, 2.8);\n'
script += show("#s-title", 3.0, 0, 0.4) + hide("#s-title", 7.0, 0.3)
for i, t in enumerate([2.8, 3.5, 4.2]):
    script += f'    tl.fromTo("#s-ring{i}", {{ opacity: 0.7, scale: 0.4 }}, {{ opacity: 0, scale: 4.2, duration: 2.2, ease: "power2.out" }}, {t});\n'
script += show("#s-note", 3.4, 0, 0.5) + hide("#s-note", 7.0)
script += '    tl.to(["#s-glow", "#s-big"], { opacity: 0, duration: 0.4 }, 7.2);\n'
script += '    tl.to("#s-night", { opacity: 0, duration: 0.7, ease: "power2.out" }, 7.3);\n'
script += '    tl.fromTo("#s-ff", { opacity: 0, scale: 1.12 }, { opacity: 1, scale: 1, duration: 0.8, ease: "expo.out" }, 7.4);\n'
script += show("#s-head", 8.6, 0, 0.01) + kin("#s-hh", 8.65, 0.06)
scene("sonar", 13.0, body, script)

# ---------------------------------------------------------------- 6 guidance
ring = ('<div id="g-ring" class="clip" data-start="0.6" data-duration="2.2" data-track-index="3" '
        'style="position:absolute; left:291px; top:618px; width:124px; height:49px; border-radius:24px; border:4px solid #F59E0B"></div>')
body = f"""
    {phone("g-phone", 1230, 37, [("g-steps", "assets/ui/steps.png", 0, 2.8, "img"), ("g-arr", "assets/ui/arrived.png", 2.8, 2.0, "img"), ("g-sheet", "assets/ui/walk_sheet.png", 4.8, 1.0, "img"), ("g-walk", "assets/clips/walk.mp4", 5.8, 2.0, "video"), ("g-wl", "assets/ui/walk_last.png", 7.8, 1.2, "img")], ring)}
    <div id="g-a" style="position:absolute; left:150px; top:300px; width:960px; opacity:0">
      <div class="kicker">Guidance</div>
      <div id="g-ah" class="h2" style="margin-top:14px">{K("Lost your place?|*Scan* *any* *marker.*")}</div>
      <div class="body" style="margin-top:22px">Re-locate, and the route starts again from wherever you are.</div>
    </div>
    <div id="g-map" class="card" style="left:240px; top:220px; width:1440px; height:759px; overflow:hidden; opacity:0">
      <img src="assets/ui/arrived_map.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover"></div>
    <div id="g-b" style="position:absolute; left:240px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Step by step · the app's own words</div>
      <div id="g-bh" class="h2" style="margin-top:10px; font-size:64px">{K("&quot;You have arrived at *Room* *104.&quot;*")}</div>
    </div>
    <div id="g-c" style="position:absolute; left:150px; top:270px; width:980px; opacity:0">
      <span class="pill" style="background:#005A32; color:#fff">Beta</span>
      <div id="g-ch" class="h2" style="margin-top:20px">{K("Scan once.|*Then* *just* *walk.*")}</div>
      <div style="font-size:28px; color:#586B45; margin-top:18px">Spoken turns. Position between markers is estimated.</div>
    </div>
"""
script = show("#g-a", 0.05, 24, 0.35) + kin("#g-ah", 0.05, 0.05) + hide("#g-a", 2.8, 0.15)
script += '    tl.fromTo("#g-ring", { scale: 1.3, opacity: 0 }, { scale: 1, opacity: 1, duration: 0.35, ease: "back.out(2)" }, 0.6);\n'
script += '    tl.to("#g-phone", { opacity: 0, x: 200, duration: 0.4, ease: "power2.in" }, 2.7);\n'
script += '    tl.fromTo("#g-map", { opacity: 0, scale: 1.08 }, { opacity: 1, scale: 1, duration: 0.6, ease: "expo.out" }, 2.85);\n'
script += show("#g-b", 2.9, 0, 0.01) + kin("#g-bh", 2.95, 0.05) + hide("#g-b", 4.6) + hide("#g-map", 4.6, 0.3)
script += '    tl.to("#g-phone", { opacity: 1, x: 0, duration: 0.5, ease: "expo.out" }, 4.7);\n'
script += show("#g-c", 4.9) + kin("#g-ch", 4.95, 0.06)
scene("guidance", 9.0, body, script)

# ---------------------------------------------------------------- 7 offline
nos = ["No GPS", "No Wi-Fi", "No beacons", "No server"]
chips = "".join(
    f'<div id="o-n{i}" style="display:flex; align-items:center; gap:18px; opacity:0">'
    f'<div style="width:46px; height:46px; border-radius:50%; border:4px solid #586B45; position:relative">'
    f'<div style="position:absolute; left:-4px; top:17px; width:46px; height:5px; background:#DC2626; transform:rotate(-45deg)"></div></div>'
    f'<div style="font-size:54px; font-weight:900; letter-spacing:-0.03em">{n}</div></div>' for i, n in enumerate(nos))
body = f"""
    <div id="o-q" style="position:absolute; left:0; width:1920px; top:350px; text-align:center; opacity:0">
      <div id="o-qh" class="h1" style="font-size:112px">{K("No beacons. No Wi-Fi.")}</div>
      <div class="h1 green" style="font-size:112px; margin-top:10px">How does it know?</div>
    </div>
    {phone("o-phone", 230, 37, [("o-loc", "assets/ui/located_end.png", 2.0, 6.3, "img"), ("o-ed1", "assets/ui/editor_map_guide.png", 8.3, 1.7, "img"), ("o-ed2", "assets/ui/editor_map.png", 10.0, 4.2, "img")])}
    <div id="o-air" class="card" style="left:780px; top:190px; padding:26px 34px; display:flex; align-items:center; gap:24px; opacity:0">
      <svg width="64" height="64" viewBox="0 0 24 24"><path fill="#005A32" d="M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"/></svg>
      <div><div style="font-size:38px; font-weight:800">Airplane mode</div><div class="olive" style="font-size:28px">Everything off</div></div>
      <div style="width:92px; height:52px; border-radius:26px; background:#C9B993; position:relative; margin-left:30px">
        <div id="o-knob" style="position:absolute; left:6px; top:6px; width:40px; height:40px; border-radius:50%; background:#fff"></div></div>
    </div>
    <div id="o-nos" style="position:absolute; left:800px; top:430px; display:flex; flex-direction:column; gap:22px">{chips}</div>
    <div id="o-s" style="position:absolute; left:780px; top:250px; width:560px; opacity:0">
      <div class="kicker">Set-up</div>
      <div class="h2" style="margin-top:14px; font-size:58px">From the building's own floor plan.</div>
      <div class="body" style="margin-top:22px">The app drafts the map. A person reviews it, prints the markers.</div>
      <div style="font-size:28px; color:#586B45; margin-top:16px">Auto-draft, reviewed by the admin</div>
    </div>
    {phone("o-phone2", 1400, 37, [("o-home2", "assets/ui/home.png", 11.2, 3.0, "img")])}
    <div id="o-file" class="card" style="left:560px; top:620px; padding:20px 26px; display:flex; align-items:center; gap:18px; opacity:0">
      <svg width="48" height="48" viewBox="0 0 24 24"><path fill="#586B45" d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>
      <div><div style="font-size:30px; font-weight:800">Indoor Nav demo building.indoornav</div><div class="olive" style="font-size:28px">One file: plans, places, markers</div></div>
    </div>
"""
script = '    tl.fromTo("#o-q", { opacity: 0, scale: 0.96 }, { opacity: 1, scale: 1, duration: 0.5, ease: "expo.out" }, 0.05);\n'
script += hide("#o-q", 1.85, 0.3)
script += '    tl.fromTo("#o-phone", { x: -500, opacity: 0 }, { x: 0, opacity: 1, duration: 0.8, ease: "expo.out" }, 2.0);\n'
script += show("#o-air", 2.1)
script += '    tl.to("#o-knob", { x: 40, duration: 0.25, ease: "power2.out" }, 2.2);\n'
script += '    tl.to("#o-knob", { backgroundColor: "#ffffff", duration: 0.2 }, 2.2);\n'
for i, t in enumerate([3.7, 4.6, 5.5, 6.6]):
    script += f'    tl.fromTo("#o-n{i}", {{ opacity: 0, x: -30 }}, {{ opacity: 1, x: 0, duration: 0.4, ease: "expo.out" }}, {t});\n'
script += hide("#o-air", 8.0) + hide("#o-nos", 8.0)
script += show("#o-s", 8.4)
script += '    tl.fromTo("#o-phone2", { x: 500, opacity: 0 }, { x: 0, opacity: 1, duration: 0.8, ease: "expo.out" }, 11.2);\n'
script += '    tl.fromTo("#o-file", { opacity: 0, x: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.3, ease: "back.out(2)" }, 11.5);\n'
script += '    tl.to("#o-file", { x: 760, y: -40, duration: 1.0, ease: "power3.inOut" }, 11.8);\n'
scene("offline", 14.2, body, script, wipe_out=True)

# ---------------------------------------------------------------- 8 evolution
def icon_card(cid, x, title, sub, svg):
    return (f'<div id="{cid}" class="card" style="left:{x}px; top:330px; width:400px; height:340px; display:flex; flex-direction:column; '
            f'align-items:center; justify-content:center; gap:18px; opacity:0">{svg}'
            f'<div style="font-size:40px; font-weight:800">{title}</div><div class="olive" style="font-size:28px">{sub}</div></div>')

chip_svg = '<svg width="110" height="110" viewBox="0 0 24 24"><path fill="#586B45" d="M15 9H9v6h6V9zm-2 4h-2v-2h2v2zm8-2V9h-2V7c0-1.1-.9-2-2-2h-2V3h-2v2h-2V3H9v2H7c-1.1 0-2 .9-2 2v2H3v2h2v2H3v2h2v2c0 1.1.9 2 2 2h2v2h2v-2h2v2h2v-2h2c1.1 0 2-.9 2-2v-2h2v-2h-2v-2h2zm-4 6H7V7h10v10z"/></svg>'
wifi_svg = '<svg width="110" height="110" viewBox="0 0 24 24"><path fill="#586B45" d="M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9zm8 8l3 3 3-3c-1.65-1.66-4.34-1.66-6 0zm-4-4l2 2c2.76-2.76 7.24-2.76 10 0l2-2C15.14 9.14 8.87 9.14 5 13z"/></svg>'
cloud_svg = '<svg width="110" height="110" viewBox="0 0 24 24"><path fill="#586B45" d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM19 18H6c-2.21 0-4-1.79-4-4s1.79-4 4-4h.71C7.37 7.69 9.48 6 12 6c3.04 0 5.5 2.46 5.5 5.5v.5H19c1.66 0 3 1.34 3 3s-1.34 3-3 3z"/></svg>'
body = f"""
    <div id="e-k" style="position:absolute; left:150px; top:170px; opacity:0"><div class="kicker">Where it started</div>
      <div class="h2" style="margin-top:12px">The first version.</div></div>
    {icon_card("e-1", 150, "ESP32", "microcontroller", chip_svg)}
    {icon_card("e-2", 760, "Wi-Fi", "to reach the board", wifi_svg)}
    {icon_card("e-3", 1370, "Cloud database", "Firebase Realtime DB", cloud_svg)}
    {phone("e-phone", 560, 37, [("e-home", "assets/ui/located_end.png", 4.9, 2.5, "img")])}
    <div id="e-paper" style="position:absolute; left:1060px; top:560px; width:250px; height:250px; background:#fff; padding:6px; box-sizing:border-box; box-shadow:0 18px 36px rgba(34,48,26,0.22); opacity:0">
      <img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block"></div>
    <div id="e-now" style="position:absolute; left:1060px; top:230px; width:760px; opacity:0">
      <div id="e-nh" class="h2">{K("Now: a phone,|*and* *a* *sticker.*")}</div>
      <div class="body" style="margin-top:18px; font-size:28px">Flutter · OpenCV ArUco · on-device Dijkstra · local storage</div></div>
"""
script = show("#e-k", 0.2)
for i, t in enumerate([0.4, 1.3, 2.4]):
    script += f'    tl.fromTo("#e-{i + 1}", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }}, {t});\n'
for i in range(3):
    script += f'    tl.to("#e-{i + 1}", {{ opacity: 0, scale: 0.3, x: {[560, -50, -660][i]}, duration: 0.5, ease: "power3.in" }}, 4.7);\n'
script += hide("#e-k", 4.6)
script += '    tl.fromTo("#e-phone", { opacity: 0, scale: 0.85 }, { opacity: 1, scale: 1, duration: 0.6, ease: "expo.out" }, 4.9);\n'
script += '    tl.fromTo("#e-paper", { opacity: 0, scale: 1.4, rotation: -12 }, { opacity: 1, scale: 1, rotation: -4, duration: 0.3, ease: "power4.in" }, 5.1);\n'
script += show("#e-now", 5.05, 20, 0.4) + kin("#e-nh", 5.05, 0.06)
scene("evolution", 7.4, body, script, wipe_in=True)

# ---------------------------------------------------------------- 9 closing
blocks = [(120, 140, 300, 180), (480, 90, 260, 250), (800, 160, 340, 170), (180, 400, 240, 220), (500, 420, 380, 160), (940, 380, 240, 260)]
bsvg = ['<svg width="1240" height="700" viewBox="0 0 1240 700">']
for i, (x, y, w, h) in enumerate(blocks):
    if i == 1:
        bsvg.append(f'<rect id="c-b{i}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="#586B45" stroke="#005A32" stroke-width="5"/>')
    else:
        bsvg.append(f'<rect id="c-b{i}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="rgba(244,237,223,0.6)" stroke="#586B45" stroke-width="4" stroke-dasharray="14 10" opacity="0"/>')
bsvg.append('<path d="M60 340 H1180 M440 40 V660 M760 40 V660" stroke="#C9B993" stroke-width="18" fill="none" opacity="0.55" stroke-linecap="round"/>')
bsvg.append("</svg>")
body = f"""
    <div id="c-campus" style="position:absolute; left:640px; top:200px; opacity:0">{''.join(bsvg)}</div>
    <div id="c-a" style="position:absolute; left:150px; top:330px; width:620px; opacity:0">
      <div id="c-ah" class="h2">{K("One building today.")}</div>
      <div id="c-a2" class="h2 green" style="margin-top:18px; opacity:0">Every building next semester?</div>
    </div>
    <div id="c-n" style="position:absolute; left:0; width:1920px; top:330px; text-align:center; opacity:0">
      <div class="h2" style="color:#4A5340">What if you could just walk through a building once?</div>
      <div id="c-n2" style="margin-top:36px; opacity:0"><span class="pill" style="background:#F59E0B; color:#22301A">Planned</span>
        <div id="c-nh" class="h1" style="margin-top:22px; font-size:100px">{K("Next: Walk it once. *It* *maps* *itself.*")}</div></div>
    </div>
    <div id="c-end" style="position:absolute; left:0; width:1920px; top:370px; display:flex; flex-direction:column; align-items:center; opacity:0">
      <div style="display:flex; align-items:center; gap:30px">{COMPASS.format(s=150, c="#005A32")}
        <div style="font-size:160px; font-weight:900; letter-spacing:-0.045em; color:#005A32">Indoor Nav</div></div>
      <div id="c-tag" class="h2" style="margin-top:30px; font-size:56px; color:#22301A; opacity:0">{K("Find your way. Anywhere indoors.")}</div>
    </div>
    <div id="c-credit" data-layout-ignore style="position:absolute; left:0; width:1920px; top:1020px; text-align:center; font-size:22px; color:#586B45; opacity:0">Music: Sascha Ende, ende.app (CC BY 4.0) · App screens rendered from the Indoor Nav app</div>
"""
script = show("#c-campus", 0.1, 20) + show("#c-a", 0.3)
script += show("#c-a2", 1.4, 16)
for i, t in [(0, 1.6), (2, 1.8), (3, 2.0), (4, 2.2), (5, 2.4)]:
    script += f'    tl.to("#c-b{i}", {{ opacity: 1, duration: 0.3 }}, {t});\n'
script += hide("#c-campus", 2.95) + hide("#c-a", 2.95, 0.3)
script += show("#c-n", 3.3, 20, 0.4) + show("#c-n2", 4.15, 20, 0.5, "expo.out")
script += hide("#c-n", 6.15, 0.25)
script += '    tl.fromTo("#c-end", { opacity: 0, scale: 0.94 }, { opacity: 1, scale: 1, duration: 0.8, ease: "expo.out" }, 6.4);\n'
script += kin("#c-tag", 7.0, 0.06) + show("#c-credit", 7.4, 0)
scene("closing", 10.0, body, script)

# ---------------------------------------------------------------- root
hosts = "\n".join(
    f'      <div id="{sid}" data-composition-id="{sid}" data-composition-src="compositions/{sid}.html" data-start="{s}" '
    f'data-duration="{d}" data-track-index="1" data-track-kind="graphics" data-width="1920" data-height="1080"></div>'
    for sid, s, d in SCENES)

audio = []
for vid, t in VOICE:
    audio.append(f'      <audio id="{vid}" data-start="{t}" data-duration="{dur(f"assets/voice/{vid}.wav")}" data-track-index="20" data-volume="1" src="assets/voice/{vid}.wav"></audio>')
# Music: soft bed under the first half, a pause before the floor change,
# then the track's strong section lands with the sonar (beat-locked 46.80s).
audio.append(f'      <audio id="music-a" data-start="0" data-duration="46.6" data-track-index="10" data-volume="0.17" data-fade-in="0.8" data-fade-out="0.9" src="{MUSIC}"></audio>')
audio.append(f'      <audio id="music-b" data-start="46.8" data-duration="5.0" data-media-start="61.1" data-track-index="11" data-volume="0.36" src="{MUSIC}"></audio>')
audio.append(f'      <audio id="music-c" data-start="51.8" data-duration="{round(TOTAL - 51.8, 2)}" data-media-start="66.1" data-track-index="10" data-volume="0.16" data-fade-out="3" src="{MUSIC}"></audio>')
lanes = []  # (end time) per lane
for i, (t, name, vol) in enumerate(SFX):
    d = dur(f"assets/sfx/{name}.ogg")
    for li, end in enumerate(lanes):
        if end <= t:
            lanes[li] = t + d
            break
    else:
        lanes.append(t + d)
        li = len(lanes) - 1
    audio.append(f'      <audio id="sfx{i:02d}" data-start="{t}" data-duration="{d}" data-track-index="{30 + li}" data-volume="{vol}" src="assets/sfx/{name}.ogg"></audio>')

index = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <title>Indoor Nav — launch film</title>
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"></script>
    <style>
      * {{ margin: 0; padding: 0; box-sizing: border-box; }}
      html, body {{ margin: 0; width: 1920px; height: 1080px; overflow: hidden; background: #E5D9C2; }}
      #root {{ position: relative; width: 100%; height: 100%; font-family: Roboto, sans-serif; }}
      #ground {{ position: absolute; inset: 0; background: #E5D9C2; }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}" data-width="1920" data-height="1080">
      <div id="ground" data-layout-ignore></div>
{hosts}
{chr(10).join(audio)}
    </div>
    <script>
      window.__timelines["main"] = gsap.timeline({{ paused: true }});
    </script>
  </body>
</html>
"""
(ROOT / "index.html").write_text(index, encoding="utf-8")
print("wrote", len(SCENES), "scenes,", len(audio), "audio clips")
