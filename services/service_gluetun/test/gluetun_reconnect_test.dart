import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// Reconnect stops the VPN and starts it again in one action.
///
/// Gluetun has no route for it. Checked against a live Gluetun: a stop and a
/// start each answer within a second, and the tunnel is back within seconds,
/// sometimes on another server with a new public IP and forwarded port, and
/// sometimes on the same one.
void main() {
  group('GluetunApi.reconnectVpn', () {
    test('stops the VPN, then starts it', () async {
      final _Gluetun gluetun = _Gluetun();

      await gluetun.api.reconnectVpn();

      expect(gluetun.changes, <String>['stopped', 'running']);
    });

    test('a refused stop throws and starts nothing', () async {
      final _Gluetun gluetun = _Gluetun(putAnswers: <int>[401]);

      await expectLater(
        gluetun.api.reconnectVpn(),
        throwsA(isA<DioException>()),
      );
      expect(gluetun.changes, <String>['stopped']);
    });

    test('a start that fails after the stop says the VPN was left down',
        () async {
      final _Gluetun gluetun = _Gluetun(putAnswers: <int>[200, 500]);

      await expectLater(
        gluetun.api.reconnectVpn(),
        throwsA(isA<GluetunRestartFailed>()),
      );
      expect(gluetun.changes, <String>['stopped', 'running']);
    });
  });

  group('GluetunHome Reconnect', () {
    const Instance instance = Instance(
      id: 'gluetun',
      name: 'Gluetun',
      kind: ServiceKind.gluetun,
      localUrl: 'http://gluetun.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

    Future<_Gluetun> pumpHome(
      WidgetTester tester, {
      required bool vpnRunning,
      List<int> putAnswers = const <int>[],
    }) async {
      final _Gluetun gluetun = _Gluetun(putAnswers: putAnswers);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            gluetunApiProvider(instance)
                .overrideWith((Ref ref) async => gluetun.api),
            gluetunVpnStatusProvider(instance).overrideWith(
              (Ref ref) async => GluetunVpnStatus(
                status: vpnRunning ? 'running' : 'stopped',
              ),
            ),
            gluetunPublicIpProvider(instance)
                .overrideWith((Ref ref) async => null),
            gluetunPortForwardProvider(instance)
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
      return gluetun;
    }

    Finder inDialog(String text) => find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(text),
        );

    Future<void> settle(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 500));

    testWidgets('is offered while the VPN runs', (WidgetTester tester) async {
      await pumpHome(tester, vpnRunning: true);

      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Stop VPN'), findsOneWidget);
    });

    testWidgets('is not offered while the VPN is stopped',
        (WidgetTester tester) async {
      await pumpHome(tester, vpnRunning: false);

      expect(find.text('Reconnect'), findsNothing);
      expect(find.text('Start VPN'), findsOneWidget);
    });

    testWidgets('asks first, then stops and starts the VPN',
        (WidgetTester tester) async {
      final _Gluetun gluetun = await pumpHome(tester, vpnRunning: true);

      await tester.tap(find.text('Reconnect'));
      await settle(tester);

      expect(find.text('Reconnect the VPN?'), findsOneWidget);
      expect(gluetun.changes, isEmpty, reason: 'nothing before a yes');

      await tester.tap(inDialog('Cancel'));
      await settle(tester);
      expect(gluetun.changes, isEmpty, reason: 'Cancel must not stop it');

      await tester.tap(find.text('Reconnect'));
      await settle(tester);
      await tester.tap(inDialog('Reconnect'));
      await settle(tester);

      expect(gluetun.changes, <String>['stopped', 'running']);
      expect(find.text('Reconnecting VPN...'), findsOneWidget);
    });

    testWidgets('says the VPN is down when it stopped but did not start',
        (WidgetTester tester) async {
      await pumpHome(
        tester,
        vpnRunning: true,
        putAnswers: <int>[200, 500],
      );

      await tester.tap(find.text('Reconnect'));
      await settle(tester);
      await tester.tap(inDialog('Reconnect'));
      await settle(tester);

      expect(
        find.textContaining('The VPN stopped but did not start again.'),
        findsOneWidget,
      );
      expect(find.text('Reconnecting VPN...'), findsNothing);
    });
  });
}

/// A Gluetun that answers each change in turn with the next status given,
/// 200 once they run out, and remembers which states were asked for.
class _Gluetun implements HttpClientAdapter {
  _Gluetun({List<int> putAnswers = const <int>[]})
      : _putAnswers = List<int>.of(putAnswers);

  final List<int> _putAnswers;
  final List<String> changes = <String>[];

  late final GluetunApi api = GluetunApi(
    Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
      ..httpClientAdapter = this,
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    int status = 200;
    String body = '{}';
    if (options.method == 'PUT') {
      final String asked =
          (options.data as Map<String, String>)['status'] ?? '';
      changes.add(asked);
      status = _putAnswers.isEmpty ? 200 : _putAnswers.removeAt(0);
      body = status == 200 ? '{"outcome":"$asked"}' : 'failed';
    }
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
