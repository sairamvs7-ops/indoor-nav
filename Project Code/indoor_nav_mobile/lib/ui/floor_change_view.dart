import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'app_theme.dart';
import 'blueprint_view.dart';
import 'route_painter.dart';

/// How long the whole floor change plays.
const Duration floorChangeDuration = Duration(milliseconds: 3600);

/// Plays the floor-change animation over the current screen: the map tilts
/// into a side view of two stacked floors, your dot travels up or down the
/// lift or stairs between them, and the view settles on the new floor.
/// Tap anywhere to skip.
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
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 250),
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
  final FloorImages images;

  /// The lift or stairs you leave from, and the one you arrive at.
  final MapNode from;
  final MapNode to;
  final List<int> route;

  /// Close by itself when the animation ends.
  final bool autoClose;

  @override
  State<FloorChangeView> createState() => _FloorChangeViewState();
}

class _FloorChangeViewState extends State<FloorChangeView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: floorChangeDuration)
    ..addStatusListener(_onStatus)
    ..forward();

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
    final from = widget.from;
    final to = widget.to;
    final goingUp = map.floors.indexWhere((f) => f.level == to.floor) >
        map.floors.indexWhere((f) => f.level == from.floor);
    final theme = Theme.of(context);
    final verb = from.type == NodeType.lift ? 'Lift' : 'Stairs';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  '$verb ${goingUp ? 'up' : 'down'} to ${map.floor(to.floor).name}',
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _FloorStack(
                      size: constraints.biggest,
                      t: _controller.value,
                      map: map,
                      images: widget.images,
                      from: from,
                      to: to,
                      route: widget.route,
                      colors: MapColors.resolve(context),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Tap to skip', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
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

  /// Tilt back from the top view, in radians (0 = flat top view).
  final double tilt;

  /// How far apart the two floors are drawn, 0..1.
  final double spread;

  /// How far the dot has travelled from the old floor to the new one, 0..1.
  final double travel;

  /// 0 shows the old floor alone, 1 the new floor alone.
  final double focus;

  static const double maxTilt = 1.05; // about 60 degrees: a clear side view

  /// Tilt and separate (0-30%), travel (30-70%), settle on the new floor
  /// (70-100%).
  factory FloorChangePose.at(double t) {
    double phase(double start, double end) => Curves.easeInOutCubic.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
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

class _FloorStack extends StatelessWidget {
  const _FloorStack({
    required this.size,
    required this.t,
    required this.map,
    required this.images,
    required this.from,
    required this.to,
    required this.route,
    required this.colors,
  });

  final Size size;
  final double t;
  final BuildingMap map;
  final FloorImages images;
  final MapNode from;
  final MapNode to;
  final List<int> route;
  final MapColors colors;

  @override
  Widget build(BuildContext context) {
    final pose = FloorChangePose.at(t);
    final goingUp = map.floors.indexWhere((f) => f.level == to.floor) >
        map.floors.indexWhere((f) => f.level == from.floor);
    final lower = goingUp ? from : to;
    final upper = goingUp ? to : from;

    final planeWidth = math.min(size.width - 48, 520.0);
    final gap = size.height * 0.32 * pose.spread;
    final center = Offset(size.width / 2, size.height / 2);

    // Full transform for a floor plane: centred on screen, shifted up/down to
    // separate the floors, then tilted back with perspective.
    Matrix4 planeMatrix(Floor floor, double shiftY) {
      final height = planeWidth * floor.height / floor.width;
      return Matrix4.translationValues(center.dx, center.dy, 0)
        ..multiply(Matrix4.identity()..setEntry(3, 2, 0.0014)) // perspective
        ..multiply(Matrix4.translationValues(0, shiftY, 0))
        ..multiply(Matrix4.rotationX(pose.tilt))
        ..multiply(Matrix4.translationValues(-planeWidth / 2, -height / 2, 0));
    }

    final lowerFloor = map.floor(lower.floor);
    final upperFloor = map.floor(upper.floor);
    final lowerMatrix = planeMatrix(lowerFloor, gap);
    final upperMatrix = planeMatrix(upperFloor, -gap);

    Offset onPlane(Matrix4 m, Floor floor, MapNode node) =>
        MatrixUtils.transformPoint(m, Offset(node.x * planeWidth / floor.width, node.y * planeWidth / floor.width));

    final lowerPoint = onPlane(lowerMatrix, lowerFloor, lower);
    final upperPoint = onPlane(upperMatrix, upperFloor, upper);
    final start = goingUp ? lowerPoint : upperPoint;
    final end = goingUp ? upperPoint : lowerPoint;
    final dot = Offset.lerp(start, end, pose.travel)!;

    // The old floor fades out as the new one comes into focus, and vice versa.
    final fromOpacity = 1 - pose.focus * (1 - pose.spread).clamp(0.0, 1.0);
    final toOpacity = math.max(pose.spread, pose.focus).clamp(0.0, 1.0);
    final lowerOpacity = goingUp ? fromOpacity : toOpacity;
    final upperOpacity = goingUp ? toOpacity : fromOpacity;

    Widget plane(Floor floor, Matrix4 matrix, double opacity) => Positioned(
      left: 0,
      top: 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          transform: matrix,
          child: SizedBox(
            width: planeWidth,
            height: planeWidth * floor.height / floor.width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 12))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(image: images(floor.image), fit: BoxFit.fill, gaplessPlayback: true),
                    CustomPaint(painter: RoutePainter(map: map, floor: floor, route: route, colors: colors)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
    Widget label(Floor floor, Matrix4 matrix, double opacity) {
      final at = MatrixUtils.transformPoint(matrix, Offset(0, planeWidth * floor.height / floor.width / 2));
      return Positioned(
        left: 8,
        top: at.dy - 12,
        child: Opacity(
          opacity: (opacity * pose.spread).clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Text(floor.name, style: labelStyle),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        plane(lowerFloor, lowerMatrix, lowerOpacity),
        plane(upperFloor, upperMatrix, upperOpacity),
        Positioned.fill(
          child: CustomPaint(
            painter: _ConnectorPainter(
              start: start,
              end: end,
              dot: dot,
              visible: pose.spread,
              line: colors.connector,
              dotColor: colors.current,
            ),
          ),
        ),
        label(lowerFloor, lowerMatrix, lowerOpacity),
        label(upperFloor, upperMatrix, upperOpacity),
      ],
    );
  }
}

/// The lift shaft or stairwell between the two floors, and you travelling it.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.start,
    required this.end,
    required this.dot,
    required this.visible,
    required this.line,
    required this.dotColor,
  });

  final Offset start;
  final Offset end;
  final Offset dot;
  final double visible;
  final Color line;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (visible <= 0.01) {
      _dot(canvas, dot);
      return;
    }
    final glow = Paint()
      ..color = line.withValues(alpha: 0.35 * visible)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = line.withValues(alpha: visible)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(start, end, glow)
      ..drawLine(start, end, core)
      ..drawCircle(start, 7, Paint()..color = line.withValues(alpha: visible))
      ..drawCircle(end, 7, Paint()..color = line.withValues(alpha: visible));
    _dot(canvas, dot);
  }

  void _dot(Canvas canvas, Offset at) {
    canvas
      ..drawCircle(at, 18, Paint()..color = dotColor.withValues(alpha: 0.3))
      ..drawCircle(at, 10, Paint()..color = Colors.white)
      ..drawCircle(at, 8, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.start != start || old.end != end || old.dot != dot || old.visible != visible;
}
