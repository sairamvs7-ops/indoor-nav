import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/routing/directions.dart';

import '../support/test_map.dart';

void main() {
  final map = BuildingMap.fromJson(smallMapJson());

  test('builds one step per hop, saying "walk to" on the same floor', () {
    final steps = buildSteps(map, [1, 2, 3]);

    expect(steps.map((s) => s.instruction), ['Walk to Room A', 'Walk to Lift G']);
    expect(steps.any((s) => s.changesFloor), isFalse);
  });

  test('says which lift or stairs to take and in which direction', () {
    final up = buildSteps(map, [3, 4]).single;
    final down = buildSteps(map, [4, 3]).single;

    expect(up.instruction, 'Take Lift G up to the First Floor');
    expect(up.changesFloor, isTrue);
    expect(down.instruction, 'Take Lift 1 down to the Ground Floor');
  });

  test('returns no steps for a single-node path', () {
    expect(buildSteps(map, [5]), isEmpty);
  });

  test('describes real stairs on the building map', () {
    final real = loadRealMap();

    expect(buildSteps(real, [11, 25]).single.instruction, 'Take Stairs 1 up to the First Floor');
  });
}
