import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
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
      await _channel.invokeMethod<bool>(
        'setShortcuts',
        <String, Object>{'shortcuts': shortcuts},
      );
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

/// Publishes the active profile's shortcut list now and again whenever it
/// changes: a profile switch, a service added, renamed, reordered or deleted,
/// or a new choice in Settings. Watched once at the app root.
final Provider<void> launcherShortcutsSyncProvider = Provider<void>((Ref ref) {
  final LauncherShortcutsPublisher publisher =
      ref.watch(launcherShortcutsPublisherProvider);
  ref.listen<List<Instance>>(
    launcherShortcutInstancesProvider,
    (_, List<Instance> next) => publisher.publish(next),
    fireImmediately: true,
  );
});
