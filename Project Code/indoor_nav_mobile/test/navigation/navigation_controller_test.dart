import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/navigation/navigation_controller.dart';

import '../support/test_map.dart';

void main() {
  late NavigationController nav;
  late int notifications;

  setUp(() {
    nav = NavigationController(BuildingMap.fromJson(smallMapJson()));
    notifications = 0;
    nav.addListener(() => notifications++);
  });

  test('starts with no location, no destination and a prompt to choose', () {
    expect(nav.currentNode, isNull);
    expect(nav.destinationNode, isNull);
    expect(nav.routeNodes, isEmpty);
    expect(nav.instruction, 'Choose a destination, then scan the nearest marker.');
    expect(nav.viewFloor, 0);
  });

  test('asks for a scan once a destination is chosen, and shows its floor', () {
    nav.selectDestination(5);

    expect(nav.instruction, 'Scan the nearest marker to start navigating to Room B.');
    expect(nav.viewFloor, 1);
    expect(notifications, 1);
  });

  test('asks for a destination after a scan when none is chosen', () {
    nav.handleMarker(2);

    expect(nav.instruction, 'You are at Room A. Choose a destination.');
  });

  test('scanning a marker routes from that node to the destination', () {
    nav.selectDestination(5);

    final outcome = nav.handleMarker(1);

    expect(outcome, ScanOutcome.located);
    expect(nav.currentNode!.id, 1);
    expect(nav.routeNodes, [1, 2, 3, 4, 5]);
    expect(nav.routeCost, 4);
    expect(nav.nextNode!.id, 2);
    expect(nav.instruction, 'Walk to Room A');
    expect(nav.viewFloor, 0);
  });

  test('scanning a later marker reroutes from there', () {
    nav
      ..selectDestination(5)
      ..handleMarker(1);

    nav.handleMarker(3);

    expect(nav.routeNodes, [3, 4, 5]);
    expect(nav.instruction, 'Take Lift G up to the First Floor');
  });

  test('scanning the destination marker reports arrival', () {
    nav
      ..selectDestination(2)
      ..handleMarker(1);

    final outcome = nav.handleMarker(2);

    expect(outcome, ScanOutcome.arrived);
    expect(nav.hasArrived, isTrue);
    expect(nav.nextNode, isNull);
    expect(nav.instruction, 'You have arrived at Room A.');
  });

  test('an unknown marker changes nothing', () {
    nav
      ..selectDestination(5)
      ..handleMarker(1);
    final before = notifications;

    final outcome = nav.handleMarker(42);

    expect(outcome, ScanOutcome.unknownMarker);
    expect(nav.currentNode!.id, 1);
    expect(notifications, before);
  });

  test('reports when no route connects the two places', () {
    nav
      ..selectDestination(7)
      ..handleMarker(1);

    expect(nav.isUnreachable, isTrue);
    expect(nav.routeNodes, isEmpty);
    expect(nav.instruction, 'No route from Entry to Store.');
  });

  test('advanceToNextStop moves through stops that have no marker', () {
    nav
      ..selectDestination(6)
      ..setCurrentLocation(5);

    nav.advanceToNextStop();

    expect(nav.currentNode!.id, 6);
    expect(nav.hasArrived, isTrue);
  });

  test('advanceToNextStop does nothing without a route', () {
    nav.advanceToNextStop();

    expect(nav.currentNode, isNull);
    expect(notifications, 0);
  });

  test('showFloor switches the visible floor and ignores repeats', () {
    nav.showFloor(1);
    nav.showFloor(1);

    expect(nav.viewFloor, 1);
    expect(notifications, 1);
    expect(() => nav.showFloor(9), throwsArgumentError);
  });

  test('clearDestination drops the route but keeps the location', () {
    nav
      ..selectDestination(5)
      ..handleMarker(1);

    nav.clearDestination();

    expect(nav.destinationNode, isNull);
    expect(nav.routeNodes, isEmpty);
    expect(nav.currentNode!.id, 1);
  });

  test('clearLocation keeps the destination for a fresh scan', () {
    final nav = NavigationController(BuildingMap.fromJson(smallMapJson()))
      ..selectDestination(5)
      ..setCurrentLocation(1);

    nav.clearLocation();

    expect(nav.currentNode, isNull);
    expect(nav.destinationNode!.id, 5);
    expect(nav.routeNodes, isEmpty);
    expect(nav.instruction, contains('Scan the nearest marker'));
    nav.handleMarker(3);
    expect(nav.routeNodes.first, 3);
  });

  test('reset clears everything', () {
    nav
      ..selectDestination(5)
      ..handleMarker(4);

    nav.reset();

    expect(nav.currentNode, isNull);
    expect(nav.destinationNode, isNull);
    expect(nav.viewFloor, 0);
  });

  test('rejects node ids that are not on the map', () {
    expect(() => nav.selectDestination(99), throwsArgumentError);
    expect(() => nav.setCurrentLocation(99), throwsArgumentError);
  });
}
