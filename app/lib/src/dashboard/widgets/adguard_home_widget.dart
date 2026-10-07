import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// AdGuard Home on the board: whether it is protecting, a way to pause it,
/// and four figures.
class DashboardAdguardHomeWidget extends StatelessWidget {
  const DashboardAdguardHomeWidget({
    required this.instances,
    this.now = DateTime.now,
    super.key,
  });

  final List<Instance> instances;

  /// The clock a pause counts down on. Tests hand in their own.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return DashboardWidgetCard(
      kind: DashboardWidgetKind.adguardHome,
      accent: Theme.of(context).colorScheme.primary,
      onTap:
          instances.length == 1 ? () => _open(context, instances.first) : null,
      child: instances.isEmpty
          ? const DashboardIdleRow(
              text: 'No AdGuard Home instances configured',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0;
                    index < instances.length;
                    index++) ...<Widget>[
                  if (index > 0) const Divider(height: Insets.lg),
                  _AdguardHomeBlock(
                    instance: instances[index],
                    showName: instances.length > 1,
                    onTap: instances.length > 1
                        ? () => _open(context, instances[index])
                        : null,
                    now: now,
                  ),
                ],
              ],
            ),
    );
  }

  void _open(BuildContext context, Instance instance) {
    context.go(AtriumRoutes.servicePath(instance.kind.name, instance.id));
  }
}

class _AdguardHomeBlock extends ConsumerStatefulWidget {
  const _AdguardHomeBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
    required this.now,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback? onTap;
  final DateTime Function() now;

  @override
  ConsumerState<_AdguardHomeBlock> createState() => _AdguardHomeBlockState();
}

class _AdguardHomeBlockState extends ConsumerState<_AdguardHomeBlock> {
  bool _busy = false;

  Instance get _instance => widget.instance;

  AdguardHomeActions get _actions =>
      ref.read(adguardHomeActionsProvider(_instance));

  Future<void> _setProtection({required bool enabled, Duration? pause}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _actions.setProtection(enabled: enabled, pause: pause);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(describeAdguardHomeError(error))),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<AdguardHomeStatus> status =
        ref.watch(adguardHomeStatusProvider(_instance));
    final AdguardHomeStats? stats =
        ref.watch(adguardHomeStatsProvider(_instance)).value;
    final AdguardHomeFiltering? filtering =
        ref.watch(adguardHomeFilteringProvider(_instance)).value;

    final Widget body;
    if (status.error is AdguardHomeSignInRefused) {
      body = _Refused(onRetry: _actions.retrySignIn);
    } else {
      body = status.when(
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
        error: (Object error, StackTrace _) =>
            DashboardErrorRow(onRetry: _actions.refresh),
        data: (AdguardHomeStatus status) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StateRow(
              status: status,
              busy: _busy,
              onSet: _setProtection,
              onPauseEnded: () =>
                  ref.invalidate(adguardHomeStatusProvider(_instance)),
              now: widget.now,
            ),
            const SizedBox(height: Insets.md),
            _Figures(stats: stats, filtering: filtering),
          ],
        ),
      );
    }

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
                  _instance.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// The state pill, and beside it the pause menu or Resume.
class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.status,
    required this.busy,
    required this.onSet,
    required this.onPauseEnded,
    required this.now,
  });

  final AdguardHomeStatus status;
  final bool busy;
  final void Function({required bool enabled, Duration? pause}) onSet;
  final VoidCallback onPauseEnded;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeProtection state = status.protection;
    final Color color = switch (state) {
      AdguardHomeProtection.on => cs.primary,
      AdguardHomeProtection.paused => cs.tertiary,
      AdguardHomeProtection.off => cs.error,
    };
    final TextStyle? pillText = theme.textTheme.labelSmall
        ?.copyWith(color: color, fontWeight: FontWeight.bold);
    final DateTime? pausedUntil = status.pausedUntil;

    final Widget pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            switch (state) {
              AdguardHomeProtection.on => Icons.gpp_good_outlined,
              AdguardHomeProtection.paused => Icons.gpp_maybe_outlined,
              AdguardHomeProtection.off => Icons.gpp_bad_outlined,
            },
            size: 14,
            color: color,
          ),
          const SizedBox(width: Insets.xs),
          Text(
            switch (state) {
              AdguardHomeProtection.on => 'PROTECTED',
              AdguardHomeProtection.paused => 'PAUSED',
              AdguardHomeProtection.off => 'OFF',
            },
            style: pillText,
          ),
          if (pausedUntil != null) ...<Widget>[
            const SizedBox(width: Insets.xs),
            AdguardHomeCountdown(
              until: pausedUntil,
              onDone: onPauseEnded,
              now: now,
              style: pillText,
            ),
          ],
        ],
      ),
    );

    return Row(
      children: <Widget>[
        // The pill shrinks rather than push the button off a narrow card at
        // large text.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: pill,
          ),
        ),
        const SizedBox(width: Insets.sm),
        if (state == AdguardHomeProtection.on)
          PopupMenuButton<Duration>(
            tooltip: 'Pause protection',
            icon: const Icon(Icons.pause_circle_outline),
            enabled: !busy,
            useRootNavigator: true,
            // Zero stands for no timer: off until turned back on.
            onSelected: (Duration length) => onSet(
              enabled: false,
              pause: length == Duration.zero ? null : length,
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Duration>>[
              for (final AdguardHomePause pause in adguardHomePauses)
                PopupMenuItem<Duration>(
                  value: pause.length,
                  child: Text(pause.label),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<Duration>(
                value: Duration.zero,
                child: Text('Until turned back on'),
              ),
            ],
          )
        else
          TextButton(
            onPressed: busy ? null : () => onSet(enabled: true),
            child: const Text('Resume'),
          ),
      ],
    );
  }
}

/// Queries, blocked, the blocked share and the rules on the blocklists.
class _Figures extends StatelessWidget {
  const _Figures({required this.stats, required this.filtering});

  final AdguardHomeStats? stats;
  final AdguardHomeFiltering? filtering;

  @override
  Widget build(BuildContext context) {
    final AdguardHomeStats? stats = this.stats;
    final AdguardHomeFiltering? filtering = this.filtering;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Figure(
          label: 'Queries',
          value: stats == null ? '-' : formatAdguardHomeCompact(stats.queries),
        ),
        _Figure(
          label: 'Blocked',
          value: stats == null
              ? '-'
              : formatAdguardHomeCompact(stats.blockedByFilters),
        ),
        _Figure(
          label: 'Blocked %',
          value: stats == null
              ? '-'
              : formatAdguardHomePercent(stats.blockedPercent),
        ),
        _Figure(
          label: 'Rules',
          value: filtering == null
              ? '-'
              : formatAdguardHomeCompact(filtering.rulesOnBlocklists),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// What the block says once the server has refused the sign-in. Nothing is
/// sent again until Try again is tapped.
class _Refused extends StatelessWidget {
  const _Refused({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                'AdGuard Home refused the sign-in. By default it blocks an '
                'address for 15 minutes after five wrong tries.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      ],
    );
  }
}
