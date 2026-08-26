import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/unraid_models.dart';
import 'unraid_client.dart';
import 'unraid_providers.dart';
import 'widgets/unraid_sparkline.dart';

/// Unraid: array health and Docker containers.
///
/// Containers can be started and stopped from here. The array cannot: stopping
/// it unmounts every share and takes down every container at once, which is
/// not something to put one mistaken tap away on a phone. Reading its state is
/// the useful half, and that is what this shows.
class UnraidHome extends ConsumerWidget {
  const UnraidHome({required this.instance, this.drawer, super.key});

  final Instance instance;
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UnraidArray> arrayAsync =
        ref.watch(unraidArrayProvider(instance));
    final AsyncValue<List<UnraidContainer>> containersAsync =
        ref.watch(unraidContainersProvider(instance));

    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        leading: drawer == null
            ? null
            : Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open menu',
                  onPressed: Scaffold.of(context).openDrawer,
                ),
              ),
        title: Text(instance.name),
      ),
      body: EasyRefresh(
        header: const ClassicHeader(
          dragText: 'Pull to refresh',
          armedText: 'Release ready',
          readyText: 'Refreshing...',
          processingText: 'Refreshing...',
          processedText: 'Updated',
          failedText: 'Failed',
          messageText: 'Last updated at %T',
        ),
        onRefresh: () async {
          ref.invalidate(unraidArrayProvider(instance));
          ref.invalidate(unraidContainersProvider(instance));
        },
        child: ListView(
          padding: Insets.page,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            AsyncValueView<UnraidArray>(
              value: arrayAsync,
              onRetry: () => ref.invalidate(unraidArrayProvider(instance)),
              loading: const _CardPlaceholder(height: 210),
              data: (UnraidArray array) => _ArraySection(array: array),
            ),
            const SizedBox(height: Insets.xl),
            _SystemSection(instance: instance),
            const SizedBox(height: Insets.xl),
            AsyncValueView<List<UnraidContainer>>(
              value: containersAsync,
              onRetry: () => ref.invalidate(unraidContainersProvider(instance)),
              loading: const _CardPlaceholder(height: 160),
              data: (List<UnraidContainer> containers) => _DockerSection(
                containers: containers,
                instance: instance,
              ),
            ),
            const SizedBox(height: Insets.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// System load
// ---------------------------------------------------------------------------

/// CPU, memory and network, with a graph of where each has been.
///
/// The server keeps no history for any of these, so the lines are built from
/// samples taken while the screen is open and start empty every time it is.
class _SystemSection extends ConsumerWidget {
  const _SystemSection({required this.instance});

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
      return _SectionHeader(
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
        _SectionHeader(
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

// ---------------------------------------------------------------------------
// Array
// ---------------------------------------------------------------------------

class _ArraySection extends StatelessWidget {
  const _ArraySection({required this.array});

  final UnraidArray array;

  @override
  Widget build(BuildContext context) {
    final UnraidParityCheck? check = array.parityCheck;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ArrayHero(array: array),
        if (check != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          _ParityCheckTile(check: check),
        ],
        _DiskSection(
          title: 'Parity',
          disks: array.parities,
          icon: Icons.shield_outlined,
        ),
        _DiskSection(
          title: 'Data',
          disks: array.disks,
          icon: Icons.storage_rounded,
        ),
        _DiskSection(
          title: 'Cache',
          disks: array.caches,
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }
}

/// One titled group of disks, or nothing at all when the server reported none.
///
/// Every Unraid server has data disks, but parity and cache are both optional,
/// and an empty heading reads as something having gone missing.
class _DiskSection extends StatelessWidget {
  const _DiskSection({
    required this.title,
    required this.disks,
    required this.icon,
  });

  final String title;
  final List<UnraidDisk> disks;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (disks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            title: title,
            trailing: disks.length == 1 ? '1 disk' : '${disks.length} disks',
          ),
          const SizedBox(height: Insets.sm),
          _DiskGroup(disks: disks, icon: icon),
        ],
      ),
    );
  }
}

class _ArrayHero extends StatelessWidget {
  const _ArrayHero({required this.array});

  final UnraidArray array;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final bool started = array.isStarted;
    final List<UnraidDisk> faults = array.unhealthyDisks;
    // The icon reports whether the array is up, not whether every disk is
    // well: a fault already has the banner below and the health stat beside
    // it, and colouring all three red buries which one is the actual news.
    final Color accent = started ? _okGreen(cs) : cs.onSurfaceVariant;

    final UnraidDisk? warmest = array.warmestDisk;
    final int parityCount = array.parities.length;
    final double? used = array.usedFraction;
    final String? usage = array.usageLabel;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(
                  started ? Icons.dns_rounded : Icons.pause_circle_outline,
                  size: 28,
                  color: accent,
                ),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Array ${array.stateLabel}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      parityCount == 0
                          ? 'No parity protection'
                          : parityCount == 1
                              ? 'Single parity'
                              : '$parityCount parity disks',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (faults.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.lg),
            _FaultBanner(faults: faults),
          ],
          if (used != null && usage != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            _UsageBar(fraction: used, label: usage, caption: 'Array'),
          ],
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatBox(
                  label: 'DISKS',
                  value: '${array.disks.length}',
                  unit: array.caches.isEmpty
                      ? 'data'
                      : 'data, ${array.caches.length} cache',
                  valueColor: cs.onSurface,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _StatBox(
                  label: 'WARMEST',
                  value: warmest?.temp == null ? '--' : '${warmest!.temp}',
                  unit: warmest == null ? 'all idle' : warmest.name,
                  valueColor: warmest == null
                      ? cs.onSurfaceVariant
                      : _heatColor(warmest.heat, cs),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _StatBox(
                  label: 'HEALTH',
                  value: faults.isEmpty ? 'OK' : '${faults.length}',
                  unit: faults.isEmpty ? 'all disks' : 'need attention',
                  valueColor: faults.isEmpty ? _okGreen(cs) : cs.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How the last parity check went, or how the running one is doing.
///
/// Parity that has never been verified is the failure nobody notices until a
/// disk dies, so this stays on screen even when there is nothing wrong.
class _ParityCheckTile extends StatelessWidget {
  const _ParityCheckTile({required this.check});

  final UnraidParityCheck check;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final bool running = check.isRunning;
    final bool bad = check.foundErrors || check.status == 'FAILED';
    final Color color = bad
        ? cs.error
        : running
            ? cs.primary
            : cs.onSurfaceVariant;

    final String text;
    if (running) {
      final int? pct = check.progress;
      text = pct == null
          ? 'Parity check running'
          : 'Parity check running, $pct%';
    } else if (check.isPaused) {
      text = 'Parity check paused';
    } else if (check.foundErrors) {
      final int n = check.errors ?? 0;
      text = n == 1
          ? 'Last parity check found 1 error'
          : 'Last parity check found $n errors';
    } else if (check.status == 'NEVER_RUN') {
      text = 'Parity has never been checked';
    } else {
      final String? label = check.statusLabel;
      final String when = _ago(check.date);
      text = label == null
          ? 'Parity check $when'
          : when.isEmpty
              ? 'Parity check $label'
              : 'Parity check $label $when';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                bad ? Icons.error_outline : Icons.verified_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (running && check.progress != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: LinearProgressIndicator(
                value: (check.progress! / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Names the disks that are actually in trouble.
///
/// A bare count sends you to a browser to find out which disk; the names cost
/// no more space and answer the only question the warning raises.
class _FaultBanner extends StatelessWidget {
  const _FaultBanner({required this.faults});

  final List<UnraidDisk> faults;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String detail = faults
        .map((UnraidDisk d) => '${d.name} ${d.statusLabel.toLowerCase()}')
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 20, color: cs.error),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled fill bar, coloured by how close to full it is.
class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.fraction,
    required this.label,
    this.caption,
  });

  final double fraction;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? cap = caption;

    // Unraid's own defaults warn at 70% and call it critical at 90%, so the
    // colour changes where the server would start emailing about it.
    final bool dark = cs.brightness == Brightness.dark;
    final Color fill = fraction >= 0.90
        ? (dark ? const Color(0xFFFF5252) : const Color(0xFFC62828))
        : fraction >= 0.70
            ? (dark ? const Color(0xFFFFA726) : const Color(0xFFE65100))
            : cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (cap != null)
              Text(
                cap,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          ),
        ),
      ],
    );
  }
}

class _DiskGroup extends StatelessWidget {
  const _DiskGroup({required this.disks, required this.icon});

  final List<UnraidDisk> disks;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < disks.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: Insets.lg, color: cs.outlineVariant),
            _DiskRow(disk: disks[i], icon: icon),
          ],
        ],
      ),
    );
  }
}

