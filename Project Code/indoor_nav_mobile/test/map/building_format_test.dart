import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/aruco_markers.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/navigation/navigation_controller.dart';
import 'package:indoor_nav_mobile/routing/bidirectional_dijkstra.dart';

Matcher throwsMapError(String fragment) =>
    throwsA(isA<MapFormatException>().having((e) => e.message, 'message', contains(fragment)));

/// Three floors, 100x100 px each. Lift A and Stairs B run through every floor,
/// linked by name only; no hand-drawn vertical edges.
Map<String, dynamic> towerJson({double? metresPerPixel = 0.5}) => {
  'format': 2,
  'id': 'abcdef0123456789',
  'building': 'Tower',
  'floors': [
    for (final level in [0, 1, 2])
      {
        'level': level,
        'name': 'Floor $level',
        'image': 'f$level.jpg',
        'width': 100,
        'height': 100,
        'metresPerPixel': ?metresPerPixel,
      },
  ],
  'nodes': [
    {'id': 1, 'name': 'Entrance', 'type': 'entry', 'floor': 0, 'x': 0, 'y': 0, 'marker': 1},
    {'id': 2, 'name': 'Lift A G', 'type': 'lift', 'floor': 0, 'x': 40, 'y': 0, 'marker': 2, 'link': 'Lift A'},
    {'id': 3, 'name': 'Stairs B G', 'type': 'stairs', 'floor': 0, 'x': 0, 'y': 30, 'marker': 3, 'link': 'Stairs B'},
    {'id': 4, 'name': 'Lift A 1', 'type': 'lift', 'floor': 1, 'x': 40, 'y': 0, 'marker': 4, 'link': 'lift a'},
    {'id': 5, 'name': 'Stairs B 1', 'type': 'stairs', 'floor': 1, 'x': 0, 'y': 30, 'marker': 5, 'link': 'Stairs B'},
    {'id': 6, 'name': 'Lift A 2', 'type': 'lift', 'floor': 2, 'x': 40, 'y': 0, 'marker': 6, 'link': 'Lift A'},
    {'id': 7, 'name': 'Stairs B 2', 'type': 'stairs', 'floor': 2, 'x': 0, 'y': 30, 'marker': 7, 'link': 'Stairs B'},
    {'id': 8, 'name': 'Lab', 'type': 'room', 'floor': 2, 'x': 20, 'y': 15, 'marker': 8},
  ],
  'edges': [
    {'from': 1, 'to': 2},
    {'from': 1, 'to': 3},
    {'from': 6, 'to': 8},
    {'from': 7, 'to': 8},
  ],
};

MapEdge edgeBetween(BuildingMap map, int a, int b) =>
    map.edges.firstWhere((e) => (e.from == a && e.to == b) || (e.from == b && e.to == a));

