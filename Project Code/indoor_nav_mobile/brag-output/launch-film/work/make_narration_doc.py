import json
t = json.load(open('timeline.json'))
ns = {}
exec(open('scenes_v3.py.txt', encoding='utf8').read().split('def at(')[0], ns)
cap = ns['CAP']
scene_of = {}
for vid, st in t['voice']:
    for sid, s0, d in t['scenes']:
        if s0 <= st < s0 + d:
            scene_of[vid] = sid
fmt = lambda x: f"{int(x // 60)}:{x % 60:04.1f}"
rows = "\n".join(f"| {vid} | {fmt(st)} | {scene_of[vid]} | {cap[vid]} |" for vid, st in sorted(t['voice'], key=lambda v: v[1]))
doc = f"""# Via launch film: narration script (final)

**Length:** {fmt(t['total'])}. That is about 105 s of speech; the longest pause between sentences is 1.5 s.

**Voice:** Kokoro `af_heart` (warm, natural US English) at normal speed, one WAV per paragraph in `composition/assets/vo/`.
- **Processing:** each file has 0.12 s of silence before and 0.25 s after, a short fade-in, and is levelled to -16 LUFS. Nothing starts abruptly, nothing is clipped, and the volume stays even.
- **Captions:** the same text is burned in at the bottom of the frame throughout.

**To swap in a better voice** (a HeyGen voice after sign-in, or a human recording): record each paragraph below into the same file names, then run `python work/build_film3.py`. Scenes re-time themselves to the new lengths.

| # | Starts | Scene | Line (as captioned) |
|---|---|---|---|
{rows}

## Pronunciation
- **Via**: "VYE-uh", as in "going via metro". **Dijkstra**: "DIKE-struh". **ESP32**: "E-S-P thirty-two". **Room 104**: "one-oh-four". **3D**: "three-D".

## Every claim, checked
- **"36 of 756 trips"**: recomputed with an exact port of the ESP32 firmware's search on its own graph (`work/esp32_pairs.py`, from `git show 693921f:"Project Code/wifi/wifi.ino"`). For example, Stairs 1 -> Stairs 3 cost 3 instead of 2.
- **"Every pair of places gets the shortest route"**: `test/routing/bidirectional_dijkstra_test.dart` matches plain Dijkstra for all 784 pairs.
- **"192 automated tests"**: the count of test cases in `test/`, run in CI on every push.
- **"The phone instantly knows where you are"**: the marker ID maps straight to a place; the scanner confirms over two frames. No speed figure is claimed.
- **"It all works offline"**: the app's own code makes no network calls. The ML Kit telemetry caveat is in `PROJECT_VIDEO_BRIEF.md`.
- **Beta and planned:** walk mode is said as "in beta". Mapping every block, the shared library, other industries and walk-it-once mapping are said as "next", "can help" or "one day", and are labelled *Planned* on screen.
"""
open('../NARRATION_SCRIPT.md', 'w', encoding='utf8').write(doc)
print("ok", fmt(t['total']))
