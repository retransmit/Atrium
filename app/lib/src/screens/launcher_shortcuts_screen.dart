import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../launcher_shortcuts/launcher_shortcuts.dart';
import '../service_icon.dart';

/// Picks which of the active profile's services appear when Atrium's
/// launcher icon is long-pressed. Until something is changed here, the first
/// four in sidebar order are used.
class LauncherShortcutsScreen extends ConsumerWidget {
  const LauncherShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(activeProfileProvider);
    final List<Instance> instances = profile?.instances ?? const <Instance>[];
    final Set<String> ticked = ref
        .watch(launcherShortcutInstancesProvider)
        .map((Instance i) => i.id)
        .toSet();
    final bool full = ticked.length >= maxLauncherShortcuts;
    final ThemeData theme = Theme.of(context);

    void toggle(Instance instance, bool on) {
      final Set<String> next = <String>{...ticked};
      if (on) {
        next.add(instance.id);
      } else {
        next.remove(instance.id);
      }
      ref.read(launcherShortcutChoiceProvider(profile!.id).notifier).setChosen(
            <String>[
              for (final Instance i in instances)
                if (next.contains(i.id)) i.id,
            ],
          );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Launcher shortcuts')),
      body: instances.isEmpty
          ? Center(
              child: Text(
                'No services configured.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.md,
                  ),
                  child: Text(
                    "Long-press Atrium's icon to open these. Up to four.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final Instance instance in instances)
                  CheckboxListTile(
                    secondary: ServiceIcon(kind: instance.kind, size: 32),
                    title: Text(instance.name),
                    subtitle: Text(instance.kind.displayName),
                    value: ticked.contains(instance.id),
                    onChanged: !ticked.contains(instance.id) && full
                        ? null
                        : (bool? on) => toggle(instance, on ?? false),
                  ),
              ],
            ),
    );
  }
}
