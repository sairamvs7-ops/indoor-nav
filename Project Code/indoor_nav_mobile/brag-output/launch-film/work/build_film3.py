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


CAP = {
    "a1": "Outside, your phone always knows where you are. But step inside a big building, and GPS goes quiet.",
    "a2": "On our own campus, new students and visitors can easily lose their way.",
    "b1": "So we're building Via for our college. It gives you directions inside a building, using just your phone, in three simple steps: pick, scan, and follow.",
    "c1": "First, pick where you want to go.",
    "d1": "Then scan the nearest marker. It's just a printed sticker on the wall, and the phone instantly knows where you are.",
    "e1": "Now follow your route, drawn on the building's own floor plan, and worked out right on the phone.",
    "f1": "If you need a route without stairs, choose Step-free. If you would rather take the stairs, choose Avoid lifts.",
    "g1": "And when your route changes floors, the app shows you exactly how you get there, in 3D.",
    "g2": "Watch the floor map rise into 3D, as your dot rides the lift up to the next floor.",
    "h1": "Clear steps guide you all the way to the door. And if you take a wrong turn, just scan any marker, and your route starts again from there.",
    "h2": "And in beta: scan once, then simply walk, with every turn read aloud.",
    "i1": "Under the hood is a corrected, bidirectional Dijkstra search. Our first ESP32 version took a longer route on 36 of 756 trips.",
    "i2": "Today, every pair of places gets the shortest route, and 192 automated tests keep it that way.",
    "j1": "And it all works offline, with no GPS, no Wi-Fi, no beacons, and no server.",
    "k1": "Each block is set up from its own floor plan, and shared as a single file.",
    "m1": "Next, we want to map every block on our campus, in one shared map library.",
    "m2": "Beyond campus, it can help hospitals, malls, airports, and exam halls. And one day, you could walk through a building once, and let it map itself.",
    "l1": "It started with a microcontroller and a cloud database. Now, all it takes is a phone, and a sticker. Via. Find your way, anywhere indoors.",
}


def at(vid, frac):
    """Local time a given share of the way through a line's speech."""
    s, d = vo[vid]
    return round(s + 0.12 + (d - 0.37) * frac, 2)


def tail(end, t=0.35):
    return round(end + t, 2)


# One campus illustration, used for the opening and for the future scene.
# Blocks sit strictly between the roads (vertical roads at x 490/940/1270,
# horizontal at y 450/880, each 54 px wide).
CB = [(80, 110, 360, 210, "Block A"), (550, 110, 330, 240, "Block B"), (990, 150, 230, 230, "Our block"), (1320, 120, 300, 220, "Library"),
      (90, 530, 330, 260, "Labs"), (560, 590, 320, 180, "Block D"), (990, 540, 230, 280, "Admin"), (1320, 590, 320, 190, "Hostel")]
OURS = 2


def campus_svg(prefix, today=False):
    out = ['<svg width="1920" height="1080" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#E5D9C2"/>',
           '<g fill="#CFD9B5"><ellipse cx="1740" cy="330" rx="110" ry="60"/><ellipse cx="250" cy="980" rx="150" ry="50"/><ellipse cx="1100" cy="985" rx="140" ry="45"/></g>',
           '<g stroke="#FBF6EC" stroke-width="54" fill="none" stroke-linecap="round"><path d="M60 450 H1860 M60 880 H1860 M490 60 V1020 M940 60 V1020 M1270 60 V1020"/></g>']
    for i, (x, y, w, h, lab) in enumerate(CB):
        if i == OURS:
            out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{"#586B45" if today else "#E3E8D3"}" stroke="#586B45" stroke-width="5"/>'
                       + (f'<text x="{x + w / 2}" y="{y + h / 2 - 6}" text-anchor="middle" font-family="Roboto" font-weight="800" font-size="32" fill="#fff">Our block</text>'
                          f'<text x="{x + w / 2}" y="{y + h / 2 + 30}" text-anchor="middle" font-family="Roboto" font-weight="700" font-size="24" fill="#C7E9C0">mapped today</text>'
                          if today else
                          f'<text x="{x + w / 2}" y="{y + h / 2 + 11}" text-anchor="middle" font-family="Roboto" font-weight="800" font-size="32" fill="#22301A">{lab}</text>'))
        else:
            dash = ' stroke-dasharray="14 10"' if today else ""
            out.append(f'<g id="{prefix}{i}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="#F4EDDF" stroke="#C9B993" stroke-width="4"{dash}/>'
                       f'<text x="{x + w / 2}" y="{y + h / 2 + 10}" text-anchor="middle" font-family="Roboto" font-weight="700" font-size="28" fill="#8A8064">{lab}</text></g>')
    out.append("</svg>")
    return "".join(out)


def dot(did, extra=""):
    return (f'<div id="{did}" style="position:absolute; left:0; top:0; width:44px; height:44px">'
            '<div style="position:absolute; inset:-22px; border-radius:50%; background:rgba(29,78,216,0.18)"></div>'
            '<div style="position:absolute; inset:0; border-radius:50%; background:#1D4ED8; border:5px solid #fff; box-shadow:0 4px 10px rgba(0,0,0,0.25)"></div>'
            f'{extra}</div>')


# ======================================================================= 1 campus
vo, end = place([("a1", 0), ("a2", 0.15)], 0.3)
D = tail(end, 0.3)
ZOOM = round(vo["a1"][0] + 2.85, 2)   # "But step inside" (measured: 2.93 s into a1)
SC = 1080 / 1024              # app map crop -> on screen
MX, MY = 740, 250
WALK = [(190, 150), (262, 292), (450, 295), (360, 293), (620, 295), (780, 294), (560, 295)]
path = [(MX + x * SC - 22, MY + y * SC - 22) for x, y in WALK]
ox, oy, ow, oh, _ = CB[OURS]
street = [(160, 450), (490, 450), (700, 450), (940, 450), (1105, 450), (1105, 400)]
body = f"""
    <div id="c-city" style="position:absolute; inset:0">{campus_svg("c-b")}
      {dot("c-cdot")}</div>
    <div id="c-gpsok" class="card" style="left:120px; top:960px; padding:14px 24px; display:flex; align-items:center; gap:14px">
      <div style="width:16px; height:16px; border-radius:50%; background:#005A32"></div><div style="font-size:30px; font-weight:800; color:#005A32">GPS · accurate outdoors</div></div>
    <div id="c-floor" style="position:absolute; inset:0; opacity:0">
      <div class="bg"></div>
      <div id="c-card" class="card" style="left:{MX - 20}px; top:{MY - 20}px; width:1120px; height:{576 * SC + 40:.0f}px; padding:20px; overflow:hidden">
        <img src="assets/ui/start_map.png" alt="" style="width:1080px; height:{576 * SC:.0f}px; display:block"></div>
      <div class="kicker" style="position:absolute; left:{MX}px; top:{MY + 576 * SC + 40:.0f}px">Our block · Ground Floor (the app's own map)</div>
      {dot("c-dot", '<div id="c-q" style="position:absolute; left:40px; top:-62px; width:56px; height:56px; border-radius:50%; background:#F4EDDF; color:#DC2626; font-size:38px; font-weight:900; display:flex; align-items:center; justify-content:center; box-shadow:0 6px 14px rgba(0,0,0,0.18); opacity:0">?</div>')}
      <div id="c-gps" class="card" style="left:120px; top:200px; padding:18px 28px; display:flex; align-items:center; gap:14px; opacity:0">
        <div style="width:16px; height:16px; border-radius:50%; background:#DC2626"></div><div style="font-size:32px; font-weight:800; color:#DC2626">No GPS signal indoors</div></div>
      <div id="c-head" class="h1" style="position:absolute; left:120px; top:400px; width:600px; opacity:0">{K("GPS stops|at the *door.*")}</div>
      <div id="c-who" style="position:absolute; left:120px; top:690px; width:560px; display:flex; flex-wrap:wrap; gap:14px; opacity:0">
        <span class="chip">New students</span><span class="chip">Visitors</span><span class="chip">Room 104?</span></div>
    </div>
"""
s = f'    tl.set("#c-cdot", {{ x: {street[0][0] - 22}, y: {street[0][1] - 22} }}, 0);\n'
seg = (ZOOM - 0.4) / (len(street) - 1)
for i, (x, y) in enumerate(street[1:]):
    s += f'    tl.to("#c-cdot", {{ x: {x - 22}, y: {y - 22}, duration: {seg - 0.03:.2f}, ease: "none" }}, {0.2 + i * seg:.2f});\n'
