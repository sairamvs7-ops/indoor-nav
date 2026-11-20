import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../map/corridor_network.dart' show Pt, simplifyStroke;
import '../map/floor_regions.dart';

export '../map/floor_regions.dart' show RegionKind;

/// One enclosed area found on a blueprint: a room, a corridor, a stairwell.
class GeneratedRegion {
  const GeneratedRegion({required this.outline, required this.kind, this.paths = const []});

  /// Closed polygon in drawing pixels (first point not repeated).
  final List<Pt> outline;
  final RegionKind kind;

  /// For corridors: walkable centrelines, in drawing pixels.
  final List<List<Pt>> paths;
}

/// The vector floor map made from a blueprint image.
class GeneratedFloorMap {
  const GeneratedFloorMap({required this.width, required this.height, required this.regions});

  /// Size of the blueprint the coordinates refer to.
  final double width;
  final double height;
  final List<GeneratedRegion> regions;
}

/// How hard to close gaps (doorways) in the walls, as a share of the drawing's
/// longer side. Bigger closes wider doorways but can merge small rooms.
enum GapClosing {
  narrow(0.007),
  normal(0.012),
  wide(0.02);

  const GapClosing(this.share);

  final double share;
}

/// Longest side the blueprint is analysed at. Plenty for room shapes, and
/// fast enough on a phone.
const int _workSize = 640;

/// Finds the walls, rooms and corridors on a blueprint image and returns
/// them as clean polygons. Works with dark lines on light paper and with
/// light lines on a dark (classic blue) blueprint. Text, dimension marks and
/// small symbols are ignored because they are small separate specks.
///
/// Runs in well under a second for a 2400 px image; call it in an isolate
/// ([Isolate.run]) to keep the UI smooth.
GeneratedFloorMap generateFloorMap(Uint8List imageBytes, {GapClosing gaps = GapClosing.normal}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(imageBytes);
  } on Object {
    decoded = null; // the decoder can throw on damaged or non-image files
  }
  if (decoded == null) throw const FormatException('This image could not be read.');
  final grid = _Grid.fromImage(decoded);
  final regions = detectRegions(grid.walls, grid.width, grid.height, gapShare: gaps.share);
  final sx = decoded.width / grid.width;
  final sy = decoded.height / grid.height;
  Pt scale(Pt p) => (x: p.x * sx, y: p.y * sy);
  return GeneratedFloorMap(
    width: decoded.width.toDouble(),
    height: decoded.height.toDouble(),
    regions: [
      for (final r in regions)
        GeneratedRegion(
          outline: [for (final p in r.outline) scale(p)],
          kind: r.kind,
          paths: [
            for (final path in r.paths) [for (final p in path) scale(p)],
          ],
        ),
    ],
  );
}

/// The blueprint reduced to a wall mask at working resolution.
class _Grid {
  _Grid(this.width, this.height, this.walls);

  factory _Grid.fromImage(img.Image source) {
    final longest = math.max(source.width, source.height);
    final image = longest > _workSize
        ? img.copyResize(
            source,
            width: source.width >= source.height ? _workSize : null,
            height: source.height > source.width ? _workSize : null,
            interpolation: img.Interpolation.average,
          )
        : source;
    final w = image.width;
    final h = image.height;
    final lum = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final a = image.hasAlpha ? p.aNormalized : 1.0;
        // Transparent pixels count as white paper.
        final v = 0.299 * p.rNormalized + 0.587 * p.gNormalized + 0.114 * p.bNormalized;
        lum[y * w + x] = ((v * a + (1 - a)) * 255).round().clamp(0, 255).toInt();
      }
    }
    final threshold = _otsu(lum);
    var dark = 0;
    for (final v in lum) {
      if (v < threshold) dark++;
    }
    // Lines are the minority. If most of the image is dark it is a blue
    // (white-line) blueprint, so the light pixels are the walls.
    final invert = dark > lum.length / 2;
    final walls = Uint8List(w * h);
    for (var i = 0; i < lum.length; i++) {
      walls[i] = ((lum[i] < threshold) != invert) ? 1 : 0;
    }
    return _Grid(w, h, walls);
  }

  final int width;
  final int height;
  final Uint8List walls;
}

