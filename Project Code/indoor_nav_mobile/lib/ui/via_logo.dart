import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The Via logo ("Route"), drawn from the same outlines as the brand masters
/// in `Logo/Final_v2`, so it stays sharp at any size and follows the theme.
///
/// The symbol is a walked route: a ring where you scan the marker, one turn,
/// and a large dot where you arrive. With [wordmark] it is the horizontal
/// logo: the symbol and the custom "via" letters on one baseline.
class ViaLogo extends StatelessWidget {
  const ViaLogo({super.key, this.height = 28, this.wordmark = true});

  /// Height of the whole logo in logical pixels.
  final double height;

  /// Whether to draw the "via" wordmark next to the symbol.
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final colors = _LogoColors.of(Theme.of(context).brightness);
    final box = wordmark ? _lockupBox : _symbolBox;
    final width = height * box.width / box.height;
    return Semantics(
      label: Brand.appName,
      image: true,
      child: CustomPaint(
        size: Size(width, height),
        painter: _ViaLogoPainter(colors, wordmark: wordmark),
      ),
    );
  }
}

class _LogoColors {
  const _LogoColors(this.route, this.dot, this.text, this.iDot);

  final Color route, dot, text, iDot;

  static const light = _LogoColors(Color(0xFF005A32), Color(0xFF586B45), Color(0xFF222222), Color(0xFF005A32));
  static const dark = _LogoColors(Color(0xFF89E900), Color(0xFFC7E9C0), Color(0xFFC7E9C0), Color(0xFF89E900));

  static _LogoColors of(Brightness b) => b == Brightness.light ? light : dark;
}

// Outlines in the master units (symbol box 100, wordmark x-height 500).
const _routeBody =
    'M16.091 34.147L41.461 86.165A9.500 9.500 0 0 0 58.539 86.165L81.967 38.129A14.600 14.600 0 1 0 64.890 29.800'
    'L50.000 60.329L33.168 25.818A11.600 11.600 0 1 0 16.091 34.147Z'
    'M16.112 24.000A5.600 5.600 0 1 0 27.312 24.000A5.600 5.600 0 1 0 16.112 24.000Z';
const _routeDot = 'M63.688 24.000A14.600 14.600 0 1 1 92.888 24.000A14.600 14.600 0 1 1 63.688 24.000Z';
const _wmStrokes =
    'M4.872 73.976L189.530 469.976A52.000 52.000 0 0 0 283.786 469.976L468.444 73.976A52.000 52.000 0 1 0 374.188 30.024'
    'L236.658 324.958L99.128 30.024A52.000 52.000 0 1 0 4.872 73.976Z'
    'M513.316 52.000A52.000 52.000 0 0 1 617.316 52.000V448.000A52.000 52.000 0 0 1 513.316 448.000Z'
    'M1047.316 52.000A52.000 52.000 0 0 1 1151.316 52.000V448.000A52.000 52.000 0 0 1 1047.316 448.000Z';
const _wmBowl =
    'M679.316 264.000A236.000 236.000 0 1 1 1151.316 264.000A236.000 236.000 0 1 1 679.316 264.000Z'
    'M783.316 264.000A132.000 132.000 0 1 0 1047.316 264.000A132.000 132.000 0 1 0 783.316 264.000Z';
const _wmIDot = 'M492.516 -112.800A72.800 72.800 0 1 1 638.116 -112.800A72.800 72.800 0 1 1 492.516 -112.800Z';

// Wordmark placement in the horizontal logo (symbol units), matching the masters.
const _wmX = 119.77, _wmY = 35.5, _wmScale = 0.112;
const _symbolBox = Rect.fromLTRB(10.11, 9.4, 92.89, 91.5);
const _lockupBox = Rect.fromLTRB(10.11, 9.4, _wmX + 1151.32 * _wmScale, 91.5);

class _ViaLogoPainter extends CustomPainter {
  _ViaLogoPainter(this.colors, {required this.wordmark});

  final _LogoColors colors;
  final bool wordmark;

  static final _body = parseSvgPath(_routeBody)..fillType = PathFillType.evenOdd;
  static final _dot = parseSvgPath(_routeDot);
  static final _strokes = parseSvgPath(_wmStrokes);
  static final _bowl = parseSvgPath(_wmBowl)..fillType = PathFillType.evenOdd;
  static final _iDot = parseSvgPath(_wmIDot);

  @override
  void paint(Canvas canvas, Size size) {
    final box = wordmark ? _lockupBox : _symbolBox;
    final s = size.height / box.height;
    canvas
      ..save()
      ..scale(s)
      ..translate(-box.left, -box.top);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawPath(_body, paint..color = colors.route);
    canvas.drawPath(_dot, paint..color = colors.dot);
    if (wordmark) {
      canvas
        ..save()
        ..translate(_wmX, _wmY)
        ..scale(_wmScale);
      canvas.drawPath(_strokes, paint..color = colors.text);
      canvas.drawPath(_bowl, paint..color = colors.text);
      canvas.drawPath(_iDot, paint..color = colors.iDot);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ViaLogoPainter old) => old.colors != colors || old.wordmark != wordmark;
}

/// Parses the absolute SVG path commands used by the logo masters
/// (M, L, H, V, A, Z) into a [Path].
@visibleForTesting
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[MLHVAZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[MLHVAZ]$').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        x = next();
        y = next();
        path.moveTo(x, y);
        cmd = 'L'; // extra coordinate pairs after M are line-tos
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'A':
        final rx = next(), ry = next();
        next(); // x-axis rotation (always 0 here)
        final large = next() != 0, sweep = next() != 0;
        x = next();
        y = next();
        path.arcToPoint(Offset(x, y), radius: Radius.elliptical(rx, ry), largeArc: large, clockwise: sweep);
      case 'Z':
        path.close();
    }
  }
  return path;
}
