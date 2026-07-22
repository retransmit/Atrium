import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'connection_resolver.dart';
import 'dio_factory.dart';

/// The app's [ConnectionResolver]. Overridden in `main()` with a started
/// instance (its connectivity subscription must be live before first use):
///
/// ```dart
/// final resolver = ConnectionResolver(connectivity: Connectivity());
/// await resolver.start();
/// ProviderScope(overrides: [
///   connectionResolverProvider.overrideWithValue(resolver),
/// ], child: ...);
/// ```
final Provider<ConnectionResolver> connectionResolverProvider =
    Provider<ConnectionResolver>((Ref ref) {
  throw UnimplementedError(
    'connectionResolverProvider must be overridden in main()',
  );
});

/// Builds [Dio] clients for instances, using the resolver above.
final Provider<DioFactory> dioFactoryProvider = Provider<DioFactory>((Ref ref) {
  return DioFactory(resolver: ref.watch(connectionResolverProvider));
});

/// Profile-wide HTTP headers applied to every instance request.
///
/// The app shell keeps this in sync with the active profile's
/// `globalHeaders`; the Dio factory and the self-built clients (Jellyfin,
/// Emby, qBittorrent) read it when constructing their clients. Per-instance
/// `customHeaders` win on key collision.
final StateProvider<Map<String, String>> globalHeadersProvider =
    StateProvider<Map<String, String>>((Ref ref) => const <String, String>{});

/// A [Dio] bound to a specific [Instance], with the right base URL and auth
/// wired in. Cached per instance value; closed automatically when no longer
/// watched.
final instanceDioProvider = FutureProvider.autoDispose.family<Dio, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Map<String, String> global = ref.watch(globalHeadersProvider);
  final Dio dio = await ref
      .watch(dioFactoryProvider)
      .create(instance, globalHeaders: global);
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
