import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cleanuparr_errors.dart';
import '../cleanuparr_providers.dart';
import '../models/cleanuparr_job.dart';
import '../models/cleanuparr_stats.dart';
import '../models/cleanuparr_status.dart';
import '../widgets/cleanuparr_job_card.dart';
import '../widgets/cleanuparr_metric_card.dart';

/// Tab 0: Overview displaying system health, operational metrics, and background jobs.
class CleanuparrOverviewTab extends ConsumerWidget {
  const CleanuparrOverviewTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(cleanuparrStatusProvider(instance));
    ref.invalidate(cleanuparrStatsProvider(instance));
    ref.invalidate(cleanuparrJobsProvider(instance));
    ref.invalidate(cleanuparrStrikesCountProvider(instance));
    await Future.wait(<Future<dynamic>>[
      ref.read(cleanuparrStatusProvider(instance).future),
      ref.read(cleanuparrStatsProvider(instance).future),
      ref.read(cleanuparrJobsProvider(instance).future),
      ref.read(cleanuparrStrikesCountProvider(instance).future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(cleanuparrStatusProvider(instance));
    final statsAsync = ref.watch(cleanuparrStatsProvider(instance));
    final jobsAsync = ref.watch(cleanuparrJobsProvider(instance));
    final int selectedHours = ref.watch(cleanuparrTimeframeHoursProvider(instance));

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onOpenDrawer,
              )
            : null,
        title: Text(instance.name),
      ),
      body: EasyRefresh(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xl),
          children: <Widget>[
            // System Status Card
            statusAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (CleanuparrStatus status) {
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  shape: const RoundedRectangleBorder(borderRadius: Radii.card),
                  margin: const EdgeInsets.only(bottom: Insets.md),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                status.appName,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.xs + 2,
                                vertical: Insets.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: Radii.chip,
                              ),
                              child: Text(
                                'v${status.version}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (status.memoryUsageMB != null)
                              Flexible(
                                child: Text(
                                  '${status.memoryUsageMB!.toStringAsFixed(1)} MB',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                          ],
                        ),
                        if (status.mediaManagers.isNotEmpty ||
                            status.downloadClients.isNotEmpty) ...<Widget>[
                          const SizedBox(height: Insets.sm),
                          Wrap(
                            spacing: Insets.xs,
                            runSpacing: Insets.xs,
                            children: <Widget>[
                              for (final m in status.mediaManagers)
                                _IntegrationChip(name: m.name, isArr: true),
                              for (final c in status.downloadClients)
                                _IntegrationChip(name: c.name, isArr: false),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            // Timeframe Segmented Control
            Center(
              child: SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 24, label: Text('24h')),
                  ButtonSegment<int>(value: 168, label: Text('7d')),
                  ButtonSegment<int>(value: 720, label: Text('30d')),
                ],
                selected: <int>{selectedHours},
                onSelectionChanged: (Set<int> newSelection) {
                  ref
                      .read(cleanuparrTimeframeHoursProvider(instance).notifier)
                      .state = newSelection.first;
                },
              ),
            ),
            const SizedBox(height: Insets.md),

            // 4 Metrics Grid
            statsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.xl),
                  child: ExpressiveProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Text('Unable to load metrics: ${describeCleanuparrError(err)}'),
                ),
              ),
              data: (CleanuparrStats stats) {
                // Exact server-side ledger count. Deliberately NOT derived
                // from the rendered strikes list, which is search-filtered
                // and capped at its page size.
                final int activeCount =
                    ref.watch(cleanuparrActiveStrikesCountProvider(instance));

                return Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CleanuparrMetricCard(
                            title: 'Malware Blocked',
                            value: '${stats.malwareBlocked}',
                            icon: Icons.shield_outlined,
                            containerColor: colorScheme.errorContainer,
                            contentColor: colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: CleanuparrMetricCard(
                            title: 'Active Strikes',
                            value: '$activeCount',
                            icon: Icons.gavel_outlined,
                            containerColor: colorScheme.tertiaryContainer,
                            contentColor: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: CleanuparrMetricCard(
                            title: 'Cleaned Torrents',
                            value: '${stats.totalCleaned}',
                            icon: Icons.cleaning_services_outlined,
                            containerColor: colorScheme.primaryContainer,
                            contentColor: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: CleanuparrMetricCard(
                            title: 'Seeker Searches',
                            value: '${stats.seekerTriggers}',
                            icon: Icons.search_rounded,
                            containerColor: colorScheme.secondaryContainer,
                            contentColor: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: Insets.lg),

            // Background Jobs Section
            Text(
              'Background Tasks',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Insets.sm),

            jobsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, _) => Text(
                'Could not load tasks: ${describeCleanuparrError(err)}',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
              data: (List<CleanuparrJob> jobs) {
                if (jobs.isEmpty) {
                  return Text(
                    'No background tasks found',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final CleanuparrJob job in jobs)
                      CleanuparrJobCard(job: job, instance: instance),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrationChip extends StatelessWidget {
  const _IntegrationChip({required this.name, required this.isArr});

  final String name;
  final bool isArr;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs + 2,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: Radii.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isArr ? Icons.auto_awesome : Icons.download_rounded,
            size: 12,
            color: cs.primary,
          ),
          const SizedBox(width: Insets.xxs + 1),
          Text(
            name,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
