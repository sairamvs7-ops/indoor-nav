import 'dart:math' as math;

/// A point on a floor drawing, in drawing pixels.
typedef Pt = ({double x, double y});

/// A corridor drawn by swiping along it on one floor.
class CorridorStroke {
  const CorridorStroke(this.floor, this.points);

  final int floor;
  final List<Pt> points;
}

/// The walkable network made from one floor's corridor strokes.
class CorridorNetwork {
  const CorridorNetwork(this.junctions, this.segments, this.attachments);

  /// Corners, crossings, corridor ends and the points where places join.
  final List<Pt> junctions;

  /// Walkable corridor pieces, as pairs of [junctions] indexes.
  final List<(int, int)> segments;

  /// Place id -> the junction where that place joins its nearest corridor.
  final Map<int, int> attachments;
}

/// Turns finger-drawn corridor strokes into a clean walkable network:
///
/// * each stroke is straightened into a few segments (wobble removed);
/// * points of different strokes closer than [snap] become one junction;
/// * a stroke that ends near another corridor joins it there;
/// * corridors that cross get a junction at the crossing;
/// * every place joins the nearest corridor at the closest point on it, which
///   stands in for its door.
///
/// [snap] is in drawing pixels; around 2% of the drawing's longer side works
/// well for finger drawing.
CorridorNetwork buildCorridorNetwork({
  required List<List<Pt>> strokes,
  required List<(int, Pt)> places,
  required double snap,
}) {
  final vertices = <Pt>[];

  int vertexAt(Pt p, double radius) {
    var best = -1;
    var bestDistance = radius;
    for (var i = 0; i < vertices.length; i++) {
      final d = _distance(vertices[i], p);
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    if (best >= 0) return best;
    vertices.add(p);
    return vertices.length - 1;
  }

  // 1. Straighten strokes and merge nearby points into shared vertices.
  final raw = <(int, int)>[];
  final seen = <(int, int)>{};
  void addSegment(int a, int b) {
    if (a == b) return;
    final key = a < b ? (a, b) : (b, a);
    if (seen.add(key)) raw.add(key);
  }

  for (final stroke in strokes) {
    if (stroke.length < 2) continue;
    final simple = simplifyStroke(stroke, snap / 3);
    int? previous;
    for (final p in simple) {
      final v = vertexAt(p, snap);
      if (previous != null) addSegment(previous, v);
      previous = v;
    }
  }

  // 2. Work out where segments need splitting: dangling ends that stop near
  // another corridor, and crossings.
  final splits = {for (var i = 0; i < raw.length; i++) i: <(double, int)>[]};
  final degree = <int, int>{};
  for (final (a, b) in raw) {
    degree[a] = (degree[a] ?? 0) + 1;
    degree[b] = (degree[b] ?? 0) + 1;
  }
  final extra = <(int, int)>[];
  for (final entry in degree.entries) {
    if (entry.value != 1) continue;
    final v = entry.key;
    var bestSegment = -1;
    var bestT = 0.0;
    var bestDistance = snap;
    for (var i = 0; i < raw.length; i++) {
      final (a, b) = raw[i];
      if (a == v || b == v) continue;
      final (t, d) = _project(vertices[v], vertices[a], vertices[b]);
      if (d < bestDistance) {
        bestSegment = i;
        bestT = t;
        bestDistance = d;
      }
    }
    if (bestSegment < 0) continue;
    final (a, b) = raw[bestSegment];
    final w = vertexAt(_lerp(vertices[a], vertices[b], bestT), snap * 0.3);
    if (w != a && w != b) splits[bestSegment]!.add((bestT, w));
    extra.add((v, w));
  }
  for (var i = 0; i < raw.length; i++) {
    for (var j = i + 1; j < raw.length; j++) {
      final (a, b) = raw[i];
      final (c, d) = raw[j];
      if (a == c || a == d || b == c || b == d) continue;
      final hit = _intersect(vertices[a], vertices[b], vertices[c], vertices[d]);
      if (hit == null) continue;
      final (t, u) = hit;
      final w = vertexAt(_lerp(vertices[a], vertices[b], t), snap * 0.1);
      if (w != a && w != b) splits[i]!.add((t, w));
      if (w != c && w != d) splits[j]!.add((u, w));
    }
  }

  // 3. Rebuild the segments with the splits in place.
  final segments = <(int, int)>[];
  final segmentSeen = <(int, int)>{};
  void keep(int a, int b) {
    if (a == b) return;
    final key = a < b ? (a, b) : (b, a);
    if (segmentSeen.add(key)) segments.add(key);
  }

  for (var i = 0; i < raw.length; i++) {
    final (a, b) = raw[i];
    final cuts = splits[i]!..sort((x, y) => x.$1.compareTo(y.$1));
    var from = a;
    for (final (_, w) in cuts) {
      keep(from, w);
      from = w;
    }
    keep(from, b);
  }
  for (final (a, b) in extra) {
    keep(a, b);
  }

  // 4. Join every place to the closest point on the nearest corridor.
  final attachments = <int, int>{};
  for (final (id, p) in places) {
    var bestSegment = -1;
    var bestT = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final (t, d) = _project(p, vertices[a], vertices[b]);
      if (d < bestDistance) {
        bestSegment = i;
        bestT = t;
        bestDistance = d;
      }
    }
    if (bestSegment < 0) break; // no corridors on this floor
    final (a, b) = segments[bestSegment];
    final q = _lerp(vertices[a], vertices[b], bestT);
    final w = vertexAt(q, snap * 0.3);
    if (w != a && w != b) {
      segments[bestSegment] = (a, w);
      segments.add((w, b));
    }
    attachments[id] = w;
  }

  return CorridorNetwork(List.unmodifiable(vertices), List.unmodifiable(segments), Map.unmodifiable(attachments));
}

