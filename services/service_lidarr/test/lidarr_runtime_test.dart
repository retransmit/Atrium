import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

void main() {
  group('Lidarr Runtime Foundation Tests', () {
    test('LidarrApi constructor and Raw*Api aggregation', () {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8686/'));
      final api = LidarrApi(dio);

      expect(api.dio, same(dio));
      expect(api.artist, isA<RawArtistApi>());
      expect(api.album, isA<RawAlbumApi>());
      expect(api.track, isA<RawTrackApi>());
      expect(api.queue, isA<RawQueueApi>());
      expect(api.history, isA<RawHistoryApi>());
      expect(api.blocklist, isA<RawBlocklistApi>());
      expect(api.system, isA<RawSystemApi>());
      expect(api.rootFolder, isA<RawRootFolderApi>());
      expect(api.qualityProfile, isA<RawQualityProfileApi>());
      expect(api.metadataProfile, isA<RawMetadataProfileApi>());
      expect(api.tag, isA<RawTagApi>());
    });

    test('lidarrApiProvider wiring via instanceDioProvider', () async {
      const instance = Instance(
        id: 'lidarr-instance-1',
        name: 'My Lidarr',
        kind: ServiceKind.lidarr,
        localUrl: 'http://192.168.1.100:8686',
        externalUrl: 'https://lidarr.example.com',
        urlMode: UrlMode.auto,
        auth: InstanceAuthApiKey(apiKey: 'secret-api-key'),
      );

      final mockDio = Dio(BaseOptions(baseUrl: 'http://192.168.1.100:8686/'));

      final container = ProviderContainer(
        overrides: [
          instanceDioProvider(instance).overrideWith((ref) async => mockDio),
        ],
      );
      addTearDown(container.dispose);

      final api = await container.read(lidarrApiProvider(instance).future);

      expect(api, isA<LidarrApi>());
      expect(api.dio, same(mockDio));
      expect(api.artist, isA<RawArtistApi>());
    });

    test('Instance isolation in lidarrApiProvider', () async {
      const instanceA = Instance(
        id: 'lidarr-instance-a',
        name: 'Lidarr A',
        kind: ServiceKind.lidarr,
        localUrl: 'http://192.168.1.101:8686',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: InstanceAuthApiKey(apiKey: 'key-a'),
      );

      const instanceB = Instance(
        id: 'lidarr-instance-b',
        name: 'Lidarr B',
        kind: ServiceKind.lidarr,
        localUrl: 'http://192.168.1.102:8686',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: InstanceAuthApiKey(apiKey: 'key-b'),
      );

      final mockDioA = Dio(BaseOptions(baseUrl: 'http://192.168.1.101:8686/'));
      final mockDioB = Dio(BaseOptions(baseUrl: 'http://192.168.1.102:8686/'));

      final container = ProviderContainer(
        overrides: [
          instanceDioProvider(instanceA).overrideWith((ref) async => mockDioA),
          instanceDioProvider(instanceB).overrideWith((ref) async => mockDioB),
        ],
      );
      addTearDown(container.dispose);

      final apiA = await container.read(lidarrApiProvider(instanceA).future);
      final apiB = await container.read(lidarrApiProvider(instanceB).future);

      expect(apiA, isNot(same(apiB)));
      expect(apiA.dio, same(mockDioA));
      expect(apiB.dio, same(mockDioB));
      expect(apiA.dio.options.baseUrl, equals('http://192.168.1.101:8686/'));
      expect(apiB.dio.options.baseUrl, equals('http://192.168.1.102:8686/'));
    });

    test('LidarrArtwork builds correct API routes and scales width', () {
      const instance = Instance(
        id: 'lidarr-instance-1',
        name: 'My Lidarr',
        kind: ServiceKind.lidarr,
        localUrl: 'https://lidarr.kurai.cloud',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: InstanceAuthApiKey(apiKey: 'my-api-key'),
      );

      final images = [
        const MediaCover(
          coverType: MediaCoverTypes.poster,
          url: '/MediaCover/5/poster.jpg?lastWrite=639210363806026257',
          remoteUrl: '/config/MediaCover/5/poster.jpg',
        ),
        const MediaCover(
          coverType: MediaCoverTypes.fanart,
          url: '/MediaCover/5/fanart.jpg?lastWrite=639204000912296918',
        ),
        const MediaCover(
          coverType: MediaCoverTypes.cover,
          url: '/MediaCover/Albums/30/cover.jpg?lastWrite=639223812709425181',
        ),
      ];

      // 1. Artist Poster URL defaults to 250px thumbnail and translates /MediaCover/
      final posterUrl = LidarrArtwork.artistPosterUrl(instance, images);
      expect(
        posterUrl,
        equals(
          'https://lidarr.kurai.cloud/api/v1/mediacover/artist/5/poster-250.jpg?lastWrite=639210363806026257&apikey=my-api-key',
        ),
      );

      // 2. Explicit width: null generates full resolution URL
      final posterFullUrl =
          LidarrArtwork.artistPosterUrl(instance, images, width: null);
      expect(
        posterFullUrl,
        equals(
          'https://lidarr.kurai.cloud/api/v1/mediacover/artist/5/poster.jpg?lastWrite=639210363806026257&apikey=my-api-key',
        ),
      );

      // 3. Album Cover URL translates /MediaCover/Albums/ and defaults to 250px thumbnail
      final albumUrl = LidarrArtwork.albumCoverUrl(instance, images);
      expect(
        albumUrl,
        equals(
          'https://lidarr.kurai.cloud/api/v1/mediacover/album/30/cover-250.jpg?lastWrite=639223812709425181&apikey=my-api-key',
        ),
      );

      // 4. Subpath base URL handling
      const subpathInstance = Instance(
        id: 'lidarr-subpath',
        name: 'Lidarr Subpath',
        kind: ServiceKind.lidarr,
        localUrl: 'http://192.168.1.100:8686/lidarr',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: InstanceAuthApiKey(apiKey: 'key'),
      );
      final subpathUrl = LidarrArtwork.artistPosterUrl(subpathInstance, images);
      expect(
        subpathUrl,
        equals(
          'http://192.168.1.100:8686/lidarr/api/v1/mediacover/artist/5/poster-250.jpg?lastWrite=639210363806026257&apikey=key',
        ),
      );
    });
  });
}
