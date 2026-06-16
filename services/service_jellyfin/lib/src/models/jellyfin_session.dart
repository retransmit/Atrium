/// A currently-playing Jellyfin session, built from `GET /Sessions` (the
/// `NowPlayingItem` + `PlayState` of each active client).
///
/// This is a plain view model assembled by hand in [JellyfinClient.getSessions];
/// it has no `fromJson` because the client maps the raw session payload
/// directly into these fields.
class ActiveSession {
  const ActiveSession({
    required this.user,
    required this.device,
    required this.status,
    required this.showTitle,
    required this.progressPercent,
    required this.timePosition,
    required this.timeDuration,
    this.episodeName,
    this.posterUrl,
  });

  /// The user streaming this session.
  final String user;

  /// The client/device name (e.g. "Jellyfin Web").
  final String device;

  /// "Playing" or "Paused".
  final String status;

  /// Series name for episodes, otherwise the item title.
  final String showTitle;

  /// Episode title, when the item is a TV episode.
  final String? episodeName;

  /// Playback progress as a whole percentage (0-100).
  final int progressPercent;

  /// Current position, formatted as `h:mm:ss` / `mm:ss`.
  final String timePosition;

  /// Total runtime, formatted as `h:mm:ss` / `mm:ss`.
  final String timeDuration;

  /// Backdrop/poster image URL for the now-playing item, if available.
  final String? posterUrl;
}
