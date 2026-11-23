"""Via launch film, v2: writes the whole HyperFrames project.

Scenes are timed from the real narration (composition/assets/vo/*.wav), so
every line has room and nothing is cut. One scene per file in
composition/compositions/, a captions composition, and the root index.html
with narration, music and sound effects on their own lanes.

Run:  python build_film.py
"""
import json
import math
from pathlib import Path

W = Path(__file__).resolve().parent
# Shared look and helpers (CSS, phone(), K(), kin(), scene(), show(), hide(), dur()).
exec((W / "build_scenes.py").read_text(encoding="utf-8").split("# ---------------------------------------------------------------- 1 problem")[0])

for old in COMP.glob("*.html"):
    old.unlink()

VO_DIR = "assets/vo"
VD = {p.stem: dur(f"{VO_DIR}/{p.name}") for p in sorted((ROOT / VO_DIR).glob("*.wav"))}

# What the captions say (the voice files spell some words out for the TTS).
CAP = {
    "a1": "Outside, your phone always knows where you are.",
    "a2": "But step inside a big building, and GPS goes quiet.",
    "a3": "On our own college campus, new students and visitors can easily lose their way.",
    "b1": "So we're building Indoor Nav for our college. Step-by-step directions inside a building, using just your phone.",
    "b2": "It's as simple as: pick, scan, and follow.",
    "c1": "First, pick where you want to go.",
    "d1": "Then scan the nearest marker. It's simply a printed sticker on the wall.",
    "d2": "The phone reads it right away, and knows exactly where you are.",
    "e1": "Now follow your route, drawn on the building's own floor plan.",
    "e2": "It's worked out right on the phone, through rooms, corridors, stairs and lifts.",
    "f1": "Need a step-free route? That's one tap. Rather take the stairs? Choose Avoid lifts.",
    "g1": "And when your route changes floors,",
    "g2": "you see exactly how you get there.",
    "h1": "Clear steps guide you all the way to the door.",
    "h2": "Took a wrong turn? Just scan any marker, and your route starts again from there.",
    "h3": "And in beta: scan once, then simply walk, with every turn read aloud.",
    "i1": "Under the hood is a corrected, bidirectional Dijkstra search.",
    "i2": "Our first version, on an ESP32, took a longer route on 36 of 756 trips.",
    "i3": "Today, every pair of places gets the shortest route. And 192 automated tests keep it that way.",
    "j1": "And it all works offline. No GPS. No Wi-Fi. No beacons. No server.",
    "k1": "Any block can be set up from its own floor plan, and shared as a single file.",
    "m1": "Next, we want to map every block on our campus, so anyone can find any room, in any building.",
    "m2": "And beyond our campus, the same idea can help in hospitals, malls, airports, and exam halls.",
    "l1": "It started with a microcontroller and a cloud database. Today, all it takes is a phone, and a sticker.",
    "l2": "Indoor Nav. Find your way, anywhere indoors.",
}


def place(plan, lead):
    """plan: [(vo_id, gap_before)], returns {id: (local_start, length)} and the end time."""
    t, out = lead, {}
    for i, (vid, gap) in enumerate(plan):
        if i:
            t += gap
        out[vid] = (round(t, 2), VD[vid])
        t += VD[vid]
    return out, t


TIMELINE = []   # (scene id, abs start, duration)
VOICE = []      # (vo id, abs start)
SFX = []        # (abs time, file, volume)
T0 = [0.0]


def add_scene(sid, d, vo, sfx=()):
    start = round(T0[0], 2)
    TIMELINE.append((sid, start, round(d, 2)))
    for vid, (s, _) in vo.items():
        VOICE.append((vid, round(start + s, 2)))
    for t, f, v in sfx:
        SFX.append((round(start + t, 2), f, v))
    T0[0] += d


def rail(active, rid):
    items = [("Pick", "M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"),
             ("Scan", "M9.5 6.5v3h-3v-3h3M11 5H5v6h6V5zm-1.5 9.5v3h-3v-3h3M11 13H5v6h6v-6zm6.5-6.5v3h-3v-3h3M19 5h-6v6h6V5zm-6 8h1.5v1.5H13V13zm1.5 1.5H16V16h-1.5v-1.5zM16 13h1.5v1.5H16V13zm-3 3h1.5v1.5H13V16zm1.5 1.5H16V19h-1.5v-1.5zM16 16h1.5v1.5H16V16zm1.5-1.5H19V16h-1.5v-1.5zm0 3H19V19h-1.5v-1.5zM22 7h-2V4h-3V2h5v5zm0 15v-5h-2v3h-3v2h5zM2 22h5v-2H4v-3H2v5zM2 2v5h2V4h3V2H2z"),
             ("Follow", "M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71z")]
    out = []
    for i, (word, path) in enumerate(items):
        on = word == active
        col = "#005A32" if on else "rgba(88,107,69,0.38)"
        out.append(f'<div id="{rid}{i}" style="display:flex; align-items:center; gap:22px; opacity:{1 if on else 0.9}">'
                   f'<svg width="58" height="58" viewBox="0 0 24 24"><path fill="{col}" d="{path}"/></svg>'
                   f'<div style="font-size:84px; font-weight:900; letter-spacing:-0.04em; color:{col}">{word}</div></div>')
    return f'<div id="{rid}" style="position:absolute; left:120px; top:300px; display:flex; flex-direction:column; gap:26px">{"".join(out)}</div>'


MAP_CARD = "card"


def big_map(mid, inner, left=240, top=220, w=1440, h=810):
    return f'<div id="{mid}" class="card" style="left:{left}px; top:{top}px; width:{w}px; height:{h}px; overflow:hidden; opacity:0">{inner}</div>'


def media(mid, src, start, d, kind="video"):
    st = "position:absolute; inset:0; width:100%; height:100%; object-fit:cover"
    if kind == "video":
        return f'<video id="{mid}" class="clip" data-start="{start}" data-duration="{d}" data-track-index="3" muted playsinline src="{src}" style="{st}"></video>'
    return f'<img id="{mid}" class="clip" data-start="{start}" data-duration="{d}" data-track-index="3" src="{src}" alt="" style="{st}">'


# ======================================================================= 1 campus
vo, end = place([("a1", 0), ("a2", 0.6), ("a3", 0.5)], 0.6)
D = round(end + 1.4, 2)
REG = json.loads((W / "regions.json").read_text())
g0 = REG["floor0"]
SC = 1080 / 770
MAP_H = 445 * SC
names = {n["region"]: n["name"] for n in g0["nodes"] if n["region"]}


def poly(o):
    return " ".join(f"{x * SC:.1f},{y * SC:.1f}" for x, y in o)


msvg = [f'<svg width="1080" height="{MAP_H:.0f}" viewBox="0 0 1080 {MAP_H:.0f}"><rect width="1080" height="{MAP_H:.0f}" fill="#FBF6EC"/>']
regs = [r for r in g0["regions"] if r["kind"] != "ignored"]
for r in sorted(regs, key=lambda r: r["kind"] != "corridor"):
    pts = poly(r["outline"])
    if r["kind"] == "corridor":
        msvg.append(f'<polygon points="{pts}" fill="#F1E8D4" stroke="#C9B993" stroke-width="3"/>')
    elif r["kind"] == "stairs":
        x0, y0, x1, y1 = [v * SC for v in r["bbox"]]
        cid = "st-" + r["id"]
        msvg.append(f'<clipPath id="{cid}"><polygon points="{pts}"/></clipPath><polygon points="{pts}" fill="rgba(183,121,31,0.14)"/>')
        msvg.append(f'<g clip-path="url(#{cid})" stroke="#B7791F" stroke-width="3">' + "".join(
            f'<line x1="{x0:.0f}" y1="{y0 + k * 14:.1f}" x2="{x1:.0f}" y2="{y0 + k * 14:.1f}"/>' for k in range(1, int((y1 - y0) / 14) + 1)) + "</g>")
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
        msvg.append(f'<text x="{(x0 + x1) / 2:.1f}" y="{cy + i * fs * 1.2:.1f}" text-anchor="middle" font-family="Roboto" font-weight="700" font-size="{fs:.0f}" fill="#2B3320">{ln}</text>')
msvg.append("</svg>")
FLOOR_SVG = "".join(msvg)
MX, MY = 740, 250
WALK = [(110, 150), (210, 222), (390, 224), (300, 222), (520, 224), (610, 222), (450, 224)]
path = [(MX + x * SC - 22, MY + y * SC - 22) for x, y in WALK]

