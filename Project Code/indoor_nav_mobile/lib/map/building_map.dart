import 'dart:math' as math;

import 'map_json.dart';

export 'map_json.dart' show MapFormatException;

/// The building file format written by this version of the app. Version 1 is
/// the original hand-written building.json; it still loads unchanged.
const int currentMapFormat = 2;

/// When a floor has no scale set, assume its drawing spans this many metres
/// along its longer side. Only affects how routes compare, never what is drawn.
const double defaultFloorSpanMetres = 60;

/// Cost of climbing or descending one floor by stairs, in metres of walking.
const double stairsCostPerFloor = 15;

/// Cost of using a lift: waiting for it, plus a little per floor travelled.
const double liftBaseCost = 20;
const double liftCostPerFloor = 3;

/// What kind of place a node is. Drives icons and how directions are worded.
enum NodeType {
  room,
  washroom,
  lift,
  stairs,
  entry,
  landmark,
  corridor;

  static NodeType parse(String value, String context) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    final allowed = values.map((t) => t.name).join(', ');
    throw MapFormatException('$context: unknown type "$value" (use one of: $allowed)');
  }

  /// Lifts and stairs connect floors.
  bool get isVertical => this == lift || this == stairs;

  String get label => switch (this) {
    room => 'Room',
    washroom => 'Washroom',
    lift => 'Lift',
    stairs => 'Stairs',
    entry => 'Entrance',
    landmark => 'Landmark',
    corridor => 'Corridor point',
  };
}

/// How a walkable connection is travelled.
enum EdgeKind { walk, stairs, lift }

/// Which routes the user is willing to take.
enum RoutePreference {
  /// Lowest total cost, using stairs and lifts freely.
  fastest,

  /// No stairs: for wheelchairs, prams and luggage.
  stepFree,

  /// No lifts.
  avoidLifts;

  String get label => switch (this) {
    fastest => 'Fastest',
    stepFree => 'Step-free',
    avoidLifts => 'Avoid lifts',
  };

  bool allows(EdgeKind kind) => switch (this) {
    fastest => true,
    stepFree => kind != EdgeKind.stairs,
    avoidLifts => kind != EdgeKind.lift,
  };
}

/// One floor and the drawing it is shown on. Node coordinates are pixels on
/// [image], so [width] and [height] must match that file.
class Floor {
  const Floor({
    required this.level,
    required this.name,
    required this.image,
    required this.width,
    required this.height,
    this.metresPerPixel,
  });

  final int level;
  final String name;

  /// The drawing: an asset path for the bundled sample, otherwise a file name
  /// inside the building's folder.
  final String image;
  final double width;
  final double height;

  /// Real-world scale of the drawing, set by calibrating two points. Null
  /// means not calibrated, and [defaultFloorSpanMetres] is assumed.
  final double? metresPerPixel;

  double get effectiveMetresPerPixel => metresPerPixel ?? defaultFloorSpanMetres / math.max(width, height);
}

/// A place you can navigate to or from. [markerId] is the ArUco marker stuck
/// at this spot, or null when the spot has no marker (it can still be routed
/// through). Lifts and stairs with the same [link] on different floors are the
/// same lift shaft or staircase, and are connected automatically.
class MapNode {
  const MapNode({
    required this.id,
    required this.name,
    required this.type,
    required this.floor,
    required this.x,
    required this.y,
    this.markerId,
    this.link,
  });

  final int id;
  final String name;
  final NodeType type;
  final int floor;
  final double x;
  final double y;
  final int? markerId;
  final String? link;
}

/// A walkable connection between two nodes. Edges are two-way.
class MapEdge {
  const MapEdge(this.from, this.to, this.weight, {this.kind = EdgeKind.walk, this.explicitWeight, this.automatic = false});

  final int from;
  final int to;

  /// The cost used for routing, in metres of walking (or the hand-set weight).
  final double weight;
  final EdgeKind kind;

  /// The weight written in the file, if any. Null means it was computed.
  final double? explicitWeight;

  /// True for lift/stairs links made from matching [MapNode.link] names.
  /// These are never written back to the file.
  final bool automatic;
}

class Neighbor {
  const Neighbor(this.node, this.weight);

  final int node;
  final double weight;
}

/// Undirected adjacency list: node id -> reachable neighbours.
typedef Graph = Map<int, List<Neighbor>>;

/// The whole building: floors, nodes and edges, validated and indexed.
/// Build it with [BuildingMap.fromJson]; every collection is unmodifiable.
class BuildingMap {
  BuildingMap._({
    required this.id,
    required this.name,
    required this.floors,
    required this.nodes,
    required this.edges,
    required Map<int, int> nodeIdByMarker,
    required Map<int, Floor> floorByLevel,
  }) : _nodeIdByMarker = nodeIdByMarker,
       _floorByLevel = floorByLevel;

