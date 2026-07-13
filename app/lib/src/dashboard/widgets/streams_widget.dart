import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_emby/service_emby.dart' as emby;
import 'package:service_jellyfin/service_jellyfin.dart' as jf;
import 'package:service_tautulli/service_tautulli.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class _StreamRow {
  const _StreamRow({
    required this.user,
    required this.title,
    required this.progress,
    required this.instance,
  });

  final String user;
  final String title;
  final double progress;
  final Instance instance;
}

/// Active sessions across Tautulli, Jellyfin and Emby.
class DashboardStreamsWidget extends ConsumerWidget {
  const DashboardStreamsWidget({
    required this.tautulliInstances,
    required this.jellyfinInstances,
    required this.embyInstances,
    super.key,
  });

  final List<Instance> tautulliInstances;
  final List<Instance> jellyfinInstances;
  final List<Instance> embyInstances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<_StreamRow> rows = <_StreamRow>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in tautulliInstances) {
      final AsyncValue<TautulliActivity> activity =
          ref.watch(tautulliActivityProvider(i));
      anyLoading |= activity.isLoading && !activity.hasValue;
      anyError |= activity.hasError;
      for (final TautulliSession s
          in activity.valueOrNull?.sessions ?? const <TautulliSession>[]) {
        rows.add(_StreamRow(
          user: s.friendlyName,
          title: s.fullTitle,
          progress: (s.progressPercent / 100).clamp(0, 1).toDouble(),
          instance: i,
        ));
      }
    }
    for (final Instance i in jellyfinInstances) {
      final AsyncValue<List<jf.ActiveSession>> sessions =
          ref.watch(jf.jellyfinSessionsProvider(i));
      anyLoading |= sessions.isLoading && !sessions.hasValue;
      anyError |= sessions.hasError;
      for (final jf.ActiveSession s
          in sessions.valueOrNull ?? const <jf.ActiveSession>[]) {
        rows.add(_StreamRow(
          user: s.user,
          title: s.episodeName == null
              ? s.showTitle
              : '${s.showTitle} - ${s.episodeName}',
          progress: (s.progressPercent / 100).clamp(0, 1).toDouble(),
          instance: i,
        ));
      }
    }
    for (final Instance i in embyInstances) {
      final AsyncValue<List<emby.ActiveSession>> sessions =
          ref.watch(emby.embySessionsProvider(i));
      anyLoading |= sessions.isLoading && !sessions.hasValue;
      anyError |= sessions.hasError;
      for (final emby.ActiveSession s
          in sessions.valueOrNull ?? const <emby.ActiveSession>[]) {
        rows.add(_StreamRow(
          user: s.user,
          title: s.episodeName == null
              ? s.showTitle
              : '${s.showTitle} - ${s.episodeName}',
          progress: (s.progressPercent / 100).clamp(0, 1).toDouble(),
          instance: i,
        ));
      }
    }

    final List<_StreamRow> top = rows.take(3).toList();

    Widget body;
    if (rows.isEmpty && anyLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.sm),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (rows.isEmpty && anyError) {
      body = DashboardErrorRow(onRetry: () => _refresh(ref));
    } else if (rows.isEmpty) {
      body = const DashboardIdleRow(text: 'No one is streaming');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final _StreamRow row in top) _SessionRow(row: row),
          if (rows.length > top.length)
            DashboardIdleRow(text: '+${rows.length - top.length} more'),
        ],
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.streams,
      accent: cs.tertiary,
      trailing: rows.isNotEmpty
          ? DashboardPill(
              icon: Icons.play_arrow_rounded,
              label: '${rows.length} streaming',
              color: cs.tertiary,
            )
          : null,
      child: body,
    );
  }

  void _refresh(WidgetRef ref) {
    for (final Instance i in tautulliInstances) {
      ref.invalidate(tautulliActivityProvider(i));
    }
    for (final Instance i in jellyfinInstances) {
      ref.invalidate(jf.jellyfinSessionsProvider(i));
    }
    for (final Instance i in embyInstances) {
      ref.invalidate(emby.embySessionsProvider(i));
    }
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.row});

  final _StreamRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go(
        AtriumRoutes.servicePath(row.instance.kind.name, row.instance.id),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${row.user} - ${row.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  '${(row.progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: row.progress,
                minHeight: 5,
                color: cs.tertiary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
