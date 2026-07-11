import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'preferences.dart';

/// Provider for custom ColorScheme pair generated from preferences seed color.
final customColorSchemeProvider = Provider<(ColorScheme, ColorScheme)>((ref) {
  final prefs = ref.watch(preferencesProvider);
  
  // Default fallback seed color (AtriumTheme violet)
  Color seed = const Color(0xFF6750A4);
  
  if (prefs.customSeedColorHex != null && prefs.customSeedColorHex!.isNotEmpty) {
    try {
      final int? val = int.tryParse(prefs.customSeedColorHex!, radix: 16);
      if (val != null) {
        seed = Color(val | 0xFF000000);
      }
    } catch (_) {}
  }
  
  return (
    ColorScheme.fromSeed(seedColor: seed),
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
  );
});
