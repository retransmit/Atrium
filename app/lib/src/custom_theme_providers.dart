import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'preferences.dart';

class SystemColorSchemeState {
  const SystemColorSchemeState(this.light, this.dark);
  final ColorScheme? light;
  final ColorScheme? dark;
}

/// Stores the platform-detected system color schemes.
final systemColorSchemeProvider = StateProvider<SystemColorSchemeState>(
    (ref) => const SystemColorSchemeState(null, null));

FlexTones _mapPaletteStyleToFlexTones(
    PaletteStyle style, Brightness brightness) {
  return switch (style) {
    PaletteStyle.material => FlexTones.material(brightness),
    PaletteStyle.vivid => FlexTones.vivid(brightness),
    PaletteStyle.highContrast => FlexTones.highContrast(brightness),
    PaletteStyle.candyPop => FlexTones.candyPop(brightness),
    PaletteStyle.jolly => FlexTones.jolly(brightness),
    PaletteStyle.oneHue => FlexTones.oneHue(brightness),
    PaletteStyle.chroma => FlexTones.chroma(brightness),
    PaletteStyle.ultraContrast => FlexTones.ultraContrast(brightness),
  };
}

ColorScheme colorSchemeFromSeedAndStyle(
    Color seedColor, PaletteStyle style, Brightness brightness) {
  return SeedColorScheme.fromSeeds(
    brightness: brightness,
    primaryKey: seedColor,
    tones: _mapPaletteStyleToFlexTones(style, brightness),
  );
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
