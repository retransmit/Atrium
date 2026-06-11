/// Public surface of `service_overseerr`.
///
/// Overseerr / Jellyseerr API client (X-Api-Key via the shared Dio), models,
/// Riverpod providers, and the per-instance [OverseerrHome] UI (request list
/// with approve / decline).
library;

export 'src/models/overseerr_request.dart';
export 'src/overseerr_api.dart';
export 'src/overseerr_home.dart';
export 'src/overseerr_providers.dart';
