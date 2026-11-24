import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

void main() {
  PlexApi api(String baseUrl) =>
      PlexApi(Dio(BaseOptions(baseUrl: baseUrl)), token: 'plex-secret');

  test('a poster url is the thumb under the resolved address', () {
    expect(
      api('http://192.168.0.10:32400/').imageUrl('/library/metadata/7/thumb/9'),
      'http://192.168.0.10:32400/library/metadata/7/thumb/9',
    );
  });

  test('the token stays out of the url', () {
    // A reverse proxy writes the full request line to its access log.
    // Artwork carries the token as an X-Plex-Token header instead, from
    // ArtworkHeaders in core_ui.
    expect(
      api('https://plex.example.org').imageUrl('/library/metadata/7/art/9'),
      isNot(contains('plex-secret')),
    );
  });

  test('no thumb, no url', () {
    expect(api('http://192.168.0.10:32400').imageUrl(null), isNull);
    expect(api('http://192.168.0.10:32400').imageUrl(''), isNull);
  });
}
