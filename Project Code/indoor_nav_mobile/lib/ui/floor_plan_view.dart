import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'app_theme.dart';
import 'blueprint_view.dart';
import 'route_painter.dart';

/// One floor's drawing with the route on top. Pinch to zoom, tap a place to
/// pick it.
class FloorPlanView extends StatelessWidget {
  const FloorPlanView({
    super.key,
    required this.map,
    required this.floor,
    required this.images,
    required this.route,
    this.currentId,
    this.destinationId,
    this.onNodeTap,
  });

  final BuildingMap map;
  final Floor floor;
  final FloorImages images;
  final List<int> route;
  final int? currentId;
  final int? destinationId;
  final ValueChanged<MapNode>? onNodeTap;

  @override
  Widget build(BuildContext context) {
    final colors = MapColors.resolve(context);
    return BlueprintView(
      image: images(floor.image),
      imageWidth: floor.width,
      imageHeight: floor.height,
      label: '${floor.name} plan',
      onTap: onNodeTap == null
          ? null
          : (point, scale) {
              final node = nodeNear(map, floor.level, point, scale);
              if (node != null) onNodeTap!(node);
            },
      overlay: (_) => RoutePainter(
        map: map,
        floor: floor,
        route: route,
        colors: colors,
        currentId: currentId,
        destinationId: destinationId,
      ),
    );
  }
}