# A stylised campus (illustration): roads, lawns, blocks. The middle block is "ours".
blocks = [(170, 140, 300, 190), (560, 120, 260, 230), (900, 150, 330, 170), (1320, 120, 280, 220),
          (170, 560, 260, 230), (560, 600, 330, 170), (980, 560, 260, 260), (1320, 600, 300, 180)]
city = ['<svg width="1920" height="1080" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#E5D9C2"/>',
        '<g fill="#CFD9B5"><ellipse cx="490" cy="470" rx="120" ry="60"/><ellipse cx="1260" cy="470" rx="150" ry="55"/><ellipse cx="1700" cy="900" rx="140" ry="70"/></g>',
        '<g stroke="#FBF6EC" stroke-width="54" fill="none" stroke-linecap="round"><path d="M60 450 H1860 M60 880 H1860 M480 60 V1020 M920 60 V1020 M1280 60 V1020"/></g>']
for i, (x, y, w, h) in enumerate(blocks):
    fill = "#F4EDDF" if i != 2 else "#E3E8D3"
    city.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" stroke="{"#586B45" if i == 2 else "#C9B993"}" stroke-width="{5 if i == 2 else 3}"/>')
city.append("</svg>")
cdot = [(140, 450), (480, 450), (480, 450), (920, 450), (1065, 450), (1065, 330)]
body = f"""
    <div id="c-city" style="position:absolute; inset:0">{''.join(city)}</div>
    <div id="c-cdot" style="position:absolute; left:0; top:0; width:40px; height:40px">
      <div style="position:absolute; inset:-12px; border-radius:50%; background:rgba(29,78,216,0.16)"></div>
      <div style="position:absolute; inset:0; border-radius:50%; background:#1D4ED8; border:5px solid #fff; box-shadow:0 4px 10px rgba(0,0,0,0.25)"></div></div>
    <div id="c-gpsok" class="card" style="left:120px; top:90px; padding:16px 26px; display:flex; align-items:center; gap:14px">
      <div style="width:16px; height:16px; border-radius:50%; background:#005A32"></div><div style="font-size:30px; font-weight:800; color:#005A32">GPS · accurate outdoors</div></div>
    <div id="c-floor" style="position:absolute; inset:0; opacity:0">
      <div class="bg"></div>
      <div id="c-card" class="card" data-layout-ignore style="left:{MX - 20}px; top:{MY - 20}px; width:1120px; height:{MAP_H + 40:.0f}px; padding:20px">{FLOOR_SVG}</div>
      <div class="kicker" style="position:absolute; left:{MX}px; top:{MY + MAP_H + 36:.0f}px">One block of our campus · Ground Floor</div>
      <div id="c-dot" style="position:absolute; left:0; top:0; width:44px; height:44px">
        <div style="position:absolute; inset:-22px; border-radius:50%; background:rgba(29,78,216,0.18)"></div>
        <div style="position:absolute; inset:0; border-radius:50%; background:#1D4ED8; border:5px solid #fff; box-shadow:0 4px 10px rgba(0,0,0,0.25)"></div>
        <div id="c-q" style="position:absolute; left:40px; top:-62px; width:56px; height:56px; border-radius:50%; background:#F4EDDF; color:#DC2626; font-size:38px; font-weight:900; display:flex; align-items:center; justify-content:center; box-shadow:0 6px 14px rgba(0,0,0,0.18); opacity:0">?</div></div>
      <div id="c-gps" class="card" style="left:120px; top:200px; padding:18px 28px; display:flex; align-items:center; gap:14px; opacity:0">
        <div style="width:16px; height:16px; border-radius:50%; background:#DC2626"></div><div style="font-size:32px; font-weight:800; color:#DC2626">No GPS signal indoors</div></div>
      <div id="c-head" class="h1" style="position:absolute; left:120px; top:420px; width:600px; opacity:0">{K("GPS stops|at the *door.*")}</div>
      <div id="c-who" style="position:absolute; left:120px; top:690px; width:560px; display:flex; flex-wrap:wrap; gap:14px; opacity:0">
        <span class="chip">New students</span><span class="chip">Visitors</span><span class="chip">Room 104?</span></div>
    </div>
"""
s = f'    tl.set("#c-cdot", {{ x: {cdot[0][0] - 20}, y: {cdot[0][1] - 20} }}, 0);\n'
for i, (x, y) in enumerate(cdot[1:]):
    s += f'    tl.to("#c-cdot", {{ x: {x - 20}, y: {y - 20}, duration: 0.7, ease: "none" }}, {0.3 + i * 0.7:.2f});\n'
bx, by = 900 + 165, 150 + 85  # our block's centre
s += f'    tl.to("#c-city", {{ scale: 5.5, transformOrigin: "{bx}px {by}px", duration: 1.1, ease: "expo.in" }}, {vo["a2"][0] - 0.2:.2f});\n'
s += f'    tl.to(["#c-cdot", "#c-gpsok"], {{ opacity: 0, duration: 0.3 }}, {vo["a2"][0] - 0.1:.2f});\n'
s += f'    tl.fromTo("#c-floor", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.45 }}, {vo["a2"][0] + 0.75:.2f});\n'
s += f'    tl.fromTo("#c-card", {{ scale: 0.6 }}, {{ scale: 1, duration: 0.9, ease: "expo.out" }}, {vo["a2"][0] + 0.75:.2f});\n'
s += f'    tl.set("#c-dot", {{ x: {path[0][0]:.0f}, y: {path[0][1]:.0f} }}, 0);\n'
t = vo["a2"][0] + 1.4
for (x, y) in path[1:]:
    s += f'    tl.to("#c-dot", {{ x: {x:.0f}, y: {y:.0f}, duration: 0.8, ease: "power1.inOut" }}, {t:.2f});\n'
    t += 0.95
s += f'    tl.fromTo("#c-q", {{ opacity: 0, scale: 0.4 }}, {{ opacity: 1, scale: 1, duration: 0.4, ease: "back.out(2)" }}, {vo["a2"][0] + 2.2:.2f});\n'
s += show("#c-gps", vo["a2"][0] + 2.0, 12)
s += kin("#c-head", vo["a2"][0] + 2.6, 0.08)
s += show("#c-who", vo["a3"][0] + 1.6, 16, 0.5)
scene("campus", D, body, s, wipe_out=True)
add_scene("campus", D, vo, [(vo["a2"][0] - 0.2, "card-shove-1", 0.3), (vo["a2"][0] + 2.0, "switch_002", 0.35), (vo["a2"][0] + 2.6, "drop_002", 0.4), (D - 0.4, "card-shove-1", 0.3)])

# ======================================================================= 2 title
vo, end = place([("b1", 0), ("b2", 0.35)], 0.4)
D = round(end + 0.9, 2)
b2 = vo["b2"][0]
body = f"""
    <div id="t-k" class="kicker" style="position:absolute; left:150px; top:250px; opacity:0">Built for our college</div>
    <div id="t-mark" style="position:absolute; left:150px; top:300px; display:flex; align-items:center; gap:30px; opacity:0">
      {COMPASS.format(s=150, c="#005A32")}
      <div style="font-size:150px; font-weight:900; letter-spacing:-0.045em; color:#005A32">Indoor Nav</div></div>
    <div id="t-tag" class="h2" style="position:absolute; left:156px; top:520px; width:900px; opacity:0">{K("Step-by-step directions|inside a building.")}</div>
    <div id="t-steps" style="position:absolute; left:156px; top:740px; display:flex; gap:40px">
      <div id="t-s0" class="h1" style="font-size:96px; opacity:0">Pick.</div>
      <div id="t-s1" class="h1" style="font-size:96px; opacity:0">Scan.</div>
      <div id="t-s2" class="h1 green" style="font-size:96px; opacity:0">Follow.</div></div>
    {phone("t-phone", 1240, 37, [("t-home", "assets/ui/home.png", 0, D, "img")])}
"""
s = show("#t-k", 0.5, 10)
s += '    tl.fromTo("#t-mark", { opacity: 0, scale: 0.92, transformOrigin: "left center" }, { opacity: 1, scale: 1, duration: 0.8, ease: "expo.out" }, 0.6);\n'
s += '    tl.fromTo("#t-phone", { y: 260, opacity: 0, rotation: 4 }, { y: 0, opacity: 1, rotation: 0, duration: 1.0, ease: "expo.out" }, 0.4);\n'
s += kin("#t-tag", 3.2, 0.07)
for i, dt in enumerate([1.45, 2.0, 2.7]):
    s += f'    tl.fromTo("#t-s{i}", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }}, {b2 + dt:.2f});\n'
