/// What a request or a search result is about.
enum OmbiMediaKind { movie, tv, music }

/// Where a request stands, as a row shows it.
enum OmbiRequestStatus { pending, processing, available, denied }

/// The filters the requests screen offers, one per v2 list route.
enum OmbiRequestFilter { pending, processing, available, denied, all }

/// Which seasons a TV request asks for.
enum OmbiTvSeasons { all, first, latest }

/// The rows on the Discover tab, each one of Ombi's own lists.
enum OmbiDiscoverRow { popularMovies, upcomingMovies, popularTv, trendingTv }

/// Where a request stands in the words of Ombi's Recently Requested cards,
/// which the dashboard mirrors. They differ from its request list's: a
/// denial wins over availability, and a show can be partly in.
enum OmbiRecentStatus { pending, approved, partlyAvailable, available, denied }

/// One request as the screens use it, whatever kind it is.
class OmbiRequest {
  const OmbiRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    this.year,
    this.posterUrl,
    this.requestedBy,
    this.requestedAt,
    this.deniedReason,
    this.denied = false,
    this.partlyAvailable = false,
    this.has4K = false,
  });

  /// What approve, deny and delete act on. For TV this is the child
  /// request's id, one per requester, not the show's.
  final int id;
  final OmbiMediaKind kind;
  final String title;

  /// Where the request stands as Ombi's request list puts it.
  final OmbiRequestStatus status;
  final int? year;
  final String? posterUrl;
  final String? requestedBy;
  final DateTime? requestedAt;
  final String? deniedReason;

  /// Ombi's own denied flag. [status] usually says the same, but Ombi's sync
  /// can later find a title it had denied, and then its list says Available
  /// while its cards still say Denied.
  final bool denied;

  /// Some requested episodes are in and the rest are not. TV only.
  final bool partlyAvailable;

  /// A 4K copy was requested too, which Ombi tags on the row. Movies only.
  final bool has4K;

  /// Where the request stands as Ombi's Recently Requested cards put it.
  OmbiRecentStatus get recentStatus {
    if (denied || status == OmbiRequestStatus.denied) {
      return OmbiRecentStatus.denied;
    }
    if (status == OmbiRequestStatus.available) {
      return OmbiRecentStatus.available;
    }
    if (partlyAvailable) {
      return OmbiRecentStatus.partlyAvailable;
    }
    if (status == OmbiRequestStatus.processing) {
      return OmbiRecentStatus.approved;
    }
    return OmbiRecentStatus.pending;
  }
}

/// A page of requests and how many there are in all.
class OmbiRequestPage {
  const OmbiRequestPage({required this.items, required this.total});

  final List<OmbiRequest> items;
  final int total;
}

/// Request totals across every kind, from `api/v1/Request/count`.
class OmbiCounts {
  const OmbiCounts({
    this.pending = 0,
    this.approved = 0,
    this.available = 0,
    this.denied = 0,
  });

  final int pending;
  final int approved;
  final int available;
  final int denied;

  int get total => pending + approved + available + denied;
}

/// A movie or a show that search or Discover found.
class OmbiSearchHit {
  const OmbiSearchHit({
    required this.tmdbId,
    required this.kind,
    required this.title,
    this.posterUrl,
    this.overview,
    this.requested = false,
    this.available = false,
  });

  final int tmdbId;
  final OmbiMediaKind kind;
  final String title;
  final String? posterUrl;
  final String? overview;

  /// What the list said about it. Search results do not say, so these stay
  /// false there; the request sheet reads the real state either way.
  final bool requested;
  final bool available;
}

/// Where a title stands in Ombi, read from its detail page.
class OmbiTitleState {
  const OmbiTitleState({
    this.requested = false,
    this.approved = false,
    this.available = false,
    this.partlyAvailable = false,
    this.denied = false,
    this.deniedReason,
  });

  final bool requested;
  final bool approved;
  final bool available;

  /// Some seasons of a show are there. It can still take a request.
  final bool partlyAvailable;
  final bool denied;
  final String? deniedReason;

  bool get canRequest => !available && !requested;
}
