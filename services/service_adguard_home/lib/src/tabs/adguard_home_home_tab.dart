import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adguard_home_blocking.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../adguard_home_top_lists.dart';
import '../models/adguard_home_filtering.dart';
import '../models/adguard_home_stats.dart';
import '../models/adguard_home_status.dart';
import '../screens/adguard_home_top_list_screen.dart';
import '../widgets/adguard_home_chart_card.dart';
import '../widgets/adguard_home_client_sheet.dart';
import '../widgets/adguard_home_protection_card.dart';
import '../widgets/adguard_home_refused_view.dart';
import '../widgets/adguard_home_stat_tile.dart';
import '../widgets/adguard_home_top_list.dart';

/// Protection, the statistics for the period the server keeps, and the top
/// lists.
class AdguardHomeHomeTab extends ConsumerStatefulWidget {
  const AdguardHomeHomeTab({
    required this.instance,
    this.now = DateTime.now,
    super.key,
  });

  final Instance instance;

  /// The clock the pause countdown runs on. Tests hand in their own.
  final DateTime Function() now;

  @override
  ConsumerState<AdguardHomeHomeTab> createState() => _AdguardHomeHomeTabState();
}

class _AdguardHomeHomeTabState extends ConsumerState<AdguardHomeHomeTab> {
  bool _busy = false;

  Instance get _instance => widget.instance;

  AdguardHomeActions get _actions =>
      ref.read(adguardHomeActionsProvider(_instance));

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setProtection({required bool enabled, Duration? pause}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _actions.setProtection(enabled: enabled, pause: pause);
    } on Object catch (error) {
      _say(describeAdguardHomeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit() {
    context.pushNamed(
      AtriumRoutes.editInstanceName,
      pathParameters: <String, String>{'instanceId': _instance.id},
    );
  }

  /// Reads everything again and holds the pull-to-refresh indicator until
  /// the status is back.
  Future<void> _refresh() async {
    _actions.refresh();
    try {
      await ref.read(adguardHomeStatusProvider(_instance).future);
    } on Object {
      // The tab shows the failure itself; the indicator only has to stop.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeStatus> status =
        ref.watch(adguardHomeStatusProvider(_instance));
    final AsyncValue<AdguardHomeStats> stats =
        ref.watch(adguardHomeStatsProvider(_instance));
    final Duration? period =
        ref.watch(adguardHomeStatsPeriodProvider(_instance)).value;
    final AdguardHomeFiltering? filtering =
        ref.watch(adguardHomeFilteringProvider(_instance)).value;

    if (status.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: _actions.retrySignIn,
        onEdit: _edit,
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }

    return status.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => ErrorView(
        message: describeAdguardHomeError(error),
        onRetry: _actions.refresh,
      ),
      data: (AdguardHomeStatus status) => EasyRefresh(
        onRefresh: _refresh,
        child: ListView(
          padding: Insets.page,
          children: <Widget>[
            AdguardHomeProtectionCard(
              status: status,
              busy: _busy,
              onSet: _setProtection,
              onPauseEnded: () =>
                  ref.invalidate(adguardHomeStatusProvider(_instance)),
              now: widget.now,
            ),
            const SizedBox(height: Insets.lg),
            ..._statistics(context, stats, period, filtering),
          ],
        ),
      ),
    );
  }

  List<Widget> _statistics(
    BuildContext context,
    AsyncValue<AdguardHomeStats> stats,
    Duration? period,
    AdguardHomeFiltering? filtering,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return stats.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const <Widget>[
        Padding(
          padding: EdgeInsets.all(Insets.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (Object error, StackTrace _) => <Widget>[
        Text(
          describeAdguardHomeError(error),
          style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
        ),
      ],
      data: (AdguardHomeStats stats) => <Widget>[
        Text(
          period == null ? 'Statistics' : adguardHomePeriodLabel(period),
          style: theme.textTheme.titleSmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.sm),
        AdguardHomeChartCard(
          label: 'DNS queries',
          value: formatAdguardHomeCount(stats.queries),
          // The average belongs with the queries it is an average of.
          detail: 'avg '
              '${formatAdguardHomeProcessingTime(stats.averageProcessingTime)}',
          color: cs.primary,
          series: stats.queriesSeries,
        ),
        const SizedBox(height: Insets.sm),
        AdguardHomeChartCard(
          label: 'Blocked by filters',
          value: formatAdguardHomeCount(stats.blockedByFilters),
          detail: formatAdguardHomePercent(stats.blockedPercent),
          color: cs.error,
          series: stats.blockedSeries,
        ),
        const SizedBox(height: Insets.sm),
        _TileRow(
          AdguardHomeStatTile(
            label: 'Blocked malware and phishing',
            value: formatAdguardHomeCount(stats.blockedThreats),
            color: cs.tertiary,
            series: stats.threatsSeries,
          ),
          AdguardHomeStatTile(
            label: 'Blocked adult websites',
            value: formatAdguardHomeCount(stats.blockedAdult),
            color: cs.secondary,
            series: stats.adultSeries,
          ),
        ),
        const SizedBox(height: Insets.sm),
        _TileRow(
          AdguardHomeStatTile(
            label: 'Enforced safe search',
            value: formatAdguardHomeCount(stats.safeSearchEnforced),
            color: cs.primary,
          ),
          // Not a figure of the period like the others: how much the
          // blocklists that are switched on hold right now.
          AdguardHomeStatTile(
            label: 'Rules on blocklists',
            value: filtering == null
                ? '-'
                : formatAdguardHomeCount(filtering.rulesOnBlocklists),
            color: cs.primary,
          ),
        ),
        for (final AdguardHomeTopListKind kind
            in AdguardHomeTopListKind.values)
          // The response times have nothing to show until an upstream has
          // answered, and an empty card for them would only be noise.
          if (kind != AdguardHomeTopListKind.upstreamTimes ||
              kind.rows(stats).isNotEmpty) ...<Widget>[
            SizedBox(
              height: kind == AdguardHomeTopListKind.values.first
                  ? Insets.lg
                  : Insets.sm,
            ),
            AdguardHomeTopList(
              kind: kind,
              rows: kind.rows(stats),
              onBlocking: (String domain, {required bool block}) =>
                  adguardHomeToggleBlocking(
                context,
                ref,
                _instance,
                domain,
                block: block,
              ),
              // A client's row opens the client: who is behind the address,
              // and a way to its settings.
              onOpen: kind == AdguardHomeTopListKind.clients
                  ? (AdguardHomeCount row) => showAdguardHomeClientSheet(
                        context,
                        instance: _instance,
                        address: row.name,
                        queries: row.value.toInt(),
                      )
                  : null,
              onViewAll: () => pushScreen<void>(
                context,
                AdguardHomeTopListScreen(instance: _instance, kind: kind),
              ),
            ),
          ],
      ],
    );
  }
}

/// Two tiles side by side, as tall as the taller of them.
class _TileRow extends StatelessWidget {
  const _TileRow(this.first, this.second);

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: first),
          const SizedBox(width: Insets.sm),
          Expanded(child: second),
        ],
      ),
    );
  }
}
