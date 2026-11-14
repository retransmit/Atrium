import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_sonarr/service_sonarr.dart';

/// Issue #234: the add sheet starts from the last choices on this instance.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 201});

  final int status;
  Map<String, dynamic>? posted;

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
  id: 'sonarr-choices-1',
  name: 'Sonarr Test',
  kind: ServiceKind.sonarr,
  localUrl: 'http://localhost:8989',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'test-key'),
);

Future<void> _open(WidgetTester tester, _Adapter adapter) async {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sonarrApiProvider(_instance).overrideWith((ref) => SonarrApi(dio)),
        sonarrRootFoldersProvider(_instance).overrideWith(
          (ref) => <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'path': '/tv'},
            <String, dynamic>{'id': 2, 'path': '/anime'},
          ],
        ),
        sonarrQualityProfilesProvider(_instance).overrideWith(
          (ref) => <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'name': 'HD-1080p'},
            <String, dynamic>{'id': 2, 'name': 'Ultra-HD'},
          ],
        ),
        sonarrTagsProvider(_instance)
            .overrideWith((ref) => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SonarrAddSeriesSheet(
                  instance: _instance,
                  series: SonarrSeries(title: 'Severance', tvdbId: 371980),
                ),
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
  final Finder add = find.widgetWithText(FilledButton, 'Add Series');
  await tester.scrollUntilVisible(add, 100);
  await tester.pumpAndSettle();
  await tester.tap(add);
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
    AddChoices.write('sonarr', _instance.id, <String, Object?>{
      'rootFolderPath': '/anime',
      'qualityProfileId': 2,
      'monitor': 'future',
      'seriesType': 'anime',
      'seasonFolder': false,
      'searchForMissing': true,
      'searchForCutoffUnmet': true,
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    final Map<String, dynamic> body = adapter.posted!;
    expect(body['rootFolderPath'], '/anime');
    expect(body['qualityProfileId'], 2);
    expect(body['seriesType'], 'anime');
    expect(body['seasonFolder'], isFalse);
    expect(_options(body)['monitor'], 'future');
    expect(_options(body)['searchForMissingEpisodes'], isTrue);
    expect(_options(body)['searchForCutoffUnmetEpisodes'], isTrue);
  });

  testWidgets('a deleted folder or profile falls back',
      (WidgetTester tester) async {
    AddChoices.write('sonarr', _instance.id, <String, Object?>{
      'rootFolderPath': '/gone',
      'qualityProfileId': 99,
      'seriesType': 'daily',
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    final Map<String, dynamic> body = adapter.posted!;
    expect(body['rootFolderPath'], '/tv');
    expect(body['qualityProfileId'], 1);
    expect(body['seriesType'], 'daily');
  });

  testWidgets('a wrong-typed or unknown value is ignored',
      (WidgetTester tester) async {
    AddChoices.write('sonarr', _instance.id, <String, Object?>{
      'monitor': 'sometimes',
      'seriesType': 3,
      'seasonFolder': 'no',
    });
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await _add(tester);

    final Map<String, dynamic> body = adapter.posted!;
    expect(_options(body)['monitor'], 'all');
    expect(body['seriesType'], 'standard');
    expect(body['seasonFolder'], isTrue);
  });

  testWidgets('saves what was picked after a successful add',
      (WidgetTester tester) async {
    final _Adapter adapter = _Adapter();
    await _open(tester, adapter);
    await tester.tap(find.text('HD-1080p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ultra-HD').last);
    await tester.pumpAndSettle();
    await _flip(tester, 'Season Folder');
    await _add(tester);

    expect(adapter.posted!['qualityProfileId'], 2);
    final Map<String, Object?> saved =
        AddChoices.read('sonarr', _instance.id)!;
    expect(saved, <String, Object?>{
      'rootFolderPath': '/tv',
      'qualityProfileId': 2,
      'monitor': 'all',
      'seriesType': 'standard',
      'seasonFolder': false,
      'searchForMissing': false,
      'searchForCutoffUnmet': false,
    });
  });

  testWidgets('a failed add remembers nothing', (WidgetTester tester) async {
    final _Adapter adapter = _Adapter(status: 500);
    await _open(tester, adapter);
    await _add(tester);

    expect(adapter.posted, isNotNull);
    expect(AddChoices.read('sonarr', _instance.id), isNull);
  });
}
