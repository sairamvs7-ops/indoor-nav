import 'dart:io';

import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/map/map_loader.dart';

/// The real bundled map, read straight from disk (tests run from the package root).
BuildingMap loadRealMap() => parseBuildingMap(File('assets/map/building.json').readAsStringSync());

/// Builds a [Graph] from (a, b, weight) triples, undirected.
Graph graphOf(List<(int, int, double)> edges) {
  final graph = <int, List<Neighbor>>{};
  for (final (a, b, w) in edges) {
    graph.putIfAbsent(a, () => []).add(Neighbor(b, w));
    graph.putIfAbsent(b, () => []).add(Neighbor(a, w));
  }
  return graph;
}

/// Plain single-direction Dijkstra, O(n^2). Used only as a reference answer.
double? referenceDistance(Graph graph, int source, int target) {
  if (!graph.containsKey(source) || !graph.containsKey(target)) return null;
  final dist = <int, double>{source: 0};
  final done = <int>{};
  while (true) {
    int? u;
    for (final e in dist.entries) {
      if (!done.contains(e.key) && (u == null || e.value < dist[u]!)) u = e.key;
    }
    if (u == null) return null;
    if (u == target) return dist[u];
    done.add(u);
    for (final n in graph[u]!) {
      final nd = dist[u]! + n.weight;
      if (nd < (dist[n.node] ?? double.infinity)) dist[n.node] = nd;
    }
  }
}

/// A minimal valid map JSON with two floors, used by parser and controller tests.
Map<String, dynamic> smallMapJson() => {
  'building': 'Test block',
  'floors': [
    {'level': 0, 'name': 'Ground Floor', 'image': 'g.jpg', 'width': 100, 'height': 100},
    {'level': 1, 'name': 'First Floor', 'image': 'f.jpg', 'width': 100, 'height': 100},
  ],
  'nodes': [
    {'id': 1, 'name': 'Entry', 'type': 'entry', 'floor': 0, 'x': 10, 'y': 10, 'marker': 1},
    {'id': 2, 'name': 'Room A', 'type': 'room', 'floor': 0, 'x': 50, 'y': 10, 'marker': 2},
    {'id': 3, 'name': 'Lift G', 'type': 'lift', 'floor': 0, 'x': 90, 'y': 10, 'marker': 3},
    {'id': 4, 'name': 'Lift 1', 'type': 'lift', 'floor': 1, 'x': 90, 'y': 10, 'marker': 4},
    {'id': 5, 'name': 'Room B', 'type': 'room', 'floor': 1, 'x': 50, 'y': 50, 'marker': 5},
    {'id': 6, 'name': 'Kiosk', 'type': 'landmark', 'floor': 1, 'x': 10, 'y': 90, 'marker': null},
    {'id': 7, 'name': 'Store', 'type': 'room', 'floor': 0, 'x': 10, 'y': 90, 'marker': 7},
  ],
  'edges': [
    {'from': 1, 'to': 2, 'weight': 1},
    {'from': 2, 'to': 3, 'weight': 1},
    {'from': 3, 'to': 4, 'weight': 1},
    {'from': 4, 'to': 5, 'weight': 1},
    {'from': 5, 'to': 6, 'weight': 1},
  ],
};
