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
  static const String appName = 'Indoor Nav';

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
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.secondary,
    onSecondary: p.onSecondary,
    surface: p.background,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final appBarBackground = light ? p.primary : const Color(0xFF1A1A1A);
  final appBarForeground = light ? p.onPrimary : p.primary;
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: appBarForeground),
    ),
    cardTheme: CardThemeData(elevation: 0, shape: rounded, color: p.card, margin: EdgeInsets.zero),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: light ? p.secondary : p.primary,
      foregroundColor: light ? p.onSecondary : p.onPrimary,
      shape: rounded,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: rounded,
        backgroundColor: light ? p.secondary : p.primary,
        foregroundColor: light ? p.onSecondary : p.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: rounded,
        foregroundColor: light ? p.secondary : p.primary,
        side: BorderSide(color: (light ? p.secondary : p.primary).withValues(alpha: 0.6)),
      ),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [MapColors.of(p)],
  );
}
