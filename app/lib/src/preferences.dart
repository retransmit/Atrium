import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

enum ThemeSource {
  system,
  preset,
  customImage,
}

enum PaletteProfile {
  vibrant,
  lightVibrant,
  darkVibrant,
  muted,
  lightMuted,
  darkMuted,
  dominant,
}

enum PaletteStyle {
  tonalSpot,
  content,
  expressive,
  fidelity,
  fruitSalad,
  monochrome,
  neutral,
  rainbow,
}

/// App-wide, non-secret preferences persisted in the settings Hive box.
@immutable
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.biometricEnabled = false,
    this.fontFamily,
    this.themeSource = ThemeSource.system,
    this.paletteProfile = PaletteProfile.vibrant,
    this.paletteStyle = PaletteStyle.tonalSpot,
    this.customSeedColorHex,
    this.customImagePath,
    this.customImageColorsCsv,
  });

  final ThemeMode themeMode;
  final bool biometricEnabled;
  final String? fontFamily;
  final ThemeSource themeSource;
  final PaletteProfile paletteProfile;
  final PaletteStyle paletteStyle;
  final String? customSeedColorHex;
  final String? customImagePath;
  final String? customImageColorsCsv;

  Preferences copyWith({
    ThemeMode? themeMode,
    bool? biometricEnabled,
    String? Function()? fontFamily,
    ThemeSource? themeSource,
    PaletteProfile? paletteProfile,
    PaletteStyle? paletteStyle,
    String? Function()? customSeedColorHex,
    String? Function()? customImagePath,
    String? Function()? customImageColorsCsv,
  }) =>
      Preferences(
        themeMode: themeMode ?? this.themeMode,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        fontFamily: fontFamily != null ? fontFamily() : this.fontFamily,
        themeSource: themeSource ?? this.themeSource,
        paletteProfile: paletteProfile ?? this.paletteProfile,
        paletteStyle: paletteStyle ?? this.paletteStyle,
        customSeedColorHex: customSeedColorHex != null ? customSeedColorHex() : this.customSeedColorHex,
        customImagePath: customImagePath != null ? customImagePath() : this.customImagePath,
        customImageColorsCsv: customImageColorsCsv != null ? customImageColorsCsv() : this.customImageColorsCsv,
      );
}

/// The settings [Box]. Overridden in `main()` once Hive is open.
final Provider<Box<String>> settingsBoxProvider = Provider<Box<String>>((
  Ref ref,
) {
  throw UnimplementedError('settingsBoxProvider must be overridden in main()');
});

final NotifierProvider<PreferencesController, Preferences> preferencesProvider =
    NotifierProvider<PreferencesController, Preferences>(
  PreferencesController.new,
);

class PreferencesController extends Notifier<Preferences> {
  static const String _themeKey = 'pref.themeMode';
  static const String _biometricKey = 'pref.biometricEnabled';
  static const String _fontFamilyKey = 'pref.fontFamily';
  static const String _themeSourceKey = 'pref.themeSource';
  static const String _paletteProfileKey = 'pref.paletteProfile';
  static const String _customSeedColorHexKey = 'pref.customSeedColorHex';
  static const String _customImagePathKey = 'pref.customImagePath';
  static const String _customImageColorsCsvKey = 'pref.customImageColorsCsv';
  static const String _paletteStyleKey = 'pref.paletteStyle';

  Box<String> get _box => ref.read(settingsBoxProvider);

  @override
  Preferences build() {
    return Preferences(
      themeMode: switch (_box.get(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      biometricEnabled: _box.get(_biometricKey) == 'true',
      fontFamily: _box.get(_fontFamilyKey),
      themeSource: switch (_box.get(_themeSourceKey)) {
        'preset' => ThemeSource.preset,
        'customImage' => ThemeSource.customImage,
        _ => ThemeSource.system,
      },
      paletteProfile: switch (_box.get(_paletteProfileKey)) {
        'lightVibrant' => PaletteProfile.lightVibrant,
        'darkVibrant' => PaletteProfile.darkVibrant,
        'muted' => PaletteProfile.muted,
        'lightMuted' => PaletteProfile.lightMuted,
        'darkMuted' => PaletteProfile.darkMuted,
        'dominant' => PaletteProfile.dominant,
        _ => PaletteProfile.vibrant,
      },
      paletteStyle: switch (_box.get(_paletteStyleKey)) {
        'content' => PaletteStyle.content,
        'expressive' => PaletteStyle.expressive,
        'fidelity' => PaletteStyle.fidelity,
        'fruitSalad' => PaletteStyle.fruitSalad,
        'monochrome' => PaletteStyle.monochrome,
        'neutral' => PaletteStyle.neutral,
        'rainbow' => PaletteStyle.rainbow,
        _ => PaletteStyle.tonalSpot,
      },
      customSeedColorHex: _box.get(_customSeedColorHexKey),
      customImagePath: _box.get(_customImagePathKey),
      customImageColorsCsv: _box.get(_customImageColorsCsvKey),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_themeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _box.put(_biometricKey, '$enabled');
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setFontFamily(String? fontFamily) async {
    if (fontFamily == null) {
      await _box.delete(_fontFamilyKey);
    } else {
      await _box.put(_fontFamilyKey, fontFamily);
    }
    state = state.copyWith(fontFamily: () => fontFamily);
  }

  Future<void> setThemeSource(ThemeSource source) async {
    await _box.put(_themeSourceKey, source.name);
    state = state.copyWith(themeSource: source);
  }

  Future<void> setPaletteProfile(PaletteProfile profile) async {
    await _box.put(_paletteProfileKey, profile.name);
    state = state.copyWith(paletteProfile: profile);
  }

  Future<void> setPaletteStyle(PaletteStyle style) async {
    await _box.put(_paletteStyleKey, style.name);
    state = state.copyWith(paletteStyle: style);
  }

  Future<void> setCustomSeedColorHex(String? hex) async {
    if (hex == null) {
      await _box.delete(_customSeedColorHexKey);
    } else {
      await _box.put(_customSeedColorHexKey, hex);
    }
    state = state.copyWith(customSeedColorHex: () => hex);
  }

  Future<void> setCustomImagePath(String? path) async {
    if (path == null) {
      await _box.delete(_customImagePathKey);
    } else {
      await _box.put(_customImagePathKey, path);
    }
    state = state.copyWith(customImagePath: () => path);
  }

  Future<void> setCustomImageColorsCsv(String? csv) async {
    if (csv == null) {
      await _box.delete(_customImageColorsCsvKey);
    } else {
      await _box.put(_customImageColorsCsvKey, csv);
    }
    state = state.copyWith(customImageColorsCsv: () => csv);
  }
}
