import 'package:flutter/material.dart';

import 'map/building_map.dart';
import 'scanner/marker_detector.dart';
import 'storage/building_repository.dart';
import 'ui/app_settings.dart';
import 'ui/app_theme.dart';
import 'ui/buildings_screen.dart';

class IndoorNavApp extends StatelessWidget {
  const IndoorNavApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.loadSample,
    this.createDetector = MarkerDetector.new,
  });

  /// Where buildings made or imported on this phone are kept.
  final BuildingRepository repository;
  final AppSettings settings;

  /// Loads the bundled sample building. Injected so tests can supply one.
  final Future<BuildingMap> Function() loadSample;

  /// Builds the marker detector for the scanner. Injected so tests can fake it.
  final FrameDetector Function() createDetector;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        home: BuildingsScreen(
          repository: repository,
          settings: settings,
          loadSample: loadSample,
          createDetector: createDetector,
        ),
      ),
    );
  }
}
