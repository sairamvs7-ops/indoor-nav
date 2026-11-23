// Renders the REAL app screens (lib/ is untouched) as PNG frames and frame
// sequences for the Indoor Nav launch film. Hardware is faked the same way the
// app's own tests fake it: a scripted marker detector and scripted motion
// sensors. Everything drawn is the app's own widgets and painters.
//
// Run from Project Code/indoor_nav_mobile:
//   flutter test brag-output/launch-film/work/capture_film_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/mapgen/generate_regions.dart';
import 'package:indoor_nav_mobile/navigation/live_walk.dart';
import 'package:indoor_nav_mobile/navigation/motion.dart';
import 'package:indoor_nav_mobile/scanner/marker_confirmer.dart';
import 'package:indoor_nav_mobile/setup/building_draft.dart';
import 'package:indoor_nav_mobile/setup/floor_editor_screen.dart';
import 'package:indoor_nav_mobile/storage/building_repository.dart';
import 'package:indoor_nav_mobile/ui/generated_map_painter.dart';
import 'package:indoor_nav_mobile/ui/app_settings.dart';
import 'package:indoor_nav_mobile/ui/app_theme.dart';
import 'package:indoor_nav_mobile/ui/buildings_screen.dart';
import 'package:indoor_nav_mobile/ui/navigation_screen.dart';

import '../../../test/support/fake_camera.dart';
import '../../../test/support/test_map.dart';

const fontDir = 'C:/Users/Sai/develop/flutter/bin/cache/artifacts/material_fonts';
const outDir = 'brag-output/launch-film/work/frames';
final boundaryKey = GlobalKey();

bool _fontsLoaded = false;
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<ByteData> f(String name) async => ByteData.sublistView(File('$fontDir/$name').readAsBytesSync());
  for (final family in ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family);
    for (final w in ['regular', 'medium', 'bold', 'black', 'light']) {
      loader.addFont(f('roboto-$w.ttf'));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'));
  await icons.load();
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
    final labels = labelMeta(boundary);
    if (labels.isNotEmpty) File('$outDir/$name.labels.json').writeAsStringSync(jsonEncode(labels));
  });
}

/// The test engine draws text that names no font family as boxes. The map
/// painter's room labels name none, so record where each one is and what it
/// says (re-running the painter's own label layout), for patch_labels.py to
/// redraw them in Roboto, the phone's system font.
BuildingDraft? editorDraft;

