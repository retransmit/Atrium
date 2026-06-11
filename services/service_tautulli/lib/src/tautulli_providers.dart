import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/tautulli_activity.dart';
import 'tautulli_api.dart';

/// A [TautulliApi] for an instance, over the shared `instanceDioProvider`.
final FutureProviderFamily<TautulliApi, Instance> tautulliApiProvider =
    FutureProvider.family<TautulliApi, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final dio = await ref.watch(instanceDioProvider(instance).future);
      return TautulliApi(dio);
    });

/// Current activity (active streams) for an instance.
final FutureProviderFamily<TautulliActivity, Instance>
    tautulliActivityProvider =
    FutureProvider.family<TautulliActivity, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final TautulliApi api =
          await ref.watch(tautulliApiProvider(instance).future);
      return api.getActivity();
    });
