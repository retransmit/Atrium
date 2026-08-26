import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../state/api_providers.dart';

/// Active download queue items for an instance. Polls every 15s while watched.
final lidarrQueueProvider =
    FutureProvider.autoDispose.family<List<QueueResource>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(lidarrQueuePollInterval);
  final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
  final ApiResponse<QueueResourcePagingResource> resp =
      await api.queue.getQueue(includeArtist: true, includeAlbum: true);
  final QueueResourcePagingResource page =
      unwrapLidarrApiResponse(resp, 'Failed to load download queue');
  return page.records ?? <QueueResource>[];
});

/// Paginated activity history provider. Key is `(Instance, {int page, int pageSize, List<int>? eventType})`.
final lidarrHistoryPagedProvider = FutureProvider.family<
    HistoryResourcePagingResource,
    (Instance, {int page, int pageSize, List<int>? eventType})>(
  (
    Ref ref,
    (Instance, {int page, int pageSize, List<int>? eventType}) key,
  ) async {
    final (
      Instance instance,
      page: int page,
      pageSize: int pageSize,
      eventType: List<int>? eventType,
    ) = key;
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<HistoryResourcePagingResource> resp =
        await api.history.getHistory(
      page: page,
      pageSize: pageSize,
      eventType: eventType,
      sortKey: 'date',
      sortDirection: SortDirection.descending,
      includeArtist: true,
      includeAlbum: true,
      includeTrack: true,
    );
    return unwrapLidarrApiResponse(resp, 'Failed to load activity history');
  },
);

/// Activity history for an instance (initial 50 records).
final lidarrHistoryProvider =
    FutureProvider.autoDispose.family<List<HistoryResource>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final HistoryResourcePagingResource page = await ref.watch(
    lidarrHistoryPagedProvider(
      (
        instance,
        page: 1,
        pageSize: 50,
        eventType: null,
      ),
    ).future,
  );
  return page.records ?? <HistoryResource>[];
});

/// Activity history for a specific artist.
final lidarrArtistHistoryProvider =
    FutureProvider.autoDispose.family<List<HistoryResource>, (Instance, int)>(
  (Ref ref, (Instance, int) key) async {
    final (Instance instance, int artistId) = key;
    final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
    final ApiResponse<List<HistoryResource>> resp =
        await api.history.getHistoryArtist(
      artistId: artistId,
      includeArtist: true,
      includeAlbum: true,
      includeTrack: true,
    );
    return unwrapLidarrApiResponse(
      resp,
      'Failed to load history for artist $artistId',
    );
  },
);

/// Blocklisted releases for an instance.
final lidarrBlocklistProvider =
    FutureProvider.autoDispose.family<List<BlocklistResource>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final LidarrApi api = await ref.watch(lidarrApiProvider(instance).future);
  final ApiResponse<BlocklistResourcePagingResource> resp =
      await api.blocklist.getBlocklist(pageSize: 50);
  final BlocklistResourcePagingResource page =
      unwrapLidarrApiResponse(resp, 'Failed to load blocklist');
  return page.records ?? <BlocklistResource>[];
});

/// Search query for the Activity tab.
final lidarrActivitySearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Persistent grouping preference for the Activity tab (true = Grouped by Artist/Date, false = Plain List).
final lidarrActivityGroupedProvider =
    NotifierProvider.family<LidarrActivityGroupedNotifier, bool, Instance>(
  LidarrActivityGroupedNotifier.new,
);

class LidarrActivityGroupedNotifier extends Notifier<bool> {
  LidarrActivityGroupedNotifier(this.instance);

  final Instance instance;

  static String _keyFor(String instanceId) =>
      'lidarr.activity.grouped.$instanceId';

  Box<String>? get _box => Hive.isBoxOpen(AtriumBoxes.settings)
      ? Hive.box<String>(AtriumBoxes.settings)
      : null;

  @override
  bool build() {
    final String? raw = _box?.get(_keyFor(instance.id));
    if (raw == 'false') return false;
    if (raw == 'true') return true;
    return true; // Default grouped
  }

  void setGrouped(bool grouped) {
    state = grouped;
    _box?.put(_keyFor(instance.id), grouped.toString());
  }

  void toggle() {
    setGrouped(!state);
  }
}

/// Multi-selection item IDs for Queue.
final lidarrQueueSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Multi-selection item IDs for Blocklist.
final lidarrBlocklistSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Event type filter for the History view (null = All events).
final lidarrHistoryEventTypeFilterProvider =
    StateProvider.family<EntityHistoryEventType?, Instance>(
  (ref, instance) => null,
);
