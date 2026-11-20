import 'corridor_network.dart' show Pt;
import 'map_json.dart';

/// What an area of a floor's generated map is used as.
enum RegionKind {
  room,
  corridor,
  stairs,
  lift,

  /// Detected but not part of the building (a courtyard, a mistake).
  ignored;

  static RegionKind parse(String value, String context) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    throw MapFormatException('$context: unknown region kind "$value"');
  }

  String get label => switch (this) {
    room => 'Room',
    corridor => 'Corridor',
    stairs => 'Stairs',
    lift => 'Lift',
    ignored => 'Not used',
  };
}

/// One area of a floor's generated map: its outline, what it is, and for
/// corridors the walkable centrelines through it. Coordinates are drawing
/// pixels of the floor's blueprint.
class FloorRegion {
  const FloorRegion({required this.id, required this.kind, required this.outline, this.paths = const []});

  final String id;
  final RegionKind kind;

  /// Closed polygon; the first point is not repeated.
  final List<Pt> outline;
  final List<List<Pt>> paths;

  FloorRegion copyWith({RegionKind? kind, List<Pt>? outline, List<List<Pt>>? paths}) => FloorRegion(
    id: id,
    kind: kind ?? this.kind,
    outline: outline ?? this.outline,
    paths: paths ?? this.paths,
  );

  /// Centre of the outline (area-weighted), where a place's pin goes.
  Pt get centre {
    var a = 0.0, cx = 0.0, cy = 0.0;
    for (var i = 0; i < outline.length; i++) {
      final p = outline[i];
      final q = outline[(i + 1) % outline.length];
      final cross = p.x * q.y - q.x * p.y;
      a += cross;
      cx += (p.x + q.x) * cross;
      cy += (p.y + q.y) * cross;
    }
    if (a.abs() < 1e-9) {
      final n = outline.length;
      return (x: outline.fold(0.0, (s, p) => s + p.x) / n, y: outline.fold(0.0, (s, p) => s + p.y) / n);
    }
    return (x: cx / (3 * a), y: cy / (3 * a));
  }

  /// Whether [p] is inside the outline (even–odd rule).
  bool contains(Pt p) {
    var inside = false;
    for (var i = 0, j = outline.length - 1; i < outline.length; j = i++) {
      final a = outline[i], b = outline[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
    }
    return inside;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'points': [
      for (final p in outline) [_r(p.x), _r(p.y)],
    ],
    if (paths.isNotEmpty)
      'paths': [
        for (final path in paths)
          [
            for (final p in path) [_r(p.x), _r(p.y)],
          ],
      ],
  };

  static FloorRegion fromJson(Object? raw, String ctx) {
    final json = asObject(raw, ctx);
    final outline = _points(requireList(json, 'points', ctx), ctx);
    if (outline.length < 3) throw MapFormatException('$ctx: a region needs at least 3 points');
    final rawPaths = json['paths'];
    if (rawPaths != null && rawPaths is! List<Object?>) throw MapFormatException('$ctx: "paths" must be a list');
    return FloorRegion(
      id: requireString(json, 'id', ctx),
      kind: RegionKind.parse(requireString(json, 'kind', ctx), ctx),
      outline: List.unmodifiable(outline),
      paths: [
        for (final p in (rawPaths as List<Object?>?) ?? const <Object?>[])
          if (p is List<Object?>) List<Pt>.unmodifiable(_points(p, ctx)),
      ],
    );
  }

  static List<Pt> _points(List<Object?> raw, String ctx) => [
    for (final p in raw)
      if (p is List<Object?> && p.length == 2 && p[0] is num && p[1] is num)
        (x: (p[0]! as num).toDouble(), y: (p[1]! as num).toDouble())
      else
        throw MapFormatException('$ctx: each point must be [x, y]'),
  ];

  static double _r(double v) => (v * 10).roundToDouble() / 10;
}
