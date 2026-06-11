import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/sab_queue.dart';
import 'sabnzbd_api.dart';
import 'sabnzbd_providers.dart';

/// SABnzbd's per-instance UI: a status/speed header with pause-all/resume-all,
/// and the download queue with per-item pause/resume/delete.
class SabnzbdHome extends ConsumerWidget {
  const SabnzbdHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SabQueue> queue = ref.watch(sabQueueProvider(instance));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sabQueueProvider(instance)),
      child: AsyncValueView<SabQueue>(
        value: queue,
        onRetry: () => ref.invalidate(sabQueueProvider(instance)),
        data: (SabQueue q) {
          return Column(
            children: <Widget>[
              _Header(instance: instance, queue: q),
              Expanded(
                child: q.slots.isEmpty
                    ? const EmptyView(
                        icon: Icons.download_done_outlined,
                        title: 'Queue is empty',
                        message: 'Nothing downloading right now.',
                      )
                    : ListView.builder(
                        padding: Insets.pageH,
                        itemCount: q.slots.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _SlotTile(
                          instance: instance,
                          slot: q.slots[index],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.instance, required this.queue});

  final Instance instance;
  final SabQueue queue;

  bool get _isPaused => queue.status.toLowerCase() == 'paused';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.sm,
        Insets.sm,
        Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.speed, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: Insets.xs),
          Text(
            queue.speed.isEmpty ? '0 B/s' : '${queue.speed}B/s',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(width: Insets.md),
          if (queue.timeleft.isNotEmpty && queue.timeleft != '0:00:00')
            Text(
              'ETA ${queue.timeleft}',
              style: theme.textTheme.labelSmall,
            ),
          const Spacer(),
          IconButton(
            tooltip: _isPaused ? 'Resume all' : 'Pause all',
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
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
    );
  }
}

class _SlotTile extends ConsumerWidget {
  const _SlotTile({required this.instance, required this.slot});

  final Instance instance;
  final SabSlot slot;

  bool get _isPaused => slot.status.toLowerCase() == 'paused';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double pct = (double.tryParse(slot.percentage) ?? 0) / 100.0;
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              slot.filename,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.sm),
            LinearProgressIndicator(value: pct.clamp(0, 1)),
            const SizedBox(height: Insets.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${slot.percentage}% • ${slot.status}'
                    '${slot.timeleft.isEmpty ? '' : ' • ${slot.timeleft}'}',
                    style: Theme.of(context).textTheme.labelSmall,
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
