import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// Whatever Gluetun refuses has to be reported as refused.
///
/// Current Gluetun refuses any route its auth config does not grant, which is
/// the easiest thing to get wrong when setting it up. Verified against a live
/// Gluetun with the PUT routes left out of the role: Update Servers and Stop
/// DNS both got a 401 and the app showed a success message for each, and
/// Stop VPN showed a raw DioException that never mentioned the route. With the
/// GET routes left out instead, the VPN card showed the same raw exception,
/// and the other cards passed the refusal off as a public IP check that was
/// switched off, a DNS server in state UNKNOWN, and an IDLE updater.
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

  GluetunApi apiAnswering(int status, String body) => GluetunApi(
        Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
          ..httpClientAdapter = _Answer(status: status, body: body),
      );

  group('GluetunApi changes', () {
    test('a refused change throws instead of passing for success', () async {
      final GluetunApi api = apiAnswering(401, 'Unauthorized');

      await expectLater(
        api.setVpnStatus(run: false),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        api.setDnsStatus(run: false),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        api.setUpdaterStatus(run: true),
        throwsA(isA<DioException>()),
      );
    });

    test('a successful change reports the state that was asked for', () async {
      // Gluetun answers a change with {"outcome": ...}, not the status object
      // its GET returns, so parsing the reply as a status read nothing and
      // fell back to "unknown" or "idle".
      final GluetunApi api = apiAnswering(200, '{"outcome":"already running"}');

      expect((await api.setVpnStatus(run: true)).status, 'running');
      expect((await api.setDnsStatus(run: false)).status, 'stopped');
      expect((await api.setUpdaterStatus(run: true)).status, 'running');
    });
  });

  group('GluetunApi reads', () {
    test('a refused read throws instead of reading as empty', () async {
      final GluetunApi api = apiAnswering(401, 'Unauthorized');

      await expectLater(api.getVpnStatus(), throwsA(isA<DioException>()));
      await expectLater(api.getPublicIp(), throwsA(isA<DioException>()));
      await expectLater(api.getPortForward(), throwsA(isA<DioException>()));
      await expectLater(api.getDnsStatus(), throwsA(isA<DioException>()));
      await expectLater(api.getUpdaterStatus(), throwsA(isA<DioException>()));
    });

    test('a granted read still parses, text/plain label and all', () async {
      final GluetunApi api = apiAnswering(200, '{"status":"running"}');

      expect((await api.getVpnStatus()).isRunning, isTrue);
      expect((await api.getDnsStatus())?.isRunning, isTrue);
    });
  });

  group('describeGluetunFailure', () {
    Future<Object> failureOf(Future<Object?> Function() read) async {
      try {
        await read();
      } on Object catch (error) {
        return error;
      }
      fail('expected the read to throw');
    }

    test('a refusal names the route to grant', () async {
      final Object error =
          await failureOf(apiAnswering(403, 'Forbidden').getVpnStatus);

      expect(
        describeGluetunFailure(error, 'GET /v1/vpn/status'),
        'Gluetun refused it. Check that the role for this API key grants '
        'GET /v1/vpn/status.',
      );
    });

    test('a login page in front of Gluetun is not called unreachable',
        () async {
      // A forward-auth proxy redirects to its portal, which answers 200 with
      // a page. Without the response on the exception this read as a server
      // that never answered.
      final Object error = await failureOf(
        apiAnswering(200, '<!DOCTYPE html><title>Login</title>').getVpnStatus,
      );

      expect(
        describeGluetunFailure(error, 'GET /v1/vpn/status'),
        startsWith('Something other than Gluetun answered.'),
      );
    });

    test('no answer at all is unreachable', () {
      final DioException error = DioException.connectionError(
        requestOptions: RequestOptions(path: 'v1/vpn/status'),
        reason: 'Connection refused',
      );

      expect(
        describeGluetunFailure(error, 'GET /v1/vpn/status'),
        'Gluetun could not be reached.',
      );
    });
  });

  group('GluetunHome when a change is refused', () {
    Future<void> pumpRefusingHome(WidgetTester tester) async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
        ..httpClientAdapter = _Answer(status: 401, body: 'Unauthorized');
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            gluetunApiProvider(instance)
                .overrideWith((Ref ref) async => GluetunApi(dio)),
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
          child: const MaterialApp(
            home: Scaffold(body: GluetunHome(instance: instance)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 500));

    testWidgets('Update Servers says it was refused, not triggered',
        (WidgetTester tester) async {
      await pumpRefusingHome(tester);

      await tester.tap(find.text('Update Servers'));
      await settle(tester);

      expect(find.textContaining('Triggered server list'), findsNothing);
      expect(find.textContaining('Gluetun refused it'), findsOneWidget);
      expect(find.textContaining('PUT /v1/updater/status'), findsOneWidget);
    });

    testWidgets('Stop DNS says it was refused, not stopping',
        (WidgetTester tester) async {
      await pumpRefusingHome(tester);

      await tester.tap(find.text('Stop'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Stop DNS'),
        ),
      );
      await settle(tester);

      expect(find.text('Stopping DNS...'), findsNothing);
      expect(find.textContaining('PUT /v1/dns/status'), findsOneWidget);
    });

    testWidgets('Stop VPN names the route instead of dumping the exception',
        (WidgetTester tester) async {
      await pumpRefusingHome(tester);

      await tester.tap(find.text('Stop VPN'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Stop VPN'),
        ),
      );
      await settle(tester);

      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('PUT /v1/vpn/status'), findsOneWidget);
    });
  });

  testWidgets('GluetunHome names the route for every read that is refused',
      (WidgetTester tester) async {
    final GluetunApi api = apiAnswering(401, 'Unauthorized');
    await tester.pumpWidget(
      ProviderScope(
        // Riverpod retries a failed provider on a timer by default, which
        // would still be pending when the test ends.
        retry: (int retryCount, Object error) => null,
        overrides: <Override>[
          gluetunVpnStatusProvider(instance)
              .overrideWith((Ref ref) => api.getVpnStatus()),
          gluetunPublicIpProvider(instance)
              .overrideWith((Ref ref) => api.getPublicIp()),
          gluetunDnsStatusProvider(instance)
              .overrideWith((Ref ref) => api.getDnsStatus()),
          gluetunUpdaterStatusProvider(instance)
              .overrideWith((Ref ref) => api.getUpdaterStatus()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GluetunHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('DioException'), findsNothing);
    for (final String route in <String>[
      'GET /v1/vpn/status',
      'GET /v1/publicip/ip',
      'GET /v1/dns/status',
      'GET /v1/updater/status',
    ]) {
      expect(find.textContaining(route), findsOneWidget, reason: route);
    }
    // What the refusals used to be passed off as.
    expect(find.textContaining('check disabled'), findsNothing);
    expect(find.text('UNKNOWN'), findsNothing);
    expect(find.text('IDLE'), findsNothing);
    expect(find.text('Start'), findsNothing);
  });
}

/// Answers every request with one status and body.
///
/// Labelled `text/plain` whatever the body holds, as Gluetun does: its JSON
/// status and outcome objects and its bare-word 401 all arrive that way,
/// checked against a live Gluetun. So the client has to decode JSON itself
/// rather than rely on Dio doing it from the content type.
class _Answer implements HttpClientAdapter {
  _Answer({required this.status, required this.body});

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain; charset=utf-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}
