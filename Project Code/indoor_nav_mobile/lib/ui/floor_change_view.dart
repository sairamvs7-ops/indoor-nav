import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'blueprint_view.dart';

/// How long the whole floor change plays.
const Duration floorChangeDuration = Duration(milliseconds: 4200);

/// Sonar colours: glowing lime lines on black.
const Color _sonar = Color(0xFF89E900);
const Color _sonarSoft = Color(0xFFC7E9C0);
const Color _night = Color(0xFF040704);

/// Plays the floor-change view over the current screen: the floor map turns
/// into a 3D sonar wireframe, the camera swings into a side view, and your dot
/// goes up or down the stairs or lift to the next floor. Tap to skip.
Future<void> showFloorChange(
  BuildContext context, {
  required BuildingMap map,
  required FloorImages images,
  required MapNode from,
  required MapNode to,
  List<int> route = const [],
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: FloorChangeView(map: map, images: images, from: from, to: to, route: route),
      ),
    ),
  );
}

class FloorChangeView extends StatefulWidget {
  const FloorChangeView({
    super.key,
    required this.map,
    required this.images,
    required this.from,
    required this.to,
    this.route = const [],
    this.autoClose = true,
  });

  final BuildingMap map;

  /// Kept for floors without a generated map (not drawn in the sonar view).
  final FloorImages images;

  /// The lift or stairs you leave from, and the one you arrive at.
  final MapNode from;
  final MapNode to;
  final List<int> route;
  final bool autoClose;

  @override
  State<FloorChangeView> createState() => _FloorChangeViewState();
}

