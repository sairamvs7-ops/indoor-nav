import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/mapgen/text_labels.dart';
import 'package:indoor_nav_mobile/setup/building_draft.dart';
import 'package:indoor_nav_mobile/storage/building_repository.dart';

List<Pt> box(double x0, double y0, double x1, double y1) => [(x: x0, y: y0), (x: x1, y: y0), (x: x1, y: y1), (x: x0, y: y1)];

TextLabel at(String text, double x, double y) => TextLabel(text, left: x - 15, top: y - 5, right: x + 15, bottom: y + 5);

/// A 400x300 floor: two rooms on top, a corridor, a room below, and a
/// small stairwell area beside it.
BuildingDraft draft() {
  final d = BuildingDraft.fromJson(
    emptyBuildingJson(id: 'abcdef0123456789', name: 'Plan'),
    save: (_) async {},
    saveDelay: Duration.zero,
  );
  d.addFloor(name: 'Ground', image: 'g.png', width: 400, height: 300);
  d.setGeneratedMap(0, [
    FloorRegion(id: 'r1', kind: RegionKind.room, outline: box(0, 0, 200, 120)),
    FloorRegion(id: 'r2', kind: RegionKind.room, outline: box(200, 0, 400, 120)),
    FloorRegion(id: 'r3', kind: RegionKind.corridor, outline: box(0, 120, 400, 180)),
    FloorRegion(id: 'r4', kind: RegionKind.room, outline: box(0, 180, 300, 300)),
    FloorRegion(id: 'r5', kind: RegionKind.stairs, outline: box(320, 190, 390, 290)),
  ]);
  return d;
}

void main() {
  test('tells stairs, lifts, corridors and names apart', () {
    expect(classifyLabel('STAIRS'), LabelMeaning.stairs);
    expect(classifyLabel('Main staircase'), LabelMeaning.stairs);
    expect(classifyLabel('LIFT 2'), LabelMeaning.lift);
    expect(classifyLabel('Elevator'), LabelMeaning.lift);
    expect(classifyLabel('Corridor'), LabelMeaning.corridor);
    expect(classifyLabel('NODE-4'), LabelMeaning.name);
    expect(classifyLabel('Room 101'), LabelMeaning.name);
    expect(classifyLabel('~'), LabelMeaning.noise);
    expect(classifyLabel('l'), LabelMeaning.noise);
  });

  test('tidies label text into names', () {
    expect(cleanLabel('NODE-4'), 'Node-4');
    expect(cleanLabel('  room   101 '), 'Room 101');
    expect(cleanLabel('LAB b'), 'Lab B');
  });

  test('names rooms, joins two-line labels, and finds stairs', () {
    final d = draft();

    final result = applyTextLabels(d, 0, [
      at('LAB', 100, 60),
      at('NODE', 300, 50),
      at('18', 300, 70),
      at('CORRIDOR', 200, 150), // already a corridor: nothing to do
      at('STAIRS', 355, 240), // on the stairwell
      at('~', 50, 250), // noise
    ]);

    expect(d.placeFor('r1', 0)!.name, 'Lab');
    expect(d.placeFor('r2', 0)!.name, 'Node 18');
    expect(d.placeFor('r4', 0), isNull);
    final stairs = d.placeFor('r5', 0)!;
    expect(stairs.type, NodeType.stairs);
    expect(stairs.name, 'Stairs');
    expect(stairs.marker, isNotNull);
    expect((result.named, result.stairs, result.corridors), (2, 1, 0));
    expect(result.toString(), '2 rooms named, 1 stairs');
  });

  test('a STAIRS label on hatching (wall) claims the stairwell next to it', () {
    final d = draft();

    applyTextLabels(d, 0, [at('STAIRS', 310, 240)]); // on the wall between the room and the stairwell

    expect(d.placeFor('r5', 0)!.type, NodeType.stairs);
    expect(d.placeFor('r4', 0), isNull);
  });

  test('a label in a corridor area can make a room walkable', () {
    final d = draft();

    final result = applyTextLabels(d, 0, [at('Main lobby', 100, 240)]);

    expect(d.floor(0).region('r4')!.kind, RegionKind.corridor);
    expect(result.corridors, 1);
  });

  test('never renames places the user already set up', () {
    final d = draft();
    d.assignPlace(0, 'r1', name: 'Physics lab', type: NodeType.room);

    applyTextLabels(d, 0, [at('ROOM 12', 100, 60)]);

    expect(d.placeFor('r1', 0)!.name, 'Physics lab');
  });

  test('can find stairs and lifts without naming rooms', () {
    final d = draft();

    applyTextLabels(d, 0, [at('LAB', 100, 60), at('LIFT', 355, 240)], nameRooms: false);

    expect(d.placeFor('r1', 0), isNull);
    expect(d.placeFor('r5', 0)!.type, NodeType.lift);
    expect(d.floor(0).region('r5')!.kind, RegionKind.lift);
  });
}
