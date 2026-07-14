import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

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

  static ThemeData light(ColorScheme? dynamicScheme, {String? fontFamily}) =>
      _build(
        dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed),
        fontFamily,
      );

  static ThemeData dark(ColorScheme? dynamicScheme, {String? fontFamily}) =>
      _build(
        dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
        fontFamily,
      );

  static ThemeData _build(ColorScheme scheme, String? fontFamily) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
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
    return _AtriumDynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
          builder(lightDynamic?.harmonized(), darkDynamic?.harmonized()),
    );
  }
}

/// A custom dynamic color builder that intentionally bypasses `getColorSchemes()`
/// provided by `dynamic_system_colors` because it queries theme attributes using
/// the Application context on Android 14+, causing Material You colors to fall back
/// to non-dynamic system defaults. Instead, it relies directly on `getCorePalette()`,
/// which uses global resources and works correctly.
class _AtriumDynamicColorBuilder extends StatefulWidget {
  const _AtriumDynamicColorBuilder({required this.builder});

  final Widget Function(ColorScheme? light, ColorScheme? dark) builder;

  @override
  State<_AtriumDynamicColorBuilder> createState() =>
      _AtriumDynamicColorBuilderState();
}

class _AtriumDynamicColorBuilderState
    extends State<_AtriumDynamicColorBuilder> {
  ColorScheme? _light;
  ColorScheme? _dark;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    try {
      // ignore: deprecated_member_use
      final CorePalette? corePalette =
          await DynamicColorPlugin.getCorePalette();
      if (!mounted) return;

      if (corePalette != null) {
        if (kDebugMode) {
          debugPrint(
              'dynamic_color: Core palette detected (bypassed schemes).',);
        }
        setState(() {
          _light = corePalette.toColorScheme();
          _dark = corePalette.toColorScheme(brightness: Brightness.dark);
        });
        return;
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain core palette. $e');
      }
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Core palette channel unavailable. $e');
      }
    }

    try {
      final Color? accentColor = await DynamicColorPlugin.getAccentColor();
      if (!mounted) return;

      if (accentColor != null) {
        if (kDebugMode) {
          debugPrint('dynamic_color: Accent color detected.');
        }
        setState(() {
          _light = ColorScheme.fromSeed(
            seedColor: accentColor,
          );
          _dark = ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          );
        });
        return;
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain accent color. $e');
      }
    } on MissingPluginException catch (e) {
      // Android without desktop accent support reports notImplemented, which
      // surfaces here rather than as a PlatformException. Keep the seed theme.
      if (kDebugMode) {
        debugPrint('dynamic_color: Accent color channel unavailable. $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_light, _dark);
  }
}
