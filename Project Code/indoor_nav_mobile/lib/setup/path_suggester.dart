/// A place on one floor, for suggesting paths between places.
class PathPoint {
  const PathPoint(this.id, this.x, this.y);

  final int id;
  final double x;
  final double y;
}

/// Suggests walkable paths between places on one floor.
///
/// Uses the relative neighbourhood graph: two places are linked unless some
/// third place is closer to both of them than they are to each other. This
/// links each place to its natural neighbours along a corridor without
/// skipping over places in between, and always keeps every place reachable.
/// It can't see walls, so the person setting up the building reviews each
/// suggestion before it is used.
///
/// Pairs already in [existing] (as (smaller id, larger id)) are not suggested.
/// Returns pairs as (smaller id, larger id), shortest first.
List<(int, int)> suggestPaths(List<PathPoint> points, {Set<(int, int)> existing = const {}}) {
  double distance2(PathPoint a, PathPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  final suggestions = <(int, int, double)>[];
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final a = points[i];
      final b = points[j];
      final key = a.id < b.id ? (a.id, b.id) : (b.id, a.id);
      if (existing.contains(key)) continue;
      final ab = distance2(a, b);
      var blocked = false;
      for (var k = 0; k < points.length && !blocked; k++) {
        if (k == i || k == j) continue;
        final c = points[k];
        // c is strictly closer to both ends than they are to each other.
        if (distance2(a, c) < ab && distance2(b, c) < ab) blocked = true;
      }
      if (!blocked) suggestions.add((key.$1, key.$2, ab));
    }
  }
  suggestions.sort((x, y) => x.$3.compareTo(y.$3));
  return [for (final s in suggestions) (s.$1, s.$2)];
}
