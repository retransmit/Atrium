import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/sab_history.dart';
import 'models/sab_queue.dart';
import 'models/sab_stats.dart';
import 'sabnzbd_api.dart';
import 'sabnzbd_providers.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

/// SABnzbd's per-instance UI: Queue / History / Server tabs.
class SabnzbdHome extends StatelessWidget {
  const SabnzbdHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Queue', icon: Icon(Icons.download_outlined)),
              Tab(text: 'History', icon: Icon(Icons.history)),
              Tab(text: 'Server', icon: Icon(Icons.dns_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _QueueTab(instance: instance),
                _HistoryTab(instance: instance),
                _ServerTab(instance: instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Queue --------------------------------------------------------------------

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SabQueue> queue = ref.watch(sabQueueProvider(instance));
    return M3RefreshIndicator(
      onRefresh: () async => ref.invalidate(sabQueueProvider(instance)),
      child: AsyncValueView<SabQueue>(
        value: queue,
        onRetry: () => ref.invalidate(sabQueueProvider(instance)),
        data: (SabQueue q) {
          if (q.slots.isEmpty) {
            return ListView(
              padding: Insets.page,
              children: <Widget>[
                _QueueSummary(instance: instance, queue: q),
                const SizedBox(height: Insets.xl),
                const EmptyView(
                  icon: Icons.download_done_outlined,
                  title: 'Queue is empty',
                  message: 'Nothing downloading right now.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: Insets.page,
            itemCount: q.slots.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: _QueueSummary(instance: instance, queue: q),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: _SlotCard(instance: instance, slot: q.slots[index - 1]),
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueSummary extends ConsumerWidget {
  const _QueueSummary({required this.instance, required this.queue});

  final Instance instance;
  final SabQueue queue;

  bool get _isPaused => queue.status.toLowerCase() == 'paused';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = _isPaused ? cs.outline : cs.primary;
    final String speed =
        queue.speed.trim().isEmpty ? '0 B/s' : '${queue.speed.trim()}B/s';
    final bool hasEta =
        queue.timeleft.isNotEmpty && queue.timeleft != '0:00:00';

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isPaused ? Icons.pause_rounded : Icons.download_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      speed,
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700, color: accent),
                    ),
                    Text(
                      _isPaused
                          ? 'Paused'
                          : (hasEta ? 'ETA ${queue.timeleft}' : 'Idle'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                ),
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? 'Resume' : 'Pause'),
                onPressed: () async {
                  final SabnzbdApi api =
                      await ref.read(sabnzbdApiProvider(instance).future);
                  if (_isPaused) {
                    await api.resumeAll();
                  } else {
                    await api.pauseAll();
                  }
                  ref.invalidate(sabQueueProvider(instance));
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              _StatPill(
                icon: Icons.speed,
                label:
                    'Limit ${queue.speedlimit.isEmpty ? "100" : queue.speedlimit}%',
                color: cs.tertiary,
              ),
              if (queue.diskspace1.isNotEmpty) ...<Widget>[
                const SizedBox(width: Insets.sm),
                _StatPill(
                  icon: Icons.sd_storage_outlined,
                  label: '${queue.diskspace1} GB free',
                  color: cs.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends ConsumerWidget {
  const _SlotCard({required this.instance, required this.slot});

  final Instance instance;
  final SabSlot slot;

  bool get _isPaused => slot.status.toLowerCase() == 'paused';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double pct = (double.tryParse(slot.percentage) ?? 0) / 100.0;
    final (Color color, IconData icon) = _queueLook(slot.status, cs);

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    slot.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicatorM3E(
                shape: ProgressM3EShape.flat,
                value: pct.clamp(0, 1),
                activeColor: color,
                trackColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                Text(
                  '${slot.percentage}%',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    <String>[
                      slot.status,
                      if (slot.mb.isNotEmpty) _mbToHuman(slot.mb),
                      if (slot.timeleft.isNotEmpty &&
                          slot.timeleft != '0:00:00')
                        slot.timeleft,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  onPressed: () async {
                    final SabnzbdApi api =
                        await ref.read(sabnzbdApiProvider(instance).future);
                    if (_isPaused) {
                      await api.resumeItem(slot.nzoId);
                    } else {
                      await api.pauseItem(slot.nzoId);
                    }
                    ref.invalidate(sabQueueProvider(instance));
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final SabnzbdApi api =
                        await ref.read(sabnzbdApiProvider(instance).future);
                    await api.deleteItem(slot.nzoId);
                    ref.invalidate(sabQueueProvider(instance));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// History ------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SabHistory> history =
        ref.watch(sabHistoryProvider(instance));
    return M3RefreshIndicator(
      onRefresh: () async => ref.invalidate(sabHistoryProvider(instance)),
      child: AsyncValueView<SabHistory>(
        value: history,
        onRetry: () => ref.invalidate(sabHistoryProvider(instance)),
        data: (SabHistory h) {
          if (h.slots.isEmpty) {
            return ListView(
              padding: Insets.page,
              children: const <Widget>[
                SizedBox(height: 80),
                EmptyView(
                  icon: Icons.history,
                  title: 'No history',
                  message: 'Completed and failed downloads will show up here.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: Insets.page,
            itemCount: h.slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) =>
                _HistoryCard(instance: instance, slot: h.slots[index]),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.instance, required this.slot});

  final Instance instance;
  final SabHistorySlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final (Color color, IconData icon) = _historyLook(slot.status, cs);
    final bool failed = slot.status.toLowerCase() == 'failed';

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        slot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        <String>[
                          slot.status,
                          if (slot.size.isNotEmpty) slot.size,
                          if (slot.category.isNotEmpty) slot.category,
                          if (slot.completed > 0) _relTime(slot.completed),
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (failed)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Retry',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      final SabnzbdApi api =
                          await ref.read(sabnzbdApiProvider(instance).future);
                      await api.retryHistoryItem(slot.nzoId);
                      ref.invalidate(sabHistoryProvider(instance));
                      ref.invalidate(sabQueueProvider(instance));
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final SabnzbdApi api =
                        await ref.read(sabnzbdApiProvider(instance).future);
                    await api.deleteHistoryItem(slot.nzoId);
                    ref.invalidate(sabHistoryProvider(instance));
                  },
                ),
              ],
            ),
            if (failed && slot.failMessage.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                slot.failMessage,
                style: theme.textTheme.labelSmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Server -------------------------------------------------------------------

class _ServerTab extends ConsumerWidget {
  const _ServerTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SabServerStats> stats =
        ref.watch(sabServerStatsProvider(instance));
    final SabQueue? queue = ref.watch(sabQueueProvider(instance)).value;
    final String version = ref.watch(sabVersionProvider(instance)).value ?? '';
    final int currentLimit = int.tryParse(queue?.speedlimit ?? '') ?? 100;

    return M3RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sabServerStatsProvider(instance));
        ref.invalidate(sabVersionProvider(instance));
        ref.invalidate(sabQueueProvider(instance));
      },
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          _SectionCard(
            title: 'Usage',
            child: stats.when(
              data: (SabServerStats s) => Row(
                children: <Widget>[
                  Expanded(
                      child:
                          _StatTile(label: 'Today', value: _fmtBytes(s.day))),
                  Expanded(
                      child:
                          _StatTile(label: 'Week', value: _fmtBytes(s.week))),
                  Expanded(
                      child:
                          _StatTile(label: 'Month', value: _fmtBytes(s.month))),
                  Expanded(
                      child:
                          _StatTile(label: 'Total', value: _fmtBytes(s.total))),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(Insets.md),
                child: Center(child: ExpressiveProgressIndicator()),
              ),
              error: (Object e, _) => Text(
                'Could not load stats',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          _SectionCard(
            title: 'Speed limit',
            child: _SpeedLimitControl(
              instance: instance,
              initialPercent: currentLimit.clamp(0, 100),
            ),
          ),
          const SizedBox(height: Insets.md),
          _SectionCard(
            title: 'Server',
            child: Column(
              children: <Widget>[
                _kv('Version', version.isEmpty ? '-' : version),
                if (queue != null && queue.diskspace1.isNotEmpty)
                  _kv(
                    'Disk free',
                    queue.diskspacetotal1.isNotEmpty
                        ? '${queue.diskspace1} / ${queue.diskspacetotal1} GB'
                        : '${queue.diskspace1} GB',
                  ),
                _kv(
                  'Status',
                  queue == null
                      ? '-'
                      : (queue.status.isEmpty ? 'Idle' : queue.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

class _SpeedLimitControl extends ConsumerStatefulWidget {
  const _SpeedLimitControl(
      {required this.instance, required this.initialPercent});

  final Instance instance;
  final int initialPercent;

  @override
  ConsumerState<_SpeedLimitControl> createState() => _SpeedLimitControlState();
}

class _SpeedLimitControlState extends ConsumerState<_SpeedLimitControl> {
  late double _value = widget.initialPercent.toDouble();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _value <= 0 ? 'Unlimited' : '${_value.round()}%',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Slider(
          value: _value.clamp(0, 100),
          max: 100,
          divisions: 20,
          label: _value <= 0 ? 'Off' : '${_value.round()}%',
          onChanged: (double v) => setState(() => _value = v),
          onChangeEnd: (double v) async {
            final SabnzbdApi api =
                await ref.read(sabnzbdApiProvider(widget.instance).future);
            await api.setSpeedLimit(v.round());
            ref.invalidate(sabQueueProvider(widget.instance));
          },
        ),
        Text(
          '0% removes the limit. Percentages apply to the line speed configured '
          'in SABnzbd.',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// Shared -------------------------------------------------------------------

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Insets.sm),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

Widget _kv(String key, String value) => Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 96,
                child: Text(
                  key,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
      },
    );

(Color, IconData) _queueLook(String status, ColorScheme cs) {
  switch (status.toLowerCase()) {
    case 'downloading':
      return (cs.primary, Icons.download_rounded);
    case 'paused':
      return (cs.outline, Icons.pause_rounded);
    case 'queued':
      return (cs.secondary, Icons.schedule_rounded);
    case 'completed':
      return (cs.tertiary, Icons.check_rounded);
    case 'fetching':
    case 'checking':
    case 'verifying':
    case 'repairing':
    case 'extracting':
      return (cs.tertiary, Icons.sync_rounded);
    default:
      return (cs.primary, Icons.download_rounded);
  }
}

(Color, IconData) _historyLook(String status, ColorScheme cs) {
  switch (status.toLowerCase()) {
    case 'completed':
      return (cs.tertiary, Icons.check_circle);
    case 'failed':
      return (cs.error, Icons.error_outline);
    default:
      return (cs.secondary, Icons.sync_rounded);
  }
}

/// SABnzbd returns slot size as an "MB" string (e.g. "1024.0"); show it human.
String _mbToHuman(String mb) {
  final double? v = double.tryParse(mb);
  if (v == null) return '';
  return _fmtBytes((v * 1024 * 1024).round());
}

String _fmtBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// Epoch seconds -> compact relative label.
String _relTime(int epochSeconds) {
  if (epochSeconds <= 0) return '';
  final DateTime then =
      DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final Duration diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${then.year}-${then.month.toString().padLeft(2, '0')}-${then.day.toString().padLeft(2, '0')}';
}