List<Map<String, Object>> labelMeta(RenderObject root) {
  final out = <Map<String, Object>>[];
  void visit(RenderObject o) {
    if (o is RenderCustomPaint && o.hasSize) {
      final ep = o.painter ?? o.foregroundPainter;
      final draft = editorDraft;
      if (ep != null && ep.runtimeType.toString() == '_EditorPainter' && draft != null) {
        // FloorEditorScreen's place markers: number in the circle, name 21 px below.
        final dyn = ep as dynamic;
        final scale = dyn.scale as double;
        final level = dyn.level as int;
        final m = o.getTransformTo(root);
        final k = m.getMaxScaleOnAxis() * 2.5;
        for (final node in draft.nodesOn(level)) {
          if (node.type == NodeType.corridor) continue;
          final c = Offset(node.x * scale, node.y * scale);
          final cc = MatrixUtils.transformPoint(m, c) * 2.5;
          final r = 8.5 * k;
          out.add({
            'text': node.marker?.toString() ?? '–',
            'box': [cc.dx - r, cc.dy - r, cc.dx + r, cc.dy + r],
            'centre': [cc.dx, cc.dy],
            'fontPx': 10 * k,
            'maxWidthPx': 200 * k,
            'ink': node.type.isVertical ? [0, 0, 0] : [255, 255, 255],
            'pad': 0,
          });
          final tp = TextPainter(
            text: TextSpan(text: node.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: 120);
          final nc = c + const Offset(0, 21);
          final a = MatrixUtils.transformPoint(m, nc - Offset(tp.width / 2, tp.height / 2)) * 2.5;
          final b = MatrixUtils.transformPoint(m, nc + Offset(tp.width / 2, tp.height / 2)) * 2.5;
          final mid = MatrixUtils.transformPoint(m, nc) * 2.5;
          out.add({
            'text': node.name,
            'box': [a.dx, a.dy, b.dx, b.dy],
            'centre': [mid.dx, mid.dy],
            'fontPx': 10 * k,
            'maxWidthPx': 1000 * k,
            'ink': [0, 0, 0],
          });
          tp.dispose();
        }
      }
      for (final p in [o.painter, o.foregroundPainter]) {
        if (p is! GeneratedMapPainter) continue;
        final scale = o.size.width / p.drawingWidth;
        final m = o.getTransformTo(root);
        final k = m.getMaxScaleOnAxis() * 2.5;
        for (final region in p.regions) {
          final name = p.names[region.id];
          if (name == null || region.kind == RegionKind.ignored) continue;
          final xs = region.outline.map((q) => q.x * scale), ys = region.outline.map((q) => q.y * scale);
          final bounds = Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max));
          if (bounds.width < 24 || bounds.height < 12) continue;
          final fs = math.min(14.0, math.max(8.0, bounds.shortestSide / 5));
          final tp = TextPainter(
            text: TextSpan(text: name, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600)),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 2,
            ellipsis: '…',
          )..layout(maxWidth: bounds.width * 0.9);
          final c = Offset(region.centre.x * scale, region.centre.y * scale);
          final tl = c - Offset(tp.width / 2, tp.height / 2 - 12);
          final a = MatrixUtils.transformPoint(m, tl);
          final b = MatrixUtils.transformPoint(m, tl + Offset(tp.width, tp.height));
          final mid = MatrixUtils.transformPoint(m, tl + Offset(tp.width / 2, tp.height / 2));
          out.add({
            'text': name,
            'box': [a.dx * 2.5, a.dy * 2.5, b.dx * 2.5, b.dy * 2.5],
            'centre': [mid.dx * 2.5, mid.dy * 2.5],
            'fontPx': fs * k,
            'maxWidthPx': bounds.width * 0.9 * k,
          });
          tp.dispose();
        }
      }
    }
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

/// A frame sequence at [fps]: name_0000.png, name_0001.png, ...
Future<void> seq(WidgetTester tester, String name, int frames, {int fps = 30}) async {
  final step = Duration(microseconds: 1000000 ~/ fps);
  Directory('$outDir/$name').createSync(recursive: true);
  for (var i = 0; i < frames; i++) {
    await shot(tester, '$name/${i.toString().padLeft(4, '0')}');
    await tester.pump(step);
  }
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

TextStyle? _r(TextStyle? s) => (s ?? const TextStyle()).copyWith(fontFamily: 'Roboto');
ButtonStyle? _rb(ButtonStyle? b) {
  if (b == null) return null;
  return b.copyWith(textStyle: WidgetStatePropertyAll(_r(b.textStyle?.resolve(<WidgetState>{}))));
}

ThemeData robotoTheme(ThemeData t) => t.copyWith(
  appBarTheme: t.appBarTheme.copyWith(titleTextStyle: _r(t.appBarTheme.titleTextStyle)),
  filledButtonTheme: FilledButtonThemeData(style: _rb(t.filledButtonTheme.style)),
  outlinedButtonTheme: OutlinedButtonThemeData(style: _rb(t.outlinedButtonTheme.style)),
  textButtonTheme: TextButtonThemeData(style: _rb(t.textButtonTheme.style ?? const ButtonStyle())),
  chipTheme: t.chipTheme.copyWith(labelStyle: _r(t.chipTheme.labelStyle), secondaryLabelStyle: _r(t.chipTheme.secondaryLabelStyle)),
  snackBarTheme: t.snackBarTheme.copyWith(contentTextStyle: _r(t.snackBarTheme.contentTextStyle)),
  floatingActionButtonTheme: t.floatingActionButtonTheme.copyWith(extendedTextStyle: _r(t.floatingActionButtonTheme.extendedTextStyle)),
  segmentedButtonTheme: SegmentedButtonThemeData(style: _rb(t.segmentedButtonTheme.style ?? const ButtonStyle())),
);

/// The same steps the app's home screen runs for the Sample building
/// (BuildingsScreen._generateSampleMaps): a generated map on every floor.
Future<BuildingMap> sampleWithMaps(BuildingMap sample) async {
  final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(sample.toJson())) as Map);
  final draft = BuildingDraft.fromJson(json, save: (_) async {}, saveDelay: Duration.zero);
  for (final floor in sample.floors) {
    draft.setGeneratedMap(floor.level, await generateRegions(File(floor.image).readAsBytesSync()));
    if (draft.floor(floor.level).regions.any((r) => r.kind == RegionKind.corridor)) {
      for (final e in sample.edges) {
        final a = sample.node(e.from), b = sample.node(e.to);
        if (!e.automatic && a.floor == floor.level && b.floor == floor.level && draft.isConnected(a.id, b.id)) {
          draft.togglePath(a.id, b.id);
        }
      }
    }
    for (final region in [...draft.floor(floor.level).regions]) {
      if (region.kind == RegionKind.stairs && draft.placeFor(region.id, floor.level) == null) {
        draft.setRegionKind(floor.level, region.id, RegionKind.ignored);
      }
    }
  }
  reviewStairs(draft);
  reviewNames(draft);
  return BuildingMap.fromJson(draft.toJson());
}