scene("title", D, body, s, wipe_in=True)
add_scene("title", D, vo, [(0.6, "impactSoft_medium_001", 0.45)] + [(b2 + dt, "drop_002", 0.35) for dt in (1.45, 2.0, 2.7)])

# ======================================================================= 3 pick
vo, end = place([("c1", 0)], 0.2)
D = round(end + 1.7, 2)
body = f"""
    {rail("Pick", "k-rail")}
    {phone("k-phone", 1100, 37, [("k-p0", "assets/ui/picker_open.png", 0, 0.7, "img"), ("k-p1", "assets/ui/picker_1.png", 0.7, 0.4, "img"), ("k-p2", "assets/ui/picker_10.png", 1.1, 0.4, "img"), ("k-p3", "assets/ui/picker_104.png", 1.5, 0.9, "img"), ("k-dest", "assets/ui/destination.png", 2.4, round(D - 2.4, 2), "img")])}
    <div id="k-note" class="card" style="left:1600px; top:500px; padding:18px 26px; opacity:0"><div class="kicker">Destination</div><div style="font-size:34px; font-weight:800; margin-top:4px">Room 104</div></div>
"""
s = '    tl.fromTo("#k-rail", { opacity: 0, x: -30 }, { opacity: 1, x: 0, duration: 0.4, ease: "expo.out" }, 0);\n'
s += '    tl.fromTo("#k-phone", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }, 0);\n'
s += show("#k-note", 2.5, 12, 0.4)
scene("pick", D, body, s)
add_scene("pick", D, vo, [(0.7, "click2", 0.3), (1.1, "click2", 0.3), (1.5, "click2", 0.3), (2.4, "select_008", 0.45)])

# ======================================================================= 4 scan
vo, end = place([("d1", 0), ("d2", 0.45)], 0.25)
D = round(end + 1.6, 2)
d2 = vo["d2"][0]
R = 440 / 1080
fx, fy, fw, fh = 240 * R, 700 * R, 600 * R, 600 * R
mk = 150
mx, my = fx + (fw - mk) / 2, fy + (fh - mk) / 2
PIN = 4.2           # phone arrives
LOCK = d2 + 1.3     # frame locks
HERE = LOCK + 0.6   # "You are at Entry 1"
cam = f"""<div id="s-cam" class="clip" data-start="{PIN}" data-duration="{round(HERE - PIN, 2)}" data-track-index="3"
        style="position:absolute; left:0; top:0; width:440px; height:978px; overflow:hidden; background:radial-gradient(ellipse 420px 620px at 50% 38%, #E2D6BE, #B9AB8E 75%, #8E826B)">
        <div id="s-mk" style="position:absolute; left:{mx:.1f}px; top:{my:.1f}px; width:{mk}px; height:{mk}px; box-shadow:0 8px 18px rgba(0,0,0,0.25)"><img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block"></div></div>
      <img id="s-ui" class="clip" data-start="{PIN}" data-duration="{round(HERE - PIN, 2)}" data-track-index="4" src="assets/ui/scanner_ui.png" alt="" style="position:absolute; left:0; top:0; width:440px; height:978px">
      <div id="s-lock" class="clip" data-start="{LOCK}" data-duration="{round(HERE - LOCK, 2)}" data-track-index="5" style="position:absolute; left:{fx:.1f}px; top:{fy:.1f}px; width:{fw:.0f}px; height:{fh:.0f}px; border:5px solid #C7E9C0; border-radius:22px; box-shadow:0 0 24px rgba(199,233,192,0.9)"></div>"""
body = f"""
    {rail("Scan", "s-rail")}
    <div id="s-q" style="position:absolute; left:560px; top:330px; width:800px; opacity:0">
      <div class="h2" style="font-size:66px">{K("No beacons. No Wi-Fi.|*How* *does* *it* *know?*")}</div></div>
    <div id="s-paper" style="position:absolute; left:600px; top:250px; width:360px; height:360px; background:#fff; padding:8px; box-sizing:border-box; box-shadow:0 22px 44px rgba(34,48,26,0.22); opacity:0">
      <img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block"></div>
    <div id="s-label" style="position:absolute; left:600px; top:650px; width:520px; opacity:0">
      <div class="kicker">Printed ArUco marker</div>
      <div style="font-size:32px; font-weight:700; margin-top:8px">Marker 13 · Entry 1</div>
      <div style="font-size:28px; color:#586B45; margin-top:10px">Read on the phone with OpenCV</div></div>
    <div id="s-head" class="h2" style="position:absolute; left:600px; top:800px; width:700px; opacity:0">{K("*Know* *where* *you* *are.*")}</div>
    {phone("s-phone", 1330, 37, [("s-here", "assets/ui/located_toast.png", HERE, round(D - HERE, 2), "img")], cam)}
"""
s = '    tl.fromTo("#s-rail", { opacity: 1 }, { opacity: 1, duration: 0.01 }, 0);\n'
s += kin("#s-q", 0.05, 0.05) + hide("#s-q", 2.55, 0.2)
s += '    tl.fromTo("#s-paper", { opacity: 0, scale: 1.4, rotation: -11 }, { opacity: 1, scale: 1, rotation: -3, duration: 0.32, ease: "power4.in" }, 2.75);\n'
s += show("#s-label", 3.2)
s += f'    tl.fromTo("#s-phone", {{ x: 520, opacity: 0 }}, {{ x: 0, opacity: 1, duration: 0.9, ease: "expo.out" }}, {PIN});\n'
s += f'    tl.fromTo("#s-mk", {{ x: 8, y: -6, rotation: 2.5 }}, {{ x: -3, y: 3, rotation: -0.5, duration: {LOCK - PIN:.2f}, ease: "sine.inOut" }}, {PIN});\n'
s += f'    tl.fromTo("#s-lock", {{ opacity: 0, scale: 1.12 }}, {{ opacity: 1, scale: 1, duration: 0.25, ease: "back.out(2)" }}, {LOCK});\n'
s += hide("#s-label", HERE + 0.2, 0.25) + kin("#s-head", HERE + 0.3, 0.06)
scene("scan", D, body, s)
add_scene("scan", D, vo, [(3.07, "impactWood_medium_001", 0.75), (3.09, "card-place-2", 0.45), (PIN, "card-slide-1", 0.32), (LOCK, "click_003", 0.55), (LOCK + 0.05, "impactSoft_medium_002", 0.42)])

# ======================================================================= 5 follow
vo, end = place([("e1", 0), ("e2", 0.35)], 0.25)
D = round(end + 0.9, 2)
PX, PY = 1100, 37
RS = 440 / 1080
MAPX, MAPY, MAPW = PX + 14 + 28 * RS, PY + 14 + 1280 * RS, 1024 * RS
BX, BY, BW, BH = 240, 210, 1440, 810
FLY = 0.7
body = f"""
    {rail("Follow", "f-rail")}
    {phone("f-phone", PX, PY, [("f-loc0", "assets/ui/located_toast.png", 0, 1.6, "img")])}
    {big_map("f-big", media("f-loc", "assets/clips/located_map.mp4", FLY, 4.0) + media("f-hold", "assets/ui/located_map_last.png", FLY + 4.0, round(D - FLY - 4.0, 2), "img"), BX, BY, BW, BH)}
    <div id="f-h" style="position:absolute; left:{BX}px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Rooms · corridors · stairs · lifts</div>
      <div id="f-hh" class="h2" style="margin-top:10px; font-size:62px">{K("Your route, worked out *on* *the* *phone.*")}</div></div>
"""
s = f'    tl.fromTo("#f-big", {{ opacity: 0, x: {MAPX - BX:.1f}, y: {MAPY - BY:.1f}, scale: {MAPW / BW:.4f}, transformOrigin: "0 0" }}, {{ opacity: 1, x: 0, y: 0, scale: 1, duration: 0.95, ease: "expo.inOut" }}, {FLY});\n'
s += f'    tl.to("#f-phone", {{ opacity: 0, scale: 1.25, duration: 0.7, ease: "power2.in" }}, {FLY});\n'
s += f'    tl.to("#f-rail", {{ opacity: 0, x: -40, duration: 0.4 }}, {FLY});\n'
s += show("#f-h", 1.5, 0, 0.01) + kin("#f-hh", 1.55, 0.05)
s += f'    tl.to("#f-big", {{ scale: 1.03, duration: {D - FLY - 1.0:.2f}, ease: "none" }}, {FLY + 1.0:.2f});\n'
scene("follow", D, body, s)
add_scene("follow", D, vo, [(FLY, "card-slide-1", 0.3), (1.5, "drop_002", 0.3)])

