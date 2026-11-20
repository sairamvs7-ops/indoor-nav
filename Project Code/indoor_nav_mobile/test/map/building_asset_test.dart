import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';

import '../support/test_map.dart';

/// Edges exactly as they were in wifi/wifi.ino initGraph(). The app must keep
/// the same graph the ESP32 used unless the map is changed on purpose.
const esp32Edges = <(int, int, double)>[
  (13, 4, 1),
  (4, 5, 1),
  (5, 6, 1),
  (6, 7, 1),
  (3, 2, 1),
  (2, 1, 1),
  (1, 10, 1),
  (10, 12, 1),
  (12, 14, 1),
  (13, 9, 1),
  (9, 11, 1),
  (11, 8, 1),
  (8, 3, 1),
  (7, 10, 1),
  (4, 3, 1),
  (27, 28, 1),
  (28, 18, 1),
  (18, 19, 1),
  (19, 20, 1),
  (20, 21, 1),
  (27, 23, 1),
  (23, 25, 1),
  (25, 22, 1),
  (22, 17, 1),
  (17, 16, 1),
  (16, 15, 1),
  (15, 24, 1),
  (24, 26, 1),
  (21, 24, 1),
  (18, 17, 1),
  (9, 23, 1),
  (11, 25, 2),
  (10, 24, 1),
  (12, 26, 2),
];

/// Printed markers are DICT_4X4_50, so only ids 0-49 can ever be detected.
const markerDictionarySize = 50;

/// Reads (width, height) from a baseline or progressive JPEG header.
(int, int) jpegSize(Uint8List bytes) {
  var i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] != 0xFF) throw const FormatException('bad JPEG marker');
    final marker = bytes[i + 1];
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (marker >= 0xC0 && marker <= 0xC3) {
      final height = (bytes[i + 5] << 8) | bytes[i + 6];
      final width = (bytes[i + 7] << 8) | bytes[i + 8];
      return (width, height);
    }
    i += 2 + length;
  }
  throw const FormatException('no JPEG size header');
}

void main() {
  final map = loadRealMap();

  test('has two floors and the 28 nodes from the floor plan', () {
    expect(map.floors.map((f) => f.name), ['Ground Floor', 'First Floor']);
    expect(map.nodes.keys.toSet(), {for (var i = 1; i <= 28; i++) i});
  });

  test('keeps exactly the ESP32 graph', () {
    String key(int a, int b, double w) => a < b ? '$a-$b:$w' : '$b-$a:$w';

    final actual = map.edges.map((e) => key(e.from, e.to, e.weight)).toSet();
    final expected = esp32Edges.map((e) => key(e.$1, e.$2, e.$3)).toSet();

    expect(actual, expected);
  });

  test('maps printed markers 1-27 to the node with the same number', () {
    for (var marker = 1; marker <= 27; marker++) {
      expect(map.nodeForMarker(marker)?.id, marker, reason: 'marker $marker');
    }
    expect(map.node(28).markerId, isNull, reason: 'the vending machine has no printed marker');
  });

  test('only uses marker ids the scanner dictionary can detect', () {
    expect(map.markerIds.every((id) => id >= 0 && id < markerDictionarySize), isTrue);
  });

  test('every node can reach every other node', () {
    final seen = <int>{1};
    final queue = [1];
    while (queue.isNotEmpty) {
      for (final n in map.graph[queue.removeLast()]!) {
        if (seen.add(n.node)) queue.add(n.node);
      }
    }

    expect(seen, map.nodes.keys.toSet());
  });

  test('floor images exist and match the sizes in building.json', () {
    for (final floor in map.floors) {
      final file = File(floor.image);
      expect(file.existsSync(), isTrue, reason: '${floor.image} is missing');

      final (width, height) = jpegSize(file.readAsBytesSync());

      expect((width.toDouble(), height.toDouble()), (floor.width, floor.height), reason: floor.image);
    }
  });

  test('lifts and stairs only connect to the matching type on the other floor', () {
    for (final e in map.edges) {
      final a = map.node(e.from);
      final b = map.node(e.to);
      if (a.floor != b.floor) {
        expect(a.type, b.type, reason: '${a.name} <-> ${b.name}');
        expect(a.type, anyOf(NodeType.lift, NodeType.stairs));
      }
    }
  });
}
