# Indoor Nav (mobile)

Offline indoor navigation. Point the camera at an ArUco marker on the wall, choose a destination, and follow the route drawn on the floor plan. Routes are computed on the phone with bidirectional Dijkstra, the same algorithm the ESP32 version ran, with its shortest-path bug fixed.

## Run it

Requirements: Flutter 3.41 or newer, Android API 24+ or iOS 13+, and a phone with a camera. Emulators can run the app, but scanning needs a real camera.

```sh
flutter pub get
flutter run            # with a phone plugged in
flutter test           # 84 tests
flutter analyze
```

The first Android build downloads Gradle and the prebuilt OpenCV libraries, so it takes a few minutes.

## Using the app

1. **Choose a destination**: the button at the top, or tap a place on the floor plan.
2. **Scan marker**: point the camera at the nearest marker. The app now knows where you are and shows the route.
3. Walk to the next stop and scan its marker. If you go a different way, scan any marker and the route is recalculated from there.
4. Places without a marker, or when you have no markers printed: tap **I'm at …** to move to the next stop, or set your location with the location button in the top bar.

## Changing the map

Everything about the building is in [`assets/map/building.json`](assets/map/building.json). The app checks it at startup and shows exactly what is wrong if an edit breaks it.

- **floors**: one entry per floor, with the drawing to show (`image`) and its size in pixels. If you replace a drawing, update `width` and `height` to match the new file.
- **nodes**: `id`, `name`, `type` (`room`, `washroom`, `lift`, `stairs`, `entry`, `landmark`), `floor`, and `marker` (the printed ArUco id, or `null`). `x` and `y` are **pixel positions on that floor's image**: open the image in Paint and hover over the spot, and the bottom bar shows the coordinates.
- **edges**: walkable connections, two-way. `weight` is the cost of walking that edge. The current weights are copied from the ESP32 (1 per hop, 2 for stairs). You can switch to real distances, such as grid squares on the drawing; routes will then prefer genuinely shorter walks.

`test/map/building_asset_test.dart` checks that the map still matches the ESP32 graph. When you change the graph on purpose, update the `esp32Edges` list in that test as well.

## How it works

```
lib/
  map/          building.json -> validated, immutable BuildingMap (+ adjacency graph)
  routing/      bidirectional_dijkstra.dart (the "double Dijkstra"), directions.dart
  navigation/   NavigationController: current node, destination, route; reroutes on every scan
  scanner/      camera + OpenCV ArUco detection (DICT_4X4_50), 2-frame confirmation
  ui/           home screen, floor plan + route overlay, place picker, steps
```

**Routing.** The ESP32 version only recorded a meeting point when a node had been finished by *both* searches, so it could miss a shortest route that crosses between the two searches along a single edge. It returned a longer route for 36 of the 756 start and destination pairs, for example Stairs 1 → Stairs 3 through both lifts instead of straight up the stairs. This version updates the best route every time either search reaches a node the other has seen. The tests compare it with plain Dijkstra for all 784 pairs on the real map.

**Scanning.** Camera frames are requested as YUV420, so the brightness plane can be used directly on both Android and iPhone. Detection runs on an OpenCV worker thread. A marker only counts after it is the largest known marker in two frames in a row, which filters out misreads and far-away markers. Markers that aren't in `building.json` are ignored, with a hint on screen.

**OpenCV version.** `opencv_dart` is pinned to 1.4.5, which ships prebuilt binaries. Version 2.x compiles OpenCV from source on the first build, and its build leaves out the `aruco` module unless it is enabled in `pubspec.yaml`.