int _otsu(Uint8List values) {
  final histogram = List<int>.filled(256, 0);
  for (final v in values) {
    histogram[v]++;
  }
  final total = values.length;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * histogram[i];
  }
  var sumBack = 0.0, weightBack = 0, best = 0.0, threshold = 128;
  for (var t = 0; t < 256; t++) {
    weightBack += histogram[t];
    if (weightBack == 0) continue;
    final weightFore = total - weightBack;
    if (weightFore == 0) break;
    sumBack += t * histogram[t];
    final meanBack = sumBack / weightBack;
    final meanFore = (sum - sumBack) / weightFore;
    final between = weightBack * weightFore * (meanBack - meanFore) * (meanBack - meanFore);
    if (between > best) {
      best = between;
      threshold = t + 1;
    }
  }
  return threshold;
}

/// A region found on the wall mask, in grid pixels.
class DetectedRegion {
  const DetectedRegion({required this.outline, required this.kind, required this.area, this.paths = const []});

  final List<Pt> outline;
  final RegionKind kind;
  final int area;
  final List<List<Pt>> paths;
}

/// Finds enclosed areas on a [walls] mask (1 = wall, row-major, [w] x [h]).
/// Exposed for tests; [generateFloorMap] is the normal entry point.
List<DetectedRegion> detectRegions(Uint8List walls, int width, int height, {double gapShare = 0.012}) {
  // Work on a copy with a blank margin, so a building drawn right up to the
  // edge of the image still has an "outside" around it.
  final longest = math.max(width, height);
  final pad = (longest * 0.08).ceil() + 2;
  final w = width + 2 * pad;
  final h = height + 2 * pad;
  final n = w * h;
  final padded = Uint8List(n);
  for (var y = 0; y < height; y++) {
    padded.setRange((y + pad) * w + pad, (y + pad) * w + pad + width, walls, y * width);
  }

  // 1. Drop specks: text, dimension ticks, furniture symbols. Walls are long
  //    connected lines; letters are small separate blobs.
  final clean = padded;
  final minSpeckArea = math.max(12, (n * 0.00015).round());
  final minSpeckSpan = math.max(4, (longest * 0.03).round());
  _components(clean, w, h, eight: true, onComponent: (pixels, minX, minY, maxX, maxY) {
    final span = math.max(maxX - minX, maxY - minY) + 1;
    if (pixels.length < minSpeckArea || span < minSpeckSpan) {
      for (final i in pixels) {
        clean[i] = 0;
      }
    }
  });

  // 2. Thicken walls to close doorways, so each room is enclosed.
  final r = math.max(1, (gapShare * longest).round());
  final closed = _dilate(clean, w, h, r);

  // 3. Find what is outside the building. Entrances are gaps in the outer
  //    wall, so seal much harder first, flood from the image edge, then grow
  //    the outside back to the wall line.
  final seal = r * 3;
  final sealed = _dilate(clean, w, h, seal);
  final open = Uint8List(n);
  for (var i = 0; i < n; i++) {
    open[i] = sealed[i] == 0 ? 1 : 0;
  }
  final outsideSeed = Uint8List(n);
  _components(open, w, h, eight: false, onComponent: (pixels, minX, minY, maxX, maxY) {
    if (minX == 0 || minY == 0 || maxX == w - 1 || maxY == h - 1) {
      for (final i in pixels) {
        outsideSeed[i] = 1;
      }
    }
  });
  final outside = _dilate(outsideSeed, w, h, seal);

  // 4. Each enclosed open area inside the building is a region.
  final labels = Int32List(n); // 0 = wall/outside, else region id
  final areas = <int, int>{};
  final boxes = <int, (int, int, int, int)>{};
  var next = 0;
  final minRoom = math.max(30, (n * 0.0012).round());
  final free = Uint8List(n);
  for (var i = 0; i < n; i++) {
    free[i] = closed[i] == 0 && outside[i] == 0 ? 1 : 0;
  }
  _components(free, w, h, eight: false, onComponent: (pixels, minX, minY, maxX, maxY) {
    final touchesEdge = minX == 0 || minY == 0 || maxX == w - 1 || maxY == h - 1;
    if (touchesEdge || pixels.length < minRoom || pixels.length > n * 0.7) return;
    final id = ++next;
    for (final i in pixels) {
      labels[i] = id;
    }
    areas[id] = pixels.length;
    boxes[id] = (minX, minY, maxX, maxY);
  });

  // 5. Grow regions back over the thickening (not over real walls), so rooms
  //    reach their walls and neighbouring rooms meet at doorways.
  final queue = Queue<int>();
  final depth = Int32List(n);
  for (var i = 0; i < n; i++) {
    if (labels[i] != 0) queue.add(i);
  }
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    if (depth[i] >= r) continue;
    final x = i % w, y = i ~/ w;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final j = ny * w + nx;
      if (labels[j] != 0 || clean[j] == 1 || closed[j] == 0 || outside[j] == 1) continue;
      labels[j] = labels[i];
      depth[j] = depth[i] + 1;
      areas[labels[i]] = areas[labels[i]]! + 1;
      queue.add(j);
    }
  }

  // 6. Trace, simplify and square up each region; long thin ones are corridors.
  final regions = <DetectedRegion>[];
  for (final id in areas.keys) {
    final contour = _trace(labels, w, h, id);
    if (contour.length < 4) continue;
    final outline = squareUp(_simplifyClosed(contour, math.max(1.2, longest * 0.004)));
    if (outline.length < 3) continue;
    final (minX, minY, maxX, maxY) = boxes[id]!;
    final bw = maxX - minX + 1 + 2 * r;
    final bh = maxY - minY + 1 + 2 * r;
    final aspect = math.max(bw, bh) / math.max(1, math.min(bw, bh));
    final fill = areas[id]! / (bw * bh);
    final corridor = aspect > 3.2 || (fill < 0.45 && areas[id]! > minRoom * 4);
    regions.add(
      DetectedRegion(
        outline: outline,
        kind: corridor ? RegionKind.corridor : RegionKind.room,
        area: areas[id]!,
        paths: corridor ? _centrelines(labels, w, h, id, spur: longest * 0.04) : const [],
      ),
    );
  }
  regions.sort((a, b) => b.area.compareTo(a.area));
  Pt unpad(Pt p) => (x: p.x - pad, y: p.y - pad);
  return [
    for (final r in regions)
      DetectedRegion(
        outline: [for (final p in r.outline) unpad(p)],
        kind: r.kind,
        area: r.area,
        paths: [
          for (final path in r.paths) [for (final p in path) unpad(p)],
        ],
      ),
  ];
}