# ======================================================================= 6 preferences
vo, end = place([("f1", 0)], 0.3)
T1, T2, T3 = 1.7, 4.3, 6.9
D = round(max(end, T3 + 2.5) + 0.5, 2)
chips = "".join(f'<span id="p-c{i}" class="chip" style="font-size:28px; padding:12px 24px">{t}</span>' for i, t in enumerate(["Fastest", "Step-free", "Avoid lifts"]))
inner = (media("p-l0", "assets/ui/located_map_last.png", 0, T1, "img") + media("p-sf", "assets/clips/pref_stepfree_map.mp4", T1, round(T2 - T1, 2))
         + media("p-al", "assets/clips/pref_avoidlifts_map.mp4", T2, round(T3 - T2, 2)) + media("p-fa", "assets/clips/pref_fastest_map.mp4", T3, 2.5)
         + media("p-l1", "assets/ui/fastest_map_last.png", T3 + 2.5, round(D - T3 - 2.5, 2), "img"))
body = f"""
    {big_map("p-big", inner)}
    <div id="p-h" style="position:absolute; left:240px; top:70px; width:1440px; display:flex; align-items:flex-end; justify-content:space-between; opacity:0">
      <div><div class="kicker">Route preferences</div><div id="p-q" class="h2" style="margin-top:10px; font-size:60px">{K("Can everyone find their way?")}</div></div>
      <div style="display:flex; gap:14px; margin-bottom:6px">{chips}</div></div>
    <div id="p-note" class="card" style="left:1120px; top:880px; padding:16px 26px; font-size:28px; font-weight:700; opacity:0">Avoid lifts → the route takes Stairs 2</div>
"""
s = '    tl.set("#p-big", { opacity: 1 }, 0);\n' + show("#p-h", 0.05, 0, 0.01) + kin("#p-q", 0.1, 0.05)
s += '    tl.set("#p-c0", { backgroundColor: "#586B45", color: "#FFFFFF" }, 0);\n'
for t, on, off in [(T1, "#p-c1", "#p-c0"), (T2, "#p-c2", "#p-c1"), (T3, "#p-c0", "#p-c2")]:
    s += f'    tl.to("{on}", {{ backgroundColor: "#586B45", color: "#FFFFFF", scale: 1.06, duration: 0.18 }}, {t});\n'
    s += f'    tl.to("{on}", {{ scale: 1, duration: 0.25 }}, {t + 0.18:.2f});\n'
    s += f'    tl.to("{off}", {{ backgroundColor: "#F4EDDF", color: "#586B45", duration: 0.18 }}, {t});\n'
s += show("#p-note", T2 + 0.6, 14, 0.4) + hide("#p-note", T3 - 0.2, 0.25)
scene("prefs", D, body, s)
add_scene("prefs", D, vo, [(T1, "click_003", 0.45), (T2, "click_003", 0.45), (T3, "click_003", 0.45)])

# ======================================================================= 7 sonar
vo, _ = place([("g1", 0)], 0.2)
DIVE, SON = vo["g1"][1] + 0.25, vo["g1"][1] + 0.85
BACK = SON + 4.67
vo["g2"] = (round(BACK + 0.35, 2), VD["g2"])
D = round(vo["g2"][0] + VD["g2"] + 2.4, 2)
rings = "".join(f'<div id="n-ring{i}" style="position:absolute; left:960px; top:540px; width:400px; height:400px; margin:-200px 0 0 -200px; border-radius:50%; border:3px solid #89E900; opacity:0"></div>' for i in range(3))
mask = "radial-gradient(ellipse 46% 52% at 50% 50%, #000 70%, transparent 100%)"
body = f"""
    <div id="n-night" style="position:absolute; inset:0; background:radial-gradient(ellipse 900px 700px at 960px 540px, #0B1408, #040704 70%); opacity:0"></div>
    {rings}
    <div id="n-glow" style="position:absolute; left:960px; top:540px; width:1200px; height:1200px; margin:-600px 0 0 -600px; border-radius:50%; background:radial-gradient(circle, rgba(137,233,0,0.22), rgba(137,233,0,0) 62%); opacity:0"></div>
    <video id="n-big" class="clip" data-start="{SON:.2f}" data-duration="4.67" data-track-index="3" muted playsinline src="assets/clips/sonar_big.mp4"
      style="position:absolute; left:555px; top:0; width:810px; height:1080px; object-fit:cover; -webkit-mask-image:{mask}; mask-image:{mask}"></video>
    {phone("n-phone", 726, 37, [("n-lift", "assets/ui/at_lift.png", 0, round(SON + 0.1, 2), "img")])}
    <div id="n-title" style="position:absolute; left:0; width:1920px; top:56px; text-align:center; font-size:30px; font-weight:800; color:#89E900; opacity:0">Lift up to First Floor</div>
    <div id="n-note" style="position:absolute; left:0; width:1920px; top:150px; text-align:center; letter-spacing:0.14em; text-transform:uppercase; color:#C7E9C0; font-size:24px; font-weight:700; opacity:0">The app's own 3D floor-change view</div>
    <div id="n-ff" class="card" style="left:240px; top:220px; width:1440px; height:759px; overflow:hidden; opacity:0">
      {media("n-ffv", "assets/clips/first_floor_map.mp4", round(BACK - 0.05, 2), 2.0)}{media("n-ffl", "assets/ui/first_floor_map_last.png", round(BACK + 1.95, 2), round(D - BACK - 1.95, 2), "img")}</div>
    <div id="n-head" style="position:absolute; left:240px; top:70px; width:1500px; opacity:0">
      <div class="kicker">First Floor · Room 104</div>
      <div id="n-hh" class="h2" style="margin-top:10px; font-size:64px">{K("Navigation doesn't stop at the *next* *floor.*")}</div></div>
"""
s = '    tl.fromTo("#n-phone", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }, 0);\n'
s += f'    tl.fromTo("#n-phone", {{ scale: 1 }}, {{ scale: 1.08, duration: {DIVE - 0.2:.2f}, ease: "sine.inOut" }}, 0.1);\n'
s += f'    tl.fromTo("#n-night", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.6, ease: "power2.in" }}, {DIVE - 0.1:.2f});\n'
s += f'    tl.to("#n-phone", {{ scale: 2.8, opacity: 0, duration: 0.6, ease: "expo.in" }}, {DIVE:.2f});  // dive into the screen\n'
s += f'    tl.fromTo("#n-big", {{ opacity: 0, scale: 1.15 }}, {{ opacity: 1, scale: 1, duration: 0.5, ease: "expo.out" }}, {SON:.2f});  // beat-locked music drop\n'
s += f'    tl.fromTo("#n-glow", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.5 }}, {SON:.2f});\n'
s += show("#n-title", SON + 0.2, 0, 0.4) + show("#n-note", SON + 0.6, 0, 0.5) + hide("#n-title", BACK - 0.5, 0.3) + hide("#n-note", BACK - 0.5, 0.3)
for i, dt in enumerate([0, 0.7, 1.4]):
    s += f'    tl.fromTo("#n-ring{i}", {{ opacity: 0.7, scale: 0.4 }}, {{ opacity: 0, scale: 4.2, duration: 2.2, ease: "power2.out" }}, {SON + dt:.2f});\n'
s += f'    tl.to(["#n-glow", "#n-big"], {{ opacity: 0, duration: 0.4 }}, {BACK - 0.3:.2f});\n'
s += f'    tl.to("#n-night", {{ opacity: 0, duration: 0.7, ease: "power2.out" }}, {BACK - 0.2:.2f});\n'
s += f'    tl.fromTo("#n-ff", {{ opacity: 0, scale: 1.12 }}, {{ opacity: 1, scale: 1, duration: 0.8, ease: "expo.out" }}, {BACK - 0.1:.2f});\n'
s += show("#n-head", BACK + 1.0, 0, 0.01) + kin("#n-hh", BACK + 1.05, 0.06)
scene("sonar", D, body, s)
SONAR_DROP_ABS = T0[0] + SON
add_scene("sonar", D, vo, [(DIVE, "card-shove-1", 0.25), (SON, "impactSoft_heavy_003", 0.55), (SON, "bong_001", 0.5), (SON + 1.2, "bong_001", 0.28), (BACK, "card-slide-1", 0.28), (BACK + 1.0, "drop_002", 0.38)])

