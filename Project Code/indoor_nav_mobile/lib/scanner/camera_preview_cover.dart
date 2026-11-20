import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Fills the screen with the camera preview, cropping instead of letterboxing.
class CameraPreviewCover extends StatelessWidget {
  const CameraPreviewCover({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    // previewSize is reported in sensor (landscape) orientation.
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: portrait ? previewSize.height : previewSize.width,
          height: portrait ? previewSize.width : previewSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
