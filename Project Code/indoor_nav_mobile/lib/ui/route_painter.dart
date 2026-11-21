import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'app_theme.dart';

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
    this.live,
    this.guide = const [],
    this.guideProgress,
  }) : super(repaint: guideProgress);

  final BuildingMap map;
  final Floor floor;
  final List<int> route;
  final MapColors colors;
  final int? currentId;
  final int? destinationId;

  /// Your position while walking, between places (drawing pixels).
  final Offset? live;

  /// The way to the next stop (drawing pixels), shown by a moving dot as
  /// [guideProgress] runs from 0 to 1.
  final List<Offset> guide;
  final Animation<double>? guideProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / floor.width;
    Offset at(MapNode n) => Offset(n.x * scale, n.y * scale);

    final dot = Paint()..color = Colors.black.withValues(alpha: 0.35);
    for (final node in map.nodesOnFloor(floor.level)) {
      if (node.type != NodeType.corridor) canvas.drawCircle(at(node), 3.5, dot);
    }

    final casing = Paint()
      ..color = colors.routeCasing
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
    _drawGuide(canvas, scale);

    final walking = live;
    if (walking != null) {
      final at = walking * scale;
      canvas
        ..drawCircle(at, 20, Paint()..color = colors.current.withValues(alpha: 0.22))
        ..drawCircle(at, 10, Paint()..color = Colors.white)
        ..drawCircle(at, 8, Paint()..color = colors.current);
      return; // the live dot replaces the "last place reached" pin
    }
    final current = currentId == null ? null : map.node(currentId!);
    if (current != null && current.floor == floor.level) {
      canvas.drawCircle(at(current), 16, Paint()..color = colors.current.withValues(alpha: 0.25));
      _drawMarker(canvas, at(current), colors.current);
    }
  }

  /// A glowing dot with a fading trail, travelling from you to the next stop.
  void _drawGuide(Canvas canvas, double scale) {
    final progress = guideProgress;
    if (progress == null || guide.length < 2 || progress.isDismissed) return;
    final points = [for (final p in guide) p * scale];
    final lengths = [for (var i = 0; i + 1 < points.length; i++) (points[i + 1] - points[i]).distance];
    final total = lengths.fold<double>(0, (a, b) => a + b);
    if (total < 1) return;
    Offset at(double d) {
      var left = d.clamp(0.0, total);
      for (var i = 0; i < lengths.length; i++) {
        if (left <= lengths[i] || i == lengths.length - 1) {
          final t = lengths[i] == 0 ? 0.0 : (left / lengths[i]).clamp(0.0, 1.0);
          return Offset.lerp(points[i], points[i + 1], t)!;
        }
        left -= lengths[i];
      }
      return points.last;
    }

    final t = Curves.easeInOut.transform(progress.value);
    final head = t * total;
    // Fade in at the start and out at the stop.
    final fade = (t < 0.1 ? t / 0.1 : (t > 0.9 ? (1 - t) / 0.1 : 1.0)).clamp(0.0, 1.0);
    for (var k = 6; k >= 1; k--) {
      final trail = at(head - k * 6);
      canvas.drawCircle(trail, 5 - k * 0.5, Paint()..color = colors.route.withValues(alpha: fade * (0.5 - k * 0.07)));
    }
    final dot = at(head);
    canvas
      ..drawCircle(dot, 13, Paint()..color = colors.route.withValues(alpha: fade * 0.3))
      ..drawCircle(dot, 7, Paint()..color = Colors.white.withValues(alpha: fade))
      ..drawCircle(dot, 5, Paint()..color = colors.route.withValues(alpha: fade));
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
        style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 16, color: Colors.black87),
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
      old.live != live ||
      old.guide != guide ||
      old.colors.route != colors.route;
}