class _DiskRow extends StatelessWidget {
  const _DiskRow({required this.disk, required this.icon});

  final UnraidDisk disk;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool healthy = disk.isHealthy;
    final String size = disk.sizeLabel;
    final double? used = disk.usedFraction;
    final String? usage = disk.usageLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: healthy ? cs.onSurfaceVariant : cs.error,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      disk.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!healthy) ...<Widget>[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        disk.statusLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (size.isNotEmpty) ...<Widget>[
                Text(
                  size,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: Insets.md),
              ],
              _TempPill(disk: disk),
            ],
          ),
          // Parity holds no filesystem and an unformatted disk reports none
          // either, so neither gets a bar: an empty one would read as free
          // space that is not there.
          if (used != null && usage != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            _UsageBar(fraction: used, label: usage),
          ],
        ],
      ),
    );
  }
}

/// The temperature, banded by [DiskHeat] so a hot disk reads as hot without
/// anyone having to know what a normal number looks like.
class _TempPill extends StatelessWidget {
  const _TempPill({required this.disk});

  final UnraidDisk disk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int? temp = disk.temp;

    // A spun-down disk reports nothing, which is not a fault and should not
    // look like one.
    if (temp == null) {
      return Text(
        disk.isSpinning == false ? 'spun down' : 'idle',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
      );
    }

