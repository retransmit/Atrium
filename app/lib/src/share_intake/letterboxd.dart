import 'package:dio/dio.dart';

import 'title_share.dart';

/// What a Letterboxd film page says about its film.
typedef LetterboxdFilm = ({int tmdbId, TitleKind kind});

final RegExp _tmdbId = RegExp(r'data-tmdb-id="(\d+)"');
final RegExp _tmdbType = RegExp(r'data-tmdb-type="([a-z]+)"');

/// Reads the TMDB ID and type a Letterboxd film page carries on its body,
/// `data-tmdb-id="860" data-tmdb-type="movie"`. Letterboxd also lists some
/// TV, typed `tv`. Null when either is missing or the type is neither.
LetterboxdFilm? parseLetterboxdFilmPage(String html) {
  final String? id = _tmdbId.firstMatch(html)?.group(1);
  final TitleKind? kind = switch (_tmdbType.firstMatch(html)?.group(1)) {
    'movie' => TitleKind.movie,
    'tv' => TitleKind.show,
    _ => null,
  };
  if (id == null || kind == null) {
    return null;
  }
  return (tmdbId: int.parse(id), kind: kind);
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
