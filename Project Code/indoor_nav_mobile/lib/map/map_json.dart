import 'aruco_markers.dart';
import 'building_map.dart';
import 'corridor_network.dart';

/// Markers are DICT_4X4_250, which only decodes ids 0-249. A marker outside
/// that range could never be scanned, so it is rejected at load.
const int maxMarkerId = markerCount - 1;

/// Thrown when building.json is malformed. The message names the bad entry so
/// a hand edit can be fixed quickly.
class MapFormatException implements Exception {
  const MapFormatException(this.message);

  final String message;

  @override
  String toString() => 'MapFormatException: $message';
}

List<Floor> parseFloors(List<Object?> rawFloors) {
  if (rawFloors.isEmpty) throw const MapFormatException('map: "floors" must not be empty');
  final floors = <Floor>[];
  final seen = <int>{};
  for (final (i, raw) in rawFloors.indexed) {
    final ctx = 'floors[$i]';
    final json = asObject(raw, ctx);
    final level = requireInt(json, 'level', ctx);
    if (!seen.add(level)) throw MapFormatException('$ctx: duplicate floor level $level');
    final floor = Floor(
      level: level,
      name: requireString(json, 'name', ctx),
      image: requireString(json, 'image', ctx),
      width: requirePositive(json, 'width', ctx),
      height: requirePositive(json, 'height', ctx),
      metresPerPixel: optionalPositive(json, 'metresPerPixel', ctx),
    );
    floors.add(floor);
  }
  floors.sort((a, b) => a.level.compareTo(b.level));
  return floors;
}

MapNode parseNode(Object? raw, String ctx, Map<int, Floor> floorByLevel) {
  final json = asObject(raw, ctx);
  final id = requireInt(json, 'id', ctx);
  final nodeCtx = 'node $id';
  final level = requireInt(json, 'floor', nodeCtx);
  final floor = floorByLevel[level];
  if (floor == null) throw MapFormatException('$nodeCtx: floor $level is not listed in "floors"');

  final x = requireNumber(json, 'x', nodeCtx);
  final y = requireNumber(json, 'y', nodeCtx);
  if (x < 0 || x > floor.width || y < 0 || y > floor.height) {
    throw MapFormatException(
      '$nodeCtx: position ($x, $y) is outside the ${floor.width.toInt()}x${floor.height.toInt()} '
      'image of ${floor.name}',
    );
  }

  final marker = json['marker'];
  if (marker != null && (marker is! int || marker < 0 || marker > maxMarkerId)) {
    throw MapFormatException('$nodeCtx: "marker" must be a whole number from 0 to $maxMarkerId, or null');
  }

  final type = NodeType.parse(requireString(json, 'type', nodeCtx), nodeCtx);
  final rawLink = optionalString(json, 'link', nodeCtx);
  final link = (rawLink == null || rawLink.trim().isEmpty) ? null : rawLink.trim();
  if (link != null && !type.isVertical) {
    throw MapFormatException('$nodeCtx: only lifts and stairs can have a "link"');
  }

  return MapNode(
    id: id,
    name: requireString(json, 'name', nodeCtx),
    type: type,
    floor: level,
    x: x,
    y: y,
    markerId: marker as int?,
    link: link,
  );
}

/// An edge as written in the file. [weight] is null when it should be
/// worked out from the drawing.
class RawEdge {
  const RawEdge(this.from, this.to, this.weight);

  final int from;
  final int to;
  final double? weight;
}

List<RawEdge> parseEdges(List<Object?> rawEdges, Map<int, MapNode> nodes) {
  final edges = <RawEdge>[];
  final seen = <(int, int)>{};
  for (final (i, raw) in rawEdges.indexed) {
    final ctx = 'edges[$i]';
    final json = asObject(raw, ctx);
    final from = requireInt(json, 'from', ctx);
    final to = requireInt(json, 'to', ctx);
    final weight = optionalPositive(json, 'weight', ctx);
    for (final end in [from, to]) {
      if (!nodes.containsKey(end)) throw MapFormatException('$ctx: node $end does not exist');
    }
    if (from == to) throw MapFormatException('$ctx: an edge cannot connect node $from to itself');
    final key = from < to ? (from, to) : (to, from);
    if (!seen.add(key)) throw MapFormatException('$ctx: nodes $from and $to are already connected');
    edges.add(RawEdge(from, to, weight));
  }
  return edges;
}

Map<String, dynamic> asObject(Object? raw, String ctx) {
  if (raw is Map<String, dynamic>) return raw;
  throw MapFormatException('$ctx: expected an object');
}

List<Object?> requireList(Map<String, dynamic> json, String key, String ctx) {
  final value = json[key];
  if (value is List<Object?>) return value;
  throw MapFormatException('$ctx: "$key" must be a list');
}

String requireString(Map<String, dynamic> json, String key, String ctx) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw MapFormatException('$ctx: "$key" must be a non-empty string');
}

String? optionalString(Map<String, dynamic> json, String key, String ctx) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw MapFormatException('$ctx: "$key" must be a string');
}

int requireInt(Map<String, dynamic> json, String key, String ctx) {
  final value = json[key];
  if (value is int) return value;
  throw MapFormatException('$ctx: "$key" must be a whole number');
}

double requireNumber(Map<String, dynamic> json, String key, String ctx) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw MapFormatException('$ctx: "$key" must be a number');
}

double? optionalPositive(Map<String, dynamic> json, String key, String ctx) {
  if (json[key] == null) return null;
  return requirePositive(json, key, ctx);
}

double requirePositive(Map<String, dynamic> json, String key, String ctx) {
  final value = requireNumber(json, key, ctx);
  if (value > 0) return value;
  throw MapFormatException('$ctx: "$key" must be greater than 0');
}

/// Reads swiped corridors: `[{"floor": 0, "points": [[x, y], ...]}, ...]`.
/// Missing means none.
List<CorridorStroke> parseCorridors(Object? raw, Map<int, Floor> floorByLevel) {
  if (raw == null) return const [];
  if (raw is! List<Object?>) throw const MapFormatException('map: "corridors" must be a list');
  final strokes = <CorridorStroke>[];
  for (final (i, item) in raw.indexed) {
    final ctx = 'corridors[$i]';
    final json = asObject(item, ctx);
    final level = requireInt(json, 'floor', ctx);
    if (!floorByLevel.containsKey(level)) throw MapFormatException('$ctx: floor $level is not listed in "floors"');
    final points = <Pt>[];
    for (final p in requireList(json, 'points', ctx)) {
      if (p is! List<Object?> || p.length != 2 || p[0] is! num || p[1] is! num) {
        throw MapFormatException('$ctx: each point must be [x, y]');
      }
      points.add((x: (p[0]! as num).toDouble(), y: (p[1]! as num).toDouble()));
    }
    if (points.length >= 2) strokes.add(CorridorStroke(level, List.unmodifiable(points)));
  }
  return strokes;
}

List<Map<String, Object>> corridorsToJson(List<CorridorStroke> corridors) => [
  for (final c in corridors)
    {
      'floor': c.floor,
      'points': [
        for (final p in c.points) [_round(p.x), _round(p.y)],
      ],
    },
];

double _round(double v) => (v * 10).roundToDouble() / 10;