# ======================================================================= 8 guide
vo, end = place([("h1", 0), ("h2", 0.45), ("h3", 0.45)], 0.3)
D = round(end + 1.0, 2)
h2, h3 = vo["h2"][0], vo["h3"][0]
ring = (f'<div id="g-ring" class="clip" data-start="{h2 + 0.8:.2f}" data-duration="2.8" data-track-index="3" '
        'style="position:absolute; left:291px; top:618px; width:124px; height:49px; border-radius:24px; border:4px solid #F59E0B"></div>')
body = f"""
    {big_map("g-map", '<img src="assets/ui/arrived_map.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover">', 240, 220, 1440, 759)}
    <div id="g-a" style="position:absolute; left:240px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Step by step · the app's own words</div>
      <div id="g-ah" class="h2" style="margin-top:10px; font-size:64px">{K("&quot;You have arrived at *Room* *104.&quot;*")}</div></div>
    {phone("g-phone", 1230, 37, [("g-steps", "assets/ui/steps.png", 0, round(h3, 2), "img"), ("g-sheet", "assets/ui/walk_sheet.png", round(h3, 2), 1.0, "img"), ("g-walk", "assets/clips/walk.mp4", round(h3 + 1.0, 2), 2.0, "video"), ("g-wl", "assets/ui/walk_last.png", round(h3 + 3.0, 2), round(D - h3 - 3.0, 2), "img")], ring)}
    <div id="g-b" style="position:absolute; left:150px; top:320px; width:960px; opacity:0">
      <div class="kicker">Re-locate</div>
      <div id="g-bh" class="h2" style="margin-top:14px">{K("Wrong turn?|*Scan* *any* *marker.*")}</div>
      <div class="body" style="margin-top:22px">The route starts again from wherever you are.</div></div>
    <div id="g-c" style="position:absolute; left:150px; top:290px; width:980px; opacity:0">
      <span class="pill" style="background:#005A32; color:#fff">Beta</span>
      <div id="g-ch" class="h2" style="margin-top:20px">{K("Scan once.|*Then* *just* *walk.*")}</div>
      <div style="font-size:28px; color:#586B45; margin-top:18px">Turns read aloud. Position between markers is estimated.</div></div>
"""
s = '    tl.fromTo("#g-map", { opacity: 0, scale: 1.06 }, { opacity: 1, scale: 1, duration: 0.6, ease: "expo.out" }, 0);\n'
s += '    tl.set("#g-phone", { opacity: 0 }, 0);\n'
s += show("#g-a", 0.1, 0, 0.01) + kin("#g-ah", 0.15, 0.05)
s += hide("#g-a", h2 - 0.45, 0.3) + hide("#g-map", h2 - 0.45, 0.3)
s += f'    tl.fromTo("#g-phone", {{ opacity: 0, x: 200 }}, {{ opacity: 1, x: 0, duration: 0.6, ease: "expo.out" }}, {h2 - 0.2:.2f});\n'
s += show("#g-b", h2, 20, 0.4) + kin("#g-bh", h2, 0.05) + hide("#g-b", h3 - 0.4, 0.3)
s += f'    tl.fromTo("#g-ring", {{ scale: 1.3, opacity: 0 }}, {{ scale: 1, opacity: 1, duration: 0.35, ease: "back.out(2)" }}, {h2 + 0.8:.2f});\n'
s += show("#g-c", h3, 20, 0.4) + kin("#g-ch", h3 + 0.05, 0.06)
scene("guide", D, body, s)
add_scene("guide", D, vo, [(0.2, "bong_001", 0.3), (h2 + 0.8, "click2", 0.4), (h3, "switch_002", 0.4), (h3 + 1.2, "footstep_wood_002", 0.25), (h3 + 1.8, "footstep_wood_002", 0.22), (h3 + 2.4, "footstep_wood_002", 0.2)])

# ======================================================================= 9 proof
vo, end = place([("i1", 0), ("i2", 0.45), ("i3", 0.5)], 0.4)
D = round(end + 1.4, 2)
i2, i3 = vo["i2"][0], vo["i3"][0]
bmap = json.loads((ROOT.parent.parent.parent / "assets/map/building.json").read_text())
pos = {n["id"]: (n["x"], n["y"], n["floor"]) for n in bmap["nodes"]}
EDGES = [(13,4),(4,5),(5,6),(6,7),(3,2),(2,1),(1,10),(10,12),(12,14),(13,9),(9,11),(11,8),(8,3),(7,10),(4,3),
         (27,28),(28,18),(18,19),(19,20),(20,21),(27,23),(23,25),(25,22),(22,17),(17,16),(16,15),(15,24),(24,26),(21,24),(18,17),
         (9,23),(11,25),(10,24),(12,26)]
GW, GH = 760, 640


def gp(n):
    x, y, f = pos[n]
    return 40 + x * 0.88, (40 if f == 1 else 360) + y * 0.52


gsvg = [f'<svg width="{GW}" height="{GH}" viewBox="0 0 {GW} {GH}">',
        f'<text x="40" y="26" font-family="Roboto" font-weight="800" font-size="20" letter-spacing="2" fill="#586B45">FIRST FLOOR</text>',
        f'<text x="40" y="346" font-family="Roboto" font-weight="800" font-size="20" letter-spacing="2" fill="#586B45">GROUND FLOOR</text>']
