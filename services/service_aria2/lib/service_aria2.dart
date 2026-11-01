/// Public surface of `service_aria2`.
///
/// aria2 JSON-RPC client (the daemon's own `--rpc-secret` token, not an HTTP
/// credential), models, Riverpod providers, and the per-instance [Aria2Home]
/// UI (active/queued/stopped lists, per-download detail, speed limit, add
/// by URI/magnet/.torrent).
library;

export 'src/aria2_add_sheet.dart';
export 'src/aria2_api.dart';
export 'src/aria2_download_detail_screen.dart';
export 'src/aria2_format.dart';
export 'src/aria2_home.dart';
export 'src/aria2_providers.dart';
export 'src/aria2_speed_dialog.dart';
export 'src/models/aria2_download.dart';
export 'src/models/aria2_file.dart';
export 'src/models/aria2_global_stat.dart';
export 'src/models/aria2_json.dart';
export 'src/models/aria2_peer.dart';
export 'src/models/aria2_server.dart';
export 'src/models/aria2_snapshot.dart';
export 'src/models/aria2_version.dart';
