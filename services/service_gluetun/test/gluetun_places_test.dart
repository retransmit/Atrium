import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// A place Gluetun reports more than once is named once.
///
/// Seen live on a ProtonVPN server in Singapore: Gluetun reports that name as
/// the city, the region and the country, and the screen showed it three times.
void main() {
  GluetunPlaces placesOf({String? country, String? region, String? city}) =>
      GluetunPublicIp(
        publicIp: '203.0.113.7',
        country: country,
        region: region,
        city: city,
      ).places;

  group('GluetunPublicIp.places', () {
    test('a city-state is named once, as the country', () {
      expect(
        placesOf(country: 'Singapore', region: 'Singapore', city: 'Singapore'),
        (country: 'Singapore', region: null, city: null),
      );
    });

    test('a city named like its region keeps the region', () {
      expect(
        placesOf(country: 'Japan', region: 'Tokyo', city: 'Tokyo'),
        (country: 'Japan', region: 'Tokyo', city: null),
      );
    });

    test('places that all differ are all kept', () {
      expect(
        placesOf(
          country: 'Netherlands',
          region: 'North Holland',
          city: 'Amsterdam',
        ),
        (country: 'Netherlands', region: 'North Holland', city: 'Amsterdam'),
      );
    });

    test('case and spacing do not make a repeat look like a new place', () {
      expect(
        placesOf(
          country: 'Singapore',
          region: ' singapore ',
          city: 'SINGAPORE',
        ),
        (country: 'Singapore', region: null, city: null),
      );
    });

    test('blank places are left out', () {
      expect(
        placesOf(country: '', region: '  '),
        (country: null, region: null, city: null),
      );
    });
  });

  testWidgets('GluetunHome names a city-state once',
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
          gluetunPublicIpProvider(instance).overrideWith(
            (Ref ref) async => const GluetunPublicIp(
              publicIp: '203.0.113.7',
              country: 'Singapore',
              region: 'Singapore',
              city: 'Singapore',
              organization: 'Example Hosting',
            ),
          ),
          gluetunDnsStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunDnsStatus(status: 'running'),
          ),
          gluetunUpdaterStatusProvider(instance).overrideWith(
            (Ref ref) async => const GluetunUpdaterStatus(status: 'stopped'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GluetunHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Singapore'), findsOneWidget);
    expect(find.text('Example Hosting'), findsOneWidget);
  });
}