s += f'    tl.to("#c-city", {{ scale: 5, transformOrigin: "{ox + ow / 2}px {oy + oh / 2}px", duration: 1.1, ease: "expo.in" }}, {ZOOM - 0.2:.2f});\n'
s += hide("#c-gpsok", ZOOM - 0.2, 0.3) + hide("#c-city", ZOOM + 0.55, 0.3)
s += f'    tl.fromTo("#c-floor", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.45 }}, {ZOOM + 0.7:.2f});\n'
s += f'    tl.fromTo("#c-card", {{ scale: 0.6 }}, {{ scale: 1, duration: 0.9, ease: "expo.out" }}, {ZOOM + 0.7:.2f});\n'
s += f'    tl.set("#c-dot", {{ x: {path[0][0]:.0f}, y: {path[0][1]:.0f} }}, 0);\n'
t = ZOOM + 1.3
for (x, y) in path[1:]:
    s += f'    tl.to("#c-dot", {{ x: {x:.0f}, y: {y:.0f}, duration: 0.8, ease: "power1.inOut" }}, {t:.2f});\n'
    t += 0.95
s += f'    tl.fromTo("#c-q", {{ opacity: 0, scale: 0.4 }}, {{ opacity: 1, scale: 1, duration: 0.4, ease: "back.out(2)" }}, {ZOOM + 2.0:.2f});\n'
s += show("#c-gps", at("a1", 0.85), 12)
s += kin("#c-head", at("a1", 0.88), 0.07)
s += show("#c-who", at("a2", 0.45), 16, 0.5)
scene("campus", D, body, s, wipe_out=True)
add_scene("campus", D, vo, [(ZOOM - 0.2, "card-shove-1", 0.3), (at("a1", 0.85), "switch_002", 0.35), (D - 0.4, "card-shove-1", 0.3)])

# ----------------------------------------------------------------------- the Via logo
# The real master (Logo/Final_v2/svg/via-logo-horizontal-light.svg, copied to
# assets/logo/), inlined so it can draw on. Its paths are used unchanged:
#   route  revealed through a mask: a wide stroke along the route's centre line
#          (start ring -> the turn -> under the destination dot), drawn on with
#          stroke-dashoffset; at the end the mask covers the route completely
#   dot    pops from scale 0 to exactly 1 about its own centre
#   word   fades in
# Its clear space (the dot's diameter) is part of the viewBox.
import re as _re
_LOGO = (W.parent / "composition/assets/logo/via-logo-horizontal-light.svg").read_text(encoding="utf-8")
_LVB = _re.search(r'viewBox="([^"]+)"', _LOGO).group(1)
_LP = _re.findall(r'<path[^>]*/>', _LOGO)
_LROUTE, _LDOT = _LP[0], _LP[1]
_LWORD = _LOGO[_LOGO.index("<g "):_LOGO.rindex("</g>") + 4]
_LVBW, _LVBH = (float(v) for v in _LVB.split()[2:])
LOGO_DOT_C = "78.288 24"     # destination dot centre, from the artwork


def LOGO(p, w):
    """The light horizontal logo, w px wide, with ids p-ms (mask stroke), p-dot, p-word."""
    h = round(w * _LVBH / _LVBW, 1)
    x0, y0 = _LVB.split()[:2]
    return (f'<svg viewBox="{_LVB}" width="{w}" height="{h}" style="display:block; overflow:visible">'
            f'<defs><mask id="{p}-m" maskUnits="userSpaceOnUse" x="{x0}" y="{y0}" width="{_LVBW}" height="{_LVBH}">'
            f'<path id="{p}-ms" d="M21.712 24 L50 84 L78.288 24" fill="none" stroke="#fff" stroke-width="34" '
            f'stroke-linecap="round" stroke-linejoin="round" pathLength="1" stroke-dasharray="1.02" stroke-dashoffset="0"/></mask></defs>'
            f'<g mask="url(#{p}-m)">{_LROUTE}</g>'
            + _LDOT.replace("<path ", f'<path id="{p}-dot" ', 1)
            + _LWORD.replace("<g ", f'<g id="{p}-word" ', 1) + "</svg>")


def logo_in(p, t, draw=0.7):
    """Draw the route on, pop the destination dot, fade the wordmark in."""
    return (f'    tl.fromTo("#{p}-ms", {{ attr: {{ "stroke-dashoffset": 1.02 }} }}, {{ attr: {{ "stroke-dashoffset": 0 }}, duration: {draw}, ease: "power2.inOut" }}, {t:.2f});\n'
            f'    tl.fromTo("#{p}-dot", {{ scale: 0, svgOrigin: "{LOGO_DOT_C}" }}, {{ scale: 1, svgOrigin: "{LOGO_DOT_C}", duration: 0.45, ease: "back.out(2.2)" }}, {t + draw - 0.1:.2f});\n'
            f'    tl.fromTo("#{p}-word", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.45, ease: "power2.out" }}, {t + draw - 0.05:.2f});\n')