/// Labels connected pixels of value 1 in [mask], calling [onComponent] with
/// each component's pixel indexes and bounding box.
void _components(
  Uint8List mask,
  int w,
  int h, {
  required bool eight,
  required void Function(List<int> pixels, int minX, int minY, int maxX, int maxY) onComponent,
}) {
  final seen = Uint8List(w * h);
  final stack = <int>[];
  for (var start = 0; start < w * h; start++) {
    if (mask[start] == 0 || seen[start] == 1) continue;
    final pixels = <int>[];
    var minX = w, minY = h, maxX = 0, maxY = 0;
    stack.add(start);
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      pixels.add(i);
      final x = i % w, y = i ~/ w;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          if (!eight && dx != 0 && dy != 0) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          if (mask[j] == 1 && seen[j] == 0) {
            seen[j] = 1;
            stack.add(j);
          }
        }
      }
    }
    onComponent(pixels, minX, minY, maxX, maxY);
  }
}

/// Square dilation by [r] pixels, done as two running-window passes.
Uint8List _dilate(Uint8List mask, int w, int h, int r) {
  final horizontal = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    var count = 0;
    for (var x = -r; x < w; x++) {
      final add = x + r;
      if (add < w && mask[y * w + add] == 1) count++;
      final remove = x - r - 1;
      if (remove >= 0 && mask[y * w + remove] == 1) count--;
      if (x >= 0) horizontal[y * w + x] = count > 0 ? 1 : 0;
    }
  }
  final out = Uint8List(w * h);
  for (var x = 0; x < w; x++) {
    var count = 0;
    for (var y = -r; y < h; y++) {
      final add = y + r;
      if (add < h && horizontal[add * w + x] == 1) count++;
      final remove = y - r - 1;
      if (remove >= 0 && horizontal[remove * w + x] == 1) count--;
      if (y >= 0) out[y * w + x] = count > 0 ? 1 : 0;
    }
  }
  return out;
}

const List<(int, int)> _ring = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)];

