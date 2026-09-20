import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_dashdot/service_dashdot.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class DashboardDashdotWidget extends ConsumerWidget {
  const DashboardDashdotWidget({required this.instances, super.key});

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color accent = Theme.of(context).colorScheme.primary;

    if (instances.isEmpty) {
      return DashboardWidgetCard(
        kind: DashboardWidgetKind.dashdot,
        accent: accent,
        child: const DashboardIdleRow(text: 'No Dashdot instances configured'),
      );
    }

    final bool showName = instances.length > 1;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < instances.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Insets.md),
          _DashdotInstanceBlock(
            instance: instances[i],
            showName: showName,
            onTap: () => _open(context, instances[i]),
          ),
        ],
      ],
    );

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.dashdot,
      accent: accent,
      onTap:
          instances.length == 1 ? () => _open(context, instances.first) : null,
      child: body,
    );
  }

  void _open(BuildContext context, Instance instance) {
    context.go(AtriumRoutes.servicePath(instance.kind.name, instance.id));
  }
}

class _DashdotInstanceBlock extends ConsumerWidget {
  const _DashdotInstanceBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // Network history (down / up)
    final NetworkHistory netHistory =
        ref.watch(dashdotNetworkHistoryProvider(instance));
    final double currentDownBytes =
        netHistory.down.isNotEmpty ? netHistory.down.last : 0.0;
    final double currentUpBytes =
        netHistory.up.isNotEmpty ? netHistory.up.last : 0.0;

    // CPU temp
    final CpuHistoryState cpuHistoryState =
        ref.watch(dashdotCpuHistoryProvider(instance));
    double cpuTemp = 0.0;
    if (cpuHistoryState.cores.isNotEmpty &&
        cpuHistoryState.cores.first.temps.isNotEmpty) {
      cpuTemp = cpuHistoryState.cores.first.temps.last;
    }

    // Uptime
    final DashdotInfo? info = ref.watch(dashdotInfoProvider(instance)).value;
    final int uptimeSecs = (info?.os?.uptime ?? 0).toInt();
    final int days = uptimeSecs ~/ 86400;
    final int hours = (uptimeSecs % 86400) ~/ 3600;
    final int mins = (uptimeSecs % 3600) ~/ 60;
    final String uptimeStr = days > 0
        ? '${days}d ${hours}h'
        : (hours > 0 ? '${hours}h ${mins}m' : '${mins}m');

    return InkWell(
      onTap: showName ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: showName ? const EdgeInsets.all(Insets.xs) : EdgeInsets.zero,
        child: Column(
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
            DashdotRingMetrics(instance: instance),
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DashdotStatPill(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: cs.primary,
                    label: 'Down',
                    value: _formatSpeed(currentDownBytes),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: _DashdotStatPill(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: cs.tertiary,
                    label: 'Up',
                    value: _formatSpeed(currentUpBytes),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: _DashdotStatPill(
                    icon: Icons.thermostat_rounded,
                    iconColor: cpuTemp >= 80
                        ? cs.error
                        : (cpuTemp > 0 ? cs.secondary : cs.outline),
                    label: 'Temp',
                    value: cpuTemp > 0 ? '${cpuTemp.toStringAsFixed(0)}°' : '--',
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: _DashdotStatPill(
                    icon: Icons.timer_outlined,
                    iconColor: cs.outline,
                    label: 'Uptime',
                    value: uptimeSecs > 0 ? uptimeStr : '--',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1048576) {
      return '${(bytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }
}

class _DashdotStatPill extends StatelessWidget {
  const _DashdotStatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
