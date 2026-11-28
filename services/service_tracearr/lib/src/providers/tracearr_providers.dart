import 'dart:async';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_ce/hive.dart';
import '../cache/tracearr_artwork_cache.dart';
import '../generated/api/raw_public_a_p_i_api.dart';
import '../generated/api/raw_public_a_p_i_v2_api.dart';
import '../models/tracearr_models.dart';
import '../repository/tracearr_repository.dart';

/// Provider for Hive box initialization for artwork cache.
final tracearrArtworkBoxProvider = FutureProvider<Box<String>?>((ref) async {
  try {
    if (Hive.isBoxOpen(TracearrArtworkCache.boxName)) {
      return Hive.box<String>(TracearrArtworkCache.boxName);
    }
    return await Hive.openBox<String>(TracearrArtworkCache.boxName);
  } catch (_) {
    return null;
  }
});

/// Provider for the singleton TracearrArtworkCache instance.
final tracearrArtworkCacheProvider = Provider<TracearrArtworkCache>((ref) {
  final boxAsync = ref.watch(tracearrArtworkBoxProvider);
  final box = boxAsync.asData?.value;
  return TracearrArtworkCache(box: box);
});

/// Provider for raw Tracearr OpenAPI v1 API client bound to an [Instance].
final tracearrV1ApiProvider =
    FutureProvider.family<RawPublicAPIApi, Instance>((ref, instance) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return RawPublicAPIApi(dio);
});

/// Provider for raw Tracearr OpenAPI v2 API client bound to an [Instance].
final tracearrV2ApiProvider =
    FutureProvider.family<RawPublicAPIV2Api, Instance>((ref, instance) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return RawPublicAPIV2Api(dio);
});

/// Provider for TracearrRepository using shared [instanceDioProvider].
final tracearrRepositoryProvider =
    FutureProvider.family<TracearrRepository, Instance>((ref, instance) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  final apiV2 = RawPublicAPIV2Api(dio);
  RawPublicAPIApi? apiV1;
  try {
    apiV1 = RawPublicAPIApi(dio);
  } catch (_) {}
  final cache = ref.watch(tracearrArtworkCacheProvider);
  final baseUrl = dio.options.baseUrl;
  return TracearrRepository(
    apiV2: apiV2,
    apiV1: apiV1,
    artworkCache: cache,
    baseUrl: baseUrl,
  );
});

/// Provider for active streams bound to an [Instance].
///
/// Polls on the instance's own configured interval through [PollingRef.polled],
/// which arms the next tick only after the current run settles, backs off on
/// error and stops while the app is backgrounded. A bare `Timer.periodic` here
/// would keep hitting the server forever, because a non-autoDispose family
/// provider is never disposed and its `onDispose` never runs.
final tracearrStreamsProvider =
    FutureProvider.autoDispose.family<List<TracearrStream>, Instance>(
  (ref, instance) => ref.polled(
    Duration(seconds: instance.pollingIntervalSeconds),
    () async {
      final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
      return repo.getStreams();
    },
  ),
);

/// Provider for watch history bound to an [Instance].
final tracearrHistoryProvider =
    FutureProvider.autoDispose.family<List<TracearrHistoryItem>, Instance>(
        (ref, instance) async {
  final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
  return repo.getHistory();
});

