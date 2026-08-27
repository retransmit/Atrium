import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/unraid_models.dart';
import '../unraid_providers.dart';
import '../widgets/unraid_common.dart';
import '../widgets/unraid_sparkline.dart';

/// CPU, memory and network, with a graph of where each has been.
///
/// The server keeps no history for any of these, so the lines are built from
/// samples taken while the screen is open and start empty every time it is.
class _SystemBody extends ConsumerWidget {
  const _SystemBody({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<UnraidMetrics> async =
        ref.watch(unraidMetricsProvider(instance));
    final UnraidMetricsHistory history =
        ref.watch(unraidMetricsHistoryProvider(instance));

    // Metrics are a smaller prize than the array and the containers, and an
    // Unraid too old to serve them refuses the whole query. A failure here
    // gets one muted line rather than an error card pushing the rest down.
    final UnraidMetrics? metrics = async.value;
    if (metrics == null) {
      return UnraidSectionHeader(
        title: 'System',
        trailing: async.hasError ? 'Unavailable' : 'Reading...',
      );
    }

    final UnraidCpu? cpu = metrics.cpu;
    final UnraidMemory? memory = metrics.memory;
    final int cores = cpu?.coreCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UnraidSectionHeader(
          title: 'System',
          trailing: cores == 0
              ? null
              : cores == 1
                  ? '1 core'
                  : '$cores cores',
        ),
        const SizedBox(height: Insets.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _LoadCard(
                label: 'CPU',
                percent: cpu?.percentTotal,
                // The average hides the case that matters: one core pinned
                // while the rest idle still reads as a quiet machine.
                detail: cpu?.busiestCorePercent == null
                    ? null
                    : 'busiest core '
                        '${cpu!.busiestCorePercent!.toStringAsFixed(0)}%',
                values: history.cpu,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _LoadCard(
                label: 'MEMORY',
                percent: memory?.usedFraction == null
                    ? null
                    : memory!.usedFraction! * 100,
                detail: memory?.usageLabel,
                values: history.memory,
                color: cs.tertiary,
              ),
            ),
          ],
        ),
        if ((cpu?.cores.length ?? 0) > 1) ...<Widget>[
          const SizedBox(height: Insets.sm),
          _CoreBars(cores: cpu!.cores),
        ],
        if (metrics.physicalInterfaces.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.sm),
          _NetworkCard(metrics: metrics, history: history),
        ],
      ],
    );
  }
}

/// One percentage, big, over the line it has been tracing.
class _LoadCard extends StatelessWidget {
  const _LoadCard({
    required this.label,
    required this.percent,
    required this.values,
    required this.color,
    this.detail,
  });

  final String label;
  final double? percent;
  final String? detail;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double? pct = percent;
    final String? sub = detail;

    // Only a machine genuinely under pressure gets a colour; load on its own
    // is not a fault, and painting every busy moment red teaches people to
    // ignore it.
    final bool dark = cs.brightness == Brightness.dark;
    final Color valueColor = pct == null
        ? cs.onSurfaceVariant
        : pct >= 90
            ? (dark ? const Color(0xFFFF5252) : const Color(0xFFC62828))
            : cs.onSurface;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                pct == null ? '--' : '${pct.toStringAsFixed(0)}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (sub != null) ...<Widget>[
            const SizedBox(height: Insets.xxs),
            Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Insets.sm),
          _ChartSlot(
            values: values,
            color: color,
            // A percentage is drawn against a full scale so a quiet machine
            // reads as quiet, instead of noise stretched to fill the card.
            maxY: 100,
          ),
        ],
      ),
    );
  }
}

/// Throughput on the interfaces that reach the outside world.
class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.metrics, required this.history});

  final UnraidMetrics metrics;
  final UnraidMetricsHistory history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color down = cs.primary;
    final Color up = cs.secondary;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'NETWORK',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              _RateLabel(
                icon: Icons.south_rounded,
                rate: metrics.rxBytesPerSec,
                color: down,
              ),
              const SizedBox(width: Insets.md),
              _RateLabel(
                icon: Icons.north_rounded,
                rate: metrics.txBytesPerSec,
                color: up,
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          _ChartSlot(
            values: history.rx,
            color: down,
            secondaryValues: history.tx,
            secondaryColor: up,
          ),
        ],
      ),
    );
  }
}

class _RateLabel extends StatelessWidget {
  const _RateLabel({
    required this.icon,
    required this.rate,
    required this.color,
  });

