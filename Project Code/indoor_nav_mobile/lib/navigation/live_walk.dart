import 'dart:async';

import 'package:flutter/foundation.dart';

import '../map/building_map.dart';
import 'motion.dart';
import 'navigation_controller.dart';
import 'route_tracker.dart';

/// The phone's motion sensors. Behind an interface so tests can walk a
/// route without a phone.
abstract interface class MotionSensors {
  /// Accelerometer readings (including gravity) with the time they arrived.
  Stream<(Vec3, Duration)> get accelerometer;
  Stream<Vec3> get magnetometer;

  /// Air pressure in hPa; null on phones without a barometer.
  Stream<double>? get barometer;
}

/// Speaks directions aloud.
abstract interface class Speaker {
  Future<void> say(String text);
  Future<void> stop();
}

/// Creates the real speaker only when something is first said, so screens
/// that never use voice don't start the text-to-speech engine.
class LazySpeaker implements Speaker {
  LazySpeaker(this._create);

  final Speaker Function() _create;
  Speaker? _speaker;

  @override
  Future<void> say(String text) => (_speaker ??= _create()).say(text);

  @override
  Future<void> stop() => _speaker?.stop() ?? Future<void>.value();
}

class SilentSpeaker implements Speaker {
  const SilentSpeaker();

  @override
  Future<void> say(String text) async {}

  @override
  Future<void> stop() async {}
}

/// "Scan once, then walk": after one scan, footsteps and the compass move
/// you along the route, places are reached as you pass them, the barometer
/// notices floor changes, and turns are announced.
class LiveWalk extends ChangeNotifier {
  LiveWalk({
    required this.nav,
    required MotionSensors Function() sensors,
    this.speaker = const SilentSpeaker(),
    this.onTurn,
    this.stepMetres = 0.7,
  }) : _sensors = sensors;

  final NavigationController nav;
  final MotionSensors Function() _sensors;
  final Speaker speaker;

  /// Called when a turn is right ahead (for a vibration).
  final VoidCallback? onTurn;
  final double stepMetres;

  RouteTracker? _tracker;
  final StepDetector _steps = StepDetector();
  final HeadingFilter _heading = HeadingFilter();
  final FloorChangeDetector _pressure = FloorChangeDetector();
  final List<StreamSubscription<Object?>> _subs = [];
  Vec3? _gravity;
  bool _moving = false; // true while this class is updating the location
  bool _onLift = false;
  String? _lastSpoken;
  bool _warnedOffRoute = false;
  int stepCount = 0;

  bool get active => _tracker != null;
  bool get offRoute => _tracker?.offRoute ?? false;
  bool get waitingForFloorChange => _tracker?.onLiftOrStairs ?? false;

  /// Your live position on the map, between places.
  (int floor, double x, double y)? get position => _tracker?.position;
  double? get remainingMetres => _tracker?.remainingMetres;
  NextAction? get next => _tracker?.nextAction();

  /// What to show and say now.
  String get prompt {
    final tracker = _tracker;
    if (tracker == null) return '';
    if (tracker.offRoute) return 'You seem to have left the route. Scan the nearest marker.';
    if (!tracker.calibrated) return 'Face the way the route starts and start walking.';
    if (tracker.onLiftOrStairs) {
      final leg = tracker.currentLeg!;
      return 'Take ${leg.from.name} to ${nav.map.floor(leg.to.floor).name}';
    }
    final action = tracker.nextAction();
    return action == null ? '' : describeAhead(action);
  }

  /// Starts following you from your current location. Hold the phone in
  /// front of you, facing the way the route starts.
  void start() {
    if (active || nav.currentNode == null || nav.routeNodes.length < 2) return;
    _tracker = RouteTracker(nav.map, nav.routeNodes, stepMetres: stepMetres);
    _onLift = false;
    _warnedOffRoute = false;
    _lastSpoken = null;
    stepCount = 0;
    final sensors = _sensors();
    _subs
      ..add(sensors.accelerometer.listen(_onAccel, onError: (Object _) {}))
      ..add(sensors.magnetometer.listen(_onMag, onError: (Object _) {}));
    final barometer = sensors.barometer;
    if (barometer != null) _subs.add(barometer.listen(_onPressure, onError: (Object _) {}));
    nav.addListener(_onNavChanged);
    _say(prompt);
    notifyListeners();
  }

