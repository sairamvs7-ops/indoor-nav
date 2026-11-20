import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../providers/navigation_provider.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isScanning = true;
  
  // Pre-initialize detector for performance
  late final cv.ArucoDetector _detector;
  late final cv.ArucoDictionary _dictionary;
  
  @override
  void initState() {
    super.initState();
    _setupDetector();
    _initCamera();
  }

  void _setupDetector() {
    _dictionary = cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_4X4_50);
    final parameters = cv.ArucoDetectorParameters.empty();
    _detector = cv.ArucoDetector.create(_dictionary, parameters);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    _controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    
    // Start processing frames
    _controller!.startImageStream((CameraImage image) {
      if (!_isProcessing && _isScanning) {
        _processFrame(image);
      }
    });
    
    if (mounted) setState(() {});
  }

  Future<void> _processFrame(CameraImage image) async {
    _isProcessing = true;

    try {
      final bytes = image.planes[0].bytes;
      final width = image.width;
      final height = image.height;
      final bytesPerRow = image.planes[0].bytesPerRow;

      // 1. Convert image to Mat (Grayscale Y-plane)
      // Handle potential padding in the camera buffer
      cv.Mat mat;
      if (bytesPerRow == width) {
        mat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, bytes);
      } else {
        // Manual copy to remove padding if bytesPerRow != width
        final cleanBytes = Uint8List(width * height);
        for (int i = 0; i < height; i++) {
          cleanBytes.setRange(
            i * width,
            (i + 1) * width,
            bytes.sublist(i * bytesPerRow, i * bytesPerRow + width),
          );
        }
        mat = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, cleanBytes);
      }

      // 2. Rotate Mat (Mobile sensors are usually landscape)
      mat = cv.rotate(mat, cv.ROTATE_90_CLOCKWISE);

      // 3. Detect
      final (corners, ids, rejected) = _detector.detectMarkers(mat);

      if (!ids.isEmpty) {
        final markerId = ids[0];
        debugPrint("SUCCESS: Detected Marker ID $markerId");
        _onMarkerDetected(markerId);
      }
    } catch (e) {
      debugPrint("Detection Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _onMarkerDetected(int id) {
    if (!_isScanning) return;
    
    setState(() => _isScanning = false);
    
    Provider.of<NavigationProvider>(context, listen: false).processScan(id);
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Scanning Overlay
          _buildOverlay(),
          
          // Dictionary Info
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Dictionary: 4x4 (50)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          
          // Close Button
          Positioned(
            top: 48,
            left: 24,
            child: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            if (!_isScanning)
              const Center(
                child: Icon(LucideIcons.checkCircle, color: Colors.green, size: 80),
              ),
          ],
        ),
      ),
    );
  }
}