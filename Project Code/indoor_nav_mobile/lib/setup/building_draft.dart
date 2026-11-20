import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../map/aruco_markers.dart';
import '../map/building_map.dart';
import '../map/corridor_network.dart' show simplifyStroke;
import '../map/map_json.dart' show corridorsToJson;
import '../mapgen/floor_map_generator.dart' show corridorCentrelines;
import 'path_suggester.dart';

class DraftFloor {
  DraftFloor({
    required this.level,
    required this.name,
    required this.image,
    required this.width,
    required this.height,
    this.metresPerPixel,
    List<FloorRegion>? regions,
  }) : regions = regions ?? [];

  final int level;
  String name;
  String image;
  double width;
  double height;
  double? metresPerPixel;

  /// The generated map of this floor (rooms, corridors, stairs, lifts).
  final List<FloorRegion> regions;

  FloorRegion? region(String id) {
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }
}

class DraftNode {
  DraftNode({
    required this.id,
    required this.name,
    required this.type,
    required this.floor,
    required this.x,
    required this.y,
    this.marker,
    this.link,
    this.region,
  });

  final int id;
  String name;
  NodeType type;
  final int floor;
  double x;
  double y;
  int? marker;
  String? link;

  /// The generated-map region this place is, if any.
  String? region;
}

/// A building being set up: floors, places and paths that can be changed one
/// tap at a time. Unlike [BuildingMap] it may be incomplete (no floors yet,
/// places not connected). Every change is saved through [save] shortly after
/// it is made; call [flush] before leaving the editor.
class BuildingDraft extends ChangeNotifier {
  BuildingDraft.fromJson(Map<String, dynamic> json, {required this.save, this.saveDelay = const Duration(milliseconds: 400)})
    : id = json['id'] as String?,
      name = (json['building'] as String?) ?? 'Untitled building' {
    for (final raw in (json['floors'] as List<Object?>? ?? const [])) {
      final f = raw! as Map<String, dynamic>;
      floors.add(
        DraftFloor(
          level: f['level'] as int,
          name: f['name'] as String,
          image: f['image'] as String,
          width: (f['width'] as num).toDouble(),
          height: (f['height'] as num).toDouble(),
          metresPerPixel: (f['metresPerPixel'] as num?)?.toDouble(),
          regions: [
            for (final (i, r) in (f['regions'] as List<Object?>? ?? const []).indexed)
              FloorRegion.fromJson(r, 'floor ${f['level']} region $i'),
          ],
        ),
      );
    }
    floors.sort((a, b) => a.level.compareTo(b.level));
    for (final raw in (json['nodes'] as List<Object?>? ?? const [])) {
      final n = raw! as Map<String, dynamic>;
      final node = DraftNode(
        id: n['id'] as int,
        name: n['name'] as String,
        type: NodeType.parse(n['type'] as String, 'node ${n['id']}'),
        floor: n['floor'] as int,
        x: (n['x'] as num).toDouble(),
        y: (n['y'] as num).toDouble(),
        marker: n['marker'] as int?,
        link: n['link'] as String?,
        region: n['region'] as String?,
      );
      nodes[node.id] = node;
    }
    for (final raw in (json['edges'] as List<Object?>? ?? const [])) {
      final e = raw! as Map<String, dynamic>;
      _edges[_key(e['from'] as int, e['to'] as int)] = (e['weight'] as num?)?.toDouble();
    }
    for (final raw in (json['corridors'] as List<Object?>? ?? const [])) {
      final c = raw! as Map<String, dynamic>;
      corridors.add(
        CorridorStroke(c['floor'] as int, [
          for (final p in (c['points'] as List<Object?>).cast<List<Object?>>())
            (x: (p[0]! as num).toDouble(), y: (p[1]! as num).toDouble()),
        ]),
      );
    }
  }

  final String? id;
  String name;
  final List<DraftFloor> floors = [];
  final Map<int, DraftNode> nodes = {};