  final IconData icon;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: Insets.xxs),
        Text(
          '${unraidFmtBytes(rate.round())}/s',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The chart, or a note that there is not enough of one yet.
///
/// Nothing here is stored between visits, so the first sample arrives with no
/// line to draw. Saying so is better than an empty box that reads as broken.
class _ChartSlot extends StatelessWidget {
  const _ChartSlot({
    required this.values,
    required this.color,
    this.maxY,
    this.secondaryValues,
    this.secondaryColor,
  });

  final List<double> values;
  final Color color;
  final double? maxY;
  final List<double>? secondaryValues;
  final Color? secondaryColor;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enough =
        values.length > 1 || (secondaryValues?.length ?? 0) > 1;

    if (!enough) {
      return Container(
        height: _height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Text(
          'Collecting...',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: UnraidSparkline(
        values: values,
        color: color,
        maxY: maxY,
        secondaryValues: secondaryValues,
        secondaryColor: secondaryColor,
        height: _height,
      ),
    );
  }
}

/// One bar per logical core.
///
/// The average across a machine hides the case worth seeing: a single core
/// pinned at 100 while the rest idle is a job that cannot use the other
/// cores, and on a 16 thread box that averages out to a quiet-looking 6%.
/// Bars side by side make that shape obvious at a glance.
class _CoreBars extends StatelessWidget {
  const _CoreBars({required this.cores});

  final List<UnraidCpuCore> cores;

  static const double _barHeight = 52;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool dark = cs.brightness == Brightness.dark;

    // Numbering every core stops being readable long before a big machine
    // runs out of cores, so past a point the bars speak for themselves.
    final bool labelled = cores.length <= 16;

    Color fill(double pct) => pct >= 90
        ? (dark ? const Color(0xFFFF5252) : const Color(0xFFC62828))
        : pct >= 70
            ? (dark ? const Color(0xFFFFA726) : const Color(0xFFE65100))
            : cs.primary;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'PER CORE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Insets.sm),
          SizedBox(
            height: _barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < cores.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Tooltip(
                      message: 'Core $i: '
                          '${(cores[i].percentTotal ?? 0).toStringAsFixed(0)}%',
                      child: _Bar(
                        percent: (cores[i].percentTotal ?? 0).clamp(0, 100),
                        color: fill(cores[i].percentTotal ?? 0),
                        track: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (labelled) ...<Widget>[
            const SizedBox(height: Insets.xxs),
            Row(
              children: <Widget>[
                for (int i = 0; i < cores.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '$i',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One core's load, drawn upwards from the bottom.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.percent,
    required this.color,
    required this.track,
  });

  final double percent;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // A core doing nothing still gets a sliver, so the bar reads as a
        // core at rest rather than a core that is missing.
        final double h =
            (constraints.maxHeight * percent / 100).clamp(2.0, constraints.maxHeight);
        return Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: track.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How hard the machine is working, and where it has been.
class UnraidSystemTab extends ConsumerWidget {
  const UnraidSystemTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnraidTabScaffold(
      onRefresh: () {
        ref.invalidate(unraidMetricsProvider(instance));
        ref.invalidate(unraidSystemInfoProvider(instance));
      },
      // Two separate reads, kept apart on purpose: a server that will not
      // serve one of them should still show the other.
      children: <Widget>[
        _SystemBody(instance: instance),
        const SizedBox(height: Insets.sm),
        _SystemInfoCard(instance: instance),
      ],
    );
  }
}

/// What the machine is, as opposed to what it is doing.
class _SystemInfoCard extends ConsumerWidget {
  const _SystemInfoCard({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final UnraidSystemInfo? info =
        ref.watch(unraidSystemInfoProvider(instance)).value;
    if (info == null) return const SizedBox.shrink();

    final String? cpu = info.cpuLabel;
    final List<(String, String)> rows = <(String, String)>[
      if (info.uptimeLabel.isNotEmpty) ('Uptime', info.uptimeLabel),
      if (info.osLabel != null) ('Version', info.osLabel!),
      if (info.kernel != null) ('Kernel', info.kernel!),
      // Absent on anything virtual, which is most test setups.
      if (info.boardLabel != null) ('Board', info.boardLabel!),
      if (info.memoryCapacityLabel != null)
        ('Memory', info.memoryCapacityLabel!),
      if (info.hostname != null) ('Hostname', info.hostname!),
    ];
    if (cpu == null && rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'ABOUT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              // Worth saying: an Unraid inside a VM behaves differently
              // enough that it explains a lot of odd readings.
              if (info.isVirtual == true)
                Text(
                  'virtual machine',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (cpu != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              cpu,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (info.coreLabel != null)
              Text(
                info.coreLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
          if (rows.isNotEmpty) const SizedBox(height: Insets.md),
          for (final (String label, String value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
