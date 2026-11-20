# Indoor Nav (mobile)

Offline indoor navigation. Point the camera at an ArUco marker on the wall, choose a destination, and follow the route drawn on the floor plan. Routes are computed on the phone with bidirectional Dijkstra, the same algorithm the ESP32 version ran, with its shortest-path bug fixed.

## Run it

Requirements: Flutter 3.41 or newer, Android API 24+ or iOS 13+, and a phone with a camera. Emulators can run the app, but scanning needs a real camera.

```sh
flutter pub get
flutter run            # with a phone plugged in
flutter test
flutter analyze
```

The first Android build downloads Gradle and the prebuilt OpenCV libraries, so it takes a few minutes.

## Using the app

### Set up a building (once, by whoever manages it)

1. **New building** on the home screen, and give it a name.
2. **Add a floor** for each storey: pick a blueprint image or photograph a printed plan. Floors are added bottom-up.
3. Open a floor and, in **Places** mode, tap the blueprint to add rooms, washrooms, entrances, lifts and stairs. Each place gets the next free marker number automatically. Give lifts and stairs a **link name** (for example `Lift A`) and use the same link name on every floor they reach: that is how the app knows they connect floors.
4. In **Paths** mode, tap **Suggest paths** and add them, then tap two places to remove any path that goes through a wall or add a missing one. Add **corridor points** (no marker) to make routes follow corners.
5. Optional: in **Scale** mode, tap two points a known distance apart and enter the metres, so routes compare real walking distances.
6. The **checklist** on the building screen lists anything that would break navigation (unreachable places, lifts linked to nothing).
7. **Print and place markers**: share or print the PDF (one marker per page), stick each marker at the place listed, and use **Test scan** to confirm each one.
8. **Share building** sends one `.indoornav` file. Anyone with the app taps **Import** to get the whole building, blueprints included.

### Navigate

1. **Navigate** a building from the home screen.
2. **Choose a destination**: the button at the top, or tap a place on the floor plan.
3. **Scan marker**: point the camera at the nearest marker. The route is drawn and listed step by step, across floors.
4. Pick **Fastest**, **Step-free** (no stairs) or **Avoid lifts**. Scanning any marker on the way recalculates the route from there.
5. For places without a marker, tap **I'm at ...**, or set your location with the location button.

The appearance button (sun/moon icon) on the home screen switches between **Match phone**, **Light** and **Dark**. Brand colours live in `lib/ui/app_theme.dart` (`Brand.light` and `Brand.dark`).

## Building files

Buildings made on the phone are stored in the app's documents folder, one folder per building with `building.json` and one image per floor. The bundled sample is `assets/map/building.json`.

- **floors**: `level`, `name`, `image`, `width` and `height` of the drawing in pixels, and optional `metresPerPixel` (set by calibrating).
- **nodes**: `id`, `name`, `type` (`room`, `washroom`, `lift`, `stairs`, `entry`, `landmark`, `corridor`), `floor`, `x`/`y` in pixels on that floor's drawing, `marker` (0 to 249, or `null`) and, for lifts and stairs, `link`.
- **edges**: walkable two-way connections. `weight` is optional: without it the cost is the drawn length in metres. Lifts and stairs with the same `link` are connected between floors automatically (stairs cost 15 m per floor, a lift 20 m plus 3 m per floor).

Markers come from OpenCV's `DICT_4X4_250`. Its first 50 markers are the original `DICT_4X4_50` set, so markers printed for the first version still work. The sample building keeps its original ESP32 hop weights; `test/map/building_asset_test.dart` checks it still matches the ESP32 graph.

## How it works

```
lib/
  map/          building.json -> validated BuildingMap, lift/stairs links, routing graphs per preference
  routing/      bidirectional_dijkstra.dart (the "double Dijkstra"), directions.dart
  navigation/   NavigationController: location, destination, preference, route; reroutes on every scan
  scanner/      camera + OpenCV ArUco detection (DICT_4X4_250), 2-frame confirmation
  storage/      buildings on the phone, .indoornav export/import
  setup/        building and floor editors, path suggestions, setup checks, marker guide and PDF
  ui/           home, navigation screen, floor plans, theme and light/dark setting
```

**Routing.** The ESP32 version only recorded a meeting point when a node had been finished by *both* searches, so it could miss a shortest route that crosses between the two searches along a single edge. It returned a longer route for 36 of the 756 start and destination pairs, for example Stairs 1 → Stairs 3 through both lifts instead of straight up the stairs. This version updates the best route every time either search reaches a node the other has seen. The tests compare it with plain Dijkstra for all 784 pairs on the real map.

**Scanning.** Camera frames are requested as YUV420, so the brightness plane can be used directly on both Android and iPhone. Detection runs on an OpenCV worker thread. A marker only counts after it is the largest known marker in two frames in a row, which filters out misreads and far-away markers. Markers that aren't in `building.json` are ignored, with a hint on screen.

**OpenCV version.** `opencv_dart` is pinned to 1.4.5, which ships prebuilt binaries. Version 2.x compiles OpenCV from source on the first build, and its build leaves out the `aruco` module unless it is enabled in `pubspec.yaml`.