# ======================================================================= 2 title
vo, end = place([("b1", 0)], 0.25)
D = tail(end, 0.3)
PSF = [round(vo["b1"][0] + 0.12 + t, 2) for t in (7.5, 8.0, 8.58)]   # measured: "pick", "scan", "follow"
body = f"""
    <div id="t-k" class="kicker" style="position:absolute; left:150px; top:250px; opacity:0">Built for our college</div>
    <div id="t-mark" style="position:absolute; left:{150 - round(520 * 19.09 / _LVBW)}px; top:270px; opacity:0">{LOGO("t", 520)}</div>
    <div id="t-tag" class="h2" style="position:absolute; left:156px; top:520px; width:900px; opacity:0">{K("Directions inside a building.|*Just* *your* *phone.*")}</div>
    <div id="t-steps" style="position:absolute; left:156px; top:740px; display:flex; gap:40px">
      <div id="t-s0" class="h1" style="font-size:96px; opacity:0">Pick.</div>
      <div id="t-s1" class="h1" style="font-size:96px; opacity:0">Scan.</div>
      <div id="t-s2" class="h1 green" style="font-size:96px; opacity:0">Follow.</div></div>
    {phone("t-phone", 1240, 37, [("t-home", "assets/ui/home.png", 0, D, "img")])}
"""
s = show("#t-k", 0.3, 10)
s += '    tl.set("#t-mark", { opacity: 1 }, 0.35);\n' + logo_in("t", 0.35)   # the dot pops as "Via" is said
s += '    tl.fromTo("#t-phone", { y: 260, opacity: 0, rotation: 4 }, { y: 0, opacity: 1, rotation: 0, duration: 1.0, ease: "expo.out" }, 0.3);\n'
s += kin("#t-tag", round(vo["b1"][0] + 2.9, 2), 0.07)
for i, t in enumerate(PSF):
    s += f'    tl.fromTo("#t-s{i}", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.45, ease: "expo.out" }}, {t:.2f});\n'
scene("title", D, body, s, wipe_in=True)
add_scene("title", D, vo, [(0.4, "impactSoft_medium_001", 0.45)] + [(t, "drop_002", 0.35) for t in PSF])

# ======================================================================= 3 pick
vo, end = place([("c1", 0)], 0.15)
D = round(max(tail(end, 0.5), 2.9), 2)
body = f"""
    {rail("Pick", "k-rail")}
    {phone("k-phone", 1100, 37, [("k-p0", "assets/ui/picker_open.png", 0, 0.6, "img"), ("k-p1", "assets/ui/picker_1.png", 0.6, 0.35, "img"), ("k-p2", "assets/ui/picker_10.png", 0.95, 0.35, "img"), ("k-p3", "assets/ui/picker_104.png", 1.3, 0.8, "img"), ("k-dest", "assets/ui/destination.png", 2.1, round(D - 2.1, 2), "img")])}
    <div id="k-note" class="card" style="left:1600px; top:500px; padding:18px 26px; opacity:0"><div class="kicker">Destination</div><div style="font-size:34px; font-weight:800; margin-top:4px">Room 104</div></div>
"""
s = '    tl.fromTo("#k-rail", { opacity: 0, x: -30 }, { opacity: 1, x: 0, duration: 0.4, ease: "expo.out" }, 0);\n'
s += '    tl.fromTo("#k-phone", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }, 0);\n'
s += show("#k-note", 2.2, 12, 0.4)
scene("pick", D, body, s)
add_scene("pick", D, vo, [(0.6, "click2", 0.3), (0.95, "click2", 0.3), (1.3, "click2", 0.3), (2.1, "select_008", 0.45)])

# ======================================================================= 4 scan
vo, end = place([("d1", 0)], 0.15)
D = tail(end, 0.6)
R = 440 / 1080
fx, fy, fw, fh = 240 * R, 700 * R, 600 * R, 600 * R
mk = 150
mx, my = fx + (fw - mk) / 2, fy + (fh - mk) / 2
SLAP = at("d1", 0.36)          # "a printed sticker"
PIN = at("d1", 0.5)
LOCK = at("d1", 0.8)           # "the phone instantly knows"
HERE = round(LOCK + 0.6, 2)
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
    <div id="s-label" style="position:absolute; left:600px; top:650px; width:560px; opacity:0">
      <div class="kicker">Printed ArUco marker</div>
      <div style="font-size:32px; font-weight:700; margin-top:8px">Marker 13 · Entry 1</div>
      <div style="font-size:28px; color:#586B45; margin-top:10px">Read on the phone with OpenCV</div></div>
    <div id="s-head" class="h2" style="position:absolute; left:600px; top:830px; width:700px; opacity:0">{K("*Know* *where* *you* *are.*")}</div>
    {phone("s-phone", 1330, 37, [("s-here", "assets/ui/located_toast.png", HERE, round(D - HERE, 2), "img")], cam)}
"""
s = kin("#s-q", 0.0, 0.04) + hide("#s-q", SLAP - 0.2, 0.15)
s += f'    tl.fromTo("#s-paper", {{ opacity: 0, scale: 1.4, rotation: -11 }}, {{ opacity: 1, scale: 1, rotation: -3, duration: 0.32, ease: "power4.in" }}, {SLAP - 0.3:.2f});\n'
s += show("#s-label", SLAP + 0.3)
s += f'    tl.fromTo("#s-phone", {{ x: 520, opacity: 0 }}, {{ x: 0, opacity: 1, duration: 0.9, ease: "expo.out" }}, {PIN});\n'
s += f'    tl.fromTo("#s-mk", {{ x: 8, y: -6, rotation: 2.5 }}, {{ x: -3, y: 3, rotation: -0.5, duration: {LOCK - PIN:.2f}, ease: "sine.inOut" }}, {PIN});\n'
s += f'    tl.fromTo("#s-lock", {{ opacity: 0, scale: 1.12 }}, {{ opacity: 1, scale: 1, duration: 0.25, ease: "back.out(2)" }}, {LOCK});\n'
s += kin("#s-head", HERE + 0.1, 0.06)
scene("scan", D, body, s)
add_scene("scan", D, vo, [(SLAP, "impactWood_medium_001", 0.75), (SLAP + 0.02, "card-place-2", 0.45), (PIN, "card-slide-1", 0.32), (LOCK, "click_003", 0.55), (LOCK + 0.05, "impactSoft_medium_002", 0.42)])

# ======================================================================= 5 follow
vo, end = place([("e1", 0)], 0.15)
D = tail(end, 0.4)
PX, PY = 1100, 37
RS = 440 / 1080
MAPX, MAPY, MAPW = PX + 14 + 28 * RS, PY + 14 + 1280 * RS, 1024 * RS
BX, BY, BW, BH = 240, 210, 1440, 810
FLY = 0.5
body = f"""
    {rail("Follow", "f-rail")}
    {phone("f-phone", PX, PY, [("f-loc0", "assets/ui/located_toast.png", 0, 1.4, "img")])}
    {big_map("f-big", media("f-loc", "assets/clips/located_map.mp4", FLY, 4.0) + media("f-hold", "assets/ui/located_map_last.png", FLY + 4.0, round(D - FLY - 4.0, 2), "img"), BX, BY, BW, BH)}
    <div id="f-h" style="position:absolute; left:{BX}px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Rooms · corridors · stairs · lifts</div>
      <div id="f-hh" class="h2" style="margin-top:10px; font-size:62px">{K("Your route, worked out *on* *the* *phone.*")}</div></div>
