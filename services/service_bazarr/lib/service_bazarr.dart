/// Public surface of `service_bazarr`.
///
/// Bazarr API client (API-key header via the shared Dio), models, Riverpod
/// providers, and the per-instance [BazarrHome] UI (badges header + unified
/// wanted-subtitles list).
library;

export 'src/bazarr_api.dart';
export 'src/bazarr_home.dart';
export 'src/bazarr_providers.dart';
export 'src/models/bazarr_models.dart';