void main() {
  group('distances', () {
    test('walking cost is the drawn length times the floor scale', () {
      final map = BuildingMap.fromJson(towerJson());

      expect(edgeBetween(map, 1, 2).weight, closeTo(20, 1e-9)); // 40 px * 0.5 m
      expect(edgeBetween(map, 1, 2).kind, EdgeKind.walk);
      expect(edgeBetween(map, 1, 2).explicitWeight, isNull);
    });

    test('an uncalibrated floor assumes it spans the default width', () {
      final map = BuildingMap.fromJson(towerJson(metresPerPixel: null));

      expect(map.floor(0).effectiveMetresPerPixel, defaultFloorSpanMetres / 100);
      expect(edgeBetween(map, 1, 2).weight, closeTo(40 * defaultFloorSpanMetres / 100, 1e-9));
    });

    test('a hand-set weight is kept as written', () {
      final json = towerJson();
      (json['edges'] as List<Object?>)[0] = {'from': 1, 'to': 2, 'weight': 7};

      expect(edgeBetween(BuildingMap.fromJson(json), 1, 2).weight, 7);
    });
  });

  group('lift and stairs links', () {
    test('matching link names connect each floor to the next, ignoring case', () {
      final map = BuildingMap.fromJson(towerJson());

      final lift01 = edgeBetween(map, 2, 4);
      final lift12 = edgeBetween(map, 4, 6);
      expect(lift01.kind, EdgeKind.lift);
      expect(lift01.automatic, isTrue);
      expect(lift01.weight, liftBaseCost + liftCostPerFloor);
      expect(lift12.kind, EdgeKind.lift);
      expect(edgeBetween(map, 3, 5).weight, stairsCostPerFloor);
      expect(edgeBetween(map, 5, 7).kind, EdgeKind.stairs);
      expect(map.edges.where((e) => e.automatic), hasLength(4));
    });

    test('a lift that skips a floor costs per floor travelled', () {
      final json = towerJson();
      (json['nodes'] as List<Object?>).removeWhere((n) => (n as Map)['id'] == 4);

      expect(edgeBetween(BuildingMap.fromJson(json), 2, 6).weight, liftBaseCost + 2 * liftCostPerFloor);
    });

    test('rejects two lifts with the same link on one floor', () {
      final json = towerJson();
      (json['nodes'] as List<Object?>).add({
        'id': 9,
        'name': 'Lift A twin',
        'type': 'lift',
        'floor': 0,
        'x': 50,
        'y': 50,
        'marker': 9,
        'link': 'Lift A',
      });

      expect(() => BuildingMap.fromJson(json), throwsMapError('are both "Lift A" on Floor 0'));
    });

    test('rejects a link on a place that is not a lift or stairs', () {
      final json = towerJson();
      ((json['nodes'] as List<Object?>)[7]! as Map<String, Object?>)['link'] = 'x';

      expect(() => BuildingMap.fromJson(json), throwsMapError('only lifts and stairs'));
    });
  });

  group('route preferences', () {
    test('fastest takes the stairs when they are cheaper', () {
      final map = BuildingMap.fromJson(towerJson());

      final route = bidirectionalDijkstra(map.graphFor(RoutePreference.fastest), 1, 8)!;
      expect(route.nodes, [1, 3, 5, 7, 8]);
    });

    test('step-free avoids the stairs and avoid-lifts avoids the lift', () {
      final map = BuildingMap.fromJson(towerJson());

      expect(bidirectionalDijkstra(map.graphFor(RoutePreference.stepFree), 1, 8)!.nodes, [1, 2, 4, 6, 8]);
      expect(bidirectionalDijkstra(map.graphFor(RoutePreference.avoidLifts), 1, 8)!.nodes, [1, 3, 5, 7, 8]);
    });

    test('the controller reroutes when the preference changes and explains a missing route', () {
      final json = towerJson();
      (json['nodes'] as List<Object?>).removeWhere((n) => const {2, 4, 6}.contains((n as Map)['id']));
      (json['edges'] as List<Object?>).removeWhere((e) => (e as Map)['to'] == 2 || e['from'] == 6);
      final nav = NavigationController(BuildingMap.fromJson(json))
        ..setCurrentLocation(1)
        ..selectDestination(8);
      expect(nav.routeNodes, [1, 3, 5, 7, 8]);

      nav.setPreference(RoutePreference.stepFree);

      expect(nav.preference, RoutePreference.stepFree);
      expect(nav.isUnreachable, isTrue);
      expect(nav.instruction, 'No step-free route from Entrance to Lab.');
    });
  });

  group('format', () {
    test('toJson round-trips and leaves out automatic links', () {
      final map = BuildingMap.fromJson(towerJson());
      final json = map.toJson();

      expect(json['format'], currentMapFormat);
      expect(json['id'], 'abcdef0123456789');
      expect(json['edges'], hasLength(4));
      final again = BuildingMap.fromJson(json);
      expect(again.edges.length, map.edges.length);
      expect(again.node(4).link, 'lift a');
      expect(again.floor(1).metresPerPixel, 0.5);
    });

    test('rejects a building made by a newer app', () {
      expect(() => BuildingMap.fromJson({...towerJson(), 'format': 99}), throwsMapError('Update the app'));
    });

    test('accepts markers up to 249', () {
      final json = towerJson();
      ((json['nodes'] as List<Object?>)[0]! as Map<String, Object?>)['marker'] = 249;

      expect(BuildingMap.fromJson(json).nodeForMarker(249)!.name, 'Entrance');
    });
  });

  group('marker drawing', () {
    test('has a black border and the OpenCV bit pattern inside', () {
      final cells = markerCells(0);

      expect(cells, hasLength(6));
      for (var i = 0; i < 6; i++) {
        expect(cells[0][i] || cells[5][i] || cells[i][0] || cells[i][5], isFalse);
      }
      // DICT_4X4_250 id 0 is 0xB532: rows 1011 0101 0011 0010.
      expect(cells[1].sublist(1, 5), [true, false, true, true]);
      expect(cells[2].sublist(1, 5), [false, true, false, true]);
      expect(cells[3].sublist(1, 5), [false, false, true, true]);
      expect(cells[4].sublist(1, 5), [false, false, true, false]);
    });

    test('rejects ids outside the dictionary', () {
      expect(() => markerCells(markerCount), throwsRangeError);
      expect(() => markerCells(-1), throwsRangeError);
    });
  });
}
