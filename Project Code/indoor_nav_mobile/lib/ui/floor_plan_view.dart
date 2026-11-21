import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'app_theme.dart';
import 'blueprint_view.dart';
import 'generated_map_painter.dart';
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
      ),
    );
  }
}
