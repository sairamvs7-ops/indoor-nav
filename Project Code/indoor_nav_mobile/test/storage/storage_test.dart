import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/storage/building_package.dart';
import 'package:indoor_nav_mobile/storage/building_repository.dart';

Future<String> savedBuilding(BuildingRepository repo, {String name = 'Main Block'}) async {
  final id = await repo.create(name);
  final image = await repo.addImage(id, Uint8List.fromList([1, 2, 3]), extension: 'PNG');
  final json = await repo.readJson(id);
  json['floors'] = [
    {'level': 0, 'name': 'Ground', 'image': image, 'width': 100, 'height': 100},
  ];
  json['nodes'] = [
    {'id': 1, 'name': 'Door', 'type': 'entry', 'floor': 0, 'x': 1, 'y': 1, 'marker': 1},
  ];
  await repo.writeJson(id, json);
  return id;
}

void main() {
  late Directory temp;
  late BuildingRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('indoor_nav_test');
    repo = BuildingRepository(Directory('${temp.path}/buildings'));
  });

  tearDown(() => temp.delete(recursive: true));

  test('lists nothing before any building exists', () async {
    expect(await repo.list(), isEmpty);
  });

  test('creates, lists, loads and deletes buildings', () async {
    final id = await savedBuilding(repo);
    await repo.create('Annex');

    final list = await repo.list();
    expect(list.map((b) => b.name), ['Annex', 'Main Block']);
    expect(list.last.floorCount, 1);
    expect(list.last.placeCount, 1);
    expect((await repo.load(id)).node(1).name, 'Door');

    await repo.delete(id);
    expect((await repo.list()).map((b) => b.name), ['Annex']);
  });

  test('stores images with safe names and removes unused ones', () async {
    final id = await savedBuilding(repo);
    final unused = await repo.addImage(id, Uint8List.fromList([9]), extension: '.exe');

    expect(unused, endsWith('.jpg'));
    await repo.removeUnusedImages(id);

    expect(await repo.fileIn(id, unused).exists(), isFalse);
    final floorImage = (await repo.load(id)).floor(0).image;
    expect(await repo.fileIn(id, floorImage).readAsBytes(), [1, 2, 3]);
  });

  test('refuses ids and file names that could escape the buildings folder', () {
    expect(() => repo.directoryOf('../etc'), throwsArgumentError);
    expect(() => repo.fileIn('abcdef0123456789', '../x.json'), throwsArgumentError);
    expect(isSafeFileName('floor_1.jpg'), isTrue);
    expect(isSafeFileName('.hidden'), isFalse);
  });

  group('packages', () {
    test('export then import gives the same building on another phone', () async {
      final id = await savedBuilding(repo);
      final bytes = await exportBuilding(repo, id);

      final otherPhone = BuildingRepository(Directory('${temp.path}/other'));
      final importedId = await importBuilding(otherPhone, bytes);

      expect(importedId, id);
      final map = await otherPhone.load(importedId);
      expect(map.name, 'Main Block');
      expect(await otherPhone.fileIn(importedId, map.floor(0).image).readAsBytes(), [1, 2, 3]);
    });

    test('importing a building that is already here makes a copy', () async {
      final id = await savedBuilding(repo);

      final copyId = await importBuilding(repo, await exportBuilding(repo, id));

      expect(copyId, isNot(id));
      expect((await repo.load(copyId)).id, copyId);
      expect(await repo.list(), hasLength(2));
    });

    test('rejects files that are not buildings, with a readable reason', () async {
      Future<String> importError(Object content) async {
        try {
          await importBuilding(repo, utf8.encode(content is String ? content : jsonEncode(content)));
          return 'no error';
        } on MapFormatException catch (e) {
          return e.message;
        }
      }

      expect(await importError('not json'), contains('not a Via building'));
      expect(await importError({'hello': 1}), contains('not a Via building'));
      expect(await importError({'viaPackage': 99, 'building': {}, 'images': {}}), contains('newer version'));
      // Files shared by the app before it was renamed Via are still read.
      expect(await importError({'indoorNavPackage': 99, 'building': {}, 'images': {}}), contains('newer version'));

      final id = await savedBuilding(repo);
      final package = jsonDecode(utf8.decode(await exportBuilding(repo, id))) as Map<String, dynamic>;
      package['images'] = <String, dynamic>{};
      expect(await importError(package), contains('drawing for Ground is missing'));
      expect(await repo.list(), hasLength(1)); // nothing half-imported
    });

    test('names exported files after the building', () {
      expect(packageFileName('Main Block (RVU)'), 'Main_Block_RVU.via');
      expect(packageFileName('  '), 'building.via');
    });

    test('only complete buildings can be exported', () async {
      final id = await repo.create('Empty');

      expect(() => exportBuilding(repo, id), throwsA(isA<MapFormatException>()));
    });
  });
}
