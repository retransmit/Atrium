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

  group('MovieDetailScreen Collection Section', () {
    testWidgets(
        'renders collection card and monitored button when movie has a collection',
        (tester) async {
      const movie = RadarrMovie(
        id: 10,
        tmdbId: 101,
        title: 'Gladiator II',
        monitored: true,
        collection: RadarrCollection(
          id: 5,
          title: 'Gladiator Collection',
          tmdbId: 1234,
          monitored: true,
        ),
      );

      const collectionDetails = RadarrCollection(
        id: 5,
        title: 'Gladiator Collection',
        tmdbId: 1234,
        monitored: true,
        overview: 'Films set in ancient Rome.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrMovieByIdProvider((instance, 10))
                .overrideWith((ref) => movie),
            radarrCollectionByTmdbIdProvider((instance, 1234))
                .overrideWith((ref) => collectionDetails),
          ],
          child: const MaterialApp(
            home: MovieDetailScreen(
              instance: instance,
              movieId: 10,
              movie: movie,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Gladiator Collection'), findsOneWidget);
      expect(find.text('Films set in ancient Rome.'), findsOneWidget);
      expect(find.text('Collection monitored'), findsOneWidget);
    });

    testWidgets(
        'renders collection card with unmonitored button when collection is unmonitored',
        (tester) async {
      const movie = RadarrMovie(
        id: 10,
        tmdbId: 101,
        title: 'Gladiator II',
        monitored: true,
        collection: RadarrCollection(
          id: 5,
          title: 'Gladiator Collection',
          tmdbId: 1234,
        ),
      );

      const collectionDetails = RadarrCollection(
        id: 5,
        title: 'Gladiator Collection',
        tmdbId: 1234,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrMovieByIdProvider((instance, 10))
                .overrideWith((ref) => movie),
            radarrCollectionByTmdbIdProvider((instance, 1234))
                .overrideWith((ref) => collectionDetails),
          ],
          child: const MaterialApp(
            home: MovieDetailScreen(
              instance: instance,
              movieId: 10,
              movie: movie,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Gladiator Collection'), findsOneWidget);
      expect(find.text('Collection unmonitored'), findsOneWidget);
    });

    testWidgets(
        'does not render collection card when movie has no collection',
        (tester) async {
      const movie = RadarrMovie(
        id: 11,
        tmdbId: 102,
        title: 'Interstellar',
        monitored: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrMovieByIdProvider((instance, 11))
                .overrideWith((ref) => movie),
          ],
          child: const MaterialApp(
            home: MovieDetailScreen(
              instance: instance,
              movieId: 11,
              movie: movie,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collection'), findsNothing);
    });

    testWidgets(
        'tapping collection toggle invokes updateCollectionMonitoring with inverted state',
        (tester) async {
      RequestOptions? recordedPutRequest;
      final dio = Dio();
      dio.httpClientAdapter = _CapturingAdapter((options) async {
        if (options.path.contains('api/v3/collection') &&
            options.method == 'PUT') {
          recordedPutRequest = options;
          return ResponseBody.fromString(
            '{}',
            202,
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
        id: 10,
        tmdbId: 101,
        title: 'Gladiator II',
        monitored: true,
        collection: RadarrCollection(
          id: 5,
          title: 'Gladiator Collection',
          tmdbId: 1234,
        ),
      );

      const collectionDetails = RadarrCollection(
        id: 5,
        title: 'Gladiator Collection',
        tmdbId: 1234,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrApiProvider(instance).overrideWith((ref) => fakeApi),
            radarrMovieByIdProvider((instance, 10))
                .overrideWith((ref) => movie),
            radarrCollectionByTmdbIdProvider((instance, 1234))
                .overrideWith((ref) => collectionDetails),
          ],
          child: const MaterialApp(
            home: MovieDetailScreen(
              instance: instance,
              movieId: 10,
              movie: movie,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final toggleButton =
          find.widgetWithText(OutlinedButton, 'Collection unmonitored');
      expect(toggleButton, findsOneWidget);

      await tester.scrollUntilVisible(toggleButton, 100);
      await tester.pumpAndSettle();

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(recordedPutRequest, isNotNull);
      expect(recordedPutRequest!.method, equals('PUT'));
      expect(recordedPutRequest!.path, equals('api/v3/collection'));
      final data = recordedPutRequest!.data as Map<String, dynamic>;
      expect(data['collectionIds'], equals([5]));
      expect(data['monitored'], isTrue);
    });
  });
}
