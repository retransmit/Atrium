import 'package:core_models/core_models.dart';

import 'torrent_share.dart';

export 'torrent_share.dart' show AtriumLink, LinkItem;

const TorrentShareProblem _unreadable = TorrentShareProblem(
  'That Atrium link could not be read, so it went nowhere.',
);

final RegExp _imdbId = RegExp(r'^tt\d{7,}$');

/// Reads an `atrium://` link opened from another app.
///
/// - `atrium://sonarr` opens a service. The name is a service's own name,
///   matched ignoring case.
/// - `atrium://radarr/movie?tmdb=550` opens a movie, by `id` (Radarr's own
///   library ID), `tmdb` or `imdb`.
/// - `atrium://sonarr/series?tvdb=81189` opens a series, by `id`, `tvdb`,
///   `tmdb` or `imdb`.
/// - `instance=<name>` on any of them picks the instance by name.
///
/// An item link keeps one ID, the most exact it carries: the library ID,
/// then the ID its service keys by (TMDB for a movie, TVDB for a series),
/// then the rest. Anything else is a [TorrentShareProblem] saying so.
TorrentShare parseAtriumLink(String link) {
  final Uri? uri = Uri.tryParse(link);
  if (uri == null || uri.scheme.toLowerCase() != 'atrium' || uri.host.isEmpty) {
    return _unreadable;
  }
  final String host = uri.host.toLowerCase();
  ServiceKind? service;
  for (final ServiceKind kind in ServiceKind.values) {
    if (kind.name.toLowerCase() == host) {
      service = kind;
    }
  }
  if (service == null) {
    return TorrentShareProblem(
      'Atrium does not know a service called "${uri.host}", so that link '
      'went nowhere.',
    );
  }

  // A broken escape such as `%FF` only shows up when the query is decoded.
  final Map<String, String> query;
  try {
    query = uri.queryParameters;
  } on FormatException {
    return _unreadable;
  } on ArgumentError {
    return _unreadable;
  }

  final String? name = query['instance']?.trim();
  final String? instanceName = name == null || name.isEmpty ? null : name;

  final String path = uri.path.replaceAll(RegExp(r'^/+|/+$'), '').toLowerCase();
  final LinkItem? item = switch (path) {
    '' => LinkItem.none,
    'movie' when service == ServiceKind.radarr => LinkItem.movie,
    'series' when service == ServiceKind.sonarr => LinkItem.series,
    _ => null,
  };
  if (item == null) {
    return _unreadable;
  }
  if (item == LinkItem.none) {
    return AtriumLink(service: service, instanceName: instanceName);
  }

  int? number(String key) {
    final int? n = int.tryParse(query[key] ?? '');
    return n != null && n > 0 ? n : null;
  }

  final int? id = number('id');
  final int? tmdb = number('tmdb');
  final int? tvdb = item == LinkItem.series ? number('tvdb') : null;
  final String? imdbText = query['imdb'];
  final String? imdb =
      imdbText != null && _imdbId.hasMatch(imdbText) ? imdbText : null;

  final AtriumLink base = AtriumLink(
    service: service,
    item: item,
    instanceName: instanceName,
  );
  if (id != null) {
    return base.withId(libraryId: id);
  }
  if (item == LinkItem.movie && tmdb != null) {
    return base.withId(tmdbId: tmdb);
  }
  if (tvdb != null) {
    return base.withId(tvdbId: tvdb);
  }
  if (tmdb != null) {
    return base.withId(tmdbId: tmdb);
  }
  if (imdb != null) {
    return base.withId(imdbId: imdb);
  }
  return _unreadable;
}

extension on AtriumLink {
  AtriumLink withId({
    int? libraryId,
    int? tmdbId,
    int? tvdbId,
    String? imdbId,
  }) =>
      AtriumLink(
        service: service,
        item: item,
        instanceName: instanceName,
        libraryId: libraryId,
        tmdbId: tmdbId,
        tvdbId: tvdbId,
        imdbId: imdbId,
      );
}
