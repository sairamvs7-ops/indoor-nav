import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'frame_utils.dart';
import 'marker_confirmer.dart';

/// Something that finds markers in a camera frame. The scanner depends on this
/// rather than on OpenCV directly, so it can be tested with a fake.
abstract interface class FrameDetector {
  Future<List<DetectedMarker>> detect(CameraImage image);

  /// Not called while a [detect] is still running.
  void dispose();
}

/// Finds ArUco markers (DICT_4X4_50, the printed set) in camera frames.
/// Works on the luminance plane only, so frames must be requested as
/// [ImageFormatGroup.yuv420] (Android YUV_420_888 and iOS NV12 both put Y in
/// plane 0). Detection runs on an OpenCV worker thread, not the UI isolate.
class MarkerDetector implements FrameDetector {
  MarkerDetector()
    : _dictionary = cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_4X4_50),
      _parameters = cv.ArucoDetectorParameters.empty() {
    _detector = cv.ArucoDetector.create(_dictionary, _parameters);
  }

  final cv.ArucoDictionary _dictionary;
  final cv.ArucoDetectorParameters _parameters;
  late final cv.ArucoDetector _detector;

  /// Copies the frame synchronously (the camera may reuse its buffer), then
  /// detects asynchronously. Every native object is freed before returning.
  @override
  Future<List<DetectedMarker>> detect(CameraImage image) async {
    final luma = image.planes.first;
    final mat = cv.Mat.create(rows: image.height, cols: image.width, type: cv.MatType.CV_8UC1);
    try {
      copyLumaRows(
        source: luma.bytes,
        bytesPerRow: luma.bytesPerRow,
        destination: mat.data,
        width: image.width,
        height: image.height,
      );
      final (corners, ids, rejected) = await _detector.detectMarkersAsync(mat);
      try {
        return [
          for (var i = 0; i < ids.length; i++)
            DetectedMarker(ids[i], polygonArea([for (final p in corners[i]) (p.x, p.y)])),
        ];
      } finally {
        corners.dispose();
        ids.dispose();
        rejected.dispose();
      }
    } finally {
      mat.dispose();
    }
  }

  @override
  void dispose() {
    _detector.dispose();
    _parameters.dispose();
    _dictionary.dispose();
  }
}
