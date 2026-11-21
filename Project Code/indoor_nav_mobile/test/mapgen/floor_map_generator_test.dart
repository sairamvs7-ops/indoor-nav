import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/mapgen/floor_map_generator.dart';
import 'package:indoor_nav_mobile/setup/building_draft.dart';
import 'package:indoor_nav_mobile/storage/building_repository.dart';

/// A 400x300 plan: two rooms on top, a corridor across the middle, two rooms
/// below, doorways drawn as 8 px gaps, a 20 px entrance on the left, and a
/// "text" speck in the top-left room.
Uint8List planPng({bool blueprint = false, bool hatchedStairs = false}) {
  final paper = blueprint ? img.ColorRgb8(20, 60, 160) : img.ColorRgb8(255, 255, 255);
  final ink = blueprint ? img.ColorRgb8(240, 240, 255) : img.ColorRgb8(0, 0, 0);
  final image = img.Image(width: 400, height: 300);
  img.fill(image, color: paper);
  void wall(int x1, int y1, int x2, int y2) => img.fillRect(image, x1: x1, y1: y1, x2: x2, y2: y2, color: ink);
  // Outer walls, with an entrance gap on the left (y 140-160).
  wall(10, 10, 390, 13);
  wall(10, 287, 390, 290);
  wall(387, 10, 390, 290);
  wall(10, 10, 13, 140);
  wall(10, 160, 13, 290);
  // Corridor walls with doorways (8 px gaps).
  wall(10, 120, 96, 123);
  wall(104, 120, 296, 123);
  wall(304, 120, 390, 123);
  wall(10, 180, 196, 183);
  wall(204, 180, 390, 183);
  // Walls between the two top rooms and the two bottom rooms.
  wall(199, 10, 202, 120);
  wall(199, 180, 202, 290);
  if (hatchedStairs) {
    // A staircase drawn as diagonal hatching in the bottom-left room.
    // Lines y = 270 - (x - c), clipped to the box x 30..130, y 200..270.
    for (var c = -40; c < 130; c += 7) {
      final xa = math.max(30, c), xb = math.min(130, c + 70);
      if (xb <= xa) continue;
      img.drawLine(image, x1: xa, y1: 270 - (xa - c), x2: xb, y2: 270 - (xb - c), color: ink, thickness: 2);
    }
  }
  // A word of text in the top-left room.
  wall(60, 60, 64, 64);
  wall(68, 60, 72, 64);
  return img.encodePng(image);
}

