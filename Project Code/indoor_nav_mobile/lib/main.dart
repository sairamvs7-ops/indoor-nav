import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'map/map_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(IndoorNavApp(loadMap: () => loadBuildingMap(rootBundle)));
}
