/// Public surface of `service_prowlarr`.
///
/// Prowlarr v1 API client, models, Riverpod providers, and the per-instance
/// [ProwlarrHome] UI (indexer list + stats + enable toggle + test, manual
/// search across indexers with grab-to-client). Built from the Sonarr
/// template.
library;

export 'src/models/prowlarr_indexer.dart';
export 'src/models/prowlarr_indexer_stats.dart';
export 'src/models/prowlarr_release.dart';
export 'src/prowlarr_api.dart';
export 'src/prowlarr_home.dart';
export 'src/prowlarr_providers.dart';
export 'src/prowlarr_search_screen.dart';
