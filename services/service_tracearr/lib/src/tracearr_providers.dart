import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/tracearr_auth_interceptor.dart';
import 'auth/tracearr_auth_manager.dart';
import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_activity_locations.dart';
import 'models/tracearr_activity_stats.dart';
import 'models/tracearr_dashboard_stats.dart';
import 'models/tracearr_session.dart';
import 'models/tracearr_stats.dart';
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

  if (res.data is Map<String, dynamic>) {
    final Map<String, dynamic> data = res.data as Map<String, dynamic>;
    if (data['data'] is List) {
      for (final dynamic server in data['data'] as List<dynamic>) {
        if (server is Map<String, dynamic>) {
          final String? id = server['id'] as String?;
          final String? url = server['url'] as String?;
          if (id != null && url != null) {
            serverMap[id] = url.replaceAll(RegExp(r'/+$'), '');
          }
        }
      }
    }
  }
  return serverMap;
});

final tracearrSessionsProvider = FutureProvider.family
    .autoDispose<TracearrActiveSessions, Instance>(
        (Ref ref, Instance instance) async {
  // Poll every 5s while someone is watching
  final CancelToken token = CancelToken();
  ref.onDispose(token.cancel);
  final Stream<void> tick = Stream<void>.periodic(const Duration(seconds: 5));
  final ProviderSubscription<void> sub = ref.listen(
    StreamProvider<void>((_) => tick),
    (_, __) {},
  );
  ref.onDispose(sub.close);

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  return api.getActiveSessions();
});

final tracearrStatsProvider = FutureProvider.family
    .autoDispose<TracearrStats, Instance>((Ref ref, Instance instance) async {
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  return api.getStats(serverIds, DateTime.now().timeZoneName);
});

final tracearrActivityStatsProvider = FutureProvider.family
    .autoDispose<TracearrActivityStats, Instance>((Ref ref, Instance instance) async {
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  return api.getActivityStats(serverIds, DateTime.now().timeZoneName);
});

final tracearrActivityLocationsProvider = FutureProvider.family
    .autoDispose<TracearrActivityLocationsResponse, Instance>((Ref ref, Instance instance) async {
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  return api.getLocations(serverIds, DateTime.now().timeZoneName);
});

final tracearrDashboardStatsProvider = FutureProvider.family
    .autoDispose<TracearrDashboardStats, Instance>((Ref ref, Instance instance) async {
  final Map<String, String> servers =
      await ref.watch(tracearrServersProvider(instance).future);
  final List<String> serverIds = servers.keys.toList();

  final TracearrApi api = await ref.watch(tracearrApiProvider(instance).future);
  return api.getDashboardStats(serverIds, DateTime.now().timeZoneName);
});

class TracearrHistoryNotifier extends ChangeNotifier {
  TracearrHistoryNotifier(this.ref, this.instance) {
    _init();
  }

  final Ref ref;
  final Instance instance;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  AsyncValue<List<TracearrSession>> state = const AsyncValue.loading();

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
}

final tracearrHistoryProvider = Provider.family.autoDispose<
    TracearrHistoryNotifier, Instance>(
  TracearrHistoryNotifier.new,
);
