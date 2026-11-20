import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/building_map.dart';

/// Colours for drawing generated floor maps. Fixed per brightness so every
/// building looks the same, whatever its blueprint looked like.
@immutable
class MapStyle {
  const MapStyle({
    required this.paper,
    required this.room,
    required this.roomEdge,
    required this.corridor,
    required this.corridorEdge,
    required this.stairs,
    required this.lift,
    required this.label,
    required this.selected,
  });

  factory MapStyle.of(Brightness brightness) => brightness == Brightness.light
      ? const MapStyle(
          paper: Color(0xFFFBF6EC),
          room: Color(0xFFE3E8D3),
          roomEdge: Color(0xFF586B45),
          corridor: Color(0xFFF1E8D4),
          corridorEdge: Color(0xFFC9B993),
          stairs: Color(0xFFB7791F),
          lift: Color(0xFF005A32),
          label: Color(0xFF2B3320),
          selected: Color(0xFFF59E0B),
        )
      : const MapStyle(
          paper: Color(0xFF181A16),
          room: Color(0xFF26301C),
          roomEdge: Color(0xFF89E900),
          corridor: Color(0xFF20241B),
          corridorEdge: Color(0xFF4A5A30),
          stairs: Color(0xFFF2B84B),
          lift: Color(0xFFC7E9C0),
          label: Color(0xFFE8F5D8),
          selected: Color(0xFFF59E0B),
        );

  final Color paper;
  final Color room;
  final Color roomEdge;
  final Color corridor;
  final Color corridorEdge;
  final Color stairs;
  final Color lift;
  final Color label;
  final Color selected;
}

/// Draws a floor's generated map: rooms as tiles, corridors as lanes, stairs
/// as steps, lifts as boxes with a cross, and room names. Coordinates are
/// drawing pixels, scaled to the canvas width.
class GeneratedMapPainter extends CustomPainter {
  GeneratedMapPainter({
    required this.regions,
    required this.drawingWidth,
    required this.style,
    this.names = const {},
    this.selectedRegion,
    this.showIgnored = false,
  });

  /// The floor's regions, in drawing pixels of a drawing [drawingWidth] wide.
  final List<FloorRegion> regions;
  final double drawingWidth;
  final MapStyle style;

  /// Region id -> name to print inside it.
  final Map<String, String> names;
  final String? selectedRegion;

  /// Editors show ignored regions faintly so they can be brought back.
  final bool showIgnored;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / drawingWidth;
    canvas.drawRect(Offset.zero & size, Paint()..color = style.paper);
    Path outline(FloorRegion r) {
      final path = Path()..moveTo(r.outline.first.x * scale, r.outline.first.y * scale);
      for (final p in r.outline.skip(1)) {
        path.lineTo(p.x * scale, p.y * scale);
      }
      return path..close();
    }

    final edgeWidth = math.max(1.5, size.width / 320);
    // Corridors first so rooms sit on top of them at doorways.
    final ordered = [
      ...regions.where((r) => r.kind == RegionKind.corridor),
      ...regions.where((r) => r.kind != RegionKind.corridor),
    ];
    for (final region in ordered) {
      final path = outline(region);
      final selected = region.id == selectedRegion;
      switch (region.kind) {
        case RegionKind.ignored:
          if (!showIgnored) continue;
          canvas.drawPath(
            path,
            Paint()
              ..color = style.corridorEdge.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = edgeWidth,
          );
        case RegionKind.corridor:
          canvas
            ..drawPath(path, Paint()..color = style.corridor)
            ..drawPath(
              path,
              Paint()
                ..color = style.corridorEdge
                ..style = PaintingStyle.stroke
                ..strokeWidth = edgeWidth * 0.8,
            );
        case RegionKind.room:
          canvas
            ..drawPath(path, Paint()..color = style.room)
            ..drawPath(
              path,
              Paint()
                ..color = style.roomEdge
                ..style = PaintingStyle.stroke
                ..strokeWidth = edgeWidth
                ..strokeJoin = StrokeJoin.round,
            );
        case RegionKind.stairs:
          _stairs(canvas, path, region, scale, edgeWidth);
        case RegionKind.lift:
          _lift(canvas, path, region, scale, edgeWidth);
      }
      if (selected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = style.selected
            ..style = PaintingStyle.stroke
            ..strokeWidth = edgeWidth * 2.5
            ..strokeJoin = StrokeJoin.round,
        );
      }
      final name = names[region.id];
      if (name != null && region.kind != RegionKind.ignored) _label(canvas, name, region, scale);
    }
  }

  void _stairs(Canvas canvas, Path path, FloorRegion region, double scale, double edge) {
    canvas.drawPath(path, Paint()..color = style.stairs.withValues(alpha: 0.18));
    final bounds = path.getBounds();
    // Treads across the shorter side, so it reads as a flight of steps.
    final vertical = bounds.height > bounds.width;
    final length = vertical ? bounds.height : bounds.width;
    final treads = math.max(4, (length / math.max(6, edge * 5)).round());
    final tread = Paint()
      ..color = style.stairs
      ..strokeWidth = edge * 0.8;
    canvas
      ..save()
      ..clipPath(path);
    for (var i = 1; i < treads; i++) {
      final t = i / treads;
      if (vertical) {
        final y = bounds.top + bounds.height * t;
        canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), tread);
      } else {
        final x = bounds.left + bounds.width * t;
        canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), tread);
      }
    }
    canvas
      ..restore()
      ..drawPath(
        path,
        Paint()
          ..color = style.stairs
          ..style = PaintingStyle.stroke
          ..strokeWidth = edge,
      );
  }

  void _lift(Canvas canvas, Path path, FloorRegion region, double scale, double edge) {
    final bounds = path.getBounds();
    final line = Paint()
      ..color = style.lift
      ..style = PaintingStyle.stroke
      ..strokeWidth = edge;
    canvas
      ..drawPath(path, Paint()..color = style.lift.withValues(alpha: 0.14))
      ..save()
      ..clipPath(path)
      ..drawLine(bounds.topLeft, bounds.bottomRight, line)
      ..drawLine(bounds.topRight, bounds.bottomLeft, line)
      ..restore()
      ..drawPath(path, line);
  }

  void _label(Canvas canvas, String text, FloorRegion region, double scale) {
    final bounds = Rect.fromPoints(
      Offset(region.outline.map((p) => p.x).reduce(math.min) * scale, region.outline.map((p) => p.y).reduce(math.min) * scale),
      Offset(region.outline.map((p) => p.x).reduce(math.max) * scale, region.outline.map((p) => p.y).reduce(math.max) * scale),
    );
    if (bounds.width < 24 || bounds.height < 12) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: style.label,
          fontSize: math.min(14, math.max(8, bounds.shortestSide / 5)),
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: bounds.width * 0.9);
    final c = region.centre;
    painter.paint(canvas, Offset(c.x * scale, c.y * scale) - Offset(painter.width / 2, painter.height / 2 - 12));
  }

  @override
  bool shouldRepaint(GeneratedMapPainter old) =>
      old.regions != regions || old.selectedRegion != selectedRegion || old.names != names || old.style != style;
}

/// Region id -> name of the place that uses it, for labels.
Map<String, String> regionNames(BuildingMap map, int level) => {
  for (final n in map.nodesOnFloor(level))
    if (n.region != null && !n.automatic) n.region!: n.name,
};
