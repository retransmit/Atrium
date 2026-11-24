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
import 'package:service_qbittorrent/src/qbittorrent_action_utils.dart';

import 'support/qbit_fixtures.dart';

const String _other = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// A qBittorrent with two categories and two torrents. Setting a category
/// moves the torrent's save path to the category's, as Automatic Torrent
/// Management does. [failNext] makes the next change answer 409.
class _FakeQbit implements HttpClientAdapter {
  _FakeQbit({String first = 'movies', String second = 'movies'})
      : category = <String, String>{qbitFixtureHash: first, _other: second};

  static const Map<String, String> paths = <String, String>{
    'movies': '/data/movies',
    'tv': '/data/tv',
  };

  final Map<String, String> category;
  final List<Map<String, dynamic>> sets = <Map<String, dynamic>>[];
  bool failNext = false;

  String savePath(String hash) => paths[category[hash]] ?? '/data/torrents';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;
    if (path.endsWith('torrents/categories')) {
      return _json(<String, dynamic>{
        for (final MapEntry<String, String> e in paths.entries)
          e.key: <String, String>{'name': e.key, 'savePath': e.value},
      });
    }
    if (path.endsWith('torrents/setCategory')) {
      if (failNext) {
        failNext = false;
        return ResponseBody.fromString('Incorrect category name', 409);
      }
      final Map<String, dynamic> form =
          Map<String, dynamic>.from(options.data as Map);
      sets.add(form);
      for (final String h in (form['hashes'] as String).split('|')) {
        category[h] = form['category'] as String;
      }
      return _json('');
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

QbitTorrent _row(_FakeQbit server, String hash) => QbitTorrent.fromJson(
      <String, dynamic>{
        ...torrentRowJson(hash: hash),
        'category': server.category[hash],
        'save_path': server.savePath(hash),
      },
    );

List<Override> _overrides(_FakeQbit server) {
  final QbittorrentClient client = QbittorrentClient(
    dio: Dio(BaseOptions(baseUrl: 'http://qbit.test/'))
      ..httpClientAdapter = server,
    cookies: CookieJar(),
    username: '',
    password: '',
    apiKey: 'k',
  );
  return <Override>[
    qbittorrentClientProvider(_instance).overrideWith((Ref ref) async => client),
    qbitRawTorrentsProvider(_instance).overrideWith(
      (Ref ref) async => <QbitTorrent>[
        _row(server, qbitFixtureHash),
        _row(server, _other),
      ],
    ),
    qbitPropertiesProvider((_instance, qbitFixtureHash)).overrideWith(
      (Ref ref) async => QbitTorrentProperties.fromJson(<String, dynamic>{
        ...torrentPropertiesJson(),
        'save_path': server.savePath(qbitFixtureHash),
      }),
    ),
  ];
}

Future<void> _openDetail(WidgetTester tester, _FakeQbit server) async {
  tester.view.physicalSize = const Size(411, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(server),
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: TorrentDetailScreen(
          instance: _instance,
          torrent: _row(server, qbitFixtureHash),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The Info card's Category row.
Finder get _categoryRow => find
    .ancestor(of: find.text('Category'), matching: find.byType(InkWell))
    .first;

Finder _inRow(String text) =>
    find.descendant(of: _categoryRow, matching: find.text(text));

Finder _option(String label) =>
    find.widgetWithText(SimpleDialogOption, label);

Finder _ticked(String label) =>
    find.descendant(of: _option(label), matching: find.byIcon(Icons.check));

Future<void> _openPicker(WidgetTester tester) async {
  await tester.ensureVisible(_categoryRow);
  await tester.tap(_categoryRow);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(_option(label));
  await tester.pumpAndSettle();
}

void main() {
  group('the detail screen', () {
    testWidgets('shows None for a torrent without a category',
        (WidgetTester tester) async {
      await _openDetail(tester, _FakeQbit(first: ''));
      expect(_inRow('None'), findsOneWidget);
    });

    testWidgets('ticks the current category in the picker',
        (WidgetTester tester) async {
      await _openDetail(tester, _FakeQbit());
      await _openPicker(tester);
      expect(find.text('Set category'), findsOneWidget);
      expect(_ticked('movies'), findsOneWidget);
      expect(_ticked('tv'), findsNothing);
      expect(_ticked('None'), findsNothing);
    });

    testWidgets('ticks None when there is no category',
        (WidgetTester tester) async {
      await _openDetail(tester, _FakeQbit(first: ''));
      await _openPicker(tester);
      expect(_ticked('None'), findsOneWidget);
      expect(_ticked('movies'), findsNothing);
    });

    testWidgets('sets the chosen category and the row follows',
        (WidgetTester tester) async {
      final _FakeQbit server = _FakeQbit();
      await _openDetail(tester, server);
      await _openPicker(tester);
      await _choose(tester, 'tv');
      expect(server.sets, <Map<String, dynamic>>[
        <String, dynamic>{'hashes': qbitFixtureHash, 'category': 'tv'},
      ]);
      expect(_inRow('tv'), findsOneWidget);
    });

    testWidgets('the save path follows a category that moves it',
        (WidgetTester tester) async {
      await _openDetail(tester, _FakeQbit());
      expect(find.text('/data/movies'), findsOneWidget);
      await _openPicker(tester);
      await _choose(tester, 'tv');
      expect(find.text('/data/tv'), findsOneWidget);
      expect(find.text('/data/movies'), findsNothing);
    });

    testWidgets('a refused change says so and keeps the old value',
        (WidgetTester tester) async {
      final _FakeQbit server = _FakeQbit()..failNext = true;
      await _openDetail(tester, server);
      await _openPicker(tester);
      await _choose(tester, 'tv');
      expect(find.text('Could not set category'), findsOneWidget);
      expect(_inRow('movies'), findsOneWidget);
    });

    testWidgets('dismissing the picker changes nothing',
        (WidgetTester tester) async {
      final _FakeQbit server = _FakeQbit();
      await _openDetail(tester, server);
      await _openPicker(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(server.sets, isEmpty);
      expect(_inRow('movies'), findsOneWidget);
    });
  });

  testWidgets('a mixed selection ticks nothing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_FakeQbit(second: 'tv')),
        child: MaterialApp(
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              // Read once so the list is loaded when the picker opens, as it
              // always is behind the list screen's selection.
              ref.watch(qbitRawTorrentsProvider(_instance));
              return TextButton(
                onPressed: () => QbittorrentActionUtils.editCategory(
                  context,
                  ref,
                  _instance,
                  <String>{qbitFixtureHash, _other},
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
