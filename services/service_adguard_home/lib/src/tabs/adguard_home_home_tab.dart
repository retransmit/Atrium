import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../adguard_home_rules.dart';
import '../models/adguard_home_stats.dart';
import '../models/adguard_home_status.dart';
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

  void _say(String message, {VoidCallback? onUndo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        onUndo == null
            ? SnackBar(content: Text(message))
            : SnackBar(
                content: Text(message),
                action: SnackBarAction(label: 'Undo', onPressed: onUndo),
                // A message with an action would otherwise stay until it is
                // dismissed. This one leaves by itself, after long enough
                // to read the rule and reach for Undo.
                persist: false,
                duration: const Duration(seconds: 8),
              ),
      );
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

  /// Blocks or unblocks [domain] and says what that did to the custom rules.
  ///
  /// The lists re-read themselves every half minute and can reorder under a
  /// finger, and a block reaches everything that uses the server, so the
  /// message offers to take the change back. Taking it back is the opposite
  /// tap, which undoes an added rule by removing it and a removed one by
  /// adding it again. It is not offered when the rule was already there:
  /// nothing changed, and the opposite tap would remove a rule this one
  /// never added. [undoable] is false for the taking back itself.
  Future<void> _toggleBlocking(
    String domain, {
    required bool block,
    bool undoable = true,
  }) async {
    try {
      final AdguardHomeRuleEdit edit =
          await _actions.toggleBlocking(domain, block: block);
      _say(
        switch (edit.change) {
          AdguardHomeRuleChange.added =>
            'Added ${edit.rule} to the custom rules',
          AdguardHomeRuleChange.removed =>
            'Removed ${edit.rule} from the custom rules',
          AdguardHomeRuleChange.alreadyThere =>
            '${edit.rule} is already in the custom rules',
        },
        onUndo: undoable && edit.change != AdguardHomeRuleChange.alreadyThere
            ? () => _toggleBlocking(domain, block: !block, undoable: false)
            : null,
      );
    } on Object catch (error) {
      _say(describeAdguardHomeError(error));
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

    if (status.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: _actions.retrySignIn,
        onEdit: _edit,
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
            ..._statistics(context, stats, period),
          ],
        ),
      ),
    );
  }

  List<Widget> _statistics(
    BuildContext context,
    AsyncValue<AdguardHomeStats> stats,
    Duration? period,
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
        _TileRow(
          AdguardHomeStatTile(
            label: 'DNS queries',
            value: formatAdguardHomeCount(stats.queries),
            color: cs.primary,
            series: stats.queriesSeries,
          ),
          AdguardHomeStatTile(
            label: 'Blocked by filters',
            value: formatAdguardHomeCount(stats.blockedByFilters),
            detail: formatAdguardHomePercent(stats.blockedPercent),
            color: cs.error,
            series: stats.blockedSeries,
          ),
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
          AdguardHomeStatTile(
            label: 'Average processing time',
            value: formatAdguardHomeProcessingTime(
              stats.averageProcessingTime,
            ),
            color: cs.primary,
          ),
        ),
        const SizedBox(height: Insets.lg),
        AdguardHomeTopList(
          title: 'Top clients',
          rows: stats.topClients,
          format: formatAdguardHomeCount,
        ),
        const SizedBox(height: Insets.sm),
        AdguardHomeTopList(
          title: 'Top queried domains',
          rows: stats.topQueriedDomains,
          format: formatAdguardHomeCount,
          actionIcon: Icons.block,
          actionLabel: 'Block',
          onAction: (String domain) => _toggleBlocking(domain, block: true),
        ),
        const SizedBox(height: Insets.sm),
        AdguardHomeTopList(
          title: 'Top blocked domains',
          rows: stats.topBlockedDomains,
          format: formatAdguardHomeCount,
          actionIcon: Icons.check_circle_outline,
          actionLabel: 'Unblock',
          onAction: (String domain) => _toggleBlocking(domain, block: false),
        ),
        const SizedBox(height: Insets.sm),
        AdguardHomeTopList(
          title: 'Top upstreams',
          rows: stats.topUpstreams,
          format: formatAdguardHomeCount,
        ),
        if (stats.topUpstreamTimes.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.sm),
          AdguardHomeTopList(
            title: 'Average upstream response time',
            rows: stats.topUpstreamTimes,
            // Seconds, as a fraction.
            format: (num seconds) => '${(seconds * 1000).round()} ms',
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
