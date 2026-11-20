import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_preview_cover.dart';
import 'marker_confirmer.dart';
import 'marker_detector.dart';
import 'scanner_overlay.dart';

const _defaultHint = 'Point the camera at a marker';
const _confirmDelay = Duration(milliseconds: 350);

/// Full-screen marker scanner. Pops with the confirmed marker id, or null if
/// the user closes it.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.isKnownMarker, this.createDetector = MarkerDetector.new});

  final bool Function(int markerId) isKnownMarker;
  final FrameDetector Function() createDetector;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late final FrameDetector _detector = widget.createDetector();
  late final MarkerConfirmer _confirmer = MarkerConfirmer(isKnown: widget.isKnownMarker);

  CameraController? _camera;
  bool _starting = false;
  bool _busy = false;
  bool _done = false;
  bool _disposed = false;
  bool _torchOn = false;
  String? _error;
  String _hint = _defaultHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startCamera());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    // A detection may still be running on the worker thread; free the
    // detector once it finishes instead of pulling it out from under it.
    if (!_busy) _detector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final camera = _camera;
      if (camera == null) return;
      setState(() {
        _camera = null;
        _torchOn = false;
      });
      unawaited(camera.dispose());
    } else if (state == AppLifecycleState.resumed && _camera == null && !_done) {
      unawaited(_startCamera());
    }
  }

  Future<void> _startCamera() async {
    if (_starting) return;
    _starting = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera was found on this device.');
        return;
      }
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_onFrame);
      if (!mounted) return;
      // The app went to the background mid-start (the first-launch permission
      // dialog does this). The OS may have revoked the camera, so drop this
      // controller; the resume handler starts a fresh one.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      final started = controller;
      controller = null; // owned by state now
      setState(() {
        _camera = started;
        _error = null;
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = describeCameraError(e));
    } catch (e) {
      // Plugin bugs or platform errors that aren't CameraExceptions must still
      // reach the screen, or the spinner would run forever.
      if (mounted) setState(() => _error = 'The camera could not start ($e).');
    } finally {
      unawaited(controller?.dispose());
      _starting = false;
    }
  }

  void _onFrame(CameraImage image) {
    if (_busy || _done || _disposed) return;
    _busy = true;
    unawaited(_process(image));
  }

  Future<void> _process(CameraImage image) async {
    try {
      final markers = await _detector.detect(image);
      if (_disposed || _done) return;
      final confirmed = _confirmer.addFrame(markers);
      if (confirmed != null) {
        await _finish(confirmed);
        return;
      }
      final unknown = _confirmer.firstUnknown(markers);
      final hint = unknown != null
          ? "Marker $unknown isn't part of this map"
          : (markers.isEmpty ? _defaultHint : 'Hold steady…');
      if (hint != _hint && mounted) setState(() => _hint = hint);
    } on Exception catch (e) {
      debugPrint('Marker detection failed, skipping frame: $e');
    } finally {
      _busy = false;
      if (_disposed) _detector.dispose();
    }
  }

  Future<void> _finish(int markerId) async {
    _done = true;
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) setState(() => _hint = 'Marker $markerId found');
    await Future<void>.delayed(_confirmDelay);
    // Pop only if this screen is still on top, so we never pop the screen below.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(markerId);
  }

  void _close() {
    if (_done) return; // the confirmed marker is about to be returned
    Navigator.of(context).pop();
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } on CameraException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('The flashlight is not available on this camera.')));
    }
  }

  void _retry() {
    setState(() => _error = null);
    unawaited(_startCamera());
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return PopScope(
      // Block back gestures during the short confirm delay, for the same reason.
      canPop: !_done,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_error != null)
              CameraErrorView(message: _error!, onRetry: _retry)
            else if (camera == null)
              const Center(child: CircularProgressIndicator(color: Colors.white))
            else ...[
              CameraPreviewCover(controller: camera),
              ScannerOverlay(hint: _hint, confirmed: _done),
            ],
            ScannerTopBar(torchOn: _torchOn, onClose: _close, onToggleTorch: camera == null ? null : _toggleTorch),
          ],
        ),
      ),
    );
  }
}

String describeCameraError(CameraException e) {
  switch (e.code) {
    case 'CameraAccessDenied':
    case 'CameraAccessDeniedWithoutPrompt':
    case 'CameraAccessRestricted':
      return 'Camera access is turned off. Allow camera access for Indoor Nav in Settings, then try again.';
    default:
      return 'The camera could not start (${e.description ?? e.code}).';
  }
}
