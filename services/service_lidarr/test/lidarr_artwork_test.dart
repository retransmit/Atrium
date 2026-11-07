import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Artwork URLs for a Lidarr reached at [local] at home and [external] away,
/// with the image paths Lidarr hands out when its URL Base is `/lidarr`.
Instance _lidarr({
  String local = 'http://192.168.1.10:8686/lidarr',
  String external = 'https://domain.tld/lidarr',
  UrlMode mode = UrlMode.auto,
  InstanceAuth auth = const InstanceAuth.apiKey(apiKey: 'k'),
}) =>
    Instance(
      id: 'lidarr',
      name: 'Lidarr',
      kind: ServiceKind.lidarr,
      localUrl: local,
      externalUrl: external,
      urlMode: mode,
      auth: auth,
    );

const MediaCover _artistPoster = MediaCover(
  coverType: MediaCoverTypes.poster,
  url: '/lidarr/MediaCover/5/poster.jpg?lastWrite=639210363806026257',
  remoteUrl: 'https://assets.fanart.tv/fanart/music/x/artistthumb/a.jpg',
);

const MediaCover _albumCover = MediaCover(
  coverType: MediaCoverTypes.cover,
  url: '/lidarr/MediaCover/Albums/30/cover.jpg?lastWrite=639223812709425181',
  remoteUrl: 'https://coverartarchive.org/release/x/1-500.jpg',
);

/// Art Lidarr has not cached yet, which it hands out through its web proxy.
const MediaCover _proxiedCover = MediaCover(
  coverType: MediaCoverTypes.cover,
  url: '/lidarr/MediaCoverProxy/0a1b2c/1-500.jpg',
  remoteUrl: 'https://coverartarchive.org/release/y/1-500.jpg',
);

void main() {
  setUp(LidarrArtwork.forgetBaseUrls);

  group('with a URL Base', () {
    test('an artist poster goes to the API route, without the base twice',
        () {
      final String? url = LidarrArtwork.artistPosterUrl(
        _lidarr(),
        <MediaCover>[_artistPoster],
      );
      expect(
        url,
        'http://192.168.1.10:8686/lidarr/api/v1/mediacover/artist/5/'
        'poster-250.jpg?lastWrite=639210363806026257&apikey=k',
      );
      expect(url, isNot(contains('/lidarr/lidarr/')));
      expect(url, isNot(contains('/MediaCover/')));
    });

    test('an album cover goes to the album API route', () {
      expect(
        LidarrArtwork.albumCoverUrl(_lidarr(), <MediaCover>[_albumCover]),
        'http://192.168.1.10:8686/lidarr/api/v1/mediacover/album/30/'
        'cover-250.jpg?lastWrite=639223812709425181&apikey=k',
      );
    });

    test('uncached art comes from where Lidarr got it, not its web proxy', () {
      expect(
        LidarrArtwork.albumCoverUrl(_lidarr(), <MediaCover>[_proxiedCover]),
        _proxiedCover.remoteUrl,
      );
    });

    test('uncached art with no source keeps its own path, base once', () {
      final String? url = LidarrArtwork.albumCoverUrl(
        _lidarr(),
        <MediaCover>[
          const MediaCover(
            coverType: MediaCoverTypes.cover,
            url: '/lidarr/MediaCoverProxy/0a1b2c/1-500.jpg',
          ),
        ],
      );
      expect(
        url,
        'http://192.168.1.10:8686/lidarr/MediaCoverProxy/0a1b2c/1-500.jpg'
        '?apikey=k',
      );
    });
  });

  group('the address', () {
    test('follows the URL the connection resolved to', () {
      // Away from home the app talks to the external URL, so the art must
      // come from there too, not from a LAN address the phone cannot reach.
      final Instance instance = _lidarr();
      LidarrArtwork.rememberBaseUrl(instance, 'https://domain.tld/lidarr/');

      expect(
        LidarrArtwork.albumCoverUrl(instance, <MediaCover>[_albumCover]),
        startsWith('https://domain.tld/lidarr/api/v1/mediacover/album/30/'),
      );
    });

    test('before any connection, follows a forced external URL', () {
      expect(
        LidarrArtwork.albumCoverUrl(
          _lidarr(mode: UrlMode.forceExternal),
          <MediaCover>[_albumCover],
        ),
        startsWith('https://domain.tld/lidarr/api/v1/'),
      );
    });

    test('before any connection, falls back to the external URL alone', () {
      expect(
        LidarrArtwork.albumCoverUrl(
          _lidarr(local: ''),
          <MediaCover>[_albumCover],
        ),
        startsWith('https://domain.tld/lidarr/api/v1/'),
      );
    });

    test('is the one the API provider connected to', () async {
      final Instance instance = _lidarr();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          instanceDioProvider(instance).overrideWith(
            (Ref ref) async =>
                Dio(BaseOptions(baseUrl: 'https://domain.tld/lidarr/')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(lidarrApiProvider(instance).future);

      expect(
        LidarrArtwork.albumCoverUrl(instance, <MediaCover>[_albumCover]),
        startsWith('https://domain.tld/lidarr/api/v1/mediacover/album/30/'),
      );
    });

    test('is not taken from before the instance was edited', () {
      LidarrArtwork.rememberBaseUrl(_lidarr(), 'https://domain.tld/lidarr/');

      expect(
        LidarrArtwork.albumCoverUrl(
          _lidarr(local: 'http://192.168.1.20:8686/lidarr', external: ''),
          <MediaCover>[_albumCover],
        ),
        startsWith('http://192.168.1.20:8686/lidarr/api/v1/'),
      );
    });

    test('with external forced but no external URL, falls back to local', () {
      expect(
        LidarrArtwork.albumCoverUrl(
          _lidarr(mode: UrlMode.forceExternal, external: ''),
          <MediaCover>[_albumCover],
        ),
        startsWith('http://192.168.1.10:8686/lidarr/api/v1/'),
      );
    });

    test('is kept per instance', () {
      LidarrArtwork.rememberBaseUrl(
        _lidarr().copyWith(id: 'other'),
        'https://other.tld/',
      );
      expect(
        LidarrArtwork.albumCoverUrl(_lidarr(), <MediaCover>[_albumCover]),
        startsWith('http://192.168.1.10:8686/lidarr/'),
      );
    });
  });

  test('a Lidarr at the root still works', () {
    expect(
      LidarrArtwork.artistPosterUrl(
        _lidarr(local: 'https://lidarr.example.org'),
        <MediaCover>[
          const MediaCover(
            coverType: MediaCoverTypes.poster,
            url: '/MediaCover/5/poster.jpg',
          ),
        ],
        width: null,
      ),
      'https://lidarr.example.org/api/v1/mediacover/artist/5/poster.jpg'
      '?apikey=k',
    );
  });
}
