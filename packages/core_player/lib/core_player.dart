/// Public surface of `core_player`.
///
/// A shared, service-agnostic full-screen video player. Service modules
/// (Jellyfin, Emby, Plex) build a [PlaybackSpec] - a stream URL plus optional
/// resume position and progress callbacks - and push [AtriumPlayerScreen].
///
/// The player itself knows nothing about any specific media server; all
/// server-specific concerns (auth in the URL, progress reporting) are
/// expressed through [PlaybackSpec]'s callbacks.
library;

export 'src/playback_spec.dart';
export 'src/player_init.dart';
export 'src/player_screen.dart';
