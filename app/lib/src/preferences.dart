import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

/// App-wide, non-secret preferences persisted in the settings Hive box.
@immutable
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.biometricEnabled = false,
    this.oledBlackEnabled = true,
  });

  final ThemeMode themeMode;
  final bool biometricEnabled;
  final bool oledBlackEnabled;

  Preferences copyWith({
    ThemeMode? themeMode,
    bool? biometricEnabled,
    bool? oledBlackEnabled,
  }) =>
      Preferences(
        themeMode: themeMode ?? this.themeMode,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        oledBlackEnabled: oledBlackEnabled ?? this.oledBlackEnabled,
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
  static const String _oledBlackKey = 'pref.oledBlackEnabled';

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
      oledBlackEnabled: _box.get(_oledBlackKey) != 'false',
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

  Future<void> setOledBlackEnabled(bool enabled) async {
    await _box.put(_oledBlackKey, '$enabled');
    state = state.copyWith(oledBlackEnabled: enabled);
  }
}
