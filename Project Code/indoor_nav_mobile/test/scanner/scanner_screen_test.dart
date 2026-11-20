import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/scanner/marker_confirmer.dart';
import 'package:indoor_nav_mobile/scanner/scanner_screen.dart';

import '../support/fake_camera.dart';

const _known = {1, 5, 13};

/// Opens the scanner from a button and records what it pops with.
class _Harness {
  Object? result = 'not popped';
  late ScriptedDetector detector;

  Future<void> open(WidgetTester tester, List<Object> script) async {
    detector = ScriptedDetector(script);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => ScannerScreen(isKnownMarker: _known.contains, createDetector: () => detector),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settleCamera(tester);
  }
}

/// Lets async camera start-up finish. pumpAndSettle can't be used while the
/// loading spinner animates.
Future<void> settleCamera(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> deliverFrames(WidgetTester tester, FakeCameraPlatform camera, int count) async {
  for (var i = 0; i < count; i++) {
    camera.sendFrame();
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  late FakeCameraPlatform camera;
  late _Harness harness;

  setUp(() {
    camera = FakeCameraPlatform();
    CameraPlatform.instance = camera;
    harness = _Harness();
  });

  testWidgets('opens the back camera with frames the detector can read on iPhone and Android', (tester) async {
    await harness.open(tester, const []);

    expect(camera.createdFor, ['back']);
    expect(camera.requestedFormat, ImageFormatGroup.yuv420);
    expect(find.text('Point the camera at a marker'), findsOneWidget);
  });

  testWidgets('pops with the marker id once it is confirmed in two frames', (tester) async {
    await harness.open(tester, const [
      [DetectedMarker(5, 900)],
      [DetectedMarker(5, 920)],
    ]);

    await deliverFrames(tester, camera, 2);
    expect(find.text('Marker 5 found'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(harness.result, 5);
    expect(camera.disposed, 1);
    expect(harness.detector.disposed, isTrue);
  });

  testWidgets('tells the user when a marker is not part of the map', (tester) async {
    await harness.open(tester, const [
      [DetectedMarker(35, 900)],
    ]);

    await deliverFrames(tester, camera, 1);

    expect(find.text("Marker 35 isn't part of this map"), findsOneWidget);
  });

  testWidgets('asks the user to hold steady while confirming', (tester) async {
    await harness.open(tester, const [
      [DetectedMarker(13, 900)],
    ]);

    await deliverFrames(tester, camera, 1);

    expect(find.text('Hold steady…'), findsOneWidget);
  });

  testWidgets('keeps scanning after a failed frame', (tester) async {
    await harness.open(tester, [
      Exception('opencv hiccup'),
      const [DetectedMarker(1, 500)],
      const [DetectedMarker(1, 500)],
    ]);

    await deliverFrames(tester, camera, 3);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(harness.result, 1);
  });

  testWidgets('explains a denied camera permission and retries', (tester) async {
    camera.initializeErrorCode = 'CameraAccessDenied';
    await harness.open(tester, const []);

    expect(find.textContaining('Allow camera access'), findsOneWidget);
    expect(find.byTooltip('Close scanner'), findsOneWidget);

    camera.initializeErrorCode = null;
    await tester.tap(find.text('Try again'));
    await settleCamera(tester);

    expect(find.text('Point the camera at a marker'), findsOneWidget);
  });

  testWidgets('says so when the device has no camera', (tester) async {
    CameraPlatform.instance = FakeCameraPlatform(cameras: const []);
    await harness.open(tester, const []);

    expect(find.text('No camera was found on this device.'), findsOneWidget);
  });

  testWidgets('toggles the flashlight, and explains when it is missing', (tester) async {
    await harness.open(tester, const []);

    await tester.tap(find.byTooltip('Turn flashlight on'));
    await tester.pump();
    await tester.tap(find.byTooltip('Turn flashlight off'));
    await tester.pump();

    expect(camera.flashModes, [FlashMode.torch, FlashMode.off]);

    camera.flashFails = true;
    await tester.tap(find.byTooltip('Turn flashlight on'));
    await tester.pump();

    expect(find.text('The flashlight is not available on this camera.'), findsOneWidget);
  });

  testWidgets('the close button returns nothing and releases the camera', (tester) async {
    await harness.open(tester, const []);

    await tester.tap(find.byTooltip('Close scanner'));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
    expect(camera.disposed, 1);
    expect(harness.detector.disposed, isTrue);
  });

  testWidgets('releases the camera in the background and reopens it on return', (tester) async {
    await harness.open(tester, const []);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(camera.disposed, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleCamera(tester);

    expect(camera.createdFor, ['back', 'back']);
    expect(find.text('Point the camera at a marker'), findsOneWidget);
  });

  testWidgets('going to the background mid-start drops that camera and restarts on return', (tester) async {
    // The first-launch permission dialog sends the app inactive while the camera starts.
    harness.detector = ScriptedDetector(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: ScannerScreen(isKnownMarker: _known.contains, createDetector: () => harness.detector),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settleCamera(tester);

    expect(camera.disposed, 1);
    expect(find.text('Point the camera at a marker'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleCamera(tester);

    expect(camera.createdFor, ['back', 'back']);
    expect(find.text('Point the camera at a marker'), findsOneWidget);
  });

  testWidgets('closing during the confirm delay returns the marker and pops only once', (tester) async {
    await harness.open(tester, const [
      [DetectedMarker(5, 900)],
      [DetectedMarker(5, 900)],
    ]);
    await deliverFrames(tester, camera, 2);

    await tester.tap(find.byTooltip('Close scanner'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(harness.result, 5);
    expect(find.text('open'), findsOneWidget, reason: 'the screen under the scanner must still be there');
  });

  testWidgets('shows an error instead of spinning forever on a non-camera failure', (tester) async {
    camera.listError = StateError('plugin not ready');
    await harness.open(tester, const []);

    expect(find.textContaining('The camera could not start'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
