import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/scanner/frame_utils.dart';

void main() {
  group('copyLumaRows', () {
    test('copies an unpadded frame as-is', () {
      final source = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final destination = Uint8List(6);

      copyLumaRows(source: source, bytesPerRow: 3, destination: destination, width: 3, height: 2);

      expect(destination, [1, 2, 3, 4, 5, 6]);
    });

    test('drops row padding, including a short final row', () {
      // 3x3 frame, 5 bytes per row; the last row has no padding (Android does this).
      final source = Uint8List.fromList([1, 2, 3, 0, 0, 4, 5, 6, 0, 0, 7, 8, 9]);
      final destination = Uint8List(9);

      copyLumaRows(source: source, bytesPerRow: 5, destination: destination, width: 3, height: 3);

      expect(destination, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('rejects a frame that is too short', () {
      expect(
        () => copyLumaRows(source: Uint8List(8), bytesPerRow: 5, destination: Uint8List(9), width: 3, height: 3),
        throwsArgumentError,
      );
    });

    test('rejects a destination that is too small', () {
      expect(
        () => copyLumaRows(source: Uint8List(9), bytesPerRow: 3, destination: Uint8List(8), width: 3, height: 3),
        throwsArgumentError,
      );
    });

    test('rejects impossible geometry', () {
      expect(
        () => copyLumaRows(source: Uint8List(9), bytesPerRow: 2, destination: Uint8List(9), width: 3, height: 3),
        throwsArgumentError,
      );
      expect(
        () => copyLumaRows(source: Uint8List(9), bytesPerRow: 3, destination: Uint8List(9), width: 0, height: 3),
        throwsArgumentError,
      );
    });
  });

  group('polygonArea', () {
    test('computes the area of a square regardless of winding', () {
      const clockwise = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)];

      expect(polygonArea(clockwise), 100);
      expect(polygonArea(clockwise.reversed.toList()), 100);
    });

    test('computes the area of a skewed quad (a marker seen at an angle)', () {
      expect(polygonArea(const [(0.0, 0.0), (4.0, 1.0), (5.0, 5.0), (1.0, 4.0)]), 15);
    });
  });
}
