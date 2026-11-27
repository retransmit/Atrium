import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'launcher_shortcuts.dart';

/// Hands the launcher shortcut list to Android, which shows it on a
/// long-press of Atrium's icon and in launcher search.
class LauncherShortcutsPublisher {
  LauncherShortcutsPublisher([
    this._channel = const MethodChannel('app.atrium/launcher'),
  ]);

  final MethodChannel _channel;

  /// What Android was last given. Android limits how often an app may change
  /// its shortcuts, so an unchanged list is not sent again.
  List<Map<String, String>>? _sent;

  Future<void> publish(List<Instance> instances) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final List<Map<String, String>> shortcuts = <Map<String, String>>[
      for (final Instance i in instances)
        <String, String>{
          'id': i.id,
          'name': i.name,
          'link': shortcutLink(i),
          'icon': 'assets/service_icons/${i.kind.name}.png',
        },
    ];
    if (const DeepCollectionEquality().equals(shortcuts, _sent)) {
      return;
    }
    _sent = shortcuts;
    try {
      final bool? applied = await _channel.invokeMethod<bool>(
        'setShortcuts',
        <String, Object>{'shortcuts': shortcuts},
      );
      // Android can refuse (rate limited while in the background) or fail.
      // Forget the list so the same one is tried again, unless a newer
      // publish has already replaced it.
      if (applied != true && identical(_sent, shortcuts)) {
        _sent = null;
      }
    } on MissingPluginException {
      _sent = null;
    } on PlatformException {
      // Not sent, so the next change, or the next launch, tries again.
      _sent = null;
    }
  }
}

final Provider<LauncherShortcutsPublisher> launcherShortcutsPublisherProvider =
    Provider<LauncherShortcutsPublisher>(
  (Ref ref) => LauncherShortcutsPublisher(),
);

/// The shortcut list to publish, or null while the profiles are still
/// loading (at launch, while secure storage is read) or failed to load.
/// Publishing then would clear the shortcuts until the profiles arrive, or
/// for good if they never do.
final Provider<List<Instance>?> _publishableShortcutsProvider =
    Provider<List<Instance>?>((Ref ref) {
  if (!ref.watch(profileListProvider).hasValue) {
    return null;
  }
  return ref.watch(launcherShortcutInstancesProvider);
});

/// Publishes the active profile's shortcut list once the profiles have
/// loaded, and again whenever it changes: a profile switch, a service added,
/// renamed, reordered or deleted, or a new choice in Settings. Watched once
/// at the app root.
final Provider<void> launcherShortcutsSyncProvider = Provider<void>((Ref ref) {
  final LauncherShortcutsPublisher publisher =
      ref.watch(launcherShortcutsPublisherProvider);
  ref.listen<List<Instance>?>(
    _publishableShortcutsProvider,
    (_, List<Instance>? next) {
      if (next != null) {
        publisher.publish(next);
      }
    },
    fireImmediately: true,
  );
});
