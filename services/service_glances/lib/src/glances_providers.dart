import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glances_api.dart';
import 'models/glances_stats.dart';

final glancesApiProvider =
    Provider.family<Future<GlancesApi>, Instance>(
        (Ref ref, Instance instance) async {
  final DioFactory factory = ref.watch(dioFactoryProvider);
  return GlancesApi(await factory.create(instance));
});

final glancesStatsProvider =
    FutureProvider.autoDispose.family<GlancesStats, Instance>(
        (Ref ref, Instance instance) async {
  ref.pollEvery(Duration(seconds: instance.pollingIntervalSeconds));
  final GlancesApi api = await ref.watch(glancesApiProvider(instance));
  return api.getStats();
});

/// The user's selected network interface names for an instance. An empty set
/// means "All" interfaces are shown.
///
/// Persisted in the app settings box (keyed by instance id) so the choice
/// survives a refresh, a screen rebuild, and an app restart.
final glancesPinnedNetworkProvider =
    NotifierProvider.family<GlancesPinnedNetworks, Set<String>, Instance>(
  GlancesPinnedNetworks.new,
);

class GlancesPinnedNetworks extends Notifier<Set<String>> {
  GlancesPinnedNetworks(this.instance);

  final Instance instance;

  static String _keyFor(String instanceId) => 'glances.pinnedNets.$instanceId';

  /// The settings box, when open. Null in contexts where Hive wasn't booted
  /// (e.g. some widget tests) - the filter then just behaves in-memory.
  Box<String>? get _box => Hive.isBoxOpen(AtriumBoxes.settings)
      ? Hive.box<String>(AtriumBoxes.settings)
      : null;

  @override
  Set<String> build() {
    final String? raw = _box?.get(_keyFor(instance.id));
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } on FormatException {
      return <String>{};
    }
  }

  /// Replaces the pinned set and persists it. An empty set clears the stored
  /// key (== show all interfaces).
  Future<void> set(Set<String> interfaces) async {
    state = interfaces;
    final Box<String>? box = _box;
    if (box == null) {
      return;
    }
    if (interfaces.isEmpty) {
      await box.delete(_keyFor(instance.id));
    } else {
      await box.put(_keyFor(instance.id), jsonEncode(interfaces.toList()));
    }
  }
}