for a, b in EDGES:
    (x1, y1), (x2, y2) = gp(a), gp(b)
    vert = pos[a][2] != pos[b][2]
    gsvg.append(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="#C9B993" stroke-width="{2 if vert else 3}" {"stroke-dasharray=\"6 6\"" if vert else ""}/>')


def pline(pid, seq, col, wdt, dash=""):
    pts = " ".join(f"{gp(n)[0]:.0f},{gp(n)[1]:.0f}" for n in seq)
    L = sum(math.dist(gp(a), gp(b)) for a, b in zip(seq, seq[1:]))
    return f'<polyline id="{pid}" points="{pts}" fill="none" stroke="{col}" stroke-width="{wdt}" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="{L:.0f}" stroke-dashoffset="{L:.0f}"/>'


gsvg.append(pline("q-old", [11, 9, 23, 25], "#DC2626", 7))
gsvg.append(pline("q-new", [11, 25], "#005A32", 9))
for n in pos:
    x, y = gp(n)
    hl = n in (11, 25)
    gsvg.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{10 if hl else 6}" fill="{"#1D4ED8" if n == 11 else "#DC2626" if n == 25 else "#F4EDDF"}" stroke="#586B45" stroke-width="2"/>')
for n, lab, dx, dy in [(11, "Stairs 1", 16, 26), (25, "Stairs 3", 16, -14), (9, "Lift 1", -70, 6), (23, "Lift 3", -70, 6)]:
    x, y = gp(n)
    gsvg.append(f'<text x="{x + dx:.0f}" y="{y + dy:.0f}" font-family="Roboto" font-weight="700" font-size="20" fill="#22301A">{lab}</text>')
gsvg.append("</svg>")
pairs = json.loads((W / "esp32_pairs.json").read_text())
bad = {(a, b) for a, b in pairs["bad"]}
CELL = 19
grid = [f'<svg width="{28 * CELL}" height="{28 * CELL}" viewBox="0 0 {28 * CELL} {28 * CELL}">']
for a in range(1, 29):
    for b in range(1, 29):
        x, y = (b - 1) * CELL, (a - 1) * CELL
        cls = "gd" if a == b else ("gb" if (a, b) in bad else "gg")
        grid.append(f'<rect class="{cls}" x="{x + 1}" y="{y + 1}" width="{CELL - 2}" height="{CELL - 2}" rx="2" fill="#E9DFCB"/>')
grid.append("</svg>")
body = f"""
    <div id="q-h" style="position:absolute; left:150px; top:70px; width:1600px; opacity:0">
      <div class="kicker">Under the hood</div>
      <div id="q-hh" class="h2" style="margin-top:10px; font-size:60px">{K("A corrected *bidirectional* *Dijkstra* search.")}</div></div>
    <div id="q-g" class="card" style="left:150px; top:230px; width:{GW}px; height:{GH + 40}px; padding:20px 0 0 0; opacity:0">{''.join(gsvg)}</div>
    <div id="q-old-t" class="card" style="left:170px; top:852px; padding:10px 18px; font-size:24px; font-weight:700; color:#DC2626; opacity:0">First version: via both lifts · cost 3</div>
    <div id="q-new-t" class="card" style="left:560px; top:852px; padding:10px 18px; font-size:24px; font-weight:700; color:#005A32; opacity:0">Now: straight up the stairs · cost 2</div>
    <div id="q-gr" style="position:absolute; left:1060px; top:330px; opacity:0">{''.join(grid)}
      <div style="font-size:22px; letter-spacing:0.12em; color:#586B45; margin-top:12px; font-weight:700">FROM ↓ · TO → · 28 PLACES</div></div>
    <div id="q-n1" style="position:absolute; left:1060px; top:230px; opacity:0"><span style="font-size:72px; font-weight:900; color:#DC2626">36</span>
      <span style="font-size:32px; font-weight:700"> of 756 trips got a longer route</span></div>
    <div id="q-n2" style="position:absolute; left:1060px; top:230px; opacity:0"><span style="font-size:72px; font-weight:900; color:#005A32">784</span>
      <span style="font-size:32px; font-weight:700"> of 784 pairs match the shortest route</span></div>
    <div id="q-t" class="pill" style="position:absolute; left:1060px; top:900px; background:#005A32; color:#fff; font-size:30px; padding:12px 24px; opacity:0">✓ 192 automated tests</div>
    <div id="q-esp" class="card" style="left:1060px; top:480px; padding:12px 22px; font-size:28px; font-weight:700; opacity:0">First version: an ESP32 board computed the routes</div>
"""
s = show("#q-h", 0.3, 0, 0.01) + kin("#q-hh", 0.35, 0.06)
s += show("#q-g", 1.0, 20, 0.6)
s += show("#q-esp", i2 + 0.3, 12, 0.4) + hide("#q-esp", i2 + 2.5, 0.3)
s += f'    tl.to("#q-old", {{ strokeDashoffset: 0, duration: 1.2, ease: "power1.inOut" }}, {i2 + 1.4:.2f});\n'
s += show("#q-old-t", i2 + 2.2, 10, 0.4)
s += show("#q-gr", i2 + 2.8, 20, 0.5)
s += f'    tl.to("#q-gr .gb", {{ fill: "#DC2626", duration: 0.2, stagger: {{ each: 0.04, from: "random" }} }}, {i2 + 3.6:.2f});\n'
s += show("#q-n1", i2 + 4.2, 14, 0.5)
s += f'    tl.to("#q-new", {{ strokeDashoffset: 0, duration: 0.7, ease: "power2.out" }}, {i3 + 0.4:.2f});\n'
s += show("#q-new-t", i3 + 0.9, 10, 0.4)
s += hide("#q-n1", i3 + 1.0, 0.25)
s += f'    tl.to("#q-gr .gg, #q-gr .gb", {{ fill: "#2E7D4F", duration: 0.25, stagger: {{ each: 0.0012, from: "start" }} }}, {i3 + 1.2:.2f});\n'
s += show("#q-n2", i3 + 1.6, 14, 0.5)
s += f'    tl.fromTo("#q-t", {{ opacity: 0, scale: 0.8 }}, {{ opacity: 1, scale: 1, duration: 0.4, ease: "back.out(2)" }}, {i3 + 4.6:.2f});\n'
scene("proof", D, body, s)
add_scene("proof", D, vo, [(1.0, "card-place-2", 0.3), (i2 + 1.4, "card-slide-1", 0.25), (i2 + 3.6, "chips-stack-2", 0.35), (i3 + 0.4, "drop_002", 0.35), (i3 + 1.2, "chips-collide-1", 0.35), (i3 + 4.6, "impactBell_heavy_003", 0.3)])

# ======================================================================= 10 offline
vo, end = place([("j1", 0)], 0.3)
D = round(end + 1.0, 2)
j1 = vo["j1"][0]
nos = ["No GPS", "No Wi-Fi", "No beacons", "No server"]
chipl = "".join(
    f'<div id="o-n{i}" style="display:flex; align-items:center; gap:18px; opacity:0"><div style="width:46px; height:46px; border-radius:50%; border:4px solid #586B45; position:relative">'
    f'<div style="position:absolute; left:-4px; top:17px; width:46px; height:5px; background:#DC2626; transform:rotate(-45deg)"></div></div>'
    f'<div style="font-size:58px; font-weight:900; letter-spacing:-0.03em">{n}</div></div>' for i, n in enumerate(nos))
body = f"""
    {phone("o-phone", 230, 37, [("o-loc", "assets/ui/located_end.png", 0, D, "img")])}
    <div id="o-air" class="card" style="left:800px; top:150px; padding:26px 34px; display:flex; align-items:center; gap:24px; opacity:0">
      <svg width="64" height="64" viewBox="0 0 24 24"><path fill="#005A32" d="M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"/></svg>
      <div><div style="font-size:40px; font-weight:800">Airplane mode</div><div class="olive" style="font-size:28px">Everything off. Still works.</div></div>
      <div style="width:92px; height:52px; border-radius:26px; background:#C9B993; position:relative; margin-left:30px"><div id="o-knob" style="position:absolute; left:6px; top:6px; width:40px; height:40px; border-radius:50%; background:#fff"></div></div></div>
    <div style="position:absolute; left:820px; top:400px; display:flex; flex-direction:column; gap:24px">{chipl}</div>
"""
s = '    tl.fromTo("#o-phone", { x: -300, opacity: 0 }, { x: 0, opacity: 1, duration: 0.7, ease: "expo.out" }, 0);\n'
s += show("#o-air", 0.3)
s += '    tl.to("#o-knob", { x: 40, duration: 0.25, ease: "power2.out" }, 0.6);\n'
s += '    tl.to("#o-knob", { backgroundColor: "#005A32", duration: 0.25 }, 0.6);\n'
for i, dt in enumerate([1.95, 2.85, 3.75, 4.85]):
    s += f'    tl.fromTo("#o-n{i}", {{ opacity: 0, x: -30 }}, {{ opacity: 1, x: 0, duration: 0.4, ease: "expo.out" }}, {j1 + dt:.2f});\n'
scene("offline", D, body, s)
add_scene("offline", D, vo, [(0.6, "switch_002", 0.5)] + [(j1 + dt, "drop_002", 0.32) for dt in (1.95, 2.85, 3.75, 4.85)])

# ======================================================================= 11 setup
vo, end = place([("k1", 0)], 0.3)
D = round(end + 1.8, 2)
body = f"""
    {phone("u-phone", 230, 37, [("u-ed1", "assets/ui/editor_map_guide.png", 0, 1.9, "img"), ("u-ed2", "assets/ui/editor_map.png", 1.9, round(D - 1.9, 2), "img")])}
    <div id="u-s" style="position:absolute; left:800px; top:240px; width:560px; opacity:0">
      <div class="kicker">Set-up</div>
      <div id="u-sh" class="h2" style="margin-top:14px; font-size:58px">{K("From each block's own *floor* *plan.*")}</div>
      <div class="body" style="margin-top:22px">The app drafts the map. A person reviews it and prints the markers.</div></div>
    {phone("u-phone2", 1400, 37, [("u-home2", "assets/ui/home.png", 0, D, "img")])}
    <div id="u-file" class="card" style="left:560px; top:640px; padding:20px 26px; display:flex; align-items:center; gap:18px; opacity:0">
      <svg width="48" height="48" viewBox="0 0 24 24"><path fill="#586B45" d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>
      <div><div style="font-size:30px; font-weight:800">Indoor Nav demo building.indoornav</div><div class="olive" style="font-size:28px">One file: plans, places, markers</div></div></div>
"""
s = '    tl.fromTo("#u-phone", { x: -300, opacity: 0 }, { x: 0, opacity: 1, duration: 0.7, ease: "expo.out" }, 0);\n'
s += show("#u-s", 0.3, 20, 0.4) + kin("#u-sh", 0.35, 0.06)
s += '    tl.fromTo("#u-phone2", { x: 500, opacity: 0 }, { x: 0, opacity: 1, duration: 0.8, ease: "expo.out" }, 2.8);\n'
s += '    tl.fromTo("#u-file", { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.3, ease: "back.out(2)" }, 3.3);\n'
s += '    tl.to("#u-file", { x: 720, y: -40, duration: 1.0, ease: "power3.inOut" }, 3.7);\n'
scene("setup", D, body, s, wipe_out=True)
add_scene("setup", D, vo, [(2.8, "card-place-2", 0.3), (3.7, "card-slide-1", 0.38), (D - 0.4, "card-shove-1", 0.3)])

# ======================================================================= 12 campus future
vo, end = place([("m1", 0)], 0.4)
D = round(end + 1.4, 2)
cblocks = [(140, 120, 300, 180, "Block A"), (520, 90, 260, 240, "Block B"), (860, 140, 320, 170, "Block C"), (1260, 100, 280, 210, "Library"),
           (140, 440, 260, 220, "Labs"), (520, 470, 330, 160, "Block D"), (930, 430, 250, 250, "Admin"), (1260, 460, 300, 180, "Hostel")]
csv = ['<svg width="1600" height="720" viewBox="0 0 1600 720">',
       '<g stroke="#FBF6EC" stroke-width="40" fill="none" stroke-linecap="round"><path d="M40 380 H1580 M470 30 V700 M1220 30 V700"/></g>']
for i, (x, y, w, h, lab) in enumerate(cblocks):
    if i == 1:
        csv.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="#586B45" stroke="#005A32" stroke-width="5"/>'
                   f'<text x="{x + w / 2}" y="{y + h / 2 + 10}" text-anchor="middle" font-family="Roboto" font-weight="800" font-size="30" fill="#fff">Today</text>')
    else:
        csv.append(f'<g id="w-b{i}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="rgba(244,237,223,0.7)" stroke="#586B45" stroke-width="4" stroke-dasharray="14 10"/>'
                   f'<text x="{x + w / 2}" y="{y + h / 2 + 10}" text-anchor="middle" font-family="Roboto" font-weight="700" font-size="28" fill="#586B45">{lab}</text></g>')
