import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// The forwarded port, which changes every time the VPN reconnects.
///
/// The answers below are Gluetun's own: taken from a live Gluetun forwarding a
/// ProtonVPN port, and from its source for releases before v3.41.
void main() {
  group('GluetunPortForward', () {
    test('reads every port current Gluetun lists', () {
      expect(
        GluetunPortForward.fromJson(
          <String, dynamic>{'port': 42702, 'ports': <int>[42702]},
        ).ports,
        <int>[42702],
      );
      expect(
        GluetunPortForward.fromJson(
          <String, dynamic>{'port': 1000, 'ports': <int>[1000, 2000]},
        ).ports,
        <int>[1000, 2000],
      );
    });

    test('reads what an older Gluetun sends', () {
      // Before v3.41 one port came as `port` alone, and several as `ports`
      // with no `port` at all.
      expect(
        GluetunPortForward.fromJson(<String, dynamic>{'port': 5914}).ports,
        <int>[5914],
      );
      expect(
        GluetunPortForward.fromJson(
          <String, dynamic>{'ports': <int>[1000, 2000]},
        ).ports,
        <int>[1000, 2000],
      );
    });

    test('nothing forwarded yet is no ports', () {
      // What Gluetun answers for the few seconds after the VPN starts.
      expect(
        GluetunPortForward.fromJson(
          <String, dynamic>{'port': 0, 'ports': <int>[]},
        ).ports,
        isEmpty,
      );
      expect(
        GluetunPortForward.fromJson(<String, dynamic>{'ports': null}).ports,
        isEmpty,
      );
    });
  });

  group('GluetunApi.getPortForward', () {
    test('asks the current route when Gluetun has it', () async {
      final _Routes routes = _Routes(<String, (int, String)>{
        '/v1/portforward': (200, '{"port":42702,"ports":[42702]}'),
      });

      expect((await routes.api.getPortForward())?.ports, <int>[42702]);
      expect(routes.asked, <String>['/v1/portforward']);
    });

    test('asks the old route on a Gluetun from before v3.41', () async {
      // Gluetun answers a route it does not have with 400, not 404.
      final _Routes routes = _Routes(<String, (int, String)>{
        '/v1/portforward': (400, 'GET /portforward not found'),
        '/v1/openvpn/portforwarded': (200, '{"port":5914}'),
      });

      expect((await routes.api.getPortForward())?.ports, <int>[5914]);
      expect(
        routes.asked,
        <String>['/v1/portforward', '/v1/openvpn/portforwarded'],
      );
    });

    test('asks the old route when the role only grants that one', () async {
      // The only role a v3.40 Gluetun accepts: it refuses to start with the
      // new route listed, so the new route is refused with 401.
      final _Routes routes = _Routes(<String, (int, String)>{
        '/v1/portforward': (401, 'Unauthorized'),
        '/v1/openvpn/portforwarded': (200, '{"port":5914}'),
      });

      expect((await routes.api.getPortForward())?.ports, <int>[5914]);
    });

    test('keeps asking the old route once it has answered', () async {
      final _Routes routes = _Routes(<String, (int, String)>{
        '/v1/portforward': (401, 'Unauthorized'),
        '/v1/openvpn/portforwarded': (200, '{"port":5914}'),
      });
      final GluetunApi api = routes.api;

      await api.getPortForward();
      await api.getPortForward();

      expect(routes.asked, <String>[
        '/v1/portforward',
        '/v1/openvpn/portforwarded',
        '/v1/openvpn/portforwarded',
      ]);
    });

    test('throws the current route failing when both are refused', () async {
      final _Routes routes = _Routes(<String, (int, String)>{
        '/v1/portforward': (401, 'Unauthorized'),
        '/v1/openvpn/portforwarded': (401, 'Unauthorized'),
      });

      await expectLater(
        routes.api.getPortForward(),
        throwsA(
          isA<DioException>().having(
            (DioException e) => e.requestOptions.uri.path,
            'path',
            '/v1/portforward',
          ),
        ),
      );
    });

    test('does not ask the old route when Gluetun is failing', () async {
      final _Routes routes = _Routes(<String, (int, String)>{
        '/v1/portforward': (500, 'Internal Server Error'),
      });

      await expectLater(
        routes.api.getPortForward(),
        throwsA(isA<DioException>()),
      );
      expect(routes.asked, <String>['/v1/portforward']);
    });
  });

  group('GluetunHome forwarded port', () {
    const Instance instance = Instance(
      id: 'gluetun',
      name: 'Gluetun',
      kind: ServiceKind.gluetun,
      localUrl: 'http://gluetun.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

    Future<void> pumpHome(
      WidgetTester tester,
      Future<GluetunPortForward?> Function() readPort,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          // Riverpod retries a failed provider on a timer by default, which
          // would still be pending when the test ends.
          retry: (int retryCount, Object error) => null,
          overrides: <Override>[
            gluetunVpnStatusProvider(instance).overrideWith(
              (Ref ref) async => const GluetunVpnStatus(status: 'running'),
            ),
            gluetunPublicIpProvider(instance)
                .overrideWith((Ref ref) async => null),
            gluetunPortForwardProvider(instance)
                .overrideWith((Ref ref) => readPort()),
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

    Finder portText(String ports) => find.byWidgetPredicate(
          (Widget widget) => widget is SelectableText && widget.data == ports,
        );

    testWidgets('shows the port once one is forwarded',
        (WidgetTester tester) async {
      await pumpHome(
        tester,
        () async => const GluetunPortForward(port: 42702, ports: <int>[42702]),
      );

      expect(find.text('Forwarded Port'), findsOneWidget);
      expect(portText('42702'), findsOneWidget);
    });

    testWidgets('leaves the port out while nothing is forwarded',
        (WidgetTester tester) async {
      await pumpHome(tester, () async => const GluetunPortForward(port: 0));

      expect(find.textContaining('Forwarded Port'), findsNothing);
    });

    testWidgets('leaves the port out when the route is refused',
        (WidgetTester tester) async {
      final RequestOptions request = RequestOptions(path: 'v1/portforward');
      await pumpHome(
        tester,
        () async => throw DioException(
          requestOptions: request,
          response: Response<dynamic>(requestOptions: request, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(find.textContaining('Forwarded Port'), findsNothing);
      expect(find.textContaining('portforward'), findsNothing);
    });
  });
}

/// A Gluetun that answers each path with its own status and body, labelled
/// `text/plain` as Gluetun labels everything, and remembers what was asked.
class _Routes implements HttpClientAdapter {
  _Routes(this.answers);

  final Map<String, (int, String)> answers;
  final List<String> asked = <String>[];

  GluetunApi get api => GluetunApi(
        Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
          ..httpClientAdapter = this,
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.uri.path);
    final (int status, String body) =
        answers[options.uri.path] ?? (404, 'not found');
    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
