/// A currently-playing Jellyfin session, built from `GET /Sessions` (the
/// `NowPlayingItem` + `PlayState` of each active client).
///
/// This is a plain view model assembled by hand in [JellyfinClient.getSessions];
/// it has no `fromJson` because the client maps the raw session payload
/// directly into these fields.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.user,
    required this.device,
    required this.status,
    required this.showTitle,
    required this.progressPercent,
    required this.timePosition,
    required this.timeDuration,
    required this.positionTicks,
    required this.durationTicks,
    required this.volumeLevel,
    required this.isMuted,
    this.episodeName,
    this.posterUrl,
    this.backdropUrl,
    this.aspectRatio,
    this.itemId,
  });

  /// The session identifier.
  final String id;

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

  /// Current volume level (0-100).
  final int volumeLevel;

  /// Whether the session is currently muted.
  final bool isMuted;

  /// Raw position in ticks (1 tick = 100ns).
  final int positionTicks;

  /// Total duration in ticks (1 tick = 100ns).
  final int durationTicks;

  /// Poster image URL for the now-playing item, if available.
  final String? posterUrl;

  /// Backdrop image URL for the now-playing item, if available.
  final String? backdropUrl;

  /// Aspect ratio of the poster image, if available.
  final double? aspectRatio;

  /// The item ID for the current playing item (used for fetching images, etc.)
  final String? itemId;
}
