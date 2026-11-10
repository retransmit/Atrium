import 'package:dio/dio.dart';

import 'title_share.dart';

/// What a Letterboxd film page says about its film. At least one ID is set.
typedef LetterboxdFilm = ({int? tmdbId, String? imdbId, TitleKind kind});

final RegExp _anchor = RegExp(r'<a\s[^>]*>');
final RegExp _tmdbLink = RegExp(r'themoviedb\.org/(movie|tv)/(\d+)');
final RegExp _imdbLink = RegExp(r'imdb\.com/title/(tt\d{7,})');
final RegExp _tmdbId = RegExp(r'data-tmdb-id="(\d+)"');
final RegExp _tmdbType = RegExp(r'data-tmdb-type="([a-z]+)"');

/// The link of the page's button marked `data-track-action="[action]"`,
/// matched against [link]. Only the film's own button counts, so a TMDB or
/// IMDb link anywhere else on the page, a review or the footer, does not.
RegExpMatch? _button(String html, String action, RegExp link) {
  for (final RegExpMatch a in _anchor.allMatches(html)) {
    final String tag = a.group(0)!;
    if (tag.contains('data-track-action="$action"')) {
      return link.firstMatch(tag);
    }
  }
  return null;
}

/// Reads which film a Letterboxd page is about.
///
/// The page's IMDb and TMDB buttons come first. Letterboxd also lists some
/// TV, and on those pages the body still says `data-tmdb-type="movie"`,
/// with the ID empty or naming some other entry, while the TMDB button
/// links the show (`themoviedb.org/tv/87108`). The body's
/// `data-tmdb-id="860" data-tmdb-type="movie"` is used only when there is
/// no TMDB button. Null when no ID is found at all.
LetterboxdFilm? parseLetterboxdFilmPage(String html) {
  final String? imdbId = _button(html, 'IMDb', _imdbLink)?.group(1);
  final RegExpMatch? tmdb = _button(html, 'TMDB', _tmdbLink);
  if (tmdb != null) {
    return (
      tmdbId: int.parse(tmdb.group(2)!),
      imdbId: imdbId,
      kind: tmdb.group(1) == 'tv' ? TitleKind.show : TitleKind.movie,
    );
  }
  final String? id = _tmdbId.firstMatch(html)?.group(1);
  final TitleKind? kind = switch (_tmdbType.firstMatch(html)?.group(1)) {
    'movie' => TitleKind.movie,
    'tv' => TitleKind.show,
    _ => null,
  };
  if (id != null && kind != null) {
    return (tmdbId: int.parse(id), imdbId: imdbId, kind: kind);
  }
  if (imdbId != null) {
    return (tmdbId: null, imdbId: imdbId, kind: TitleKind.unknown);
  }
  return null;
}

/// The client for Letterboxd. It times out like the app's server clients
/// do, so a stalled connection cannot keep the share waiting forever.
Dio letterboxdDio() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

/// Follows a shared Letterboxd link to its film page and reads it.
///
/// A `boxd.it` short link answers with a redirect to the page, so redirects
/// are followed. This is the only request a share makes to a site the user
/// did not set up, and only when they share from Letterboxd. Any failure is
/// null, so the caller can fall back to searching by title.
Future<LetterboxdFilm?> readLetterboxdFilm(Dio dio, Uri url) async {
  try {
    final Response<String> response = await dio.getUri<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        headers: <String, String>{
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) Atrium',
        },
      ),
    );
    final String? body = response.data;
    return body == null ? null : parseLetterboxdFilmPage(body);
  } on DioException {
    return null;
  }
}