"""
s = f'    tl.fromTo("#f-big", {{ opacity: 0, x: {MAPX - BX:.1f}, y: {MAPY - BY:.1f}, scale: {MAPW / BW:.4f}, transformOrigin: "0 0" }}, {{ opacity: 1, x: 0, y: 0, scale: 1, duration: 0.95, ease: "expo.inOut" }}, {FLY});\n'
s += f'    tl.to("#f-phone", {{ opacity: 0, scale: 1.25, duration: 0.7, ease: "power2.in" }}, {FLY});\n'
s += f'    tl.to("#f-rail", {{ opacity: 0, x: -40, duration: 0.4 }}, {FLY});\n'
s += show("#f-h", 1.3, 0, 0.01) + kin("#f-hh", 1.35, 0.05)
scene("follow", D, body, s)
add_scene("follow", D, vo, [(FLY, "card-slide-1", 0.3), (1.3, "drop_002", 0.3)])

# ======================================================================= 6 preferences
vo, end = place([("f1", 0)], 0.15)
T1, T2 = round(vo["f1"][0] + 2.1, 2), round(vo["f1"][0] + 5.0, 2)   # measured: "Step-free" 2.14 s, "Avoid lifts" 5.06 s       # "step-free", "Avoid lifts"
D = round(max(tail(end, 0.3), T2 + 1.9), 2)
T3 = D
chips = "".join(f'<span id="p-c{i}" class="chip" style="font-size:28px; padding:12px 24px">{t}</span>' for i, t in enumerate(["Fastest", "Step-free", "Avoid lifts"]))
inner = (media("p-l0", "assets/ui/located_map_last.png", 0, T1, "img") + media("p-sf", "assets/clips/pref_stepfree_map.mp4", T1, round(T2 - T1, 2))
         + media("p-al", "assets/clips/pref_avoidlifts_map.mp4", T2, round(D - T2, 2)))
body = f"""
    {big_map("p-big", inner)}
    <div id="p-h" style="position:absolute; left:240px; top:70px; width:1440px; display:flex; align-items:flex-end; justify-content:space-between; opacity:0">
      <div><div class="kicker">Route preferences</div><div id="p-q" class="h2" style="margin-top:10px; font-size:60px">{K("Can everyone find their way?")}</div></div>
      <div style="display:flex; gap:14px; margin-bottom:6px">{chips}</div></div>
"""
s = '    tl.set("#p-big", { opacity: 1 }, 0);\n' + show("#p-h", 0.05, 0, 0.01) + kin("#p-q", 0.1, 0.05)
s += '    tl.set("#p-c0", { backgroundColor: "#586B45", color: "#FFFFFF" }, 0);\n'
for t, on, off in [(T1, "#p-c1", "#p-c0"), (T2, "#p-c2", "#p-c1")]:
    s += f'    tl.to("{on}", {{ backgroundColor: "#586B45", color: "#FFFFFF", scale: 1.06, duration: 0.18 }}, {t});\n'
    s += f'    tl.to("{on}", {{ scale: 1, duration: 0.25 }}, {t + 0.18:.2f});\n'
    s += f'    tl.to("{off}", {{ backgroundColor: "#F4EDDF", color: "#586B45", duration: 0.18 }}, {t});\n'
scene("prefs", D, body, s)
add_scene("prefs", D, vo, [(T1, "click_003", 0.45), (T2, "click_003", 0.45)])

# ======================================================================= 7 sonar: the app's own 3D view at real speed
# One narrated line covers it. The clip is the app's FloorChangeView frames
# 9-128 (its whole 4.0 s animation, without the overlay's fade in/out
# frames), unaltered and at real speed. No text is drawn over it. It holds
# on the settled first floor, then a brand-green wipe leads into the guide.
vo, end = place([("g1", 0)], 0.1)
L0 = vo["g1"][0]
CLIP = 4.0
DIVE = round(L0 + 0.45, 2)            # "And when your route..."
SON = round(L0 + 1.05, 2)             # "...changes floors": the 3D view starts
BACK = round(SON + CLIP, 2)           # ends with "...in 3D."
D = round(max(tail(end, 0.25), BACK + 0.45), 2)
rings = "".join(f'<div id="n-ring{i}" style="position:absolute; left:960px; top:540px; width:400px; height:400px; margin:-200px 0 0 -200px; border-radius:50%; border:3px solid #89E900; opacity:0"></div>' for i in range(3))
mask = "radial-gradient(ellipse 46% 52% at 50% 50%, #000 70%, transparent 100%)"
vs = f"position:absolute; left:555px; top:0; width:810px; height:1080px; object-fit:cover; -webkit-mask-image:{mask}; mask-image:{mask}"
body = f"""
    <div id="n-night" style="position:absolute; inset:0; background:radial-gradient(ellipse 900px 700px at 960px 540px, #0B1408, #040704 70%); opacity:0"></div>
    {rings}
    <div id="n-glow" style="position:absolute; left:960px; top:540px; width:1200px; height:1200px; margin:-600px 0 0 -600px; border-radius:50%; background:radial-gradient(circle, rgba(137,233,0,0.22), rgba(137,233,0,0) 62%); opacity:0"></div>
    <div id="n-view" style="position:absolute; inset:0; opacity:0">
      <img id="n-first" class="clip" data-start="{SON:.2f}" data-duration="0.5" data-track-index="3" src="assets/ui/sonar_first.png" alt="" style="{vs}">
      <video id="n-big" class="clip" data-start="{SON:.2f}" data-duration="{CLIP}" data-track-index="4" muted playsinline src="assets/clips/sonar_clean.mp4" style="{vs}"></video>
      <img id="n-last" class="clip" data-start="{round(BACK - 0.04, 2):.2f}" data-duration="{round(D - BACK + 0.04, 2)}" data-track-index="5" src="assets/ui/sonar_last.png" alt="" style="{vs}"></div>
    {phone("n-phone", 726, 37, [("n-lift", "assets/ui/at_lift.png", 0, round(SON + 0.1, 2), "img")])}
