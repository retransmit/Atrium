import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'auth/tracearr_auth_interceptor.dart';
import 'auth/tracearr_auth_manager.dart';
import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_activity_locations.dart';
import 'models/tracearr_activity_stats.dart';
import 'models/tracearr_completion.dart';
import 'models/tracearr_dashboard_stats.dart';
import 'models/tracearr_library_roi.dart';
import 'models/tracearr_library_storage.dart';
import 'models/tracearr_library_watch_activity.dart';
import 'models/tracearr_patterns.dart';
import 'models/tracearr_session.dart';
import 'models/tracearr_stats.dart';
import 'models/tracearr_top_movies.dart';
import 'models/tracearr_top_shows.dart';
import 'tracearr_api.dart';

final tracearrAuthManagerProvider =
    FutureProvider.family<TracearrAuthManager, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ConnectionResolver resolver = ref.watch(connectionResolverProvider);
  final Uri baseUrl = await resolver.resolve(instance);

  final Dio dio = await ref.watch(dioFactoryProvider).create(instance);

  return TracearrAuthManager(
    baseUrl: baseUrl,
    auth: instance.auth,
    dio: dio,
  );
});

final tracearrApiProvider = FutureProvider.family<TracearrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(dioFactoryProvider).create(instance);

  final TracearrAuthManager manager = await ref.watch(
    tracearrAuthManagerProvider(instance).future,
  );

  dio.interceptors.add(
    TracearrAuthInterceptor(
      manager: manager,
      dio: dio,
    ),
  );

  final String token = await manager.ensureToken();
  return TracearrApi(dio, token: token);
});

final tracearrServersProvider = FutureProvider.family
    .autoDispose<Map<String, String>, Instance>(
        (Ref ref, Instance instance) async {
  final Dio dio = await ref.watch(dioFactoryProvider).create(instance);
  final TracearrAuthManager manager =
      await ref.watch(tracearrAuthManagerProvider(instance).future);
  dio.interceptors.add(TracearrAuthInterceptor(manager: manager, dio: dio));

  final Response<dynamic> res = await dio.get<dynamic>('api/v1/servers');
  final Map<String, String> serverMap = <String, String>{};

  dynamic rawList;
  if (res.data is Map) {
    final Map<dynamic, dynamic> mapData = res.data as Map<dynamic, dynamic>;
    if (mapData['data'] is List) {
      rawList = mapData['data'];
    } else if (mapData['servers'] is List) {
      rawList = mapData['servers'];
    }
  } else if (res.data is List) {
    rawList = res.data;
  }

  if (rawList is List) {
    for (final dynamic server in rawList) {
      if (server is Map) {
        final String? id = server['id']?.toString() ??
            server['serverId']?.toString() ??
            server['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          final String name = server['name']?.toString() ??
              server['url']?.toString() ??
              server['type']?.toString() ??
              id;
          serverMap[id] = name;
        }
      }
    }
  }
  return serverMap;
});

final tracearrSessionsProvider = FutureProvider.family
    .autoDispose<TracearrActiveSessions, Instance>(
        (Ref ref, Instance instance) async {
  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  final TracearrActiveSessions data = await api.getActiveSessions();
  final bool hasActiveStreams = data.sessions.isNotEmpty;
  ref.pollEvery(hasActiveStreams ? const Duration(seconds: 5) : const Duration(seconds: 10));
  return data;
});

Future<String>? _tzFuture;
Future<String> _getTimezone() {
  if (_tzFuture != null) return _tzFuture!;
  _tzFuture = _fetchTz();
  return _tzFuture!;
}

Future<String> _fetchTz() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (e) {
    return DateTime.now().timeZoneName;
  }
}

class TracearrStatsFilterParams {
  const TracearrStatsFilterParams({
    required this.instance,
    this.period = 'month',
    this.from,
    this.to,
  });

  final Instance instance;
  final String period;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TracearrStatsFilterParams &&
        other.instance == instance &&
        other.period == period &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(instance, period, from, to);
}

typedef TracearrActivityStatsParams = TracearrStatsFilterParams;

final tracearrStatsProvider = FutureProvider.family
    .autoDispose<TracearrStats, TracearrStatsFilterParams>((Ref ref, TracearrStatsFilterParams params) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(params.instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(params.instance).future);
  final String timezone = await _getTimezone();
  return api.getStats(
    serverIds,
    timezone,
    period: params.period,
    from: params.from,
    to: params.to,
  );
});

final tracearrStorageGrowthProvider = FutureProvider.family
    .autoDispose<Map<String, TracearrStorageResponse>, TracearrStatsFilterParams>((Ref ref, TracearrStatsFilterParams params) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(params.instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(params.instance).future);
  final String timezone = await _getTimezone();
  
  String periodParam = params.period;
  if (periodParam == 'month' || periodParam == '30d') {
    periodParam = '30d';
  } else if (periodParam == 'week' || periodParam == '7d') {
    periodParam = '7d';
  } else if (periodParam == 'year' || periodParam == '1yr' || periodParam == '1y') {
    periodParam = '1y';
  } else if (periodParam.toLowerCase() == 'all') {
    periodParam = 'all';
  } else if (periodParam == 'custom') {
    periodParam = '30d';
  }

  return api.getMultiServerLibraryStorage(
    serverIds,
    periodParam,
    timezone,
  );
});

