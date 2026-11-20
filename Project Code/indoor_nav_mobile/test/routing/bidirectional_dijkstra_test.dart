import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/routing/bidirectional_dijkstra.dart';

import '../support/test_map.dart';

double pathCost(Graph graph, List<int> path) {
  var total = 0.0;
  for (var i = 0; i + 1 < path.length; i++) {
    final hop = graph[path[i]]!.where((n) => n.node == path[i + 1]);
    expect(hop, isNotEmpty, reason: '${path[i]} -> ${path[i + 1]} is not an edge');
    total += hop.first.weight;
  }
  return total;
}

void main() {
  group('bidirectionalDijkstra on small graphs', () {
    test('returns a single-node path with zero cost when start equals goal', () {
      final graph = graphOf([(1, 2, 1)]);

      final result = bidirectionalDijkstra(graph, 1, 1);

      expect(result!.nodes, [1]);
      expect(result.cost, 0);
    });

    test('takes the cheaper direct edge over a two-hop detour', () {
      // The ESP32 version returned s-m-t (cost 4) here: it only recorded a
      // meeting at nodes settled by both searches and stopped too early.
      final graph = graphOf([(1, 3, 3), (1, 2, 2), (2, 3, 2)]);

      final result = bidirectionalDijkstra(graph, 1, 3);

      expect(result!.nodes, [1, 3]);
      expect(result.cost, 3);
    });

    test('returns null when the goal is unreachable', () {
      final graph = graphOf([(1, 2, 1), (3, 4, 1)]);

      expect(bidirectionalDijkstra(graph, 1, 4), isNull);
    });

    test('returns null for node ids that are not in the graph', () {
      final graph = graphOf([(1, 2, 1)]);

      expect(bidirectionalDijkstra(graph, 1, 99), isNull);
      expect(bidirectionalDijkstra(graph, 99, 1), isNull);
    });

    test('finds the shortest path on a weighted grid where greedy choices mislead', () {
      final graph = graphOf([(1, 2, 1), (2, 3, 1), (3, 4, 10), (1, 5, 4), (5, 6, 4), (6, 4, 1), (2, 6, 8)]);

      final result = bidirectionalDijkstra(graph, 1, 4)!;

      expect(result.cost, 9);
      expect(result.nodes, [1, 5, 6, 4]);
    });
  });

  group('bidirectionalDijkstra on the building map', () {
    final map = loadRealMap();
    final ids = map.nodes.keys.toList()..sort();

    test('Stairs 1 to Stairs 3 uses the direct stairs (ESP32 returned the lift detour)', () {
      final result = bidirectionalDijkstra(map.graph, 11, 25)!;

      expect(result.nodes, [11, 25]);
      expect(result.cost, 2);
    });

    test('Boys Washroom to Entry 3 goes past the stairs and lift (ESP32 returned cost 4)', () {
      final result = bidirectionalDijkstra(map.graph, 22, 27)!;

      expect(result.nodes, [22, 25, 23, 27]);
      expect(result.cost, 3);
    });

    test('matches plain Dijkstra for every start/destination pair', () {
      var pairs = 0;
      for (final source in ids) {
        for (final target in ids) {
          final result = bidirectionalDijkstra(map.graph, source, target);
          final expected = referenceDistance(map.graph, source, target);

          expect(result, isNotNull, reason: '$source -> $target has no path');
          expect(result!.cost, expected, reason: '$source -> $target is not shortest');
          expect(result.nodes.first, source);
          expect(result.nodes.last, target);
          expect(pathCost(map.graph, result.nodes), result.cost, reason: '$source -> $target path/cost mismatch');
          pairs++;
        }
      }
      expect(pairs, ids.length * ids.length);
    });
  });
}