/// The admin review step for the sample's stairs, done with the floor
/// editor's own operations (Trace area, mark as stairs / not used). The
/// hand-drawn plan has two hatched stairwells per floor: a wide one on the
/// left (Stairs 1 / Stairs 3) and a narrow one at the bottom right
/// (Stairs 2 / Stairs 4). The blueprint auto-draft finds only part of them,
/// so each is traced from the plan (drawing pixels) and the stairs place is
/// linked to it. Places keep their positions, so routes are unchanged.
const Map<int, (double, double, double, double)> stairwells = {
  11: (52, 262, 200, 410), // Stairs 1, ground floor, left
  12: (648, 328, 713, 410), // Stairs 2, ground floor, bottom right
  25: (52, 250, 205, 400), // Stairs 3, first floor, left
  26: (610, 290, 715, 398), // Stairs 4, first floor, bottom right
};

void reviewStairs(BuildingDraft draft) {
  for (final MapEntry(key: id, value: (l, t, r, b)) in stairwells.entries) {
    final node = draft.nodes[id];
    if (node == null) continue;
    final level = node.floor;
    for (final region in [...draft.floor(level).regions]) {
      if (region.kind == RegionKind.corridor || region.kind == RegionKind.ignored) continue;
      final xs = region.outline.map((q) => q.x), ys = region.outline.map((q) => q.y);
      final rl = xs.reduce(math.min), rr = xs.reduce(math.max), rt = ys.reduce(math.min), rb = ys.reduce(math.max);
      final ix = math.max(0.0, math.min(rr, r) - math.max(rl, l)), iy = math.max(0.0, math.min(rb, b) - math.max(rt, t));
      final area = (rr - rl) * (rb - rt);
      if (area <= 0 || ix * iy / area < 0.6) continue; // not mostly inside the stairwell
      final place = draft.placeFor(region.id, level);
      if (place != null && place.id != id) continue; // another place's room
      if (place != null) place.region = null;
      draft.setRegionKind(level, region.id, RegionKind.ignored);
    }
    final traced = draft.addRegion(level, [(x: l, y: t), (x: r, y: t), (x: r, y: b), (x: l, y: b)], kind: RegionKind.stairs);
    node.region = traced;
  }
}

