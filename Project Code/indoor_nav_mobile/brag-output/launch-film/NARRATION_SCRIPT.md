# Via launch film: narration script (final)

**Length:** 2:02.0. That is about 105 s of speech; the longest pause between sentences is 1.5 s.

**Voice:** Kokoro `af_heart` (warm, natural US English) at normal speed, one WAV per paragraph in `composition/assets/vo/`.
- **Processing:** each file has 0.12 s of silence before and 0.25 s after, a short fade-in, and is levelled to -16 LUFS. Nothing starts abruptly, nothing is clipped, and the volume stays even.
- **Captions:** the same text is burned in at the bottom of the frame throughout.

**To swap in a better voice** (a HeyGen voice after sign-in, or a human recording): record each paragraph below into the same file names, then run `python work/build_film3.py`. Scenes re-time themselves to the new lengths.

| # | Starts | Scene | Line (as captioned) |
|---|---|---|---|
| a1 | 0:00.3 | campus | Outside, your phone always knows where you are. But step inside a big building, and GPS goes quiet. |
| a2 | 0:07.0 | campus | On our own campus, new students and visitors can easily lose their way. |
| b1 | 0:12.1 | title | So we're building Via for our college. It gives you directions inside a building, using just your phone, in three simple steps: pick, scan, and follow. |
| c1 | 0:21.9 | pick | First, pick where you want to go. |
| d1 | 0:24.8 | scan | Then scan the nearest marker. It's just a printed sticker on the wall, and the phone instantly knows where you are. |
| e1 | 0:32.2 | follow | Now follow your route, drawn on the building's own floor plan, and worked out right on the phone. |
| f1 | 0:38.5 | prefs | If you need a route without stairs, choose Step-free. If you would rather take the stairs, choose Avoid lifts. |
| g1 | 0:45.5 | sonar | And when your route changes floors, the app shows you exactly how you get there, in 3D. |
| h1 | 0:51.1 | guide | Clear steps guide you all the way to the door. And if you take a wrong turn, just scan any marker, and your route starts again from there. |
| h2 | 0:59.4 | guide | And in beta: scan once, then simply walk, with every turn read aloud. |
| i1 | 1:04.5 | proof | Under the hood is a corrected, bidirectional Dijkstra search. Our first ESP32 version took a longer route on 36 of 756 trips. |
| i2 | 1:16.0 | proof | Today, every pair of places gets the shortest route, and 192 automated tests keep it that way. |
| j1 | 1:23.6 | offline | And it all works offline, with no GPS, no Wi-Fi, no beacons, and no server. |
| k1 | 1:29.7 | setup | Each block is set up from its own floor plan, and shared as a single file. |
| m1 | 1:35.6 | future | Next, we want to map every block on our campus, in one shared map library. |
| m2 | 1:41.1 | industries | Beyond campus, it can help hospitals, malls, airports, and exam halls. And one day, you could walk through a building once, and let it map itself. |
| l1 | 1:50.7 | close | It started with a microcontroller and a cloud database. Now, all it takes is a phone, and a sticker. Via. Find your way, anywhere indoors. |

## Pronunciation
- **Via**: "VYE-uh", as in "going via metro". **Dijkstra**: "DIKE-struh". **ESP32**: "E-S-P thirty-two". **Room 104**: "one-oh-four". **3D**: "three-D".

## Every claim, checked
- **"36 of 756 trips"**: recomputed with an exact port of the ESP32 firmware's search on its own graph (`work/esp32_pairs.py`, from `git show 693921f:"Project Code/wifi/wifi.ino"`). For example, Stairs 1 -> Stairs 3 cost 3 instead of 2.
- **"Every pair of places gets the shortest route"**: `test/routing/bidirectional_dijkstra_test.dart` matches plain Dijkstra for all 784 pairs.
- **"192 automated tests"**: the count of test cases in `test/`, run in CI on every push.
- **"The phone instantly knows where you are"**: the marker ID maps straight to a place; the scanner confirms over two frames. No speed figure is claimed.
- **"It all works offline"**: the app's own code makes no network calls. The ML Kit telemetry caveat is in `PROJECT_VIDEO_BRIEF.md`.
- **Beta and planned:** walk mode is said as "in beta". Mapping every block, the shared library, other industries and walk-it-once mapping are said as "next", "can help" or "one day", and are labelled *Planned* on screen.
