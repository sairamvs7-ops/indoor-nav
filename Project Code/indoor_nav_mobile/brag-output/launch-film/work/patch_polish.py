"""One-off edit of build_scenes.py for the quality pass: new routing and sonar
scenes, kinetic headlines, act wipes. build_scenes.py stays the source."""
from pathlib import Path

W = Path(__file__).parent
p = W / "build_scenes.py"
s = p.read_text(encoding="utf-8")


def rep(a, b, count=1):
    global s
    if a not in s:
        raise SystemExit(f"MISSING: {a[:90]}")
    s = s.replace(a, b, count)


# new routing + sonar
a = s.index("# ---------------------------------------------------------------- 4 routing")
b = s.index("# ---------------------------------------------------------------- 6 guidance")
s = s[:a] + (W / "scenes_routing_sonar.py.txt").read_text(encoding="utf-8") + s[b:]

# word masks for kinetic headlines
rep(".card { position: absolute;", ".w { display: inline-block; overflow: hidden; vertical-align: top; padding-bottom: 0.1em; margin-bottom: -0.1em; }\n.wi { display: inline-block; }\n.card { position: absolute;")

# problem
rep('opacity:0">GPS stops<br>at the door.</div>', 'opacity:0">{K("GPS stops|at the *door.*")}</div>')
rep('script += show("#p-head", 7.6, 40, 0.7, "expo.out")', 'script += kin("#p-head", 7.6, 0.08)')
rep('scene("problem", 10.0, body, script)', 'scene("problem", 10.0, body, script, wipe_out=True)')
# intro
rep('opacity:0">Find your way indoors</div>', 'opacity:0">{K("Find your way indoors")}</div>')
rep('script += show("#i-tag", 1.3)', 'script += kin("#i-tag", 1.3)')
rep('scene("intro", 5.8, body, script)', 'scene("intro", 5.8, body, script, wipe_in=True)')
# marker
rep('opacity:0">Scan a marker.<br><span class="green">Know where you are.</span></div>', 'opacity:0">{K("Scan a marker.|*Know* *where* *you* *are.*")}</div>')
rep('script += show("#m-head", 8.1, 30, 0.5, "expo.out")', 'script += kin("#m-head", 8.1, 0.05)')
rep('scene("marker", 10.2, body, script)', 'scene("marker", 10.2, body, script, wipe_out=True)')
# guidance
rep('<div class="h2" style="margin-top:14px">Lost your place?<br><span class="green">Scan any marker.</span></div>',
    '<div id="g-ah" class="h2" style="margin-top:14px">{K("Lost your place?|*Scan* *any* *marker.*")}</div>')
rep('<div class="h2" style="margin-top:14px">"You have arrived<br>at Room 104."</div>',
    '<div id="g-bh" class="h2" style="margin-top:14px">{K("&quot;You have arrived|at Room 104.&quot;")}</div>')
rep('<div class="h2" style="margin-top:20px">Scan once.<br>Then just walk.</div>',
    '<div id="g-ch" class="h2" style="margin-top:20px">{K("Scan once.|*Then* *just* *walk.*")}</div>')
rep('script = show("#g-a", 0.05, 24, 0.35)', 'script = show("#g-a", 0.05, 24, 0.35) + kin("#g-ah", 0.05, 0.05)')
rep('script += show("#g-b", 2.9)', 'script += show("#g-b", 2.9) + kin("#g-bh", 2.9, 0.05)')
rep('script += show("#g-c", 4.9)', 'script += show("#g-c", 4.9) + kin("#g-ch", 4.95, 0.06)')
# offline
rep('<div class="h1" style="font-size:112px">No beacons. No Wi-Fi.</div>', '<div id="o-qh" class="h1" style="font-size:112px">{K("No beacons. No Wi-Fi.")}</div>')
rep('scene("offline", 14.2, body, script)', 'scene("offline", 14.2, body, script, wipe_out=True)')
# evolution
rep('<div class="h2">Now: a phone,<br><span class="green">and a sticker.</span></div>', '<div id="e-nh" class="h2">{K("Now: a phone,|*and* *a* *sticker.*")}</div>')
rep('script += show("#e-now", 5.05, 20, 0.4)', 'script += show("#e-now", 5.05, 20, 0.4) + kin("#e-nh", 5.05, 0.06)')
rep('scene("evolution", 7.4, body, script)', 'scene("evolution", 7.4, body, script, wipe_in=True)')
# closing
rep('<div class="h2">One building today.</div>', '<div id="c-ah" class="h2">{K("One building today.")}</div>')
rep('<div class="h1" style="margin-top:22px; font-size:100px">Next: Walk it once. <span class="green">It maps itself.</span></div></div>',
    '<div id="c-nh" class="h1" style="margin-top:22px; font-size:100px">{K("Next: Walk it once. *It* *maps* *itself.*")}</div></div>')
rep('opacity:0">Find your way. Anywhere indoors.</div>', 'opacity:0">{K("Find your way. Anywhere indoors.")}</div>')
rep('script += show("#c-tag", 7.0, 16)', 'script += kin("#c-tag", 7.0, 0.06)')

# chip clicks follow the new preference timings
rep('(36.0, "click_003", 0.45), (38.5, "click_003", 0.45), (41.0, "click_003", 0.45), (41.2, "drop_002", 0.38)',
    '(36.4, "click_003", 0.45), (38.9, "click_003", 0.45), (41.4, "click_003", 0.45), (41.6, "drop_002", 0.38), (28.6, "card-slide-1", 0.3)')
# wipe whooshes on the act changes
rep('    (5.8, "switch_002", 0.35),', '    (5.8, "switch_002", 0.35), (9.6, "card-shove-1", 0.3), (25.6, "card-shove-1", 0.3), (79.8, "card-shove-1", 0.3),')
p.write_text(s, encoding="utf-8")
print("patched")
