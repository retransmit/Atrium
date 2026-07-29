import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';


import 'auth/tracearr_auth_interceptor.dart';
import 'auth/tracearr_auth_manager.dart';
import 'models/tracearr_active_sessions.dart';
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
    .autoDispose<Map<String, String>, Instance>((Ref ref, Instance instance) async {
  final Dio dio = await ref.watch(dioFactoryProvider).create(instance);
  final TracearrAuthManager manager = await ref.watch(tracearrAuthManagerProvider(instance).future);
  dio.interceptors.add(TracearrAuthInterceptor(manager: manager, dio: dio));
  
  final Response<dynamic> res = await dio.get<dynamic>('api/v1/servers');
  final Map<String, String> serverMap = <String, String>{};
  
  if (res.data is Map<String, dynamic> && res.data['data'] is List) {
    for (final dynamic server in res.data['data'] as List<dynamic>) {
      if (server is Map<String, dynamic>) {
        final String? id = server['id'] as String?;
        final String? url = server['url'] as String?;
        if (id != null && url != null) {
          serverMap[id] = url.replaceAll(RegExp(r'/+$'), '');
        }
      }
    }
  }
  return serverMap;
});

final tracearrSessionsProvider = FutureProvider.family
    .autoDispose<TracearrActiveSessions, Instance>((Ref ref, Instance instance) async {
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
