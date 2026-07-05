import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Atrium's Material 3 theme.
///
/// On Android 12+ the user's wallpaper-derived palette is used when
/// available (via `dynamic_system_colors`); otherwise we fall back to a violet seed
/// that nods to the "atrium" calm-architectural feel. Both light and dark
/// are derived from the same seed so they stay in sync.
abstract final class AtriumTheme {
  /// Fallback seed when dynamic color is unavailable.
  static const Color seed = Color(0xFF6750A4);

  static ThemeData light(ColorScheme? dynamicScheme) =>
      _build(dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark(ColorScheme? dynamicScheme) => _build(
        dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
      );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Insets.lg),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Wraps [builder] with the platform dynamic-color palettes when present.
  /// Use at the app root so both themes get the harmonized schemes.
  static Widget withDynamicColor({
    required Widget Function(ColorScheme? light, ColorScheme? dark) builder,
  }) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
          builder(lightDynamic, darkDynamic),
    );
  }
}