    final Color color = _heatColor(disk.heat, cs);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: Radii.chip,
      ),
      child: Text(
        '$temp deg',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The one green used for a healthy state, kept off the colour scheme so it
/// reads the same as the green end of the temperature scale.
Color _okGreen(ColorScheme cs) => cs.brightness == Brightness.dark
    ? const Color(0xFF66BB6A)
    : const Color(0xFF2E7D32);

/// Cool blue through to hot red, deliberately not taken from the colour
/// scheme: the dark theme's error colour is a pale pink that reads cooler than
/// the orange one band below it, which would put the scale in the wrong order.
/// Each band is given a light and a dark variant so it stays legible either
/// way.
Color _heatColor(DiskHeat heat, ColorScheme cs) {
  final bool dark = cs.brightness == Brightness.dark;
  return switch (heat) {
    DiskHeat.hot => dark ? const Color(0xFFFF5252) : const Color(0xFFC62828),
    DiskHeat.warm => dark ? const Color(0xFFFFA726) : const Color(0xFFE65100),
    DiskHeat.normal => dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
    DiskHeat.cool => dark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD),
    DiskHeat.unknown => cs.outline,
  };
}

/// `2 days ago`, or an empty string when there is no date to place.
String _ago(DateTime? when) {
  if (when == null) return '';
  final Duration d = DateTime.now().difference(when);
  if (d.isNegative) return '';
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) {
    final int m = d.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (d.inDays < 1) {
    final int h = d.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (d.inDays < 30) {
    final int days = d.inDays;
    return days == 1 ? 'yesterday' : '$days days ago';
  }
  final int months = d.inDays ~/ 30;
  return months == 1 ? 'last month' : '$months months ago';
}

// ---------------------------------------------------------------------------
// Docker
// ---------------------------------------------------------------------------

enum _DockerFilter { all, running, stopped, issues }

class _DockerSection extends StatefulWidget {
  const _DockerSection({required this.containers, required this.instance});

  final List<UnraidContainer> containers;
  final Instance instance;

  @override
  State<_DockerSection> createState() => _DockerSectionState();
}

class _DockerSectionState extends State<_DockerSection> {
  _DockerFilter _filter = _DockerFilter.all;

  List<UnraidContainer> _apply(_DockerFilter filter) {
    return switch (filter) {
      _DockerFilter.all => widget.containers,
      _DockerFilter.running =>
        widget.containers.where((UnraidContainer c) => c.isRunning).toList(),
      _DockerFilter.stopped =>
        widget.containers.where((UnraidContainer c) => c.isStopped).toList(),
      _DockerFilter.issues =>
        widget.containers.where((UnraidContainer c) => c.isUnhealthy).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<UnraidContainer> all = widget.containers;

    if (all.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(title: 'Docker'),
          SizedBox(height: Insets.sm),
          EmptyView(
            title: 'No containers',
            message: 'This server is not running any Docker containers.',
          ),
        ],
      );
    }

    final int running = _apply(_DockerFilter.running).length;
    final int issues = _apply(_DockerFilter.issues).length;
    // A filter that would show nothing is worse than no filter: keep the chip
    // out of the row rather than offering an empty result.
    final List<_DockerFilter> available = <_DockerFilter>[
      _DockerFilter.all,
      if (running > 0) _DockerFilter.running,
      if (running < all.length) _DockerFilter.stopped,
      if (issues > 0) _DockerFilter.issues,
    ];
    final List<UnraidContainer> shown = _apply(_filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: 'Docker',
          trailing: '$running of ${all.length} running',
        ),
        if (available.length > 1) ...<Widget>[
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              for (final _DockerFilter f in available)
                FilterChip(
                  label: Text(_filterLabel(f, all.length, running, issues)),
                  selected: _filter == f,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        _ContainerGroup(containers: shown, instance: widget.instance),
      ],
    );
  }

  String _filterLabel(_DockerFilter f, int total, int running, int issues) =>
      switch (f) {
        _DockerFilter.all => 'All $total',
        _DockerFilter.running => 'Running $running',
        _DockerFilter.stopped => 'Stopped ${total - running}',
        _DockerFilter.issues => 'Issues $issues',
      };
}

