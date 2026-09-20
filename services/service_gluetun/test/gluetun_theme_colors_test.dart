import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// Status colours have to come from the theme.
///
/// The screen used a fixed green for a running VPN and DNS server, so it
/// ignored the user's palette and dynamic wallpaper colours, and disagreed with
/// the dashboard widget, which already used the theme's primary role.
void main() {
  const Instance instance = Instance(
    id: 'gluetun',
    name: 'Gluetun',
    kind: ServiceKind.gluetun,
    localUrl: 'http://gluetun.test',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: 'k'),
  );

  Future<ColorScheme> pumpUnder(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    // A purple seed, so a hardcoded green cannot match the theme by accident.
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gluetunVpnStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunVpnStatus(status: 'running'),
          ),
          gluetunPublicIpProvider(instance)
              .overrideWith((Ref ref) async => null),
          gluetunDnsStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunDnsStatus(status: 'running'),
          ),
          gluetunUpdaterStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunUpdaterStatus(status: 'stopped'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const Scaffold(body: GluetunHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return scheme;
  }

  void expectThemeColoured(WidgetTester tester, ColorScheme scheme) {
    // Both the VPN banner and the DNS row read RUNNING.
    final Iterable<Text> running =
        tester.widgetList<Text>(find.text('RUNNING'));
    expect(running, hasLength(2));
    for (final Text text in running) {
      expect(text.style?.color, scheme.primary);
    }
    expect(tester.widget<Icon>(find.byIcon(Icons.dns)).color, scheme.primary);
  }

  testWidgets('a running VPN and DNS use the theme in dark mode',
      (WidgetTester tester) async {
    expectThemeColoured(tester, await pumpUnder(tester, Brightness.dark));
  });

  testWidgets('a running VPN and DNS use the theme in light mode',
      (WidgetTester tester) async {
    expectThemeColoured(tester, await pumpUnder(tester, Brightness.light));
  });
}
