import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'deluge_add_sheet.dart';
import 'deluge_client.dart';
import 'deluge_format.dart';
import 'deluge_providers.dart';
import 'deluge_speed_dialog.dart';
import 'deluge_torrent_detail_screen.dart';
import 'models/deluge_filter_tree.dart';
import 'models/deluge_session_status.dart';
import 'models/deluge_torrent.dart';

/// Deluge's per-instance UI: the torrent list, plus session controls.
///
/// There are no tabs here. Deluge keeps finished torrents in the same list as
/// running ones (they simply become `Seeding`), so unlike the Usenet clients
/// there is no separate history to show.
class DelugeHome extends ConsumerStatefulWidget {
  const DelugeHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<DelugeHome> createState() => _DelugeHomeState();
}

class _DelugeHomeState extends ConsumerState<DelugeHome> {
  void _refresh() {
    // The raw provider owns the fetch; invalidating only the derived filtered
    // one would re-filter stale data without going back to the server.
    ref.invalidate(delugeRawTorrentsProvider(widget.instance));
    ref.invalidate(delugeSessionStatusProvider(widget.instance));
    ref.invalidate(delugeSessionPausedProvider(widget.instance));
    ref.invalidate(delugeFilterTreeProvider(widget.instance));
    ref.invalidate(delugeSpeedLimitsProvider(widget.instance));
    ref.invalidate(delugeFreeSpaceProvider(widget.instance));
  }

