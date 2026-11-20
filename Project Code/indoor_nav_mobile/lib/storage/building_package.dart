import 'dart:convert';
import 'dart:typed_data';

import '../map/building_map.dart';
import 'building_repository.dart';

/// Extension used for shared building files.
const String packageExtension = 'indoornav';

/// Version of the package wrapper written by [exportBuilding].
const int packageVersion = 1;

/// A whole building in one file, so it can be shared on WhatsApp, Drive or
/// email and imported on another phone:
///
///     {"indoorNavPackage": 1, "building": {...building.json...},
///      "images": {"floor_1.jpg": "<base64>", ...}}
///
/// Plain JSON keeps it dependency-free and easy to inspect.
Future<Uint8List> exportBuilding(BuildingRepository repository, String id) async {
  final json = await repository.readJson(id);
  final map = BuildingMap.fromJson(json); // only complete buildings are shared
  final images = <String, String>{};
  for (final floor in map.floors) {
    images[floor.image] = base64Encode(await repository.fileIn(id, floor.image).readAsBytes());
  }
  return utf8.encode(jsonEncode({'indoorNavPackage': packageVersion, 'building': json, 'images': images}));
}

/// A safe file name for an exported building, like "Main_Block.indoornav".
String packageFileName(String buildingName) {
  final cleaned = buildingName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return '${cleaned.isEmpty ? 'building' : cleaned}.$packageExtension';
}

/// Reads a package made by [exportBuilding] and saves it as a building.
/// Returns the new building's id. If a building with the package's id is
/// already on this phone, the import gets a fresh id instead of overwriting it.
///
/// Throws [MapFormatException] with a readable message if the file is not a
/// valid building package.
Future<String> importBuilding(BuildingRepository repository, Uint8List bytes) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const MapFormatException('This file is not an Indoor Nav building.');
  }
  if (decoded is! Map<String, dynamic> || decoded['indoorNavPackage'] is! int) {
    throw const MapFormatException('This file is not an Indoor Nav building.');
  }
  if ((decoded['indoorNavPackage'] as int) > packageVersion) {
    throw const MapFormatException('This building was made with a newer version of the app. Update the app to open it.');
  }
  final building = decoded['building'];
  final images = decoded['images'];
  if (building is! Map<String, dynamic> || images is! Map<String, dynamic>) {
    throw const MapFormatException('This building file is incomplete.');
  }

  final map = BuildingMap.fromJson(building);
  final imageBytes = <String, Uint8List>{};
  for (final floor in map.floors) {
    final data = images[floor.image];
    if (!isSafeFileName(floor.image) || data is! String) {
      throw MapFormatException('The drawing for ${floor.name} is missing from this file.');
    }
    try {
      imageBytes[floor.image] = base64Decode(data);
    } on FormatException {
      throw MapFormatException('The drawing for ${floor.name} is damaged.');
    }
  }

  final packageId = map.id;
  final id = (packageId != null && RegExp(r'^[a-z0-9]{8,40}$').hasMatch(packageId) && !await repository.exists(packageId))
      ? packageId
      : newBuildingId();
  try {
    await repository.directoryOf(id).create(recursive: true);
    for (final entry in imageBytes.entries) {
      await repository.fileIn(id, entry.key).writeAsBytes(entry.value, flush: true);
    }
    await repository.writeJson(id, {...building, 'id': id});
  } catch (_) {
    await repository.delete(id); // don't leave half a building behind
    rethrow;
  }
  return id;
}