/// Outer boundary of region [id], clockwise, as pixel centres (Moore tracing).
List<Pt> _trace(Int32List labels, int w, int h, int id) {
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && labels[y * w + x] == id;
  var start = -1;
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] == id) {
      start = i;
      break;
    }
  }
  if (start < 0) return const [];
  final sx = start % w, sy = start ~/ w;
  final contour = <Pt>[(x: sx + 0.5, y: sy + 0.5)];
  var cx = sx, cy = sy;
  var from = 4; // we entered the start pixel from the west (scan order)
  final limit = 8 * w * h;
  for (var step = 0; step < limit; step++) {
    var found = false;
    for (var k = 1; k <= 8; k++) {
      final d = (from + k) % 8;
      final nx = cx + _ring[d].$1, ny = cy + _ring[d].$2;
      if (inside(nx, ny)) {
        cx = nx;
        cy = ny;
        // Next search starts just after the neighbour we came from.
        from = (d + 4) % 8;
        found = true;
        break;
      }
    }
    if (!found) break; // a single pixel
    if (cx == sx && cy == sy) break;
    contour.add((x: cx + 0.5, y: cy + 0.5));
  }
  return contour;
}

List<Pt> _simplifyClosed(List<Pt> ring, double tolerance) {
  if (ring.length < 4) return ring;
  // Split the ring at its farthest point from the start so both halves are
  // open lines, simplify each, and join.
  var far = 0;
  var best = 0.0;
  for (var i = 1; i < ring.length; i++) {
    final d = math.pow(ring[i].x - ring[0].x, 2) + math.pow(ring[i].y - ring[0].y, 2);
    if (d > best) {
      best = d.toDouble();
      far = i;
    }
  }
  final a = simplifyStroke(ring.sublist(0, far + 1), tolerance);
  final b = simplifyStroke([...ring.sublist(far), ring.first], tolerance);
  return [...a, ...b.sublist(1, b.length - 1)];
}

/// Makes nearly horizontal or vertical edges exactly so, which is how
/// buildings are drawn, then drops points that end up in a straight line.
List<Pt> squareUp(List<Pt> polygon, {double degrees = 10}) {
  if (polygon.length < 3) return polygon;
  final pts = [for (final p in polygon) (x: p.x, y: p.y)];
  final tan = math.tan(degrees * math.pi / 180);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final dx = (b.x - a.x).abs(), dy = (b.y - a.y).abs();
      if (dy <= dx * tan) {
        final y = (a.y + b.y) / 2;
        pts[i] = (x: a.x, y: y);
        pts[(i + 1) % pts.length] = (x: b.x, y: y);
      } else if (dx <= dy * tan) {
        final x = (a.x + b.x) / 2;
        pts[i] = (x: x, y: a.y);
        pts[(i + 1) % pts.length] = (x: x, y: b.y);
      }
    }
  }
  final out = <Pt>[];
  for (var i = 0; i < pts.length; i++) {
    final prev = pts[(i - 1 + pts.length) % pts.length];
    final p = pts[i];
    final next = pts[(i + 1) % pts.length];
    final cross = (p.x - prev.x) * (next.y - p.y) - (p.y - prev.y) * (next.x - p.x);
    final same = (p.x - prev.x).abs() < 1e-9 && (p.y - prev.y).abs() < 1e-9;
    if (cross.abs() > 1e-6 && !same) out.add(p);
  }
  return out;
}

/// Walkable centrelines of a corridor polygon (drawing pixels), found by
/// thinning the filled shape. [longest] is the drawing's longer side.
List<List<Pt>> corridorCentrelines(List<Pt> polygon, {required double longest}) {
  if (polygon.length < 3) return const [];
  // Rasterise at working resolution, then thin.
  final scale = _workSize / longest;
  var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
  for (final p in polygon) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final w = ((maxX - minX) * scale).ceil() + 3;
  final h = ((maxY - minY) * scale).ceil() + 3;
  final labels = Int32List(w * h);
  final scaled = [for (final p in polygon) (x: (p.x - minX) * scale + 1, y: (p.y - minY) * scale + 1)];
  for (var y = 0; y < h; y++) {
    final cy = y + 0.5;
    final xs = <double>[];
    for (var i = 0; i < scaled.length; i++) {
      final a = scaled[i];
      final b = scaled[(i + 1) % scaled.length];
      if ((a.y <= cy && b.y > cy) || (b.y <= cy && a.y > cy)) {
        xs.add(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x));
      }
    }
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      for (var x = xs[k].ceil(); x < xs[k + 1] && x < w; x++) {
        if (x >= 0) labels[y * w + x] = 1;
      }
    }
  }
  final lines = _centrelines(labels, w, h, 1, spur: _workSize * 0.04);
  return [
    for (final line in lines) [for (final p in line) (x: (p.x - 1) / scale + minX, y: (p.y - 1) / scale + minY)],
  ];
}

