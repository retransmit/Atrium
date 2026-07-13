import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:service_glances/service_glances.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class _DiskRow {
  const _DiskRow({
    required this.label,
    required this.fraction,
    required this.detail,
  });

  final String label;
  final double fraction; // used fraction 0..1
  final String detail;
}

String _fmtBytes(num bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[u]}';
}

/// Free space from whatever reports it: SABnzbd's download disk and Glances
/// filesystems. Not tappable.
class DashboardDiskWidget extends ConsumerWidget {
  const DashboardDiskWidget({
    required this.sabInstances,
    required this.glancesInstances,
    super.key,
  });

  final List<Instance> sabInstances;
  final List<Instance> glancesInstances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<_DiskRow> rows = <_DiskRow>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in sabInstances) {
      final AsyncValue<SabQueue> queue = ref.watch(sabQueueProvider(i));
      anyLoading |= queue.isLoading && !queue.hasValue;
      anyError |= queue.hasError;
      final SabQueue? q = queue.value;
      final double free = double.tryParse(q?.diskspace1 ?? '') ?? 0;
      final double total = double.tryParse(q?.diskspacetotal1 ?? '') ?? 0;
      if (total > 0) {
        rows.add(_DiskRow(
          label: i.name,
          fraction: ((total - free) / total).clamp(0, 1).toDouble(),
          detail:
              '${free.toStringAsFixed(0)} GB free of ${total.toStringAsFixed(0)} GB',
        ));
      }
    }
    for (final Instance i in glancesInstances) {
      final AsyncValue<GlancesStats> stats = ref.watch(glancesStatsProvider(i));
      anyLoading |= stats.isLoading && !stats.hasValue;
      anyError |= stats.hasError;
      for (final GlancesDisk d
          in stats.value?.disks ?? const <GlancesDisk>[]) {
        if (d.total > 0) {
          rows.add(_DiskRow(
            label: '${i.name} ${d.path}',
            fraction: (d.percentage / 100).clamp(0, 1).toDouble(),
            detail:
                '${_fmtBytes(d.total - d.used)} free of ${_fmtBytes(d.total)}',
          ));
        }
      }
    }

    final List<_DiskRow> top = rows.take(5).toList();

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
      body = DashboardErrorRow(
        onRetry: () {
          for (final Instance i in sabInstances) {
            ref.invalidate(sabQueueProvider(i));
          }
          for (final Instance i in glancesInstances) {
            ref.invalidate(glancesStatsProvider(i));
          }
        },
      );
    } else if (rows.isEmpty) {
      body = const DashboardIdleRow(text: 'No disk info available');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final _DiskRow row in top) _BarRow(row: row),
          if (rows.length > top.length)
            DashboardIdleRow(text: '+${rows.length - top.length} more'),
        ],
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.diskSpace,
      accent: cs.primary,
      child: body,
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row});

  final _DiskRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color barColor = row.fraction > 0.9 ? cs.error : cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                row.detail,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: row.fraction,
              minHeight: 5,
              color: barColor,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
