import 'dart:typed_data';

import 'package:atrium/src/share_intake/letterboxd.dart';
import 'package:atrium/src/share_intake/title_share.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const String _filmPage = '<html><body class="film" data-tmdb-id="860" '
    'data-tmdb-type="movie"><h1>WarGames</h1></body></html>';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }
}

void main() {
  group('parseLetterboxdFilmPage', () {
    test('reads a film page', () {
      expect(
        parseLetterboxdFilmPage(_filmPage),
        (tmdbId: 860, kind: TitleKind.movie),
      );
    });

    test('reads a TV page', () {
      expect(
        parseLetterboxdFilmPage(
          '<body data-tmdb-type="tv" data-tmdb-id="1396">',
        ),
        (tmdbId: 1396, kind: TitleKind.show),
      );
    });

    test('null without the attributes', () {
      expect(parseLetterboxdFilmPage('<html></html>'), isNull);
    });

    test('null for an unknown type', () {
      expect(
        parseLetterboxdFilmPage(
          '<body data-tmdb-id="5" data-tmdb-type="person">',
        ),
        isNull,
      );
    });
  });

  group('readLetterboxdFilm', () {
    test('returns null on a network error', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _Adapter(
          (RequestOptions o) async => throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          ),
        );
      expect(
        await readLetterboxdFilm(dio, Uri.parse('https://boxd.it/29qU')),
        isNull,
      );
    });

    test('parses the fetched page', () async {
      final _Adapter adapter = _Adapter(
        (RequestOptions o) async => ResponseBody.fromString(
          _filmPage,
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
          },
        ),
      );
      final Dio dio = Dio()..httpClientAdapter = adapter;
      expect(
        await readLetterboxdFilm(dio, Uri.parse('https://boxd.it/29qU')),
        (tmdbId: 860, kind: TitleKind.movie),
      );
      expect(adapter.requests.single.uri.host, 'boxd.it');
      expect(adapter.requests.single.followRedirects, isTrue);
    });
  });
}
