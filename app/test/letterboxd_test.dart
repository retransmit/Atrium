import 'dart:typed_data';

import 'package:atrium/src/share_intake/letterboxd.dart';
import 'package:atrium/src/share_intake/title_share.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const String _filmPage = '<html><body class="film" data-tmdb-id="860" '
    'data-tmdb-type="movie"><h1>WarGames</h1></body></html>';

/// The film's own IMDb and TMDB buttons, as Letterboxd writes them.
String _buttons(String imdb, String tmdb) =>
    '<a href="http://www.imdb.com/title/$imdb/maindetails" '
    'class="micro-button track-event" data-track-action="IMDb" '
    'target="_blank" >IMDb</a> <a href="https://www.themoviedb.org/$tmdb/" '
    'class="micro-button track-event" data-track-action="TMDB" '
    'target="_blank" >TMDB</a>';

/// The footer credit every page carries, a TMDB link that is no film.
const String _footer = '<a href="https://letterboxd.com/about/film-data/" '
    'class="mute">Film data</a> from <a href="https://www.themoviedb.org" '
    'class="mute">TMDB</a>.';

/// A page as Letterboxd serves it: the body tags, the buttons, the footer.
String _page(String bodyTags, String buttons) =>
    '<html><body class="film backdropped" data-type="film" $bodyTags>'
    '$buttons$_footer</body></html>';

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
        (tmdbId: 860, imdbId: null, kind: TitleKind.movie),
      );
    });

    test('reads a TV page', () {
      expect(
        parseLetterboxdFilmPage(
          '<body data-tmdb-type="tv" data-tmdb-id="1396">',
        ),
        (tmdbId: 1396, imdbId: null, kind: TitleKind.show),
      );
    });

    test('a movie page is read from its buttons', () {
      expect(
        parseLetterboxdFilmPage(
          _page(
            'data-tmdb-type="movie" data-tmdb-id="550"',
            _buttons('tt0137523', 'movie/550'),
          ),
        ),
        (tmdbId: 550, imdbId: 'tt0137523', kind: TitleKind.movie),
      );
    });

    // Chernobyl: Letterboxd tags the page a movie and leaves the ID empty,
    // but its TMDB button links the show.
    test('a show tagged as a movie with no ID is read from its buttons', () {
      expect(
        parseLetterboxdFilmPage(
          _page(
            'data-tmdb-type="movie" data-tmdb-id=""',
            _buttons('tt7366338', 'tv/87108'),
          ),
        ),
        (tmdbId: 87108, imdbId: 'tt7366338', kind: TitleKind.show),
      );
    });

    // Band of Brothers: the page's ID tag names a movie Radarr cannot find;
    // the TMDB button names the show.
    test('a show whose ID tag names a movie follows the TMDB button', () {
      expect(
        parseLetterboxdFilmPage(
          _page(
            'data-tmdb-type="movie" data-tmdb-id="331214"',
            _buttons('tt0185906', 'tv/4613'),
          ),
        ),
        (tmdbId: 4613, imdbId: 'tt0185906', kind: TitleKind.show),
      );
    });

    test('only an IMDb button gives the IMDb ID, kind unknown', () {
      expect(
        parseLetterboxdFilmPage(
          _page(
            'data-tmdb-type="movie" data-tmdb-id=""',
            '<a href="http://www.imdb.com/title/tt7366338/maindetails" '
                'class="micro-button track-event" data-track-action="IMDb" '
                'target="_blank" >IMDb</a>',
          ),
        ),
        (tmdbId: null, imdbId: 'tt7366338', kind: TitleKind.unknown),
      );
    });

    test('null when the ID tag is empty and there are no buttons', () {
      expect(
        parseLetterboxdFilmPage(
          _page('data-tmdb-type="movie" data-tmdb-id=""', ''),
        ),
        isNull,
      );
    });

    test('an ID too long to be a number counts as no ID', () {
      const String tooLong = '99999999999999999999';
      expect(
        parseLetterboxdFilmPage(
          _page(
            'data-tmdb-type="movie" data-tmdb-id="$tooLong"',
            _buttons('tt7366338', 'tv/$tooLong'),
          ),
        ),
        (tmdbId: null, imdbId: 'tt7366338', kind: TitleKind.unknown),
      );
      expect(
        parseLetterboxdFilmPage(
          _page('data-tmdb-type="movie" data-tmdb-id="$tooLong"', ''),
        ),
        isNull,
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

  test('the Letterboxd client gives up instead of waiting forever', () {
    final BaseOptions options = letterboxdDio().options;
    expect(options.connectTimeout, const Duration(seconds: 10));
    expect(options.receiveTimeout, const Duration(seconds: 15));
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
        (tmdbId: 860, imdbId: null, kind: TitleKind.movie),
      );
      expect(adapter.requests.single.uri.host, 'boxd.it');
      expect(adapter.requests.single.followRedirects, isTrue);
    });
  });
}