class _FloorChangeViewState extends State<FloorChangeView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: floorChangeDuration)
    ..addStatusListener(_onStatus)
    ..forward();
  late final _Scene _scene = _Scene.build(widget.map, widget.from, widget.to, widget.route);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.autoClose) _close();
  }

  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    final theme = Theme.of(context);
    final verb = widget.from.type == NodeType.lift ? 'Lift' : 'Stairs';
    return Scaffold(
      backgroundColor: _night,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  '$verb ${_scene.goingUp ? 'up' : 'down'} to ${map.floor(widget.to.floor).name}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _sonar,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _SonarPainter(scene: _scene, t: _controller.value),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Tap to skip',
                  style: theme.textTheme.bodySmall?.copyWith(color: _sonarSoft.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the animation is at time [t] (0..1).
class FloorChangePose {
  const FloorChangePose({required this.tilt, required this.spread, required this.travel, required this.focus});

  /// How far the camera has swung down from the top view, in radians
  /// (0 = looking straight down, like the flat map).
  final double tilt;

  /// How visible the other floor and the lift/stairs are, 0..1.
  final double spread;

  /// How far you have travelled from the old floor to the new one, 0..1.
  final double travel;

  /// 0 shows the old floor alone, 1 the new floor alone.
  final double focus;

  /// About 60 degrees: from looking straight down to a low side view.
  static const double maxTilt = 1.05;

  /// Swing into the side view (0-30%), travel (30-70%), swing back over the
  /// new floor (70-100%).
  factory FloorChangePose.at(double t) {
    double phase(double start, double end) =>
        Curves.easeInOutCubic.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
    final open = phase(0, 0.3);
    final close = phase(0.7, 1);
    return FloorChangePose(
      tilt: maxTilt * (open - close),
      spread: open - close,
      travel: phase(0.3, 0.7),
      focus: phase(0.55, 1),
    );
  }
}

/// A point in the 3D scene. x/z are across the floor (z towards the viewer
/// at the bottom of the plan), y is up.
typedef _V3 = ({double x, double y, double z});

/// The building as 3D wireframe lines, built once per floor change.
class _Scene {
  _Scene({
    required this.floorLines,
    required this.floorY,
    required this.fromLevel,
    required this.toLevel,
    required this.connector,
    required this.path,
    required this.isLift,
    required this.goingUp,
    required this.labels,
  });

  /// Floor level -> its wall lines (pairs of points) and corridor lines.
  final Map<int, ({List<(_V3, _V3)> walls, List<(_V3, _V3)> lanes})> floorLines;
  final Map<int, double> floorY;
  final int fromLevel;
  final int toLevel;

  /// The stairs or lift shaft between the two floors.
  final List<(_V3, _V3)> connector;

  /// Where your dot goes, from start to end.
  final List<_V3> path;
  final bool isLift;
  final bool goingUp;
  final Map<int, (_V3, String)> labels;

  static const double wallHeight = 0.07;
  static const double floorGap = 0.5;

  factory _Scene.build(BuildingMap map, MapNode from, MapNode to, List<int> route) {
    final order = {for (final (i, f) in map.floors.indexed) f.level: i};
    final goingUp = order[to.floor]! > order[from.floor]!;
    // Both floors share one footprint size: the wider drawing sets the scale.
    final widest = math.max(map.floor(from.floor).width, map.floor(to.floor).width);
    final floorY = {
      for (final level in {from.floor, to.floor}) level: (order[level]! - order[from.floor]!) * floorGap,
    };

    _V3 at(int level, double x, double y, [double up = 0]) {
      final f = map.floor(level);
      return (x: (x - f.width / 2) / widest, y: floorY[level]! + up, z: (y - f.height / 2) / widest);
    }

    final floorLines = <int, ({List<(_V3, _V3)> walls, List<(_V3, _V3)> lanes})>{};
    final labels = <int, (_V3, String)>{};
    for (final level in floorY.keys) {
      final f = map.floor(level);
      final walls = <(_V3, _V3)>[];
      final lanes = <(_V3, _V3)>[];
      if (f.regions.isEmpty) {
        // No generated map: the floor's outline and a post for each place.
        final corners = [(0.0, 0.0), (f.width, 0.0), (f.width, f.height), (0.0, f.height)];
        for (var i = 0; i < 4; i++) {
          final (ax, ay) = corners[i];
          final (bx, by) = corners[(i + 1) % 4];
          lanes.add((at(level, ax, ay), at(level, bx, by)));
        }
        for (final n in map.nodesOnFloor(level)) {
          if (n.automatic) continue;
          walls.add((at(level, n.x, n.y), at(level, n.x, n.y, wallHeight)));
        }
      }
      for (final region in f.regions) {
        if (region.kind == RegionKind.ignored) continue;
        final o = region.outline;
        for (var i = 0; i < o.length; i++) {
          final a = o[i], b = o[(i + 1) % o.length];
          if (region.kind == RegionKind.corridor) {
            lanes.add((at(level, a.x, a.y), at(level, b.x, b.y)));
            continue;
          }
          // Rooms, stairwells and lift shafts get walls: bottom, top, and a
          // post at each corner.
          walls
            ..add((at(level, a.x, a.y), at(level, b.x, b.y)))
            ..add((at(level, a.x, a.y, wallHeight), at(level, b.x, b.y, wallHeight)))
            ..add((at(level, a.x, a.y), at(level, a.x, a.y, wallHeight)));
        }
      }
      floorLines[level] = (walls: walls, lanes: lanes);
      labels[level] = (at(level, 0, f.height), f.name);
    }

    // The stairs or lift: footprint on each floor (its region, or a small
    // square around the place).
    (double, double, double, double) footprint(MapNode node) {
      final f = map.floor(node.floor);
      final region = f.region(node.region);
      if (region != null) {
        final xs = region.outline.map((p) => p.x), ys = region.outline.map((p) => p.y);
        return (xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
      }
      final half = widest * 0.025;
      return (node.x - half, node.y - half, node.x + half, node.y + half);
    }

    final isLift = from.type == NodeType.lift;
    final (fx0, fy0, fx1, fy1) = footprint(from);
    final (tx0, ty0, tx1, ty1) = footprint(to);
    final connector = <(_V3, _V3)>[];
    final path = <_V3>[];
    if (isLift) {
      // A shaft from the lower lift to the upper one, at the departure lift.
      final corners = [(fx0, fy0), (fx1, fy0), (fx1, fy1), (fx0, fy1)];
      for (var i = 0; i < 4; i++) {
        final (ax, ay) = corners[i];
        final (bx, by) = corners[(i + 1) % 4];
        connector
          ..add((at(from.floor, ax, ay), at(to.floor, ax, ay)))
          ..add((at(to.floor, ax, ay), at(to.floor, bx, by)));
      }
      final cx = (fx0 + fx1) / 2, cy = (fy0 + fy1) / 2;
      path
        ..add(at(from.floor, cx, cy))
        ..add(at(to.floor, cx, cy));
    } else {
      // A flight of steps from the departure stairs to the arrival stairs,
      // rising along the stairwell's longer side.
      const steps = 12;
      final along = (fx1 - fx0) >= (fy1 - fy0);
      for (var s = 0; s <= steps; s++) {
        final k = s / steps;
        double lerp(double a, double b) => a + (b - a) * k;
        // Centre line from one end of the departure stairs to the far end of
        // the arrival stairs.
        final x = along ? lerp(fx0, tx1) : lerp((fx0 + fx1) / 2, (tx0 + tx1) / 2);
        final y = along ? lerp((fy0 + fy1) / 2, (ty0 + ty1) / 2) : lerp(fy0, ty1);
        final halfWidth = (along ? (fy1 - fy0) : (fx1 - fx0)) / 2;
        final rise = (floorY[to.floor]! - floorY[from.floor]!) * k;
        final base = at(from.floor, x, y, rise);
        final side = along ? (x: 0.0, y: 0.0, z: halfWidth / widest) : (x: halfWidth / widest, y: 0.0, z: 0.0);
        final left = (x: base.x - side.x, y: base.y, z: base.z - side.z);
        final right = (x: base.x + side.x, y: base.y, z: base.z + side.z);
        connector.add((left, right)); // tread
        if (s < steps) {
          final up = (floorY[to.floor]! - floorY[from.floor]!) / steps;
          // Riser, then the start of the next tread on both sides.
          connector
            ..add((left, (x: left.x, y: left.y + up, z: left.z)))
            ..add((right, (x: right.x, y: right.y + up, z: right.z)));
        }
        path.add(base);
      }
    }

    return _Scene(
      floorLines: floorLines,
      floorY: floorY,
      fromLevel: from.floor,
      toLevel: to.floor,
      connector: connector,
      path: path,
      isLift: isLift,
      goingUp: goingUp,
      labels: labels,
    );
  }

  /// Your position after travelling [k] (0..1) of the way.
  _V3 dotAt(double k) {
    if (path.length < 2) return path.isEmpty ? (x: 0, y: 0, z: 0) : path.first;
    final scaled = k.clamp(0.0, 1.0) * (path.length - 1);
    final i = math.min(scaled.floor(), path.length - 2);
    final f = scaled - i;
    final a = path[i], b = path[i + 1];
    return (x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f, z: a.z + (b.z - a.z) * f);
  }
}

class _SonarPainter extends CustomPainter {
  _SonarPainter({required this.scene, required this.t});

  final _Scene scene;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = FloorChangePose.at(t);
    final elevation = math.pi / 2 - pose.tilt; // 90 degrees = straight down
    final yaw = -0.55 * pose.spread + 0.15 * math.sin(t * math.pi);
    final dot = scene.dotAt(pose.travel);
    // The camera follows you up or down.
    final target = (x: 0.0, y: dot.y, z: 0.0);
    const distance = 2.2;
    final focal = math.min(size.width, size.height * 1.4) * 0.85 * distance;
    final centre = Offset(size.width / 2, size.height / 2);

    Offset? project(_V3 p) {
      final qx = p.x - target.x, qy = p.y - target.y, qz = p.z - target.z;
      final x1 = qx * math.cos(yaw) - qz * math.sin(yaw);
      final z1 = qx * math.sin(yaw) + qz * math.cos(yaw);
      final y2 = qy * math.cos(elevation) - z1 * math.sin(elevation);
      final z2 = qy * math.sin(elevation) + z1 * math.cos(elevation);
      final depth = distance - z2;
      if (depth < 0.1) return null;
      return centre + Offset(focal * x1 / depth, -focal * y2 / depth);
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = _night);

    // Sonar pulses: rings spreading from you every ~1.2 s.
    final pulses = [for (var k = 0; k < 2; k++) ((t * 3.4 + k * 0.5) % 1.0) * 1.3];
    double glowAt(_V3 a, _V3 b) {
      final mx = (a.x + b.x) / 2 - dot.x, mz = (a.z + b.z) / 2 - dot.z, my = (a.y + b.y) / 2 - dot.y;
      final d = math.sqrt(mx * mx + mz * mz + my * my * 4);
      var glow = 0.0;
      for (final r in pulses) {
        glow = math.max(glow, math.exp(-math.pow((d - r) / 0.06, 2).toDouble()) * (1 - r / 1.3));
      }
      return glow;
    }

    void lines(List<(_V3, _V3)> segments, Color color, double alpha, double width) {
      if (alpha <= 0.01) return;
      final core = Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final halo = Paint()
        ..strokeWidth = width * 4
        ..strokeCap = StrokeCap.round;
      for (final (a, b) in segments) {
        final pa = project(a), pb = project(b);
        if (pa == null || pb == null) continue;
        final g = glowAt(a, b);
        final strength = (alpha * (0.45 + 0.55 * g)).clamp(0.0, 1.0);
        if (g > 0.05) canvas.drawLine(pa, pb, halo..color = color.withValues(alpha: strength * 0.25));
        canvas.drawLine(pa, pb, core..color = color.withValues(alpha: strength));
      }
    }

    // The old floor fades as the new one comes into focus.
    final fromAlpha = 1 - pose.focus * (1 - pose.spread);
    final toAlpha = math.max(pose.spread, pose.focus);
    for (final entry in scene.floorLines.entries) {
      final alpha = entry.key == scene.fromLevel ? fromAlpha : toAlpha;
      lines(entry.value.lanes, _sonarSoft, alpha * 0.45, 1);
      lines(entry.value.walls, _sonar, alpha, 1.4);
    }
    lines(scene.connector, _sonarSoft, pose.spread, scene.isLift ? 1.2 : 1.6);

    // The lift cabin travels with you.
    if (scene.isLift && pose.spread > 0.01) {
      const half = 0.025;
      final cabin = [
        (x: dot.x - half, y: dot.y, z: dot.z - half),
        (x: dot.x + half, y: dot.y, z: dot.z - half),
        (x: dot.x + half, y: dot.y, z: dot.z + half),
        (x: dot.x - half, y: dot.y, z: dot.z + half),
      ];
      final ring = [for (var i = 0; i < 4; i++) (cabin[i], cabin[(i + 1) % 4])];
      final roof = [for (final (a, b) in ring) ((x: a.x, y: a.y + 0.05, z: a.z), (x: b.x, y: b.y + 0.05, z: b.z))];
      lines([...ring, ...roof], _sonar, pose.spread, 2);
    }

    // Floor names.
    for (final entry in scene.labels.entries) {
      final alpha = (entry.key == scene.fromLevel ? fromAlpha : toAlpha) * (0.3 + 0.7 * pose.spread);
      final at = project(entry.value.$1);
      if (at == null || alpha < 0.05) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: entry.value.$2.toUpperCase(),
          style: TextStyle(
            color: _sonarSoft.withValues(alpha: alpha.clamp(0.0, 1.0)),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at + const Offset(-4, 6));
    }

    // You.
    final you = project(dot);
    if (you != null) {
      final beat = 0.5 + 0.5 * math.sin(t * math.pi * 10);
      canvas
        ..drawCircle(you, 16 + 6 * beat, Paint()..color = _sonar.withValues(alpha: 0.18))
        ..drawCircle(you, 8, Paint()..color = Colors.white)
        ..drawCircle(you, 6, Paint()..color = _sonar);
    }
  }

  @override
  bool shouldRepaint(_SonarPainter old) => old.t != t || old.scene != scene;
}