/// The admin review step for names, as done in the floor editor's Map mode
/// (tap an area: name it, or mark it "not used"). Checked against the
/// hand-drawn plan: Room 1 (Node-1) must own its room, and the lobby beside
/// it, where the Lift 2 (Node-10) and Entry 2 (Node-14) doorways are, is not
/// a room, so Entry 2 must not label it.
void reviewNames(BuildingDraft draft) {
  final room1 = draft.nodes[1];
  final area = room1 == null ? null : draft.regionAt(room1.floor, (x: 552, y: 340), includeIgnored: false);
  if (room1 != null && area != null && area.kind == RegionKind.room && draft.placeFor(area.id, room1.floor) == null) {
    room1.region = area.id;
  }
  final entry2 = draft.nodes[14];
  if (entry2 != null) {
    final lobby = draft.regionAt(entry2.floor, (x: 630, y: 300), includeIgnored: false);
    entry2.region = null;
    if (lobby != null && lobby.kind == RegionKind.room && draft.placeFor(lobby.id, entry2.floor) == null) {
      draft.setRegionKind(entry2.floor, lobby.id, RegionKind.ignored);
    }
  }
}

class ScriptedSensors implements MotionSensors {
  final accel = StreamController<(Vec3, Duration)>.broadcast(sync: true);
  final mag = StreamController<Vec3>.broadcast(sync: true);
  Duration _time = Duration.zero;
  @override
  Stream<(Vec3, Duration)> get accelerometer => accel.stream;
  @override
  Stream<Vec3> get magnetometer => mag.stream;
  @override
  Stream<double>? get barometer => null;
  @override
  Stream<(Vec3, Duration)>? get gyroscope => null;

  /// One footstep (half a second of walking bounce at 50 Hz).
  void step() {
    for (var k = 0; k < 25; k++) {
      _time += const Duration(milliseconds: 20);
      accel.add(((x: 0, y: 0, z: 9.81 + 3 * math.sin(2 * math.pi * k / 25)), _time));
      mag.add((x: 0, y: 20, z: -40));
    }
  }
}

Widget frame(Widget home) => RepaintBoundary(
  key: boundaryKey,
  child: MaterialApp(debugShowCheckedModeBanner: false, theme: robotoTheme(buildTheme(Brightness.light)), home: home),
);

