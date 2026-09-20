import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/myspeed_status.dart';
import '../models/myspeed_test.dart';
import '../myspeed_providers.dart';
import '../widgets/myspeed_test_card.dart';

/// Tab 0: Status & control tab.
///
/// Displays:
/// 1. Execution status (Running pulse / Idle pill).
/// 2. Manual speedtest trigger button (no flash icon).
/// 3. Most recent speedtest result with accurate time.
/// 4. 24-hour speedtest results with accurate times.
/// Polls information every 5 seconds.
class MySpeedStatusTab extends ConsumerStatefulWidget {
  const MySpeedStatusTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<MySpeedStatusTab> createState() => _MySpeedStatusTabState();
}

class _MySpeedStatusTabState extends ConsumerState<MySpeedStatusTab> {
  Timer? _pollingTimer;
  bool _isLocallyRunning = false;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    final int activeTab = ref.read(myspeedActiveTabBarIndexProvider(widget.instance));
    final bool wasRunning = _isLocallyRunning ||
        (ref.read(myspeedStatusProvider(widget.instance)).value?.isRunning ?? false);
    if (activeTab != 0 && !wasRunning) return;

    ref.invalidate(myspeedStatusProvider(widget.instance));
    // The day's list is a few hundred rows. It changes when a run ends, so
    // it is re-read then, and once a minute for a scheduled run the status
    // poll happened to miss.
    _ticks++;
    if (_ticks % 12 == 0) {
      ref.invalidate(myspeed24HourTestsProvider(widget.instance));
    }

    MySpeedStatus? newStatus;
    try {
      newStatus = await ref.read(myspeedStatusProvider(widget.instance).future);
    } catch (_) {
      newStatus = null;
    }

    final bool isNowRunning = newStatus?.isRunning ?? false;

    if (mounted) {
      if (isNowRunning && _isLocallyRunning) {
        setState(() => _isLocallyRunning = false);
      } else if (wasRunning && !isNowRunning && _isLocallyRunning) {
        setState(() => _isLocallyRunning = false);
      }
    }

    // The widget may have gone while the status was in flight, and its ref
    // with it.
    if (!mounted) return;
    if (wasRunning && !isNowRunning) {
      ref.invalidate(myspeed24HourTestsProvider(widget.instance));
      await ref.read(myspeedHistoryProvider(widget.instance).notifier).fetchDiff();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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

    // Immediately reflect running state in UI
    setState(() => _isLocallyRunning = true);

    try {
      final api = await ref.read(myspeedApiProvider(widget.instance).future);
      await api.runSpeedtest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speedtest triggered successfully')),
      );
      await _poll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocallyRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger speedtest: $e')),
      );
      ref.invalidate(myspeedStatusProvider(widget.instance));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AsyncValue<MySpeedStatus> statusAsync =
        ref.watch(myspeedStatusProvider(widget.instance));
    final MySpeedTest? latestTest = ref.watch(myspeedLatestTestProvider(widget.instance));
    final AsyncValue<List<MySpeedTest>> speedtests24hAsync =
        ref.watch(myspeed24HourTestsProvider(widget.instance));

