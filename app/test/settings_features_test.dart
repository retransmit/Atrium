import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/screens/custom_headers_screen.dart';
import 'package:atrium/src/screens/settings_screen.dart';
import 'package:atrium/src/screens/wake_on_lan_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic render tests for the Settings network features
/// (Wake-on-LAN + Custom Headers), in the `new_services_render_test.dart`
/// harness style: ProviderScope overrides + MaterialApp + fixed pumps (no
/// pumpAndSettle).
Profile _profile() => const Profile(
      id: 'p1',
      name: 'Default',
      instances: <Instance>[
        Instance(
          id: 'i1',
          name: 'Media Box',
          kind: ServiceKind.sonarr,
          localUrl: 'http://localhost:8989',
          externalUrl: '',
          urlMode: UrlMode.auto,
          auth: InstanceAuth.apiKey(apiKey: 'k'),
          customHeaders: <String, String>{'X-Instance': 'one'},
        ),
      ],
      globalHeaders: <String, String>{'X-Test': '1'},
      wolDevices: <WolDevice>[
        WolDevice(id: 'w1', name: 'Server', mac: 'AA:BB:CC:DD:EE:FF'),
      ],
    );

/// Preferences backed by nothing: keeps SettingsScreen from touching the
/// (unavailable in tests) settings Hive box.
class _FakePreferencesController extends PreferencesController {
  @override
  Preferences build() => const Preferences();
}

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides,
  Widget home, {
  int pumps = 2,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AtriumTheme.light(null), home: home),
    ),
  );
  for (int i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('WakeOnLanScreen renders the device with a Wake button',
      (WidgetTester tester) async {
    await _pump(
      tester,
      <Override>[activeProfileProvider.overrideWithValue(_profile())],
      const WakeOnLanScreen(),
    );

    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Wake'), findsOneWidget);
    expect(find.text('AA:BB:CC:DD:EE:FF - 255.255.255.255:9'), findsOneWidget);
  });

  testWidgets(
      'CustomHeadersScreen renders global headers and the instance row',
      (WidgetTester tester) async {
    await _pump(
      tester,
      <Override>[activeProfileProvider.overrideWithValue(_profile())],
      const CustomHeadersScreen(),
    );

    expect(find.text('Global headers'), findsOneWidget);
    expect(find.text('X-Test'), findsOneWidget);
    expect(find.text('Media Box'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders the Network section tiles',
      (WidgetTester tester) async {
    // Tall viewport so the whole settings list (Network sits below
    // Appearance / Font / Security) is inside the viewport.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      <Override>[
        activeProfileProvider.overrideWithValue(_profile()),
        preferencesProvider.overrideWith(_FakePreferencesController.new),
      ],
      const SettingsScreen(),
    );

    // The Network section sits below Appearance / Theme Styling / Font /
    // Security, so scroll the settings list until it is on screen.
    final Finder wol = find.text('Wake-on-LAN');
    await tester.scrollUntilVisible(
      wol,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(wol, findsOneWidget);
    expect(find.text('1 device configured'), findsOneWidget);
    expect(find.text('Custom Headers'), findsOneWidget);
  });
}
