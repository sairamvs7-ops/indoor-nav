import '../map/building_map.dart';

/// One hop of a route, with a sentence the user can follow.
class RouteStep {
  const RouteStep({required this.from, required this.to, required this.instruction});

  final MapNode from;
  final MapNode to;
  final String instruction;

  bool get changesFloor => from.floor != to.floor;
}

/// Turns a node-id path into readable steps, one per named place. Corridor
/// points along the way (corners, junctions) are walked through without a
/// step of their own, so the route reads "Walk to Room 104", not every turn.
List<RouteStep> buildSteps(BuildingMap map, List<int> path) {
  final stops = <MapNode>[];
  for (final (i, id) in path.indexed) {
    final node = map.node(id);
    final isEnd = i == 0 || i == path.length - 1;
    if (isEnd || node.type != NodeType.corridor) stops.add(node);
  }
  final steps = <RouteStep>[];
  for (var i = 0; i + 1 < stops.length; i++) {
    steps.add(RouteStep(from: stops[i], to: stops[i + 1], instruction: describeStep(map, stops[i], stops[i + 1])));
  }
  return List.unmodifiable(steps);
}

String describeStep(BuildingMap map, MapNode from, MapNode to) {
  if (from.floor == to.floor) return 'Walk to ${to.name}';
  final direction = to.floor > from.floor ? 'up' : 'down';
  return 'Take ${from.name} $direction to the ${map.floor(to.floor).name}';
}
