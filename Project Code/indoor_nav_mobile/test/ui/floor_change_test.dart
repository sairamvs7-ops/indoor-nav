import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/ui/app_theme.dart';
import 'package:indoor_nav_mobile/ui/blueprint_view.dart';
import 'package:indoor_nav_mobile/ui/floor_change_view.dart';

import '../support/test_map.dart';

void main() {
  group('FloorChangePose', () {
    test('starts and ends as a flat top view', () {
      expect(FloorChangePose.at(0).tilt, 0);
      expect(FloorChangePose.at(0).spread, 0);
      expect(FloorChangePose.at(1).tilt, closeTo(0, 1e-9));
      expect(FloorChangePose.at(1).focus, 1);
    });

    test('tilts into a side view and moves you between the floors', () {
      final middle = FloorChangePose.at(0.5);

      expect(middle.tilt, FloorChangePose.maxTilt);
      expect(middle.spread, 1);
      expect(middle.travel, closeTo(0.5, 1e-9));
      expect(FloorChangePose.at(0.3).travel, 0);
      expect(FloorChangePose.at(0.7).travel, 1);
    });
  });

  testWidgets('plays the floor change and closes by itself', (tester) async {
    final map = loadRealMap();
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            screen = context;
            return const Scaffold(body: Text('navigation'));
          },
        ),
      ),
    );

    final done = showFloorChange(screen, map: map, images: assetFloorImages(), from: map.node(9), to: map.node(23));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lift up to First Floor'), findsOneWidget);
    expect(find.byType(FloorChangeView), findsOneWidget);

    await tester.pump(floorChangeDuration);
    await tester.pumpAndSettle();
    await done;

    expect(find.byType(FloorChangeView), findsNothing);
    expect(find.text('navigation'), findsOneWidget);
  });

  testWidgets('tapping skips the floor change', (tester) async {
    final map = loadRealMap();
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            screen = context;
            return const Scaffold(body: Text('navigation'));
          },
        ),
      ),
    );

    unawaited(showFloorChange(screen, map: map, images: assetFloorImages(), from: map.node(25), to: map.node(11)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stairs down to Ground Floor'), findsOneWidget);

    await tester.tap(find.text('Tap to skip'));
    await tester.pumpAndSettle();

    expect(find.byType(FloorChangeView), findsNothing);
  });
}
