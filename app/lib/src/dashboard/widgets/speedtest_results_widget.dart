import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class DashboardSpeedtestResultsWidget extends ConsumerWidget {
  const DashboardSpeedtestResultsWidget({
    required this.instances,
    super.key,
  });

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color accent = ServiceVisuals.accent(ServiceKind.speedtestTracker);
    return DashboardWidgetCard(
      kind: DashboardWidgetKind.speedtestResults,
      accent: accent,
      onTap: instances.length == 1
          ? () => _open(context, instances.first)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < instances.length; index++) ...<Widget>[
            if (index > 0) const Divider(height: Insets.lg),
            _SpeedtestInstanceBlock(
              instance: instances[index],
              showName: instances.length > 1,
              onTap: instances.length > 1
                  ? () => _open(context, instances[index])
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, Instance instance) {
    context.go(
      AtriumRoutes.servicePath(instance.kind.name, instance.id),
    );
  }
}

class _SpeedtestInstanceBlock extends ConsumerWidget {
  const _SpeedtestInstanceBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SpeedtestOverview> overview =
        ref.watch(speedtestOverviewProvider(instance));
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  instance.name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            overview.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.sm),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
              error: (Object error, StackTrace _) => _DashboardError(
                error: error,
                onRetry: () =>
                    ref.invalidate(speedtestOverviewProvider(instance)),
              ),
              data: (SpeedtestOverview data) => _DashboardResult(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardResult extends StatelessWidget {
  const _DashboardResult({required this.data});

  final SpeedtestOverview data;

  @override
  Widget build(BuildContext context) {
    final SpeedtestResult? result = data.latestCompleted;
    final SpeedtestResult? latestAny = data.latestAny;
    if (result == null) {
      if (latestAny?.status.isInProgress ?? false) {
        return const DashboardIdleRow(text: 'Latest speed test is running');
      }
      if (latestAny?.status.isFailure ?? false) {
        return DashboardIdleRow(
          text: 'Latest speed test ${latestAny!.status.label.toLowerCase()}',
        );
      }
      return const DashboardIdleRow(text: 'No completed results');
    }

    final ThemeData theme = Theme.of(context);
    final bool latestFailed = latestAny != null &&
        latestAny.id != result.id &&
        latestAny.status.isFailure;
    final bool latestRunning = latestAny != null &&
        latestAny.id != result.id &&
        latestAny.status.isInProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (latestFailed || latestRunning) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                latestFailed ? Icons.warning_amber : Icons.schedule,
                size: 17,
                color: latestFailed
                    ? theme.colorScheme.error
                    : theme.colorScheme.tertiary,
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text(
                  latestFailed
                      ? 'Latest speed test ${latestAny.status.label.toLowerCase()}'
                      : 'Latest speed test is ${latestAny.status.label.toLowerCase()}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _DashboardMetric(
                label: 'Download',
                value: formatSpeed(result.downloadBitsPerSecond),
              ),
            ),
            Expanded(
              child: _DashboardMetric(
                label: 'Upload',
                value: formatSpeed(result.uploadBitsPerSecond),
              ),
            ),
            Expanded(
              child: _DashboardMetric(
                label: 'Ping',
                value: formatMilliseconds(result.pingMilliseconds),
              ),
            ),
            if (result.packetLossPercent != null)
              Expanded(
                child: _DashboardMetric(
                  label: 'Loss',
                  value: formatPacketLoss(result.packetLossPercent),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Text(
          <String>[
            if (result.serverOrProvider != null) result.serverOrProvider!,
            _formatTime(result.completedAt),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? value) => value == null
      ? 'Unknown time'
      : DateFormat.MMMd().add_jm().format(
            value.isUtc ? value.toLocal() : value,
          );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String message = error is SpeedtestTrackerException
        ? (error as SpeedtestTrackerException).message
        : 'Could not load Speedtest Tracker results.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message, style: Theme.of(context).textTheme.bodySmall),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
