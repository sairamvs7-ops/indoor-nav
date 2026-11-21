import 'package:flutter/foundation.dart';

import '../map/building_map.dart';
import '../routing/bidirectional_dijkstra.dart';
import '../routing/directions.dart';

enum ScanOutcome { located, arrived, unknownMarker }

/// Navigation state: where you are, where you're going, and the route between.
/// Every location change recomputes the route on the phone, so walking off the
/// planned route and scanning any marker simply reroutes from there.
class NavigationController extends ChangeNotifier {
  NavigationController(this.map) : _viewFloor = map.floors.first.level;

  final BuildingMap map;

  int? _currentId;
  int? _destinationId;
  RoutePreference _preference = RoutePreference.fastest;
  ShortestPath? _route;
  List<RouteStep> _steps = const [];
  int _viewFloor;

  MapNode? get currentNode => _currentId == null ? null : map.node(_currentId!);
  MapNode? get destinationNode => _destinationId == null ? null : map.node(_destinationId!);

  /// Node ids from the current location to the destination; empty if no route.
  List<int> get routeNodes => _route?.nodes ?? const [];
  double? get routeCost => _route?.cost;
  List<RouteStep> get steps => _steps;
  MapNode? get nextNode => _steps.isEmpty ? null : _steps.first.to;

  bool get hasArrived => _currentId != null && _currentId == _destinationId;

  /// True when both ends are set but no path connects them.
  bool get isUnreachable => _currentId != null && _destinationId != null && _route == null;

  /// Which connections routes may use (all, no stairs, or no lifts).
  RoutePreference get preference => _preference;

  /// The floor shown on the map. Follows your location, but can be changed.
  int get viewFloor => _viewFloor;

  String get instruction {
    final current = currentNode;
    final destination = destinationNode;
    if (destination == null) {
      return current == null
          ? 'Choose a destination, then scan the nearest marker.'
          : 'You are at ${current.name}. Choose a destination.';
    }
    if (current == null) return 'Scan the nearest marker to start navigating to ${destination.name}.';
    if (hasArrived) return 'You have arrived at ${destination.name}.';
    if (isUnreachable) {
      final kind = _preference == RoutePreference.fastest ? '' : '${_preference.label.toLowerCase()} ';
      return 'No ${kind}route from ${current.name} to ${destination.name}.';
    }
    return _steps.first.instruction;
  }

  void selectDestination(int nodeId) {
    final destination = map.node(nodeId);
    _destinationId = nodeId;
    _recomputeRoute();
    if (_currentId == null) _viewFloor = destination.floor;
    notifyListeners();
  }

  /// Forgets where you are but keeps the destination, so the next scan
  /// routes you from wherever you are now ("Re-locate").
  void clearLocation() {
    if (_currentId == null) return;
    _currentId = null;
    _recomputeRoute();
    notifyListeners();
  }

  void clearDestination() {
    _destinationId = null;
    _recomputeRoute();
    notifyListeners();
  }

  /// Sets where you are without scanning (manual pick, or a stop with no marker).
  void setCurrentLocation(int nodeId) {
    final node = map.node(nodeId);
    _currentId = nodeId;
    _viewFloor = node.floor;
    _recomputeRoute();
    notifyListeners();
  }

  ScanOutcome handleMarker(int markerId) {
    final node = map.nodeForMarker(markerId);
    if (node == null) return ScanOutcome.unknownMarker;
    setCurrentLocation(node.id);
    return hasArrived ? ScanOutcome.arrived : ScanOutcome.located;
  }

  /// Marks the next stop as reached, for stops without a marker.
  void advanceToNextStop() {
    final next = nextNode;
    if (next != null) setCurrentLocation(next.id);
  }

  void setPreference(RoutePreference preference) {
    if (preference == _preference) return;
    _preference = preference;
    _recomputeRoute();
    notifyListeners();
  }

  void showFloor(int level) {
    map.floor(level); // throws for unknown levels
    if (level == _viewFloor) return;
    _viewFloor = level;
    notifyListeners();
  }

  void reset() {
    _currentId = null;
    _destinationId = null;
    _recomputeRoute();
    _viewFloor = map.floors.first.level;
    notifyListeners();
  }

  void _recomputeRoute() {
    final current = _currentId;
    final destination = _destinationId;
    _route = (current == null || destination == null) ? null : bidirectionalDijkstra(map.graphFor(_preference), current, destination);
    _steps = _route == null ? const [] : buildSteps(map, _route!.nodes);
  }
}
