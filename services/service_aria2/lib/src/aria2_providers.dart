import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'aria2_api.dart';
import 'models/aria2_download.dart';
import 'models/aria2_peer.dart';
import 'models/aria2_snapshot.dart';

/// How often the download lists refresh while a screen is visible.
const Duration aria2PollInterval = Duration(seconds: 3);

/// The detail screen refreshes a little slower than the list.
const Duration aria2DetailPollInterval = Duration(seconds: 5);

/// An [Aria2Api] for an instance, over the shared `instanceDioProvider`.
///
/// The daemon's secret token is read from the instance's api key: aria2
/// calls it `--rpc-secret`, and it is the one credential the RPC interface
/// takes. An instance with no secret gets a client that sends no token, which
/// is what an aria2 with no `--rpc-secret` expects.
final aria2ApiProvider = FutureProvider.family<Aria2Api, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  final String secret = switch (instance.auth) {
    InstanceAuthApiKey(:final String apiKey) => apiKey,
    InstanceAuthUserPass() || InstanceAuthPlex() || InstanceAuthCookie() => '',
  };
  return Aria2Api(dio, secret: secret);
}, retry: (_, _) => null);

/// The whole daemon in one poll: the three download lists, the global
/// counters and the version.
final aria2SnapshotProvider = FutureProvider.autoDispose
    .family<Aria2Snapshot, Instance>((Ref ref, Instance instance) => ref.polled(
          aria2PollInterval,
          () async {
            final Aria2Api api =
                await ref.watch(aria2ApiProvider(instance).future);
            return api.getSnapshot();
          },
        ), retry: (_, _) => null);

/// One download's own status, for the detail screen.
///
/// Null when the daemon no longer knows the download - it was removed and
/// its result purged, which is what happens when the user clears the list.
final aria2DownloadProvider = FutureProvider.autoDispose
    .family<Aria2Download?, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) => ref.polled(aria2DetailPollInterval, () async {
          final (Instance instance, String gid) = key;
          final Aria2Api api =
              await ref.watch(aria2ApiProvider(instance).future);
          try {
            return await api.tellStatus(gid);
          } on Aria2RpcException catch (e) {
            // Only "GID is not found" means the download was removed and
            // purged. Any other error (a wrong secret, a proxy error) is
            // shown as an error.
            if (e.isGidNotFound) {
              return null;
            }
            rethrow;
          }
        }), retry: (_, _) => null);

/// The daemon's global options, read on demand.
///
/// Not polled: the answer carries every option the daemon has, and only the
/// speed limits are ever shown.
final aria2GlobalOptionsProvider = FutureProvider.autoDispose
    .family<Map<String, String>, Instance>((Ref ref, Instance instance) async {
      final Aria2Api api = await ref.watch(aria2ApiProvider(instance).future);
      return api.getGlobalOption();
    }, retry: (_, _) => null);

/// Active peers for a BitTorrent download.
final aria2PeersProvider = FutureProvider.autoDispose
    .family<List<Aria2Peer>, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) => ref.polled(aria2DetailPollInterval, () async {
          final (Instance instance, String gid) = key;
          final Aria2Api api =
              await ref.watch(aria2ApiProvider(instance).future);
          try {
            return await api.getPeers(gid);
          } on Aria2RpcException catch (e) {
            if (e.isGidNotFound) {
              return const <Aria2Peer>[];
            }
            rethrow;
          }
        }), retry: (_, _) => null);

/// Options of one specific download.
final aria2DownloadOptionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) async {
      final (Instance instance, String gid) = key;
      final Aria2Api api = await ref.watch(aria2ApiProvider(instance).future);
      try {
        return await api.getOption(gid);
      } on Aria2RpcException catch (e) {
        if (e.isGidNotFound) {
          return const <String, dynamic>{};
        }
        rethrow;
      }
    }, retry: (_, _) => null);

// -----------------------------------------------------------------------------
// UI State & Filtering Providers
// -----------------------------------------------------------------------------

/// Unified filter settings for transfers.
enum Aria2TransfersFilter {
  all('All'),
  active('Active'),
  waiting('Queued'),
  completed('Completed'),
  paused('Paused'),
  error('Errors');

  const Aria2TransfersFilter(this.label);
  final String label;
}

/// Sorting fields supported by transfers.
enum Aria2SortField {
  name('Name'),
  size('Size'),
  progress('Progress'),
  downloadSpeed('Download Speed'),
  uploadSpeed('Upload Speed'),
  eta('ETA');

  const Aria2SortField(this.label);
  final String label;
}

/// Active tab index in Aria2Home (0: Downloads, 1: Settings, 2: System).
final aria2ActiveTabProvider = StateProvider.family<int, Instance>(
  (Ref ref, Instance instance) => 0,
);

/// Visibility of the bottom navigation bar.
final aria2BottomNavVisibleProvider = StateProvider.family<bool, Instance>(
  (Ref ref, Instance instance) => true,
);

/// Whether the search bar is active in the downloads hub.
final aria2SearchActiveProvider = StateProvider.family<bool, Instance>(
  (Ref ref, Instance instance) => false,
);

/// Search query for active & queued transfers.
final aria2SearchQueryProvider = StateProvider.family<String, Instance>(
  (Ref ref, Instance instance) => '',
);

/// Filter for active & queued transfers.
final aria2TransfersFilterProvider =
    StateProvider.family<Aria2TransfersFilter, Instance>(
      (Ref ref, Instance instance) => Aria2TransfersFilter.all,
    );

/// Sort field for transfers.
final aria2SortFieldProvider = StateProvider.family<Aria2SortField, Instance>(
  (Ref ref, Instance instance) => Aria2SortField.name,
);

/// Sort ascending toggle.
final aria2SortAscendingProvider = StateProvider.family<bool, Instance>(
  (Ref ref, Instance instance) => true,
);

/// Set of selected GIDs for multi-selection.
final aria2SelectionProvider = StateProvider.family<Set<String>, Instance>(
  (Ref ref, Instance instance) => <String>{},
);

/// Scroll-to-top event bus per tab.
final aria2ScrollToTopProvider = StateProvider.family<int, (Instance, int)>(
  (Ref ref, (Instance, int) key) => 0,
);