final tracearrActivityStatsProvider = FutureProvider.family
    .autoDispose<TracearrActivityStats, TracearrActivityStatsParams>((Ref ref, TracearrActivityStatsParams params) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(params.instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(params.instance).future);
  final String timezone = await _getTimezone();
  return api.getActivityStats(
    serverIds,
    timezone,
    period: params.period,
    from: params.from,
    to: params.to,
  );
});

final tracearrActivityLocationsProvider = FutureProvider.family
    .autoDispose<TracearrActivityLocationsResponse, Instance>((Ref ref, Instance instance) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  final String timezone = await _getTimezone();
  return api.getLocations(serverIds, timezone);
});

final tracearrDashboardStatsProvider = FutureProvider.family
    .autoDispose<TracearrDashboardStats, Instance>((Ref ref, Instance instance) async {
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  final String timezone = await _getTimezone();
  final TracearrDashboardStats stats = await api.getDashboardStats(serverIds, timezone);
  final AsyncValue<TracearrActiveSessions>? sessionsVal = ref.read(tracearrSessionsProvider(instance));
  final bool hasActiveStreams = sessionsVal?.value?.sessions.isNotEmpty == true;
  ref.pollEvery(hasActiveStreams ? const Duration(seconds: 5) : const Duration(seconds: 10));
  return stats;
});

class TracearrHistoryNotifier extends ChangeNotifier {
  TracearrHistoryNotifier(this.ref, this.instance) {
    _init();
    _startPolling();
  }

  final Ref ref;
  final Instance instance;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _pollingTimer;

  bool get hasMore => _hasMore;

  AsyncValue<List<TracearrSession>> state = const AsyncValue.loading();

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final AppLifecycleState? lifecycleState = SchedulerBinding.instance.lifecycleState;
      if (lifecycleState == null || lifecycleState == AppLifecycleState.resumed) {
        if (!_isLoadingMore && _page == 1) {
          _silentRefresh();
        }
      }
    });
  }

  Future<void> _silentRefresh() async {
    try {
      final List<TracearrSession> data = await _fetchPage(1);
      state = AsyncValue.data(data);
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _init() async {
    try {
      final List<TracearrSession> data = await _fetchPage(1);
      state = AsyncValue.data(data);
      notifyListeners();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      notifyListeners();
    }
  }

  Future<List<TracearrSession>> _fetchPage(int page) async {
    final Map<String, String> servers =
        await ref.read(tracearrServersProvider(instance).future);
    final List<String> serverIds = servers.keys.toList();

    final TracearrApi api = await ref.read(tracearrApiProvider(instance).future);
    final List<TracearrSession> data = await api.getHistory(serverIds, page: page);

    if (data.length < 50) {
      _hasMore = false;
    }
    return data;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    final List<TracearrSession>? current = state.value;
    if (current == null) return;

    _isLoadingMore = true;

    try {
      final List<TracearrSession> nextData = await _fetchPage(_page + 1);
      _page++;
      state = AsyncValue.data(<TracearrSession>[
        ...current,
        ...nextData,
      ]);
      notifyListeners();
    } catch (e) {
      // ignore
    } finally {
      _isLoadingMore = false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final tracearrHistoryProvider = Provider.family.autoDispose<
    TracearrHistoryNotifier, Instance>(
  TracearrHistoryNotifier.new,
);

class TracearrRoiNotifier extends ChangeNotifier {
  TracearrRoiNotifier(this.ref, this.instance) {
    _fetch();
    _startPolling();
  }

  final Ref ref;
  final Instance instance;
  int page = 1;
  int pageSize = 10;
  String sortBy = 'watch_hours_per_gb';
  String sortOrder = 'desc';
  Timer? _pollingTimer;

  AsyncValue<TracearrLibraryRoiResponse> state = const AsyncValue.loading();

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final AppLifecycleState? lifecycleState = SchedulerBinding.instance.lifecycleState;
      if (lifecycleState == null || lifecycleState == AppLifecycleState.resumed) {
        _fetch();
      }
    });
  }

  Future<void> _fetch({bool isRefresh = false}) async {
    if (isRefresh) {
      state = const AsyncValue.loading();
      notifyListeners();
    }
    try {
      final Map<String, String> servers = await ref.read(tracearrServersProvider(instance).future);
      final List<String> serverIds = servers.keys.toList();
      final TracearrApi api = await ref.read(tracearrApiProvider(instance).future);
      final String timezone = await _getTimezone();

      final TracearrLibraryRoiResponse res = await api.getLibraryRoiItems(
        serverIds: serverIds,
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        timezone: timezone,
      );

      state = AsyncValue.data(res);
      notifyListeners();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    ref.invalidate(tracearrServersProvider(instance));
    await _fetch(isRefresh: true);
  }

  void setSort(String field) {
    if (sortBy == field) {
      sortOrder = sortOrder == 'desc' ? 'asc' : 'desc';
    } else {
      sortBy = field;
      sortOrder = 'desc';
    }
    page = 1;
    _fetch(isRefresh: true);
  }

  void nextPage() {
    final TracearrLibraryRoiResponse? data = state.value;
    if (data != null && (page * pageSize) < data.pagination.total) {
      page++;
      _fetch(isRefresh: true);
    }
  }

  void previousPage() {
    if (page > 1) {
      page--;
      _fetch(isRefresh: true);
    }
  }

  void setPage(int targetPage) {
    if (targetPage == page || targetPage < 1) {
      return;
    }
    final TracearrLibraryRoiResponse? data = state.value;
    if (data != null) {
      final int totalPages = (data.pagination.total + pageSize - 1) ~/ pageSize;
      if (targetPage > totalPages && totalPages > 0) {
        return;
      }
    }
    page = targetPage;
    _fetch(isRefresh: true);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final tracearrRoiProvider = Provider.family.autoDispose<
    TracearrRoiNotifier, Instance>(
  TracearrRoiNotifier.new,
);

final tracearrTopMoviesProvider = FutureProvider.family.autoDispose<
    TracearrTopMoviesResponse, ({Instance instance, String period})>((
  Ref ref,
  ({Instance instance, String period}) params,
) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers = await ref.watch(tracearrServersProvider(params.instance).future);
  final List<String> serverIds = servers.keys.toList();
  final TracearrApi api = await ref.watch(tracearrApiProvider(params.instance).future);
  return api.getTopMovies(serverIds: serverIds, period: params.period);
});

final tracearrTopShowsProvider = FutureProvider.family.autoDispose<
    TracearrTopShowsResponse, ({Instance instance, String period})>((
  Ref ref,
  ({Instance instance, String period}) params,
) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers = await ref.watch(tracearrServersProvider(params.instance).future);
  final List<String> serverIds = servers.keys.toList();
  final TracearrApi api = await ref.watch(tracearrApiProvider(params.instance).future);
  return api.getTopShows(serverIds: serverIds, period: params.period);
});

final tracearrCompletionSummaryProvider = FutureProvider.family.autoDispose<
    TracearrCompletionSummary, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers = await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();
  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  return api.getAggregatedLibraryCompletion(serverIds);
});