  void stop() {
    if (!active) return;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    nav.removeListener(_onNavChanged);
    _tracker = null;
    unawaited(speaker.stop());
    notifyListeners();
  }

  /// You say the lift or stairs ride is over (no barometer, or it missed it).
  void arrivedOnFloor() {
    final tracker = _tracker;
    if (tracker == null || !tracker.onLiftOrStairs) return;
    _reached(tracker.finishFloorChange());
  }

  void _onAccel((Vec3, Duration) reading) {
    final (accel, time) = reading;
    _gravity = accel;
    if (_steps.add(accel, time)) _onStep();
  }

  void _onMag(Vec3 mag) {
    final gravity = _gravity;
    if (gravity == null) return;
    final heading = compassHeading(gravity, mag);
    if (heading != null) _heading.add(heading);
  }

  void _onStep() {
    final tracker = _tracker;
    final heading = _heading.value;
    if (tracker == null || heading == null) return;
    stepCount++;
    if (!tracker.calibrated) tracker.calibrate(heading);
    final wasOff = tracker.offRoute;
    final passed = tracker.step(heading);
    if (tracker.offRoute && !wasOff && !_warnedOffRoute) {
      _warnedOffRoute = true;
      _say(prompt);
    }
    _reached(passed);
    _announce();
    notifyListeners();
  }

  void _onPressure(double hPa) {
    final tracker = _tracker;
    if (tracker == null) return;
    final floors = _pressure.add(hPa);
    if (!tracker.onLiftOrStairs) {
      _onLift = false;
      return;
    }
    if (!_onLift) {
      _onLift = true;
      _pressure.reset();
      return;
    }
    // Most of a storey up or down: the ride is over.
    if (floors.abs() >= 0.7) _reached(tracker.finishFloorChange());
  }

  /// Marks named places you walked past as reached. The route is then worked
  /// out again from there (with the same compass calibration).
  void _reached(List<MapNode> passed) {
    final named = passed.where((n) => !n.automatic && n.type != NodeType.corridor).toList();
    if (named.isEmpty) return;
    final at = named.last;
    final old = _tracker!;
    _moving = true;
    try {
      nav.setCurrentLocation(at.id);
    } finally {
      _moving = false;
    }
    if (nav.hasArrived) {
      _say('You have arrived at ${at.name}');
      stop();
      return;
    }
    _rebuild(old);
    _say(prompt);
  }

  /// The location changed some other way (a scan, "I'm at", a new
  /// destination): follow the new route from there.
  void _onNavChanged() {
    if (_moving || _tracker == null) return;
    if (nav.hasArrived || nav.routeNodes.length < 2) {
      stop();
      return;
    }
    _rebuild(_tracker!);
    _tracker!.resume();
    _warnedOffRoute = false;
    notifyListeners();
  }

  void _rebuild(RouteTracker old) {
    final fresh = RouteTracker(nav.map, nav.routeNodes, stepMetres: stepMetres)..offset = old.offset;
    final first = fresh.currentLeg;
    if (old.calibrated && first != null && !first.vertical) {
      fresh.calibrate(normaliseAngle(first.angle - old.offset));
    }
    _tracker = fresh;
    _onLift = false;
  }

  static String? _keyOf(NextAction? action) =>
      action == null ? null : '${action.text}|${action.metres < 4 ? 'now' : 'ahead'}';

  void _announce() {
    final action = _tracker?.nextAction();
    if (action == null) return;
    // Speak a turn once when it comes up, again when it is right ahead.
    final key = _keyOf(action);
    if (key == _lastSpoken) return;
    if (action.metres < 4 && action.turn != 0) onTurn?.call();
    _lastSpoken = key;
    unawaited(speaker.say(describeAhead(action)));
  }

  void _say(String text) {
    if (text.isEmpty) return;
    _lastSpoken = _keyOf(_tracker?.nextAction());
    unawaited(speaker.say(text));
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
