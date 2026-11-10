import 'torrent_share.dart';

export 'torrent_share.dart' show TitleKind, TitleShare;

/// Pulls a movie or show out of shared text.
///
/// Apps share a title differently:
/// - Showly sends the title, an IMDb link and a Trakt link.
/// - The IMDb app sends an IMDb link.
/// - Letterboxd sends a `boxd.it` short link.
/// - Others send a TMDB or Trakt link, or just the title.
///
/// The strongest clue is kept: an IMDb ID, then a TMDB ID, then a Letterboxd
/// link to follow later. Whether it is a movie or a show comes from whichever
/// link says so. A title is kept too, for a search when no ID resolves.
///
/// Returns null when the text holds none of these, such as an unknown link on
/// its own: searching for a URL would find nothing useful.
TitleShare? extractTitleShare(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  String? imdbId;
  int? tmdbId;
  Uri? letterboxdUrl;
  TitleKind? kind;
  String? slugTitle;

  for (final String token in trimmed.split(RegExp(r'\s+'))) {
    final Uri? uri = _webLink(token);
    if (uri == null) {
      continue;
    }
    final String host = uri.host.toLowerCase();
    final String path = uri.path;

    if (_isHost(host, 'imdb.com')) {
      imdbId ??= RegExp(r'^/title/(tt\d{7,})').firstMatch(path)?.group(1);
    } else if (_isHost(host, 'themoviedb.org')) {
      final RegExpMatch? m = RegExp(r'^/(movie|tv)/(\d+)').firstMatch(path);
      if (m != null && tmdbId == null) {
        tmdbId = int.parse(m.group(2)!);
        kind ??= m.group(1) == 'movie' ? TitleKind.movie : TitleKind.show;
      }
    } else if (_isHost(host, 'trakt.tv')) {
      final RegExpMatch? m =
          RegExp(r'^/(movies|shows)/([^/]+)').firstMatch(path);
      if (m != null) {
        kind ??= m.group(1) == 'movies' ? TitleKind.movie : TitleKind.show;
        slugTitle ??= _titleFromSlug(m.group(2)!);
      }
    } else if (host == 'boxd.it' ||
        (_isHost(host, 'letterboxd.com') && path.startsWith('/film/'))) {
      letterboxdUrl ??= uri;
    }
  }

  final String? title = slugTitle ?? _titleLine(trimmed);
  if (imdbId == null &&
      tmdbId == null &&
      letterboxdUrl == null &&
      title == null) {
    return null;
  }
  return TitleShare(
    kind: kind ?? TitleKind.unknown,
    imdbId: imdbId,
    tmdbId: tmdbId,
    letterboxdUrl: letterboxdUrl,
    title: title,
  );
}

Uri? _webLink(String token) {
  final Uri? uri = Uri.tryParse(token);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
}

bool _isHost(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

/// `wargames-1983` becomes `wargames`, `breaking-bad` becomes `breaking bad`.
String _titleFromSlug(String slug) => slug
    .replaceFirst(RegExp(r'-\d{4}$'), '')
    .replaceAll('-', ' ')
    .trim();

/// The first line left once every link is taken out, without a trailing
/// colon (Showly writes `Title:` above its links).
String? _titleLine(String text) {
  for (final String line in text.split('\n')) {
    final String words = line
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty && _webLink(t) == null)
        .join(' ')
        .trim();
    final String title = words.endsWith(':')
        ? words.substring(0, words.length - 1).trim()
        : words;
    if (title.isNotEmpty) {
      return title;
    }
  }
  return null;
}
