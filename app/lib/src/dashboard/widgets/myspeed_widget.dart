import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_myspeed/service_myspeed.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// Compact dashboard widget for MySpeed.
///
/// Displays the most recent speedtest result (down, up, ping) and a compact
/// "Run test" button with live status tracking and confirmation dialog.
class DashboardMySpeedWidget extends ConsumerWidget {
  const DashboardMySpeedWidget({
    required this.instances,
    super.key,
  });

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return DashboardWidgetCard(
      kind: DashboardWidgetKind.myspeed,
      accent: accent,
      onTap: instances.length == 1
          ? () => _open(context, instances.first)
          : null,
      child: instances.isEmpty
          ? const DashboardIdleRow(text: 'No MySpeed instances configured')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < instances.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: Insets.lg),
                  _MySpeedInstanceBlock(
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

class _MySpeedInstanceBlock extends ConsumerStatefulWidget {
  const _MySpeedInstanceBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback? onTap;

  @override
  ConsumerState<_MySpeedInstanceBlock> createState() =>
      _MySpeedInstanceBlockState();
}

class _MySpeedInstanceBlockState extends ConsumerState<_MySpeedInstanceBlock> {
  bool _isLocallyRunning = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) async {
      ref.invalidate(myspeedStatusProvider(widget.instance));
      MySpeedStatus? newStatus;
      try {
        newStatus =
            await ref.read(myspeedStatusProvider(widget.instance).future);
      } catch (_) {
        newStatus = null;
      }

      final bool stillRunning = newStatus?.isRunning ?? false;
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!stillRunning) {
        timer.cancel();
        setState(() => _isLocallyRunning = false);
        ref.invalidate(myspeedRecentTestsProvider(widget.instance));
      }
    });
  }

  Future<void> _runSpeedtest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Run speedtest'),
        content: Text('Start a new speedtest on ${widget.instance.name}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLocallyRunning = true);

    try {
      final MySpeedApi api =
          await ref.read(myspeedApiProvider(widget.instance).future);
      await api.runSpeedtest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speedtest triggered successfully')),
      );
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocallyRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger speedtest: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AsyncValue<MySpeedStatus> statusAsync =
        ref.watch(myspeedStatusProvider(widget.instance));
    // The newest few tests at any age: the day's window is empty for a
    // weekly schedule, and the History tab's list is far more than a card
    // needs.
    final MySpeedTest? latest = myspeedLatestGood(
      ref.watch(myspeedRecentTestsProvider(widget.instance)).value,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.showName)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  widget.instance.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
            statusAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => latest != null
                  ? _buildContent(context, statusAsync.value, latest)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.sm),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
              error: (Object error, StackTrace _) => latest != null
                  ? _buildContent(context, statusAsync.value, latest)
                  : DashboardErrorRow(
                      onRetry: () {
                        ref.invalidate(myspeedStatusProvider(widget.instance));
                        ref.invalidate(
                          myspeedRecentTestsProvider(widget.instance),
                        );
                      },
                    ),
              data: (MySpeedStatus status) =>
                  _buildContent(context, status, latest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MySpeedStatus? status,
    MySpeedTest? latest,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isRunning = _isLocallyRunning || (status?.isRunning ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MySpeedMetricBox(
                icon: Icons.arrow_downward_rounded,
                label: 'DOWN',
                value: latest != null
                    ? latest.download.toStringAsFixed(1)
                    : '--',
                unit: 'Mbps',
                iconColor: colors.primary,
                boxColor: colors.primaryContainer.withValues(alpha: 0.25),
                borderColor: colors.primary.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: Insets.xs),
            Expanded(
              child: MySpeedMetricBox(
                icon: Icons.arrow_upward_rounded,
                label: 'UP',
                value:
                    latest != null ? latest.upload.toStringAsFixed(1) : '--',
                unit: 'Mbps',
                iconColor: colors.tertiary,
                boxColor: colors.tertiaryContainer.withValues(alpha: 0.25),
                borderColor: colors.tertiary.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: Insets.xs),
            Expanded(
              child: MySpeedMetricBox(
                icon: Icons.timer_outlined,
                label: 'PING',
                value: latest != null ? latest.ping.toStringAsFixed(0) : '--',
                unit: 'ms',
                iconColor: colors.secondary,
                boxColor: colors.secondaryContainer.withValues(alpha: 0.25),
                borderColor: colors.secondary.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            if (latest?.createdAt != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      latest!.formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.xs),
            ],
            Expanded(
              child: Text(
                latest?.server != null && latest!.server!.isNotEmpty
                    ? latest.server!
                    : (latest?.createdAt == null ? 'No results yet' : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isRunning ? null : _runSpeedtest,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isRunning
                    ? SizedBox(
                        key: const ValueKey<String>('running-spinner'),
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onSecondaryContainer,
                        ),
                      )
                    : const Row(
                        key: ValueKey<String>('run-button-content'),
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.play_arrow_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('Run test'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