/// Removes finger wobble: keeps only the points needed to stay within
/// [tolerance] pixels of the stroke (Ramer–Douglas–Peucker).
List<Pt> simplifyStroke(List<Pt> points, double tolerance) {
  if (points.length <= 2) return List.of(points);
  var index = 0;
  var maxDistance = 0.0;
  for (var i = 1; i < points.length - 1; i++) {
    final (_, d) = _project(points[i], points.first, points.last);
    if (d > maxDistance) {
      index = i;
      maxDistance = d;
    }
  }
  if (maxDistance <= tolerance) return [points.first, points.last];
  final left = simplifyStroke(points.sublist(0, index + 1), tolerance);
  final right = simplifyStroke(points.sublist(index), tolerance);
  return [...left, ...right.skip(1)];
}

double _distance(Pt a, Pt b) => math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

Pt _lerp(Pt a, Pt b, double t) => (x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t);

/// Where [p] lands on segment [a]-[b]: (position 0..1 along it, distance).
(double, double) _project(Pt p, Pt a, Pt b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return (0, _distance(p, a));
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(0.0, 1.0);
  return (t, _distance(p, _lerp(a, b, t)));
}

/// Where segments a-b and c-d cross, as positions along each, or null if
/// they don't cross (touching at the very ends doesn't count).
(double, double)? _intersect(Pt a, Pt b, Pt c, Pt d) {
  final rX = b.x - a.x;
  final rY = b.y - a.y;
  final sX = d.x - c.x;
  final sY = d.y - c.y;
  final denominator = rX * sY - rY * sX;
  if (denominator.abs() < 1e-9) return null; // parallel
  final t = ((c.x - a.x) * sY - (c.y - a.y) * sX) / denominator;
  final u = ((c.x - a.x) * rY - (c.y - a.y) * rX) / denominator;
  const edge = 1e-6;
  if (t <= edge || t >= 1 - edge || u <= edge || u >= 1 - edge) return null;
  return (t, u);
}
