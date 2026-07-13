import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

/// qBittorrent states that count as actively downloading.
const Set<String> _activeDlStates = <String>{
  'downloading',
  'forcedDL',
  'metaDL',
  'stalledDL',
  'queuedDL',
  'checkingDL',
  'allocating',
};

/// Live count of active downloads across every qBittorrent + SABnzbd instance.
/// Instances still loading or in error contribute 0, so the dashboard only
/// surfaces the downloads widget once real activity is confirmed.
final activeDownloadCountProvider = Provider.autoDispose<int>((Ref ref) {
  final List<Instance> instances = ref.watch(activeInstancesProvider);
  int count = 0;
  for (final Instance i in instances) {
    if (i.kind == ServiceKind.qbittorrent) {
      final List<QbitTorrent> torrents =
          ref.watch(qbitRawTorrentsProvider(i)).value ?? const <QbitTorrent>[];
      for (final QbitTorrent t in torrents) {
        if (_activeDlStates.contains(t.state)) {
          count++;
        }
      }
    } else if (i.kind == ServiceKind.sabnzbd) {
      count += ref.watch(sabQueueProvider(i)).value?.slots.length ?? 0;
    }
  }
  return count;
});

/// Parses SABnzbd's human speed string ("1.2 M", "512 K") into bytes/s.
int parseSabSpeed(String raw) {
  final RegExpMatch? m =
      RegExp(r'^([\d.]+)\s*([KMGT]?)$').firstMatch(raw.trim());
  if (m == null) {
    return 0;
  }
  final double value = double.tryParse(m.group(1)!) ?? 0;
  const Map<String, int> mult = <String, int>{
    '': 1,
    'K': 1024,
    'M': 1024 * 1024,
    'G': 1024 * 1024 * 1024,
    'T': 1024 * 1024 * 1024 * 1024,
  };
  return (value * mult[m.group(2)]!).round();
}

class _DownloadRow {
  const _DownloadRow({
    required this.name,
    required this.progress,
    required this.instance,
  });

  final String name;
  final double progress;
  final Instance instance;
}

/// Combined qBittorrent + SABnzbd activity: total speed, count, top items.
class DashboardDownloadsWidget extends ConsumerWidget {
  const DashboardDownloadsWidget({
    required this.qbitInstances,
    required this.sabInstances,
    super.key,
  });

  final List<Instance> qbitInstances;
  final List<Instance> sabInstances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final List<_DownloadRow> rows = <_DownloadRow>[];
    int totalSpeed = 0;
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in qbitInstances) {
      final AsyncValue<List<QbitTorrent>> torrents =
          ref.watch(qbitRawTorrentsProvider(i));
      anyLoading |= torrents.isLoading && !torrents.hasValue;
      anyError |= torrents.hasError;
      for (final QbitTorrent t in torrents.value ?? const <QbitTorrent>[]) {
        if (_activeDlStates.contains(t.state)) {
          rows.add(_DownloadRow(
            name: t.name,
            progress: t.progress.clamp(0, 1).toDouble(),
            instance: i,
          ));
        }
      }
      totalSpeed += ref.watch(qbitTransferProvider(i)).value?.dlSpeed ?? 0;
    }
    for (final Instance i in sabInstances) {
      final AsyncValue<SabQueue> queue = ref.watch(sabQueueProvider(i));
      anyLoading |= queue.isLoading && !queue.hasValue;
      anyError |= queue.hasError;
      final SabQueue? q = queue.value;
      if (q != null) {
        totalSpeed += parseSabSpeed(q.speed);
        for (final SabSlot s in q.slots) {
          rows.add(_DownloadRow(
            name: s.filename,
            progress: ((double.tryParse(s.percentage) ?? 0) / 100)
                .clamp(0, 1)
                .toDouble(),
            instance: i,
          ));
        }
      }
    }

    rows.sort(
        (_DownloadRow a, _DownloadRow b) => b.progress.compareTo(a.progress));
    final List<_DownloadRow> top = rows.take(3).toList();

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
      body = const DashboardIdleRow(text: 'Nothing downloading');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final _DownloadRow row in top) _ItemRow(row: row),
          if (rows.length > top.length)
            DashboardIdleRow(text: '+${rows.length - top.length} more'),
        ],
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.downloads,
      accent: cs.primary,
      trailing: totalSpeed > 0
          ? DashboardPill(
              icon: Icons.arrow_downward_rounded,
              label: '${fmtBytes(totalSpeed)}/s',
              color: cs.primary,
            )
          : null,
      child: body,
    );
  }

  void _refresh(WidgetRef ref) {
    for (final Instance i in qbitInstances) {
      ref.invalidate(qbitRawTorrentsProvider(i));
      ref.invalidate(qbitTransferProvider(i));
    }
    for (final Instance i in sabInstances) {
      ref.invalidate(sabQueueProvider(i));
    }
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.row});

  final _DownloadRow row;

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
                    row.name,
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
              child: LinearProgressIndicatorM3E(
                size: LinearProgressM3ESize.s,
                shape: ProgressM3EShape.flat,
                value: row.progress,
                activeColor: cs.primary,
                trackColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
