import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../map/corridor_network.dart' show Pt;

/// A line drawing read from a DXF file: every wall, door and outline as a
/// polyline, tagged with its CAD layer.
class DxfDrawing {
  const DxfDrawing({required this.shapes, required this.metresPerUnit, required this.unitsGuessed});

  final List<DxfShape> shapes;

  /// Real size of one drawing unit, from the file's $INSUNITS.
  final double metresPerUnit;

  /// True when the file didn't say its units and they were guessed from the
  /// drawing's size.
  final bool unitsGuessed;

  /// Layer name -> number of shapes on it, most used first.
  Map<String, int> get layers {
    final counts = <String, int>{};
    for (final s in shapes) {
      counts[s.layer] = (counts[s.layer] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }
}

class DxfShape {
  const DxfShape(this.layer, this.points);

  final String layer;
  final List<Pt> points;
}

class DxfFormatException implements Exception {
  const DxfFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Layers that usually hold text, dimensions, furniture or the title block
/// rather than walls; unticked by default when importing.
final RegExp clutterLayer = RegExp(r'text|dim|anno|hatch|furn|title|border|frame|grid|note|label|symbol', caseSensitive: false);

/// Metres per unit for DXF $INSUNITS codes.
const Map<int, double> _units = {1: 0.0254, 2: 0.3048, 4: 0.001, 5: 0.01, 6: 1, 3: 1609.344, 7: 1000, 14: 0.1};

/// Reads an ASCII DXF (AutoCAD "Save As DXF"). Lines, polylines, arcs,
/// circles, splines and blocks (doors, windows) are kept; text, dimensions
/// and hatching are skipped.
DxfDrawing parseDxf(String source) {
  if (source.startsWith('AutoCAD Binary DXF')) {
    throw const DxfFormatException('This is a binary DXF. Save it again as an ASCII DXF and import that.');
  }
  final lines = source.split(RegExp(r'\r?\n'));
  final pairs = <(int, String)>[];
  for (var i = 0; i + 1 < lines.length; i += 2) {
    final code = int.tryParse(lines[i].trim());
    if (code == null) throw const DxfFormatException('This file is not a DXF drawing.');
    pairs.add((code, lines[i + 1].trim()));
  }
  if (!pairs.any((p) => p.$1 == 0 && p.$2 == 'SECTION')) {
    throw const DxfFormatException('This file is not a DXF drawing.');
  }

  int? insUnits;
  final blocks = <String, List<_Entity>>{};
  final entities = <_Entity>[];

  var i = 0;
  while (i < pairs.length) {
    final (code, value) = pairs[i];
    if (code == 9 && value == r'$INSUNITS' && i + 1 < pairs.length) {
      insUnits = int.tryParse(pairs[i + 1].$2);
    }
    if (code == 0 && value == 'SECTION' && i + 1 < pairs.length && pairs[i + 1].$1 == 2) {
      final section = pairs[i + 1].$2;
      i += 2;
      if (section == 'BLOCKS') {
        i = _readBlocks(pairs, i, blocks);
      } else if (section == 'ENTITIES') {
        i = _readEntities(pairs, i, entities, end: 'ENDSEC');
      }
      continue;
    }
    i++;
  }

  final shapes = <DxfShape>[];
  for (final e in entities) {
    e.expand(blocks, _Transform.identity, shapes, 0);
  }
  if (shapes.isEmpty) throw const DxfFormatException('No lines were found in this drawing.');

  var metres = _units[insUnits];
  var guessed = false;
  if (metres == null) {
    // No units given: buildings are tens of metres across, so a drawing
    // thousands of units wide is in millimetres.
    final (minX, minY, maxX, maxY) = _bounds(shapes);
    final span = math.max(maxX - minX, maxY - minY);
    metres = span > 2000 ? 0.001 : (span > 300 ? 0.01 : 1.0);
    guessed = true;
  }
  return DxfDrawing(shapes: shapes, metresPerUnit: metres, unitsGuessed: guessed);
}

/// The drawing rendered as a white PNG with black lines, the longer side
/// [maxPixels] wide, keeping only [layers]. Also returns the size and the
/// real scale of the image.
Future<({Uint8List png, int width, int height, double metresPerPixel})> renderDxf(
  DxfDrawing drawing, {
  required Set<String> layers,
  int maxPixels = 2400,
}) async {
  final shapes = drawing.shapes.where((s) => layers.contains(s.layer)).toList();
  if (shapes.isEmpty) throw const DxfFormatException('Choose at least one layer with walls on it.');
  final (minX, minY, maxX, maxY) = _bounds(shapes);
  final spanX = math.max(maxX - minX, 1e-6);
  final spanY = math.max(maxY - minY, 1e-6);
  final margin = 0.03 * math.max(spanX, spanY);
  final unitsWide = spanX + 2 * margin;
  final unitsHigh = spanY + 2 * margin;
  final pixelsPerUnit = maxPixels / math.max(unitsWide, unitsHigh);
  final width = math.max(1, (unitsWide * pixelsPerUnit).round());
  final height = math.max(1, (unitsHigh * pixelsPerUnit).round());

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  final pen = ui.Paint()
    ..color = const ui.Color(0xFF111111)
    ..strokeWidth = math.max(1.5, maxPixels / 1200)
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  // DXF y points up; images y points down.
  ui.Offset toPixels(Pt p) => ui.Offset((p.x - minX + margin) * pixelsPerUnit, (maxY - p.y + margin) * pixelsPerUnit);
  for (final s in shapes) {
    final path = ui.Path()..moveTo(toPixels(s.points.first).dx, toPixels(s.points.first).dy);
    for (final p in s.points.skip(1)) {
      final o = toPixels(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, pen);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return (
      png: data!.buffer.asUint8List(),
      width: width,
      height: height,
      metresPerPixel: drawing.metresPerUnit / pixelsPerUnit,
    );
  } finally {
    image.dispose();
  }
}

(double, double, double, double) _bounds(List<DxfShape> shapes) {
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final s in shapes) {
    for (final p in s.points) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
  }
  return (minX, minY, maxX, maxY);
}

int _readBlocks(List<(int, String)> pairs, int i, Map<String, List<_Entity>> blocks) {
  while (i < pairs.length) {
    final (code, value) = pairs[i];
    if (code == 0 && value == 'ENDSEC') return i + 1;
    if (code == 0 && value == 'BLOCK') {
      var name = '';
      var baseX = 0.0, baseY = 0.0;
      i++;
      while (i < pairs.length && pairs[i].$1 != 0) {
        final (c, v) = pairs[i];
        if (c == 2) name = v;
        if (c == 10) baseX = double.tryParse(v) ?? 0;
        if (c == 20) baseY = double.tryParse(v) ?? 0;
        i++;
      }
      final list = <_Entity>[];
      i = _readEntities(pairs, i, list, end: 'ENDBLK');
      blocks[name] = [for (final e in list) e.shifted(-baseX, -baseY)];
      continue;
    }
    i++;
  }
  return i;
}

/// Reads entities until a `0 / [end]` pair; returns the index after it.
int _readEntities(List<(int, String)> pairs, int i, List<_Entity> out, {required String end}) {
  while (i < pairs.length) {
    final (code, type) = pairs[i];
    if (code != 0) {
      i++;
      continue;
    }
    if (type == end) return i + 1;
    // Group codes of this entity, up to the next entity.
    final start = ++i;
    while (i < pairs.length && pairs[i].$1 != 0) {
      i++;
    }
    final fields = pairs.sublist(start, i);
    if (type == 'POLYLINE') {
      // Old-style polyline: VERTEX entities follow until SEQEND.
      final vertices = <Pt>[];
      while (i < pairs.length && pairs[i].$1 == 0 && pairs[i].$2 == 'VERTEX') {
        final vStart = ++i;
        while (i < pairs.length && pairs[i].$1 != 0) {
          i++;
        }
        final v = pairs.sublist(vStart, i);
        vertices.add((x: _num(v, 10), y: _num(v, 20)));
      }
      if (i < pairs.length && pairs[i].$2 == 'SEQEND') {
        i++;
        while (i < pairs.length && pairs[i].$1 != 0) {
          i++;
        }
      }
      final closed = (_int(fields, 70) & 1) == 1;
      if (vertices.length >= 2) out.add(_Entity.polyline(_layer(fields), closed ? [...vertices, vertices.first] : vertices));
      continue;
    }
    final entity = _Entity.parse(type, fields);
    if (entity != null) out.add(entity);
  }
  return i;
}

String _layer(List<(int, String)> f) => f.firstWhere((p) => p.$1 == 8, orElse: () => (8, '0')).$2;

double _num(List<(int, String)> f, int code, [double fallback = 0]) {
  for (final (c, v) in f) {
    if (c == code) return double.tryParse(v) ?? fallback;
  }
  return fallback;
}

int _int(List<(int, String)> f, int code) => _num(f, code).round();

List<double> _all(List<(int, String)> f, int code) => [
  for (final (c, v) in f)
    if (c == code) double.tryParse(v) ?? 0,
];

List<Pt> _arc(double cx, double cy, double r, double startDeg, double endDeg) {
  var sweep = endDeg - startDeg;
  if (sweep <= 0) sweep += 360;
  final steps = math.max(2, (sweep / 10).ceil());
  return [
    for (var k = 0; k <= steps; k++)
      (
        x: cx + r * math.cos((startDeg + sweep * k / steps) * math.pi / 180),
        y: cy + r * math.sin((startDeg + sweep * k / steps) * math.pi / 180),
      ),
  ];
}

class _Transform {
  const _Transform(this.a, this.b, this.c, this.d, this.tx, this.ty);

  static const identity = _Transform(1, 0, 0, 1, 0, 0);

  // x' = a*x + c*y + tx ; y' = b*x + d*y + ty
  final double a, b, c, d, tx, ty;

  Pt apply(Pt p) => (x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty);

  /// This transform applied after [inner].
  _Transform then(_Transform inner) => _Transform(
    a * inner.a + c * inner.b,
    b * inner.a + d * inner.b,
    a * inner.c + c * inner.d,
    b * inner.c + d * inner.d,
    a * inner.tx + c * inner.ty + tx,
    b * inner.tx + d * inner.ty + ty,
  );
}

class _Entity {
  _Entity.polyline(this.layer, this.points) : block = null, insert = null;
  _Entity.insertOf(this.layer, this.block, this.insert) : points = const [];

  final String layer;
  final List<Pt> points;
  final String? block;
  final _Transform? insert;

  static _Entity? parse(String type, List<(int, String)> f) {
    final layer = _layer(f);
    switch (type) {
      case 'LINE':
        return _Entity.polyline(layer, [(x: _num(f, 10), y: _num(f, 20)), (x: _num(f, 11), y: _num(f, 21))]);
      case 'LWPOLYLINE':
        final xs = _all(f, 10);
        final ys = _all(f, 20);
        final points = [for (var k = 0; k < math.min(xs.length, ys.length); k++) (x: xs[k], y: ys[k])];
        if (points.length < 2) return null;
        final closed = (_int(f, 70) & 1) == 1;
        return _Entity.polyline(layer, closed ? [...points, points.first] : points);
      case 'SPLINE':
        // Fit points if present, else control points: close enough for walls.
        var xs = _all(f, 11);
        var ys = _all(f, 21);
        if (xs.length < 2) {
          xs = _all(f, 10);
          ys = _all(f, 20);
        }
        final points = [for (var k = 0; k < math.min(xs.length, ys.length); k++) (x: xs[k], y: ys[k])];
        return points.length < 2 ? null : _Entity.polyline(layer, points);
      case 'ARC':
        return _Entity.polyline(layer, _arc(_num(f, 10), _num(f, 20), _num(f, 40), _num(f, 50), _num(f, 51)));
      case 'CIRCLE':
        return _Entity.polyline(layer, _arc(_num(f, 10), _num(f, 20), _num(f, 40), 0, 360));
      case 'INSERT':
        final name = f.firstWhere((p) => p.$1 == 2, orElse: () => (2, '')).$2;
        final sx = _num(f, 41, 1);
        final sy = _num(f, 42, 1);
        final angle = _num(f, 50) * math.pi / 180;
        final cos = math.cos(angle);
        final sin = math.sin(angle);
        return _Entity.insertOf(
          layer,
          name,
          _Transform(sx * cos, sx * sin, -sy * sin, sy * cos, _num(f, 10), _num(f, 20)),
        );
      default:
        return null; // text, dimensions, hatches, ...
    }
  }

  _Entity shifted(double dx, double dy) => block == null
      ? _Entity.polyline(layer, [for (final p in points) (x: p.x + dx, y: p.y + dy)])
      : _Entity.insertOf(layer, block, _Transform(1, 0, 0, 1, dx, dy).then(insert!));

  void expand(Map<String, List<_Entity>> blocks, _Transform outer, List<DxfShape> out, int depth) {
    final name = block;
    if (name == null) {
      out.add(DxfShape(layer, [for (final p in points) outer.apply(p)]));
      return;
    }
    if (depth > 6) return; // guard against blocks that include themselves
    final transform = outer.then(insert!);
    for (final e in blocks[name] ?? const <_Entity>[]) {
      // Entities on layer "0" inside a block take the layer of the insert.
      final inner = e.layer == '0' && e.block == null ? _Entity.polyline(layer, e.points) : e;
      inner.expand(blocks, transform, out, depth + 1);
    }
  }
}
