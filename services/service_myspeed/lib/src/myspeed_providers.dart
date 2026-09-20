import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/myspeed_config.dart';
import 'models/myspeed_status.dart';
import 'models/myspeed_storage.dart';
import 'models/myspeed_test.dart';
import 'myspeed_api.dart';

/// Active bottom navbar tab index for [instance] (0: Status, 1: History, 2: Config).
final myspeedActiveTabBarIndexProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 0);

/// Provides a [MySpeedApi] client instance configured for the given [Instance].
final myspeedApiProvider =
    FutureProvider.autoDispose.family<MySpeedApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  return MySpeedApi(dio);
});

/// Fetches the current speedtest execution status from `GET /api/speedtests/status`.
final myspeedStatusProvider =
    FutureProvider.autoDispose.family<MySpeedStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  final MySpeedApi api = await ref.watch(myspeedApiProvider(instance).future);
  return api.getSpeedtestStatus();
});

/// Notifier that caches historical speedtests in memory across tab switches.
///
/// Reads the whole history from `GET /api/speedtests` once (the server's
/// default is one day and ten rows, so the window and the cap are spelled
/// out) and retains it.
/// Calling [fetchDiff] queries only the latest batch and prepends newly created
/// tests without reloading the entire dataset, avoiding UI lag.
class MySpeedHistoryNotifier extends AsyncNotifier<List<MySpeedTest>> {
  MySpeedHistoryNotifier(this.instance);

  final Instance instance;

  @override
  Future<List<MySpeedTest>> build() async {
    final MySpeedApi api = await ref.watch(myspeedApiProvider(instance).future);
    return api.getSpeedtests(
      hours: MySpeedApi.historyHours,
      limit: MySpeedApi.pageLimit,
    );
  }

  /// Incremental update: fetches only the most recent tests (limit: 10)
  /// and prepends any new tests not present in local state.
  Future<void> fetchDiff() async {
    final List<MySpeedTest>? current = state.asData?.value;
    if (current == null || current.isEmpty) {
      ref.invalidateSelf();
      return;
    }

    try {
      final MySpeedApi api = await ref.read(myspeedApiProvider(instance).future);
      final List<MySpeedTest> latestBatch = await api.getSpeedtests(limit: 10);

      final Set<String> existingIds = current.map((MySpeedTest t) => t.id).toSet();
      final List<MySpeedTest> newItems = latestBatch
          .where((MySpeedTest t) => !existingIds.contains(t.id))
          .toList();

      if (newItems.isNotEmpty) {
        final List<MySpeedTest> merged = <MySpeedTest>[
          ...newItems,
          ...current,
        ];
        merged.sort((a, b) {
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        state = AsyncData<List<MySpeedTest>>(merged);
      }
    } catch (_) {
      // Non-fatal background diff check
    }
  }

  /// Full reload of all speedtests (e.g. on manual pull-to-refresh).
  Future<void> reload() async {
    state = const AsyncLoading<List<MySpeedTest>>();
    state = await AsyncValue.guard(() async {
      final MySpeedApi api = await ref.read(myspeedApiProvider(instance).future);
      return api.getSpeedtests(
      hours: MySpeedApi.historyHours,
      limit: MySpeedApi.pageLimit,
    );
    });
  }
}

/// Provider for historical speedtests.
///
/// Kept alive in memory so that switching between tabs never triggers
/// repeated network requests.
final myspeedHistoryProvider = AsyncNotifierProvider.family<
    MySpeedHistoryNotifier,
    List<MySpeedTest>,
    Instance>(MySpeedHistoryNotifier.new);

/// Fetches only the last 24 hours of speedtest results from `GET /api/speedtests?hours=24`.
final myspeed24HourTestsProvider =
    FutureProvider.autoDispose.family<List<MySpeedTest>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final MySpeedApi api = await ref.watch(myspeedApiProvider(instance).future);
  return api.get24HourSpeedtests();
});

/// Provides the single most recent speedtest result, or null if no results exist.
final myspeedLatestTestProvider =
    Provider.autoDispose.family<MySpeedTest?, Instance>((
  Ref ref,
  Instance instance,
) {
  final AsyncValue<List<MySpeedTest>> recent24h =
      ref.watch(myspeed24HourTestsProvider(instance));
  final List<MySpeedTest>? list24h = recent24h.asData?.value;
  if (list24h != null && list24h.isNotEmpty) {
    return list24h.first;
  }
  final AsyncValue<List<MySpeedTest>> history =
      ref.watch(myspeedHistoryProvider(instance));
  final List<MySpeedTest>? historyList = history.asData?.value;
  if (historyList != null && historyList.isNotEmpty) {
    return historyList.first;
  }
  return null;
});

/// Fetches server configuration from `GET /api/config`.
final myspeedConfigProvider =
    FutureProvider.autoDispose.family<MySpeedConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final MySpeedApi api = await ref.watch(myspeedApiProvider(instance).future);
  return api.getConfig();
});

/// Fetches database and storage information from `GET /api/storage`.
final myspeedStorageProvider =
    FutureProvider.autoDispose.family<MySpeedStorage, Instance>((
  Ref ref,
  Instance instance,
) async {
  final MySpeedApi api = await ref.watch(myspeedApiProvider(instance).future);
  return api.getStorage();
});

/// The newest few tests across the whole history, for the dashboard: the
/// latest good run and whether a newer one failed, without the day's window
/// (a weekly schedule has no run in the last 24 hours) and without the
/// History tab's thousand rows.
final myspeedRecentTestsProvider =
    FutureProvider.autoDispose.family<List<MySpeedTest>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final MySpeedApi api = await ref.watch(myspeedApiProvider(instance).future);
  return api.getSpeedtests(hours: MySpeedApi.historyHours, limit: 5);
});

/// The newest run that produced figures, or null. A failed run is a row
/// with an error and no speeds, which is not what a card should show.
MySpeedTest? myspeedLatestGood(List<MySpeedTest>? tests) {
  if (tests == null) return null;
  for (final MySpeedTest test in tests) {
    if (test.error == null) return test;
  }
  return null;
}
