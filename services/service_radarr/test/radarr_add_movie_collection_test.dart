import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }
}

void main() {
  const instance = Instance(
    id: 'radarr-test-1',
    name: 'Radarr Test',
    kind: ServiceKind.radarr,
    localUrl: 'http://localhost:7878',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuthApiKey(apiKey: 'test-key'),
  );

  Widget buildTestHarness({
    required RadarrMovie movie,
    RadarrApi? api,
  }) {
    return ProviderScope(
      overrides: [
        if (api != null) radarrApiProvider(instance).overrideWith((ref) => api),
        radarrRootFoldersProvider(instance).overrideWith((ref) => [
              {'id': 1, 'path': '/movies'},
            ],),
        radarrQualityProfilesProvider(instance).overrideWith((ref) => [
              {'id': 1, 'name': 'HD-1080p'},
            ],),
        radarrTagsProvider(instance).overrideWith((ref) => []),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                // Route 1 (search screen)
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: ElevatedButton(
                        onPressed: () {
                          // Route 2 (sheet)
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => RadarrAddMovieSheet(
                              instance: instance,
                              movie: movie,
                            ),
                          );
                        },
                        child: const Text('Open Sheet'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Search'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
  }

  group('RadarrAddMovieSheet Collection Monitoring', () {
    testWidgets(
        'displays Monitor collection switch when movie has a collection',
        (tester) async {
      const movieWithCollection = RadarrMovie(
        tmdbId: 101,
        title: 'Gladiator II',
        collection: RadarrCollection(
          title: 'Gladiator Collection',
          tmdbId: 1234,
        ),
      );

      await tester.pumpWidget(
        buildTestHarness(movie: movieWithCollection),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('Monitor collection'), findsOneWidget);
      expect(find.text('Gladiator Collection'), findsOneWidget);

      final monitorCollectionSwitchFinder = find.ancestor(
        of: find.text('Monitor collection'),
        matching: find.byType(SwitchListTile),
      );
      expect(monitorCollectionSwitchFinder, findsOneWidget);
      final switchWidget =
          tester.widget<SwitchListTile>(monitorCollectionSwitchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets(
        'does NOT display Monitor collection switch when movie has no collection',
        (tester) async {
      const movieWithoutCollection = RadarrMovie(
        tmdbId: 102,
        title: 'Oppenheimer',
      );

      await tester.pumpWidget(
        buildTestHarness(movie: movieWithoutCollection),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('Monitor collection'), findsNothing);
    });

    testWidgets(
        'submits addOptions with movieAndCollection when Monitor collection is checked',
        (tester) async {
      RequestOptions? recordedAddRequest;
      final dio = Dio();
      dio.httpClientAdapter = _CapturingAdapter((options) async {
        if (options.path.contains('api/v3/movie') && options.method == 'POST') {
          recordedAddRequest = options;
          return ResponseBody.fromString(
            '{"id": 55}',
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '[]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final fakeApi = RadarrApi(dio);

      const movie = RadarrMovie(
        tmdbId: 101,
        title: 'Gladiator II',
        collection: RadarrCollection(
          title: 'Gladiator Collection',
          tmdbId: 1234,
        ),
      );

      await tester.pumpWidget(
        buildTestHarness(movie: movie, api: fakeApi),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      // Toggle Monitor collection switch
      final monitorCollectionSwitchFinder = find.ancestor(
        of: find.text('Monitor collection'),
        matching: find.byType(SwitchListTile),
      );
      await tester.scrollUntilVisible(monitorCollectionSwitchFinder, 100);
      await tester.pumpAndSettle();
      await tester.tap(monitorCollectionSwitchFinder);
      await tester.pumpAndSettle();

      // Tap Add Movie button
      final addMovieButton = find.widgetWithText(FilledButton, 'Add Movie');
      expect(addMovieButton, findsOneWidget);
      await tester.tap(addMovieButton);
      await tester.pumpAndSettle();

      expect(recordedAddRequest, isNotNull);
      final data = recordedAddRequest!.data as Map<String, dynamic>;
      expect(data['monitored'], isTrue);
      final addOptions = data['addOptions'] as Map<String, dynamic>;
      expect(addOptions['monitor'], equals('movieAndCollection'));
    });

    testWidgets(
        'submits addOptions with movieOnly when Monitor collection is unchecked',
        (tester) async {
      RequestOptions? recordedAddRequest;
      final dio = Dio();
      dio.httpClientAdapter = _CapturingAdapter((options) async {
        if (options.path.contains('api/v3/movie') && options.method == 'POST') {
          recordedAddRequest = options;
          return ResponseBody.fromString(
            '{"id": 56}',
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '[]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final fakeApi = RadarrApi(dio);

      const movie = RadarrMovie(
        tmdbId: 101,
        title: 'Gladiator II',
        collection: RadarrCollection(
          title: 'Gladiator Collection',
          tmdbId: 1234,
        ),
      );

      await tester.pumpWidget(
        buildTestHarness(movie: movie, api: fakeApi),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      // Leave Monitor collection unchecked
      final addMovieButton = find.widgetWithText(FilledButton, 'Add Movie');
      await tester.tap(addMovieButton);
      await tester.pumpAndSettle();

      expect(recordedAddRequest, isNotNull);
      final data = recordedAddRequest!.data as Map<String, dynamic>;
      expect(data['monitored'], isTrue);
      final addOptions = data['addOptions'] as Map<String, dynamic>;
      expect(addOptions['monitor'], equals('movieOnly'));
    });
  });
}
