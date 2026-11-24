import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';

RadarrApi _apiFor(String baseUrl) =>
    RadarrApi(Dio(BaseOptions(baseUrl: baseUrl)), apiKey: 'test-key');

void main() {
  group('posterUrl targets the API route, not the web frontend', () {
    test('plain Radarr with no URL Base', () {
      final url = _apiFor('https://example.com/').posterUrl(
        const RadarrImage(
          coverType: 'poster',
          url: '/MediaCover/87/poster.jpg?lastWrite=639',
        ),
      );
      expect(url, contains('/api/v3/mediacover/87/'));
      expect(url, isNot(contains('/MediaCover/')));
    });

    test('Radarr with a URL Base configured (issue #64)', () {
      // With UrlBase set, Radarr prefixes it onto images[].url, so the value
      // arrives as /radarr/MediaCover/... rather than /MediaCover/...
      final url = _apiFor('https://example.com/radarr/').posterUrl(
        const RadarrImage(
          coverType: 'poster',
          url: '/radarr/MediaCover/87/poster.jpg?lastWrite=639',
        ),
      );
      // Must hit the API route; the frontend /MediaCover/ route ignores the
      // api key and 302s to the login page.
      expect(url, isNot(contains('/MediaCover/')));
      expect(url, contains('/radarr/api/v3/mediacover/87/'));
    });

    test('width resizing still applies with a URL Base', () {
      final url = _apiFor('https://example.com/radarr/').posterUrl(
        const RadarrImage(
          coverType: 'poster',
          url: '/radarr/MediaCover/87/poster.jpg?lastWrite=639',
        ),
        width: 500,
      );
      expect(url, contains('poster-500.jpg'));
      expect(url, contains('/radarr/api/v3/mediacover/87/'));
    });
  });

  test('the api key stays out of the url', () {
    // A reverse proxy writes the full request line to its access log, so a
    // key in the query ends up there. Artwork sends it as a header instead,
    // from ArtworkHeaders in core_ui.
    final String? url = _apiFor('https://example.com/').posterUrl(
      const RadarrImage(
        coverType: 'poster',
        url: '/MediaCover/87/poster.jpg?lastWrite=639',
      ),
    );
    expect(
      url,
      'https://example.com/api/v3/mediacover/87/poster-500.jpg?lastWrite=639',
    );
  });
}
