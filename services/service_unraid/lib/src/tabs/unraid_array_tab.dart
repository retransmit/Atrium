import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/unraid_models.dart';
import '../unraid_providers.dart';
import '../widgets/unraid_common.dart';

class _ArrayBody extends StatelessWidget {
  const _ArrayBody({required this.array});

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
          UnraidSectionHeader(
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
    final Color accent = started ? unraidOkGreen(cs) : cs.onSurfaceVariant;

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
            UnraidUsageBar(fraction: used, label: usage, caption: 'Array'),
          ],
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: UnraidStatBox(
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
                child: UnraidStatBox(
                  label: 'WARMEST',
                  value: warmest?.temp == null ? '--' : '${warmest!.temp}',
                  unit: warmest == null ? 'all idle' : warmest.name,
                  valueColor: warmest == null
                      ? cs.onSurfaceVariant
                      : unraidHeatColor(warmest.heat, cs),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: UnraidStatBox(
                  label: 'HEALTH',
                  value: faults.isEmpty ? 'OK' : '${faults.length}',
                  unit: faults.isEmpty ? 'all disks' : 'need attention',
                  valueColor: faults.isEmpty ? unraidOkGreen(cs) : cs.error,
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
      final String when = unraidAgo(check.date);
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
            UnraidUsageBar(fraction: used, label: usage),
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

    final Color color = unraidHeatColor(disk.heat, cs);
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

/// Array state, its parity check and every disk.
class UnraidArrayTab extends ConsumerWidget {
  const UnraidArrayTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UnraidArray> array =
        ref.watch(unraidArrayProvider(instance));

    return UnraidTabScaffold(
      onRefresh: () => ref.invalidate(unraidArrayProvider(instance)),
      children: <Widget>[
        AsyncValueView<UnraidArray>(
          value: array,
          onRetry: () => ref.invalidate(unraidArrayProvider(instance)),
          loading: const UnraidCardPlaceholder(height: 210),
          data: (UnraidArray value) => _ArrayBody(array: value),
        ),
      ],
    );
  }
}
