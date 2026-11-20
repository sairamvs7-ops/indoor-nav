import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/app.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/storage/building_repository.dart';
import 'package:indoor_nav_mobile/ui/app_settings.dart';
import 'package:indoor_nav_mobile/ui/app_theme.dart';

import '../support/test_map.dart';

void main() {
  late Directory temp;
  late BuildingRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('indoor_nav_ui');
    repo = BuildingRepository(Directory('${temp.path}/buildings'));
  });

  tearDown(() => temp.delete(recursive: true));

  /// Pumps the app and lets the real file reads finish.
  Future<AppSettings> pumpHome(WidgetTester tester, {Future<BuildingMap> Function()? loadSample}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final settings = AppSettings(file: File('${temp.path}/settings.json'));
    await tester.pumpWidget(
      IndoorNavApp(repository: repo, settings: settings, loadSample: loadSample ?? () async => loadRealMap()),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('a first launch offers to set up a building and shows the sample', (tester) async {
    await pumpHome(tester);

    expect(find.text(Brand.appName), findsOneWidget);
    expect(find.text('Set up your first building'), findsOneWidget);
    expect(find.text('Indoor Nav demo building'), findsOneWidget);
    expect(find.text('Copy to edit'), findsOneWidget);
  });

  testWidgets('lists buildings saved on the phone', (tester) async {
    await tester.runAsync(() async {
      final id = await repo.create('Main Block');
      final image = await repo.addImage(id, Uint8List.fromList([1]), extension: 'jpg');
      final json = await repo.readJson(id);
      json['floors'] = [
        {'level': 0, 'name': 'Ground', 'image': image, 'width': 10, 'height': 10},
      ];
      await repo.writeJson(id, json);
    });

    await pumpHome(tester);

    expect(find.text('Main Block'), findsOneWidget);
    expect(find.text('1 floor · 0 places'), findsOneWidget);
    expect(find.text('Set up your first building'), findsNothing);
  });

  testWidgets('explains a broken sample building', (tester) async {
    await pumpHome(tester, loadSample: () async => throw const MapFormatException('node 3: "x" must be a number'));

    expect(find.textContaining('node 3: "x" must be a number'), findsOneWidget);
  });

  testWidgets('switches between light and dark mode', (tester) async {
    final settings = await pumpHome(tester);

    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    final context = tester.element(find.text('Your buildings'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).colorScheme.primary, Brand.dark.primary);
  });

  test('theme settings are remembered between launches', () async {
    final file = File('${temp.path}/settings.json');
    AppSettings(file: file).setThemeMode(ThemeMode.light);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect((await AppSettings.load(file)).themeMode, ThemeMode.light);
    expect((await AppSettings.load(File('${temp.path}/missing.json'))).themeMode, ThemeMode.system);
  });

  test('both palettes use the brand colours', () {
    expect(buildTheme(Brightness.light).colorScheme.primary, const Color(0xFF586B45));
    expect(buildTheme(Brightness.light).colorScheme.secondary, const Color(0xFF005A32));
    expect(buildTheme(Brightness.light).scaffoldBackgroundColor, const Color(0xFFE5D9C2));
    expect(buildTheme(Brightness.dark).colorScheme.primary, const Color(0xFF89E900));
    expect(buildTheme(Brightness.dark).colorScheme.secondary, const Color(0xFFC7E9C0));
    expect(buildTheme(Brightness.dark).scaffoldBackgroundColor, const Color(0xFF222222));
  });
}
