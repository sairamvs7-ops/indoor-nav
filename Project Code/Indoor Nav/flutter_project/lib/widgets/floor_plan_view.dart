import 'package:flutter/material.dart';

class NodePosition {
  final double x;
  final double y;
  final String name;
  final int floor; // 0 for Ground, 1 for First

  NodePosition(this.x, this.y, this.name, this.floor);
}

class FloorPlanView extends StatelessWidget {
  final List<int> path;
  final int? currentNode;
  final int? nextNode;
  final int selectedFloor;

  const FloorPlanView({
    super.key,
    required this.path,
    this.currentNode,
    this.nextNode,
    required this.selectedFloor,
  });

  static final Map<int, NodePosition> nodes = {
    // Ground Floor
    13: NodePosition(0.15, 0.15, "Entry 1", 0),
    4: NodePosition(0.4, 0.25, "Room 004", 0),
    5: NodePosition(0.55, 0.25, "Room 005", 0),
    6: NodePosition(0.7, 0.25, "Room 006", 0),
    7: NodePosition(0.85, 0.25, "Room 007", 0),
    9: NodePosition(0.08, 0.4, "Lift 1", 0),
    11: NodePosition(0.15, 0.7, "Stairs 1", 0),
    8: NodePosition(0.35, 0.75, "Girls Washroom", 0),
    3: NodePosition(0.45, 0.85, "Room 003", 0),
    2: NodePosition(0.6, 0.85, "Room 002", 0),
    1: NodePosition(0.75, 0.8, "Room 001", 0),
    10: NodePosition(0.85, 0.8, "Lift 2", 0),
    12: NodePosition(0.92, 0.8, "Stairs 2", 0),
    14: NodePosition(0.92, 0.9, "Entry 2", 0),
    
    // First Floor
    27: NodePosition(0.15, 0.15, "Entry 3", 1),
    28: NodePosition(0.3, 0.15, "Vending Machine", 1),
    18: NodePosition(0.45, 0.25, "Room 104", 1),
    19: NodePosition(0.6, 0.25, "Room 105", 1),
    20: NodePosition(0.75, 0.25, "Room 106", 1),
    21: NodePosition(0.9, 0.25, "Room 107", 1),
    23: NodePosition(0.08, 0.4, "Lift 3", 1),
    25: NodePosition(0.15, 0.7, "Stairs 3", 1),
    22: NodePosition(0.35, 0.75, "Boys Washroom", 1),
    17: NodePosition(0.45, 0.8, "Room 103", 1),
    16: NodePosition(0.6, 0.8, "Room 102", 1),
    15: NodePosition(0.75, 0.8, "Room 101", 1),
    24: NodePosition(0.85, 0.8, "Lift 4", 1),
    26: NodePosition(0.92, 0.8, "Stairs 4", 1),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: FloorPlanPainter(
                  path: path,
                  currentNode: currentNode,
                  nextNode: nextNode,
                  nodes: nodes,
                  selectedFloor: selectedFloor,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedFloor == 0 ? "GROUND FLOOR" : "FIRST FLOOR",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class FloorPlanPainter extends CustomPainter {
  final List<int> path;
  final int? currentNode;
  final int? nextNode;
  final Map<int, NodePosition> nodes;
  final int selectedFloor;

  FloorPlanPainter({
    required this.path,
    required this.currentNode,
    required this.nextNode,
    required this.nodes,
    required this.selectedFloor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawArchitecture(canvas, size);
    _drawConnections(canvas, size);
    _drawPath(canvas, size);
    _drawNodes(canvas, size);
  }

  void _drawArchitecture(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Drawing outer perimeter to frame the plan
    canvas.drawRect(
      Rect.fromLTRB(size.width * 0.05, size.height * 0.1, size.width * 0.95, size.height * 0.9),
      paint,
    );
  }

  void _drawConnections(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final connections = selectedFloor == 0 ? [
      [13, 4], [4, 5], [5, 6], [6, 7], // Top row
      [3, 2], [2, 1], [1, 10], [10, 12], [12, 14], // Bottom row + Right
      [13, 9], [9, 11], [11, 8], [8, 3], // Left vertical/mid
      [7, 10], // Link top to right side
      [4, 3], // Doorway/link
    ] : [
      [27, 28], [28, 18], [18, 19], [19, 20], [20, 21], // Top row
      [27, 23], [23, 25], [25, 22], [22, 17], // Left vertical/mid
      [17, 16], [16, 15], [15, 24], [24, 26], // Bottom row + Right
      [21, 24], // Link top to right side
      [18, 17], // Doorway/link
    ];

    for (var conn in connections) {
      final start = nodes[conn[0]];
      final end = nodes[conn[1]];
      if (start != null && end != null) {
        canvas.drawLine(
          Offset(start.x * size.width, start.y * size.height),
          Offset(end.x * size.width, end.y * size.height),
          paint,
        );
      }
    }
  }

  void _drawPath(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    final pathPaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.green.withOpacity(0.2)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < path.length - 1; i++) {
      final startNode = nodes[path[i]];
      final endNode = nodes[path[i + 1]];
      if (startNode != null && endNode != null && 
          startNode.floor == selectedFloor && endNode.floor == selectedFloor) {
        final start = Offset(startNode.x * size.width, startNode.y * size.height);
        final end = Offset(endNode.x * size.width, endNode.y * size.height);
        canvas.drawLine(start, end, glowPaint);
        canvas.drawLine(start, end, pathPaint);
      }
    }
  }

  void _drawNodes(Canvas canvas, Size size) {
    nodes.forEach((id, pos) {
      if (pos.floor != selectedFloor) return;

      final isCurrent = id == currentNode;
      final isNext = id == nextNode;
      final isInPath = path.contains(id);

      // Room / Area Box
      if (pos.name.startsWith('R') || pos.name == 'GW' || pos.name == 'BW' || pos.name == 'VM') {
        final boxPaint = Paint()
          ..color = isCurrent 
              ? Colors.green.withOpacity(0.2) 
              : (isNext ? Colors.blue.withOpacity(0.2) : (isInPath ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.03)))
          ..style = PaintingStyle.fill;
        
        final borderPaint = Paint()
          ..color = isCurrent 
              ? Colors.green 
              : (isNext ? Colors.blue : (isInPath ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.1)))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent || isNext ? 2 : 1;

        final rect = Rect.fromCenter(
          center: Offset(pos.x * size.width, pos.y * size.height),
          width: size.width * 0.08,
          height: size.height * 0.15,
        );
        
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), boxPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), borderPaint);
      }

      // Labels and Highlights
      final textPainter = TextPainter(
        text: TextSpan(
          text: pos.name,
          style: TextStyle(
            color: isCurrent ? Colors.green : (isNext ? Colors.blue : Colors.white.withOpacity(0.8)),
            fontSize: 8,
            fontWeight: isCurrent || isNext ? FontWeight.bold : FontWeight.normal,
            backgroundColor: isCurrent ? Colors.green.withOpacity(0.2) : (isNext ? Colors.blue.withOpacity(0.2) : Colors.transparent),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset(pos.x * size.width - (textPainter.width / 2), pos.y * size.height - (textPainter.height / 2)),
      );
    });
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) {
    return oldDelegate.currentNode != currentNode || 
           oldDelegate.nextNode != nextNode || 
           oldDelegate.path != path ||
           oldDelegate.selectedFloor != selectedFloor;
  }
}
