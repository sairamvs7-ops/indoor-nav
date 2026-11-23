# Via launch film: storyboard (final)

- **Format:** 1920×1080, 30 fps, **2:02.0**.
- **File:** `via-launch-film.mp4`, built by `work/build_film3.py` (one HTML file per scene in `composition/compositions/`).
- **Narration:** continuous; the longest pause is 1.5 s. Captions are burned in throughout.
- **Story:** we're building navigation **for our own college**. The app is shown working (pick, scan, follow), then the future: every campus block, then other industries.
- **Look:**
  - The app's light theme everywhere: sand, cream, olive, deep green, Roboto.
  - The sonar switches to the app's own black and lime.
  - Brand-green wipes mark the act changes.
- **One consistent map:**
  - The building is always the app's own render of the sample floors: the opening, the route, the preferences, the first floor, the arrival.
  - The campus illustration is the same drawing in the opening and the future scene.
  - Stairs and room names match the hand-drawn plan; the labels fit inside their rooms.
- **Music:** "Happy Beats / Business Moves" Vol. 12, then Vol. 1 (Sascha Ende, CC BY 4.0). Vol. 1's strong cue is beat-locked to the 3D reveal at 0:46.6

| # | Time | Scene | What's on screen | On-screen text / hooks |
|---|---|---|---|---|
| 1 | 0:00–0:12 | Campus | Campus illustration; a blue dot walks the road ("GPS · accurate outdoors"). Zoom into *Our block*, then the app's own ground-floor map: the dot wanders, "?", "No GPS signal indoors" | "GPS stops at the door." · New students / Visitors / Room 104? |
| 2 | 0:12–0:22 | Title | "Built for our college" · the **Via logo** draws on (route, then the destination dot pops as "Via" is said) · real home screen | "Directions inside a building. Just your phone." · **Pick. Scan. Follow.** |
| 3 | 0:22–0:25 | Pick | Rail (Pick) · real search "1" → "10" → "104" → Room 104 | Destination: Room 104 |
| 4 | 0:25–0:32 | Scan | Rail (Scan) · hook · printed marker 13 slaps on · viewfinder with the app's real scanner overlay locks · "You are at Entry 1" | **"No beacons. No Wi-Fi. How does it know?"** · "Know where you are." |
| 5 | 0:32–0:38 | Follow | The phone's map flies out to full frame; the real route draws, guide dot running | "Your route, worked out on the phone." |
| 6 | 0:38–0:45 | Preferences | Big map; chips switch to Step-free, then Avoid lifts (the route swings to Stairs 2) | **"Can everyone find their way?"** |
| 7 | 0:45–0:51 | Sonar | Dive into the phone → the app's own 3D floor-change view, full height on black, at real speed; it settles on the first floor, then a brand-green wipe | — (no text over the 3D view) |
| 8 | 0:51–1:04 | Guidance | Arrival map → phone with Re-locate ringed → **BETA** walk mode | "You have arrived at Room 104." · "Wrong turn? Scan any marker." · "Position between markers is estimated." |
| 9 | 1:04–1:23 | Proof | The firmware's graph: the old route via both lifts (cost 3) and the real **36/756** red grid; then the new route straight up the stairs (cost 2), **784/784** green, "✓ 192 automated tests" | "A corrected bidirectional Dijkstra search." |
| 10 | 1:23–1:30 | Offline | Airplane mode on · No GPS / No Wi-Fi / No beacons / No server | — |
| 11 | 1:30–1:35 | Setup | Real floor editor (blueprint → drafted map) · `.via` file to a second phone | "From each block's own floor plan." |
| 12 | 1:35–1:41 | Future: campus | The same campus: "Today: our block" plus the other blocks lighting up | **"One block today. Every block next."** · PLANNED · One shared map library |
| 13 | 1:41–1:51 | Beyond campus | Hospitals · Malls · Airports · Exam halls, each as it is said → teaser | "Anywhere people get lost indoors." · **"What if you could walk through a building just once?" → PLANNED → "Next: Walk it once. It maps itself."** |
| 14 | 1:51–2:02 | Close | ESP32 / Wi-Fi / Cloud database cards collapse into the phone + sticker → end card: the Via logo draws on, its dot landing on the spoken "Via" | "Today: a phone, and a sticker." · **Built for our college · Via · Find your way. Anywhere indoors.** |

**Final scene times:**

| Scene | Time |
|---|---|
| campus | 0:00.0–0:11.8 |
| title | 0:11.8–0:21.7 |
| pick | 0:21.7–0:24.6 |
| scan | 0:24.6–0:32.1 |
| follow | 0:32.1–0:38.4 |
| prefs | 0:38.4–0:45.4 |
| sonar | 0:45.4–0:51.1 |
| guide | 0:51.1–1:04.3 |
| proof | 1:04.3–1:23.5 |
| offline | 1:23.5–1:29.6 |
| setup | 1:29.6–1:35.4 |
| future | 1:35.4–1:41.0 |
| industries | 1:41.0–1:50.6 |
| close | 1:50.6–2:02.0 |

The 3D floor change (sonar) is the app's own animation, at its real speed (4.0 s, the capture's frames 9–128, without the overlay's fade-in and fade-out frames). One narrated line covers it: "And when your route changes floors" dives into the phone, and the 3D view starts on "changes floors". Nothing is drawn over it; its floor labels are redrawn in Roboto where the app draws them (`work/fix_sonar_labels.py`). It holds on the settled first floor, then a brand-green wipe leads to the arrival map.

**Status shown honestly:**
- **Working:** everything in scenes 3–11, except walk mode.
- **Beta:** walk mode.
- **Planned:** campus-wide mapping, the library, other industries, walk-it-once.
- **Illustration:** the campus layout is not RVU's real plan.