  /// Corridors swiped on the blueprints, in the order they were drawn.
  final List<CorridorStroke> corridors = [];

  /// Walkable paths as (smaller id, larger id), with a hand-set weight if the
  /// file had one (the original sample building does).
  final Map<(int, int), double?> _edges = {};

  final Future<void> Function(Map<String, dynamic> json) save;
  final Duration saveDelay;
  Timer? _saveTimer;
  bool _disposed = false;

  static (int, int) _key(int a, int b) => a < b ? (a, b) : (b, a);

  Iterable<(int, int)> get edges => _edges.keys;

  DraftFloor floor(int level) => floors.firstWhere((f) => f.level == level);

  Iterable<DraftNode> nodesOn(int level) => nodes.values.where((n) => n.floor == level);

  Iterable<(int, int)> edgesOn(int level) =>
      _edges.keys.where((e) => nodes[e.$1]!.floor == level && nodes[e.$2]!.floor == level);

  bool isConnected(int a, int b) => _edges.containsKey(_key(a, b));

  Set<int> get usedMarkers => {for (final n in nodes.values) if (n.marker != null) n.marker!};

  /// The lowest marker number not in use, starting from 1 (0 is used last so
  /// printed numbers start where people expect). Null when all are taken.
  int? nextFreeMarker() {
    final used = usedMarkers;
    for (var id = 1; id < markerCount; id++) {
      if (!used.contains(id)) return id;
    }
    return used.contains(0) ? null : 0;
  }

  /// Link names already given to lifts or stairs of [type], for suggestions.
  List<String> linkNames(NodeType type) {
    final names = <String>{for (final n in nodes.values) if (n.type == type && n.link != null) n.link!};
    return names.toList()..sort();
  }

  /// Corridors on [level], with their index in [corridors].
  Iterable<(int, CorridorStroke)> corridorsOn(int level) =>
      corridors.indexed.where((entry) => entry.$2.floor == level);

  /// Adds a corridor swiped along [points] (drawing pixels). Finger wobble is
  /// smoothed out; very short swipes are ignored. Returns true if added.
  bool addCorridor(int level, List<Pt> points) {
    final f = floor(level);
    final longest = math.max(f.width, f.height);
    final clamped = [
      for (final p in points) (x: p.x.clamp(0, f.width).toDouble(), y: p.y.clamp(0, f.height).toDouble()),
    ];
    final simple = simplifyStroke(clamped, longest * 0.004);
    final length = [
      for (var i = 0; i + 1 < simple.length; i++)
        math.sqrt(math.pow(simple[i + 1].x - simple[i].x, 2) + math.pow(simple[i + 1].y - simple[i].y, 2)),
    ].fold<double>(0, (a, b) => a + b);
    if (simple.length < 2 || length < longest * 0.02) return false;
    corridors.add(CorridorStroke(level, List.unmodifiable(simple)));
    _changed();
    return true;
  }

  void removeCorridor(int index) {
    corridors.removeAt(index);
    _changed();
  }

  /// Removes the corridor most recently drawn on [level]. Returns false if
  /// there is none.
  bool undoCorridor(int level) {
    final last = corridors.lastIndexWhere((c) => c.floor == level);
    if (last < 0) return false;
    removeCorridor(last);
    return true;
  }

  /// The corridor on [level] passing closest to [point], within [radius]
  /// pixels, as an index into [corridors].
  int? corridorNear(int level, Pt point, double radius) {
    int? best;
    var bestDistance = radius;
    for (final (i, c) in corridorsOn(level)) {
      for (var k = 0; k + 1 < c.points.length; k++) {
        final d = _segmentDistance(point, c.points[k], c.points[k + 1]);
        if (d < bestDistance) {
          best = i;
          bestDistance = d;
        }
      }
    }
    return best;
  }

