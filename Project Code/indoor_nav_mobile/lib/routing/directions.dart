import '../map/building_map.dart';

/// One hop of a route, with a sentence the user can follow.
class RouteStep {
  const RouteStep({required this.from, required this.to, required this.instruction});

  final MapNode from;
  final MapNode to;
  final String instruction;

  bool get changesFloor => from.floor != to.floor;
}

/// Turns a node-id path into readable steps, one per hop.
List<RouteStep> buildSteps(BuildingMap map, List<int> path) {
  final steps = <RouteStep>[];
  for (var i = 0; i + 1 < path.length; i++) {
    final from = map.node(path[i]);
    final to = map.node(path[i + 1]);
    steps.add(RouteStep(from: from, to: to, instruction: describeStep(map, from, to)));
  }
  return List.unmodifiable(steps);
}

String describeStep(BuildingMap map, MapNode from, MapNode to) {
  if (from.floor == to.floor) return 'Walk to ${to.name}';
  final direction = to.floor > from.floor ? 'up' : 'down';
  return 'Take ${from.name} $direction to the ${map.floor(to.floor).name}';
}
