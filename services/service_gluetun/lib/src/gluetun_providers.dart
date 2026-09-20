import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gluetun_api.dart';
import 'models/gluetun_models.dart';

/// The Gluetun client for [instance].
///
/// Built on [instanceDioProvider] rather than straight off the factory, so the
/// client is closed when this provider is disposed instead of outliving it.
final gluetunApiProvider = FutureProvider.family<GluetunApi, Instance>(
  (Ref ref, Instance instance) async {
    final Dio dio = await ref.watch(instanceDioProvider(instance).future);
    return GluetunApi(dio);
  },
);

/// How often to poll, scaled from the instance's own setting.
///
/// Every provider below goes through `polled`, not `pollEvery`: the next tick
/// is armed after a request settles, so a slow link cannot cancel a request
/// that is still running, and a failure (a wrong API key answers 401) backs
/// off instead of hitting Gluetun every few seconds forever.
Duration _every(Instance instance, [int factor = 1]) =>
    Duration(seconds: instance.pollingIntervalSeconds * factor);

final gluetunVpnStatusProvider =
    FutureProvider.autoDispose.family<GluetunVpnStatus, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    _every(instance),
    () async => (await ref.watch(gluetunApiProvider(instance).future))
        .getVpnStatus(),
  ),
);

final gluetunPublicIpProvider =
    FutureProvider.autoDispose.family<GluetunPublicIp?, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    _every(instance),
    () async => (await ref.watch(gluetunApiProvider(instance).future))
        .getPublicIp(),
  ),
);

final gluetunPortForwardProvider =
    FutureProvider.autoDispose.family<GluetunPortForward?, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    _every(instance),
    () async => (await ref.watch(gluetunApiProvider(instance).future))
        .getPortForward(),
  ),
);

final gluetunDnsStatusProvider =
    FutureProvider.autoDispose.family<GluetunDnsStatus?, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    _every(instance),
    () async => (await ref.watch(gluetunApiProvider(instance).future))
        .getDnsStatus(),
  ),
);

final gluetunUpdaterStatusProvider =
    FutureProvider.autoDispose.family<GluetunUpdaterStatus?, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    _every(instance, 2),
    () async => (await ref.watch(gluetunApiProvider(instance).future))
        .getUpdaterStatus(),
  ),
);
