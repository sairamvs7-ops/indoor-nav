from pathlib import Path
p = Path("scenes_v3.py.txt")
s = p.read_text(encoding="utf-8")
def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)
rep('"b1": "So we\'re building Indoor Nav for our college. Directions inside a building, with just your phone. Pick, scan, and follow.",',
    '"b1": "So we\'re building Indoor Nav for our college. It gives you directions inside a building, using just your phone, in three simple steps: pick, scan, and follow.",')
rep('"g1": "And when your route changes floors, the app shows you exactly how you get there, in 3D.",',
    '"g1": "And when your route changes floors, the app shows you exactly how you get there, in 3D.",\n    "g2": "Watch the floor map rise into 3D, as your dot rides the lift up to the next floor.",')
rep('"h1": "Clear steps guide you to the door. Wrong turn? Scan any marker, and the route starts again from there.",',
    '"h1": "Clear steps guide you all the way to the door. And if you take a wrong turn, just scan any marker, and your route starts again from there.",')
rep('"j1": "It all works offline. No GPS. No Wi-Fi. No beacons. No server.",',
    '"j1": "And it all works offline, with no GPS, no Wi-Fi, no beacons, and no server.",')
rep('"k1": "Any block can be set up from its own floor plan, and shared as a single file.",',
    '"k1": "Each block is set up from its own floor plan, and shared as a single file.",')
# measured word times (speech recognition on the files)
rep('PSF = [at("b1", f) for f in (0.76, 0.84, 0.93)]   # "pick, scan, and follow"',
    'PSF = [round(vo["b1"][0] + 0.12 + t, 2) for t in (8.0, 8.72, 9.08)]   # measured: "pick", "scan", "follow"')
rep('s += kin("#t-tag", at("b1", 0.36), 0.07)', 's += kin("#t-tag", round(vo["b1"][0] + 2.9, 2), 0.07)')
rep('RELOC = at("h1", 0.33)          # "Took a wrong turn?"', 'RELOC = round(vo["h1"][0] + 0.12 + 2.96, 2)   # measured: "And if you take a wrong turn"')
rep('NO = [at("j1", f) for f in (0.38, 0.53, 0.68, 0.86)]', 'NO = [round(vo["j1"][0] + 0.12 + t, 2) for t in (1.68, 3.0, 3.94, 4.64)]   # measured')
rep('FILE = at("k1", 0.7)            # "shared as a single file"', 'FILE = round(vo["k1"][0] + 0.12 + 2.94, 2)   # measured: "shared"')
# 3D floor change: two narrated sentences, the app's own animation at half speed
rep('vo, end = place([("g1", 0)], 0.1)\nDIVE, SON = 0.5, 1.1\nBACK = round(SON + 4.67, 2)\nD = round(max(tail(end, 0.2), BACK + 0.9), 2)',
    'vo, end = place([("g1", 0), ("g2", 0.25)], 0.1)\nDIVE, SON = 0.5, 1.1\nSLOW = 0.5                      # the app\'s 4.67 s view, shown at half speed\nSDUR = round(4.67 / SLOW, 2)\nBACK = round(SON + SDUR, 2)\nD = round(max(tail(end, 0.3), BACK + 1.0), 2)')
rep('<video id="n-big" class="clip" data-start="{SON:.2f}" data-duration="4.67" data-track-index="3" muted playsinline src="assets/clips/sonar_big.mp4"',
    '<video id="n-big" class="clip" data-start="{SON:.2f}" data-duration="{SDUR}" data-playback-rate="{SLOW}" data-track-index="3" muted playsinline src="assets/clips/sonar_big.mp4"')
p.write_text(s, encoding="utf-8")
print("patched")
