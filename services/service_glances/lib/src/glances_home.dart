import 'dart:math' as math;

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_collection/m3e_collection.dart';

import 'glances_providers.dart';
import 'models/glances_stats.dart';
import 'package:m3_expressive/m3_expressive.dart';

class GlancesHome extends ConsumerWidget {
  const GlancesHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GlancesStats> statsAsync =
        ref.watch(glancesStatsProvider(instance));
    final Set<String> pinnedNets =
        ref.watch(glancesPinnedNetworkProvider(instance));

    return statsAsync.when(
      data: (GlancesStats stats) => M3RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(glancesStatsProvider(instance).future),
        child: ListView(
          padding: Insets.page,
          children: <Widget>[
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: Insets.md),
              shape: RoundedRectangleBorder(
                borderRadius: Radii.card,
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.schedule_outlined,
                        color: Color(0xFF3B82F6)),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        'System Uptime',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      _formatUptime(stats.uptime),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            _buildGauges(context, stats),
            const SizedBox(height: Insets.md),
            _buildCoresCard(context, stats.cpu),
            const SizedBox(height: Insets.md),
            _buildNetworkSectionHeader(context, ref, stats.network),
            ...stats.network
                .where((GlancesNetwork n) =>
                    pinnedNets.isEmpty || pinnedNets.contains(n.interface))
                .map((GlancesNetwork n) => _buildNetworkCard(context, n)),
            const SizedBox(height: Insets.md),
            _buildSectionHeader(context, 'Disks', Icons.storage_outlined),
            ...stats.disks.map((GlancesDisk d) => _buildDiskCard(context, d)),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicatorM3E()),
      error: (Object e, StackTrace st) => Center(
        child: Padding(
          padding: Insets.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Failed to load stats',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUptime(GlancesUptime uptime) {
    final List<String> parts = <String>[];
    if (uptime.days > 0) parts.add('${uptime.days}d');
    if (uptime.hours > 0) parts.add('${uptime.hours}h');
    if (uptime.minutes > 0) parts.add('${uptime.minutes}m');
    parts.add('${uptime.seconds}s');
    return parts.join(' ');
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Insets.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSectionHeader(
      BuildContext context, WidgetRef ref, List<GlancesNetwork> networks) {
    final Set<String> pinnedNets =
        ref.watch(glancesPinnedNetworkProvider(instance));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: <Widget>[
          Icon(Icons.network_check_outlined,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Insets.sm),
          Text(
            'Network',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (pinnedNets.isNotEmpty) ...<Widget>[
            const SizedBox(width: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pinnedNets.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Interfaces',
            onPressed: () {
              _showNetworkFilterDialog(context, ref, networks);
            },
          ),
        ],
      ),
    );
  }

  void _showNetworkFilterDialog(BuildContext context, WidgetRef parentRef,
      List<GlancesNetwork> networks) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final Set<String> pinnedNets =
                ref.watch(glancesPinnedNetworkProvider(instance));
            return AlertDialog(
              title: const Text('Filter Network Interfaces'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: networks.map((GlancesNetwork net) {
                    final bool isSelected = pinnedNets.isEmpty ||
                        pinnedNets.contains(net.interface);
                    return CheckboxListTile(
                      title: Text(net.interface),
                      value: isSelected,
                      onChanged: (bool? checked) {
                        final Set<String> newSet = Set<String>.from(pinnedNets);
                        if (pinnedNets.isEmpty) {
                          if (checked != true) {
                            newSet.addAll(networks
                                .map((GlancesNetwork e) => e.interface));
                            newSet.remove(net.interface);
                          }
                        } else {
                          if (checked == true) {
                            newSet.add(net.interface);
                          } else {
                            newSet.remove(net.interface);
                          }
                          if (newSet.length == networks.length) {
                            newSet.clear();
                          }
                        }
                        ref
                            .read(
                                glancesPinnedNetworkProvider(instance).notifier)
                            .set(newSet);
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    ref
                        .read(glancesPinnedNetworkProvider(instance).notifier)
                        .set(<String>{});
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGauges(BuildContext context, GlancesStats stats) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _GaugeCard(
                title: 'CPU',
                percent: stats.cpu.totalUsage / 100.0,
                subtitle: '${stats.cpu.packageTemp.toStringAsFixed(1)}°C',
                subtitleIcon: Icons.thermostat_outlined,
                icon: Icons.speed_outlined,
                color: const Color(0xFF10B981), // Emerald green
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _GaugeCard(
                title: 'Memory',
                percent: stats.memory.percentage / 100.0,
                subtitle:
                    '${(stats.memory.used / 1024 / 1024 / 1024).toStringAsFixed(2)} / ${(stats.memory.total / 1024 / 1024 / 1024).toStringAsFixed(2)} GB',
                subtitleIcon: Icons.data_usage_outlined,
                icon: Icons.memory_outlined,
                color: const Color(0xFF6366F1), // Indigo
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.card,
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: <Widget>[
                const Icon(Icons.swap_horiz_outlined, color: Color(0xFFF59E0B)),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Swap',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 10,
                        child: CustomPaint(
                          painter: _FlatLinearPainter(
                            value:
                                (stats.swap.percentage / 100.0).clamp(0.0, 1.0),
                            track:
                                const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            active: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${stats.swap.percentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${(stats.swap.used / 1024 / 1024 / 1024).toStringAsFixed(2)} / ${(stats.swap.total / 1024 / 1024 / 1024).toStringAsFixed(2)} GB',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoresCard(BuildContext context, GlancesCpu cpu) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.developer_board,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: Insets.sm),
                Text(
                  'Cores (${cpu.physicalCores} Phys, ${cpu.logicalCores} Log)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            ...cpu.cores.map((GlancesCpuCore core) {
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 60,
                      child: Text('Core ${core.id}',
                          style: theme.textTheme.labelMedium),
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 0.0,
                            end: (core.usage / 100.0).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (BuildContext context, double value,
                            Widget? child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 10,
                            child: CustomPaint(
                              painter: _FlatLinearPainter(
                                value: value,
                                track: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.1),
                                active: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${core.usage.toStringAsFixed(1)}%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDiskCard(BuildContext context, GlancesDisk disk) {
    final double pct = disk.percentage / 100.0;
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.dns_outlined, size: 20),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    disk.path,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  '${disk.percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            SizedBox(
              width: double.infinity,
              height: 10,
              child: CustomPaint(
                painter: _FlatLinearPainter(
                  value: pct.clamp(0.0, 1.0),
                  track: Theme.of(context).colorScheme.surfaceContainerHighest,
                  active: pct > 0.9
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${(disk.used / 1024 / 1024 / 1024).toStringAsFixed(2)} GB used',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  '${(disk.total / 1024 / 1024 / 1024).toStringAsFixed(2)} GB total',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard(BuildContext context, GlancesNetwork net) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: Insets.page,
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.router_outlined,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(net.interface, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(Icons.arrow_upward,
                          size: 14, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatBytes(net.txSpeed)}/s',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(width: Insets.lg),
                      Icon(Icons.arrow_downward,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatBytes(net.rxSpeed)}/s',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes > 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.title,
    required this.percent,
    required this.subtitle,
    this.subtitleIcon,
    required this.icon,
    required this.color,
  });

  final String title;
  final double percent;
  final String subtitle;
  final IconData? subtitleIcon;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: Insets.lg, horizontal: Insets.md),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Center(
                    child: Transform.scale(
                      scale: 80 / 52,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 0.0, end: percent.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (BuildContext context, double value,
                            Widget? child) {
                          return SizedBox(
                            width: 52,
                            height: 52,
                            child: CustomPaint(
                              painter: _FlatCircularPainter(
                                value: value,
                                track: color.withValues(alpha: 0.15),
                                active: color,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (subtitleIcon != null) ...<Widget>[
                  Icon(
                    subtitleIcon,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatCircularPainter extends CustomPainter {
  _FlatCircularPainter({
    required this.value,
    required this.active,
    required this.track,
  });

  final double value;
  final Color active;
  final Color track;

  @override
  void paint(Canvas canvas, Size s) {
    const double stroke = 4.0;
    final Offset center = s.center(Offset.zero);
    final double baseRadius = (math.min(s.width, s.height) - stroke) / 2;

    final double activeSweep = value.clamp(0.0, 1.0) * math.pi * 2;
    const double start = -math.pi / 2;
    final double end = start + activeSweep;

    final bool waveOnly = value >= 1.0;
    if (!waveOnly) {
      final Paint trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = track;

      final double gapAngle = 8.0 / baseRadius;
      final Rect rect = Rect.fromCircle(center: center, radius: baseRadius);
      final double total = math.pi * 2;
      final double a1 = end + gapAngle;
      final double a2 = start - gapAngle;
      double sweep1 = a2 - a1;
      while (sweep1 <= 0) {
        sweep1 += total;
      }
      canvas.drawArc(rect, a1, sweep1, false, trackPaint);
    }

    if (activeSweep > 0) {
      final Paint activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = active;

      final Rect rect = Rect.fromCircle(center: center, radius: baseRadius);
      canvas.drawArc(rect, start, activeSweep, false, activePaint);
    } else {
      final Paint activePaint = Paint()..color = active;
      canvas.drawCircle(
          Offset(center.dx, center.dy - baseRadius), stroke / 2, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlatCircularPainter old) =>
      value != old.value || active != old.active || track != old.track;
}

class _FlatLinearPainter extends CustomPainter {
  _FlatLinearPainter({
    required this.value,
    required this.active,
    required this.track,
  });

  final double value;
  final Color active;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 0.0;
    final double right = size.width - 10.0;
    final double width = math.max(0.0, right - left);

    final double cy = size.height / 2;
    const double stroke = 4.0;
    const double gap = 8.0;

    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final double p = value.clamp(0.0, 1.0);
    final bool waveOnly = p >= 1.0;

    final double activeEndX = left + width * p;
    final double trackStartX = math.min(right, activeEndX + gap);

    if (!waveOnly && trackStartX < right) {
      canvas.drawLine(
        Offset(trackStartX, cy),
        Offset(right, cy),
        base..color = track,
      );
    }

    final double start = left;
    final double end = activeEndX;
    final double length = end - start;

    if (length > 0) {
      canvas.drawLine(Offset(start, cy), Offset(end, cy), base..color = active);
    } else {
      canvas.drawLine(
          Offset(start, cy), Offset(start, cy), base..color = active);
    }

    if (!waveOnly) {
      final double dotCenterX = math.max(left, right - 2.0);
      canvas.drawCircle(
          Offset(dotCenterX, cy), stroke / 2, Paint()..color = active);
    }
  }

  @override
  bool shouldRepaint(covariant _FlatLinearPainter old) =>
      value != old.value || active != old.active || track != old.track;
}
