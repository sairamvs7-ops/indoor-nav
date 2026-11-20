import '../map/building_map.dart';

enum IssueLevel {
  /// Navigation will give wrong or no routes until this is fixed.
  problem,

  /// Works, but probably not what was intended.
  warning,
}

class BuildingIssue {
  const BuildingIssue(this.level, this.message, {this.nodeId, this.floorLevel});

  final IssueLevel level;
  final String message;

  /// The place or floor the issue is about, so the editor can jump to it.
  final int? nodeId;
  final int? floorLevel;
}

/// Checks a building for setup mistakes that the file format allows but that
/// would make navigation fail: places you can't reach, lifts that go nowhere,
/// floors with nothing on them.
List<BuildingIssue> checkBuilding(BuildingMap map) {
  final issues = <BuildingIssue>[];

  for (final floor in map.floors) {
    if (map.nodesOnFloor(floor.level).every((n) => n.automatic)) {
      issues.add(
        BuildingIssue(IssueLevel.warning, '${floor.name} has no places yet.', floorLevel: floor.level),
      );
    }
  }

  if (map.nodes.values.every((n) => n.automatic)) {
    issues.add(const BuildingIssue(IssueLevel.problem, 'Add at least one place to navigate to.'));
    return issues;
  }

  // Places that can't be reached from the biggest connected group.
  final groups = connectedGroups(map);
  if (groups.length > 1) {
    final main = groups.first;
    final mainName = main.map(map.node).firstWhere((n) => !n.automatic, orElse: () => map.node(main.first)).name;
    for (final group in groups.skip(1)) {
      for (final id in group) {
        final node = map.node(id);
        if (node.automatic) continue; // a stray corridor is reported via its places
        issues.add(
          BuildingIssue(
            IssueLevel.problem,
            '${node.name} (${map.floor(node.floor).name}) is not connected to $mainName. '
            'Swipe a corridor to it, or move it next to one.',
            nodeId: id,
            floorLevel: node.floor,
          ),
        );
      }
    }
  }

  if (map.floors.length > 1) {
    final linked = <int>{for (final e in map.edges) if (e.kind != EdgeKind.walk) ...[e.from, e.to]};
    for (final node in map.nodes.values) {
      if (node.type.isVertical && !linked.contains(node.id)) {
        issues.add(
          BuildingIssue(
            IssueLevel.warning,
            '${node.name} is not linked to any other floor. Give it the same link name as the matching '
            '${node.type.label.toLowerCase()} on the next floor.',
            nodeId: node.id,
            floorLevel: node.floor,
          ),
        );
      }
    }
  }

  if (map.markerIds.isEmpty) {
    issues.add(const BuildingIssue(IssueLevel.problem, 'No place has a marker, so nobody can find where they are.'));
  }

  return issues;
}

/// Groups of node ids that can reach each other, the group with the most
/// places first.
List<List<int>> connectedGroups(BuildingMap map) {
  final graph = map.graph;
  final seen = <int>{};
  final groups = <List<int>>[];
  for (final start in map.nodes.keys) {
    if (seen.contains(start)) continue;
    final group = <int>[];
    final stack = [start];
    seen.add(start);
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      group.add(id);
      for (final n in graph[id]!) {
        if (seen.add(n.node)) stack.add(n.node);
      }
    }
    groups.add(group);
  }
  // Most places first: a stray corridor with many junctions but no places
  // must not count as the main part of the building.
  int places(List<int> group) => group.where((id) => !map.node(id).automatic).length;
  groups.sort((a, b) => places(b).compareTo(places(a)));
  return groups;
}
