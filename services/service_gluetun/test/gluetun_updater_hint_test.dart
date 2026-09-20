import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// Update Servers says what ProtonVPN needs for it to do anything.
///
/// Gluetun asks Proton's API for the server list, and since v3.40.1 that
/// needs the account login. Without it, tapping Update Servers on a live
/// Gluetun looked like it worked while nothing was updated.
void main() {
  testWidgets('Update Servers names the Proton login it needs',
      (WidgetTester tester) async {
    const Instance instance = Instance(
      id: 'gluetun',
      name: 'Gluetun',
      kind: ServiceKind.gluetun,
      localUrl: 'http://gluetun.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gluetunVpnStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunVpnStatus(status: 'running'),
          ),
          gluetunPublicIpProvider(instance)
              .overrideWith((Ref ref) async => null),
          gluetunPortForwardProvider(instance)
              .overrideWith((Ref ref) async => null),
          gluetunDnsStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunDnsStatus(status: 'running'),
          ),
          gluetunUpdaterStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunUpdaterStatus(status: 'completed'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GluetunHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('UPDATER_PROTONVPN_EMAIL'),
      200,
    );

    expect(find.text('Update Servers'), findsOneWidget);
    expect(
      find.textContaining(
        'UPDATER_PROTONVPN_EMAIL and UPDATER_PROTONVPN_PASSWORD',
      ),
      findsOneWidget,
    );
  });
}
