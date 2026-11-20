import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/setup/blueprint_picker.dart';
import 'package:indoor_nav_mobile/setup/dxf_import.dart';

/// Builds a DXF text from (group code, value) pairs.
String dxf(List<(int, Object)> pairs) => [for (final (c, v) in pairs) '$c\n$v'].join('\n');

/// A 20 m x 10 m room in millimetres: walls on layer WALLS, a door block on
/// DOORS inserted twice (once rotated), and a text label that must be skipped.
String roomDxf({bool withUnits = true}) => dxf([
  (0, 'SECTION'),
  (2, 'HEADER'),
  if (withUnits) ...[(9, r'$INSUNITS'), (70, 4)],
  (0, 'ENDSEC'),
  (0, 'SECTION'),
  (2, 'BLOCKS'),
  (0, 'BLOCK'),
  (8, '0'),
  (2, 'DOOR'),
  (10, 0),
  (20, 0),
  (0, 'LINE'),
  (8, '0'),
  (10, 0),
  (20, 0),
  (11, 900),
  (21, 0),
  (0, 'ENDBLK'),
  (0, 'ENDSEC'),
  (0, 'SECTION'),
  (2, 'ENTITIES'),
  (0, 'LWPOLYLINE'),
  (8, 'WALLS'),
  (90, 4),
  (70, 1),
  (10, 0),
  (20, 0),
  (10, 20000),
  (20, 0),
  (10, 20000),
  (20, 10000),
  (10, 0),
  (20, 10000),
  (0, 'INSERT'),
  (8, 'DOORS'),
  (2, 'DOOR'),
  (10, 1000),
  (20, 0),
  (0, 'INSERT'),
  (8, 'DOORS'),
  (2, 'DOOR'),
  (10, 20000),
  (20, 5000),
  (50, 90),
  (0, 'TEXT'),
  (8, 'TEXT'),
  (10, 5000),
  (20, 5000),
  (1, 'Office'),
  (0, 'ARC'),
  (8, 'WALLS'),
  (10, 10000),
  (20, 10000),
  (40, 1000),
  (50, 180),
  (51, 0),
  (0, 'ENDSEC'),
  (0, 'EOF'),
]);

void main() {
  test('reads walls, expands blocks and skips text', () {
    final drawing = parseDxf(roomDxf());

    expect(drawing.metresPerUnit, 0.001);
    expect(drawing.unitsGuessed, isFalse);
    expect(drawing.layers, {'WALLS': 2, 'DOORS': 2});

    final walls = drawing.shapes.firstWhere((s) => s.layer == 'WALLS');
    expect(walls.points, hasLength(5)); // closed: back to the start
    expect(walls.points.last, walls.points.first);

    final doors = drawing.shapes.where((s) => s.layer == 'DOORS').toList();
    expect(doors[0].points, [(x: 1000.0, y: 0.0), (x: 1900.0, y: 0.0)]);
    // Rotated 90 degrees: the door now runs up the right-hand wall.
    expect(doors[1].points.last.x, closeTo(20000, 1e-6));
    expect(doors[1].points.last.y, closeTo(5900, 1e-6));
  });

  test('guesses millimetres when a large drawing has no units', () {
    final drawing = parseDxf(roomDxf(withUnits: false));

    expect(drawing.unitsGuessed, isTrue);
    expect(drawing.metresPerUnit, 0.001);
  });

  test('explains files it cannot read', () {
    expect(() => parseDxf('hello'), throwsA(isA<DxfFormatException>()));
    expect(
      () => parseDxf('AutoCAD Binary DXF\r\n'),
      throwsA(isA<DxfFormatException>().having((e) => e.message, 'message', contains('ASCII'))),
    );
    expect(
      () => parseDxf(dxf([(0, 'SECTION'), (2, 'ENTITIES'), (0, 'ENDSEC'), (0, 'EOF')])),
      throwsA(isA<DxfFormatException>().having((e) => e.message, 'message', contains('No lines'))),
    );
  });

  test('clutter layers are recognised', () {
    expect(clutterLayer.hasMatch('A-ANNO-TEXT'), isTrue);
    expect(clutterLayer.hasMatch('Furniture'), isTrue);
    expect(clutterLayer.hasMatch('A-WALL'), isFalse);
  });

  testWidgets('renders the chosen layers to a scaled PNG', (tester) async {
    final drawing = parseDxf(roomDxf());

    final image = (await tester.runAsync(() => renderDxf(drawing, layers: {'WALLS'}, maxPixels: 1200)))!;

    expect(image.width, 1200);
    expect(image.height, greaterThan(500));
    expect(image.height, lessThan(800));
    // 20 m plus 3% margin each side across 1200 px.
    expect(image.metresPerPixel, closeTo(21.2 / 1200, 1e-3));
    final size = (await tester.runAsync(() => imageSize(image.png)))!;
    expect(size, (image.width, image.height));
    await expectLater(renderDxf(drawing, layers: {'NOPE'}), throwsA(isA<DxfFormatException>()));
  });
}
