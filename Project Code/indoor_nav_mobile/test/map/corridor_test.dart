import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/map/corridor_network.dart';
import 'package:indoor_nav_mobile/routing/bidirectional_dijkstra.dart';
import 'package:indoor_nav_mobile/routing/directions.dart';

Pt p(double x, double y) => (x: x, y: y);

bool hasJunctionNear(CorridorNetwork n, Pt target, [double within = 1]) =>
    n.junctions.any((j) => (j.x - target.x).abs() <= within && (j.y - target.y).abs() <= within);

/// Whether junctions [a] and [b] are connected through the network.
bool reachable(CorridorNetwork n, int a, int b) {
  final seen = {a};
  final stack = [a];
  while (stack.isNotEmpty) {
    final v = stack.removeLast();
    if (v == b) return true;
    for (final (x, y) in n.segments) {
      final next = x == v ? y : (y == v ? x : null);
      if (next != null && seen.add(next)) stack.add(next);
    }
  }
  return false;
}

/// An L-shaped corridor on a 100x100 floor (scale 1 m per px), with Room A at
/// the top-left end and Room B at the bottom-right end.
Map<String, dynamic> lJson() => {
  'format': 3,
  'building': 'L block',
  'floors': [
    {'level': 0, 'name': 'Ground', 'image': 'g.jpg', 'width': 100, 'height': 100, 'metresPerPixel': 1},
  ],
  'nodes': [
    {'id': 1, 'name': 'Room A', 'type': 'room', 'floor': 0, 'x': 10, 'y': 5, 'marker': 1},
    {'id': 2, 'name': 'Room B', 'type': 'room', 'floor': 0, 'x': 95, 'y': 90, 'marker': 2},
  ],
  'edges': <Object?>[],
  'corridors': [
    {
      'floor': 0,
      'points': [
        [10, 10],
        [10, 90],
        [90, 90],
      ],
    },
  ],
};

void main() {
  group('buildCorridorNetwork', () {
    test('corridors that cross get a junction at the crossing', () {
      final n = buildCorridorNetwork(
        strokes: [
          [p(0, 50), p(100, 50)],
          [p(50, 0), p(50, 100)],
        ],
        places: const [],
        snap: 5,
      );

      expect(hasJunctionNear(n, p(50, 50)), isTrue);
      expect(n.segments, hasLength(4));
    });

    test('a corridor that stops just short of another joins it', () {
      final n = buildCorridorNetwork(
        strokes: [
          [p(0, 50), p(100, 50)],
          [p(50, 100), p(50, 53)],
        ],
        places: const [],
        snap: 5,
      );

      final bottom = n.junctions.indexWhere((j) => j.y == 100);
      final left = n.junctions.indexWhere((j) => j.x == 0);
      expect(reachable(n, bottom, left), isTrue);
    });

    test('nearby stroke ends merge into one junction', () {
      final n = buildCorridorNetwork(
        strokes: [
          [p(0, 0), p(50, 0)],
          [p(52, 1), p(52, 60)],
        ],
        places: const [],
        snap: 5,
      );

      expect(n.junctions, hasLength(3));
      expect(n.segments, hasLength(2));
    });

    test('each place joins the closest point of the nearest corridor', () {
      final n = buildCorridorNetwork(
        strokes: [
          [p(0, 50), p(100, 50)],
        ],
        places: [(7, p(30, 40)), (8, p(100, 55))],
        snap: 5,
      );

      expect(hasJunctionNear(n, p(30, 50), 1e-9), isTrue);
      final door7 = n.junctions[n.attachments[7]!];
      expect(door7.x, closeTo(30, 1e-9));
      expect(door7.y, closeTo(50, 1e-9));
      expect(n.junctions[n.attachments[8]!], p(100, 50)); // the corridor end
      expect(n.segments, hasLength(2)); // split once, at Room 7's door
    });

    test('places on a floor without corridors are left alone', () {
      final n = buildCorridorNetwork(strokes: const [], places: [(1, p(1, 1))], snap: 5);

      expect(n.attachments, isEmpty);
    });
  });

  test('simplifyStroke straightens finger wobble but keeps corners', () {
    final wobbly = [p(0, 0), p(10, 1), p(20, -1), p(30, 0.5), p(40, 0), p(40, 10), p(41, 20), p(40, 30)];

    final simple = simplifyStroke(wobbly, 2);

    expect(simple, [p(0, 0), p(40, 0), p(40, 30)]);
  });

  group('buildings with corridors', () {
    test('routes follow the corridor around the corner', () {
      final map = BuildingMap.fromJson(lJson());

      final route = bidirectionalDijkstra(map.graph, 1, 2)!;

      // 5 m to the corridor, 80 m down, 80 m across, 5 m into Room B.
      expect(route.cost, closeTo(170, 1e-6));
      final corner = route.nodes.map(map.node).where((n) => n.automatic);
      expect(corner.any((n) => n.x == 10 && n.y == 90), isTrue);
    });

    test('directions skip the corridor junctions', () {
      final map = BuildingMap.fromJson(lJson());
      final route = bidirectionalDijkstra(map.graph, 1, 2)!;

      final steps = buildSteps(map, route.nodes);

      expect(steps.map((s) => s.instruction), ['Walk to Room B']);
    });

    test('junctions are rebuilt on load, not saved', () {
      final map = BuildingMap.fromJson(lJson());
      final json = map.toJson();

      expect(map.nodes.values.where((n) => n.automatic), isNotEmpty);
      expect(json['nodes'], hasLength(2));
      expect(json['edges'], isEmpty);
      expect(json['corridors'], [
        {
          'floor': 0,
          'points': [
            [10.0, 10.0],
            [10.0, 90.0],
            [90.0, 90.0],
          ],
        },
      ]);
      expect(BuildingMap.fromJson(json).edges.length, map.edges.length);
    });

    test('rejects corridors on unknown floors or with bad points', () {
      final badFloor = {
        ...lJson(),
        'corridors': [
          {
            'floor': 4,
            'points': [
              [0, 0],
              [1, 1],
            ],
          },
        ],
      };
      final badPoint = {
        ...lJson(),
        'corridors': [
          {
            'floor': 0,
            'points': [
              [0, 0],
              ['x', 1],
            ],
          },
        ],
      };

      expect(() => BuildingMap.fromJson(badFloor), throwsA(isA<MapFormatException>()));
      expect(() => BuildingMap.fromJson(badPoint), throwsA(isA<MapFormatException>()));
    });
  });
}
