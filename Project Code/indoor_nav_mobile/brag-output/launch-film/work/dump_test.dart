import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';

import '../../../test/support/test_map.dart';
import 'capture_film_test.dart' as cap;

void main() {
  test('dump', () async {
    final map = await cap.sampleWithMaps(loadRealMap());
    final out = <String, Object>{};
    for (final f in map.floors) {
      out['floor${f.level}'] = {
        'regions': [
          for (final r in f.regions)
            {
              'id': r.id,
              'kind': r.kind.name,
              'outline': [for (final p in r.outline) [p.x.round(), p.y.round()]],
              'paths': [for (final path in r.paths) [for (final p in path) [p.x.round(), p.y.round()]]],
              'bbox': [
                r.outline.map((p) => p.x).reduce(math.min).round(),
                r.outline.map((p) => p.y).reduce(math.min).round(),
                r.outline.map((p) => p.x).reduce(math.max).round(),
                r.outline.map((p) => p.y).reduce(math.max).round(),
              ],
            },
        ],
        'nodes': [
          for (final n in map.nodesOnFloor(f.level))
            if (!n.automatic) {'id': n.id, 'name': n.name, 'type': n.type.name, 'x': n.x.round(), 'y': n.y.round(), 'region': n.region},
        ],
      };
    }
    File('brag-output/launch-film/work/regions.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}
