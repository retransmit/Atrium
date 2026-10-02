import '../generated/generated.dart';
import 'ombi_models.dart';

const String _tmdbImages = 'https://image.tmdb.org/t/p/';

/// A poster URL for a path Ombi stored. TMDB paths arrive relative
/// (`/abc.jpg`); a source that stores a full URL has it used as it is.
String? ombiPosterUrl(String? path, {String size = 'w342'}) {
  final String? p = _text(path);
  if (p == null) {
    return null;
  }
  if (p.startsWith('http://') || p.startsWith('https://')) {
    return p;
  }
  return '$_tmdbImages$size${p.startsWith('/') ? p : '/$p'}';
}

/// A backdrop URL for a path Ombi stored, wide enough to head a sheet.
String? ombiBackdropUrl(String? path) => ombiPosterUrl(path, size: 'w780');

OmbiRequest ombiRequestFromMovie(MovieRequests m) => OmbiRequest(
      id: m.id ?? 0,
      kind: OmbiMediaKind.movie,
      title: _text(m.title) ?? 'Untitled movie',
      status: _status(m.approved, m.available, m.denied),
      tmdbId: m.theMovieDbId,
      year: _year(m.releaseDate),
      posterUrl: ombiPosterUrl(m.posterPath),
      backdropUrl: ombiBackdropUrl(m.background),
      overview: _text(m.overview),
      requestedBy: _requester(m.requestedByAlias, m.requestedUser),
      requestedAt: _utcDate(m.requestedDate),
      deniedReason: _text(m.deniedReason),
      denied: m.denied ?? false,
      has4K: m.has4KRequest ?? false,
    );

/// A TV row is a child request, the one approve, deny and delete act on.
/// Its title, poster and year belong to the parent show.
OmbiRequest ombiRequestFromChild(ChildRequests c) {
  final TvRequests? show = c.parentRequest;
  final List<SeasonRequests> seasons =
      c.seasonRequests ?? const <SeasonRequests>[];
  final List<EpisodeRequests> episodes = <EpisodeRequests>[
    for (final SeasonRequests season in seasons) ...?season.episodes,
  ];
  final int episodesIn =
      episodes.where((EpisodeRequests e) => e.available ?? false).length;
  return OmbiRequest(
    id: c.id ?? 0,
    kind: OmbiMediaKind.tv,
    title: _text(show?.title) ?? _text(c.title) ?? 'Untitled show',
    status: _status(c.approved, c.available, c.denied),
    // The show's TMDB id. Its TVDB one is kept beside it and opens nothing.
    tmdbId: show?.externalProviderId,
    year: _year(show?.releaseDate) ?? _year(c.releaseYear),
    posterUrl: ombiPosterUrl(show?.posterPath),
    backdropUrl: ombiBackdropUrl(show?.background),
    overview: _text(show?.overview),
    requestedBy: _requester(c.requestedByAlias, c.requestedUser),
    requestedAt: _utcDate(c.requestedDate),
    deniedReason: _text(c.deniedReason),
    denied: c.denied ?? false,
    // Ombi's own rule for its cards: any requested episode being in.
    partlyAvailable: episodesIn > 0,
    seasons: <int>[
      for (final SeasonRequests season in seasons)
        if (season.seasonNumber case final int number) number,
    ]..sort(),
    episodes: episodes.length,
    episodesAvailable: episodesIn,
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
    year: _year(m.releaseDate),
    rating: _rating(m.voteAverage),
    posterUrl: ombiPosterUrl(m.posterPath),
    backdropUrl: ombiBackdropUrl(m.backdropPath),
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
    year: _year(t.firstAired),
    // Shows carry their numbers as text.
    rating: _rating(double.tryParse(t.rating ?? '')),
    posterUrl: ombiPosterUrl(t.posterPath),
    backdropUrl: ombiBackdropUrl(t.backdropPath ?? t.banner),
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
      posterUrl: ombiPosterUrl(m.posterPath),
      backdropUrl: ombiBackdropUrl(m.backdropPath),
      tagline: _text(m.tagline),
      overview: _text(m.overview),
      year: _year(m.releaseDate),
      runtimeMinutes: _positive(m.runtime),
      rating: _rating(m.voteAverage),
      genres: _genres(m.genres),
      releaseStatus: _text(m.status),
    );

OmbiTitleState ombiTitleStateFromTv(SearchFullInfoTvShowViewModel t) =>
    OmbiTitleState(
      requested: t.requested ?? false,
      approved: t.approved ?? false,
      available: (t.fullyAvailable ?? false) || (t.available ?? false),
      partlyAvailable: t.partlyAvailable ?? false,
      denied: t.denied ?? false,
      deniedReason: _text(t.deniedReason),
      posterUrl: ombiPosterUrl(t.images?.original),
      // A show's backdrop is its banner.
      backdropUrl: ombiBackdropUrl(t.banner),
      tagline: _text(t.tagline),
      overview: _text(t.overview),
      year: _year(t.firstAired),
      // Shows carry their numbers as text, and a missing runtime as "0".
      runtimeMinutes: _positive(int.tryParse(t.runtime ?? '')),
      rating: _rating(double.tryParse(t.rating ?? '')),
      genres: _genres(t.genres),
      releaseStatus: _text(t.status),
      network: _text(t.network?.name),
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

/// When a movie or TV request was made.
///
/// Ombi stores these in UTC and sends them with no zone on them, which a
/// plain parse reads as this phone's local time: every request would then
/// look older, or newer, by the phone's distance from UTC. A date that does
/// name its zone is left as it is. Albums are not read this way, since Ombi
/// stamps those in its own local time.
DateTime? _utcDate(String? s) {
  final DateTime? d = _date(s);
  if (d == null || d.isUtc) {
    return d;
  }
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
    d.microsecond,
  );
}

/// A score worth showing. TheMovieDB reports an unrated title as zero.
double? _rating(double? value) => (value == null || value <= 0) ? null : value;

int? _positive(int? value) => (value == null || value <= 0) ? null : value;

List<String> _genres(List<GenreViewModel>? genres) => <String>[
      for (final GenreViewModel g in genres ?? const <GenreViewModel>[])
        if (_text(g.name) case final String name) name,
    ];

int? _year(String? s) => _date(s)?.year;