"""
s = '    tl.fromTo("#n-phone", { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.35, ease: "expo.out" }, 0);\n'
s += f'    tl.fromTo("#n-night", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.45, ease: "power2.in" }}, {DIVE - 0.05:.2f});\n'
s += f'    tl.to("#n-phone", {{ scale: 2.8, opacity: 0, duration: 0.55, ease: "expo.in" }}, {DIVE:.2f});  // dive into the screen\n'
s += f'    tl.fromTo("#n-view", {{ opacity: 0, scale: 1.1 }}, {{ opacity: 1, scale: 1, duration: 0.4, ease: "expo.out" }}, {SON:.2f});  // beat-locked music drop\n'
s += f'    tl.fromTo("#n-glow", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.4 }}, {SON:.2f});\n'
for i, dt in enumerate([0, 0.7, 1.4]):
    s += f'    tl.fromTo("#n-ring{i}", {{ opacity: 0.7, scale: 0.4 }}, {{ opacity: 0, scale: 4.2, duration: 2.2, ease: "power2.out" }}, {SON + dt:.2f});\n'
scene("sonar", D, body, s, wipe_out=True)   # holds the settled first floor, then wipes
SONAR_DROP_ABS = T0[0] + SON
add_scene("sonar", D, vo, [(DIVE, "card-shove-1", 0.25), (SON, "impactSoft_heavy_003", 0.55), (SON, "bong_001", 0.45), (SON + 1.6, "bong_001", 0.22)])

# ======================================================================= 8 guide
vo, end = place([("h1", 0), ("h2", 0.15)], 0.0)
D = tail(end, 0.4)
RELOC = round(vo["h1"][0] + 0.12 + 2.96, 2)   # measured: "And if you take a wrong turn"
h2 = vo["h2"][0]
ring = (f'<div id="g-ring" class="clip" data-start="{RELOC + 0.9:.2f}" data-duration="{round(h2 - RELOC - 1.0, 2)}" data-track-index="3" '
        'style="position:absolute; left:291px; top:618px; width:124px; height:49px; border-radius:24px; border:4px solid #F59E0B"></div>')
body = f"""
    {big_map("g-map", '<img src="assets/ui/arrived_map.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover">', 240, 220, 1440, 759)}
    <div id="g-a" style="position:absolute; left:240px; top:70px; width:1500px; opacity:0">
      <div class="kicker">Step by step · the app's own words</div>
      <div id="g-ah" class="h2" style="margin-top:10px; font-size:64px">{K("&quot;You have arrived at *Room* *104.&quot;*")}</div></div>
    {phone("g-phone", 1230, 37, [("g-steps", "assets/ui/steps.png", 0, round(h2, 2), "img"), ("g-sheet", "assets/ui/walk_sheet.png", round(h2, 2), 1.0, "img"), ("g-walk", "assets/clips/walk.mp4", round(h2 + 1.0, 2), 2.0, "video"), ("g-wl", "assets/ui/walk_last.png", round(h2 + 3.0, 2), round(D - h2 - 3.0, 2), "img")], ring)}
    <div id="g-b" style="position:absolute; left:150px; top:320px; width:960px; opacity:0">
      <div class="kicker">Re-locate</div>
      <div id="g-bh" class="h2" style="margin-top:14px">{K("Wrong turn?|*Scan* *any* *marker.*")}</div>
      <div class="body" style="margin-top:22px">The route starts again from wherever you are.</div></div>
    <div id="g-c" style="position:absolute; left:150px; top:290px; width:980px; opacity:0">
      <span class="pill" style="background:#005A32; color:#fff">Beta</span>
      <div id="g-ch" class="h2" style="margin-top:24px">{K("Scan once.|*Then* *just* *walk.*")}</div>
      <div style="font-size:28px; color:#586B45; margin-top:18px">Turns read aloud. Position between markers is estimated.</div></div>
"""
s = '    tl.fromTo("#g-map", { opacity: 0, scale: 1.06 }, { opacity: 1, scale: 1, duration: 0.6, ease: "expo.out" }, 0);\n'
s += '    tl.set("#g-phone", { opacity: 0 }, 0);\n'
s += show("#g-a", 0.1, 0, 0.01) + kin("#g-ah", 0.15, 0.05)
s += hide("#g-a", RELOC - 0.2, 0.3) + hide("#g-map", RELOC - 0.2, 0.3)
s += f'    tl.fromTo("#g-phone", {{ opacity: 0, x: 200 }}, {{ opacity: 1, x: 0, duration: 0.6, ease: "expo.out" }}, {RELOC:.2f});\n'
s += show("#g-b", RELOC + 0.1, 20, 0.4) + kin("#g-bh", RELOC + 0.1, 0.05) + hide("#g-b", h2 - 0.3, 0.25)
s += f'    tl.fromTo("#g-ring", {{ scale: 1.3, opacity: 0 }}, {{ scale: 1, opacity: 1, duration: 0.35, ease: "back.out(2)" }}, {RELOC + 0.9:.2f});\n'
s += show("#g-c", h2, 20, 0.4) + kin("#g-ch", h2 + 0.05, 0.06)
scene("guide", D, body, s, wipe_in=True)
add_scene("guide", D, vo, [(0.2, "bong_001", 0.3), (RELOC + 0.9, "click2", 0.4), (h2, "switch_002", 0.4), (h2 + 1.2, "footstep_wood_002", 0.25), (h2 + 1.8, "footstep_wood_002", 0.22), (h2 + 2.4, "footstep_wood_002", 0.2)])

# ======================================================================= 9 proof
vo, end = place([("i1", 0), ("i2", 0.15)], 0.2)
D = tail(end, 0.6)
ESP = at("i1", 0.42)            # "Our first version, on an ESP32"
OLD = at("i1", 0.55)
GRID = at("i1", 0.72)           # "took a longer route on 36 of 756"
i2 = vo["i2"][0]
GREEN = at("i2", 0.08)
TESTS = at("i2", 0.62)          # "192 automated tests"
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
        '<text x="40" y="26" font-family="Roboto" font-weight="800" font-size="20" letter-spacing="2" fill="#586B45">FIRST FLOOR</text>',
        '<text x="40" y="346" font-family="Roboto" font-weight="800" font-size="20" letter-spacing="2" fill="#586B45">GROUND FLOOR</text>']
for a, b in EDGES:
    (x1, y1), (x2, y2) = gp(a), gp(b)
    vert = pos[a][2] != pos[b][2]
    da = ' stroke-dasharray="6 6"' if vert else ""
    gsvg.append(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="#C9B993" stroke-width="{2 if vert else 3}"{da}/>')


def pline(pid, seq, col, wdt):
    pts = " ".join(f"{gp(n)[0]:.0f},{gp(n)[1]:.0f}" for n in seq)
    L = sum(math.dist(gp(a), gp(b)) for a, b in zip(seq, seq[1:]))
    return f'<polyline id="{pid}" points="{pts}" fill="none" stroke="{col}" stroke-width="{wdt}" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="{L:.0f}" stroke-dashoffset="{L:.0f}"/>'


gsvg.append(pline("q-old", [11, 9, 23, 25], "#DC2626", 7))
gsvg.append(pline("q-new", [11, 25], "#005A32", 9))
for n in pos:
    x, y = gp(n)
    gsvg.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{10 if n in (11, 25) else 6}" fill="{"#1D4ED8" if n == 11 else "#DC2626" if n == 25 else "#F4EDDF"}" stroke="#586B45" stroke-width="2"/>')
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
        cls = "gd" if a == b else ("gb" if (a, b) in bad else "gg")
        grid.append(f'<rect class="{cls}" x="{(b - 1) * CELL + 1}" y="{(a - 1) * CELL + 1}" width="{CELL - 2}" height="{CELL - 2}" rx="2" fill="#E9DFCB"/>')
grid.append("</svg>")
body = f"""
    <div id="q-h" style="position:absolute; left:150px; top:70px; width:1600px; opacity:0">
      <div class="kicker">Under the hood</div>
      <div id="q-hh" class="h2" style="margin-top:10px; font-size:60px">{K("A corrected *bidirectional* *Dijkstra* search.")}</div></div>
    <div id="q-g" class="card" style="left:150px; top:230px; width:{GW}px; height:{GH + 40}px; padding:20px 0 0 0; opacity:0">{''.join(gsvg)}</div>
    <div id="q-old-t" class="card" style="left:170px; top:852px; padding:10px 18px; font-size:24px; font-weight:700; color:#DC2626; opacity:0">First version: via both lifts · cost 3</div>
    <div id="q-new-t" class="card" style="left:560px; top:852px; padding:10px 18px; font-size:24px; font-weight:700; color:#005A32; opacity:0">Now: straight up the stairs · cost 2</div>
    <div id="q-esp" class="card" style="left:1060px; top:330px; padding:16px 24px; font-size:28px; font-weight:700; opacity:0">First version: an ESP32 board computed the routes</div>
    <div id="q-gr" style="position:absolute; left:1060px; top:330px; opacity:0">{''.join(grid)}
      <div style="font-size:22px; letter-spacing:0.12em; color:#586B45; margin-top:12px; font-weight:700">FROM ↓ · TO → · 28 PLACES</div></div>
    <div id="q-n1" style="position:absolute; left:1060px; top:230px; opacity:0"><span style="font-size:72px; font-weight:900; color:#DC2626">36</span>
      <span style="font-size:32px; font-weight:700"> of 756 trips got a longer route</span></div>
    <div id="q-n2" style="position:absolute; left:1060px; top:230px; opacity:0"><span style="font-size:72px; font-weight:900; color:#005A32">784</span>
      <span style="font-size:32px; font-weight:700"> of 784 pairs match the shortest route</span></div>
    <div id="q-t" class="pill" style="position:absolute; left:1060px; top:906px; background:#005A32; color:#fff; font-size:30px; padding:12px 26px; opacity:0">✓ 192 automated tests</div>
