import 'map_json.dart';

export 'map_json.dart' show MapFormatException;

/// What kind of place a node is. Drives icons and how directions are worded.
enum NodeType {
  room,
  washroom,
  lift,
  stairs,
  entry,
  landmark;

  static NodeType parse(String value, String context) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    final allowed = values.map((t) => t.name).join(', ');
    throw MapFormatException('$context: unknown type "$value" (use one of: $allowed)');
  }
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
  });

  final int level;
  final String name;
  final String image;
  final double width;
  final double height;
}

/// A place you can navigate to or from. [markerId] is the ArUco marker stuck
/// at this spot, or null when the spot has no marker (it can still be routed
/// through).
class MapNode {
  const MapNode({
    required this.id,
    required this.name,
    required this.type,
    required this.floor,
    required this.x,
    required this.y,
    this.markerId,
  });

  final int id;
  final String name;
  final NodeType type;
  final int floor;
  final double x;
  final double y;
  final int? markerId;
}

/// A walkable connection between two nodes. Edges are two-way.
class MapEdge {
  const MapEdge(this.from, this.to, this.weight);

  final int from;
  final int to;
  final double weight;
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
    required this.name,
    required this.floors,
    required this.nodes,
    required this.edges,
    required this.graph,
    required Map<int, int> nodeIdByMarker,
    required Map<int, Floor> floorByLevel,
  }) : _nodeIdByMarker = nodeIdByMarker,
       _floorByLevel = floorByLevel;

  /// Throws [MapFormatException] with a message naming the bad entry.
  factory BuildingMap.fromJson(Map<String, dynamic> json) {
    final name = optionalString(json, 'building', 'map') ?? 'Building';
    final floors = parseFloors(requireList(json, 'floors', 'map'));
    final floorByLevel = {for (final f in floors) f.level: f};

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
          throw MapFormatException('node ${node.id}: marker $marker is already used by node $owner');
        }
        nodeIdByMarker[marker] = node.id;
      }
      nodes[node.id] = node;
    }

    final edges = parseEdges(requireList(json, 'edges', 'map'), nodes);
    final adjacency = <int, List<Neighbor>>{for (final id in nodes.keys) id: <Neighbor>[]};
    for (final e in edges) {
      adjacency[e.from]!.add(Neighbor(e.to, e.weight));
      adjacency[e.to]!.add(Neighbor(e.from, e.weight));
    }

    return BuildingMap._(
      name: name,
      floors: List.unmodifiable(floors),
      nodes: Map.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      graph: Map.unmodifiable({
        for (final entry in adjacency.entries) entry.key: List<Neighbor>.unmodifiable(entry.value),
      }),
      nodeIdByMarker: Map.unmodifiable(nodeIdByMarker),
      floorByLevel: Map.unmodifiable(floorByLevel),
    );
  }

  final String name;

  /// Sorted from the lowest level up.
  final List<Floor> floors;
  final Map<int, MapNode> nodes;
  final List<MapEdge> edges;
  final Graph graph;
  final Map<int, int> _nodeIdByMarker;
  final Map<int, Floor> _floorByLevel;

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
}