class _ContainerGroup extends StatelessWidget {
  const _ContainerGroup({required this.containers, required this.instance});

  final List<UnraidContainer> containers;
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // Anything failing a healthcheck first, then what is up, then by name, so
    // the thing that needs a person is never buried.
    final List<UnraidContainer> sorted = <UnraidContainer>[...containers]
      ..sort((UnraidContainer a, UnraidContainer b) {
        if (a.isUnhealthy != b.isUnhealthy) return a.isUnhealthy ? -1 : 1;
        if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < sorted.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: Insets.lg, color: cs.outlineVariant),
            _ContainerRow(container: sorted[i], instance: instance),
          ],
        ],
      ),
    );
  }
}

class _ContainerRow extends ConsumerStatefulWidget {
  const _ContainerRow({required this.container, required this.instance});

  final UnraidContainer container;
  final Instance instance;

  @override
  ConsumerState<_ContainerRow> createState() => _ContainerRowState();
}

class _ContainerRowState extends ConsumerState<_ContainerRow> {
  bool _busy = false;

  /// Runs one lifecycle action and refreshes the list.
  ///
  /// The reason a refusal gives is shown as it comes: an API key without the
  /// Docker permission is an ordinary way to have this set up, and "Action
  /// failed" would leave nothing to act on.
  Future<void> _run(
    Future<UnraidContainer> Function(UnraidClient client) action,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final UnraidClient client =
          await ref.read(unraidClientProvider(widget.instance).future);
      await action(client);
      if (!mounted) return;
      ref.invalidate(unraidContainersProvider(widget.instance));
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is NetworkException ? e.message : 'Action failed.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the container's own web interface.
  ///
  /// The address comes from the container's Unraid template, so a container
  /// without one is never tappable in the first place.
  Future<void> _openWebUi(String url) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the web interface.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final UnraidContainer c = widget.container;

    // A failing healthcheck still reports RUNNING, so state alone would show
    // it as fine. It gets its own icon rather than only its own colour, which
    // a red-green colour blind eye would miss.
    final (IconData icon, Color color) = c.isUnhealthy
        ? (Icons.warning_amber_rounded, cs.error)
        : c.isPaused
            ? (Icons.pause_rounded, cs.tertiary)
            : c.isRunning
                ? (Icons.play_arrow_rounded, _okGreen(cs))
                : (Icons.stop_rounded, cs.outline);

    final String? ports = c.publishedPortsLabel;
    final String subtitle =
        c.status ?? (c.isRunning ? 'Running' : 'Stopped');

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: <Widget>[
          _ContainerAvatar(container: c, icon: icon, color: color),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        c.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.isUpdateAvailable == true) ...<Widget>[
                      const SizedBox(width: Insets.xs),
                      Tooltip(
                        message: 'Update available',
                        child: Icon(
                          Icons.arrow_circle_up_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                      ),
                    ],
                    // Says the row goes somewhere. Without it, tapping to open
                    // the container's web interface is not discoverable at all.
                    if ((c.webUiUrl ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(width: Insets.xs),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  ports == null ? subtitle : '$subtitle  -  $ports',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.isUnhealthy ? cs.error : cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (c.autoStart) ...<Widget>[
            const SizedBox(width: Insets.sm),
            Tooltip(
              message: 'Starts with the array',
              child: Icon(Icons.bolt, size: 18, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(width: Insets.xs),
          _busy
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  // A paused container is offered a resume rather than a
                  // stop: stopping it would throw away the state pausing it
                  // was meant to keep.
                  icon: Icon(
                    c.isRunning
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  tooltip: c.isRunning
                      ? 'Stop'
                      : c.isPaused
                          ? 'Resume'
                          : 'Start',
                  onPressed: () => _run(
                    (UnraidClient client) => switch (c.state) {
                      'RUNNING' => client.stopContainer(c.id),
                      'PAUSED' => client.unpauseContainer(c.id),
                      _ => client.startContainer(c.id),
                    },
                  ),
                ),
        ],
      ),
    );

    // Only a container whose template names a web interface has anywhere to
    // go, so the rest are left inert rather than tapping to nothing.
    final String? web = c.webUiUrl;
    if (web == null || web.isEmpty) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: () => _openWebUi(web), child: row),
    );
  }
}

/// The container's own icon when its Unraid template names one, and the state
/// glyph when it does not.
///
/// A container created outside the web UI has no template and so no icon,
/// which is common enough that it cannot be treated as an error.
class _ContainerAvatar extends StatelessWidget {
  const _ContainerAvatar({
    required this.container,
    required this.icon,
    required this.color,
  });

  final UnraidContainer container;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String? url = container.iconUrl;

    final Widget fallback = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );

    if (url == null || url.isEmpty) return fallback;

    return Stack(
      alignment: Alignment.bottomRight,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Image.network(
            url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            // A broken or unreachable icon is not worth an error state; the
            // glyph says everything the row actually needs to.
            errorBuilder: (_, __, ___) => fallback,
            frameBuilder: (
              BuildContext context,
              Widget child,
              int? frame,
              bool wasSynchronouslyLoaded,
            ) =>
                wasSynchronouslyLoaded || frame != null ? child : fallback,
          ),
        ),
        // The state still has to be readable at a glance once the icon takes
        // the place the state glyph used to hold.
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              width: 2,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? sub = trailing;

    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (sub != null)
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.md,
        horizontal: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: const Center(child: ExpressiveProgressIndicator()),
    );
  }
}
