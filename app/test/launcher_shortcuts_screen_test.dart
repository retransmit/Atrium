import 'package:atrium/src/launcher_shortcuts/launcher_shortcuts.dart';
import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/screens/launcher_shortcuts_screen.dart';
import 'package:atrium/src/screens/settings_screen.dart';
import 'package:atrium/src/update_check/update_check_state.dart';
import 'package:atrium/src/update_check/update_checker.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Instance _i(String id) => Instance(
      id: id,
      name: 'Service $id',
      kind: ServiceKind.sonarr,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

final Profile _profile = Profile(
  id: 'p1',
  name: 'Home',
  instances: <Instance>[for (final String id in <String>['a', 'b', 'c', 'd', 'e']) _i(id)],
);

/// Keeps the choice in memory instead of the settings box.
class _MemoryChoice extends LauncherShortcutChoiceController {
  _MemoryChoice(super.profileId);

  @override
  List<String>? build() => null;

  @override
  Future<void> setChosen(List<String> ids) async {
    state = List<String>.unmodifiable(ids);
  }
}

class _FakePreferencesController extends PreferencesController {
  @override
  Preferences build() => const Preferences();
}

class _IdleUpdateChecker extends UpdateChecker {
  @override
  UpdateCheckState build() => const UpdateCheckState();
  @override
  Future<void> check() async {}
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        activeProfileProvider.overrideWithValue(_profile),
        launcherShortcutChoiceProvider('p1')
            .overrideWith(() => _MemoryChoice('p1')),
        preferencesProvider.overrideWith(_FakePreferencesController.new),
        updateCheckProvider.overrideWith(_IdleUpdateChecker.new),
      ],
      child: MaterialApp(theme: AtriumTheme.light(null), home: home),
    ),
  );
  await tester.pump();
}

CheckboxListTile _row(WidgetTester tester, String id) => tester.widget(
      find.ancestor(
        of: find.text('Service $id'),
        matching: find.byType(CheckboxListTile),
      ),
    );

List<String>? _stored(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(LauncherShortcutsScreen)),
    ).read(launcherShortcutChoiceProvider('p1'));

void main() {
  testWidgets('ticks the first four by default', (WidgetTester tester) async {
    await _pump(tester, const LauncherShortcutsScreen());

    expect(find.text("Long-press Atrium's icon to open these. Up to four."),
        findsOneWidget);
    for (final String id in <String>['a', 'b', 'c', 'd']) {
      expect(_row(tester, id).value, isTrue, reason: id);
    }
    expect(_row(tester, 'e').value, isFalse);
    expect(_row(tester, 'e').onChanged, isNull);
  });

  testWidgets('unticking frees a slot', (WidgetTester tester) async {
    await _pump(tester, const LauncherShortcutsScreen());

    await tester.tap(find.text('Service b'));
    await tester.pump();

    expect(_stored(tester), <String>['a', 'c', 'd']);
    expect(_row(tester, 'b').value, isFalse);
    expect(_row(tester, 'e').onChanged, isNotNull);
  });

  testWidgets('ticking stores the choice', (WidgetTester tester) async {
    await _pump(tester, const LauncherShortcutsScreen());

    await tester.tap(find.text('Service b'));
    await tester.pump();
    await tester.tap(find.text('Service e'));
    await tester.pump();

    expect(_stored(tester), <String>['a', 'c', 'd', 'e']);
    expect(_row(tester, 'b').onChanged, isNull);
  });

  testWidgets('settings opens the screen', (WidgetTester tester) async {
    await _pump(tester, const SettingsScreen());

    final Finder tile = find.text('Launcher shortcuts');
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text("Services shown when you long-press Atrium's icon."),
        findsOneWidget);
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LauncherShortcutsScreen), findsOneWidget);
  });
}
