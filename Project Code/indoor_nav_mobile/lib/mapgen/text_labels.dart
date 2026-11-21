import 'dart:math' as math;

import '../map/building_map.dart';
import '../setup/building_draft.dart';

/// A line of text read from a blueprint, with its box in drawing pixels.
class TextLabel {
  const TextLabel(this.text, {required this.left, required this.top, required this.right, required this.bottom});

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  Pt get centre => (x: (left + right) / 2, y: (top + bottom) / 2);
}

/// What a label on a plan says an area is.
enum LabelMeaning { stairs, lift, corridor, name, noise }

final RegExp _stairs = RegExp(r'\bstair', caseSensitive: false);
final RegExp _lift = RegExp(r'\b(lift|elevator|elev)\b', caseSensitive: false);
final RegExp _corridor = RegExp(r'\b(corridor|passage|lobby|hallway)\b', caseSensitive: false);
final RegExp _hasWord = RegExp(r'[A-Za-z0-9]{2,}|[A-Za-z]\s*-?\s*\d');

LabelMeaning classifyLabel(String text) {
  if (_stairs.hasMatch(text)) return LabelMeaning.stairs;
  if (_lift.hasMatch(text)) return LabelMeaning.lift;
  if (_corridor.hasMatch(text)) return LabelMeaning.corridor;
  return _hasWord.hasMatch(text) ? LabelMeaning.name : LabelMeaning.noise;
}

/// "NODE-4" -> "Node-4", "room   101" -> "Room 101".
String cleanLabel(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words
      .map((w) => w.length <= 1 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// What reading the plan's text changed.
class LabelResult {
  int named = 0;
  int stairs = 0;
  int lifts = 0;
  int corridors = 0;

  int get total => named + stairs + lifts + corridors;

  @override
  String toString() => [
    if (named > 0) '$named ${named == 1 ? 'room' : 'rooms'} named',
    if (stairs > 0) '$stairs stairs',
    if (lifts > 0) '$lifts ${lifts == 1 ? 'lift' : 'lifts'}',
    if (corridors > 0) '$corridors ${corridors == 1 ? 'corridor' : 'corridors'}',
  ].join(', ');
}

/// Uses the text printed on a blueprint to fill in its generated map:
/// "STAIRS" and "LIFT" mark those areas (as places, linked across floors),
/// "CORRIDOR" marks walkways, and other labels name the room they sit in.
/// Areas that already have a place are left as they are, so nothing the
/// user named is overwritten. With [nameRooms] false only stairs, lifts and
/// corridors are used.
LabelResult applyTextLabels(BuildingDraft draft, int level, List<TextLabel> labels, {bool nameRooms = true}) {
  final result = LabelResult();
  final floor = draft.floor(level);
  final reach = 0.05 * math.max(floor.width, floor.height);

  // Lines that fall in the same area are one label ("NODE" over "18").
  final byRegion = <String, List<TextLabel>>{};
  final kinds = <String, LabelMeaning>{};
  for (final label in labels) {
    final meaning = classifyLabel(label.text);
    if (meaning == LabelMeaning.noise) continue;
    var region = draft.regionAt(level, label.centre);
    // Stairs and lifts are often hatched, so their label sits on what came
    // out as wall: use a stairs or lift area close by instead.
    if ((region == null || region.kind == RegionKind.corridor) &&
        (meaning == LabelMeaning.stairs || meaning == LabelMeaning.lift)) {
      region = _nearest(floor.regions, label.centre, reach, (r) => r.kind == RegionKind.stairs || r.kind == RegionKind.lift);
    }
    if (region == null || (region.kind == RegionKind.ignored && meaning == LabelMeaning.name)) continue;
    byRegion.putIfAbsent(region.id, () => []).add(label);
    // The strongest meaning wins: stairs/lift over corridor over a name.
    final previous = kinds[region.id];
    if (previous == null || meaning.index < previous.index) kinds[region.id] = meaning;
  }

  var stairsCount = draft.nodesOn(level).where((n) => n.type == NodeType.stairs).length;
  var liftCount = draft.nodesOn(level).where((n) => n.type == NodeType.lift).length;
  for (final entry in byRegion.entries) {
    final id = entry.key;
    if (draft.placeFor(id, level) != null) continue; // already set up
    final region = floor.region(id);
    if (region == null) continue;
    switch (kinds[id]!) {
      case LabelMeaning.stairs:
        stairsCount++;
        draft.assignPlace(level, id, name: stairsCount == 1 ? 'Stairs' : 'Stairs $stairsCount', type: NodeType.stairs);
        result.stairs++;
      case LabelMeaning.lift:
        liftCount++;
        draft.assignPlace(level, id, name: liftCount == 1 ? 'Lift' : 'Lift $liftCount', type: NodeType.lift);
        result.lifts++;
      case LabelMeaning.corridor:
        if (region.kind != RegionKind.corridor) {
          draft.setRegionKind(level, id, RegionKind.corridor);
          result.corridors++;
        }
      case LabelMeaning.name:
        if (!nameRooms || region.kind != RegionKind.room) continue;
        final lines = [...entry.value]..sort((a, b) {
          final row = (a.top - b.top).abs() < (a.bottom - a.top) / 2 ? 0 : a.top.compareTo(b.top);
          return row != 0 ? row : a.left.compareTo(b.left);
        });
        final name = cleanLabel(lines.map((l) => l.text).join(' '));
        if (name.isEmpty) continue;
        draft.assignPlace(level, id, name: name, type: NodeType.room);
        result.named++;
      case LabelMeaning.noise:
        continue;
    }
  }
  return result;
}

FloorRegion? _nearest(List<FloorRegion> regions, Pt p, double reach, bool Function(FloorRegion) wanted) {
  FloorRegion? best;
  var bestDistance = reach;
  for (final r in regions) {
    if (!wanted(r)) continue;
    final xs = r.outline.map((q) => q.x), ys = r.outline.map((q) => q.y);
    final dx = math.max(0, math.max(xs.reduce(math.min) - p.x, p.x - xs.reduce(math.max)));
    final dy = math.max(0, math.max(ys.reduce(math.min) - p.y, p.y - ys.reduce(math.max)));
    final d = math.sqrt(dx * dx + dy * dy);
    if (d <= bestDistance) {
      best = r;
      bestDistance = d;
    }
  }
  return best;
}
