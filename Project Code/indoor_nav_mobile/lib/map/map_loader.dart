import 'dart:convert';

import 'package:flutter/services.dart';

import 'building_map.dart';

const String defaultMapAsset = 'assets/map/building.json';

/// Loads and validates the building map bundled with the app.
/// Throws [MapFormatException] if the file is not valid JSON or not a valid map.
Future<BuildingMap> loadBuildingMap(AssetBundle bundle, {String asset = defaultMapAsset}) async {
  final raw = await bundle.loadString(asset);
  return parseBuildingMap(raw);
}

BuildingMap parseBuildingMap(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw MapFormatException('building.json is not valid JSON: ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const MapFormatException('building.json must contain a JSON object at the top level');
  }
  return BuildingMap.fromJson(decoded);
}
