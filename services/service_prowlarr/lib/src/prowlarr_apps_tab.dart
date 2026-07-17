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
    return AsyncValueView<List<ProwlarrApplication>>(
          value: apps,
        onRetry: () => ref.invalidate(prowlarrApplicationsProvider(instance)),
          data: (List<ProwlarrApplication> list) {
            
          if (list.isEmpty) {
            return EasyRefresh(
        header: const ClassicHeader(
          dragText: 'Pull to refresh',
          armedText: 'Release ready',
          readyText: 'Refreshing...',
          processingText: 'Refreshing...',
          processedText: 'Succeeded',
          failedText: 'Failed',
          messageText: 'Last updated at %T',
        ),
        onRefresh: () async =>
          ref.invalidate(prowlarrApplicationsProvider(instance)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const <Widget>[
            SizedBox(height: 100),
            EmptyView(
              icon: Icons.apps_outlined,
              title: 'No applications',
              message:
                  'Tap "Add application" to connect Sonarr, Radarr, and more.',
            ),
          ],
        ),
      );
          }
          return EasyRefresh(
      header: const ClassicHeader(
        dragText: 'Pull to refresh',
        armedText: 'Release ready',
        readyText: 'Refreshing...',
        processingText: 'Refreshing...',
        processedText: 'Succeeded',
        failedText: 'Failed',
        messageText: 'Last updated at %T',
      ),
      onRefresh: () async =>
          ref.invalidate(prowlarrApplicationsProvider(instance)),
      child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.sm,
            ),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final ThemeData theme = Theme.of(context);
              final ColorScheme cs = theme.colorScheme;
              final ProwlarrApplication app = list[index];
              final bool synced =
                  app.syncLevel.isNotEmpty && app.syncLevel != 'disabled';
              final Color accent = synced ? cs.tertiary : cs.outline;
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onEdit(app.id),
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              synced ? Icons.sync : Icons.sync_disabled,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  app.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (app.implementation.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    app.implementation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          _SyncPill(
                            label: _syncLabel(app.syncLevel),
                            color: accent,
                          ),
                          const SizedBox(width: Insets.sm),
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
        
          },
        );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
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
