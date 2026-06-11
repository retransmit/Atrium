/// Public surface of `service_plex`.
///
/// Plex Media Server client (X-Plex-Token + JSON over the shared Dio), models,
/// Riverpod providers, and the per-instance [PlexHome] UI (library chips +
/// poster grid). Browse only - playback is a later piece.
library;

export 'src/models/plex_models.dart';
export 'src/plex_api.dart';
export 'src/plex_home.dart';
export 'src/plex_providers.dart';