/// Thins region [id] to a one-pixel skeleton (Zhang–Suen) and turns it into
/// polylines, dropping short side branches.
List<List<Pt>> _centrelines(Int32List labels, int w, int h, int id, {required double spur}) {
  final skeleton = Uint8List(w * h);
  var area = 0, edge = 0;
  for (var i = 0; i < labels.length; i++) {
    skeleton[i] = labels[i] == id ? 1 : 0;
  }
  int at(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : skeleton[y * w + x];
  for (var i = 0; i < skeleton.length; i++) {
    if (skeleton[i] == 0) continue;
    area++;
    final x = i % w, y = i ~/ w;
    if (at(x + 1, y) == 0 || at(x - 1, y) == 0 || at(x, y + 1) == 0 || at(x, y - 1) == 0) edge++;
  }
  // Branches shorter than the corridor is wide are corner stubs left by
  // thinning, not real side corridors.
  final minBranch = math.max(spur, edge == 0 ? 0.0 : 2 * area / edge);
  var changed = true;
  final remove = <int>[];
  while (changed) {
    changed = false;
    for (var pass = 0; pass < 2; pass++) {
      remove.clear();
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (skeleton[y * w + x] == 0) continue;
          final p = [at(x, y - 1), at(x + 1, y - 1), at(x + 1, y), at(x + 1, y + 1), at(x, y + 1), at(x - 1, y + 1), at(x - 1, y), at(x - 1, y - 1)];
          final b = p.fold<int>(0, (s, v) => s + v);
          if (b < 2 || b > 6) continue;
          var a = 0;
          for (var k = 0; k < 8; k++) {
            if (p[k] == 0 && p[(k + 1) % 8] == 1) a++;
          }
          if (a != 1) continue;
          if (pass == 0) {
            if (p[0] * p[2] * p[4] != 0 || p[2] * p[4] * p[6] != 0) continue;
          } else {
            if (p[0] * p[2] * p[6] != 0 || p[0] * p[4] * p[6] != 0) continue;
          }
          remove.add(y * w + x);
        }
      }
      for (final i in remove) {
        skeleton[i] = 0;
      }
      if (remove.isNotEmpty) changed = true;
    }
  }

  List<int> neighbours(int i) {
    final x = i % w, y = i ~/ w;
    return [
      for (final (dx, dy) in _ring)
        if (at(x + dx, y + dy) == 1) (y + dy) * w + (x + dx),
    ];
  }

  final pixels = [for (var i = 0; i < skeleton.length; i++) if (skeleton[i] == 1) i];
  if (pixels.isEmpty) return const [];
  final degree = {for (final i in pixels) i: neighbours(i).length};
  final visited = <(int, int)>{};
  (int, int) key(int a, int b) => a < b ? (a, b) : (b, a);
  final lines = <List<int>>[];

  List<int> walk(int from, int to) {
    final path = [from, to];
    visited.add(key(from, to));
    var prev = from, cur = to;
    while (degree[cur] == 2) {
      final next = neighbours(cur).firstWhere((n) => n != prev, orElse: () => -1);
      if (next < 0 || !visited.add(key(cur, next))) break;
      path.add(next);
      prev = cur;
      cur = next;
    }
    return path;
  }

  for (final i in pixels) {
    if (degree[i] == 2) continue;
    for (final j in neighbours(i)) {
      if (!visited.contains(key(i, j))) lines.add(walk(i, j));
    }
  }
  // A closed loop corridor has no ends or junctions.
  for (final i in pixels) {
    for (final j in neighbours(i)) {
      if (!visited.contains(key(i, j))) lines.add(walk(i, j));
    }
  }

  double length(List<int> line) {
    var total = 0.0;
    for (var k = 0; k + 1 < line.length; k++) {
      final dx = line[k] % w - line[k + 1] % w;
      final dy = line[k] ~/ w - line[k + 1] ~/ w;
      total += math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  final kept = lines.where((line) {
    final deadEnd = degree[line.first] == 1 || degree[line.last] == 1;
    final branch = degree[line.first]! > 2 || degree[line.last]! > 2;
    return !(deadEnd && branch && length(line) < minBranch) && length(line) >= 2;
  }).toList();
  final source = kept.isEmpty ? lines : kept;
  return [
    for (final line in source)
      simplifyStroke([for (final i in line) (x: i % w + 0.5, y: i ~/ w + 0.5)], 1.5),
  ];
}
