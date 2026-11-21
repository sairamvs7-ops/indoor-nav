import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/scanner/marker_confirmer.dart';
import 'package:indoor_nav_mobile/scanner/scanner_screen.dart';
import 'package:indoor_nav_mobile/ui/app_theme.dart';
import 'package:indoor_nav_mobile/ui/blueprint_view.dart';
import 'package:indoor_nav_mobile/ui/floor_plan_view.dart';
import 'package:indoor_nav_mobile/ui/navigation_screen.dart';

import '../support/fake_camera.dart';
import '../support/test_map.dart';

String instructionText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('instruction'))).data!;

Future<void> pumpApp(WidgetTester tester, BuildingMap map, {ScriptedDetector? detector}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      home: NavigationScreen(
        map: map,
        images: assetFloorImages(),
        createDetector: () => detector ?? ScriptedDetector(const []),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the scanner from the home screen and feeds it [frames] frames.
Future<void> scanFromHome(WidgetTester tester, FakeCameraPlatform camera, {required int frames}) async {
  await tester.tap(find.text('Scan marker'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < frames; i++) {
    camera.sendFrame();
    await tester.pump();
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> pickPlace(WidgetTester tester, {required String button, required String place}) async {
  await tester.tap(find.byTooltip(button).evaluate().isEmpty ? find.text(button) : find.byTooltip(button));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), place);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, place));
  await tester.pumpAndSettle();
}

void main() {
  final realMap = loadRealMap();

  testWidgets('starts with the building name and the ground floor plan', (tester) async {
    await pumpApp(tester, realMap);

    expect(find.text(realMap.name), findsOneWidget);
    expect(tester.widget<FloorPlanView>(find.byType(FloorPlanView)).floor.level, 0);
    expect(instructionText(tester), 'Choose a destination, then scan the nearest marker.');
    expect(find.byType(FloorPlanView), findsOneWidget);
    expect(find.text('Scan marker'), findsOneWidget);
  });

  testWidgets('choosing a destination and location shows the route and steps', (tester) async {
    await pumpApp(tester, realMap);

    await pickPlace(tester, button: 'Choose a destination', place: 'Room 104');

    expect(instructionText(tester), 'Scan the nearest marker to start navigating to Room 104.');
    expect(find.text('Going to Room 104'), findsOneWidget);

    await pickPlace(tester, button: 'Set my location', place: 'Entry 1');

    expect(instructionText(tester), 'Walk to Lift 1');
    expect(find.textContaining('You are at Entry 1'), findsOneWidget);
    expect(find.textContaining('Route · '), findsOneWidget);
  });

  testWidgets('"I\'m at" advances one stop and the map follows to the next floor', (tester) async {
    await pumpApp(tester, realMap);
    await pickPlace(tester, button: 'Choose a destination', place: 'Room 104');
    await pickPlace(tester, button: 'Set my location', place: 'Lift 1');

    expect(instructionText(tester), 'Take Lift 1 up to the First Floor');

    await tester.tap(find.text('Next: Lift 3'));
    await tester.pumpAndSettle();

    expect(instructionText(tester), 'Walk to Entry 3');
    expect(tester.widget<FloorPlanView>(find.byType(FloorPlanView)).floor.level, 1);
  });

  testWidgets('the floor switcher changes the plan shown', (tester) async {
    await pumpApp(tester, realMap);

    await tester.tap(find.byKey(const ValueKey('floor-1')));
    await tester.pumpAndSettle();

    expect(tester.widget<FloorPlanView>(find.byType(FloorPlanView)).floor.level, 1);
  });

  testWidgets('tapping a place on the plan makes it the destination', (tester) async {
    await pumpApp(tester, realMap);
    final entry = realMap.node(13);
    final plan = find.byType(FloorPlanView);
    final scale = tester.getSize(plan).width / realMap.floor(0).width;

    await tester.tapAt(tester.getTopLeft(plan) + Offset(entry.x * scale, entry.y * scale));
    await tester.pumpAndSettle();

    expect(find.text('Going to Entry 1'), findsOneWidget);
  });

  testWidgets('scanning a marker on the home screen locates you and routes you', (tester) async {
    final camera = FakeCameraPlatform();
    CameraPlatform.instance = camera;
    final detector = ScriptedDetector(const [
      [DetectedMarker(13, 800)],
      [DetectedMarker(13, 820)],
      [DetectedMarker(18, 900)],
      [DetectedMarker(18, 900)],
    ]);
    await pumpApp(tester, realMap, detector: detector);
    await pickPlace(tester, button: 'Choose a destination', place: 'Room 104');

    await scanFromHome(tester, camera, frames: 2);

    expect(find.text('You are at Entry 1'), findsOneWidget);
    expect(instructionText(tester), 'Walk to Lift 1');

    await scanFromHome(tester, camera, frames: 2);

    expect(find.text('You have arrived at Room 104'), findsOneWidget);
    expect(instructionText(tester), 'You have arrived at Room 104.');
  });

  testWidgets('closing the scanner without a marker changes nothing', (tester) async {
    CameraPlatform.instance = FakeCameraPlatform();
    await pumpApp(tester, realMap);

    await tester.tap(find.text('Scan marker'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byTooltip('Close scanner'));
    await tester.pumpAndSettle();

    expect(instructionText(tester), 'Choose a destination, then scan the nearest marker.');
  });

  testWidgets('route preference chips reroute and explain a missing step-free route', (tester) async {
    await pumpApp(tester, realMap);
    await pickPlace(tester, button: 'Choose a destination', place: 'Room 104');
    await pickPlace(tester, button: 'Set my location', place: 'Stairs 1');

    await tester.tap(find.text('Avoid lifts'));
    await tester.pumpAndSettle();

    expect(instructionText(tester), 'Take Stairs 1 up to the First Floor');

    await tester.tap(find.text('Step-free'));
    await tester.pumpAndSettle();

    expect(instructionText(tester), isNot(contains('Stairs 1 up')));
  });

  testWidgets('Re-locate keeps the destination and opens the scanner', (tester) async {
    CameraPlatform.instance = FakeCameraPlatform();
    await pumpApp(tester, realMap);
    await pickPlace(tester, button: 'Choose a destination', place: 'Room 104');
    await pickPlace(tester, button: 'Set my location', place: 'Entry 1');

    await tester.scrollUntilVisible(find.text('Re-locate'), 300);
    await tester.tap(find.text('Re-locate'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(ScannerScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Close scanner'));
    await tester.pumpAndSettle();
    expect(instructionText(tester), 'Scan the nearest marker to start navigating to Room 104.');
    expect(find.text('Going to Room 104'), findsOneWidget);
  });

  testWidgets('"Start over" clears the destination and location', (tester) async {
    await pumpApp(tester, realMap);
    await pickPlace(tester, button: 'Choose a destination', place: 'Room 104');

    await tester.tap(find.byTooltip('Start over'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a destination'), findsOneWidget);
  });

  test('describeCameraError explains a denied permission in plain words', () {
    final denied = CameraException('CameraAccessDenied', 'User denied');
    final other = CameraException('cameraNotFound', 'No camera');

    expect(describeCameraError(denied), contains('Allow camera access'));
    expect(describeCameraError(other), contains('No camera'));
  });
}