csv.append("</svg>")
body = f"""
    <div id="w-h" style="position:absolute; left:160px; top:60px; width:1600px; opacity:0">
      <div class="kicker">Our next step · planned</div>
      <div id="w-hh" class="h2" style="margin-top:10px; font-size:62px">{K("One block today. *Every* *block* *next.*")}</div></div>
    <div id="w-map" class="card" style="left:160px; top:240px; width:1600px; height:720px; opacity:0">{''.join(csv)}</div>
    <div id="w-lib" class="card" style="left:1180px; top:820px; padding:18px 28px; display:flex; align-items:center; gap:16px; opacity:0">
      <span class="pill" style="background:#F59E0B; color:#22301A">Planned</span><div style="font-size:32px; font-weight:800">One shared map library</div></div>
"""
s = show("#w-h", 0.3, 0, 0.01) + kin("#w-hh", 0.35, 0.06)
s += '    tl.fromTo("#w-map", { opacity: 0, scale: 0.96 }, { opacity: 1, scale: 1, duration: 0.7, ease: "expo.out" }, 0.4);\n'
for k, i in enumerate([0, 2, 3, 4, 5, 6, 7]):
    s += f'    tl.fromTo("#w-b{i}", {{ opacity: 0.25 }}, {{ opacity: 1, duration: 0.3 }}, {1.6 + k * 0.4:.2f});\n'
s += show("#w-lib", 4.6, 16, 0.4)
scene("future", D, body, s, wipe_in=True)
add_scene("future", D, vo, [(1.6 + k * 0.4, "drop_002", 0.22) for k in range(0, 7, 2)] + [(4.6, "select_008", 0.35)])

# ======================================================================= 13 industries
vo, end = place([("m2", 0)], 0.3)
m2 = vo["m2"][0]
TEASE = round(end + 0.3, 2)
D = round(TEASE + 3.4, 2)
ICONS = [("Hospitals", "M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z", 3.75),
         ("Malls", "M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-1.99.9-1.99 2L3 20c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm0 10c-2.76 0-5-2.24-5-5h2c0 1.66 1.34 3 3 3s3-1.34 3-3h2c0 2.76-2.24 5-5 5z", 4.55),
         ("Airports", "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z", 5.15),
         ("Exam halls", "M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3z", 5.95)]
cards = "".join(f'<div id="x-i{i}" class="card" style="position:relative; width:340px; height:340px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:22px; opacity:0">'
                f'<svg width="120" height="120" viewBox="0 0 24 24"><path fill="#005A32" d="{p}"/></svg><div style="font-size:42px; font-weight:800">{n}</div></div>'
                for i, (n, p, _) in enumerate(ICONS))
body = f"""
    <div id="x-h" style="position:absolute; left:160px; top:120px; width:1600px; opacity:0">
      <div class="kicker">Beyond our campus</div>
      <div id="x-hh" class="h2" style="margin-top:10px; font-size:62px">{K("Anywhere people get *lost* *indoors.*")}</div></div>
    <div id="x-row" style="position:absolute; left:160px; top:380px; width:1600px; display:flex; justify-content:space-between">{cards}</div>
    <div id="x-n" style="position:absolute; left:0; width:1920px; top:340px; text-align:center; opacity:0">
      <div class="h2" style="color:#4A5340">What if you could just walk through a building once?</div>
      <div style="margin-top:34px"><span class="pill" style="background:#F59E0B; color:#22301A">Planned</span>
        <div id="x-nh" class="h1" style="margin-top:22px; font-size:96px">{K("Next: Walk it once. *It* *maps* *itself.*")}</div></div></div>
"""
s = show("#x-h", 0.2, 0, 0.01) + kin("#x-hh", 0.25, 0.06)
for i, (_, _, dt) in enumerate(ICONS):
    s += f'    tl.fromTo("#x-i{i}", {{ opacity: 0, y: 50 }}, {{ opacity: 1, y: 0, duration: 0.55, ease: "expo.out" }}, {m2 + dt - 0.3:.2f});\n'
s += hide("#x-h", TEASE - 0.3, 0.3) + hide("#x-row", TEASE - 0.3, 0.3)
s += show("#x-n", TEASE, 16, 0.4) + kin("#x-nh", TEASE + 0.9, 0.06)
scene("industries", D, body, s, wipe_out=True)
add_scene("industries", D, vo, [(m2 + dt - 0.3, "card-place-2", 0.3) for _, _, dt in ICONS] + [(TEASE + 0.9, "select_008", 0.35), (D - 0.4, "card-shove-1", 0.3)])

# ======================================================================= 14 close
vo, end = place([("l1", 0), ("l2", 0.7)], 0.3)
l2 = vo["l2"][0]
D = round(end + 3.8, 2)
COLL = 4.1  # "Today, all it takes..."


def icon_card(cid, x, title, sub, svgp):
    return (f'<div id="{cid}" class="card" style="left:{x}px; top:330px; width:400px; height:340px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:18px; opacity:0">'
            f'<svg width="110" height="110" viewBox="0 0 24 24"><path fill="#586B45" d="{svgp}"/></svg><div style="font-size:40px; font-weight:800">{title}</div><div class="olive" style="font-size:28px">{sub}</div></div>')


chip_p = "M15 9H9v6h6V9zm-2 4h-2v-2h2v2zm8-2V9h-2V7c0-1.1-.9-2-2-2h-2V3h-2v2h-2V3H9v2H7c-1.1 0-2 .9-2 2v2H3v2h2v2H3v2h2v2c0 1.1.9 2 2 2h2v2h2v-2h2v2h2v-2h2c1.1 0 2-.9 2-2v-2h2v-2h-2v-2h2zm-4 6H7V7h10v10z"
wifi_p = "M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9zm8 8l3 3 3-3c-1.65-1.66-4.34-1.66-6 0zm-4-4l2 2c2.76-2.76 7.24-2.76 10 0l2-2C15.14 9.14 8.87 9.14 5 13z"
cloud_p = "M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM19 18H6c-2.21 0-4-1.79-4-4s1.79-4 4-4h.71C7.37 7.69 9.48 6 12 6c3.04 0 5.5 2.46 5.5 5.5v.5H19c1.66 0 3 1.34 3 3s-1.34 3-3 3z"
body = f"""
    <div id="z-k" style="position:absolute; left:150px; top:170px; opacity:0"><div class="kicker">Where it started</div></div>
    {icon_card("z-1", 150, "ESP32", "microcontroller", chip_p)}
    {icon_card("z-2", 760, "Wi-Fi", "to reach the board", wifi_p)}
    {icon_card("z-3", 1370, "Cloud database", "Firebase Realtime DB", cloud_p)}
    {phone("z-phone", 560, 37, [("z-loc", "assets/ui/located_end.png", COLL, round(l2 - 0.4 - COLL, 2), "img")])}
    <div id="z-paper" style="position:absolute; left:1060px; top:560px; width:250px; height:250px; background:#fff; padding:6px; box-sizing:border-box; box-shadow:0 18px 36px rgba(34,48,26,0.22); opacity:0">
      <img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block"></div>
    <div id="z-now" style="position:absolute; left:1060px; top:230px; width:760px; opacity:0">
      <div id="z-nh" class="h2">{K("Today: a phone,|*and* *a* *sticker.*")}</div>
      <div class="body" style="margin-top:18px; font-size:28px">Flutter · OpenCV ArUco · on-device Dijkstra · offline</div></div>
    <div id="z-end" style="position:absolute; left:0; width:1920px; top:360px; display:flex; flex-direction:column; align-items:center; opacity:0">
      <div class="kicker" style="margin-bottom:26px">Built for our college</div>
      <div style="display:flex; align-items:center; gap:30px">{COMPASS.format(s=150, c="#005A32")}<div style="font-size:160px; font-weight:900; letter-spacing:-0.045em; color:#005A32">Indoor Nav</div></div>
      <div id="z-tag" class="h2" style="margin-top:30px; font-size:56px; opacity:0">{K("Find your way. Anywhere indoors.")}</div></div>
    <div id="z-credit" data-layout-ignore style="position:absolute; left:0; width:1920px; top:1020px; text-align:center; font-size:22px; color:#586B45; opacity:0">Music: Sascha Ende, ende.app (CC BY 4.0) · App screens rendered from the Indoor Nav app</div>
"""
s = show("#z-k", 0.2)
for i, t in enumerate([0.4, 1.1, 1.8]):
    s += f'    tl.fromTo("#z-{i + 1}", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }}, {t});\n'
