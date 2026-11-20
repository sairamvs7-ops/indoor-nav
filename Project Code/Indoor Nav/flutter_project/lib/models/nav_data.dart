class PathStep {
  final int id;
  final String name;
  final String roomNumber;

  PathStep({required this.id, required this.name, required this.roomNumber});

  factory PathStep.fromJson(Map<String, dynamic> json) {
    return PathStep(
      id: json['id'] ?? 0,
      name: json['name'] ?? "Unknown",
      roomNumber: json['roomNumber'] ?? "N/A",
    );
  }
}

class NavData {
  final int next;
  final String instruction;
  final bool destinationReached;
  final List<PathStep> path;

  NavData({
    required this.next,
    required this.instruction,
    required this.destinationReached,
    this.path = const [],
  });

  static final Map<int, String> nodeNames = {
    1: "Room 001", 2: "Room 002", 3: "Room 003", 4: "Room 004", 5: "Room 005", 6: "Room 006", 7: "Room 007",
    8: "Girls Washroom", 9: "Lift 1", 10: "Lift 2", 11: "Stairs 1", 12: "Stairs 2", 13: "Entry 1", 14: "Entry 2",
    15: "Room 101", 16: "Room 102", 17: "Room 103", 18: "Room 104", 19: "Room 105", 20: "Room 106", 21: "Room 107",
    22: "Boys Washroom", 23: "Lift 3", 24: "Lift 4", 25: "Stairs 3", 26: "Stairs 4", 27: "Entry 3", 28: "Vending Machine"
  };

  factory NavData.fromJson(Map<String, dynamic> json) {
    List<PathStep> path = [];
    if (json['path'] != null) {
      for (var e in (json['path'] as List)) {
        if (e is int) {
          final name = nodeNames[e] ?? "Room $e";
          path.add(PathStep(id: e, name: name, roomNumber: "$e"));
        } else if (e is Map) {
          path.add(PathStep.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    
    final nextId = json['next'] ?? (path.length > 1 ? path[1].id : 0);
    final nextName = nodeNames[nextId] ?? "Next Point";
    
    return NavData(
      next: nextId,
      instruction: json['instruction'] ?? (path.isNotEmpty ? "Head towards $nextName" : "Unknown"),
      destinationReached: json['destinationReached'] ?? false,
      path: path,
    );
  }
}
