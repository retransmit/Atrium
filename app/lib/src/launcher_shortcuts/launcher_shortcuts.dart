import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences.dart';

/// How many services get a launcher shortcut. Most launchers show about four
/// on a long-press, so a longer list would mostly go unseen.
const int maxLauncherShortcuts = 4;

/// The `atrium://` link a shortcut opens: the instance's service screen,
/// picked by name, through the same path as any other Atrium link.
String shortcutLink(Instance instance) => Uri(
      scheme: 'atrium',
      host: instance.kind.name.toLowerCase(),
      queryParameters: <String, String>{'instance': instance.name},
    ).toString();

/// The instances that get a shortcut, in sidebar order.
///
/// [chosenIds] is null until the user edits the list, and then the first
/// [maxLauncherShortcuts] services stand in, so shortcuts work with no setup.
/// Once chosen, an empty list means none, and IDs of deleted instances drop
/// out.
List<Instance> shortcutInstances(
  List<Instance> instances,
  List<String>? chosenIds,
) {
  final Iterable<Instance> picked = chosenIds == null
      ? instances
      : instances.where((Instance i) => chosenIds.contains(i.id));
  return picked.take(maxLauncherShortcuts).toList(growable: false);
}

/// The services a profile's user ticked for launcher shortcuts, or null when
/// they never edited the list. Kept per profile in the settings box.
class LauncherShortcutChoiceController extends Notifier<List<String>?> {
  LauncherShortcutChoiceController(this.profileId);

  final String profileId;

  String get _key => 'launcherShortcuts.$profileId';

  @override
  List<String>? build() {
    final String? raw = ref.read(settingsBoxProvider).get(_key);
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // Falls through to the default below.
    }
    return null;
  }

  /// Shows [ids] at once, so a second tap made while this one is still
  /// saving starts from it, then saves. A failed save puts the earlier
  /// choice back, unless a later one has replaced it.
  Future<void> setChosen(List<String> ids) async {
    final List<String>? previous = state;
    final List<String> next = List<String>.unmodifiable(ids);
    state = next;
    try {
      await ref.read(settingsBoxProvider).put(_key, jsonEncode(next));
    } catch (_) {
      if (identical(state, next)) {
        state = previous;
      }
      rethrow;
    }
  }
}

final launcherShortcutChoiceProvider = NotifierProvider.family<
    LauncherShortcutChoiceController, List<String>?, String>(
  LauncherShortcutChoiceController.new,
);

/// The active profile's services that get a launcher shortcut.
final Provider<List<Instance>> launcherShortcutInstancesProvider =
    Provider<List<Instance>>((Ref ref) {
  final Profile? profile = ref.watch(activeProfileProvider);
  if (profile == null) {
    return const <Instance>[];
  }
  return shortcutInstances(
    profile.instances,
    ref.watch(launcherShortcutChoiceProvider(profile.id)),
  );
});
