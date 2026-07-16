/// Public surface of `service_emby`.
///
/// Emby REST client (token-session auth; `X-Emby-Authorization` /
/// `X-Emby-Token`), models, Riverpod providers, and the per-instance
/// [EmbyHome] UI (library chips + poster grid). Browse only - playback is a
/// later piece. Mirrors `service_jellyfin`.
library;

export 'src/emby_client.dart';
export 'src/emby_home.dart';
export 'src/emby_providers.dart';
export 'src/emby_search.dart';
export 'src/emby_session_detail_screen.dart';
export 'src/emby_settings_screen.dart';
export 'src/models/emby_auth.dart';
export 'src/models/emby_item.dart';
export 'src/models/emby_session.dart';
export 'src/models/emby_view.dart';
