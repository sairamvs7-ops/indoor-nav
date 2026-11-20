import '../map/building_map.dart';
import '../routing/bidirectional_dijkstra.dart';

enum WalkVerdict {
  /// The map already has a route between the two scans with no other marker
  /// on it: what was walked matches the map.
  confirmed,

  /// The map's route passes other marked places that weren't scanned: either
  /// they were skipped, or there is a more direct way the map doesn't know.
  viaOthers,

  /// The map has no way between the two places at all.
  missing,

  /// A lift or stairs on one floor, then the same kind on another floor,
  /// that the map does not link yet.
  unlinkedFloors,

  /// A lift or stairs pair the map already links.
  linkedFloors,

  /// Changed floor between scans without scanning the lift or stairs used.
  floorChangeUnknown,
}

/// What walking from one scanned place straight to the next says about the map.
class WalkFinding {
  const WalkFinding(this.verdict, this.from, this.to, {this.via = const []});

  final WalkVerdict verdict;
  final MapNode from;
  final MapNode to;

  /// For [WalkVerdict.viaOthers]: the marked places the map's route goes past.
  final List<MapNode> via;

  String get message => switch (verdict) {
    WalkVerdict.confirmed => '${from.name} → ${to.name}: matches the map.',
    WalkVerdict.viaOthers =>
      '${from.name} → ${to.name}: the map goes past ${via.map((n) => n.name).join(', ')}. '
          'If you walked straight here, add a direct link.',
    WalkVerdict.missing => '${from.name} → ${to.name}: the map had no way between these.',
    WalkVerdict.unlinkedFloors => '${from.name} → ${to.name}: these connect floors but were not linked.',
    WalkVerdict.linkedFloors => '${from.name} → ${to.name}: floor link matches the map.',
    WalkVerdict.floorChangeUnknown =>
      '${from.name} → ${to.name}: changed floor in between. Scan the lift or stairs you use.',
  };
}

/// Compares walking straight from [fromId] to [toId] (two scans in a row)
/// with the routes the map knows.
WalkFinding checkWalkStep(BuildingMap map, int fromId, int toId) {
  final from = map.node(fromId);
  final to = map.node(toId);

  if (from.floor != to.floor) {
    final vertical = from.type.isVertical && from.type == to.type;
    if (!vertical) return WalkFinding(WalkVerdict.floorChangeUnknown, from, to);
    final linked = map.edges.any(
      (e) => e.kind != EdgeKind.walk && ((e.from == fromId && e.to == toId) || (e.from == toId && e.to == fromId)),
    );
    return WalkFinding(linked ? WalkVerdict.linkedFloors : WalkVerdict.unlinkedFloors, from, to);
  }

  final route = bidirectionalDijkstra(map.graph, fromId, toId);
  if (route == null) return WalkFinding(WalkVerdict.missing, from, to);
  final via = [
    for (final id in route.nodes.skip(1).take(route.nodes.length - 2))
      if (map.node(id).markerId != null) map.node(id),
  ];
  return via.isEmpty
      ? WalkFinding(WalkVerdict.confirmed, from, to)
      : WalkFinding(WalkVerdict.viaOthers, from, to, via: via);
}

/// Marked places not reached in [visited], lowest floor first.
List<MapNode> notVisited(BuildingMap map, Set<int> visited) {
  final order = {for (final (i, f) in map.floors.indexed) f.level: i};
  return map.nodes.values.where((n) => n.markerId != null && !visited.contains(n.id)).toList()
    ..sort((a, b) => order[a.floor]!.compareTo(order[b.floor]!));
}
