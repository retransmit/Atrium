/// Public surface of `service_tautulli`.
///
/// Tautulli API client (cmd-based, apikey query param via the shared Dio),
/// models, Riverpod providers, and the per-instance [TautulliHome] UI (current
/// active streams).
library;

export 'src/models/tautulli_activity.dart';
export 'src/tautulli_api.dart';
export 'src/tautulli_home.dart';
export 'src/tautulli_providers.dart';
