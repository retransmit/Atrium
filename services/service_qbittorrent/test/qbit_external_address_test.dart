import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';
// Not exported: only the home screen builds it.
import 'package:service_qbittorrent/src/qbittorrent_settings_tab.dart';

/// Answers the routes the System settings tab reads, with [serverState] as
/// the `server_state` of a full `/sync/maindata` reply.
class _Qbittorrent implements HttpClientAdapter {
  _Qbittorrent(this.serverState);

  final Map<String, dynamic> serverState;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return switch (options.uri.path) {
      '/api/v2/sync/maindata' => _json(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'torrents': <String, dynamic>{},
          'server_state': serverState,
        }),
      '/api/v2/transfer/info' => _json(<String, dynamic>{
          'connection_status': 'connected',
        }),
      '/api/v2/app/version' => _text('v5.2.0'),
      '/api/v2/app/webapiVersion' => _text('2.13.0'),
      _ => ResponseBody.fromString('Not Found', 404),
    };
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  ResponseBody _text(String body) => ResponseBody.fromString(
        body,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain; charset=UTF-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}

const Instance _instance = Instance(
  id: 'qbit-1',
  name: 'qBit',
  kind: ServiceKind.qbittorrent,
  localUrl: 'https://qbit.example.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

/// qBittorrent reports the public address it last saw itself at in the
/// `server_state` of `/sync/maindata` (5.0 onwards), which Settings > System
/// shows. The server state comes as a delta like the torrents do, so the
/// store has to keep it between replies.
void main() {
  group('the sync store', () {
    test('keeps the addresses from a full update', () {
      final QbitSyncStore store = QbitSyncStore()
        ..apply(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'server_state': <String, dynamic>{
            'last_external_address_v4': '203.0.113.7',
            'last_external_address_v6': '',
          },
        });
      expect(store.externalAddresses, (v4: '203.0.113.7', v6: ''));
    });

    test('keeps them through a delta that leaves them out', () {
      final QbitSyncStore store = QbitSyncStore()
        ..apply(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'server_state': <String, dynamic>{
            'last_external_address_v4': '203.0.113.7',
            'last_external_address_v6': '2001:db8::7',
          },
        })
        ..apply(<String, dynamic>{
          'rid': 2,
          'server_state': <String, dynamic>{'dl_info_speed': 10},
        });
      expect(store.externalAddresses, (v4: '203.0.113.7', v6: '2001:db8::7'));
    });

    test('takes a changed address from a delta', () {
      final QbitSyncStore store = QbitSyncStore()
        ..apply(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'server_state': <String, dynamic>{
            'last_external_address_v4': '203.0.113.7',
          },
        })
        ..apply(<String, dynamic>{
          'rid': 2,
          'server_state': <String, dynamic>{
            'last_external_address_v4': '198.51.100.4',
          },
        });
      expect(store.externalAddresses.v4, '198.51.100.4');
    });

    test('a full update without the fields forgets them', () {
      // A server restarted onto an older qBittorrent, which never sends them.
      final QbitSyncStore store = QbitSyncStore()
        ..apply(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'server_state': <String, dynamic>{
            'last_external_address_v4': '203.0.113.7',
          },
        })
        ..apply(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'server_state': <String, dynamic>{'dl_info_speed': 0},
        });
      expect(store.externalAddresses, (v4: null, v6: null));
    });
  });

  group('Settings > System', () {
    late List<String> copied;

    setUp(() {
      copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> open(
      WidgetTester tester,
      Map<String, dynamic> serverState,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final QbittorrentClient client = QbittorrentClient(
        dio: Dio(BaseOptions(baseUrl: 'https://qbit.example.test/'))
          ..httpClientAdapter = _Qbittorrent(serverState),
        cookies: CookieJar(),
        username: '',
        password: '',
        apiKey: 'k',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            qbittorrentClientProvider(_instance)
                .overrideWith((Ref ref) async => client),
          ],
          child: const MaterialApp(
            home: Scaffold(body: QbittorrentSettingsTab(instance: _instance)),
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // The list polls, so the tree is taken down before the test ends.
    Future<void> close(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox.shrink());

    testWidgets('shows the IPv4 address and copies it on a tap',
        (WidgetTester tester) async {
      await open(tester, <String, dynamic>{
        'last_external_address_v4': '203.0.113.7',
        'last_external_address_v6': '',
      });

      expect(find.text('External IPv4'), findsOneWidget);
      expect(find.text('203.0.113.7'), findsOneWidget);
      // No IPv6 address, which is most connections: no row for it.
      expect(find.text('External IPv6'), findsNothing);

      await tester.tap(find.text('203.0.113.7'));
      await tester.pump();
      expect(copied, <String>['203.0.113.7']);
      expect(find.text('External IPv4 copied'), findsOneWidget);
      await close(tester);
    });

    testWidgets('shows an IPv6 address when there is one',
        (WidgetTester tester) async {
      await open(tester, <String, dynamic>{
        'last_external_address_v4': '203.0.113.7',
        'last_external_address_v6': '2001:db8:85a3::8a2e:370:7334',
      });

      expect(find.text('External IPv6'), findsOneWidget);
      expect(find.text('2001:db8:85a3::8a2e:370:7334'), findsOneWidget);
      await close(tester);
    });

    testWidgets('says the address is not known before qBittorrent learns it',
        (WidgetTester tester) async {
      await open(tester, <String, dynamic>{
        'last_external_address_v4': '',
        'last_external_address_v6': '',
      });

      expect(find.text('External IPv4'), findsOneWidget);
      expect(find.text('Not known yet'), findsOneWidget);
      await tester.tap(find.text('Not known yet'));
      await tester.pump();
      expect(copied, isEmpty);
      await close(tester);
    });

    testWidgets('shows no rows for a qBittorrent that does not report them',
        (WidgetTester tester) async {
      await open(tester, <String, dynamic>{'connection_status': 'connected'});

      expect(find.text('Connection Status'), findsOneWidget);
      expect(find.textContaining('External IP'), findsNothing);
      await close(tester);
    });
  });
}