"""
s = show("#q-h", 0.2, 0, 0.01) + kin("#q-hh", 0.25, 0.06)
s += show("#q-g", 0.8, 20, 0.6)
s += show("#q-esp", ESP - 0.3, 12, 0.35) + hide("#q-esp", GRID - 0.1, 0.2)
s += f'    tl.to("#q-old", {{ strokeDashoffset: 0, duration: 1.1, ease: "power1.inOut" }}, {OLD:.2f});\n'
s += show("#q-old-t", OLD + 0.8, 10, 0.4)
s += show("#q-gr", GRID, 20, 0.4)
s += f'    tl.to("#q-gr .gb", {{ fill: "#DC2626", duration: 0.2, stagger: {{ each: 0.03, from: "random" }} }}, {GRID + 0.3:.2f});\n'
s += show("#q-n1", GRID + 0.4, 14, 0.4)
s += f'    tl.to("#q-new", {{ strokeDashoffset: 0, duration: 0.6, ease: "power2.out" }}, {GREEN:.2f});\n'
s += show("#q-new-t", GREEN + 0.4, 10, 0.4)
s += hide("#q-n1", GREEN + 0.5, 0.25)
s += f'    tl.to("#q-gr .gg, #q-gr .gb", {{ fill: "#2E7D4F", duration: 0.25, stagger: {{ each: 0.0012, from: "start" }} }}, {GREEN + 0.6:.2f});\n'
s += show("#q-n2", GREEN + 0.9, 14, 0.4)
s += f'    tl.fromTo("#q-t", {{ opacity: 0, scale: 0.8 }}, {{ opacity: 1, scale: 1, duration: 0.4, ease: "back.out(2)" }}, {TESTS:.2f});\n'
scene("proof", D, body, s)
add_scene("proof", D, vo, [(0.8, "card-place-2", 0.3), (OLD, "card-slide-1", 0.25), (GRID + 0.3, "chips-stack-2", 0.35), (GREEN, "drop_002", 0.35), (GREEN + 0.6, "chips-collide-1", 0.35), (TESTS, "impactBell_heavy_003", 0.3)])

# ======================================================================= 10 offline
vo, end = place([("j1", 0)], 0.15)
D = tail(end, 0.3)
NO = [round(vo["j1"][0] + 0.12 + t, 2) for t in (1.68, 3.0, 3.94, 4.64)]   # measured
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
s += show("#o-air", 0.2)
s += '    tl.to("#o-knob", { x: 40, duration: 0.25, ease: "power2.out" }, 0.5);\n'
s += '    tl.to("#o-knob", { backgroundColor: "#005A32", duration: 0.25 }, 0.5);\n'
for i, t in enumerate(NO):
    s += f'    tl.fromTo("#o-n{i}", {{ opacity: 0, x: -30 }}, {{ opacity: 1, x: 0, duration: 0.4, ease: "expo.out" }}, {t:.2f});\n'
scene("offline", D, body, s)
add_scene("offline", D, vo, [(0.5, "switch_002", 0.5)] + [(t, "drop_002", 0.32) for t in NO])

# ======================================================================= 11 setup
vo, end = place([("k1", 0)], 0.15)
D = tail(end, 1.0)
FILE = round(vo["k1"][0] + 0.12 + 2.94, 2)   # measured: "shared"
body = f"""
    {phone("u-phone", 230, 37, [("u-ed1", "assets/ui/editor_map_guide.png", 0, 1.8, "img"), ("u-ed2", "assets/ui/editor_map.png", 1.8, round(D - 1.8, 2), "img")])}
    <div id="u-s" style="position:absolute; left:800px; top:240px; width:560px; opacity:0">
      <div class="kicker">Set-up</div>
      <div id="u-sh" class="h2" style="margin-top:14px; font-size:58px">{K("From each block's own *floor* *plan.*")}</div>
      <div class="body" style="margin-top:22px">The app drafts the map. A person reviews it and prints the markers.</div></div>
    {phone("u-phone2", 1400, 37, [("u-home2", "assets/ui/home.png", 0, D, "img")])}
    <div id="u-file" class="card" style="left:560px; top:640px; padding:20px 26px; display:flex; align-items:center; gap:18px; opacity:0">
      <svg width="48" height="48" viewBox="0 0 24 24"><path fill="#586B45" d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>
      <div><div style="font-size:30px; font-weight:800">Via demo building.via</div><div class="olive" style="font-size:28px">One file: plans, places, markers</div></div></div>