  static double _segmentDistance(Pt p, Pt a, Pt b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2).clamp(0.0, 1.0);
    final qx = a.x + dx * t - p.x;
    final qy = a.y + dy * t - p.y;
    return math.sqrt(qx * qx + qy * qy);
  }

  // --- Generated floor maps ----------------------------------------------

  /// The place that uses region [regionId], if any.
  DraftNode? placeFor(String regionId) {
    for (final n in nodes.values) {
      if (n.region == regionId) return n;
    }
    return null;
  }

  /// Replaces a floor's generated map, e.g. after (re)generating it from the
  /// blueprint. Places keep working: each is linked to the new region it
  /// sits in, and lifts and stairs mark their region as such.
  void setGeneratedMap(int level, List<FloorRegion> regions) {
    final f = floor(level);
    f.regions
      ..clear()
      ..addAll(regions);
    for (final n in nodesOn(level)) {
      n.region = null;
      for (final r in f.regions) {
        if (r.contains((x: n.x, y: n.y))) {
          n.region = r.id;
          final kind = switch (n.type) {
            NodeType.stairs => RegionKind.stairs,
            NodeType.lift => RegionKind.lift,
            _ => r.kind == RegionKind.corridor ? null : RegionKind.room,
          };
          if (kind != null && kind != r.kind) _setKind(f, r.id, kind);
          break;
        }
      }
    }
    _changed();
  }

  /// Sets what region [regionId] on [level] is. Corridors get walkable
  /// centrelines; a region that stops being a place loses its place.
  void setRegionKind(int level, String regionId, RegionKind kind) {
    _setKind(floor(level), regionId, kind);
    if (kind == RegionKind.corridor || kind == RegionKind.ignored) {
      final place = placeFor(regionId);
      if (place != null) deleteNode(place.id);
    }
    _changed();
  }

  void _setKind(DraftFloor f, String regionId, RegionKind kind) {
    final index = f.regions.indexWhere((r) => r.id == regionId);
    if (index < 0) return;
    final region = f.regions[index];
    f.regions[index] = region.copyWith(
      kind: kind,
      paths: kind == RegionKind.corridor
          ? corridorCentrelines(region.outline, longest: math.max(f.width, f.height))
          : const [],
    );
  }

  /// Makes region [regionId] a named place (room, stairs, lift...), creating
  /// its place at the region's centre or updating the existing one.
  /// Returns the place's id.
  int assignPlace(
    int level,
    String regionId, {
    required String name,
    required NodeType type,
    bool withMarker = true,
    int? marker,
    String? link,
  }) {
    final region = floor(level).region(regionId)!;
    final kind = switch (type) {
      NodeType.stairs => RegionKind.stairs,
      NodeType.lift => RegionKind.lift,
      _ => RegionKind.room,
    };
    _setKind(floor(level), regionId, kind);
    final existing = placeFor(regionId);
    if (existing != null) {
      updateNode(
        existing.id,
        name: name,
        type: type,
        link: link ?? '',
        clearMarker: !withMarker,
        marker: withMarker ? (marker ?? existing.marker ?? nextFreeMarker()) : null,
      );
      return existing.id;
    }
    final c = region.centre;
    final id = addNode(name: name, type: type, floor: level, x: c.x, y: c.y, withMarker: withMarker, link: link);
    if (marker != null && withMarker) updateNode(id, marker: marker);
    nodes[id]!.region = regionId;
    _changed();
    return id;
  }

  /// Adds a region traced by hand (tapping its corners), for areas the
  /// generator missed, like hatched stairwells. Returns its id.
  String addRegion(int level, List<Pt> outline, {RegionKind kind = RegionKind.room}) {
    final f = floor(level);
    var n = f.regions.length + 1;
    while (f.region('t$n') != null) {
      n++;
    }
    final id = 't$n';
    f.regions.add(FloorRegion(id: id, kind: RegionKind.room, outline: List.unmodifiable(outline)));
    if (kind != RegionKind.room) _setKind(f, id, kind);
    _changed();
    return id;
  }

  void removeRegion(int level, String regionId) {
    final place = placeFor(regionId);
    if (place != null) place.region = null;
    floor(level).regions.removeWhere((r) => r.id == regionId);
    _changed();
  }

  /// The region on [level] under [point], smallest first (a stairwell drawn
  /// inside a corridor wins over the corridor).
  FloorRegion? regionAt(int level, Pt point, {bool includeIgnored = true}) {
    FloorRegion? best;
    var bestArea = double.infinity;
    for (final r in floor(level).regions) {
      if (!includeIgnored && r.kind == RegionKind.ignored) continue;
      if (!r.contains(point)) continue;
      final area = _area(r.outline);
      if (area < bestArea) {
        best = r;
        bestArea = area;
      }
    }
    return best;
  }

  static double _area(List<Pt> o) {
    var a = 0.0;
    for (var i = 0; i < o.length; i++) {
      final p = o[i], q = o[(i + 1) % o.length];
      a += p.x * q.y - q.x * p.y;
    }
    return a.abs() / 2;
  }

  void rename(String value) {
    name = value.trim().isEmpty ? name : value.trim();
    _changed();
  }

  /// Adds a floor above the current top floor and returns its level.
  int addFloor({required String name, required String image, required double width, required double height}) {
    final level = floors.isEmpty ? 0 : floors.map((f) => f.level).reduce(math.max) + 1;
    floors.add(DraftFloor(level: level, name: name, image: image, width: width, height: height));
    _changed();
    return level;
  }

  void renameFloor(int level, String value) {
    if (value.trim().isEmpty) return;
    floor(level).name = value.trim();
    _changed();
  }

  /// Sets the real-world scale from two points on the drawing that are
  /// [metres] apart.
  void calibrateFloor(int level, {required double pixels, required double metres}) {
    if (pixels <= 0 || metres <= 0) return;
    floor(level).metresPerPixel = metres / pixels;
    _changed();
  }

  /// Swaps a floor's drawing, moving its places so they keep their relative
  /// position on the new drawing.
  void replaceFloorImage(int level, {required String image, required double width, required double height}) {
    final f = floor(level);
    final sx = width / f.width;
    final sy = height / f.height;
    for (final n in nodesOn(level)) {
      n.x *= sx;
      n.y *= sy;
    }
    for (var i = 0; i < corridors.length; i++) {
      final c = corridors[i];
      if (c.floor != level) continue;
      corridors[i] = CorridorStroke(level, [for (final p in c.points) (x: p.x * sx, y: p.y * sy)]);
    }
    Pt scaled(Pt p) => (x: p.x * sx, y: p.y * sy);
    for (var i = 0; i < f.regions.length; i++) {
      final r = f.regions[i];
      f.regions[i] = r.copyWith(
        outline: [for (final p in r.outline) scaled(p)],
        paths: [
          for (final path in r.paths) [for (final p in path) scaled(p)],
        ],
      );
    }
    f
      ..image = image
      ..width = width
      ..height = height
      ..metresPerPixel = f.metresPerPixel == null ? null : f.metresPerPixel! / sx;
    _changed();
  }

  void removeFloor(int level) {
    final gone = nodesOn(level).map((n) => n.id).toSet();
    _edges.removeWhere((e, _) => gone.contains(e.$1) || gone.contains(e.$2));
    nodes.removeWhere((id, _) => gone.contains(id));
    corridors.removeWhere((c) => c.floor == level);
    floors.removeWhere((f) => f.level == level);
    _changed();
  }

  /// Adds a place and returns its id. Places get the next free marker unless
  /// they are corridor points, which are only there to shape routes.
  int addNode({
    required String name,
    required NodeType type,
    required int floor,
    required double x,
    required double y,
    bool withMarker = true,
    String? link,
  }) {
    final id = nodes.isEmpty ? 1 : nodes.keys.reduce(math.max) + 1;
    final f = this.floor(floor);
    nodes[id] = DraftNode(
      id: id,
      name: name.trim().isEmpty ? '${type.label} $id' : name.trim(),
      type: type,
      floor: floor,
      x: x.clamp(0, f.width).toDouble(),
      y: y.clamp(0, f.height).toDouble(),
      marker: withMarker && type != NodeType.corridor ? nextFreeMarker() : null,
      link: type.isVertical ? _cleanLink(link) : null,
    );
    _changed();
    return id;
  }

  /// Changes a place's details. A marker already used elsewhere is swapped:
  /// the other place gets this place's old marker.
  void updateNode(int id, {String? name, NodeType? type, int? marker, bool clearMarker = false, String? link}) {
    final node = nodes[id]!;
    if (name != null && name.trim().isNotEmpty) node.name = name.trim();
    if (type != null) node.type = type;
    if (clearMarker) {
      node.marker = null;
    } else if (marker != null && marker != node.marker) {
      for (final other in nodes.values) {
        if (other.id != id && other.marker == marker) other.marker = node.marker;
      }
      node.marker = marker;
    }
    node.link = node.type.isVertical ? (link == null ? node.link : _cleanLink(link)) : null;
    _changed();
  }

  void moveNode(int id, double x, double y) {
    final node = nodes[id]!;
    final f = floor(node.floor);
    node
      ..x = x.clamp(0, f.width).toDouble()
      ..y = y.clamp(0, f.height).toDouble();
    _changed();
  }

  void deleteNode(int id) {
    nodes.remove(id);
    _edges.removeWhere((e, _) => e.$1 == id || e.$2 == id);
    _changed();
  }

  /// Connects two places on the same floor, or removes the path if they are
  /// already connected. Returns true if they are connected afterwards.
  bool togglePath(int a, int b) {
    if (a == b) return false;
    final key = _key(a, b);
    final connected = !_edges.containsKey(key);
    if (connected) {
      _edges[key] = null;
    } else {
      _edges.remove(key);
    }
    _changed();
    return connected;
  }

  /// Paths the app would suggest on [level], not yet added.
  List<(int, int)> suggestionsFor(int level) => suggestPaths(
    [for (final n in nodesOn(level)) PathPoint(n.id, n.x, n.y)],
    existing: _edges.keys.toSet(),
  );

  void addPaths(Iterable<(int, int)> pairs) {
    for (final (a, b) in pairs) {
      if (a != b) _edges.putIfAbsent(_key(a, b), () => null);
    }
    _changed();
  }

  Map<String, dynamic> toJson() => {
    'format': currentMapFormat,
    'id': ?id,
    'building': name,
    'floors': [
      for (final f in floors)
        {
          'level': f.level,
          'name': f.name,
          'image': f.image,
          'width': f.width,
          'height': f.height,
          'metresPerPixel': ?f.metresPerPixel,
          if (f.regions.isNotEmpty) 'regions': [for (final r in f.regions) r.toJson()],
        },
    ],
    'nodes': [
      for (final n in nodes.values)
        {
          'id': n.id,
          'name': n.name,
          'type': n.type.name,
          'floor': n.floor,
          'x': n.x,
          'y': n.y,
          'marker': n.marker,
          'link': ?n.link,
          'region': ?n.region,
        },
    ],
    'edges': [
      for (final e in _edges.entries) {'from': e.key.$1, 'to': e.key.$2, 'weight': ?e.value},
    ],
    'corridors': corridorsToJson(corridors),
  };

  /// The building as a map ready for navigation, or the reason it isn't one.
  (BuildingMap?, String?) tryBuild() {
    try {
      return (BuildingMap.fromJson(toJson()), null);
    } on MapFormatException catch (e) {
      return (null, e.message);
    }
  }

  /// Saves any change still waiting for its save delay.
  Future<void> flush() async {
    final pending = _saveTimer?.isActive ?? false;
    _saveTimer?.cancel();
    if (pending) await save(toJson());
  }

  static String? _cleanLink(String? link) => (link == null || link.trim().isEmpty) ? null : link.trim();

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(save(toJson())));
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }
}
