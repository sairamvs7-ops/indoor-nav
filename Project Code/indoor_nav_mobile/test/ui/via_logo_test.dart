import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/ui/app_theme.dart';
import 'package:indoor_nav_mobile/ui/via_logo.dart';

void main() {
  test('the parsed symbol has a true hole in the start ring and an open V', () {
    // Route symbol body from Logo/Final_v2 (even-odd: the start ring's hole is a second contour).
    final body = parseSvgPath(
      'M16.091 34.147L41.461 86.165A9.500 9.500 0 0 0 58.539 86.165L81.967 38.129A14.600 14.600 0 1 0 64.890 29.800'
      'L50.000 60.329L33.168 25.818A11.600 11.600 0 1 0 16.091 34.147Z'
      'M16.112 24.000A5.600 5.600 0 1 0 27.312 24.000A5.600 5.600 0 1 0 16.112 24.000Z',
    )..fillType = PathFillType.evenOdd;
    expect(body.contains(const Offset(21.71, 24)), isFalse, reason: 'centre of the start ring is a hole');
    expect(body.contains(const Offset(21.71, 15)), isTrue, reason: 'the ring itself is filled');
    expect(body.contains(const Offset(78.29, 24)), isTrue, reason: 'the destination disc is filled');
    expect(body.contains(const Offset(50, 86)), isTrue, reason: 'the turn at the bottom is filled');
    expect(body.contains(const Offset(50, 40)), isFalse, reason: 'the inside of the V is open');
    expect(body.contains(const Offset(5, 50)), isFalse);
  });

  testWidgets('the logo keeps its proportions and is announced as Via', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: ViaLogo(height: 40))));
    final size = tester.getSize(find.byType(CustomPaint).last);
    expect(size.height, 40);
    expect(size.width / size.height, closeTo((248.72 - 10.11) / (91.5 - 9.4), 0.01));
    expect(find.bySemanticsLabel(Brand.appName), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: Center(child: ViaLogo(height: 40, wordmark: false))));
    final mark = tester.getSize(find.byType(CustomPaint).last);
    expect(mark.width / mark.height, closeTo((92.89 - 10.11) / (91.5 - 9.4), 0.01));
  });
}
