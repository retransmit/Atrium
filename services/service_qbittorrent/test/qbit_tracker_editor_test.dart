import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

import 'support/qbit_fixtures.dart';

const String _a = 'udp://a.example.org:1337/announce';
const String _b = 'https://b.example.org/announce';

/// A qBittorrent holding one torrent's trackers, whose first tracker removal
/// fails the way a server error would.
class _FakeQbit implements HttpClientAdapter {
  final List<Map<String, dynamic>> trackers = <Map<String, dynamic>>[
    <String, dynamic>{'url': _a, 'tier': 0, 'status': 1},
  ];
  final List<String> removed = <String>[];
  bool failNextRemove = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;
    final Map<String, dynamic> form = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    if (path.endsWith('torrents/trackers')) {
      return _json(trackers);
    }
    if (path.endsWith('torrents/addTrackers')) {
      for (final String url in (form['urls'] as String).split('\n')) {
        if (url.isNotEmpty) {
          trackers.add(<String, dynamic>{'url': url, 'tier': 0, 'status': 1});
        }
      }
      return _json('');
    }
    if (path.endsWith('torrents/removeTrackers')) {
      if (failNextRemove) {
        failNextRemove = false;
        return ResponseBody.fromString('', 500);
      }
      final List<String> urls = (form['urls'] as String).split('|');
      removed.addAll(urls);
      trackers.removeWhere((Map<String, dynamic> t) => urls.contains(t['url']));
      return _json('');
    }
    if (path.endsWith('sync/torrentPeers')) {
      return _json(<String, dynamic>{'peers': <String, dynamic>{}});
    }
    return _json(<dynamic>[]);
  }

  ResponseBody _json(Object data) => ResponseBody.fromString(
        jsonEncode(data),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

const Instance _instance = Instance(
  id: 'test-qbit',
  name: 'Test qBittorrent',
  kind: ServiceKind.qbittorrent,
  localUrl: 'http://qbit.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

Future<void> _openTrackers(WidgetTester tester, _FakeQbit server) async {
  tester.view.physicalSize = const Size(411, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final QbitTorrent row = QbitTorrent.fromJson(torrentRowJson());
  final QbittorrentClient client = QbittorrentClient(
    dio: Dio(BaseOptions(baseUrl: 'http://qbit.test/'))
      ..httpClientAdapter = server,
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
        qbitRawTorrentsProvider(_instance)
            .overrideWith((Ref ref) async => <QbitTorrent>[row]),
        qbitPropertiesProvider((_instance, row.hash)).overrideWith(
          (Ref ref) async =>
              QbitTorrentProperties.fromJson(torrentPropertiesJson()),
        ),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: TorrentDetailScreen(instance: _instance, torrent: row),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Trackers'));
  await tester.pumpAndSettle();
}

Finder get _editor => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );

Finder get _save => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(FilledButton, 'Save'),
    );

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  testWidgets('says that trackers already there keep their tier',
      (WidgetTester tester) async {
    await _openTrackers(tester, _FakeQbit());
    await tester.tap(find.text('Edit trackers'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('the torrent already has keep their tier'),
      findsOneWidget,
    );

    await _unmount(tester);
  });

  testWidgets('after a save that half went through, the next one is worked '
      'out against what the torrent has now', (WidgetTester tester) async {
    final _FakeQbit server = _FakeQbit();
    await _openTrackers(tester, server);
    await tester.tap(find.text('Edit trackers'));
    await tester.pumpAndSettle();

    // Swap A for B: B is added, then removing A fails.
    await tester.enterText(_editor, _b);
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(
      server.trackers.map((Map<String, dynamic> t) => t['url']),
      <String>[_a, _b],
    );

    // Change of mind: keep A after all. B is on the torrent now, so it has
    // to go, which a list read before the save would not know.
    await tester.enterText(_editor, _a);
    await tester.pump();
    expect(find.text('1 to remove'), findsOneWidget);
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(server.removed, <String>[_b]);
    expect(
      server.trackers.map((Map<String, dynamic> t) => t['url']),
      <String>[_a],
    );

    await _unmount(tester);
  });
}
