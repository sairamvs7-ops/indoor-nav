import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/setup/walk_check.dart';

import '../support/test_map.dart';

void main() {
  final real = loadRealMap();

  test('a walk the map already has is confirmed', () {
    final finding = checkWalkStep(real, 13, 4); // Entry 1 -> Room 4, next door

    expect(finding.verdict, WalkVerdict.confirmed);
    expect(finding.message, contains('matches the map'));
  });

  test('a walk past marked places that were not scanned is flagged', () {
    final finding = checkWalkStep(real, 13, 5); // the map goes via Room 4

    expect(finding.verdict, WalkVerdict.viaOthers);
    expect(finding.via.map((n) => n.name), ['Room 4']);
  });

  test('a walk between unconnected places is missing from the map', () {
    final map = BuildingMap.fromJson(smallMapJson());

    expect(checkWalkStep(map, 1, 7).verdict, WalkVerdict.missing); // Entry -> Store
  });

  test('lifts on two floors are checked for a link', () {
    final linked = BuildingMap.fromJson(smallMapJson());
    final json = smallMapJson();
    (json['edges'] as List<Object?>).removeWhere((e) => (e! as Map)['from'] == 3);
    final unlinked = BuildingMap.fromJson(json);

    expect(checkWalkStep(linked, 3, 4).verdict, WalkVerdict.linkedFloors);
    expect(checkWalkStep(unlinked, 3, 4).verdict, WalkVerdict.unlinkedFloors);
    expect(checkWalkStep(real, 9, 23).verdict, WalkVerdict.linkedFloors); // Lift 1 -> Lift 3
  });

  test('changing floor without scanning the lift or stairs is pointed out', () {
    final finding = checkWalkStep(real, 13, 18); // Entry 1 -> Room 104

    expect(finding.verdict, WalkVerdict.floorChangeUnknown);
    expect(finding.message, contains('Scan the lift or stairs'));
  });

  test('lists marked places not visited yet, lowest floor first', () {
    final left = notVisited(real, {for (var id = 1; id <= 26; id++) id});

    expect(left.map((n) => n.name), ['Entry 3']); // the vending machine has no marker
  });
}
