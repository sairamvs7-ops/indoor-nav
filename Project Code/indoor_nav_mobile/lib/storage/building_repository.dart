import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../map/building_map.dart';

const String buildingFileName = 'building.json';

/// File names allowed inside a building folder or package. Keeps imported
/// packages from writing outside their own folder.
final RegExp _safeFileName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$');

bool isSafeFileName(String name) => _safeFileName.hasMatch(name) && !name.contains('..');

/// A building saved on this phone, as shown in the building list.
class SavedBuilding {
  const SavedBuilding({required this.id, required this.name, required this.floorCount, required this.placeCount});

  final String id;
  final String name;
  final int floorCount;
  final int placeCount;
}

/// Buildings made on this phone or imported from a package. Each building is
/// a folder holding building.json and one image per floor:
///
///     <root>/<id>/building.json
///     <root>/<id>/floor_1700000000000.jpg
///
/// Buildings that are still being set up may not be valid maps yet, so the
/// list and the editor work on the raw JSON; [load] validates.
class BuildingRepository {
  BuildingRepository(this.root);

  final Directory root;

  Directory directoryOf(String id) {
    _checkId(id);
    return Directory('${root.path}${Platform.pathSeparator}$id');
  }

  File fileIn(String id, String name) {
    if (!isSafeFileName(name)) throw ArgumentError.value(name, 'name', 'Not a safe file name');
    return File('${directoryOf(id).path}${Platform.pathSeparator}$name');
  }

  Future<List<SavedBuilding>> list() async {
    if (!await root.exists()) return const [];
    final buildings = <SavedBuilding>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!_isValidId(id)) continue;
      try {
        final json = await readJson(id);
        buildings.add(
          SavedBuilding(
            id: id,
            name: (json['building'] as String?) ?? 'Untitled building',
            floorCount: (json['floors'] as List<Object?>?)?.length ?? 0,
            placeCount: (json['nodes'] as List<Object?>?)?.length ?? 0,
          ),
        );
      } on Object {
        // A folder without a readable building.json is not a building.
        continue;
      }
    }
    buildings.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return buildings;
  }

  /// Creates an empty building and returns its id.
  Future<String> create(String name) async {
    final id = newBuildingId();
    await directoryOf(id).create(recursive: true);
    await writeJson(id, emptyBuildingJson(id: id, name: name));
    return id;
  }

  Future<Map<String, dynamic>> readJson(String id) async {
    final raw = await fileIn(id, buildingFileName).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) throw const MapFormatException('building.json must contain an object');
    return decoded;
  }

  /// Loads and validates a building for navigation.
  /// Throws [MapFormatException] if it is not a complete, valid map.
  Future<BuildingMap> load(String id) async => BuildingMap.fromJson(await readJson(id));

  /// Saves building.json, replacing the old file only once the new one is
  /// fully written, so a crash mid-save can't corrupt the building.
  Future<void> writeJson(String id, Map<String, dynamic> json) async {
    final target = fileIn(id, buildingFileName);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(json), flush: true);
    await temp.rename(target.path);
  }

  /// Stores a floor drawing in the building's folder and returns its file name.
  Future<String> addImage(String id, Uint8List bytes, {required String extension}) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
    final name = 'floor_${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    final file = fileIn(id, name);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return name;
  }

  /// Deletes images in the building's folder that no floor uses any more.
  Future<void> removeUnusedImages(String id) async {
    final json = await readJson(id);
    final used = {for (final f in (json['floors'] as List<Object?>? ?? const [])) (f as Map<String, dynamic>)['image']};
    await for (final entry in directoryOf(id).list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name == buildingFileName || used.contains(name)) continue;
      await entry.delete();
    }
  }

  Future<void> delete(String id) async {
    final dir = directoryOf(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<bool> exists(String id) => fileIn(id, buildingFileName).exists();

  static bool _isValidId(String id) => RegExp(r'^[a-z0-9]{8,40}$').hasMatch(id);

  static void _checkId(String id) {
    if (!_isValidId(id)) throw ArgumentError.value(id, 'id', 'Not a building id');
  }
}

/// A random building id: 16 lowercase hex characters.
String newBuildingId([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}

Map<String, dynamic> emptyBuildingJson({required String id, required String name}) => {
  'format': currentMapFormat,
  'id': id,
  'building': name,
  'floors': <Object?>[],
  'nodes': <Object?>[],
  'edges': <Object?>[],
};