final tracearrPatternsProvider = FutureProvider.family.autoDispose<
    TracearrPatternsResponse, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(const Duration(seconds: 10));
  final Map<String, String> servers = await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();
  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  final String timezone = await _getTimezone();
  return api.getLibraryPatterns(serverIds: serverIds, timezone: timezone);
});

class TracearrLibraryWatchNotifier extends ChangeNotifier {
  TracearrLibraryWatchNotifier(this.ref, this.instance) {
    _fetch();
    _startPolling();
  }

  final Ref ref;
  final Instance instance;
  int page = 1;
  int pageSize = 20;
  Timer? _pollingTimer;

  AsyncValue<TracearrLibraryWatchResponse> state = const AsyncValue.loading();

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final AppLifecycleState? lifecycleState = SchedulerBinding.instance.lifecycleState;
      if (lifecycleState == null || lifecycleState == AppLifecycleState.resumed) {
        _fetch();
      }
    });
  }

  Future<void> _fetch({bool isRefresh = false}) async {
    if (isRefresh) {
      state = const AsyncValue.loading();
      notifyListeners();
    }
    try {
      final Map<String, String> servers = await ref.read(tracearrServersProvider(instance).future);
      final List<String> serverIds = servers.keys.toList();
      final TracearrApi api = await ref.read(tracearrApiProvider(instance).future);

      final TracearrLibraryWatchResponse res = await api.getLibraryWatchItems(
        serverIds: serverIds,
        page: page,
        pageSize: pageSize,
      );

      state = AsyncValue.data(res);
      notifyListeners();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    ref.invalidate(tracearrServersProvider(instance));
    await _fetch(isRefresh: true);
  }

  void nextPage() {
    final TracearrLibraryWatchResponse? data = state.value;
    if (data != null && (page * pageSize) < data.pagination.total) {
      page++;
      _fetch(isRefresh: true);
    }
  }

  void previousPage() {
    if (page > 1) {
      page--;
      _fetch(isRefresh: true);
    }
  }

  void setPage(int targetPage) {
    if (targetPage == page || targetPage < 1) {
      return;
    }
    final TracearrLibraryWatchResponse? data = state.value;
    if (data != null) {
      final int totalPages = (data.pagination.total + pageSize - 1) ~/ pageSize;
      if (targetPage > totalPages && totalPages > 0) {
        return;
      }
    }
    page = targetPage;
    _fetch(isRefresh: true);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final tracearrLibraryWatchProvider = Provider.family.autoDispose<
    TracearrLibraryWatchNotifier, Instance>(
  TracearrLibraryWatchNotifier.new,
);

