import 'package:collection/collection.dart';

import '../map/building_map.dart';

/// A route through the graph: node ids from start to goal, and the total weight.
class ShortestPath {
  const ShortestPath(this.nodes, this.cost);

  final List<int> nodes;
  final double cost;
}

/// Bidirectional ("double") Dijkstra on an undirected graph with positive
/// weights. One search grows from [source], one from [target], until they meet.
///
/// Port of the search that ran on the ESP32 (wifi/wifi.ino), with its bug
/// fixed: the ESP32 only counted a meeting at nodes that *both* searches had
/// finished, so it missed shortest paths that cross between the two searches
/// along a single edge, and returned a longer route for 36 of 756 start/goal
/// pairs. Here the best total is updated whenever either search improves a
/// node the other search has already reached, which is the standard,
/// provably correct rule.
///
/// Returns null when either id is not in [graph] or the goal is unreachable.
ShortestPath? bidirectionalDijkstra(Graph graph, int source, int target) {
  if (!graph.containsKey(source) || !graph.containsKey(target)) return null;
  if (source == target) return ShortestPath(List.unmodifiable([source]), 0);

  final forward = _Frontier(graph, source);
  final backward = _Frontier(graph, target);
  var best = double.infinity;
  int? meeting;

  while (true) {
    final forwardTop = forward.peekDistance();
    final backwardTop = backward.peekDistance();
    // One side has run out of nodes: everything reachable has been seen.
    if (forwardTop == null || backwardTop == null) break;
    // Nothing left in either queue can beat the best meeting found so far.
    if (forwardTop + backwardTop >= best) break;

    final (side, other) = forwardTop <= backwardTop ? (forward, backward) : (backward, forward);
    for (final node in side.settleNext()) {
      final otherDistance = other.distanceTo(node);
      if (otherDistance == null) continue;
      final total = side.distanceTo(node)! + otherDistance;
      if (total < best) {
        best = total;
        meeting = node;
      }
    }
  }

  if (meeting == null) return null;
  final path = [...forward.pathFromOrigin(meeting), ...backward.pathFromOrigin(meeting).reversed.skip(1)];
  return ShortestPath(List.unmodifiable(path), best);
}

/// One direction of the search: tentative distances, parents and a min-heap.
class _Frontier {
  _Frontier(this._graph, this._origin) {
    _distance[_origin] = 0;
    _queue.add((_origin, 0));
  }

  final Graph _graph;
  final int _origin;
  final Map<int, double> _distance = {};
  final Map<int, int> _parent = {};
  final Set<int> _settled = {};
  final HeapPriorityQueue<(int, double)> _queue = HeapPriorityQueue((a, b) => a.$2.compareTo(b.$2));

  double? distanceTo(int node) => _distance[node];

  /// Distance of the closest unsettled node, dropping stale heap entries.
  double? peekDistance() {
    while (_queue.isNotEmpty) {
      final (node, distance) = _queue.first;
      if (!_settled.contains(node) && distance <= _distance[node]!) return distance;
      _queue.removeFirst();
    }
    return null;
  }

  /// Settles the closest node and returns the neighbours whose distance improved.
  /// Call only after [peekDistance] returned non-null.
  List<int> settleNext() {
    final (node, distance) = _queue.removeFirst();
    _settled.add(node);
    final improved = <int>[];
    for (final neighbor in _graph[node] ?? const <Neighbor>[]) {
      final candidate = distance + neighbor.weight;
      if (candidate < (_distance[neighbor.node] ?? double.infinity)) {
        _distance[neighbor.node] = candidate;
        _parent[neighbor.node] = node;
        _queue.add((neighbor.node, candidate));
        improved.add(neighbor.node);
      }
    }
    return improved;
  }

  /// Node ids from this search's origin to [node], following parent links.
  List<int> pathFromOrigin(int node) {
    final path = <int>[node];
    var current = node;
    while (current != _origin) {
      current = _parent[current]!;
      path.add(current);
    }
    return path.reversed.toList();
  }
}