void main() {
  late BuildingMap raw;
  late BuildingMap generated;

  setUp(() {
    Directory(outDir).createSync(recursive: true);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Future<void> home(WidgetTester tester) async {
    await tester.runAsync(loadFonts);
    phone(tester);
    raw = loadRealMap();
    final temp = Directory.systemTemp.createTempSync('indoornav_film');
    final settings = await tester.runAsync(() => AppSettings.load(File('${temp.path}/settings.json')));
    await tester.pumpWidget(
      frame(BuildingsScreen(repository: BuildingRepository(Directory('${temp.path}/b')), settings: settings!, loadSample: () async => raw)),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await pumpFor(tester, 600);
    await shot(tester, 'home');
  }

  Future<void> navigate(WidgetTester tester) async {
    await tester.runAsync(loadFonts);
    phone(tester);
    raw = loadRealMap();
    generated = (await tester.runAsync(() => sampleWithMaps(raw)))!;
    final camera = FakeCameraPlatform();
    CameraPlatform.instance = camera;
    final detector = ScriptedDetector(const [
      [DetectedMarker(13, 800)],
      [DetectedMarker(13, 820)],
    ]);
    final sensors = ScriptedSensors();
    await tester.pumpWidget(
      frame(
        NavigationScreen(
          map: generated,
          images: (image) => AssetImage(image),
          createDetector: () => detector,
          motionSensors: () => sensors,
          speaker: SilentSpeaker.new,
        ),
      ),
    );
    await pumpFor(tester, 500);
    await shot(tester, 'nav_start');

    // Destination search.
    await tester.tap(find.text('Choose a destination'));
    await pumpFor(tester, 600);
    await shot(tester, 'picker_open');
    for (final typed in ['1', '10', '104']) {
      await tester.enterText(find.byType(TextField), typed);
      await pumpFor(tester, 200);
      await shot(tester, 'picker_$typed');
    }
    await tester.tap(find.widgetWithText(ListTile, 'Room 104'));
    await pumpFor(tester, 800);
    await shot(tester, 'destination');

    // Scan marker 13.
    await tester.tap(find.text('Scan marker'));
    await pumpFor(tester, 600);
    await shot(tester, 'scanner');
    for (var i = 0; i < 2; i++) {
      camera.sendFrame();
      await tester.pump();
      await tester.pump();
    }
    await seq(tester, 'located', 120); // 4 s: toast, route, guide dot

    // Route preferences.
    for (final (label, name) in [('Step-free', 'pref_stepfree'), ('Avoid lifts', 'pref_avoidlifts'), ('Fastest', 'pref_fastest')]) {
      await tester.tap(find.text(label));
      await seq(tester, name, 75); // 2.5 s each
    }

    // Steps list.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await pumpFor(tester, 800);
    await shot(tester, 'steps');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 520));
    await pumpFor(tester, 800);

    // Start walking (beta): sheet, then scripted footsteps.
    await tester.tap(find.text('Start walking'));
    await pumpFor(tester, 700);
    await shot(tester, 'walk_sheet');
    await tester.tap(find.text("I'm facing the route, start"));
    await pumpFor(tester, 700);
    Directory('$outDir/walk').createSync(recursive: true);
    for (var i = 0; i < 60; i++) {
      if (i % 5 == 0) sensors.step();
      await shot(tester, 'walk/${i.toString().padLeft(4, '0')}');
      await tester.pump(const Duration(milliseconds: 33));
    }
    await tester.tap(find.text('Stop'));
    await pumpFor(tester, 500);

    // Jump to the lift on this route, then take it: the sonar floor change.
    final nav = generated;
    final lift = nav.nodes.values.firstWhere((n) => n.name == 'Lift 1');
    await tester.tap(find.byTooltip('Set my location'));
    await pumpFor(tester, 600);
    await tester.enterText(find.byType(TextField), lift.name);
    await pumpFor(tester, 300);
    await tester.tap(find.widgetWithText(ListTile, lift.name));
    await pumpFor(tester, 1500);
    await shot(tester, 'at_lift');
    await tester.tap(find.textContaining('Next:'));
    await seq(tester, 'sonar', 140); // 4.67 s: the whole 4.2 s view plus fades
    await seq(tester, 'first_floor', 60);

    // Walk on by "Next" to the destination.
    for (var i = 0; i < 6; i++) {
      final next = find.textContaining('Next:');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next.first);
      await pumpFor(tester, 900);
      await shot(tester, 'next_$i');
    }
    await shot(tester, 'arrived');
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
  }

  Future<void> editor(WidgetTester tester) async {
    await tester.runAsync(loadFonts);
    phone(tester);
    raw = loadRealMap();
    final withMaps = (await tester.runAsync(() => sampleWithMaps(raw)))!;
    final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(withMaps.toJson())) as Map);
    final draft = BuildingDraft.fromJson(json, save: (_) async {}, saveDelay: Duration.zero);
    editorDraft = draft;
    await tester.pumpWidget(
      frame(
        FloorEditorScreen(
          draft: draft,
          level: 0,
          images: (image) => AssetImage(image),
          loadImage: (image) async => File(image).readAsBytesSync(),
          readText: (_) async => const [],
        ),
      ),
    );
    await tester.runAsync(() => precacheImage(const AssetImage('assets/floor_plans/ground_floor.jpg'), boundaryKey.currentContext!));
    await pumpFor(tester, 800);
    await shot(tester, 'editor_map');
    await tester.tap(find.byTooltip('Show blueprint underneath'));
    await pumpFor(tester, 500);
    await shot(tester, 'editor_map_guide');
    await tester.tap(find.text('Places'));
    await pumpFor(tester, 500);
    await shot(tester, 'editor_places');
    await tester.tap(find.text('Paths'));
    await pumpFor(tester, 500);
    await shot(tester, 'editor_paths');
    editorDraft = null;
    draft.dispose();
  }

  testWidgets('capture', (tester) async {
    await home(tester);
    await navigate(tester);
    await editor(tester);
  });
}
