import 'package:flutter/material.dart';

import '../map/building_map.dart';

/// Colours for the route overlay, taken from the app theme.
class RouteColors {
  const RouteColors({required this.route, required this.current, required this.destination, required this.connector});

  factory RouteColors.of(ColorScheme scheme) => RouteColors(
    route: scheme.primary,
    current: Colors.blue.shade600,
    destination: Colors.red.shade600,
    connector: Colors.orange.shade700,
  );

  final Color route;
  final Color current;
  final Color destination;
  final Color connector;
}

/// Draws nodes and the route on top of one floor's drawing. Node positions are
/// pixels on the floor image, scaled to the widget size.
class RoutePainter extends CustomPainter {
  RoutePainter({
    required this.map,
    required this.floor,
    required this.route,
    required this.colors,
    this.currentId,
    this.destinationId,
  });

  final BuildingMap map;
  final Floor floor;
  final List<int> route;
  final RouteColors colors;
  final int? currentId;
  final int? destinationId;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / floor.width;
    Offset at(MapNode n) => Offset(n.x * scale, n.y * scale);

    final dot = Paint()..color = Colors.black.withValues(alpha: 0.35);
    for (final node in map.nodesOnFloor(floor.level)) {
      canvas.drawCircle(at(node), 3.5, dot);
    }

    final casing = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = colors.route
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i + 1 < route.length; i++) {
      final a = map.node(route[i]);
      final b = map.node(route[i + 1]);
      if (a.floor == floor.level && b.floor == floor.level) {
        canvas.drawLine(at(a), at(b), casing);
        canvas.drawLine(at(a), at(b), line);
      } else if (a.floor == floor.level || b.floor == floor.level) {
        final here = a.floor == floor.level ? a : b;
        final there = identical(here, a) ? b : a;
        _drawConnector(canvas, at(here), there.floor > here.floor);
      }
    }

    final destination = destinationId == null ? null : map.node(destinationId!);
    if (destination != null && destination.floor == floor.level) {
      _drawMarker(canvas, at(destination), colors.destination);
    }
    final current = currentId == null ? null : map.node(currentId!);
    if (current != null && current.floor == floor.level) {
      canvas.drawCircle(at(current), 16, Paint()..color = colors.current.withValues(alpha: 0.25));
      _drawMarker(canvas, at(current), colors.current);
    }
  }

  void _drawMarker(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(center, 7, Paint()..color = color);
  }

  /// Lift/stairs where the route changes floor: a ring with an up/down arrow.
  void _drawConnector(Canvas canvas, Offset center, bool goingUp) {
    canvas.drawCircle(center, 13, Paint()..color = Colors.white);
    canvas.drawCircle(center, 11, Paint()..color = colors.connector);
    final icon = goingUp ? Icons.arrow_upward : Icons.arrow_downward;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 16, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.floor != floor ||
      old.route != route ||
      old.currentId != currentId ||
      old.destinationId != destinationId ||
      old.colors.route != colors.route;
}
