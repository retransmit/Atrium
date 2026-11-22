import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:service_technitium/service_technitium.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// Dashboard widget for Technitium DNS Server.
class DashboardTechnitiumWidget extends StatelessWidget {
  const DashboardTechnitiumWidget({
    required this.instances,
    this.now = DateTime.now,
    super.key,
  });

  final List<Instance> instances;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return DashboardWidgetCard(
      kind: DashboardWidgetKind.technitium,
      accent: Theme.of(context).colorScheme.primary,
      onTap:
          instances.length == 1 ? () => _open(context, instances.first) : null,
      child: instances.isEmpty
          ? const DashboardIdleRow(
              text: 'No Technitium DNS instances configured',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < instances.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: Insets.lg),
                  _TechnitiumBlock(
                    instance: instances[i],
                    showName: instances.length > 1,
                    onTap: instances.length > 1
                        ? () => _open(context, instances[i])
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

class _TechnitiumBlock extends ConsumerStatefulWidget {
  const _TechnitiumBlock({
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
  ConsumerState<_TechnitiumBlock> createState() => _TechnitiumBlockState();
}

class _TechnitiumBlockState extends ConsumerState<_TechnitiumBlock> {
  bool _busy = false;

  Instance get _instance => widget.instance;
  TechnitiumActions get _actions =>
      ref.read(technitiumActionsProvider(_instance));

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
            SnackBar(content: Text(describeTechnitiumError(error))),
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
    final AsyncValue<TechnitiumStatus> status =
        ref.watch(technitiumStatusProvider(_instance));
    final TechnitiumStats? stats =
        ref.watch(technitiumStatsProvider(_instance)).value;

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
            status.when(
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
              error: (Object _, StackTrace __) =>
                  DashboardErrorRow(onRetry: _actions.refresh),
              data: (TechnitiumStatus status) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StateRow(
                    status: status,
                    busy: _busy,
                    onSet: _setProtection,
                    onPauseEnded: () =>
                        ref.invalidate(technitiumStatusProvider(_instance)),
                    now: widget.now,
                  ),
                  const SizedBox(height: Insets.md),
                  _Summary(stats: stats),
                  if (stats != null &&
                      stats.queriesSeries.length > 1) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    SizedBox(
                      height: 48,
                      child: TechnitiumSeriesChart(
                        series: stats.queriesSeries,
                        color: cs.primary,
                        over: stats.blockedSeries,
                        overColor: cs.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Last 24 hours',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.status,
    required this.busy,
    required this.onSet,
    required this.onPauseEnded,
    required this.now,
  });

  final TechnitiumStatus status;
  final bool busy;
  final void Function({required bool enabled, Duration? pause}) onSet;
  final VoidCallback onPauseEnded;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TechnitiumProtection state = status.protection;
    final Color color = switch (state) {
      TechnitiumProtection.on => cs.primary,
      TechnitiumProtection.paused => cs.tertiary,
      TechnitiumProtection.off => cs.error,
    };
    final TextStyle? pillText = theme.textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.bold,
    );
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
              TechnitiumProtection.on => Icons.shield_rounded,
              TechnitiumProtection.paused => Icons.pause_circle_outline_rounded,
              TechnitiumProtection.off => Icons.shield_outlined,
            },
            size: 14,
            color: color,
          ),
          const SizedBox(width: Insets.xs),
          Text(
            switch (state) {
              TechnitiumProtection.on => 'PROTECTED',
              TechnitiumProtection.paused => 'PAUSED',
              TechnitiumProtection.off => 'OFF',
            },
            style: pillText,
          ),
          if (pausedUntil != null &&
              state == TechnitiumProtection.paused) ...<Widget>[
            const SizedBox(width: Insets.xs),
            TechnitiumCountdown(
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
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: pill,
          ),
        ),
        const SizedBox(width: Insets.sm),
        if (state == TechnitiumProtection.on)
          _PauseButton(busy: busy, onSet: onSet)
        else
          FilledButton.tonalIcon(
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
            onPressed: busy ? null : () => onSet(enabled: true),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Resume'),
          ),
      ],
    );
  }
}

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
        for (final TechnitiumPause pause in technitiumPauses)
          PopupMenuItem<Duration>(
            value: pause.duration,
            child: Text(pause.label),
          ),
        const PopupMenuDivider(),
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
      onPressed: busy ? null : () => _choose(context),
      icon: const Icon(Icons.pause_rounded, size: 16),
      label: const Text('Pause'),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final TechnitiumStats? stats;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TechnitiumStats? stats = this.stats;
    return Row(
      children: <Widget>[
        Expanded(
          child: _Figure(
            label: 'Queries',
            value: stats == null
                ? '-'
                : formatTechnitiumCompact(stats.totalQueries),
            color: cs.primary,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: _Figure(
            label: 'Blocked',
            value: stats == null
                ? '-'
                : formatTechnitiumCompact(stats.blockedQueries),
            color: cs.error,
          ),
        ),
        const SizedBox(width: Insets.sm),
        _ShareRing(percent: stats?.blockedPercent, color: cs.error),
      ],
    );
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShareRing extends StatelessWidget {
  const _ShareRing({required this.percent, required this.color});

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
          SizedBox(
            width: 32,
            height: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                percent == null ? '-' : formatTechnitiumPercent(percent),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