"""
s = '    tl.fromTo("#u-phone", { x: -300, opacity: 0 }, { x: 0, opacity: 1, duration: 0.7, ease: "expo.out" }, 0);\n'
s += show("#u-s", 0.2, 20, 0.4) + kin("#u-sh", 0.25, 0.06)
s += f'    tl.fromTo("#u-phone2", {{ x: 500, opacity: 0 }}, {{ x: 0, opacity: 1, duration: 0.8, ease: "expo.out" }}, {FILE - 0.6:.2f});\n'
s += f'    tl.fromTo("#u-file", {{ opacity: 0, scale: 0.8 }}, {{ opacity: 1, scale: 1, duration: 0.3, ease: "back.out(2)" }}, {FILE - 0.2:.2f});\n'
s += f'    tl.to("#u-file", {{ x: 720, y: -40, duration: 1.0, ease: "power3.inOut" }}, {FILE + 0.2:.2f});\n'
scene("setup", D, body, s, wipe_out=True)
add_scene("setup", D, vo, [(FILE - 0.6, "card-place-2", 0.3), (FILE + 0.2, "card-slide-1", 0.38), (D - 0.4, "card-shove-1", 0.3)])

# ======================================================================= 12 future: every block (same campus as the opening)
vo, end = place([("m1", 0)], 0.15)
D = tail(end, 0.4)
LIB = at("m1", 0.75)            # "one shared map library"
body = f"""
    <div id="w-map" style="position:absolute; inset:0">{campus_svg("w-b", today=True)}</div>
    <div id="w-h" class="card" style="left:120px; top:40px; padding:22px 34px; opacity:0">
      <div class="kicker">Our next step</div>
      <div id="w-hh" class="h2" style="margin-top:8px; font-size:56px">{K("One block today. *Every* *block* *next.*")}</div></div>
    <div id="w-lib" class="card" style="left:1300px; top:60px; padding:16px 26px; display:flex; align-items:center; gap:18px; opacity:0">
      <span class="pill" style="background:#F59E0B; color:#22301A">Planned</span><div style="font-size:32px; font-weight:800">One shared map library</div></div>
"""
s = '    tl.fromTo("#w-map", { opacity: 0, scale: 0.86, transformOrigin: "50% 100%" }, { opacity: 1, scale: 0.82, duration: 0.7, ease: "expo.out" }, 0);\n'
s += show("#w-h", 0.15, 0, 0.3) + kin("#w-hh", 0.2, 0.06)
order = [0, 1, 3, 4, 5, 6, 7]
for k, i in enumerate(order):
    s += f'    tl.to("#w-b{i} rect", {{ fill: "#E3E8D3", stroke: "#586B45", duration: 0.3 }}, {at("m1", 0.25) + k * 0.28:.2f});\n'
    s += f'    tl.to("#w-b{i} text", {{ fill: "#22301A", duration: 0.3 }}, {at("m1", 0.25) + k * 0.28:.2f});\n'
s += show("#w-lib", LIB, 16, 0.4)
scene("future", D, body, s, wipe_in=True)
add_scene("future", D, vo, [(at("m1", 0.25) + k * 0.28, "drop_002", 0.2) for k in range(0, 7, 2)] + [(LIB, "select_008", 0.35)])

# ======================================================================= 13 industries + walk-it-once (narrated)
vo, end = place([("m2", 0)], 0.15)
D = tail(end, 0.7)
ICONS = [("Hospitals", "M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z", 0.21),
         ("Malls", "M19 6h-2c0-2.76-2.24-5-5-5S7 3.24 7 6H5c-1.1 0-1.99.9-1.99 2L3 20c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-3c1.66 0 3 1.34 3 3H9c0-1.66 1.34-3 3-3zm0 10c-2.76 0-5-2.24-5-5h2c0 1.66 1.34 3 3 3s3-1.34 3-3h2c0 2.76-2.24 5-5 5z", 0.29),
         ("Airports", "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z", 0.34),
         ("Exam halls", "M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3z", 0.41)]
TEASE = at("m2", 0.5)          # "And one day, you could walk through a building just once"
cards = "".join(f'<div id="x-i{i}" class="card" style="position:relative; width:340px; height:340px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:22px; opacity:0">'
                f'<svg width="120" height="120" viewBox="0 0 24 24"><path fill="#005A32" d="{p}"/></svg><div style="font-size:42px; font-weight:800">{n}</div></div>'
                for i, (n, p, _) in enumerate(ICONS))
body = f"""
    <div id="x-h" style="position:absolute; left:160px; top:120px; width:1600px; opacity:0">
      <div class="kicker">Beyond our campus</div>
      <div id="x-hh" class="h2" style="margin-top:10px; font-size:62px">{K("Anywhere people get *lost* *indoors.*")}</div></div>
    <div id="x-row" style="position:absolute; left:160px; top:380px; width:1600px; display:flex; justify-content:space-between">{cards}</div>
    <div id="x-n" style="position:absolute; left:0; width:1920px; top:300px; display:flex; flex-direction:column; align-items:center; gap:38px; opacity:0">
      <div class="h2" style="color:#4A5340">What if you could walk through a building just once?</div>
      <span class="pill" style="background:#F59E0B; color:#22301A">Planned</span>
      <div id="x-nh" class="h1" style="font-size:96px">{K("Next: Walk it once. *It* *maps* *itself.*")}</div></div>
"""
s = show("#x-h", 0.15, 0, 0.01) + kin("#x-hh", 0.2, 0.06)
for i, (_, _, f) in enumerate(ICONS):
    s += f'    tl.fromTo("#x-i{i}", {{ opacity: 0, y: 50 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }}, {at("m2", f) - 0.2:.2f});\n'
s += hide("#x-h", TEASE - 0.3, 0.3) + hide("#x-row", TEASE - 0.3, 0.3)
s += show("#x-n", TEASE, 16, 0.4) + kin("#x-nh", TEASE + 1.2, 0.06)
scene("industries", D, body, s, wipe_out=True)
add_scene("industries", D, vo, [(at("m2", f) - 0.2, "card-place-2", 0.3) for _, _, f in ICONS] + [(TEASE + 1.2, "select_008", 0.35), (D - 0.4, "card-shove-1", 0.3)])

# ======================================================================= 14 close
vo, end = place([("l1", 0)], 0.15)
COLL = round(vo["l1"][0] + 3.35, 2)   # "Now, all it takes" (measured: 3.46 s)
ENDC = round(vo["l1"][0] + 6.3, 2)    # "Via." (measured: 6.34 s)
D = tail(end, 2.2)


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
    {phone("z-phone", 560, 37, [("z-loc", "assets/ui/located_end.png", COLL, round(ENDC - 0.3 - COLL, 2), "img")])}
    <div id="z-paper" style="position:absolute; left:1060px; top:560px; width:250px; height:250px; background:#fff; padding:6px; box-sizing:border-box; box-shadow:0 18px 36px rgba(34,48,26,0.22); opacity:0">
      <img src="assets/img/marker13.svg" alt="" style="width:100%; height:100%; display:block"></div>
    <div id="z-now" style="position:absolute; left:1060px; top:230px; width:760px; opacity:0">
      <div id="z-nh" class="h2">{K("Today: a phone,|*and* *a* *sticker.*")}</div>
      <div class="body" style="margin-top:18px; font-size:28px">Flutter · OpenCV ArUco · on-device Dijkstra · offline</div></div>
    <div id="z-end" style="position:absolute; left:0; width:1920px; top:330px; display:flex; flex-direction:column; align-items:center; opacity:0">
      <div class="kicker">Built for our college</div>
      {LOGO("z", 680)}
      <div id="z-tag" class="h2" style="margin-top:0; font-size:56px; opacity:0">{K("Find your way. Anywhere indoors.")}</div></div>
    <div id="z-credit" data-layout-ignore style="position:absolute; left:0; width:1920px; top:1040px; text-align:center; font-size:22px; color:#586B45; opacity:0">Music: Sascha Ende, ende.app (CC BY 4.0) · App screens rendered from the Via app</div>
"""
s = show("#z-k", 0.1)
for i, t in enumerate([0.2, 0.6, 1.0]):
    s += f'    tl.fromTo("#z-{i + 1}", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.5, ease: "expo.out" }}, {t});\n'
