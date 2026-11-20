import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'route_painter.dart';

/// Tap radius for picking a node, in logical pixels.
const _tapRadius = 24.0;

/// One floor of the hand-drawn plan with the route on top. Pinch to zoom,
/// tap a place to pick it.
class FloorPlanView extends StatelessWidget {
  const FloorPlanView({
    super.key,
    required this.map,
    required this.floor,
    required this.route,
    this.currentId,
    this.destinationId,
    this.onNodeTap,
  });

  final BuildingMap map;
  final Floor floor;
  final List<int> route;
  final int? currentId;
  final int? destinationId;
  final ValueChanged<MapNode>? onNodeTap;

  MapNode? _nodeNear(Offset position, double scale) {
    MapNode? nearest;
    var nearestDistance = _tapRadius;
    for (final node in map.nodesOnFloor(floor.level)) {
      final distance = (Offset(node.x * scale, node.y * scale) - position).distance;
      if (distance <= nearestDistance) {
        nearest = node;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final colors = RouteColors.of(Theme.of(context).colorScheme);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: floor.width / floor.height,
        child: InteractiveViewer(
          maxScale: 5,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / floor.width;
              return GestureDetector(
                onTapUp: onNodeTap == null
                    ? null
                    : (details) {
                        final node = _nodeNear(details.localPosition, scale);
                        if (node != null) onNodeTap!(node);
                      },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      floor.image,
                      fit: BoxFit.fill,
                      semanticLabel: '${floor.name} plan',
                      errorBuilder: (context, error, stack) => ColoredBox(
                        color: Colors.grey.shade300,
                        child: Center(child: Text('Missing image: ${floor.image}')),
                      ),
                    ),
                    CustomPaint(
                      painter: RoutePainter(
                        map: map,
                        floor: floor,
                        route: route,
                        colors: colors,
                        currentId: currentId,
                        destinationId: destinationId,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
