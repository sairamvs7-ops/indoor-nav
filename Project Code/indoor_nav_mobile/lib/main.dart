import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'map/map_loader.dart';
import 'storage/building_repository.dart';
import 'ui/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final separator = Platform.pathSeparator;
  final settings = await AppSettings.load(File('${documents.path}${separator}settings.json'));
  runApp(
    ViaApp(
      repository: BuildingRepository(Directory('${documents.path}${separator}buildings')),
      settings: settings,
      loadSample: () => loadBuildingMap(rootBundle),
    ),
  );
}
