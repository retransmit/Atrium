import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:service_glances/service_glances.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

String _fmtBytes(num bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[u]}';
}

/// Colour for a load bar: red past 90%, otherwise the primary accent.
Color _loadColor(double percent, ColorScheme cs) =>
    percent >= 90 ? cs.error : cs.primary;

/// Live server vitals from Glances: CPU, memory, GPU (when present) and the
/// filesystems, one section per Glances instance.
class DashboardServerInfoWidget extends ConsumerWidget {
  const DashboardServerInfoWidget({required this.instances, super.key});

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<({Instance instance, GlancesStats stats})> servers =
        <({Instance instance, GlancesStats stats})>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in instances) {
      final AsyncValue<GlancesStats> stats = ref.watch(glancesStatsProvider(i));
      anyLoading |= stats.isLoading && !stats.hasValue;
      anyError |= stats.hasError;
      final GlancesStats? value = stats.value;
      if (value != null) {
        servers.add((instance: i, stats: value));
      }
    }

    Widget body;
    if (servers.isEmpty && anyLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.sm),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (servers.isEmpty && anyError) {
      body = DashboardErrorRow(
        onRetry: () {
          for (final Instance i in instances) {
            ref.invalidate(glancesStatsProvider(i));
          }
        },
      );
    } else if (servers.isEmpty) {
      body = const DashboardIdleRow(text: 'No server stats available');
    } else {
      final bool showName = servers.length > 1;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int j = 0; j < servers.length; j++) ...<Widget>[
            if (j > 0) const SizedBox(height: Insets.md),
            _ServerBlock(
              instance: servers[j].instance,
              stats: servers[j].stats,
              showName: showName,
            ),
          ],
        ],
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.serverInfo,
      accent: Theme.of(context).colorScheme.primary,
      child: body,
    );
  }
}

class _ServerBlock extends StatelessWidget {
  const _ServerBlock({
    required this.instance,
    required this.stats,
    required this.showName,
  });

  final Instance instance;
  final GlancesStats stats;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final GlancesGpu? gpu = stats.gpus.isNotEmpty ? stats.gpus.first : null;
    final List<GlancesDisk> disks = <GlancesDisk>[
      for (final GlancesDisk d in stats.disks)
        if (d.total > 0) d,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showName)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text(
              instance.name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _MetricTile(
                label: 'CPU',
                percent: stats.cpu.totalUsage,
                detail: stats.cpu.packageTemp > 0
                    ? '${stats.cpu.packageTemp.round()}°C'
                    : '${stats.cpu.logicalCores} cores',
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: _MetricTile(
                label: 'Memory',
                percent: stats.memory.percentage,
                detail:
                    '${_fmtBytes(stats.memory.used)} / ${_fmtBytes(stats.memory.total)}',
              ),
            ),
            if (gpu != null) ...<Widget>[
              const SizedBox(width: Insets.md),
              Expanded(
                child: _MetricTile(
                  label: 'GPU',
                  percent: gpu.proc,
                  detail: gpu.temp > 0
                      ? '${gpu.temp.round()}°C'
                      : 'MEM ${gpu.mem.round()}%',
                ),
              ),
            ],
          ],
        ),
        if (disks.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.md),
          for (final GlancesDisk d in disks.take(4)) _DiskBar(disk: d),
          if (disks.length > 4)
            DashboardIdleRow(text: '+${disks.length - 4} more'),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.percent,
    required this.detail,
  });

  final String label;
  final double percent;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color color = _loadColor(percent, cs);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicatorM3E(
                value: (percent / 100).clamp(0, 1).toDouble(),
                size: CircularProgressM3ESize.m,
                shape: ProgressM3EShape.flat,
                activeColor: color,
                trackColor: cs.surfaceContainerHighest,
              ),
              Text(
                '${percent.round()}%',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DiskBar extends StatelessWidget {
  const _DiskBar({required this.disk});

  final GlancesDisk disk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double fraction = (disk.percentage / 100).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  disk.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                '${_fmtBytes(disk.total - disk.used)} free of ${_fmtBytes(disk.total)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicatorM3E(
              value: fraction,
              shape: ProgressM3EShape.flat,
              size: LinearProgressM3ESize.s,
              activeColor: _loadColor(disk.percentage, cs),
              trackColor: cs.surfaceContainerHighest,
              inset: 0.0,
            ),
          ),
        ],
      ),
    );
  }
}
