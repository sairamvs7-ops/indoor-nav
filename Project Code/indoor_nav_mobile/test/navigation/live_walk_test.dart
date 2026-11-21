import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/navigation/live_walk.dart';
import 'package:indoor_nav_mobile/navigation/motion.dart';
import 'package:indoor_nav_mobile/navigation/navigation_controller.dart';
import 'package:indoor_nav_mobile/navigation/route_tracker.dart';

import '../support/test_map.dart';

/// An L-shaped walk on a 100 m x 100 m floor: Entrance -> 50 m east -> Lab
/// -> 50 m south -> Office.
BuildingMap lWalk() => BuildingMap.fromJson({
  'format': 3,
  'building': 'Walk',
  'floors': [
    {'level': 0, 'name': 'Ground', 'image': 'g.png', 'width': 100, 'height': 100, 'metresPerPixel': 1},
  ],
  'nodes': [
    {'id': 1, 'name': 'Entrance', 'type': 'entry', 'floor': 0, 'x': 0, 'y': 50, 'marker': 1},
    {'id': 2, 'name': 'Lab', 'type': 'room', 'floor': 0, 'x': 50, 'y': 50, 'marker': 2},
    {'id': 3, 'name': 'Office', 'type': 'room', 'floor': 0, 'x': 50, 'y': 100, 'marker': 3},
  ],
  'edges': [
    {'from': 1, 'to': 2},
    {'from': 2, 'to': 3},
  ],
});

const Vec3 flat = (x: 0, y: 0, z: 9.81);

/// Magnetic field with the top of a flat phone pointing north / east.
const Vec3 facingNorth = (x: 0, y: 20, z: -40);
const Vec3 facingEast = (x: -20, y: 0, z: -40);

class FakeSensors implements MotionSensors {
  final accel = StreamController<(Vec3, Duration)>.broadcast(sync: true);
  final mag = StreamController<Vec3>.broadcast(sync: true);
  final pressure = StreamController<double>.broadcast(sync: true);
  Duration _time = Duration.zero;

  @override
  Stream<(Vec3, Duration)> get accelerometer => accel.stream;

  @override
  Stream<Vec3> get magnetometer => mag.stream;

  @override
  Stream<double>? get barometer => pressure.stream;

  @override
  Stream<(Vec3, Duration)>? get gyroscope => null;

  /// One footstep: half a second of the bounce walking makes, at 50 Hz,
  /// with the phone's compass reading [field].
  void step(Vec3 field) {
    for (var k = 0; k < 25; k++) {
      _time += const Duration(milliseconds: 20);
      accel.add(((x: 0, y: 0, z: 9.81 + 3 * math.sin(2 * math.pi * k / 25)), _time));
      mag.add(field);
    }
  }
}

class RecordingSpeaker implements Speaker {
  final said = <String>[];

  @override
  Future<void> say(String text) async => said.add(text);

  @override
  Future<void> stop() async {}
}

