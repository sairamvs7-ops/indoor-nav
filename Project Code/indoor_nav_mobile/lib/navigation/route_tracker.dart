import 'dart:math' as math;

import '../map/building_map.dart';
import 'motion.dart';

/// One straight piece of a route: a corridor stretch on one floor, or a lift
/// or stairs ride between floors ([vertical]).
class RouteLeg {
  RouteLeg({required this.from, required this.to, required this.metres});

  final MapNode from;
  final MapNode to;

  /// Walking length; 0 for vertical legs.
  final double metres;

  bool get vertical => from.floor != to.floor;

  /// Direction on the floor plan, clockwise from the drawing's +x axis.
  double get angle => math.atan2(to.y - from.y, to.x - from.x);
}

/// What to do next while walking.
class NextAction {
  const NextAction({required this.metres, required this.text, this.turn = 0});

  /// How far ahead it is.
  final double metres;
  final String text;

  /// Signed turn angle in radians (positive = right), 0 for "go straight".
  final double turn;
}

/// Follows you along a route from footsteps and heading. Your position is
/// kept on the route (it can't drift through walls): steps in the route's
/// direction move you forward; steps the wrong way for a while mean you left
/// the route.
class RouteTracker {
  RouteTracker(this.map, List<int> route, {this.stepMetres = 0.7}) : legs = _legs(map, route);

  final BuildingMap map;
  final List<RouteLeg> legs;
  final double stepMetres;

  int _leg = 0;
  double _along = 0;
  int _wrongWaySteps = 0;

  /// The difference between compass north and the drawing's +x axis: the
  /// drawing's angle for a compass heading is heading + [offset].
  double offset = 0;
  bool _calibrated = false;

  /// Steps in a row walked well away from the route direction before
  /// [offRoute] turns on.
  static const int wrongWayLimit = 8;

  static List<RouteLeg> _legs(BuildingMap map, List<int> route) => [
    for (var i = 0; i + 1 < route.length; i++)
      () {
        final a = map.node(route[i]), b = map.node(route[i + 1]);
        final metres = a.floor == b.floor
            ? math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2)) * map.floor(a.floor).effectiveMetresPerPixel
            : 0.0;
        return RouteLeg(from: a, to: b, metres: metres);
      }(),
  ];

  RouteLeg? get currentLeg => _leg < legs.length ? legs[_leg] : null;
  bool get finished => _leg >= legs.length;
  bool get onLiftOrStairs => currentLeg?.vertical ?? false;
  bool get offRoute => _wrongWaySteps >= wrongWayLimit;
  bool get calibrated => _calibrated;

  /// Where you are: the floor and the point on the drawing.
  (int floor, double x, double y) get position {
    final leg = currentLeg;
    if (leg == null) {
      final last = legs.isEmpty ? null : legs.last.to;
      return (last?.floor ?? 0, last?.x ?? 0, last?.y ?? 0);
    }
    if (leg.vertical || leg.metres == 0) return (leg.from.floor, leg.from.x, leg.from.y);
    final t = (_along / leg.metres).clamp(0.0, 1.0);
    return (leg.from.floor, leg.from.x + (leg.to.x - leg.from.x) * t, leg.from.y + (leg.to.y - leg.from.y) * t);
  }

  /// Metres left to walk to the destination.
  double get remainingMetres {
    var total = 0.0;
    for (var i = _leg; i < legs.length; i++) {
      total += legs[i].metres;
    }
    return math.max(0, total - _along);
  }

  /// Lines the compass up with the drawing: you are facing along the first
  /// walking leg with this [heading].
  void calibrate(double heading) {
    final leg = currentLeg;
    if (leg == null || leg.vertical) return;
    offset = angleBetween(leg.angle, heading);
    _calibrated = true;
  }

  /// One footstep, walking with compass [heading]. Returns the places passed
  /// during it (in order), so they can be announced and marked reached.
  List<MapNode> step(double heading) {
    final leg = currentLeg;
    if (leg == null || leg.vertical) return const [];
    final walking = normaliseAngle(heading + offset);
    final off = angleBetween(walking, leg.angle);
    if (off.abs() > 1.4) {
      // Well away from the route direction (more than ~80 degrees).
      _wrongWaySteps++;
      return const [];
    }
    _wrongWaySteps = 0;
    // Walking straight along a corridor: nudge the compass to match, so slow
    // drift in the magnetometer doesn't build up.
    if (off.abs() < 0.45) offset = normaliseAngle(offset - 0.08 * off);
    _along += stepMetres * math.cos(off);
    return _advance();
  }

  /// The lift or stairs ride is over (pressure changed, or you said so).
  List<MapNode> finishFloorChange() {
    if (!onLiftOrStairs) return const [];
    final passed = [legs[_leg].to];
    _leg++;
    _along = 0;
    return [...passed, ..._advance()];
  }

  /// Clears the off-route warning (after a rescan put you back on track).
  void resume() => _wrongWaySteps = 0;

  List<MapNode> _advance() {
    final passed = <MapNode>[];
    while (_leg < legs.length && !legs[_leg].vertical && _along >= legs[_leg].metres) {
      _along -= legs[_leg].metres;
      passed.add(legs[_leg].to);
      _leg++;
    }
    if (_leg < legs.length && legs[_leg].vertical) _along = 0;
    return passed;
  }

  /// The next turn, lift or stairs, or the destination, with how far it is.
  NextAction? nextAction() {
    if (finished) return null;
    var ahead = -_along;
    for (var i = _leg; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.vertical) {
        final up = map.floors.indexWhere((f) => f.level == leg.to.floor) >
            map.floors.indexWhere((f) => f.level == leg.from.floor);
        return NextAction(
          metres: math.max(0, ahead),
          text: 'Take ${leg.from.name} ${up ? 'up' : 'down'} to ${map.floor(leg.to.floor).name}',
        );
      }
      ahead += leg.metres;
      if (i + 1 >= legs.length) {
        return NextAction(metres: math.max(0, ahead), text: 'Arrive at ${leg.to.name}');
      }
      final next = legs[i + 1];
      if (next.vertical || next.metres < 0.5) continue;
      final turn = angleBetween(next.angle, leg.angle);
      if (turn.abs() < 0.6) continue; // under ~35 degrees: keep going
      final side = turn > 0 ? 'right' : 'left';
      final sharp = turn.abs() > 2.2 ? 'sharp ' : (turn.abs() < 0.9 ? 'slight ' : '');
      final at = leg.to.type == NodeType.corridor ? '' : ' at ${leg.to.name}';
      return NextAction(metres: math.max(0, ahead), text: 'Turn $sharp$side$at', turn: turn);
    }
    return null;
  }
}

/// "In 12 m, turn left", rounded the way people say distances.
String describeAhead(NextAction action) {
  final m = action.metres;
  if (m < 3) return action.text;
  final rounded = m < 20 ? m.round() : (m / 5).round() * 5;
  final verb = action.text.isEmpty ? '' : action.text[0].toLowerCase() + action.text.substring(1);
  return 'In $rounded m, $verb';
}
