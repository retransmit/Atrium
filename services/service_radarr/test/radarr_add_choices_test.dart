import 'dart:async';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';

/// Issue #234: the add sheet starts from the last choices on this instance.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 201});

  final int status;
  Map<String, dynamic>? posted;

  /// Holds the add request open until completed.
  Completer<void>? gate;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bool post = options.method == 'POST';
    if (post) posted = options.data as Map<String, dynamic>;
    if (post) await gate?.future;
    return ResponseBody.fromString(
      post ? '{"id": 9}' : '[]',
      post ? status : 200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

const Instance _instance = Instance(
  id: 'radarr-choices-1',
  name: 'Radarr Test',
  kind: ServiceKind.radarr,
  localUrl: 'http://localhost:7878',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'test-key'),
);

const RadarrMovie _withCollection = RadarrMovie(
  tmdbId: 101,
  title: 'Gladiator II',
  collection: RadarrCollection(title: 'Gladiator Collection', tmdbId: 1234),
);

Future<void> _open(
  WidgetTester tester,
  _Adapter adapter, {
  RadarrMovie movie = _withCollection,
}) async {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        radarrApiProvider(_instance).overrideWith((ref) => RadarrApi(dio)),
        radarrRootFoldersProvider(_instance).overrideWith(
          (ref) => <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'path': '/movies'},
            <String, dynamic>{'id': 2, 'path': '/4k'},
          ],
        ),
        radarrQualityProfilesProvider(_instance).overrideWith(
          (ref) => <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'name': 'HD-1080p'},
            <String, dynamic>{'id': 2, 'name': 'Ultra-HD'},
          ],
        ),
        radarrTagsProvider(_instance)
            .overrideWith((ref) => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    RadarrAddMovieSheet(instance: _instance, movie: movie),
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

Future<void> _add(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add Movie'));
  await tester.pumpAndSettle();
}

Future<void> _flip(WidgetTester tester, String title) async {
  final Finder tile = find.widgetWithText(SwitchListTile, title);
  await tester.scrollUntilVisible(tile, 100);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _options(Map<String, dynamic> body) =>
    body['addOptions'] as Map<String, dynamic>;

void main() {
  late Box<String> box;

  // In memory: a file-backed box queues its disk writes on the widget test's
  // fake clock, and closing it then waits forever.
  setUp(() async {
    box = await Hive.openBox<String>(
      AtriumBoxes.settings,
      bytes: Uint8List(0),
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets('opens with the choices last used on this instance',
      (WidgetTester tester) async {
    AddChoices.write('radarr', _instance.id, <String, Object?>{
      'rootFolderPath': '/4k',
      'qualityProfileId': 2,
      'monitored': true,
      'monitorCollection': true,
      'minimumAvailability': 'released',
      'searchForMovie': true,
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    final Map<String, dynamic> body = adapter.posted!;
    expect(body['rootFolderPath'], '/4k');
    expect(body['qualityProfileId'], 2);
    expect(body['minimumAvailability'], 'released');
    expect(_options(body)['searchForMovie'], isTrue);
    expect(_options(body)['monitor'], 'movieAndCollection');
  });

  testWidgets('a remembered collection choice does not apply to a lone movie',
      (WidgetTester tester) async {
    AddChoices.write('radarr', _instance.id, <String, Object?>{
      'monitored': true,
      'monitorCollection': true,
    });
    final _Adapter adapter = _Adapter();
    await _open(
      tester,
      adapter,
      movie: const RadarrMovie(tmdbId: 102, title: 'Oppenheimer'),
    );
    await _add(tester);

    expect(_options(adapter.posted!)['monitor'], 'movieOnly');
  });

  testWidgets('a deleted folder or profile falls back',
      (WidgetTester tester) async {
    AddChoices.write('radarr', _instance.id, <String, Object?>{
      'rootFolderPath': '/gone',
      'qualityProfileId': 99,
      'searchForMovie': true,
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    final Map<String, dynamic> body = adapter.posted!;
    expect(body['rootFolderPath'], '/movies');
    expect(body['qualityProfileId'], 1);
    expect(_options(body)['searchForMovie'], isTrue);
  });

  testWidgets('a wrong-typed or unknown value is ignored',
      (WidgetTester tester) async {
    AddChoices.write('radarr', _instance.id, <String, Object?>{
      'searchForMovie': 'yes',
      'minimumAvailability': 'tba',
      'monitored': 0,
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    final Map<String, dynamic> body = adapter.posted!;
    expect(_options(body)['searchForMovie'], isFalse);
    expect(body['minimumAvailability'], 'announced');
    expect(body['monitored'], isTrue);
  });

  testWidgets('a profile id saved as a decimal falls back',
      (WidgetTester tester) async {
    AddChoices.write('radarr', _instance.id, <String, Object?>{
      'qualityProfileId': 2.0,
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    expect(adapter.posted!['qualityProfileId'], 1);
  });

  testWidgets('saves what was sent, not a change made while adding',
      (WidgetTester tester) async {
    final _Adapter adapter = _Adapter()..gate = Completer<void>();
    await _open(tester, adapter);
    await tester.tap(find.widgetWithText(FilledButton, 'Add Movie'));
    for (int i = 0; i < 50 && adapter.posted == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(adapter.posted, isNotNull);

    final Finder tile =
        find.widgetWithText(SwitchListTile, 'Start search for movie');
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    adapter.gate!.complete();
    await tester.pumpAndSettle();

    expect(_options(adapter.posted!)['searchForMovie'], isFalse);
    expect(
      AddChoices.read('radarr', _instance.id)!['searchForMovie'],
      isFalse,
    );
  });

  testWidgets('saves what was picked after a successful add',
      (WidgetTester tester) async {
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await tester.tap(find.text('HD-1080p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ultra-HD').last);
    await tester.pumpAndSettle();
    await _flip(tester, 'Start search for movie');
    await _add(tester);

    expect(adapter.posted!['qualityProfileId'], 2);
    final Map<String, Object?> saved =
        AddChoices.read('radarr', _instance.id)!;
    expect(saved['rootFolderPath'], '/movies');
    expect(saved['qualityProfileId'], 2);
    expect(saved['searchForMovie'], isTrue);
    expect(saved['monitored'], isTrue);
    expect(saved['monitorCollection'], isFalse);
    expect(saved['minimumAvailability'], 'announced');
    expect(saved.containsKey('tags'), isFalse);
  });

  testWidgets('a failed add remembers nothing', (WidgetTester tester) async {
    final _Adapter adapter = _Adapter(status: 500);
    await _open(tester, adapter);
    await _add(tester);

    expect(adapter.posted, isNotNull);
    expect(AddChoices.read('radarr', _instance.id), isNull);
  });
}
