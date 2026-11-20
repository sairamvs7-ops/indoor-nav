import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:indoor_nav_mobile/scanner/marker_confirmer.dart';
import 'package:indoor_nav_mobile/scanner/marker_detector.dart';

/// Stands in for the native camera plugin. Frames are pushed with [sendFrame].
class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({List<CameraDescription>? cameras, this.initializeErrorCode})
    : cameras =
          cameras ??
          const [
            CameraDescription(name: 'front', lensDirection: CameraLensDirection.front, sensorOrientation: 270),
            CameraDescription(name: 'back', lensDirection: CameraLensDirection.back, sensorOrientation: 90),
          ];

  final List<CameraDescription> cameras;
  String? initializeErrorCode;
  bool flashFails = false;

  final List<String> createdFor = [];
  final List<FlashMode> flashModes = [];
  ImageFormatGroup? requestedFormat;
  int disposed = 0;

  final _initialized = StreamController<CameraInitializedEvent>.broadcast();
  final _frames = StreamController<CameraImageData>.broadcast();
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  final _orientation = StreamController<DeviceOrientationChangedEvent>.broadcast();

  /// Thrown from [availableCameras] when set, to simulate a non-camera error.
  Object? listError;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    final error = listError;
    if (error != null) throw error;
    return cameras;
  }

  @override
  Future<int> createCameraWithSettings(CameraDescription description, MediaSettings settings) async {
    createdFor.add(description.name);
    return createdFor.length;
  }

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    requestedFormat = imageFormatGroup;
    final error = initializeErrorCode;
    if (error != null) throw PlatformException(code: error, message: 'fake $error');
    _initialized.add(CameraInitializedEvent(cameraId, 640, 480, ExposureMode.auto, true, FocusMode.auto, true));
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) => _initialized.stream;

  // Real plugin streams never close; the controller awaits `.first` on them.
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => _orientation.stream;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId, {CameraImageStreamOptions? options}) => _frames.stream;

  @override
  bool supportsImageStreaming() => true;

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    if (flashFails) throw PlatformException(code: 'flashUnavailable');
    flashModes.add(mode);
  }

  @override
  Future<void> dispose(int cameraId) async => disposed++;

  void sendFrame() => _frames.add(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
      planes: [CameraImagePlane(bytes: Uint8List(12), bytesPerRow: 4)],
      width: 4,
      height: 3,
    ),
  );
}

/// Returns scripted detections, one list per frame, then nothing.
class ScriptedDetector implements FrameDetector {
  ScriptedDetector(this.script);

  final List<Object> script; // List<DetectedMarker> or an Exception to throw
  int calls = 0;
  bool disposed = false;

  @override
  Future<List<DetectedMarker>> detect(CameraImage image) async {
    final step = calls < script.length ? script[calls] : const <DetectedMarker>[];
    calls++;
    if (step is Exception) throw step;
    return step as List<DetectedMarker>;
  }

  @override
  void dispose() => disposed = true;
}
