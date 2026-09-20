import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gluetun/service_gluetun.dart';

/// Stopping Gluetun cuts off whatever sits behind it, so a stop has to be
/// confirmed before anything is sent.
///
/// Before this, Stop VPN fired on a single tap. Verified against a live
/// Gluetun: one tap took the tunnel down with no prompt, and in the usual
/// setup the download client shares that network and goes down with it.
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

  Future<_RecordingAdapter> pumpHome(
    WidgetTester tester, {
    required bool vpnRunning,
  }) async {
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          gluetunApiProvider(instance)
              .overrideWith((Ref ref) async => GluetunApi(dio)),
          gluetunVpnStatusProvider(instance).overrideWith(
            (Ref ref) async => GluetunVpnStatus(
              status: vpnRunning ? 'running' : 'stopped',
            ),
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
    return adapter;
  }

  Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  testWidgets('Stop VPN asks first and sends nothing until confirmed',
      (WidgetTester tester) async {
    final _RecordingAdapter adapter =
        await pumpHome(tester, vpnRunning: true);

    await tester.tap(find.text('Stop VPN'));
    await settle(tester);

    expect(find.text('Stop the VPN?'), findsOneWidget);
    expect(adapter.puts, isEmpty, reason: 'nothing may be sent before a yes');

    await tester.tap(inDialog('Cancel'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(adapter.puts, isEmpty, reason: 'Cancel must not stop anything');

    await tester.tap(find.text('Stop VPN'));
    await settle(tester);
    await tester.tap(inDialog('Stop VPN'));
    await settle(tester);

    expect(adapter.puts, hasLength(1));
    expect(adapter.puts.single.path, endsWith('v1/vpn/status'));
    expect(
      (adapter.puts.single.data as Map<String, dynamic>)['status'],
      'stopped',
    );
  });

  testWidgets('Starting a stopped VPN does not ask',
      (WidgetTester tester) async {
    // Starting cannot cut anything off, so a prompt there would only nag.
    final _RecordingAdapter adapter =
        await pumpHome(tester, vpnRunning: false);

    await tester.tap(find.text('Start VPN'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(adapter.puts, hasLength(1));
    expect(
      (adapter.puts.single.data as Map<String, dynamic>)['status'],
      'running',
    );
  });

  testWidgets('Stop DNS asks first and sends nothing until confirmed',
      (WidgetTester tester) async {
    final _RecordingAdapter adapter =
        await pumpHome(tester, vpnRunning: true);

    await tester.tap(find.text('Stop'));
    await settle(tester);

    expect(find.text('Stop DNS?'), findsOneWidget);
    expect(adapter.puts, isEmpty);

    await tester.tap(inDialog('Stop DNS'));
    await settle(tester);

    expect(adapter.puts, hasLength(1));
    expect(adapter.puts.single.path, endsWith('v1/dns/status'));
  });
}

/// Records every request and answers each with a small JSON body.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  Iterable<RequestOptions> get puts =>
      requests.where((RequestOptions r) => r.method == 'PUT');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"status":"stopped"}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
