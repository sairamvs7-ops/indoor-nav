import 'dart:io';

import 'package:flutter/material.dart';

import '../map/building_map.dart';

/// Where a floor's drawing comes from: the app's bundled assets (the sample
/// building) or a building folder on the phone.
typedef FloorImages = ImageProvider Function(String image);

FloorImages assetFloorImages() =>
    (image) => AssetImage(image);

FloorImages folderFloorImages(Directory folder) =>
    (image) => FileImage(File('${folder.path}${Platform.pathSeparator}$image'));

/// A floor drawing with something painted on top, pinch-zoomable. Taps are
/// reported in drawing pixels, the same coordinates places are stored in.
class BlueprintView extends StatelessWidget {
  const BlueprintView({
    super.key,
    required this.image,
    required this.imageWidth,
    required this.imageHeight,
    required this.overlay,
    this.label,
    this.onTap,
    this.transformationController,
    this.borderRadius = 16,
    this.interactive = true,
    this.onDrawStart,
    this.onDrawUpdate,
    this.onDrawEnd,
  });

  final ImageProvider image;
  final double imageWidth;
  final double imageHeight;

  /// Builds the painter for the overlay, given drawing-to-screen [scale].
  final CustomPainter Function(double scale) overlay;
  final String? label;
  final void Function(Offset imagePoint, double scale)? onTap;
  final TransformationController? transformationController;
  final double borderRadius;

  /// False while drawing, so one-finger drags draw instead of panning.
  final bool interactive;

  /// Finger-drawing callbacks, in drawing pixels.
  final void Function(Offset imagePoint)? onDrawStart;
  final void Function(Offset imagePoint)? onDrawUpdate;
  final VoidCallback? onDrawEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: imageWidth / imageHeight,
        child: ColoredBox(
          color: Colors.white,
          child: InteractiveViewer(
            transformationController: transformationController,
            maxScale: 8,
            panEnabled: interactive,
            scaleEnabled: interactive,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / imageWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: onTap == null ? null : (details) => onTap!(details.localPosition / scale, scale),
                  onPanStart: onDrawStart == null ? null : (d) => onDrawStart!(d.localPosition / scale),
                  onPanUpdate: onDrawUpdate == null ? null : (d) => onDrawUpdate!(d.localPosition / scale),
                  onPanEnd: onDrawEnd == null ? null : (_) => onDrawEnd!(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: image,
                        fit: BoxFit.fill,
                        semanticLabel: label,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                        ),
                      ),
                      CustomPaint(painter: overlay(scale)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The place nearest to [point] (drawing pixels) on [floor], within
/// [radius] screen pixels at [scale], ignoring corridor points unless asked.
MapNode? nodeNear(
  BuildingMap map,
  int floor,
  Offset point,
  double scale, {
  double radius = 24,
  bool includeCorridors = false,
}) {
  MapNode? nearest;
  var nearestDistance = radius / scale;
  for (final node in map.nodesOnFloor(floor)) {
    if (!includeCorridors && node.type == NodeType.corridor) continue;
    final distance = (Offset(node.x, node.y) - point).distance;
    if (distance <= nearestDistance) {
      nearest = node;
      nearestDistance = distance;
    }
  }
  return nearest;
}