  /// Throws [MapFormatException] with a message naming the bad entry.
  factory BuildingMap.fromJson(Map<String, dynamic> json) {
    final format = json['format'];
    if (format != null && (format is! int || format < 1 || format > currentMapFormat)) {
      throw MapFormatException(
        'map: "format" $format is not supported (this app reads formats 1 to $currentMapFormat). '
        'Update the app to open this building.',
      );
    }
    final id = optionalString(json, 'id', 'map');
    final name = optionalString(json, 'building', 'map') ?? 'Building';
    final floors = parseFloors(requireList(json, 'floors', 'map'));
    final floorByLevel = {for (final f in floors) f.level: f};
    final floorIndex = {for (final (i, f) in floors.indexed) f.level: i};

    final nodes = <int, MapNode>{};
    final nodeIdByMarker = <int, int>{};
    for (final (i, raw) in requireList(json, 'nodes', 'map').indexed) {
      final node = parseNode(raw, 'nodes[$i]', floorByLevel);
      if (nodes.containsKey(node.id)) {
        throw MapFormatException('nodes[$i]: duplicate node id ${node.id}');
      }
      final marker = node.markerId;
      if (marker != null) {
        final owner = nodeIdByMarker[marker];
        if (owner != null) {
          throw MapFormatException(
            '${nodes[owner]!.name} and ${node.name} both use marker $marker. Each marker can only be in one place.',
          );
        }
        nodeIdByMarker[marker] = node.id;
      }
      nodes[node.id] = node;
    }

    double walkCost(MapNode a, MapNode b) {
      final floor = floorByLevel[a.floor]!;
      final pixels = math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
      // Two nodes drawn on the same spot still cost something to walk between.
      return math.max(pixels * floor.effectiveMetresPerPixel, 0.5);
    }

    double verticalCost(EdgeKind kind, MapNode a, MapNode b) {
      final floorsApart = (floorIndex[a.floor]! - floorIndex[b.floor]!).abs();
      return kind == EdgeKind.lift
          ? liftBaseCost + liftCostPerFloor * floorsApart
          : stairsCostPerFloor * floorsApart;
    }

    final edges = <MapEdge>[];
    final connected = <(int, int)>{};
    for (final raw in parseEdges(requireList(json, 'edges', 'map'), nodes)) {
      final a = nodes[raw.from]!;
      final b = nodes[raw.to]!;
      final kind = a.floor == b.floor
          ? EdgeKind.walk
          : (a.type == NodeType.lift && b.type == NodeType.lift ? EdgeKind.lift : EdgeKind.stairs);
      final weight = raw.weight ?? (kind == EdgeKind.walk ? walkCost(a, b) : verticalCost(kind, a, b));
      edges.add(MapEdge(raw.from, raw.to, weight, kind: kind, explicitWeight: raw.weight));
      connected.add(_key(raw.from, raw.to));
    }

    // Lifts and stairs that share a link name are one shaft or staircase:
    // connect each to the next floor up where it appears.
    final groups = <String, List<MapNode>>{};
    for (final node in nodes.values) {
      final link = node.link;
      if (link == null) continue;
      groups.putIfAbsent('${node.type.name}:${link.trim().toLowerCase()}', () => []).add(node);
    }
    for (final members in groups.values) {
      members.sort((a, b) => floorIndex[a.floor]!.compareTo(floorIndex[b.floor]!));
      for (var i = 0; i + 1 < members.length; i++) {
        final a = members[i];
        final b = members[i + 1];
        if (a.floor == b.floor) {
          throw MapFormatException(
            '${a.name} and ${b.name} are both "${a.link}" on ${floorByLevel[a.floor]!.name}. '
            'Give each ${a.type.label.toLowerCase()} a different link name on the same floor.',
          );
        }
        if (connected.contains(_key(a.id, b.id))) continue;
        final kind = a.type == NodeType.lift ? EdgeKind.lift : EdgeKind.stairs;
        edges.add(MapEdge(a.id, b.id, verticalCost(kind, a, b), kind: kind, automatic: true));
        connected.add(_key(a.id, b.id));
      }
    }

    return BuildingMap._(
      id: id,
      name: name,
      floors: List.unmodifiable(floors),
      nodes: Map.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      nodeIdByMarker: Map.unmodifiable(nodeIdByMarker),
      floorByLevel: Map.unmodifiable(floorByLevel),
    );
  }

  static (int, int) _key(int a, int b) => a < b ? (a, b) : (b, a);

  /// Stable identifier of a saved building, or null for the bundled sample.
  final String? id;
  final String name;

  /// Sorted from the lowest level up.
  final List<Floor> floors;
  final Map<int, MapNode> nodes;

  /// Every connection, including lift/stairs links made from link names.
  final List<MapEdge> edges;
  final Map<int, int> _nodeIdByMarker;
  final Map<int, Floor> _floorByLevel;
  final Map<RoutePreference, Graph> _graphs = {};

  /// The routing graph with every connection allowed.
  Graph get graph => graphFor(RoutePreference.fastest);

  /// The routing graph without the connections [preference] rules out.
  Graph graphFor(RoutePreference preference) => _graphs.putIfAbsent(preference, () {
    final adjacency = <int, List<Neighbor>>{for (final id in nodes.keys) id: <Neighbor>[]};
    for (final e in edges) {
      if (!preference.allows(e.kind)) continue;
      adjacency[e.from]!.add(Neighbor(e.to, e.weight));
      adjacency[e.to]!.add(Neighbor(e.from, e.weight));
    }
    return Map.unmodifiable({
      for (final entry in adjacency.entries) entry.key: List<Neighbor>.unmodifiable(entry.value),
    });
  });

  MapNode node(int id) => nodes[id] ?? (throw ArgumentError.value(id, 'id', 'No node with this id'));

  MapNode? nodeForMarker(int markerId) {
    final id = _nodeIdByMarker[markerId];
    return id == null ? null : nodes[id];
  }

  bool isKnownMarker(int markerId) => _nodeIdByMarker.containsKey(markerId);

  Iterable<int> get markerIds => _nodeIdByMarker.keys;

  Floor floor(int level) =>
      _floorByLevel[level] ?? (throw ArgumentError.value(level, 'level', 'No floor at this level'));

  Iterable<MapNode> nodesOnFloor(int level) => nodes.values.where((n) => n.floor == level);

  /// The building as JSON, in the current format. Automatic lift/stairs links
  /// are left out, since they are rebuilt from link names on load.
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
          'marker': n.markerId,
          'link': ?n.link,
        },
    ],
    'edges': [
      for (final e in edges)
        if (!e.automatic) {'from': e.from, 'to': e.to, 'weight': ?e.explicitWeight},
    ],
  };
}
