/// Public surface of `service_sabnzbd`.
///
/// SABnzbd API client (apikey + output=json query params via the shared Dio),
/// models, Riverpod providers, and the per-instance [SabnzbdHome] UI (queue
/// with pause/resume/delete).
library;

export 'src/models/sab_queue.dart';
export 'src/sabnzbd_api.dart';
export 'src/sabnzbd_home.dart';
export 'src/sabnzbd_providers.dart';
