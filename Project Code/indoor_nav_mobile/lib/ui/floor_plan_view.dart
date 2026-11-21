import 'dart:async';

import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'app_theme.dart';
import 'blueprint_view.dart';
import 'generated_map_painter.dart';
import 'route_painter.dart';

/// One floor's drawing with the route on top, and a dot running from you to
/// the next stop. Pinch to zoom, tap a place to pick it.
class FloorPlanView extends StatefulWidget {
  const FloorPlanView({
    super.key,
    required this.map,
    required this.floor,
    required this.images,
    required this.route,
    this.currentId,
    this.destinationId,
    this.live,
    this.onNodeTap,
  });

  final BuildingMap map;
  final Floor floor;
  final FloorImages images;
  final List<int> route;
  final int? currentId;
  final int? destinationId;

  /// Where you are while walking, between places (drawing pixels).
  final Offset? live;
  final ValueChanged<MapNode>? onNodeTap;

  @override
  State<FloorPlanView> createState() => _FloorPlanViewState();
}

/// How many times the guide dot runs after the way ahead changes, before it
/// rests (so it doesn't keep the screen busy).
const int _guideRuns = 3;

class _FloorPlanViewState extends State<FloorPlanView> with SingleTickerProviderStateMixin {
  late final AnimationController _guide = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..addStatusListener(_onGuideStatus);
  int _runsLeft = 0;
  List<Offset> _path = const [];

  BuildingMap get map => widget.map;
  Floor get floor => widget.floor;
  FloorImages get images => widget.images;
  List<int> get route => widget.route;
  int? get currentId => widget.currentId;
  int? get destinationId => widget.destinationId;
  Offset? get live => widget.live;
  ValueChanged<MapNode>? get onNodeTap => widget.onNodeTap;

  @override
  void initState() {
    super.initState();
    _updateGuide();
  }

  @override
  void didUpdateWidget(FloorPlanView old) {
    super.didUpdateWidget(old);
    if (old.route != widget.route || old.floor != widget.floor || old.currentId != widget.currentId) _updateGuide();
  }

  @override
  void dispose() {
    _guide.dispose();
    super.dispose();
  }

  /// The way from you to the next stop on this floor: the route up to the
  /// first place that isn't a corridor point, or the lift/stairs.
  void _updateGuide() {
    final path = <Offset>[];
    if (route.length >= 2 && map.node(route.first).floor == floor.level) {
      for (final (i, id) in route.indexed) {
        final n = map.node(id);
        if (n.floor != floor.level) break;
        path.add(Offset(n.x, n.y));
        if (i > 0 && n.type != NodeType.corridor) break;
      }
    }
    _path = path;
    if (path.length >= 2) {
      _runsLeft = _guideRuns;
      unawaited(_guide.forward(from: 0));
    } else {
      _runsLeft = 0;
      _guide.reset();
    }
  }

  void _onGuideStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _runsLeft--;
    if (_runsLeft > 0) {
      unawaited(_guide.forward(from: 0));
    } else {
      _guide.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MapColors.resolve(context);
    // Floors with a generated map are drawn from it; the blueprint image is
    // only used for floors made before maps were generated.
    final generated = floor.hasGeneratedMap;
    final style = MapStyle.of(Theme.of(context).brightness);
    final names = generated ? regionNames(map, floor.level) : const <String, String>{};
    return BlueprintView(
      image: generated ? null : images(floor.image),
      underlay: generated
          ? (_) => GeneratedMapPainter(regions: floor.regions, drawingWidth: floor.width, style: style, names: names)
          : null,
      imageWidth: floor.width,
      imageHeight: floor.height,
      label: '${floor.name} plan',
      onTap: onNodeTap == null
          ? null
          : (point, scale) {
              var node = nodeNear(map, floor.level, point, scale);
              // On a generated map, tapping anywhere in a room picks it.
              if (node == null && generated) {
                for (final n in map.nodesOnFloor(floor.level)) {
                  final region = floor.region(n.region);
                  if (region != null && region.kind != RegionKind.corridor && region.contains((x: point.dx, y: point.dy))) {
                    node = n;
                    break;
                  }
                }
              }
              if (node != null) onNodeTap!(node);
            },
      overlay: (_) => RoutePainter(
        map: map,
        floor: floor,
        route: route,
        colors: colors,
        currentId: currentId,
        destinationId: destinationId,
        live: live,
        guide: live == null ? _path : const [],
        guideProgress: _guide,
      ),
    );
  }
}