void main() {
  group('motion', () {
    test('counts the steps in a walking bounce', () {
      final detector = StepDetector();
      var steps = 0;
      for (var i = 0; i < 250; i++) {
        // 5 seconds at 50 Hz, two steps a second.
        final z = 9.81 + 3 * math.sin(2 * math.pi * 2 * i / 50);
        if (detector.add((x: 0, y: 0, z: z), Duration(milliseconds: 20 * i))) steps++;
      }

      expect(steps, inInclusiveRange(9, 10));
    });

    test('a phone lying still takes no steps', () {
      final detector = StepDetector();
      var steps = 0;
      for (var i = 0; i < 250; i++) {
        if (detector.add((x: 0.02, y: 0, z: 9.8 + 0.05 * math.sin(i.toDouble())), Duration(milliseconds: 20 * i))) {
          steps++;
        }
      }

      expect(steps, 0);
    });

    test('compass heading follows the top of the phone, clockwise from north', () {
      expect(compassHeading(flat, facingNorth), closeTo(0, 1e-9));
      expect(compassHeading(flat, facingEast), closeTo(math.pi / 2, 1e-9));
      expect(compassHeading(flat, (x: 20, y: 0, z: -40)), closeTo(3 * math.pi / 2, 1e-9));
      expect(compassHeading((x: 0, y: 0, z: 0), facingNorth), isNull);
    });

    test('angles wrap around north', () {
      expect(angleBetween(0.1, 2 * math.pi - 0.1), closeTo(0.2, 1e-9));
      expect(normaliseAngle(-math.pi / 2), closeTo(3 * math.pi / 2, 1e-9));
      final filter = HeadingFilter(strength: 0.5);
      filter.add(2 * math.pi - 0.1);
      expect(angleBetween(filter.add(0.1), 0), closeTo(0, 1e-9));
    });

    test('the gyroscope turns the heading and the compass corrects its drift', () {
      final heading = FusedHeading()
        ..gravity(flat)
        ..compass(1.0)
        ..gyro((x: 0, y: 0, z: 0), Duration.zero);
      // Turning counter-clockwise at 0.5 rad/s for one second.
      for (var i = 1; i <= 50; i++) {
        heading.gyro((x: 0, y: 0, z: 0.5), Duration(milliseconds: 20 * i));
      }
      expect(heading.value, closeTo(0.5, 0.02));

      // A compass reading far off barely moves it; many readings win.
      heading.compass(2.0);
      expect(heading.value, closeTo(0.53, 0.01));
      for (var i = 0; i < 400; i++) {
        heading.compass(2.0);
      }
      expect(heading.value, closeTo(2.0, 0.01));
    });

    test('air pressure dropping about 0.4 hPa is one floor up', () {
      final detector = FloorChangeDetector();
      for (var i = 0; i < 20; i++) {
        detector.add(1013.2);
      }
      detector.reset();
      var floors = 0.0;
      for (var i = 0; i < 40; i++) {
        floors = detector.add(1012.8);
      }

      expect(floors, closeTo(1, 0.05));
    });
  });

  group('RouteTracker', () {
    test('steps along the route move you forward and pass places', () {
      final tracker = RouteTracker(lWalk(), [1, 2, 3])..calibrate(1.0);

      expect(tracker.nextAction()!.text, 'Turn right at Lab');
      expect(describeAhead(tracker.nextAction()!), 'In 50 m, turn right at Lab');
      final passed = <String>[];
      for (var i = 0; i < 72; i++) {
        passed.addAll(tracker.step(1.0).map((n) => n.name));
      }

      expect(passed, ['Lab']);
      expect(tracker.currentLeg!.to.name, 'Office');
      expect(tracker.nextAction()!.text, 'Arrive at Office');
    });

    test('the position stays on the route', () {
      final tracker = RouteTracker(lWalk(), [1, 2, 3])..calibrate(0);
      for (var i = 0; i < 10; i++) {
        tracker.step(0.3); // a little off the corridor's direction
      }

      final (floor, x, y) = tracker.position;
      expect(floor, 0);
      expect(y, 50);
      expect(x, closeTo(10 * 0.7 * math.cos(0.3), 0.6)); // only the forward part counts, minus drift correction
      expect(tracker.remainingMetres, closeTo(100 - x, 1e-6));
    });

    test('walking the wrong way for a while means you left the route', () {
      final tracker = RouteTracker(lWalk(), [1, 2, 3])..calibrate(0);
      for (var i = 0; i < RouteTracker.wrongWayLimit; i++) {
        tracker.step(math.pi);
      }

      expect(tracker.offRoute, isTrue);
      tracker.resume();
      expect(tracker.offRoute, isFalse);
    });

    test('lifts wait for the floor change, then carry on', () {
      final tower = BuildingMap.fromJson({
        'format': 2,
        'building': 'Tower',
        'floors': [
          for (final level in [0, 1])
            {'level': level, 'name': 'Floor $level', 'image': 'f.png', 'width': 100, 'height': 100, 'metresPerPixel': 1},
        ],
        'nodes': [
          {'id': 1, 'name': 'Door', 'type': 'entry', 'floor': 0, 'x': 0, 'y': 0, 'marker': 1},
          {'id': 2, 'name': 'Lift A', 'type': 'lift', 'floor': 0, 'x': 10, 'y': 0, 'marker': 2, 'link': 'A'},
          {'id': 3, 'name': 'Lift A 1', 'type': 'lift', 'floor': 1, 'x': 10, 'y': 0, 'marker': 3, 'link': 'A'},
          {'id': 4, 'name': 'Lab', 'type': 'room', 'floor': 1, 'x': 30, 'y': 0, 'marker': 4},
        ],
        'edges': [
          {'from': 1, 'to': 2},
          {'from': 3, 'to': 4},
        ],
      });
      final tracker = RouteTracker(tower, [1, 2, 3, 4])..calibrate(0);

      expect(tracker.nextAction()!.text, 'Take Lift A up to Floor 1');
      for (var i = 0; i < 15; i++) {
        tracker.step(0);
      }
      expect(tracker.onLiftOrStairs, isTrue);
      expect(tracker.step(0), isEmpty); // walking in the lift goes nowhere

      expect(tracker.finishFloorChange().map((n) => n.name), ['Lift A 1']);
      expect(tracker.position.$1, 1);
      expect(tracker.nextAction()!.text, 'Arrive at Lab');
    });
  });

  group('LiveWalk', () {
    test('walks the whole route: turns, places reached, arrival', () {
      final map = lWalk();
      final nav = NavigationController(map)
        ..setCurrentLocation(1)
        ..selectDestination(3);
      final sensors = FakeSensors();
      final speaker = RecordingSpeaker();
      var turns = 0;
      final walk = LiveWalk(nav: nav, sensors: () => sensors, speaker: speaker, onTurn: () => turns++)..start();

      expect(walk.active, isTrue);
      for (var i = 0; i < 80 && nav.currentNode!.id != 2; i++) {
        sensors.step(facingNorth); // the first leg runs "north" on the compass
      }
      expect(nav.currentNode!.name, 'Lab');
      expect(walk.position!.$2, closeTo(50, 1));
      expect(turns, 1);
      expect(speaker.said.any((s) => s.endsWith('turn right at Lab')), isTrue);

      // Turn right and keep walking.
      for (var i = 0; i < 80 && walk.active; i++) {
        sensors.step(facingEast);
      }

      expect(nav.hasArrived, isTrue);
      expect(walk.active, isFalse);
      expect(speaker.said.last, 'You have arrived at Office');
    });

    test('a scan while walking reroutes from the scanned place', () {
      final nav = NavigationController(lWalk())
        ..setCurrentLocation(1)
        ..selectDestination(3);
      final sensors = FakeSensors();
      final walk = LiveWalk(nav: nav, sensors: () => sensors)..start();
      for (var i = 0; i < 5; i++) {
        sensors.step(facingNorth);
      }

      nav.handleMarker(2); // scanned the Lab's marker

      expect(walk.active, isTrue);
      expect(walk.position!.$2, 50);
      expect(walk.next!.text, 'Arrive at Office');
    });

    test('does not start without a location and a route', () {
      final walk = LiveWalk(nav: NavigationController(loadRealMap()), sensors: FakeSensors.new)..start();

      expect(walk.active, isFalse);
    });
  });
}
