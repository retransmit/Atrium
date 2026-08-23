import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/unraid_models.dart';
import 'unraid_client.dart';

/// How often the array and container lists refresh while on screen.
///
/// Slower than the torrent clients on purpose: none of this moves quickly, and
/// every tick is a GraphQL query the server has to resolve.
const Duration unraidPollInterval = Duration(seconds: 15);

/// Client bound to one instance.
///
/// Rides [instanceDioProvider], so the base URL, custom headers, self-signed
/// opt-in and the `x-api-key` header all come from the shared setup.
final unraidClientProvider =
    FutureProvider.autoDispose.family<UnraidClient, Instance>(
  (Ref ref, Instance instance) async =>
      UnraidClient(await ref.watch(instanceDioProvider(instance).future)),
);

/// Array state and disks, polled while watched.
final unraidArrayProvider =
    FutureProvider.autoDispose.family<UnraidArray, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    unraidPollInterval,
    () async {
      final UnraidClient client =
          await ref.watch(unraidClientProvider(instance).future);
      return client.getArray();
    },
  ),
);

/// Docker containers, polled while watched.
final unraidContainersProvider =
    FutureProvider.autoDispose.family<List<UnraidContainer>, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    unraidPollInterval,
    () async {
      final UnraidClient client =
          await ref.watch(unraidClientProvider(instance).future);
      return client.getContainers();
    },
  ),
);
