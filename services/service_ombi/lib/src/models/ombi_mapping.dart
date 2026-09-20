import '../generated/generated.dart';
import 'ombi_models.dart';

const String _tmdbImages = 'https://image.tmdb.org/t/p/';

/// A poster URL for a path Ombi stored. TMDB paths arrive relative
/// (`/abc.jpg`); a source that stores a full URL has it used as it is.
String? ombiPosterUrl(String? path, {String size = 'w185'}) {
  final String? p = _text(path);
  if (p == null) {
    return null;
  }
  if (p.startsWith('http://') || p.startsWith('https://')) {
    return p;
  }
  return '$_tmdbImages$size${p.startsWith('/') ? p : '/$p'}';
}

OmbiRequest ombiRequestFromMovie(MovieRequests m) => OmbiRequest(
      id: m.id ?? 0,
      kind: OmbiMediaKind.movie,
      title: _text(m.title) ?? 'Untitled movie',
      status: _status(m.approved, m.available, m.denied),
      year: _year(m.releaseDate),
      posterUrl: ombiPosterUrl(m.posterPath),
      requestedBy: _requester(m.requestedByAlias, m.requestedUser),
      requestedAt: _date(m.requestedDate),
      deniedReason: _text(m.deniedReason),
      denied: m.denied ?? false,
      has4K: m.has4KRequest ?? false,
    );

/// A TV row is a child request, the one approve, deny and delete act on.
/// Its title, poster and year belong to the parent show.
OmbiRequest ombiRequestFromChild(ChildRequests c) {
  final TvRequests? show = c.parentRequest;
  return OmbiRequest(
    id: c.id ?? 0,
    kind: OmbiMediaKind.tv,
    title: _text(show?.title) ?? _text(c.title) ?? 'Untitled show',
    status: _status(c.approved, c.available, c.denied),
    year: _year(show?.releaseDate) ?? _year(c.releaseYear),
    posterUrl: ombiPosterUrl(show?.posterPath),
    requestedBy: _requester(c.requestedByAlias, c.requestedUser),
    requestedAt: _date(c.requestedDate),
    deniedReason: _text(c.deniedReason),
    denied: c.denied ?? false,
    // Ombi's own rule for its cards: any requested episode being in.
    partlyAvailable: <EpisodeRequests>[
      for (final SeasonRequests season
          in c.seasonRequests ?? const <SeasonRequests>[])
        ...?season.episodes,
    ].any((EpisodeRequests e) => e.available ?? false),
  );
}

OmbiRequest ombiRequestFromAlbum(AlbumRequest a) {
  final String album = _text(a.title) ?? 'Untitled album';
  final String? artist = _text(a.artistName);
  return OmbiRequest(
    id: a.id ?? 0,
    kind: OmbiMediaKind.music,
    title: artist == null ? album : '$artist - $album',
    status: _status(a.approved, a.available, a.denied),
    year: _year(a.releaseDate),
    posterUrl: ombiPosterUrl(a.cover),
    requestedBy: _requester(a.requestedByAlias, a.requestedUser),
    requestedAt: _date(a.requestedDate),
    deniedReason: _text(a.deniedReason),
    denied: a.denied ?? false,
  );
}

OmbiCounts ombiCountsFrom(RequestCountModel? m) => OmbiCounts(
      pending: m?.pending ?? 0,
      approved: m?.approved ?? 0,
      available: m?.available ?? 0,
      denied: m?.denied ?? 0,
    );

/// A hit the screens can use, or null for anything that is not a movie or a
/// show, or has no usable TMDB id.
OmbiSearchHit? ombiSearchHitFrom(MultiSearchResult r) {
  final OmbiMediaKind? kind = switch (r.mediaType) {
    'movie' => OmbiMediaKind.movie,
    'tv' => OmbiMediaKind.tv,
    _ => null,
  };
  final int? id = int.tryParse(r.id ?? '');
  final String? title = _text(r.title);
  if (kind == null || id == null || title == null) {
    return null;
  }
  return OmbiSearchHit(
    tmdbId: id,
    kind: kind,
    title: title,
    posterUrl: ombiPosterUrl(r.poster),
    overview: _text(r.overview),
  );
}

/// A Discover movie. Movies carry their TMDB id as `theMovieDbId`, a string,
/// as well as in `id`.
OmbiSearchHit? ombiSearchHitFromMovie(SearchMovieViewModel m) {
  final int? id = int.tryParse(m.theMovieDbId ?? '') ?? m.id;
  final String? title = _text(m.title);
  if (id == null || title == null) {
    return null;
  }
  return OmbiSearchHit(
    tmdbId: id,
    kind: OmbiMediaKind.movie,
    title: title,
    posterUrl: ombiPosterUrl(m.posterPath),
    overview: _text(m.overview),
    requested: m.requested ?? false,
    available: m.available ?? false,
  );
}

/// A Discover show. On these rows `theMovieDbId` is empty and the TMDB id is
/// `id`, which the TV detail route confirms.
OmbiSearchHit? ombiSearchHitFromShow(SearchTvShowViewModel t) {
  final int? id = int.tryParse(t.theMovieDbId ?? '') ?? t.id;
  final String? title = _text(t.title);
  if (id == null || title == null) {
    return null;
  }
  return OmbiSearchHit(
    tmdbId: id,
    kind: OmbiMediaKind.tv,
    title: title,
    posterUrl: ombiPosterUrl(t.posterPath),
    overview: _text(t.overview),
    requested: t.requested ?? false,
    available: t.available ?? false,
  );
}

OmbiTitleState ombiTitleStateFromMovie(MovieFullInfoViewModel m) =>
    OmbiTitleState(
      requested: m.requested ?? false,
      approved: m.approved ?? false,
      available: m.available ?? false,
      denied: m.denied ?? false,
      deniedReason: _text(m.deniedReason),
    );

OmbiTitleState ombiTitleStateFromTv(SearchFullInfoTvShowViewModel t) =>
    OmbiTitleState(
      requested: t.requested ?? false,
      approved: t.approved ?? false,
      available: (t.fullyAvailable ?? false) || (t.available ?? false),
      partlyAvailable: t.partlyAvailable ?? false,
      denied: t.denied ?? false,
      deniedReason: _text(t.deniedReason),
    );

/// The order Ombi's own request status takes, which its request list shows:
/// availability first, so a denied title Ombi later found reads Available.
OmbiRequestStatus _status(bool? approved, bool? available, bool? denied) {
  if (available ?? false) {
    return OmbiRequestStatus.available;
  }
  if (denied ?? false) {
    return OmbiRequestStatus.denied;
  }
  if (approved ?? false) {
    return OmbiRequestStatus.processing;
  }
  return OmbiRequestStatus.pending;
}

/// Who asked: someone requested on behalf of first, then the account's alias,
/// then its user name.
String? _requester(String? onBehalfOf, OmbiUser? user) {
  for (final String? name in <String?>[
    onBehalfOf,
    user?.userAlias,
    user?.alias,
    user?.userName,
  ]) {
    final String? t = _text(name);
    if (t != null) {
      return t;
    }
  }
  return null;
}

String? _text(String? s) {
  final String? t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

DateTime? _date(String? s) => s == null ? null : DateTime.tryParse(s);

int? _year(String? s) => _date(s)?.year;
