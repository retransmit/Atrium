import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'preferences.dart';

class SystemColorSchemeState {
  const SystemColorSchemeState(this.light, this.dark);
  final ColorScheme? light;
  final ColorScheme? dark;
}

/// Stores the platform-detected system color schemes.
final systemColorSchemeProvider = StateProvider<SystemColorSchemeState>(
    (ref) => const SystemColorSchemeState(null, null));

DynamicScheme _createDynamicScheme({
  required Color seedColor,
  required Brightness brightness,
  required PaletteStyle style,
}) {
  final Hct sourceColorHct = Hct.fromInt(seedColor.toARGB32());
  final bool isDark = brightness == Brightness.dark;
  const double contrastLevel = 0.0;

  switch (style) {
    case PaletteStyle.content:
      return SchemeContent(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.expressive:
      return SchemeExpressive(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.fidelity:
      return SchemeFidelity(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.fruitSalad:
      return SchemeFruitSalad(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.monochrome:
      return SchemeMonochrome(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.neutral:
      return SchemeNeutral(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.rainbow:
      return SchemeRainbow(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
    case PaletteStyle.tonalSpot:
      return SchemeTonalSpot(
        sourceColorHct: sourceColorHct,
        isDark: isDark,
        contrastLevel: contrastLevel,
      );
  }
}

ColorScheme colorSchemeFromSeedAndStyle(
    Color seedColor, PaletteStyle style, Brightness brightness) {
  final DynamicScheme dynamicScheme = _createDynamicScheme(
    seedColor: seedColor,
    brightness: brightness,
    style: style,
  );

  final isLight = brightness == Brightness.light;
  if (isLight) {
    return ColorScheme(
      brightness: brightness,
      primary: Color(dynamicScheme.primaryPalette.get(40)),
      onPrimary: Color(dynamicScheme.primaryPalette.get(100)),
      primaryContainer: Color(dynamicScheme.primaryPalette.get(90)),
      onPrimaryContainer: Color(dynamicScheme.primaryPalette.get(10)),
      secondary: Color(dynamicScheme.secondaryPalette.get(40)),
      onSecondary: Color(dynamicScheme.secondaryPalette.get(100)),
      secondaryContainer: Color(dynamicScheme.secondaryPalette.get(90)),
      onSecondaryContainer: Color(dynamicScheme.secondaryPalette.get(10)),
      tertiary: Color(dynamicScheme.tertiaryPalette.get(40)),
      onTertiary: Color(dynamicScheme.tertiaryPalette.get(100)),
      tertiaryContainer: Color(dynamicScheme.tertiaryPalette.get(90)),
      onTertiaryContainer: Color(dynamicScheme.tertiaryPalette.get(10)),
      error: Color(dynamicScheme.errorPalette.get(40)),
      onError: Color(dynamicScheme.errorPalette.get(100)),
      errorContainer: Color(dynamicScheme.errorPalette.get(90)),
      onErrorContainer: Color(dynamicScheme.errorPalette.get(10)),
      surface: Color(dynamicScheme.neutralPalette.get(98)),
      onSurface: Color(dynamicScheme.neutralPalette.get(10)),
      surfaceDim: Color(dynamicScheme.neutralPalette.get(87)),
      surfaceBright: Color(dynamicScheme.neutralPalette.get(98)),
      surfaceContainerLowest: Color(dynamicScheme.neutralPalette.get(100)),
      surfaceContainerLow: Color(dynamicScheme.neutralPalette.get(96)),
      surfaceContainer: Color(dynamicScheme.neutralPalette.get(94)),
      surfaceContainerHigh: Color(dynamicScheme.neutralPalette.get(92)),
      surfaceContainerHighest: Color(dynamicScheme.neutralPalette.get(90)),
      onSurfaceVariant: Color(dynamicScheme.neutralVariantPalette.get(30)),
      outline: Color(dynamicScheme.neutralVariantPalette.get(50)),
      outlineVariant: Color(dynamicScheme.neutralVariantPalette.get(80)),
      inverseSurface: Color(dynamicScheme.neutralPalette.get(20)),
      onInverseSurface: Color(dynamicScheme.neutralPalette.get(95)),
      inversePrimary: Color(dynamicScheme.primaryPalette.get(80)),
    );
  } else {
    return ColorScheme(
      brightness: brightness,
      primary: Color(dynamicScheme.primaryPalette.get(80)),
      onPrimary: Color(dynamicScheme.primaryPalette.get(20)),
      primaryContainer: Color(dynamicScheme.primaryPalette.get(30)),
      onPrimaryContainer: Color(dynamicScheme.primaryPalette.get(90)),
      secondary: Color(dynamicScheme.secondaryPalette.get(80)),
      onSecondary: Color(dynamicScheme.secondaryPalette.get(20)),
      secondaryContainer: Color(dynamicScheme.secondaryPalette.get(30)),
      onSecondaryContainer: Color(dynamicScheme.secondaryPalette.get(90)),
      tertiary: Color(dynamicScheme.tertiaryPalette.get(80)),
      onTertiary: Color(dynamicScheme.tertiaryPalette.get(20)),
      tertiaryContainer: Color(dynamicScheme.tertiaryPalette.get(30)),
      onTertiaryContainer: Color(dynamicScheme.tertiaryPalette.get(90)),
      error: Color(dynamicScheme.errorPalette.get(80)),
      onError: Color(dynamicScheme.errorPalette.get(20)),
      errorContainer: Color(dynamicScheme.errorPalette.get(30)),
      onErrorContainer: Color(dynamicScheme.errorPalette.get(90)),
      surface: Color(dynamicScheme.neutralPalette.get(6)),
      onSurface: Color(dynamicScheme.neutralPalette.get(90)),
      surfaceDim: Color(dynamicScheme.neutralPalette.get(6)),
      surfaceBright: Color(dynamicScheme.neutralPalette.get(24)),
      surfaceContainerLowest: Color(dynamicScheme.neutralPalette.get(4)),
      surfaceContainerLow: Color(dynamicScheme.neutralPalette.get(10)),
      surfaceContainer: Color(dynamicScheme.neutralPalette.get(12)),
      surfaceContainerHigh: Color(dynamicScheme.neutralPalette.get(17)),
      surfaceContainerHighest: Color(dynamicScheme.neutralPalette.get(22)),
      onSurfaceVariant: Color(dynamicScheme.neutralVariantPalette.get(80)),
      outline: Color(dynamicScheme.neutralVariantPalette.get(60)),
      outlineVariant: Color(dynamicScheme.neutralVariantPalette.get(30)),
      inverseSurface: Color(dynamicScheme.neutralPalette.get(90)),
      onInverseSurface: Color(dynamicScheme.neutralPalette.get(20)),
      inversePrimary: Color(dynamicScheme.primaryPalette.get(40)),
    );
  }
}

/// Provider for custom ColorScheme pair generated from preferences seed color.
final customColorSchemeProvider = Provider<(ColorScheme, ColorScheme)>((ref) {
  final prefs = ref.watch(preferencesProvider);

  // Default fallback seed color (AtriumTheme violet)
  Color seed = const Color(0xFF6750A4);

  if (prefs.customSeedColorHex != null &&
      prefs.customSeedColorHex!.isNotEmpty) {
    try {
      final int? val = int.tryParse(prefs.customSeedColorHex!, radix: 16);
      if (val != null) {
        seed = Color(val | 0xFF000000);
      }
    } catch (_) {}
  }

  return (
    colorSchemeFromSeedAndStyle(seed, prefs.paletteStyle, Brightness.light),
    colorSchemeFromSeedAndStyle(seed, prefs.paletteStyle, Brightness.dark),
  );
});
