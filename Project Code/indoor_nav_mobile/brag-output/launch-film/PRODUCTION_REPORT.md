# Via launch film: production report

## Deliverables (in `brag-output/launch-film/`)

| File | What it is |
|---|---|
| `via-launch-film.mp4` | **The film.** 1920×1080, 30 fps, H.264 + AAC 48 kHz stereo, **2:02.0**. Narrated throughout, with burned-in captions. A poster frame is baked in as the first frame. |
| `via-launch-film-vertical.mp4` | 1080×1920 cut-down for phones and Reels. The same film, framed over a blurred brand-sand fill |
| `brag.jpg` | Poster / thumbnail frame |
| `LAUNCH_FILM_STORYBOARD.md` | Scene-by-scene timeline, visuals, on-screen text, hooks |
| `NARRATION_SCRIPT.md` | Every line with its start time, pronunciation, and the evidence behind each claim |
| `ASSET_REQUIREMENTS.md` | What was rendered from the app, what was drawn, audio sources and licences, and footage still worth shooting |
| `ENGAGEMENT_HOOKS.md` | The open questions in the film, and the ones kept for Q&A |
| `share-copy.txt` | A short caption for sharing |
| `composition/` | The HyperFrames project: one HTML file per scene, editable in the HyperFrames app or Studio |
| `work/` | Everything needed to rebuild: capture test, label patcher, ESP32 proof script, generator (`build_film3.py`) |

## How it was made
1. **Real app screens.** `work/capture_film_test.dart` drives the app's own widgets with `flutter test` and saves frames: home, search, scan, route and guide dot, preferences, the full 3D floor change, arrival, beta walk, floor editor. No app source was changed. The sample building got the same review an admin does in the editor, so its stairs and room names match the hand-drawn plan.
2. **Labels.** Flutter 3.50's test engine draws unstyled text as boxes, so `work/patch_labels.py` redraws those labels in Roboto, at the app's own positions and fitted inside each room.
3. **Proof numbers.** `work/esp32_pairs.py` is an exact port of the ESP32 firmware's search. It gives **36 of 756** longer routes, and the grid in the film plots exactly those pairs.
4. **Film.** `work/build_film3.py` writes 14 HyperFrames scenes, timed from the narration files. HyperFrames `check` passes with 0 errors, and the film was rendered locally.

## Quality checks run on the final file
- **Length:** 2:02.0. Everything is kept; full-sentence narration makes it slightly longer than 2:00, as agreed.
- **Narration:** continuous; the longest pause between sentences is 1.5 s. Every line was checked for clipped starts and endings, padded, and levelled to −16 LUFS.
- **Speech recognition (Whisper) on all 17 narration files, and on the full soundtrack:** every line is heard exactly as written, once, in order, with no extra or garbled speech. Both music tracks contain no vocals.
- **One pre-mixed soundtrack** (`composition/assets/audio/film_mix.wav`, −16.3 LUFS measured on the final MP4, −1.0 dBFS true peak) plays in the preview and the render. That stops the preview player stuttering ("babbling") when it seeks many separate clips. The separate voice, music and SFX clips are listed in `work/audio_stems.html` for editing; they are not in `index.html`, so the soundtrack is never doubled.
- **Audio vs a reference mix built directly from the source clips:** 0 dropout windows, envelope correlation 0.998. No clipping.
- **Campus illustration:** every block sits between the roads. It is the same drawing in the opening and the future scene.
- **Visual watch-through:**
  - frames every 3 s across the whole film, plus targeted checks at every scene change
  - captions aligned to the spoken words (measured from the audio)
  - the end card lands on "Via": the logo's destination dot pops on the spoken word
  - the Via logo (title and end card) settles on the exact master artwork, checked against `Logo/Final_v2/png/on-light/via-logo-horizontal-light-2400.png`
  - the map is the app's own render everywhere, with consistent stairs and names

- **3D floor change:** the app's own animation at its **real speed**, not slowed or retimed. It is the capture's frames 9–128 (4.0 s), without the overlay's fade-in and fade-out frames, so the stray map that used to follow it is gone.
  - One narrated line covers it: "And when your route changes floors, the app shows you exactly how you get there, in 3D."
  - **No text is drawn over it.** Its own floor labels ("GROUND FLOOR", "FIRST FLOOR") are redrawn in Roboto by `work/fix_sonar_labels.py`. They follow each label's track and fade with it. The two labels never overlap.
  - It holds on the settled first floor, then a brand-green wipe leads to the arrival map. There are no blank or muddy frames.
  - Checked frame by frame on a rendered MP4 of that section.
- **Narration grammar:** every line is a complete sentence, and each was re-checked word for word with speech recognition.

## Still worth doing (optional)
1. **Better voice:** a HeyGen sign-in gives a more natural voice (and a music catalogue), or a team member can record the 17 lines in `NARRATION_SCRIPT.md`. Drop the files into `composition/assets/vo/` and run `python work/build_film3.py`; the scenes re-time themselves.
2. **Real footage:** the scan viewfinder is composited, because the test camera is black. A 4-second phone recording of a real scan of marker 13 (see `ASSET_REQUIREMENTS.md`) would replace it, and would make an even stronger live demo.
3. **Credits:** confirm the team credit line before external use.
4. **ML Kit check:** check the release APK's merged permissions before making any stronger privacy claim. The film only says "works offline".

## Honesty notes
- **Labelled as not finished:** walk mode is labelled **BETA**. Mapping every campus block, the shared library, other industries and walk-it-once mapping are labelled **PLANNED** or said as "next" or "one day".
- **Illustrations:** the campus plan is an illustration, not RVU's real layout. The floor plans and app screens are real.
- **Numbers:** the only figures in the film are 36/756, 784/784 and 192, all verified from the code.
