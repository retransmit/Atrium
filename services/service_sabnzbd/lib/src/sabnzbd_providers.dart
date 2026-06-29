import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/sab_history.dart';
import 'models/sab_queue.dart';
import 'models/sab_stats.dart';
import 'sabnzbd_api.dart';

/// How often the download queue refreshes while a SABnzbd screen is visible.
const Duration sabQueuePollInterval = Duration(seconds: 3);

/// How often history refreshes (changes less often than the live queue).
const Duration sabHistoryPollInterval = Duration(seconds: 10);

/// A [SabnzbdApi] for an instance, over the shared `instanceDioProvider`.
///
/// Deliberately NOT autoDispose: the underlying Dio is shared and cheap to keep.
final sabnzbdApiProvider =
    FutureProvider.family<SabnzbdApi, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final dio = await ref.watch(instanceDioProvider(instance).future);
      return SabnzbdApi(dio);
    });

/// The current download queue. Polls fast while watched.
final sabQueueProvider =
    FutureProvider.autoDispose.family<SabQueue, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      ref.pollEvery(sabQueuePollInterval);
      final SabnzbdApi api = await ref.watch(sabnzbdApiProvider(instance).future);
      return api.getQueue();
    });

/// Completed / failed download history. Polls slowly while watched.
final sabHistoryProvider =
    FutureProvider.autoDispose.family<SabHistory, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      ref.pollEvery(sabHistoryPollInterval);
      final SabnzbdApi api = await ref.watch(sabnzbdApiProvider(instance).future);
      return api.getHistory();
    });

/// Bytes-downloaded stats (day/week/month/total). Fetched on demand.
final sabServerStatsProvider =
    FutureProvider.autoDispose.family<SabServerStats, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final SabnzbdApi api = await ref.watch(sabnzbdApiProvider(instance).future);
      return api.getServerStats();
    });

/// SABnzbd version string. Fetched on demand.
final sabVersionProvider =
    FutureProvider.autoDispose.family<String, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final SabnzbdApi api = await ref.watch(sabnzbdApiProvider(instance).future);
      return api.getVersion();
    });