  /// Runs a client action, surfaces failures, and refreshes either way.
  Future<void> _run(Future<void> Function(DelugeClient client) action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final DelugeClient client =
          await ref.read(delugeClientProvider(widget.instance).future);
      await action(client);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) _refresh();
    }
  }

  Future<void> _confirmRemove(DelugeTorrent torrent) async {
    bool withData = false;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
          title: const Text('Remove torrent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(torrent.name),
              const SizedBox(height: Insets.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: withData,
                onChanged: (bool? v) =>
                    setLocal(() => withData = v ?? false),
                title: const Text('Also delete downloaded files'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
    if (go != true) return;
    await _run(
      (DelugeClient c) =>
          c.remove(<String>[torrent.id], removeData: withData),
    );
  }

  void _openDetail(DelugeTorrent torrent) {
    // Deliberately the nearest Navigator, not the root one: the detail screen
    // belongs inside the instance's shell.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DelugeTorrentDetailScreen(
          instance: widget.instance,
          torrentId: torrent.id,
          initialName: torrent.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DelugeTorrent>> torrents =
        ref.watch(delugeTorrentsProvider(widget.instance));
    return AsyncValueView<List<DelugeTorrent>>(
      value: torrents,
      onRetry: _refresh,
      data: (List<DelugeTorrent> list) {
        return EasyRefresh(
          header: const ClassicHeader(),
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: Insets.page,
            children: <Widget>[
              _SessionSummary(
                instance: widget.instance,
                onAdd: () => showDelugeAddSheet(context, widget.instance),
                onTogglePause: (bool paused) =>
                    _run((DelugeClient c) => c.setSessionPaused(paused: paused)),
                onSetDownLimit: (double kib) =>
                    _run((DelugeClient c) => c.setSpeedLimits(downloadKib: kib)),
                onSetUpLimit: (double kib) =>
                    _run((DelugeClient c) => c.setSpeedLimits(uploadKib: kib)),
              ),
              const SizedBox(height: Insets.md),
              _FilterBar(instance: widget.instance),
              const SizedBox(height: Insets.sm),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: Insets.xl),
                  child: EmptyView(
                    icon: Icons.download_done_outlined,
                    title: 'No torrents',
                    message: 'Nothing matches this filter.',
                  ),
                )
              else
                for (final DelugeTorrent t in list)
                  _TorrentRow(
                    torrent: t,
                    onTap: () => _openDetail(t),
                    onPauseResume: () => _run(
                      (DelugeClient c) => t.isPaused
                          ? c.resume(<String>[t.id])
                          : c.pause(<String>[t.id]),
                    ),
                    onRemove: () => _confirmRemove(t),
                    onRecheck: () =>
                        _run((DelugeClient c) => c.recheck(<String>[t.id])),
                    onReannounce: () =>
                        _run((DelugeClient c) => c.reannounce(<String>[t.id])),
                    onQueueTop: () =>
                        _run((DelugeClient c) => c.queueTop(<String>[t.id])),
                    onQueueUp: () =>
                        _run((DelugeClient c) => c.queueUp(<String>[t.id])),
                    onQueueDown: () =>
                        _run((DelugeClient c) => c.queueDown(<String>[t.id])),
                    onQueueBottom: () =>
                        _run((DelugeClient c) => c.queueBottom(<String>[t.id])),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Session speeds, free space, and the global controls.
class _SessionSummary extends ConsumerWidget {
  const _SessionSummary({
    required this.instance,
    required this.onAdd,
    required this.onTogglePause,
    required this.onSetDownLimit,
    required this.onSetUpLimit,
  });

  final Instance instance;
  final VoidCallback onAdd;
  final void Function(bool paused) onTogglePause;
  final void Function(double kib) onSetDownLimit;
  final void Function(double kib) onSetUpLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DelugeSessionStatus status = ref
            .watch(delugeSessionStatusProvider(instance))
            .value ??
        const DelugeSessionStatus();
    final bool paused =
        ref.watch(delugeSessionPausedProvider(instance)).value ?? false;
    final DelugeSpeedLimits limits =
        ref.watch(delugeSpeedLimitsProvider(instance)).value ??
            const DelugeSpeedLimits();
    final int? freeSpace = ref.watch(delugeFreeSpaceProvider(instance)).value;

    final TextTheme text = Theme.of(context).textTheme;
    final List<String> meta = <String>[
      '${status.dhtNodes} DHT nodes',
      '${status.numPeers} ${status.numPeers == 1 ? 'peer' : 'peers'}',
      if (freeSpace != null) '${delugeFmtBytes(freeSpace)} free',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The two live rates are the point of this card, so they get the
            // only large type on the screen. Everything else stays quiet.
            Row(
              children: <Widget>[
                Expanded(
                  child: _SpeedReadout(
                    icon: Icons.south,
                    bytesPerSec: status.downloadRate,
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: _SpeedReadout(
                    icon: Icons.north,
                    bytesPerSec: status.uploadRate,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              meta.join(' - '),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Divider(height: Insets.xl),
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: paused ? 'Resume all' : 'Pause all',
                  onPressed: () => onTogglePause(!paused),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                ),
                const SizedBox(width: Insets.xs),
                // Limits read as status first and controls second, so they are
                // quiet text rather than buttons competing with Add.
                Expanded(
                  child: _LimitButton(
                    icon: Icons.south,
                    label: delugeFmtLimitKib(limits.maxDownloadKib),
                    onPressed: () async {
                      final double? kib = await showDelugeSpeedDialog(
                        context,
                        title: 'Download limit',
                        current: limits.maxDownloadKib,
                      );
                      if (kib != null) onSetDownLimit(kib);
                    },
                  ),
                ),
                Expanded(
                  child: _LimitButton(
                    icon: Icons.north,
                    label: delugeFmtLimitKib(limits.maxUploadKib),
                    onPressed: () async {
                      final double? kib = await showDelugeSpeedDialog(
                        context,
                        title: 'Upload limit',
                        current: limits.maxUploadKib,
                      );
                      if (kib != null) onSetUpLimit(kib);
                    },
                  ),
                ),
                const SizedBox(width: Insets.xs),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One live rate, typeset as a big figure with a small unit beside it.
class _SpeedReadout extends StatelessWidget {
  const _SpeedReadout({
    required this.icon,
    required this.bytesPerSec,
    required this.color,
  });

  final IconData icon;
  final num bytesPerSec;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final (String value, String unit) = delugeSplitRate(bytesPerSec);
    final bool idle = bytesPerSec <= 0;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: idle ? scheme.outline : color),
        const SizedBox(width: Insets.xs),
        Text(
          value,
          style: text.headlineSmall?.copyWith(
            color: idle ? scheme.onSurfaceVariant : scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: Insets.xxs),
        Padding(
          padding: const EdgeInsets.only(top: Insets.xs),
          child: Text(
            unit,
            style: text.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A bandwidth cap shown as its current value; tapping changes it.
class _LimitButton extends StatelessWidget {
  const _LimitButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// State / label / tracker filter chips, built from whatever buckets the daemon
/// actually offers.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DelugeFilterTree tree =
        ref.watch(delugeFilterTreeProvider(instance)).value ??
            const DelugeFilterTree();
    final DelugeFilter filter = ref.watch(delugeFilterProvider(instance));
    if (tree.states.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ChipRow(
          buckets: tree.states,
          selected: filter.state,
          onSelected: (String v) => ref
              .read(delugeFilterProvider(instance).notifier)
              .update((DelugeFilter f) => f.copyWith(state: v)),
        ),
        // Only rendered when the daemon has the Label plugin; otherwise there
        // is nothing to filter on and the row would always be empty.
        if (tree.hasLabels) ...<Widget>[
          const SizedBox(height: Insets.xs),
          _ChipRow(
            buckets: tree.labels,
            selected: filter.label,
            onSelected: (String v) => ref
                .read(delugeFilterProvider(instance).notifier)
                .update((DelugeFilter f) => f.copyWith(label: v)),
          ),
        ],
        const SizedBox(height: Insets.xs),
        Row(
          children: <Widget>[
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: Insets.xs),
            Expanded(child: _SortMenu(instance: instance)),
          ],
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.buckets,
    required this.selected,
    required this.onSelected,
  });

  final List<DelugeFilterBucket> buckets;
  final String selected;
  final void Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final DelugeFilterBucket b in buckets)
            Padding(
              padding: const EdgeInsets.only(right: Insets.xs),
              child: FilterChip(
                label: Text(
                  b.name.isEmpty ? 'None' : '${b.name} (${b.count})',
                ),
                selected: b.name == selected,
                onSelected: (_) => onSelected(b.name),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DelugeSortField field = ref.watch(delugeSortFieldProvider(instance));
    final bool descending = ref.watch(delugeSortDescendingProvider(instance));
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButton<DelugeSortField>(
            isExpanded: true,
            value: field,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<DelugeSortField>>[
              for (final DelugeSortField f in DelugeSortField.values)
                DropdownMenuItem<DelugeSortField>(
                  value: f,
                  child: Text(f.displayName),
                ),
            ],
            onChanged: (DelugeSortField? f) {
              if (f != null) {
                ref.read(delugeSortFieldProvider(instance).notifier).state = f;
              }
            },
          ),
        ),
        IconButton(
          tooltip: descending ? 'Descending' : 'Ascending',
          icon: Icon(descending ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: () => ref
              .read(delugeSortDescendingProvider(instance).notifier)
              .state = !descending,
        ),
      ],
    );
  }
}

class _TorrentRow extends StatelessWidget {
  const _TorrentRow({
    required this.torrent,
    required this.onTap,
    required this.onPauseResume,
    required this.onRemove,
    required this.onRecheck,
    required this.onReannounce,
    required this.onQueueTop,
    required this.onQueueUp,
    required this.onQueueDown,
    required this.onQueueBottom,
  });

  final DelugeTorrent torrent;
  final VoidCallback onTap;
  final VoidCallback onPauseResume;
  final VoidCallback onRemove;
  final VoidCallback onRecheck;
  final VoidCallback onReannounce;
  final VoidCallback onQueueTop;
  final VoidCallback onQueueUp;
  final VoidCallback onQueueDown;
  final VoidCallback onQueueBottom;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color stateColor = delugeStateColor(scheme, torrent.state);
    final bool done = torrent.progress >= 100;
    final bool moving = torrent.downloadRate > 0 || torrent.uploadRate > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    delugeStateIcon(torrent.state),
                    size: 18,
                    color: stateColor,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      torrent.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _RowMenu(
                    isPaused: torrent.isPaused,
                    onPauseResume: onPauseResume,
                    onRemove: onRemove,
                    onRecheck: onRecheck,
                    onReannounce: onReannounce,
                    onQueueTop: onQueueTop,
                    onQueueUp: onQueueUp,
                    onQueueDown: onQueueDown,
                    onQueueBottom: onQueueBottom,
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              // Once a torrent is finished its progress bar is pinned at 100%
              // and says nothing. Give the bar a second job: show share ratio
              // toward 1.0, which is the one number still moving.
              LinearProgressIndicatorM3E(
                value: done
                    ? torrent.ratio.clamp(0, 1).toDouble()
                    : torrent.progressFraction,
                // The expressive wave reads as "moving right now", so it is
                // spent only on torrents actually shifting bytes. A torrent
                // parked at 100% stays flat.
                shape: moving ? ProgressM3EShape.wavy : ProgressM3EShape.flat,
                size: LinearProgressM3ESize.s,
                activeColor: stateColor,
                trackColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(height: Insets.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: done
                                ? 'Ratio ${torrent.ratio.toStringAsFixed(2)}'
                                : '${torrent.progress.toStringAsFixed(0)}%',
                            style: text.titleSmall?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: done
                                ? '  ${delugeFmtBytes(torrent.totalUploaded)} '
                                    'shared of ${delugeFmtBytes(
                                    torrent.totalWanted,
                                  )}'
                                : '  ${delugeFmtBytes(torrent.totalDone)} of '
                                    '${delugeFmtBytes(torrent.totalWanted)}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    torrent.state,
                    style: text.labelMedium?.copyWith(color: stateColor),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xxs),
              DefaultTextStyle.merge(
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.south, size: 12, color: scheme.onSurfaceVariant),
                    Text(delugeFmtRate(torrent.downloadRate)),
                    const SizedBox(width: Insets.sm),
                    Icon(Icons.north, size: 12, color: scheme.onSurfaceVariant),
                    Text(delugeFmtRate(torrent.uploadRate)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        '${torrent.numSeeds}/${torrent.totalSeeds} seeds - '
                        '${torrent.numPeers}/${torrent.totalPeers} peers',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (torrent.eta > 0) Text(delugeFmtEta(torrent.eta)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.isPaused,
    required this.onPauseResume,
    required this.onRemove,
    required this.onRecheck,
    required this.onReannounce,
    required this.onQueueTop,
    required this.onQueueUp,
    required this.onQueueDown,
    required this.onQueueBottom,
  });

  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onRemove;
  final VoidCallback onRecheck;
  final VoidCallback onReannounce;
  final VoidCallback onQueueTop;
  final VoidCallback onQueueUp;
  final VoidCallback onQueueDown;
  final VoidCallback onQueueBottom;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pause',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            title: Text(isPaused ? 'Resume' : 'Pause'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'recheck',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fact_check_outlined),
            title: Text('Force recheck'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reannounce',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.campaign_outlined),
            title: Text('Reannounce'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'top',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.vertical_align_top),
            title: Text('Queue to top'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'up',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.arrow_upward),
            title: Text('Queue up'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'down',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.arrow_downward),
            title: Text('Queue down'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'bottom',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.vertical_align_bottom),
            title: Text('Queue to bottom'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'remove',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Remove'),
          ),
        ),
      ],
      onSelected: (String value) {
        switch (value) {
          case 'pause':
            onPauseResume();
          case 'recheck':
            onRecheck();
          case 'reannounce':
            onReannounce();
          case 'top':
            onQueueTop();
          case 'up':
            onQueueUp();
          case 'down':
            onQueueDown();
          case 'bottom':
            onQueueBottom();
          case 'remove':
            onRemove();
        }
      },
    );
  }
}
