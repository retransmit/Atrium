import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// AdGuard Home on the board: whether it is protecting, a way to pause it,
/// how much it answered and blocked, and when.
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
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<AdguardHomeStatus> status =
        ref.watch(adguardHomeStatusProvider(_instance));
    final AdguardHomeStats? stats =
        ref.watch(adguardHomeStatsProvider(_instance)).value;
    final AdguardHomeFiltering? filtering =
        ref.watch(adguardHomeFilteringProvider(_instance)).value;
    final Duration? period =
        ref.watch(adguardHomeStatsPeriodProvider(_instance)).value;

    final Widget body;
    if (status.error is AdguardHomeSignInRefused) {
      body = _Refused(
        onRetry: _actions.retrySignIn,
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
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
            _Summary(stats: stats),
            // A server that keeps no statistics, or has none yet, sends no
            // series to draw.
            if (stats != null && stats.queriesSeries.length > 1) ...<Widget>[
              const SizedBox(height: Insets.sm),
              SizedBox(
                height: _chartHeight,
                child: AdguardHomeSeriesChart(
                  series: stats.queriesSeries,
                  color: cs.primary,
                  over: stats.blockedSeries,
                  overColor: cs.error,
                ),
              ),
            ],
            if (period != null || filtering != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              _Caption(period: period, filtering: filtering),
            ],
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
                    color: cs.onSurfaceVariant,
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

/// How tall the chart of the period is drawn.
const double _chartHeight = 48;

/// The compact tonal look of the one button the widget has.
final ButtonStyle _actionStyle = FilledButton.styleFrom(
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(
    horizontal: Insets.md,
    vertical: Insets.xs,
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

/// The state pill, and beside it Pause or Resume.
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
          _PauseButton(busy: busy, onSet: onSet)
        else
          FilledButton.tonalIcon(
            style: _actionStyle,
            onPressed: busy ? null : () => onSet(enabled: true),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Resume'),
          ),
      ],
    );
  }
}

/// Pause, which opens the lengths a pause can have.
class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.busy, required this.onSet});

  final bool busy;
  final void Function({required bool enabled, Duration? pause}) onSet;

  Future<void> _choose(BuildContext context) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay = Navigator.of(context, rootNavigator: true)
        .overlay!
        .context
        .findRenderObject()! as RenderBox;
    final Duration? length = await showMenu<Duration>(
      context: context,
      useRootNavigator: true,
      // Under the button.
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(
            button.size.bottomLeft(Offset.zero),
            ancestor: overlay,
          ),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<Duration>>[
        for (final AdguardHomePause pause in adguardHomePauses)
          PopupMenuItem<Duration>(
            value: pause.length,
            child: Text(pause.label),
          ),
        const PopupMenuDivider(),
        // Zero stands for no timer: off until turned back on.
        const PopupMenuItem<Duration>(
          value: Duration.zero,
          child: Text('Until turned back on'),
        ),
      ],
    );
    if (length == null) return;
    onSet(enabled: false, pause: length == Duration.zero ? null : length);
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: _actionStyle,
      onPressed: busy ? null : () => _choose(context),
      icon: const Icon(Icons.pause_rounded, size: 16),
      label: const Text('Pause'),
    );
  }
}

/// The queries and how many of them were blocked, with that share as a
/// ring. The two colours are the ones their lines have in the chart.
class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final AdguardHomeStats? stats;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AdguardHomeStats? stats = this.stats;
    return Row(
      children: <Widget>[
        Expanded(
          child: _Figure(
            label: 'Queries',
            value:
                stats == null ? '-' : formatAdguardHomeCompact(stats.queries),
            color: cs.primary,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: _Figure(
            label: 'Blocked',
            value: stats == null
                ? '-'
                : formatAdguardHomeCompact(stats.blockedByFilters),
            color: cs.error,
          ),
        ),
        const SizedBox(width: Insets.sm),
        _ShareRing(percent: stats?.blockedPercent, color: cs.error),
      ],
    );
  }
}

/// A figure over its name, the name marked with a dot of its colour.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle? valueStyle =
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final TextStyle? labelStyle = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // One line of each at the current text size.
    final double valueHeight =
        (scaler.scale(valueStyle?.fontSize ?? 22) * (valueStyle?.height ?? 1.27))
            .ceilToDouble();
    final double labelHeight =
        (scaler.scale(labelStyle?.fontSize ?? 12) * (labelStyle?.height ?? 1.33))
            .ceilToDouble();
    final double dot = scaler.scale(8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // What is too wide for its share of the card shrinks, inside a box
        // that stays one line tall, so the two figures stay level.
        SizedBox(
          height: valueHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: valueStyle,
            ),
          ),
        ),
        SizedBox(
          height: labelHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: dot,
                  height: dot,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label, maxLines: 1, softWrap: false, style: labelStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The share of the queries that were blocked, as a ring with the figure
/// inside it.
class _ShareRing extends StatelessWidget {
  const _ShareRing({required this.percent, required this.color});

  /// From 0 to 100. Null while the statistics are not there.
  final double? percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? percent = this.percent;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: ((percent ?? 0) / 100).clamp(0.0, 1.0),
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? _) {
              return CircularProgressIndicatorM3E(
                value: value,
                shape: ProgressM3EShape.flat,
                activeColor: color,
                trackColor: theme.colorScheme.surfaceContainerHighest,
              );
            },
          ),
          // Kept inside the ring whatever the text size.
          SizedBox(
            width: 32,
            height: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                percent == null
                    ? '-'
                    : formatAdguardHomeCompactPercent(percent),
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The period the figures cover, and how many rules do the blocking.
class _Caption extends StatelessWidget {
  const _Caption({required this.period, required this.filtering});

  final Duration? period;
  final AdguardHomeFiltering? filtering;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final Duration? period = this.period;
    final int? rules = filtering?.rulesOnBlocklists;
    // One line, the two at either end. Where that is too narrow, as at
    // large text, the second goes under the first.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: Insets.md,
        children: <Widget>[
          if (period != null) Text(adguardHomePeriodLabel(period), style: style),
          if (rules != null)
            Text(
              '${formatAdguardHomeCompact(rules)} '
              '${rules == 1 ? 'rule' : 'rules'}',
              style: style,
            ),
        ],
      ),
    );
  }
}

/// What the block says once the server has refused the sign-in. Nothing is
/// sent again until Try again is tapped.
class _Refused extends StatelessWidget {
  const _Refused({
    required this.onRetry,
    required this.hasCredentials,
    required this.refusals,
  });

  final VoidCallback onRetry;

  /// Whether the instance has a username or password at all. Without them
  /// the server refused nothing it counts: it only wants a sign-in.
  final bool hasCredentials;

  /// How many tries in a row the server has refused. Said from the second
  /// on, so a try that is refused again does not look like no try at all.
  final int refusals;

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
                hasCredentials
                    ? 'AdGuard Home refused the sign-in. By default it '
                        'blocks an address for 15 minutes after five wrong '
                        'tries.'
                    : 'AdGuard Home asks for a sign-in, and this instance '
                        'has no username or password.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        if (hasCredentials && refusals > 1)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              'Refused $refusals times in a row from this app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      ],
    );
  }
}
