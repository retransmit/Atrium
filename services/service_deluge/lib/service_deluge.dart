/// Public surface of `service_deluge`.
///
/// Deluge 2.x Web UI JSON-RPC client (password login exchanged for a session
/// cookie), models, Riverpod providers, and the per-instance [DelugeHome] UI
/// (torrent list with pause/resume/remove/recheck/queue, filters, global speed
/// limits, add by magnet/URL/file, and a per-torrent detail screen).
library;

export 'src/deluge_add_sheet.dart';
export 'src/deluge_client.dart';
export 'src/deluge_format.dart';
export 'src/deluge_home.dart';
export 'src/deluge_providers.dart';
export 'src/deluge_speed_dialog.dart';
export 'src/deluge_torrent_detail_screen.dart';
export 'src/models/deluge_filter_tree.dart';
export 'src/models/deluge_session_status.dart';
export 'src/models/deluge_torrent.dart';
export 'src/models/deluge_torrent_detail.dart';
