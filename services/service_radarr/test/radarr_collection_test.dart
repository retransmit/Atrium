import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);
}

void main() {
  group('RadarrCollection Model', () {
    test('deserializes minimal collection from movie JSON with defaults', () {
      final json = <String, dynamic>{
        'title': 'The Matrix Collection',
        'tmdbId': 2344,
      };

      final collection = RadarrCollection.fromJson(json);

      expect(collection.id, equals(0));
      expect(collection.title, equals('The Matrix Collection'));
      expect(collection.tmdbId, equals(2344));
      expect(collection.monitored, isFalse);
      expect(collection.images, isEmpty);
      expect(collection.overview, isNull);
      expect(collection.rootFolderPath, isNull);
      expect(collection.qualityProfileId, isNull);
      expect(collection.searchOnAdd, isFalse);
      expect(collection.minimumAvailability, isNull);
      expect(collection.missingMovies, equals(0));
    });

    test('deserializes full collection from /collection endpoint', () {
      final json = <String, dynamic>{
        'id': 12,
        'title': 'Gladiator Collection',
        'tmdbId': 5678,
        'monitored': true,
        'overview': 'The epic historical drama films.',
        'rootFolderPath': '/data/movies',
        'qualityProfileId': 1,
        'searchOnAdd': true,
        'minimumAvailability': 'released',
        'missingMovies': 1,
        'images': <Map<String, dynamic>>[
          <String, dynamic>{
            'coverType': 'poster',
            'url': '/MediaCover/12/poster.jpg',
          },
        ],
      };

      final collection = RadarrCollection.fromJson(json);

      expect(collection.id, equals(12));
      expect(collection.title, equals('Gladiator Collection'));
      expect(collection.tmdbId, equals(5678));
      expect(collection.monitored, isTrue);
      expect(collection.overview, equals('The epic historical drama films.'));
      expect(collection.rootFolderPath, equals('/data/movies'));
      expect(collection.qualityProfileId, equals(1));
      expect(collection.searchOnAdd, isTrue);
      expect(collection.minimumAvailability, equals('released'));
      expect(collection.missingMovies, equals(1));
      expect(collection.images.length, equals(1));
      expect(collection.images.first.coverType, equals('poster'));
    });
  });

  group('RadarrApi Collection Methods', () {
    test('getCollectionByTmdbId sends query and returns collection', () async {
      RequestOptions? recordedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          '''
          [
            {
              "id": 42,
              "title": "Dune Collection",
              "tmdbId": 724495,
              "monitored": true
            }
          ]
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final api = RadarrApi(dio);
      final collection = await api.getCollectionByTmdbId(724495);

      expect(recordedOptions?.path, equals('api/v3/collection'));
      expect(recordedOptions?.queryParameters['tmdbId'], equals(724495));
      expect(collection, isNotNull);
      expect(collection!.id, equals(42));
      expect(collection.title, equals('Dune Collection'));
      expect(collection.monitored, isTrue);
    });

    test('getCollectionByTmdbId returns null if no collection found', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        return ResponseBody.fromString(
          '[]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final api = RadarrApi(dio);
      final collection = await api.getCollectionByTmdbId(999999);

      expect(collection, isNull);
    });

    test('updateCollectionMonitoring sends PUT to /collection', () async {
      RequestOptions? recordedOptions;
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          '{}',
          202,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final api = RadarrApi(dio);
      await api.updateCollectionMonitoring(42, monitored: true);

      expect(recordedOptions?.method, equals('PUT'));
      expect(recordedOptions?.path, equals('api/v3/collection'));
      expect(
        recordedOptions?.data,
        equals(<String, dynamic>{
          'collectionIds': <int>[42],
          'monitored': true,
        }),
      );
    });
  });
}