for i in range(3):
    s += f'    tl.to("#z-{i + 1}", {{ opacity: 0, scale: 0.3, x: {[560, -50, -660][i]}, duration: 0.5, ease: "power3.in" }}, {COLL - 0.3:.2f});\n'
s += hide("#z-k", COLL - 0.4)
s += f'    tl.fromTo("#z-phone", {{ opacity: 0, scale: 0.85 }}, {{ opacity: 1, scale: 1, duration: 0.6, ease: "expo.out" }}, {COLL});\n'
s += f'    tl.fromTo("#z-paper", {{ opacity: 0, scale: 1.4, rotation: -12 }}, {{ opacity: 1, scale: 1, rotation: -4, duration: 0.3, ease: "power4.in" }}, {COLL + 2.0:.2f});\n'
s += show("#z-now", COLL + 0.2, 20, 0.4) + kin("#z-nh", COLL + 0.2, 0.06)
s += hide("#z-phone", l2 - 0.5, 0.35) + hide("#z-paper", l2 - 0.5, 0.35) + hide("#z-now", l2 - 0.5, 0.35)
s += f'    tl.fromTo("#z-end", {{ opacity: 0, scale: 0.94 }}, {{ opacity: 1, scale: 1, duration: 0.8, ease: "expo.out" }}, {l2 - 0.1:.2f});\n'
s += kin("#z-tag", l2 + 1.4, 0.06) + show("#z-credit", l2 + VD["l2"] + 0.1, 0)
scene("close", D, body, s)
add_scene("close", D, vo, [(0.4, "card-place-2", 0.32), (1.1, "card-place-2", 0.32), (1.8, "card-place-2", 0.32), (COLL - 0.3, "impactSoft_heavy_003", 0.4), (COLL + 2.0, "impactWood_medium_001", 0.6), (l2 - 0.1, "impactBell_heavy_000", 0.5)])

TOTAL = round(T0[0], 2)

# ======================================================================= captions
cap_items = []
for vid, start in VOICE:
    text, d = CAP[vid], VD[vid]
    s0, s1 = start + 0.15, start + d - 0.3
    parts, cur = [], []
    for w in text.split(" "):
        cur.append(w)
        if (w.endswith((",", ".", "?", ":")) and len(cur) >= 3) or len(cur) >= 8:
            parts.append(" ".join(cur)); cur = []
    if cur:
        if parts and len(cur) < 3:
            parts[-1] += " " + " ".join(cur)
        else:
            parts.append(" ".join(cur))
    total = sum(len(p) for p in parts)
    t = s0
    for p in parts:
        span = (s1 - s0) * len(p) / total
        cap_items.append((round(t, 2), round(span, 2), p))
        t += span
caps = "\n".join(f'    <div id="cap{i:03d}" class="clip cap" data-start="{st}" data-duration="{max(0.4, d)}" data-track-index="1"><span>{txt}</span></div>'
                 for i, (st, d, txt) in enumerate(cap_items))
(COMP / "captions.html").write_text(f"""<template>
  <style>
    #root {{ position: absolute; inset: 0; pointer-events: none; font-family: Roboto, sans-serif; }}
    .cap {{ position: absolute; left: 0; width: 1920px; top: 1000px; text-align: center; }}
    .cap span {{ display: inline-block; padding: 10px 24px; border-radius: 12px; background: rgba(34,48,26,0.86); color: #F4EDDF; font-size: 32px; font-weight: 600; letter-spacing: 0.005em; }}
  </style>
  <div id="root" data-composition-id="captions" data-width="1920" data-height="1080" data-duration="{TOTAL}" data-layout-allow-caption-zone>
{caps}
  </div>
  <script>
    window.__timelines["captions"] = gsap.timeline({{ paused: true }});
  </script>
</template>
""", encoding="utf-8")

# ======================================================================= root
hosts = "\n".join(
    f'      <div id="{sid}" data-composition-id="{sid}" data-composition-src="compositions/{sid}.html" data-start="{st}" '
    f'data-duration="{d}" data-track-index="1" data-track-kind="graphics" data-width="1920" data-height="1080"></div>'
    for sid, st, d in TIMELINE)
hosts += (f'\n      <div id="captions" data-composition-id="captions" data-composition-src="compositions/captions.html" data-start="0" '
          f'data-duration="{TOTAL}" data-track-index="2" data-track-kind="captions" data-width="1920" data-height="1080" style="z-index:90; position:absolute; inset:0"></div>')
audio = []
for vid, st in VOICE:
    audio.append(f'      <audio id="vo-{vid}" data-start="{st}" data-duration="{VD[vid]}" data-track-index="20" data-volume="1" src="{VO_DIR}/{vid}.wav"></audio>')
M1 = "assets/music/happy-beats-business-moves-vol-12-by-ende-dot-app.mp3"
M2 = "assets/music/happy-beats-business-moves-vol-1-by-ende-dot-app.mp3"
DROP = round(SONAR_DROP_ABS, 2)
audio.append(f'      <audio id="music-a" data-start="0" data-duration="{round(DROP - 0.5, 2)}" data-track-index="10" data-volume="0.15" data-fade-in="1.0" data-fade-out="1.2" src="{M1}"></audio>')
# beat-locked: vol-1's strong cue at 48.02 s lands on the sonar drop
audio.append(f'      <audio id="music-b" data-start="{DROP}" data-duration="4.6" data-media-start="48.02" data-track-index="11" data-volume="0.34" data-fade-out="0.8" src="{M2}"></audio>')
audio.append(f'      <audio id="music-c" data-start="{round(DROP + 4.6, 2)}" data-duration="{round(TOTAL - DROP - 4.6, 2)}" data-media-start="52.62" data-track-index="10" data-volume="0.14" data-fade-out="3.5" src="{M2}"></audio>')
lanes = []
for i, (t, name, vol) in enumerate(sorted(SFX)):
    d = dur(f"assets/sfx/{name}.ogg")
    for li, e in enumerate(lanes):
        if e <= t:
            lanes[li] = t + d
            break
    else:
        lanes.append(t + d)
        li = len(lanes) - 1
    audio.append(f'      <audio id="sfx{i:02d}" data-start="{t}" data-duration="{d}" data-track-index="{30 + li}" data-volume="{vol}" src="assets/sfx/{name}.ogg"></audio>')
(ROOT / "index.html").write_text(f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <title>Via — launch film</title>
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
""", encoding="utf-8")
(W / "timeline.json").write_text(json.dumps({"total": TOTAL, "scenes": TIMELINE, "voice": VOICE, "drop": DROP, "captions": cap_items}, indent=1))
print(f"film {TOTAL}s, {len(TIMELINE)} scenes, {len(VOICE)} lines, {len(cap_items)} captions, {len(SFX)} sfx, drop at {DROP}s")
for sid, st, d in TIMELINE:
    print(f"  {st:7.2f}  {sid:11s} {d:5.2f}s")
