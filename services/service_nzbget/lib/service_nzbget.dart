/// Public surface of `service_nzbget`.
///
/// NZBGet JSON-RPC client (HTTP Basic auth via the shared Dio), models,
/// Riverpod providers, and the per-instance [NzbgetHome] UI (queue with
/// pause/resume/delete/reorder, history, speed limit, add NZB).
library;

export 'src/models/nzbget_group.dart';
export 'src/models/nzbget_history_entry.dart';
export 'src/models/nzbget_status.dart';
export 'src/nzbget_api.dart';
