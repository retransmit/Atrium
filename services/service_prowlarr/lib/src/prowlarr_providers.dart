import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_application.dart';
import 'models/prowlarr_history.dart';
import 'models/prowlarr_indexer.dart';
import 'models/prowlarr_indexer_stats.dart';
import 'models/prowlarr_system.dart';
import 'prowlarr_api.dart';

/// How often the indexer list and stats refresh while a Prowlarr screen is
/// visible. Indexer config changes rarely; this mostly picks up health and
/// grab/query counters.
const Duration prowlarrPollInterval = Duration(seconds: 60);

/// A [ProwlarrApi] bound to a specific instance.
///
/// Deliberately NOT autoDispose: the underlying Dio is shared and cheap to
/// keep; disposing it per-screen would re-run the LAN/WAN probe needlessly.
final prowlarrApiProvider = FutureProvider.family<ProwlarrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return ProwlarrApi(dio);
});

/// All indexers for an instance, sorted by name. Polls slowly while watched.
final prowlarrIndexersProvider =
    FutureProvider.autoDispose.family<List<ProwlarrIndexer>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(prowlarrPollInterval);
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  final List<ProwlarrIndexer> indexers = await api.getIndexers();
  indexers.sort(
    (ProwlarrIndexer a, ProwlarrIndexer b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return indexers;
});

/// Indexer stats keyed by indexerId, for badge counts in the list. Polls
/// slowly while watched.
final prowlarrStatsByIdProvider =
    FutureProvider.autoDispose.family<Map<int, ProwlarrIndexerStat>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(prowlarrPollInterval);
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  final ProwlarrIndexerStats stats = await api.getIndexerStats();
  return <int, ProwlarrIndexerStat>{
    for (final ProwlarrIndexerStat s in stats.indexers) s.indexerId: s,
  };
});

/// Addable indexer definitions for the "Add indexer" picker. Effectively
/// static for a session, so no polling.
final prowlarrIndexerSchemasProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  final List<Map<String, dynamic>> schemas = await api.getIndexerSchemas();
  schemas.sort(
    (Map<String, dynamic> a, Map<String, dynamic> b) =>
        ((a['name'] ?? a['implementationName'] ?? '') as String)
            .toLowerCase()
            .compareTo(
              ((b['name'] ?? b['implementationName'] ?? '') as String)
                  .toLowerCase(),
            ),
  );
  return schemas;
});

/// App (sync) profiles, for the indexer form's sync-profile dropdown.
final prowlarrAppProfilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  return api.getAppProfiles();
});

/// All configured application sync targets, sorted by name. Polls slowly while
/// watched to pick up sync-level changes made elsewhere.
final prowlarrApplicationsProvider =
    FutureProvider.autoDispose.family<List<ProwlarrApplication>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(prowlarrPollInterval);
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  final List<ProwlarrApplication> apps = await api.getApplications();
  apps.sort(
    (ProwlarrApplication a, ProwlarrApplication b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return apps;
});

/// Addable application definitions for the "Add application" picker. Effectively
/// static for a session, so no polling.
final prowlarrApplicationSchemasProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  return api.getApplicationSchemas();
});

/// Args for the generic provider list/schema providers: an instance plus the
/// resource endpoint ('downloadclient', 'notification', 'indexerproxy').
typedef ProwlarrProviderArgs = ({Instance instance, String endpoint});

/// Configured instances of a provider resource (download clients, etc.) as raw
/// maps, sorted by name. Polls slowly while watched.
final prowlarrProvidersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ProwlarrProviderArgs>((
  Ref ref,
  ProwlarrProviderArgs args,
) async {
  ref.pollEvery(prowlarrPollInterval);
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(args.instance).future,
  );
  final List<Map<String, dynamic>> list = await api.getProviders(args.endpoint);
  list.sort(
    (Map<String, dynamic> a, Map<String, dynamic> b) =>
        ((a['name'] ?? '') as String)
            .toLowerCase()
            .compareTo(((b['name'] ?? '') as String).toLowerCase()),
  );
  return list;
});

/// Addable definitions for a provider resource. Static for a session.
final prowlarrProviderSchemasProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ProwlarrProviderArgs>((
  Ref ref,
  ProwlarrProviderArgs args,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(args.instance).future,
  );
  return api.getProviderSchemas(args.endpoint);
});

/// Args for [prowlarrHistoryProvider]: an instance plus an optional
/// HistoryEventType filter (1 grabbed, 2 query, 3 RSS, 4 auth; null = all).
typedef ProwlarrHistoryArgs = ({Instance instance, int? eventType});

/// Recent history, newest first, optionally filtered by event type. Polls
/// slowly while watched.
final prowlarrHistoryProvider = FutureProvider.autoDispose
    .family<ProwlarrHistoryPage, ProwlarrHistoryArgs>((
  Ref ref,
  ProwlarrHistoryArgs args,
) async {
  ref.pollEvery(prowlarrPollInterval);
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(args.instance).future,
  );
  return api.getHistory(eventType: args.eventType);
});

/// System status (version, OS, runtime). Effectively static for a session.
final prowlarrSystemStatusProvider =
    FutureProvider.autoDispose.family<ProwlarrSystemStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  return api.getSystemStatus();
});

/// Active health warnings/errors.
final prowlarrHealthProvider =
    FutureProvider.autoDispose.family<List<ProwlarrHealth>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  return api.getHealth();
});

/// Scheduled tasks.
final prowlarrTasksProvider =
    FutureProvider.autoDispose.family<List<ProwlarrSystemTask>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  return api.getTasks();
});

/// Existing backups.
final prowlarrBackupsProvider =
    FutureProvider.autoDispose.family<List<ProwlarrBackup>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ProwlarrApi api = await ref.watch(
    prowlarrApiProvider(instance).future,
  );
  return api.getBackups();
});
