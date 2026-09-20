import 'package:atrium/src/dashboard/dashboard_widget_kind.dart';
import 'package:atrium/src/dashboard/widgets/gluetun_status_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

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

  // A purple seed, so a fixed blue or green cannot match by accident.
  final ColorScheme scheme =
      ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

  Future<void> pumpCard(
    WidgetTester tester, {
    required Override vpnStatus,
    GluetunPublicIp? publicIp,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        // Riverpod retries a failed provider on a timer by default, which
        // would still be pending when the test ends.
        retry: (int retryCount, Object error) => null,
        overrides: <Override>[
          vpnStatus,
          gluetunPublicIpProvider(instance)
              .overrideWith((Ref ref) async => publicIp),
        ],
        child: MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const Scaffold(
            body: DashboardGluetunStatusWidget(instances: <Instance>[instance]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  final Override running = gluetunVpnStatusProvider(instance).overrideWith(
    (Ref ref) async => const GluetunVpnStatus(status: 'running'),
  );

  // The card takes every colour from the theme.
  //
  // Its badge used the fixed brand blue while the other dashboard cards use
  // a theme role, so it was the one card that ignored the user's palette.
  testWidgets('the badge and status chip follow the theme',
      (WidgetTester tester) async {
    await pumpCard(tester, vpnStatus: running);

    final Icon badge = tester.widget<Icon>(
      find.byIcon(DashboardWidgetKind.gluetunStatus.icon),
    );
    expect(badge.color, scheme.primary);
    expect(
      tester.widget<Text>(find.text('RUNNING')).style?.color,
      scheme.primary,
    );
  });

  // A city-state reports its name as the city, region and country, which
  // the card joined into "Singapore, Singapore, Singapore".
  testWidgets('a city-state is named once', (WidgetTester tester) async {
    await pumpCard(
      tester,
      vpnStatus: running,
      publicIp: const GluetunPublicIp(
        publicIp: '203.0.113.7',
        country: 'Singapore',
        region: 'Singapore',
        city: 'Singapore',
      ),
    );

    expect(find.text('Singapore'), findsOneWidget);
  });

  // A card that cannot load says why.
  //
  // It only ever said it could not load, which left a role missing the
  // status route looking the same as a server that is down.
  testWidgets('a refused status read names the route to grant',
      (WidgetTester tester) async {
    final RequestOptions request = RequestOptions(path: 'v1/vpn/status');
    await pumpCard(
      tester,
      vpnStatus: gluetunVpnStatusProvider(instance).overrideWith(
        (Ref ref) async => throw DioException(
          requestOptions: request,
          response: Response<dynamic>(requestOptions: request, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      ),
    );

    expect(
      find.textContaining('Could not load Gluetun status.'),
      findsOneWidget,
    );
    expect(find.textContaining('GET /v1/vpn/status'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });
}
