import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_application.dart';
import 'prowlarr_providers.dart';

/// The Apps tab: the applications Prowlarr syncs its indexers to (Sonarr,
/// Radarr, ...). Tapping a row opens its config form. Add and sync live on the
/// home FABs.
class ProwlarrAppsTab extends ConsumerWidget {
  const ProwlarrAppsTab({
    required this.instance,
    required this.onEdit,
    super.key,
  });

  final Instance instance;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProwlarrApplication>> apps =
        ref.watch(prowlarrApplicationsProvider(instance));
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(prowlarrApplicationsProvider(instance)),
      child: AsyncValueView<List<ProwlarrApplication>>(
        value: apps,
        onRetry: () => ref.invalidate(prowlarrApplicationsProvider(instance)),
        data: (List<ProwlarrApplication> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.apps_outlined,
              title: 'No applications',
              message:
                  'Tap "Add application" to connect Sonarr, Radarr, and more.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final ProwlarrApplication app = list[index];
              final bool synced =
                  app.syncLevel.isNotEmpty && app.syncLevel != 'disabled';
              return ListTile(
                leading: Icon(
                  synced ? Icons.sync : Icons.sync_disabled,
                  color: synced
                      ? Colors.green
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(app.name),
                subtitle: Text(
                  <String>[
                    if (app.implementation.isNotEmpty) app.implementation,
                    _syncLabel(app.syncLevel),
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onEdit(app.id),
              );
            },
          );
        },
      ),
    );
  }
}

String _syncLabel(String level) {
  switch (level) {
    case 'fullSync':
      return 'Full sync';
    case 'addOnly':
      return 'Add and remove only';
    case 'disabled':
      return 'Disabled';
    default:
      return level.isEmpty ? 'Unknown' : level;
  }
}
