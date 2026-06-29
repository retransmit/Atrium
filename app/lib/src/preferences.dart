import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

/// App-wide, non-secret preferences persisted in the settings Hive box.
@immutable
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.biometricEnabled = false,
    this.fontFamily,
  });

  final ThemeMode themeMode;
  final bool biometricEnabled;
  final String? fontFamily;

  Preferences copyWith({
    ThemeMode? themeMode,
    bool? biometricEnabled,
    String? fontFamily,
  }) =>
      Preferences(
        themeMode: themeMode ?? this.themeMode,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        fontFamily: fontFamily ?? this.fontFamily,
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
    // We explicitly allow passing null to copyWith to clear the font, but our
    // copyWith above doesn't support clearing if it falls back to this.fontFamily.
    // Let's replace the whole state directly.
    state = Preferences(
      themeMode: state.themeMode,
      biometricEnabled: state.biometricEnabled,
      fontFamily: fontFamily,
    );
  }
}
