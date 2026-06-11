/// Public surface of `service_qbittorrent`.
///
/// qBittorrent WebUI API v2 client (cookie-session auth), models, Riverpod
/// providers, and the per-instance [QbittorrentHome] UI. This is the first
/// service using cookie login rather than a static API key.
library;

export 'src/add_torrent_sheet.dart';
export 'src/models/qbit_detail.dart';
export 'src/models/qbit_torrent.dart';
export 'src/models/qbit_transfer_info.dart';
export 'src/qbittorrent_client.dart';
export 'src/qbittorrent_home.dart';
export 'src/qbittorrent_providers.dart';
export 'src/torrent_detail_screen.dart';
