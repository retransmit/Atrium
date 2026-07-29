import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/nzbget_group.dart';
import 'models/nzbget_history_entry.dart';
import 'models/nzbget_status.dart';
import 'nzbget_api.dart';

/// How often the queue and global status refresh while a screen is visible.
const Duration nzbgetQueuePollInterval = Duration(seconds: 3);

/// History changes less often than the live queue.
const Duration nzbgetHistoryPollInterval = Duration(seconds: 10);

/// A [NzbgetApi] for an instance, over the shared `instanceDioProvider`.
///
/// Deliberately NOT autoDispose: the underlying Dio is shared and cheap to keep.
final nzbgetApiProvider = FutureProvider.family<NzbgetApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return NzbgetApi(dio);
});

/// The download queue. Polls fast while watched.
final nzbgetQueueProvider =
    FutureProvider.autoDispose.family<List<NzbgetGroup>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(nzbgetQueuePollInterval);
  final NzbgetApi api = await ref.watch(nzbgetApiProvider(instance).future);
  return api.getGroups();
});

/// Global speed / paused / disk status. Polls alongside the queue.
final nzbgetStatusProvider =
    FutureProvider.autoDispose.family<NzbgetStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(nzbgetQueuePollInterval);
  final NzbgetApi api = await ref.watch(nzbgetApiProvider(instance).future);
  return api.getStatus();
});

/// Completed / failed history. Polls slowly while watched.
final nzbgetHistoryProvider =
    FutureProvider.autoDispose.family<List<NzbgetHistoryEntry>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(nzbgetHistoryPollInterval);
  final NzbgetApi api = await ref.watch(nzbgetApiProvider(instance).future);
  return api.getHistory();
});

/// Server-configured category names. Fetched on demand.
final nzbgetCategoriesProvider =
    FutureProvider.autoDispose.family<List<String>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final NzbgetApi api = await ref.watch(nzbgetApiProvider(instance).future);
  return api.getCategories();
});