/// State for paginated history items.
class TracearrHistoryPaginatedState {
  const TracearrHistoryPaginatedState({
    this.items = const [],
    this.nextCursor,
    this.isLoadingInitial = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<TracearrHistoryItem> items;
  final String? nextCursor;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final Object? error;

  bool get hasMore => nextCursor != null || isLoadingInitial;

  TracearrHistoryPaginatedState copyWith({
    List<TracearrHistoryItem>? items,
    String? nextCursor,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    bool clearNextCursor = false,
  }) {
    return TracearrHistoryPaginatedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TracearrHistoryPaginatedNotifier
    extends StateNotifier<TracearrHistoryPaginatedState> {
  TracearrHistoryPaginatedNotifier(this.ref, this.instance)
      : super(const TracearrHistoryPaginatedState()) {
    _loadInitial();
  }

  final Ref ref;
  final Instance instance;
  int _loadGeneration = 0;

  Future<void> _loadInitial() async {
    final currentGen = ++_loadGeneration;
    try {
      state = state.copyWith(isLoadingInitial: true, clearError: true);
      final repo = await ref.read(tracearrRepositoryProvider(instance).future);
      final page = await repo.getHistoryPage();
      if (!mounted || currentGen != _loadGeneration) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingInitial: false,
      );
    } catch (e) {
      if (!mounted || currentGen != _loadGeneration) return;
      state = state.copyWith(isLoadingInitial: false, error: e);
    }
  }

  Future<bool> loadMore() async {
    if (state.isLoadingMore ||
        state.isLoadingInitial ||
        state.nextCursor == null) {
      return false;
    }
    final currentGen = ++_loadGeneration;
    try {
      state = state.copyWith(isLoadingMore: true);
      final repo = await ref.read(tracearrRepositoryProvider(instance).future);
      final page = await repo.getHistoryPage(cursor: state.nextCursor);
      if (!mounted || currentGen != _loadGeneration) return false;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
      return page.nextCursor != null;
    } catch (e) {
      if (!mounted || currentGen != _loadGeneration) return false;
      state = state.copyWith(isLoadingMore: false);
      return false;
    }
  }

  Future<void> refresh() async {
    await _loadInitial();
  }
}

final tracearrHistoryPaginatedProvider = StateNotifierProvider.family<
    TracearrHistoryPaginatedNotifier,
    TracearrHistoryPaginatedState,
    Instance>(TracearrHistoryPaginatedNotifier.new);

/// State for paginated recently added items.
class TracearrRecentPaginatedState {
  const TracearrRecentPaginatedState({
    this.items = const [],
    this.nextCursor,
    this.isLoadingInitial = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<TracearrRecentlyAddedItem> items;
  final String? nextCursor;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final Object? error;

  bool get hasMore => nextCursor != null || isLoadingInitial;

  TracearrRecentPaginatedState copyWith({
    List<TracearrRecentlyAddedItem>? items,
    String? nextCursor,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    bool clearNextCursor = false,
  }) {
    return TracearrRecentPaginatedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TracearrRecentPaginatedNotifier
    extends StateNotifier<TracearrRecentPaginatedState> {
  TracearrRecentPaginatedNotifier(this.ref, this.instance)
      : super(const TracearrRecentPaginatedState()) {
    ref.listen<String>(tracearrSelectedLibraryFilterProvider(instance),
        (previous, next) {
      _loadInitial();
    });
    _loadInitial();
  }

  final Ref ref;
  final Instance instance;
  int _loadGeneration = 0;

  Future<void> _loadInitial() async {
    final currentGen = ++_loadGeneration;
    try {
      state = state.copyWith(isLoadingInitial: true, clearError: true);
      final repo = await ref.read(tracearrRepositoryProvider(instance).future);
      final selectedLib =
          ref.read(tracearrSelectedLibraryFilterProvider(instance));
      final page = await repo.getRecentlyAddedPage(
        libraryId: selectedLib == 'all' ? null : selectedLib,
      );
      if (!mounted || currentGen != _loadGeneration) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingInitial: false,
      );
    } catch (e) {
      if (!mounted || currentGen != _loadGeneration) return;
      state = state.copyWith(isLoadingInitial: false, error: e);
    }
  }

  Future<bool> loadMore() async {
    if (state.isLoadingMore ||
        state.isLoadingInitial ||
        state.nextCursor == null) {
      return false;
    }
    final currentGen = ++_loadGeneration;
    try {
      state = state.copyWith(isLoadingMore: true);
      final repo = await ref.read(tracearrRepositoryProvider(instance).future);
      final selectedLib =
          ref.read(tracearrSelectedLibraryFilterProvider(instance));
      final page = await repo.getRecentlyAddedPage(
        cursor: state.nextCursor,
        libraryId: selectedLib == 'all' ? null : selectedLib,
      );
      if (!mounted || currentGen != _loadGeneration) return false;
      final existingIds = state.items.map((i) => i.id).toSet();
      final uniqueNewItems =
          page.items.where((i) => !existingIds.contains(i.id)).toList();
      state = state.copyWith(
        items: [...state.items, ...uniqueNewItems],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
      return page.nextCursor != null;
    } catch (e) {
      if (!mounted || currentGen != _loadGeneration) return false;
      state = state.copyWith(isLoadingMore: false);
      return false;
    }
  }

  Future<void> refresh() async {
    await _loadInitial();
  }
}

final tracearrRecentPaginatedProvider = StateNotifierProvider.family<
    TracearrRecentPaginatedNotifier,
    TracearrRecentPaginatedState,
    Instance>(TracearrRecentPaginatedNotifier.new);

/// Provider for recently added items bound to an [Instance].
final tracearrRecentlyAddedProvider =
    FutureProvider.autoDispose.family<List<TracearrRecentlyAddedItem>, Instance>(
        (ref, instance) async {
  final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
  final selectedLibrary =
      ref.watch(tracearrSelectedLibraryFilterProvider(instance));
  return repo.getRecentlyAdded(
    libraryId: selectedLibrary == 'all' ? null : selectedLibrary,
  );
});

/// Provider for per-library rollups bound to an [Instance].
final tracearrLibrariesProvider =
    FutureProvider.autoDispose.family<List<TracearrLibrary>, Instance>(
        (ref, instance) async {
  final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
  return repo.getLibraries();
});

/// StateProvider for selected library filter in Recently Added tab.
final tracearrSelectedLibraryFilterProvider =
    StateProvider.family<String, Instance>((ref, instance) => 'all');

/// Provider for registered user directory bound to an [Instance].
final tracearrUsersProvider =
    FutureProvider.autoDispose.family<List<TracearrUserSummary>, Instance>(
        (ref, instance) async {
  final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
  return repo.getUsers();
});

/// Provider for security rule violations audit log bound to an [Instance].
final tracearrViolationsProvider =
    FutureProvider.autoDispose.family<List<TracearrViolationItem>, Instance>(
        (ref, instance) async {
  final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
  return repo.getViolations();
});

/// Family provider for user details per (Instance, userId).
final tracearrUserDetailProvider =
    FutureProvider.autoDispose.family<TracearrUserDetail, (Instance, String)>(
        (ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  return repo.getUserDetail(arg.$2);
});

/// Family provider for media details per (Instance, refKey).
final tracearrMediaDetailProvider =
    FutureProvider.autoDispose.family<TracearrMediaDetail, (Instance, String)>(
        (ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  return repo.getMediaDetail(arg.$2);
});

/// Family provider for media children (seasons/episodes) per (Instance, refKey).
final tracearrMediaChildrenProvider =
    FutureProvider.autoDispose.family<List<TracearrMediaChild>, (Instance, String)>(
        (ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  return repo.getMediaChildren(arg.$2);
});

/// Provider for server health and connectivity bound to an [Instance].
final tracearrHealthProvider =
    FutureProvider.autoDispose.family<TracearrHealthResponse, Instance>(
        (ref, instance) async {
  final repo = await ref.watch(tracearrRepositoryProvider(instance).future);
  return repo.getHealth();
});

/// The device's IANA timezone (such as "America/Los_Angeles"), for the
/// queries Tracearr answers by calendar day. Null when the platform cannot
/// say, which leaves Tracearr on its default of UTC.
final tracearrDeviceTimezoneProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  try {
    final String zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    return zone.isEmpty ? null : zone;
  } catch (_) {
    return null;
  }
});

/// Provider for 24h fleet dashboard statistics per (Instance, serverId?, timezone?).
/// With no timezone, "today" is the device's today.
final tracearrTodayStatsProvider =
    FutureProvider.autoDispose.family<TracearrTodayStats, (Instance, String?, String?)>(
        (ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  final timezone =
      arg.$3 ?? await ref.watch(tracearrDeviceTimezoneProvider.future);
  return repo.getStatsToday(serverId: arg.$2, timezone: timezone);
});

/// Provider for playback activity trends per (Instance, period?, serverId?, timezone?).
/// With no timezone, plays are bucketed by the device's calendar days.
final tracearrActivityProvider = FutureProvider.autoDispose.family<TracearrActivityTrend,
    (Instance, String?, String?, String?)>((ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  final timezone =
      arg.$4 ?? await ref.watch(tracearrDeviceTimezoneProvider.future);
  return repo.getActivity(
    period: arg.$2 ?? 'week',
    serverId: arg.$3,
    timezone: timezone,
  );
});

/// Provider for 30-day dashboard aggregate stats per (Instance, serverId?).
final tracearrAggregateStatsProvider =
    FutureProvider.autoDispose.family<TracearrAggregateStats, (Instance, String?)>(
        (ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  return repo.getStats(serverId: arg.$2);
});

/// Family provider for dedicated media watch history per (Instance, refKey).
final tracearrMediaHistoryProvider =
    FutureProvider.autoDispose.family<TracearrHistoryPage, (Instance, String)>(
        (ref, arg) async {
  final repo = await ref.watch(tracearrRepositoryProvider(arg.$1).future);
  return repo.getMediaHistoryPage(ref: arg.$2);
});

/// Active destination index for TracearrHomeScreen per Instance (0: Overview, 1: Activity, 2: Media, 3: People, 4: Security).
final tracearrActiveTabProvider =
    StateProvider.family<int, Instance>((ref, instance) => 0);

/// Bottom navigation bar visibility for TracearrHomeScreen per Instance.
final tracearrBottomNavVisibleProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Scroll to top trigger count per (Instance, tabIndex).
final tracearrHomeScrollToTopProvider =
    StateProvider.family<int, (Instance, int)>((ref, key) => 0);
