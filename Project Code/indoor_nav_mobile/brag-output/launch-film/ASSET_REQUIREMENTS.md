# Via launch film: assets

## 1. What the film already uses

### Real app screens, rendered from the app's own code
`work/capture_film_test.dart` is run with `flutter test` and is kept outside `lib/` (no app source was changed). It drives the real widgets — `BuildingsScreen`, `NavigationScreen`, `ScannerScreen`, `FloorChangeView`, `FloorEditorScreen` — on the bundled sample building, at 1080×2400 (DPR 2.5), in the light theme. Hardware is faked the same way the app's own tests fake it:

| What | How it was produced | Faithful to the phone? |
|---|---|---|
| Home, search, destination, route, guide dot, preferences, steps, arrival | Real widgets and painters, real routing (bidirectional Dijkstra on the sample graph) | Yes, pixel for pixel, apart from note (a) |
| Marker scan → "You are at Entry 1" | Real scanner screen; a scripted detector reports marker 13 twice (the app's two-frame confirmation) | The *result* is real. The camera feed is not: the test camera is black, so the film composites the printed marker into the viewfinder |
| Sonar floor change | Real `FloorChangeView`, captured frame by frame (140 frames, 4.67 s) as Lift 1 → Lift 3 | Yes. The film uses frames 9–128 (the whole 4.0 s animation, without the overlay fading in or out), at real speed, not redrawn |
| Walk mode (beta) | Real `LiveWalk` and walk bar, fed scripted footsteps and a steady compass (like `test/navigation/live_walk_test.dart`) | The UI and logic are real. The sensor input is simulated |
| Floor editor | Real `FloorEditorScreen` with the generated map | Yes, apart from note (a) |

**(a) Labels.** Flutter 3.50's test engine draws any text that names no font family as boxes. Room names on the generated map, the sonar floor names and the editor's place labels are drawn that way. `work/patch_labels.py` redraws exactly those labels in Roboto (the phone's system font), at the size and position the app's own painters compute; the positions are recorded by the capture.

**(b) Sample review.** The sample building was given the same review an admin does in the editor, using the editor's own operations, so its stairs and names match the hand-drawn plan:
- **Stairs:** Stairs 1–4 were traced as stairwells, because the blueprint auto-draft found only part of them.
- **Room 1:** linked to its room.
- **Lobby:** the lobby by Lift 2 / Entry 2 was marked "not used" instead of being labelled as a room.

Places and routes are unchanged. See `reviewStairs` and `reviewNames` in the capture test. The same fix belongs in the app's sample generation (`ui/buildings_screen.dart:_generateSampleMaps`), which is a follow-up and was not done here.

Files: frames in `work/frames/` (raw) and `work/frames_fixed/` (labels redrawn). Clips in `composition/assets/clips/`, stills in `composition/assets/ui/`.

### Existing project images
- **Marker 13:** `ArUco/ArUco - 13.png` (Entry 1 in the sample) is rebuilt as a vector, `assets/img/marker13.svg`. It is generated with OpenCV's `DICT_4X4_50` id 13, checked cell for cell against the printed PNG, and drawn as one path, so it stays sharp at any size with no seams.
- **Act 1 map:** the reviewed ground floor's generated map (`work/regions.json`, written by `work/dump_test.dart`), drawn in the app's light `MapStyle` colours. The photo of the hand-drawn plan is no longer used, because it clashed with the app palette.
- **Scanner overlay:** `assets/ui/scanner_ui.png` is the real scanner screen with its black (fake) camera preview made transparent, so a composited wall-and-marker "camera view" can sit under the app's own frame and hint.

### Generated in the composition (HTML/SVG, no stock)
- Graph-paper sand background
- Phone bezel
- The "you" dot
- GPS card
- Bidirectional-search graph diagram
- Route-preference chips (in the app's chip style)
- Airplane-mode tile
- "No …" list
- `.via` file card
- ESP32 / Wi-Fi / cloud cards (Material Symbols icons)
- Campus blocks
- Via logo, "Route" (`Logo/Final_v2/svg/via-logo-horizontal-light.svg`, copied to `composition/assets/logo/`). It is inlined unchanged on the title and end cards: the route is revealed by a mask that draws along it, then the destination dot pops to its exact size and the wordmark fades in. The settled frame is the master artwork, with no recolouring, stretching or glow.

### Audio
- **Voice:** Kokoro `af_heart`, 17 narration files in `assets/vo/` (padded and levelled; see `NARRATION_SCRIPT.md`). To upgrade, sign in to HeyGen (free tier, about 3 min of voice a month) or record a human voice, replace the files, and re-run `work/build_film3.py`.
- **Music:** "Happy Beats / Business Moves" Vol. 12 (to the floor change) and Vol. 1 (from the beat-locked drop at 0:46.6 to the end), Sascha Ende, CC BY 4.0. **The credit is required** and is on the end card.
- **SFX:** Kenney.nl CC0 packs bundled with /brag, in `assets/sfx/`:
  - impactWood (paper slap)
  - clicks, select (taps)
  - impactSoft (reveals and the sonar drop)
  - bong (sonar ping)
  - card slide, place, shove (cards and wipes)
  - drop (headlines)
  - switch (toggles)
  - footsteps (beta walk)
  - chips stack, collide (proof grid)
  - impactBell (the logo's destination dot landing on "Via")

### Proof data
`work/esp32_pairs.py` is an exact port of the ESP32 firmware's bidirectional Dijkstra, run on the firmware's own graph. It finds 36 of 756 ordered pairs with a longer route; the grid in the film plots exactly those (`work/esp32_pairs.json`).

## 2. Still needed: physical footage (team to shoot)

The film works without these, but real footage makes it a genuine launch film. Shoot on a tripod or gimbal, 4K/30 or 1080/60, in even daylight. Match the shot to the slot so it can be swapped in DaVinci.

| Slot | Shot | Length | Notes |
|---|---|---|---|
| 0–10 s | A student walks into the real building, looks at the corridor signs and turns back | 8–10 s | Faces optional (back or over-shoulder shots avoid releases). Keep the hand-drawn plan as an overlay or picture-in-picture |
| 16.5–18 s | A hand sticks **marker 13** (printed with a white margin) on a plain wall at chest height | 3 s | Macro, shallow depth of field. Matches the paper-slap SFX |
| 20–24 s | **Real phone scan:** over the shoulder, the phone points at marker 13, the frame turns mint, and "You are at Entry 1" appears | 4 s | Screen-record at the same time (Android screen recorder) to replace the composited viewfinder |
| 46–52 s | A person steps into the lift, doors closing (B-roll behind or beside the sonar) | 3 s | Optional; the sonar should stay the hero |
| 62–66 s | Walking a corridor holding the phone flat, with the walk bar visible | 4 s | Label it **BETA** in the edit. Rehearse first |
| 67–70 s | The phone's quick settings: Airplane mode turned on, then a scan | 3 s | Proves offline operation on camera |
| 77–80 s | Two phones: the share sheet sends the `.via` file, the other phone taps Import | 3 s | Nearby Share or WhatsApp |
| Optional | Marker peeled off the wall (for the "What happens when a marker disappears?" hook in the Dean pitch) | 2 s | |
| Optional | A wide shot of the RVU campus or building exterior | 3 s | Closing or campus hook |

### Recording checklist
- [ ] Install the latest release APK (GitHub Actions artifact `indoor-nav-apk`, arm64-v8a)
- [ ] Print markers 13 (Entry 1), 9 (Lift 1), 23 (Lift 3) and 18 (Room 104) from `ArUco/`, with white margins
- [ ] Phone: Do Not Disturb on, full battery, clean status bar, light theme, brightness at 80%
- [ ] Rehearse the scan three times in the actual lighting before rolling
- [ ] Record the screen at the same time as the camera (shoot with an audible clap to sync)
- [ ] Record W1 (from `PROJECT_VIDEO_BRIEF.md` §10) as one unedited take, for the Dean pitch's "live proof"

## 3. Optional upgrades in DaVinci Resolve
- **Voice:** replace the Kokoro lines with a human voice-over at the same start times.
- **Music:** if you have a licensed cinematic electronic track (110–120 BPM), cut its drop to land at **46.80 s**.
- **Grade:** grade the live-action to the sand palette (warm, slightly lifted blacks). **Don't grade the sonar section**: it is the app's own colour.
- **Stems:** export the voice, music and SFX stems by rendering with `data-hidden` on the other tracks, or rebuild the mix from `composition/assets/`.
