import 'package:meta/meta.dart';

/// Everything [AtriumPlayerScreen] needs to play one item, independent of
/// which media server it came from.
///
/// Service modules construct this with their own stream URL and (optionally)
/// progress-reporting callbacks. The player drives the callbacks at the right
/// moments; it never talks to a server directly.
@immutable
class PlaybackSpec {
  const PlaybackSpec({
    required this.url,
    required this.title,
    this.subtitle,
    this.headers = const <String, String>{},
    this.startPosition = Duration.zero,
    this.onStarted,
    this.onProgress,
    this.onStopped,
  });

  /// Absolute, playable URL. For most servers this already carries auth as a
  /// query parameter (e.g. Jellyfin's `?api_key=`); when a server needs auth
  /// headers instead, put them in [headers].
  final String url;

  /// Shown in the player's app bar.
  final String title;

  /// Optional secondary line (e.g. "S02E04 - Episode name").
  final String? subtitle;

  /// Extra HTTP headers for the media request. Most servers don't need these.
  final Map<String, String> headers;

  /// Where to resume from. [Duration.zero] starts at the beginning.
  final Duration startPosition;

  /// Called once, after the media is loaded and the first frame is ready.
  /// Servers use this to mark the item as "now playing".
  final void Function(Duration position)? onStarted;

  /// Called periodically (~every 10s) and on pause/seek with the current
  /// position. Servers use this to persist resume points.
  final void Function(Duration position, bool isPaused)? onProgress;

  /// Called once when the player closes, with the final position. Servers use
  /// this to mark "stopped" and store the final resume point.
  final void Function(Duration position)? onStopped;
}
