/// Coarse health signal surfaced in the dashboard tiles and instance lists.
///
/// Individual services emit richer health information (e.g., Sonarr's
/// `/api/v3/health` returns typed warnings); the connection layer collapses
/// those to one of these four states for at-a-glance use.
enum Health {
  /// Reachable and reporting OK.
  ok,

  /// Reachable but reporting non-fatal problems (missing indexer, expired
  /// cert in N days, etc.).
  warning,

  /// Unreachable or returning errors.
  error,

  /// Not yet probed since the app launched, or probe in flight.
  unknown,
}
