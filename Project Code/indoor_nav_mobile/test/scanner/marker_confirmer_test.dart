import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/scanner/marker_confirmer.dart';

void main() {
  late MarkerConfirmer confirmer;

  setUp(() => confirmer = MarkerConfirmer(isKnown: (id) => id >= 1 && id <= 27));

  test('confirms a marker seen in two frames in a row', () {
    expect(confirmer.addFrame(const [DetectedMarker(5, 900)]), isNull);
    expect(confirmer.addFrame(const [DetectedMarker(5, 950)]), 5);
  });

  test('a single-frame misread never confirms', () {
    expect(confirmer.addFrame(const [DetectedMarker(5, 900)]), isNull);
    expect(confirmer.addFrame(const [DetectedMarker(9, 900)]), isNull);
    expect(confirmer.addFrame(const [DetectedMarker(5, 900)]), isNull);
  });

  test('an empty frame breaks the streak', () {
    confirmer.addFrame(const [DetectedMarker(5, 900)]);
    confirmer.addFrame(const []);

    expect(confirmer.addFrame(const [DetectedMarker(5, 900)]), isNull);
  });

  test('picks the closest (largest) known marker when several are visible', () {
    const frame = [DetectedMarker(3, 400), DetectedMarker(12, 2500), DetectedMarker(40, 9000)];

    confirmer.addFrame(frame);

    expect(confirmer.addFrame(frame), 12, reason: 'marker 40 is larger but not on the map');
  });

  test('ignores markers that are not on the map and reports the first one', () {
    const frame = [DetectedMarker(35, 900), DetectedMarker(0, 900)];

    expect(confirmer.addFrame(frame), isNull);
    expect(confirmer.addFrame(frame), isNull);
    expect(confirmer.firstUnknown(frame), 35);
    expect(confirmer.firstUnknown(const [DetectedMarker(4, 10)]), isNull);
  });

  test('reset forgets the current streak', () {
    confirmer.addFrame(const [DetectedMarker(5, 900)]);
    confirmer.reset();

    expect(confirmer.addFrame(const [DetectedMarker(5, 900)]), isNull);
  });

  test('can require more frames', () {
    final strict = MarkerConfirmer(isKnown: (_) => true, requiredFrames: 3);
    const frame = [DetectedMarker(2, 100)];

    expect([strict.addFrame(frame), strict.addFrame(frame), strict.addFrame(frame)], [null, null, 2]);
  });
}
