import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/map/map_loader.dart';

import '../support/test_map.dart';

Matcher throwsMapError(String fragment) =>
    throwsA(isA<MapFormatException>().having((e) => e.message, 'message', contains(fragment)));

Map<String, dynamic> withNode(int index, Map<String, dynamic> changes) {
  final json = smallMapJson();
  final nodes = (json['nodes'] as List<Object?>).cast<Map<String, dynamic>>();
  nodes[index] = {...nodes[index], ...changes};
  return json;
}

Map<String, dynamic> withEdges(List<Map<String, dynamic>> edges) => {...smallMapJson(), 'edges': edges};

void main() {
  group('BuildingMap.fromJson', () {
    test('parses floors, nodes, markers and two-way edges', () {
      final map = BuildingMap.fromJson(smallMapJson());

      expect(map.name, 'Test block');
      expect(map.floors.map((f) => f.level), [0, 1]);
      expect(map.nodes, hasLength(7));
      expect(map.node(3).type, NodeType.lift);
      expect(map.nodeForMarker(5)!.name, 'Room B');
      expect(map.nodeForMarker(6), isNull, reason: 'node 6 has no marker');
      expect(map.isKnownMarker(7), isTrue);
      expect(map.isKnownMarker(6), isFalse);
      expect(map.graph[2]!.map((n) => n.node), unorderedEquals([1, 3]));
      expect(map.graph[7], isEmpty);
      expect(map.nodesOnFloor(1).map((n) => n.id), unorderedEquals([4, 5, 6]));
      expect(map.floor(1).name, 'First Floor');
    });

    test('sorts floors by level', () {
      final json = smallMapJson();
      json['floors'] = (json['floors'] as List<Object?>).reversed.toList();

      expect(BuildingMap.fromJson(json).floors.first.level, 0);
    });

    test('exposes unmodifiable collections', () {
      final map = BuildingMap.fromJson(smallMapJson());

      expect(() => map.nodes.remove(1), throwsUnsupportedError);
      expect(() => map.graph[1]!.clear(), throwsUnsupportedError);
      expect(() => map.edges.clear(), throwsUnsupportedError);
    });

    test('throws ArgumentError for unknown node ids and floor levels', () {
      final map = BuildingMap.fromJson(smallMapJson());

      expect(() => map.node(99), throwsArgumentError);
      expect(() => map.floor(5), throwsArgumentError);
    });

    test('rejects a duplicate node id', () {
      expect(() => BuildingMap.fromJson(withNode(1, {'id': 1})), throwsMapError('duplicate node id 1'));
    });

    test('rejects two nodes sharing one marker', () {
      expect(
        () => BuildingMap.fromJson(withNode(1, {'marker': 1})),
        throwsMapError('marker 1 is already used by node 1'),
      );
    });

    test('rejects a negative, non-integer or unscannable marker', () {
      expect(() => BuildingMap.fromJson(withNode(0, {'marker': -1})), throwsMapError('"marker"'));
      expect(() => BuildingMap.fromJson(withNode(0, {'marker': 'one'})), throwsMapError('"marker"'));
      expect(() => BuildingMap.fromJson(withNode(0, {'marker': 50})), throwsMapError('from 0 to 49'));
      expect(BuildingMap.fromJson(withNode(0, {'marker': 49})).nodeForMarker(49)!.id, 1);
    });

    test('rejects a node on a floor that does not exist', () {
      expect(() => BuildingMap.fromJson(withNode(0, {'floor': 3})), throwsMapError('floor 3 is not listed'));
    });

    test('rejects a node positioned outside its floor image', () {
      expect(() => BuildingMap.fromJson(withNode(0, {'x': 150})), throwsMapError('outside the 100x100 image'));
    });

    test('rejects an unknown node type and lists the allowed ones', () {
      expect(() => BuildingMap.fromJson(withNode(0, {'type': 'cafe'})), throwsMapError('use one of: room'));
    });

    test('rejects missing or wrongly typed fields', () {
      expect(
        () => BuildingMap.fromJson(withNode(0, {'name': ''})),
        throwsMapError('"name" must be a non-empty string'),
      );
      expect(() => BuildingMap.fromJson(withNode(0, {'x': 'left'})), throwsMapError('"x" must be a number'));
      expect(() => BuildingMap.fromJson(withNode(0, {'floor': 0.5})), throwsMapError('"floor" must be a whole number'));
      expect(
        () => BuildingMap.fromJson({...smallMapJson(), 'nodes': 'none'}),
        throwsMapError('"nodes" must be a list'),
      );
      expect(
        () => BuildingMap.fromJson({
          ...smallMapJson(),
          'nodes': [3],
        }),
        throwsMapError('expected an object'),
      );
      expect(
        () => BuildingMap.fromJson({...smallMapJson(), 'building': 7}),
        throwsMapError('"building" must be a string'),
      );
    });

    test('rejects an empty floor list, duplicate levels and non-positive sizes', () {
      final floor = {'level': 0, 'name': 'G', 'image': 'g.jpg', 'width': 10, 'height': 10};

      expect(() => BuildingMap.fromJson({...smallMapJson(), 'floors': []}), throwsMapError('must not be empty'));
      expect(
        () => BuildingMap.fromJson({
          ...smallMapJson(),
          'floors': [floor, floor],
        }),
        throwsMapError('duplicate floor level 0'),
      );
      expect(
        () => BuildingMap.fromJson({
          ...smallMapJson(),
          'floors': [
            {...floor, 'width': 0},
          ],
        }),
        throwsMapError('"width" must be greater than 0'),
      );
    });

    test('rejects edges to missing nodes, self-loops, duplicates and bad weights', () {
      expect(
        () => BuildingMap.fromJson(
          withEdges([
            {'from': 1, 'to': 50, 'weight': 1},
          ]),
        ),
        throwsMapError('node 50 does not exist'),
      );
      expect(
        () => BuildingMap.fromJson(
          withEdges([
            {'from': 2, 'to': 2, 'weight': 1},
          ]),
        ),
        throwsMapError('to itself'),
      );
      expect(
        () => BuildingMap.fromJson(
          withEdges([
            {'from': 1, 'to': 2, 'weight': 1},
            {'from': 2, 'to': 1, 'weight': 3},
          ]),
        ),
        throwsMapError('already connected'),
      );
      expect(
        () => BuildingMap.fromJson(
          withEdges([
            {'from': 1, 'to': 2, 'weight': 0},
          ]),
        ),
        throwsMapError('"weight" must be greater than 0'),
      );
    });
  });

  group('parseBuildingMap', () {
    test('reports invalid JSON clearly', () {
      expect(() => parseBuildingMap('{ nodes: ['), throwsMapError('not valid JSON'));
    });

    test('requires an object at the top level', () {
      expect(() => parseBuildingMap('[]'), throwsMapError('JSON object at the top level'));
    });
  });
}
