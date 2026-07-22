import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/speedtest_tracker_models.dart';
import 'speedtest_tracker_api.dart';
import 'speedtest_tracker_providers.dart';
import 'widgets/speedtest_history_chart.dart';
import 'widgets/speedtest_result_views.dart';

class SpeedtestTrackerHome extends ConsumerStatefulWidget {
  const SpeedtestTrackerHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<SpeedtestTrackerHome> createState() =>
      _SpeedtestTrackerHomeState();
}

class _SpeedtestTrackerHomeState extends ConsumerState<SpeedtestTrackerHome> {
  static const int _historyPageSize = 25;
  int _loadedPages = 1;

  SpeedtestHistoryQuery _query(int page) => (
        instance: widget.instance,
        page: page,
        pageSize: _historyPageSize,
      );

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SpeedtestOverview> overview =
        ref.watch(speedtestOverviewProvider(widget.instance));
    final SpeedtestRunState runState =
        ref.watch(speedtestRunControllerProvider(widget.instance));

    return AsyncValueView<SpeedtestOverview>(
      value: overview,
      onRetry: () => ref.invalidate(speedtestOverviewProvider(widget.instance)),
      data: (SpeedtestOverview data) {
        final _HistorySnapshot history = _watchHistory();
        return EasyRefresh(
          header: const ClassicHeader(
            dragText: 'Pull to refresh',
            armedText: 'Release ready',
            readyText: 'Refreshing...',
            processingText: 'Refreshing...',
            processedText: 'Succeeded',
            failedText: 'Failed',
            messageText: 'Last updated at %T',
          ),
          footer: history.hasMore
              ? const ClassicFooter(
                  dragText: 'Pull to load more',
                  armedText: 'Release ready',
                  readyText: 'Loading...',
                  processingText: 'Loading...',
                  processedText: 'Loaded',
                  failedText: 'Failed',
                  noMoreText: 'No more results',
                  messageText: 'Last updated at %T',
                )
              : null,
          onRefresh: _refresh,
          onLoad: history.hasMore ? _loadMore : null,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: Insets.page,
            children: <Widget>[
              _RunAction(
                instance: widget.instance,
                state: runState,
                onRun: _confirmRun,
              ),
              ..._statusBanners(data, runState),
              const SizedBox(height: Insets.md),
              if (data.latestCompleted case final SpeedtestResult result)
                SpeedtestLatestCard(result: result)
              else
                const _SectionCard(
                  title: 'Latest result',
                  child: EmptyView(
                    icon: Icons.speed_outlined,
                    title: 'No completed results',
                    message: 'Completed speed tests will appear here.',
                  ),
                ),
              const SizedBox(height: Insets.md),
              _SectionCard(
                title: 'Download and upload history',
                child: SpeedtestHistoryChart(
                  results: data.completedResults,
                ),
              ),
              const SizedBox(height: Insets.md),
              _SectionCard(
                title: 'Recent history',
                child: _HistoryBody(
                  snapshot: history,
                  onRetry: () => ref.invalidate(
                    speedtestHistoryProvider(_query(history.failedPage ?? 1)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _HistorySnapshot _watchHistory() {
    final List<SpeedtestResult> results = <SpeedtestResult>[];
    final Set<int> ids = <int>{};
    bool loading = false;
    bool hasMore = true;
    Object? error;
    int? failedPage;
    for (int page = 1; page <= _loadedPages; page++) {
      final AsyncValue<SpeedtestResultsPage> value =
          ref.watch(speedtestHistoryProvider(_query(page)));
      loading |= value.isLoading && !value.hasValue;
      if (value.hasError) {
        error = value.error;
        failedPage = page;
      }
      final SpeedtestResultsPage? data = value.value;
      if (data != null) {
        hasMore = data.hasMore;
        for (final SpeedtestResult result in data.results) {
          if (ids.add(result.id)) {
            results.add(result);
          }
        }
      }
    }
    return _HistorySnapshot(
      results: results,
      loading: loading,
      hasMore: hasMore,
      error: error,
      failedPage: failedPage,
    );
  }

  List<Widget> _statusBanners(
    SpeedtestOverview overview,
    SpeedtestRunState runState,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (runState.phase != SpeedtestRunPhase.idle) {
      final bool busy = runState.isBusy;
      final bool success = runState.phase == SpeedtestRunPhase.completed;
      final bool warning = runState.phase == SpeedtestRunPhase.timedOut ||
          runState.phase == SpeedtestRunPhase.indeterminate;
      final String message = runState.message ??
          runState.result?.status.label ??
          switch (runState.phase) {
            SpeedtestRunPhase.checking =>
              'Checking for an active speed test...',
            SpeedtestRunPhase.submitting => 'Queuing speed test...',
            SpeedtestRunPhase.reconciling =>
              'Checking whether the speed test was accepted...',
            SpeedtestRunPhase.queued => 'Speed test queued...',
            SpeedtestRunPhase.running => 'Speed test running...',
            _ => 'Speed test status unavailable.',
          };
      return <Widget>[
        const SizedBox(height: Insets.md),
        SpeedtestRunBanner(
          icon: success
              ? Icons.check_circle_outline
              : warning
                  ? Icons.schedule
                  : Icons.error_outline,
          message: message,
          color: success
              ? colors.primary
              : busy
                  ? colors.tertiary
                  : colors.error,
          busy: busy,
        ),
      ];
    }

    final SpeedtestResult? latest = overview.latestAny;
    if (latest == null || latest.status == SpeedtestResultStatus.completed) {
      return const <Widget>[];
    }
    if (latest.status.isInProgress) {
      return <Widget>[
        const SizedBox(height: Insets.md),
        SpeedtestRunBanner(
          icon: Icons.speed,
          message:
              'The latest speed test is ${latest.status.label.toLowerCase()}.',
          color: colors.tertiary,
          busy: true,
        ),
      ];
    }
    return <Widget>[
      const SizedBox(height: Insets.md),
      SpeedtestRunBanner(
        icon: Icons.warning_amber,
        message: latest.status == SpeedtestResultStatus.unknown
            ? 'The latest test has a status this Atrium version does not understand.'
            : 'The latest speed test ${latest.status.label.toLowerCase()}.',
        color: colors.error,
      ),
    ];
  }

  Future<void> _confirmRun() async {
    final SpeedtestRunState current =
        ref.read(speedtestRunControllerProvider(widget.instance));
    final bool retryingIndeterminate =
        current.phase == SpeedtestRunPhase.indeterminate;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          retryingIndeterminate ? 'Run another speed test?' : 'Run speed test?',
        ),
        content: Text(
          retryingIndeterminate
              ? 'Atrium could not confirm the previous submission. Running '
                  'again may create a duplicate and can use significant bandwidth.'
              : 'This can use significant bandwidth. Run permission cannot be '
                  'verified until Speedtest Tracker receives the request.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Run test'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(speedtestRunControllerProvider(widget.instance).notifier)
          .run(confirmIndeterminateRetry: retryingIndeterminate);
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() => _loadedPages = 1);
    }
    ref.invalidate(speedtestOverviewProvider(widget.instance));
    ref.invalidate(speedtestHistoryProvider);
    await Future.wait(<Future<Object?>>[
      ref.read(speedtestOverviewProvider(widget.instance).future),
      ref.read(speedtestHistoryProvider(_query(1)).future),
    ]);
  }

  Future<void> _loadMore() async {
    final SpeedtestResultsPage current =
        await ref.read(speedtestHistoryProvider(_query(_loadedPages)).future);
    if (!current.hasMore || !mounted) {
      return;
    }
    setState(() => _loadedPages++);
    await ref.read(speedtestHistoryProvider(_query(_loadedPages)).future);
  }
}

class _RunAction extends StatelessWidget {
  const _RunAction({
    required this.instance,
    required this.state,
    required this.onRun,
  });

  final Instance instance;
  final SpeedtestRunState state;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Internet performance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Results from ${instance.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed:
                state.isBusy || state.isDisabledForSession ? null : onRun,
            icon: state.isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(state.isBusy ? 'Running' : 'Run test'),
          ),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Insets.md),
              child,
            ],
          ),
        ),
      );
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.snapshot, required this.onRetry});

  final _HistorySnapshot snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.results.isEmpty && snapshot.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (snapshot.results.isEmpty && snapshot.error != null) {
      return ErrorView(
        message: _errorMessage(snapshot.error!),
        onRetry: onRetry,
      );
    }
    if (snapshot.results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Insets.lg),
        child: Center(child: Text('No completed results yet.')),
      );
    }
    return Column(
      children: <Widget>[
        for (final SpeedtestResult result in snapshot.results)
          SpeedtestResultTile(
            result: result,
            onTap: () => showSpeedtestResultDetails(context, result),
          ),
        if (snapshot.loading)
          const Padding(
            padding: EdgeInsets.all(Insets.md),
            child: CircularProgressIndicator(),
          ),
        if (snapshot.error != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.sm),
            child: ErrorView(
              title: 'Could not load more results',
              message: _errorMessage(snapshot.error!),
              onRetry: onRetry,
            ),
          ),
      ],
    );
  }

  String _errorMessage(Object error) {
    if (error is SpeedtestTrackerException) {
      return error.message;
    }
    return 'Speedtest Tracker returned an unexpected error.';
  }
}

class _HistorySnapshot {
  const _HistorySnapshot({
    required this.results,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.failedPage,
  });

  final List<SpeedtestResult> results;
  final bool loading;
  final bool hasMore;
  final Object? error;
  final int? failedPage;
}
