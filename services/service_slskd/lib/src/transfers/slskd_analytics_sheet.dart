import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Modal bottom sheet displaying historical transfer analytics, peer leaderboard,
/// failure Pareto breakdown, popular directories, and host KPIs.
class SlskdAnalyticsSheet extends ConsumerStatefulWidget {
  const SlskdAnalyticsSheet({
    required this.instance,
    super.key,
  });

  final Instance instance;

  static Future<void> show(
    BuildContext context, {
    required Instance instance,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlskdAnalyticsSheet(instance: instance),
    );
  }

  @override
  ConsumerState<SlskdAnalyticsSheet> createState() =>
      _SlskdAnalyticsSheetState();
}

class _SlskdAnalyticsSheetState extends ConsumerState<SlskdAnalyticsSheet> {
  String _leaderboardDirection = 'Download';
  String _paretoDirection = 'Download';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final selectedDays =
        ref.watch(slskdAnalyticsTimeframeDaysProvider(widget.instance));
    final leaderboardAsync = ref.watch(
      slskdTransferLeaderboardProvider(
        (widget.instance, _leaderboardDirection),
      ),
    );
    final paretoAsync = ref.watch(
      slskdTransferExceptionsParetoProvider(
        (widget.instance, _paretoDirection),
      ),
    );
    final directoriesAsync =
        ref.watch(slskdTransferDirectoriesProvider(widget.instance));
    final kpisAsync = ref.watch(slskdPrometheusKpisProvider(widget.instance));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Sheet Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: Insets.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(Insets.xs),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Transfer Analytics & KPIs',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Historical telemetry & peer leaderboard',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh analytics',
                      onPressed: () {
                        ref.invalidate(
                          slskdTransferLeaderboardProvider((
                            widget.instance,
                            _leaderboardDirection,
                          )),
                        );
                        ref.invalidate(
                          slskdTransferExceptionsParetoProvider((
                            widget.instance,
                            _paretoDirection,
                          )),
                        );
                        ref.invalidate(
                          slskdTransferDirectoriesProvider(widget.instance),
                        );
                        ref.invalidate(
                          slskdPrometheusKpisProvider(widget.instance),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Insets.xs),

              // Timeframe filter row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Timeframe:',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    FilterChip(
                      label: const Text('24h'),
                      selected: selectedDays == 1,
                      onSelected: (val) {
                        if (val) {
                          ref
                              .read(
                                slskdAnalyticsTimeframeDaysProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state = 1;
                        }
                      },
                    ),
                    const SizedBox(width: Insets.xs),
                    FilterChip(
                      label: const Text('7 Days'),
                      selected: selectedDays == 7,
                      onSelected: (val) {
                        if (val) {
                          ref
                              .read(
                                slskdAnalyticsTimeframeDaysProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state = 7;
                        }
                      },
                    ),
                    const SizedBox(width: Insets.xs),
                    FilterChip(
                      label: const Text('30 Days'),
                      selected: selectedDays == 30,
                      onSelected: (val) {
                        if (val) {
                          ref
                              .read(
                                slskdAnalyticsTimeframeDaysProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state = 30;
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Insets.xs),
              const Divider(height: 1),

              // Body content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(Insets.md),
                  children: <Widget>[
                    // 1. Host Daemon KPIs Section
                    Text(
                      'Host Daemon Telemetry (Prometheus KPIs)',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    kpisAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Insets.md),
                          child: ExpressiveProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Card(
                        elevation: 0,
                        color: colorScheme.errorContainer.withValues(alpha: 0.2),
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.sm),
                          child: Text(
                            'Failed to load daemon KPIs: $err',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ),
                      data: (kpis) {
                        final memMetric = kpis['process_working_set_bytes'] ??
                            kpis['process_Working_set_bytes'];
                        final dotnetMem = kpis['dotnet_total_memory_bytes'];
                        final connections = kpis[
                                'microsoft_aspnetcore_server_kestrel_current_connections'] ??
                            kpis['system_net_sockets_connected_sockets'];

                        final double memBytes =
                            memMetric?.samples.firstOrNull?.value ??
                                memMetric?.sum ??
                                0.0;
                        final double dotnetBytes =
                            dotnetMem?.samples.firstOrNull?.value ??
                                dotnetMem?.sum ??
                                0.0;
                        final double connCount =
                            connections?.samples.firstOrNull?.value ??
                                connections?.sum ??
                                0.0;

                        return Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.md),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildMetricItem(
                                    context,
                                    label: 'Resident Memory',
                                    value: memBytes > 0
                                        ? slskdFormatBytes(memBytes)
                                        : 'N/A',
                                    icon: Icons.memory_rounded,
                                    colorScheme: colorScheme,
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  width: 1,
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                                Expanded(
                                  child: _buildMetricItem(
                                    context,
                                    label: 'Managed Heap',
                                    value: dotnetBytes > 0
                                        ? slskdFormatBytes(dotnetBytes)
                                        : 'N/A',
                                    icon: Icons.storage_rounded,
                                    colorScheme: colorScheme,
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  width: 1,
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                                Expanded(
                                  child: _buildMetricItem(
                                    context,
                                    label: 'TCP Connections',
                                    value: connCount.isFinite
                                        ? connCount.toInt().toString()
                                        : '0',
                                    icon: Icons.hub_rounded,
                                    colorScheme: colorScheme,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: Insets.lg),

                    // 2. Peer Transfer Leaderboard
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.leaderboard_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: Insets.xs),
                        Expanded(
                          child: Text(
                            'Top Peers Leaderboard',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'Download',
                              label: Text('DL'),
                            ),
                            ButtonSegment<String>(
                              value: 'Upload',
                              label: Text('UL'),
                            ),
                          ],
                          selected: <String>{_leaderboardDirection},
                          onSelectionChanged: (val) {
                            setState(() => _leaderboardDirection = val.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    leaderboardAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Insets.md),
                          child: ExpressiveProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Text(
                            'Leaderboard error: $err',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ),
                      data: (peers) {
                        if (peers.isEmpty) {
                          return Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(Insets.lg),
                              child: Center(
                                child: Text(
                                  'No transfer activity recorded in this timeframe.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: List.generate(peers.length, (i) {
                              final p = peers[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: i < 3
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  child: Text(
                                    '#${i + 1}',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: i < 3
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  (p.username != null && p.username!.isNotEmpty)
                                      ? p.username!
                                      : 'Unknown Peer',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${p.count} transfers • avg ${slskdFormatRate(p.averageSpeed)}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Text(
                                  slskdFormatBytes(p.totalBytes),
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: Insets.lg),

                    // 3. Transfer Exceptions Pareto
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.report_problem_rounded,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: Insets.xs),
                        Expanded(
                          child: Text(
                            'Failure Analysis (Pareto)',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'Download',
                              label: Text('DL'),
                            ),
                            ButtonSegment<String>(
                              value: 'Upload',
                              label: Text('UL'),
                            ),
                          ],
                          selected: <String>{_paretoDirection},
                          onSelectionChanged: (val) {
                            setState(() => _paretoDirection = val.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    paretoAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Insets.md),
                          child: ExpressiveProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Text(
                            'Pareto error: $err',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ),
                      data: (exceptions) {
                        if (exceptions.isEmpty) {
                          return Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(Insets.lg),
                              child: Center(
                                child: Text(
                                  '0 failures recorded for $_paretoDirection transfers.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: exceptions.map((e) {
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.warning_amber_rounded,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                title: SelectableText(
                                  e.exception.isNotEmpty
                                      ? e.exception
                                      : 'Generic Network Failure',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${e.distinctUsers} distinct peers affected',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Insets.sm,
                                    vertical: Insets.xs / 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${e.count}x',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: Insets.lg),

                    // 4. Most Downloaded Directories
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.folder_special_rounded,
                          size: 18,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: Insets.xs),
                        Text(
                          'Most Downloaded Directories',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    directoriesAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Insets.md),
                          child: ExpressiveProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Text(
                            'Directories error: $err',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ),
                      data: (dirs) {
                        if (dirs.isEmpty) {
                          return Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(Insets.lg),
                              child: Center(
                                child: Text(
                                  'No directory download statistics yet.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: dirs.map((d) {
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.folder_rounded,
                                  color: colorScheme.secondary,
                                  size: 20,
                                ),
                                title: Text(
                                  d.directory,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${d.distinctUsers} distinct peers',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Text(
                                  '${d.count} files',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(height: Insets.xs / 2),
        Text(
          value,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
