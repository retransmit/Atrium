/// Public surface of `service_transmission`.
///
/// Transmission RPC client (CSRF-token handshake, optional HTTP Basic), models,
/// Riverpod providers, and the per-instance [TransmissionHome] UI (torrent list
/// with start/stop/remove/verify/reannounce/queue moves, status and label
/// filters, session limits with turtle mode, add by magnet/URL/file, and a
/// per-torrent detail screen).
library;

export 'src/models/transmission_detail.dart';
export 'src/models/transmission_session.dart';
export 'src/models/transmission_torrent.dart';
export 'src/transmission_add_sheet.dart';
export 'src/transmission_api.dart';
export 'src/transmission_detail_screen.dart';
export 'src/transmission_format.dart';
export 'src/transmission_home.dart';
export 'src/transmission_providers.dart';
export 'src/transmission_speed_dialog.dart';