void main() {
  test('finds the rooms and the corridor, ignoring text and the outside', () {
    final map = generateFloorMap(planPng());

    expect(map.width, 400);
    final rooms = map.regions.where((r) => r.kind == RegionKind.room).toList();
    final corridors = map.regions.where((r) => r.kind == RegionKind.corridor).toList();
    expect(rooms, hasLength(4));
    expect(corridors, hasLength(1));
    expect(corridors.single.paths, isNotEmpty);
    expect(map.regions.where((r) => r.kind == RegionKind.stairs), isEmpty); // plain walls aren't stairs

    // The top-left room fills the space between its walls.
    final topLeft = rooms.firstWhere((r) => r.outline.every((p) => p.x < 200 && p.y < 120));
    final xs = topLeft.outline.map((p) => p.x).toList()..sort();
    final ys = topLeft.outline.map((p) => p.y).toList()..sort();
    expect(xs.first, closeTo(14, 4));
    expect(xs.last, closeTo(198, 4));
    expect(ys.first, closeTo(14, 4));
    expect(ys.last, closeTo(119, 4));
    // Squared up: a rectangle, plus a small notch where its doorway is.
    expect(topLeft.outline.length, inInclusiveRange(4, 10));
  });

  test('a wide hall that three rooms open onto is a corridor', () {
    final image = img.Image(width: 300, height: 300);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    void wall(int x1, int y1, int x2, int y2) =>
        img.fillRect(image, x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgb8(0, 0, 0));
    wall(10, 10, 290, 13);
    wall(10, 287, 290, 290);
    wall(10, 10, 13, 290);
    wall(287, 10, 290, 290);
    // Three rooms on top, each with a doorway onto the hall below.
    wall(103, 10, 106, 150);
    wall(197, 10, 200, 150);
    wall(10, 150, 50, 153);
    wall(58, 150, 146, 153);
    wall(154, 150, 240, 153);
    wall(248, 150, 290, 153);

    final map = generateFloorMap(img.encodePng(image));

    expect(map.regions.where((r) => r.kind == RegionKind.room), hasLength(3));
    final hall = map.regions.singleWhere((r) => r.kind == RegionKind.corridor);
    expect(hall.outline.every((p) => p.y > 140), isTrue);
  });

  test('hatching is offered as stairs', () {
    final map = generateFloorMap(planPng(hatchedStairs: true));

    final stairs = map.regions.where((r) => r.kind == RegionKind.stairs).toList();
    expect(stairs, hasLength(1));
    final xs = stairs.single.outline.map((p) => p.x), ys = stairs.single.outline.map((p) => p.y);
    expect(xs.reduce((a, b) => a < b ? a : b), closeTo(30, 15));
    expect(xs.reduce((a, b) => a > b ? a : b), closeTo(130, 15));
    expect(ys.reduce((a, b) => a < b ? a : b), closeTo(200, 15));
    expect(ys.reduce((a, b) => a > b ? a : b), closeTo(270, 15));
  });

  test('reads a white-on-blue blueprint the same way', () {
    final map = generateFloorMap(planPng(blueprint: true));

    expect(map.regions.where((r) => r.kind == RegionKind.room), hasLength(4));
    expect(map.regions.where((r) => r.kind == RegionKind.corridor), hasLength(1));
  });

  test('narrow gap closing keeps doorways open, so rooms join the corridor', () {
    final normal = generateFloorMap(planPng());
    final narrow = generateFloorMap(planPng(), gaps: GapClosing.narrow);

    expect(narrow.regions.length, lessThan(normal.regions.length));
  });

  test('rejects files that are not images', () {
    expect(() => generateFloorMap(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });

  test('squareUp straightens a slightly crooked rectangle', () {
    final square = squareUp([(x: 0, y: 0), (x: 100, y: 3), (x: 101, y: 50), (x: -2, y: 49)]);

    expect(square, hasLength(4));
    for (var i = 0; i < 4; i++) {
      final a = square[i], b = square[(i + 1) % 4];
      expect(a.x == b.x || a.y == b.y, isTrue, reason: 'edge $i should be horizontal or vertical');
    }
  });

  test('a corridor rectangle gets a centreline down its middle', () {
    final lines = corridorCentrelines([(x: 0, y: 0), (x: 640, y: 0), (x: 640, y: 60), (x: 0, y: 60)], longest: 640);

    expect(lines, isNotEmpty);
    final points = lines.expand((l) => l).toList();
    expect(points.every((p) => (p.y - 30).abs() < 12), isTrue);
    final span = points.map((p) => p.x).reduce((a, b) => a > b ? a : b) - points.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    expect(span, greaterThan(400));
  });

  group('editing a generated map', () {
    BuildingDraft draftWithMap() {
      final draft = BuildingDraft.fromJson(
        emptyBuildingJson(id: 'abcdef0123456789', name: 'Plan'),
        save: (_) async {},
        saveDelay: Duration.zero,
      );
      draft.addFloor(name: 'Ground', image: 'g.png', width: 400, height: 300);
      final generated = generateFloorMap(planPng());
      draft.setGeneratedMap(0, [
        for (final (i, r) in generated.regions.indexed)
          FloorRegion(id: 'r${i + 1}', kind: r.kind, outline: r.outline, paths: r.paths),
      ]);
      return draft;
    }

    test('naming areas makes places, and routes run through the corridor', () {
      final draft = draftWithMap();
      final topLeft = draft.regionAt(0, (x: 100.0, y: 60.0))!;
      final bottom = draft.regionAt(0, (x: 100.0, y: 240.0))!;

      final a = draft.assignPlace(0, topLeft.id, name: 'Lab', type: NodeType.room);
      final b = draft.assignPlace(0, bottom.id, name: 'Hall', type: NodeType.room);

      expect(draft.nodes[a]!.region, topLeft.id);
      expect(draft.placeFor(bottom.id)!.name, 'Hall');
      final (map, error) = draft.tryBuild();
      expect(error, isNull);
      expect(map!.floor(0).hasGeneratedMap, isTrue);
      // Lab and Hall both join the corridor's centreline, so they connect.
      expect(map.graph[a], isNotEmpty);
      expect(map.graph[b], isNotEmpty);
      final json = draft.toJson();
      expect(((json['floors'] as List).first as Map)['regions'], isNotEmpty);
      expect(BuildingMap.fromJson(json).node(a).region, topLeft.id);
    });

    test('marking an area as corridor removes its place and adds a path', () {
      final draft = draftWithMap();
      final room = draft.regionAt(0, (x: 300.0, y: 60.0))!;
      draft.assignPlace(0, room.id, name: 'Store', type: NodeType.room);

      draft.setRegionKind(0, room.id, RegionKind.corridor);

      expect(draft.placeFor(room.id), isNull);
      expect(draft.floor(0).region(room.id)!.paths, isNotEmpty);
    });

    test('regenerating keeps places linked to the area they sit in', () {
      final draft = draftWithMap();
      final room = draft.regionAt(0, (x: 100.0, y: 60.0))!;
      final id = draft.assignPlace(0, room.id, name: 'Lab', type: NodeType.room);
      final again = generateFloorMap(planPng());

      draft.setGeneratedMap(0, [
        for (final (i, r) in again.regions.indexed)
          FloorRegion(id: 'n${i + 1}', kind: r.kind, outline: r.outline, paths: r.paths),
      ]);

      expect(draft.nodes[id]!.region, startsWith('n'));
    });

    test('a place plotted at a room door claims that room, never the corridor', () {
      final draft = BuildingDraft.fromJson(
        emptyBuildingJson(id: 'abcdef0123456789', name: 'Plan'),
        save: (_) async {},
        saveDelay: Duration.zero,
      );
      draft.addFloor(name: 'Ground', image: 'g.png', width: 400, height: 300);
      // Just below the top-left room's wall, in the corridor.
      final door = draft.addNode(name: 'Room 1', type: NodeType.room, floor: 0, x: 100, y: 127);
      final generated = generateFloorMap(planPng());

      draft.setGeneratedMap(0, [
        for (final (i, r) in generated.regions.indexed)
          FloorRegion(id: 'r${i + 1}', kind: r.kind, outline: r.outline, paths: r.paths),
      ]);

      final region = draft.floor(0).region(draft.nodes[door]!.region!)!;
      expect(region.kind, RegionKind.room);
      expect(region.contains((x: 100.0, y: 60.0)), isTrue); // the top-left room
    });

    test('stairs in the same spot on two floors link up by themselves', () {
      final draft = BuildingDraft.fromJson(
        emptyBuildingJson(id: 'abcdef0123456789', name: 'Two floors'),
        save: (_) async {},
        saveDelay: Duration.zero,
      );
      final square = [(x: 10.0, y: 10.0), (x: 40.0, y: 10.0), (x: 40.0, y: 40.0), (x: 10.0, y: 40.0)];
      draft
        ..addFloor(name: 'Ground', image: 'g.png', width: 400, height: 300)
        ..addFloor(name: 'First', image: 'f.png', width: 400, height: 300);
      final g = draft.addRegion(0, square);
      final f = draft.addRegion(1, [for (final p in square) (x: p.x + 4, y: p.y + 3)]);

      final a = draft.assignPlace(0, g, name: 'Main stairs', type: NodeType.stairs);
      final b = draft.assignPlace(1, f, name: 'Main stairs (1st)', type: NodeType.stairs);

      expect(draft.nodes[a]!.link, isNotNull);
      expect(draft.nodes[b]!.link, draft.nodes[a]!.link);
      final map = draft.tryBuild().$1!;
      expect(map.edges.any((e) => e.kind == EdgeKind.stairs), isTrue);
    });

    test('traced areas can become stairs with a link name', () {
      final draft = draftWithMap();
      final id = draft.addRegion(0, [(x: 20.0, y: 200.0), (x: 60.0, y: 200.0), (x: 60.0, y: 280.0), (x: 20.0, y: 280.0)]);

      final place = draft.assignPlace(0, id, name: 'Stairs A', type: NodeType.stairs, link: 'Stairs A');

      expect(draft.floor(0).region(id)!.kind, RegionKind.stairs);
      expect(draft.nodes[place]!.link, 'Stairs A');
      expect(draft.regionAt(0, (x: 40.0, y: 240.0))!.id, id); // smaller area wins
      draft.removeRegion(0, id);
      expect(draft.nodes[place]!.region, isNull);
    });
  });
}
