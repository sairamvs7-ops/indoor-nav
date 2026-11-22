import 'package:flutter/material.dart';

/// One mode's brand colours. Everything else in the theme is derived from
/// these, so rebranding means changing the two palettes below.
@immutable
class BrandPalette {
  const BrandPalette({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.card,
    required this.route,
    required this.routeCasing,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color background;

  /// Cards and sheets, a step lighter (or darker) than [background].
  final Color card;

  /// The route line on blueprints, which are always light paper.
  final Color route;
  final Color routeCasing;
}

abstract final class Brand {
  static const String appName = 'Via';

  /// Light mode: olive, deep green, soft sand.
  static const light = BrandPalette(
    primary: Color(0xFF586B45),
    onPrimary: Colors.white,
    secondary: Color(0xFF005A32),
    onSecondary: Colors.white,
    background: Color(0xFFE5D9C2),
    card: Color(0xFFF4EDDF),
    route: Color(0xFF005A32),
    routeCasing: Colors.white,
  );

  /// Dark mode: charcoal, lime, mint.
  static const dark = BrandPalette(
    primary: Color(0xFF89E900),
    onPrimary: Color(0xFF111111),
    secondary: Color(0xFFC7E9C0),
    onSecondary: Color(0xFF111111),
    background: Color(0xFF222222),
    card: Color(0xFF2E2E2E),
    route: Color(0xFF89E900),
    routeCasing: Color(0xFF222222),
  );

  static BrandPalette of(Brightness brightness) => brightness == Brightness.light ? light : dark;
}

/// Colours for drawing on floor plans, derived from the brand.
@immutable
class MapColors extends ThemeExtension<MapColors> {
  const MapColors({
    required this.route,
    required this.routeCasing,
    required this.current,
    required this.destination,
    required this.connector,
    required this.place,
    required this.path,
    required this.suggestion,
    required this.selected,
  });

  factory MapColors.of(BrandPalette p) => MapColors(
    route: p.route,
    routeCasing: p.routeCasing,
    // Blueprints are light paper in both modes, so map pins use the darker
    // greens for contrast.
    current: const Color(0xFF1D4ED8),
    destination: const Color(0xFFDC2626),
    connector: const Color(0xFFF59E0B),
    place: Brand.light.primary,
    path: Brand.light.secondary.withValues(alpha: 0.8),
    suggestion: const Color(0xFFF59E0B),
    selected: const Color(0xFFF59E0B),
  );

  final Color route;
  final Color routeCasing;
  final Color current;
  final Color destination;
  final Color connector;
  final Color place;
  final Color path;
  final Color suggestion;
  final Color selected;

  static MapColors resolve(BuildContext context) =>
      Theme.of(context).extension<MapColors>() ?? MapColors.of(Brand.of(Theme.of(context).brightness));

  @override
  MapColors copyWith({Color? route, Color? current, Color? destination}) => MapColors(
    route: route ?? this.route,
    routeCasing: routeCasing,
    current: current ?? this.current,
    destination: destination ?? this.destination,
    connector: connector,
    place: place,
    path: path,
    suggestion: suggestion,
    selected: selected,
  );

  @override
  MapColors lerp(MapColors? other, double t) => t < 0.5 || other == null ? this : other;
}

ThemeData buildTheme(Brightness brightness) {
  final p = Brand.of(brightness);
  final light = brightness == Brightness.light;
  // Light mode is earthy paper, not a green header: sand everywhere, olive
  // and deep green only as accents, cream cards with a fine olive outline.
  const cream = Color(0xFFFBF6EC);
  const sage = Color(0xFFD9E0C8); // light olive tint for selections
  const ink = Color(0xFF2B3320); // dark olive for text on sand
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: brightness,
    primary: p.primary,
    onPrimary: light ? cream : p.onPrimary,
    secondary: p.secondary,
    onSecondary: light ? cream : p.onSecondary,
    primaryContainer: light ? sage : null,
    onPrimaryContainer: light ? ink : null,
    secondaryContainer: light ? const Color(0xFFCFE3D3) : null,
    onSecondaryContainer: light ? const Color(0xFF00321C) : null,
    surface: p.background,
    onSurface: light ? ink : null,
    surfaceContainerLowest: light ? cream : p.card,
    surfaceContainerLow: light ? cream : p.card,
    surfaceContainer: p.card,
    outline: light ? p.primary.withValues(alpha: 0.35) : null,
    outlineVariant: light ? p.primary.withValues(alpha: 0.18) : null,
  );
  final radius = BorderRadius.circular(light ? 20 : 16);
  final rounded = RoundedRectangleBorder(borderRadius: radius);
  final cardShape = light
      ? RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.primary.withValues(alpha: 0.18)))
      : rounded;
  final appBarBackground = light ? p.background : const Color(0xFF1A1A1A);
  final appBarForeground = light ? p.secondary : p.primary;
  final buttonBackground = p.primary;
  final buttonForeground = light ? cream : p.onPrimary;
  final base = ThemeData(brightness: brightness, colorScheme: scheme);
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      surfaceTintColor: Colors.transparent,
      // A sand bar that only shades slightly once content scrolls under it.
      scrolledUnderElevation: light ? 1 : 0,
      shadowColor: light ? p.primary.withValues(alpha: 0.25) : null,
      centerTitle: false,
      iconTheme: IconThemeData(color: appBarForeground),
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: light ? p.primary : appBarForeground,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: cardShape,
      color: light ? cream : p.card,
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: light ? cream : p.card,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(backgroundColor: light ? cream : p.card, surfaceTintColor: Colors.transparent),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: buttonBackground,
      foregroundColor: buttonForeground,
      shape: rounded,
      elevation: light ? 2 : 6,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: rounded,
        backgroundColor: buttonBackground,
        foregroundColor: buttonForeground,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: rounded,
        foregroundColor: light ? p.secondary : p.primary,
        side: BorderSide(color: (light ? p.secondary : p.primary).withValues(alpha: 0.5), width: 1.4),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: light ? cream : null,
      selectedColor: light ? p.primary : null,
      secondarySelectedColor: light ? p.primary : null,
      labelStyle: TextStyle(color: light ? ink : null, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: light ? cream : null, fontWeight: FontWeight.w600),
      side: light ? BorderSide(color: p.primary.withValues(alpha: 0.3)) : null,
    ),
    segmentedButtonTheme: light
        ? SegmentedButtonThemeData(
            style: SegmentedButton.styleFrom(
              backgroundColor: cream,
              foregroundColor: ink,
              selectedBackgroundColor: p.primary,
              selectedForegroundColor: cream,
              side: BorderSide(color: p.primary.withValues(alpha: 0.35)),
            ),
          )
        : null,
    inputDecorationTheme: InputDecorationTheme(
      filled: light,
      fillColor: light ? cream : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: light ? p.secondary : p.primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? ink : null,
      contentTextStyle: light ? const TextStyle(color: cream) : null,
    ),
    extensions: [MapColors.of(p)],
  );
}