    return AsyncValueView<MySpeedStatus>(
      value: statusAsync,
      onRetry: () {
        ref.invalidate(myspeedStatusProvider(widget.instance));
        ref.invalidate(myspeed24HourTestsProvider(widget.instance));
        ref.invalidate(myspeedHistoryProvider(widget.instance));
      },
      data: (MySpeedStatus status) {
        final MySpeedStatus effectiveStatus = _isLocallyRunning
            ? const MySpeedStatus(
                isRunning: true,
                message: 'Speedtest in progress...',
              )
            : status;

        return EasyRefresh(
          onRefresh: () async {
            ref.invalidate(myspeedStatusProvider(widget.instance));
            ref.invalidate(myspeed24HourTestsProvider(widget.instance));
            await Future.wait(<Future<dynamic>>[
              ref.read(myspeedStatusProvider(widget.instance).future),
              ref.read(myspeed24HourTestsProvider(widget.instance).future),
              ref.read(myspeedHistoryProvider(widget.instance).notifier).fetchDiff(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: Insets.page,
            children: <Widget>[
              _buildStatusCard(context, effectiveStatus),
              const SizedBox(height: Insets.md),
              _buildLatestResultCard(context, latestTest, speedtests24hAsync),
              const SizedBox(height: Insets.lg),
              Divider(color: colors.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: Insets.md),
              _build24HourResultsSection(context, speedtests24hAsync),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, MySpeedStatus status) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isRunning = status.isRunning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isRunning
              ? colors.primary.withValues(alpha: 0.5)
              : colors.outlineVariant.withValues(alpha: 0.5),
          width: isRunning ? 1.5 : 1.0,
        ),
      ),
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning
                        ? colors.primaryContainer.withValues(alpha: 0.35)
                        : colors.surfaceContainerHigh,
                  ),
                  child: Icon(
                    isRunning ? Icons.network_check_rounded : Icons.speed_rounded,
                    color: isRunning ? colors.primary : colors.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Execution status',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        isRunning ? 'Speedtest running' : 'Idle',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isRunning ? colors.primary : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? colors.primaryContainer.withValues(alpha: 0.35)
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isRunning
                          ? colors.primary.withValues(alpha: 0.5)
                          : colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isRunning ? 'ACTIVE' : 'IDLE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isRunning ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: Insets.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isRunning
                    ? 'A speedtest is currently executing on your MySpeed instance.'
                    : 'No speedtest is currently running. Server is ready.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (status.message != null && status.message!.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Message: ${status.message}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.outline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isRunning ? null : _runSpeedtest,
                child: isRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Run test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestResultCard(
    BuildContext context,
    MySpeedTest? latest,
    AsyncValue<List<MySpeedTest>> historyAsync,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Most recent result',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (latest != null && latest.id.isNotEmpty) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '#${latest.id}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (latest?.createdAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      latest!.formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            if (latest != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: MySpeedMetricBox(
                      icon: Icons.arrow_downward_rounded,
                      label: 'DOWN',
                      value: latest.download.toStringAsFixed(1),
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
                      value: latest.upload.toStringAsFixed(1),
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
                      value: latest.ping.toStringAsFixed(0),
                      unit: 'ms',
                      iconColor: colors.secondary,
                      boxColor: colors.secondaryContainer.withValues(alpha: 0.25),
                      borderColor: colors.secondary.withValues(alpha: 0.25),
                    ),
                  ),
                  if (latest.jitter != null) ...<Widget>[
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: MySpeedMetricBox(
                        icon: Icons.graphic_eq_rounded,
                        label: 'JITTER',
                        value: latest.jitter!.toStringAsFixed(0),
                        unit: 'ms',
                        iconColor: colors.onSurfaceVariant,
                        boxColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderColor: colors.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ],
              ),
              if (latest.server != null && latest.server!.isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.md),
                Divider(color: colors.outlineVariant.withValues(alpha: 0.3)),
                const SizedBox(height: Insets.xs),
                Text(
                  'Server: ${latest.server}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ] else if (historyAsync.isLoading) ...<Widget>[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...<Widget>[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.lg),
                  child: Text('No completed speedtests in the last 24 hours.'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _build24HourResultsSection(
    BuildContext context,
    AsyncValue<List<MySpeedTest>> historyAsync,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Recent results',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              historyAsync.maybeWhen(
                data: (List<MySpeedTest> tests) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tests.length == 1 ? '1 test' : '${tests.length} tests',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        historyAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (Object error, _) => Card(
            elevation: 0,
            color: colors.errorContainer.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(
                'Error loading 24-hour results: $error',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          ),
          data: (List<MySpeedTest> tests) {
            if (tests.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                color: colors.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Center(
                    child: Text(
                      'No speedtests recorded in the past 24 hours.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: tests.map((MySpeedTest test) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: MySpeedTestCard(test: test),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
