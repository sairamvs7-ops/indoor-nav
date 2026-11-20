import 'dart:isolate';
import 'dart:typed_data';

import '../map/building_map.dart';
import 'floor_map_generator.dart';

/// Generates a floor's map from its blueprint image in a background isolate
/// and returns it as regions with ids r1, r2, ... (largest first).
/// Throws [FormatException] if the image can't be read.
Future<List<FloorRegion>> generateRegions(Uint8List imageBytes, {GapClosing gaps = GapClosing.normal}) async {
  final generated = await Isolate.run(() => generateFloorMap(imageBytes, gaps: gaps));
  return [
    for (final (i, r) in generated.regions.indexed)
      FloorRegion(
        id: 'r${i + 1}',
        kind: r.kind,
        outline: List.unmodifiable(r.outline),
        paths: [for (final p in r.paths) List.unmodifiable(p)],
      ),
  ];
}