for i in range(3):
    s += f'    tl.to("#z-{i + 1}", {{ opacity: 0, scale: 0.3, x: {[560, -50, -660][i]}, duration: 0.5, ease: "power3.in" }}, {COLL - 0.3:.2f});\n'
s += hide("#z-k", COLL - 0.4)
s += f'    tl.fromTo("#z-phone", {{ opacity: 0, scale: 0.85 }}, {{ opacity: 1, scale: 1, duration: 0.6, ease: "expo.out" }}, {COLL});\n'
s += f'    tl.fromTo("#z-paper", {{ opacity: 0, scale: 1.4, rotation: -12 }}, {{ opacity: 1, scale: 1, rotation: -4, duration: 0.3, ease: "power4.in" }}, {COLL + 1.4:.2f});\n'
s += show("#z-now", COLL + 0.2, 20, 0.4) + kin("#z-nh", COLL + 0.2, 0.06)
s += hide("#z-phone", ENDC - 0.75, 0.3) + hide("#z-paper", ENDC - 0.75, 0.3) + hide("#z-now", ENDC - 0.75, 0.3)
s += f'    tl.fromTo("#z-end", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.3, ease: "power2.out" }}, {ENDC - 0.45:.2f});\n'
s += logo_in("z", ENDC - 0.4, 0.6)   # the dot lands on the spoken "Via."
s += kin("#z-tag", round(vo["l1"][0] + 7.25, 2), 0.06) + show("#z-credit", round(end + 0.1, 2), 0)
scene("close", D, body, s, wipe_in=True)
add_scene("close", D, vo, [(0.3, "card-place-2", 0.32), (0.9, "card-place-2", 0.32), (1.5, "card-place-2", 0.32), (COLL - 0.3, "impactSoft_heavy_003", 0.4), (COLL + 1.4, "impactWood_medium_001", 0.6), (ENDC + 0.1, "impactBell_heavy_000", 0.5)])

TOTAL = round(T0[0], 2)

# ======================================================================= captions
cap_items = []
import re as _re
import subprocess as _sp


def voiced(path, d):
    """Voiced spans of a narration file, from ffmpeg silencedetect."""
    out = _sp.run(["ffmpeg", "-hide_banner", "-i", str(ROOT / path), "-af", "silencedetect=n=-38dB:d=0.18", "-f", "null", "-"],
                  capture_output=True, text=True).stderr
    st = [float(x) for x in _re.findall(r"silence_start: ([0-9.]+)", out)]
    en = [float(x) for x in _re.findall(r"silence_end: ([0-9.]+)", out)]
    spans, cur = [], 0.0
    for s0, e0 in zip(st, en + [d]):
        if s0 > cur + 0.05:
            spans.append((cur, s0))
        cur = e0
    if cur < d - 0.05:
        spans.append((cur, d))
    return spans or [(0.0, d)]


def at_voiced(spans, frac):
    want = sum(e0 - s0 for s0, e0 in spans) * frac
    for s0, e0 in spans:
        if want <= e0 - s0:
            return s0 + want
        want -= e0 - s0
    return spans[-1][1]


for vid, start in VOICE:
    text, d = CAP[vid], VD[vid]
    spans = voiced(f"{VO_DIR}/{vid}.wav", d)
    parts, cur = [], []
    words = text.split(" ")
    for k, w in enumerate(words):
        cur.append(w)
        # a long run breaks at 8 words, unless a phrase ends within 2 more
        soon = any(x.endswith((",", ".", "?", ":")) for x in words[k + 1:k + 3])
        if (w.endswith((",", ".", "?", ":")) and len(cur) >= 3) or (len(cur) >= 8 and not soon) or len(cur) >= 10:
            parts.append(" ".join(cur)); cur = []
    if cur:
        if parts and len(cur) < 3:
            parts[-1] += " " + " ".join(cur)
        else:
            parts.append(" ".join(cur))
    total = sum(len(p) for p in parts)
    acc = 0
    for p in parts:
        t0 = at_voiced(spans, acc / total)
        acc += len(p)
        t1 = at_voiced(spans, acc / total)
        cap_items.append((round(start + t0 - 0.05, 2), round(max(0.5, t1 - t0 + 0.15), 2), p))
cap_items.sort()
for _i in range(len(cap_items) - 1):
    _st, _du, _tx = cap_items[_i]
    _nx = cap_items[_i + 1][0]
    if _st + _du > _nx - 0.02:
        cap_items[_i] = (_st, round(max(0.2, _nx - 0.02 - _st), 2), _tx)
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

# ---- one pre-mixed soundtrack (smooth preview); the separate clips stay, hidden
import re as _re2
import subprocess as _sp2
import wave as _wave
import numpy as _np
SR = 48000
mix = _np.zeros((int((TOTAL + 1) * SR), 2), _np.float32)
for tag in audio:
    at = dict(_re2.findall(r'([\w-]+)="([^"]*)"', tag))
    st, du = float(at["data-start"]), float(at.get("data-duration", 0) or 0)
    ms = float(at.get("data-media-start", 0))
    raw = _sp2.run(["ffmpeg", "-v", "error", "-ss", str(ms), "-t", str(du), "-i", str(ROOT / at["src"]), "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
                   capture_output=True, check=True).stdout
    x = _np.frombuffer(raw, _np.float32).reshape(-1, 2) * float(at.get("data-volume", 1))
    n = len(x)
    env = _np.ones(n, _np.float32)
    fi, fo = float(at.get("data-fade-in", 0)), float(at.get("data-fade-out", 0))
    if fi:
        k = min(n, int(fi * SR)); env[:k] = _np.linspace(0, 1, k)
    if fo:
        k = min(n, int(fo * SR)); env[n - k:] = _np.linspace(1, 0, k)
    i = int(st * SR)
    seg = (x * env[:, None])[: len(mix) - i]
    mix[i:i + len(seg)] += seg
mix = mix[: int(TOTAL * SR)]
peak = float(_np.abs(mix).max())
if peak > 0.89:
    mix *= 0.89 / peak
(ROOT / "assets/audio").mkdir(exist_ok=True)
with _wave.open(str(ROOT / "assets/audio/film_mix.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((_np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
(W / "audio_stems.html").write_text("\n".join(audio), encoding="utf-8")  # the separate clips, for re-mixing
audio = []
audio.insert(0, f'      <audio id="film-mix" data-start="0" data-duration="{TOTAL}" data-track-index="5" data-volume="1" src="assets/audio/film_mix.wav"></audio>')

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
