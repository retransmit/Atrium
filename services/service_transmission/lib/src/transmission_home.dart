import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_session.dart';
import 'models/transmission_torrent.dart';
import 'transmission_add_sheet.dart';
import 'transmission_api.dart';
import 'transmission_detail_screen.dart';
import 'transmission_format.dart';
import 'transmission_providers.dart';
import 'transmission_speed_dialog.dart';

/// Transmission's per-instance UI: the torrent list plus session controls.
///
/// No tabs: Transmission keeps finished torrents in the same list as running
/// ones, so there is no separate history to show.
class TransmissionHome extends ConsumerStatefulWidget {
  const TransmissionHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<TransmissionHome> createState() => _TransmissionHomeState();
}

class _TransmissionHomeState extends ConsumerState<TransmissionHome> {
  void _refresh() {
    // The raw provider owns the fetch; invalidating only the derived filtered
    // one would re-filter stale data without going back to the server.
    ref.invalidate(transmissionRawTorrentsProvider(widget.instance));
    ref.invalidate(transmissionSessionProvider(widget.instance));
    ref.invalidate(transmissionSessionStatsProvider(widget.instance));
  }

  Future<void> _run(Future<void> Function(TransmissionApi api) action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final TransmissionApi api =
          await ref.read(transmissionApiProvider(widget.instance).future);
      await action(api);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) _refresh();
    }
  }

  Future<void> _confirmRemove(TransmissionTorrent t) async {
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
              Text(t.name),
              const SizedBox(height: Insets.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: withData,
                onChanged: (bool? v) => setLocal(() => withData = v ?? false),
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
      (TransmissionApi api) => api.remove(
        <String>[t.hashString],
        deleteLocalData: withData,
      ),
    );
  }

  void _openDetail(TransmissionTorrent t) {
    // The nearest Navigator, not the root one: the detail screen belongs
    // inside the instance's shell.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TransmissionDetailScreen(
          instance: widget.instance,
          hashString: t.hashString,
          initialName: t.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TransmissionTorrent>> torrents =
        ref.watch(transmissionTorrentsProvider(widget.instance));
    return AsyncValueView<List<TransmissionTorrent>>(
      value: torrents,
      onRetry: _refresh,
      data: (List<TransmissionTorrent> list) {
        return EasyRefresh(
          header: const ClassicHeader(),
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: Insets.page,
            children: <Widget>[
              _SessionSummary(
                instance: widget.instance,
                onAdd: () =>
                    showTransmissionAddSheet(context, widget.instance),
                onToggleTurtle: (bool enabled) => _run(
                  (TransmissionApi api) =>
                      api.setAltSpeed(enabled: enabled),
                ),
                onSetDown: (int kbps) => _run(
                  (TransmissionApi api) => api.setSpeedLimits(
                    downKbps: kbps == transmissionUnlimited ? null : kbps,
                    downEnabled: kbps != transmissionUnlimited,
                  ),
                ),
                onSetUp: (int kbps) => _run(
                  (TransmissionApi api) => api.setSpeedLimits(
                    upKbps: kbps == transmissionUnlimited ? null : kbps,
                    upEnabled: kbps != transmissionUnlimited,
                  ),
                ),
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
                    message: 'Nothing here yet. Use Add to start one.',
                  ),
                )
              else
                for (final TransmissionTorrent t in list)
                  _TorrentRow(
                    torrent: t,
                    onTap: () => _openDetail(t),
                    onStartStop: () => _run(
                      (TransmissionApi api) => t.status.isStopped
                          ? api.start(<String>[t.hashString])
                          : api.stop(<String>[t.hashString]),
                    ),
                    onStartNow: () => _run(
                      (TransmissionApi api) =>
                          api.startNow(<String>[t.hashString]),
                    ),
                    onRemove: () => _confirmRemove(t),
                    onVerify: () => _run(
                      (TransmissionApi api) =>
                          api.verify(<String>[t.hashString]),
                    ),
                    onReannounce: () => _run(
                      (TransmissionApi api) =>
                          api.reannounce(<String>[t.hashString]),
                    ),
                    onQueueTop: () => _run(
                      (TransmissionApi api) =>
                          api.queueTop(<String>[t.hashString]),
                    ),
                    onQueueUp: () => _run(
                      (TransmissionApi api) =>
                          api.queueUp(<String>[t.hashString]),
                    ),
                    onQueueDown: () => _run(
                      (TransmissionApi api) =>
                          api.queueDown(<String>[t.hashString]),
                    ),
                    onQueueBottom: () => _run(
                      (TransmissionApi api) =>
                          api.queueBottom(<String>[t.hashString]),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionSummary extends ConsumerWidget {
  const _SessionSummary({
    required this.instance,
    required this.onAdd,
    required this.onToggleTurtle,
    required this.onSetDown,
    required this.onSetUp,
  });

  final Instance instance;
  final VoidCallback onAdd;
  final void Function(bool enabled) onToggleTurtle;
  final void Function(int kbps) onSetDown;
  final void Function(int kbps) onSetUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TransmissionSessionStats stats =
        ref.watch(transmissionSessionStatsProvider(instance)).value ??
            const TransmissionSessionStats();
    final TransmissionSession session =
        ref.watch(transmissionSessionProvider(instance)).value ??
            const TransmissionSession();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.download_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: Insets.xs),
                Text(trFmtRate(stats.downloadSpeed)),
                const SizedBox(width: Insets.lg),
                Icon(Icons.upload_outlined, size: 18, color: scheme.tertiary),
                const SizedBox(width: Insets.xs),
                Text(trFmtRate(stats.uploadSpeed)),
                const Spacer(),
                // Only shown when the daemon actually knows: a containerised
                // Transmission commonly reports -1 here.
                if (session.knowsFreeSpace)
                  Text(
                    '${trFmtBytes(session.downloadDirFreeSpace)} free',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              '${stats.activeTorrentCount} active, '
              '${stats.pausedTorrentCount} paused '
              'of ${stats.torrentCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                // Turtle mode overrides both limits while on, so it is a
                // distinct control rather than another limit value.
                FilledButton.tonalIcon(
                  onPressed: () => onToggleTurtle(!session.altSpeedEnabled),
                  icon: Icon(
                    session.altSpeedEnabled
                        ? Icons.speed
                        : Icons.slow_motion_video,
                  ),
                  label: Text(
                    session.altSpeedEnabled
                        ? 'Turtle on (${session.altSpeedDown}/'
                            '${session.altSpeedUp} KB/s)'
                        : 'Turtle off',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final int? kbps = await showTransmissionSpeedDialog(
                      context,
                      title: 'Download limit',
                      currentKbps: session.speedLimitDown,
                      currentEnabled: session.speedLimitDownEnabled,
                    );
                    if (kbps != null) onSetDown(kbps);
                  },
                  icon: const Icon(Icons.south, size: 18),
                  label: Text(
                    trFmtLimit(
                      kbps: session.speedLimitDown,
                      enabled: session.speedLimitDownEnabled,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final int? kbps = await showTransmissionSpeedDialog(
                      context,
                      title: 'Upload limit',
                      currentKbps: session.speedLimitUp,
                      currentEnabled: session.speedLimitUpEnabled,
                    );
                    if (kbps != null) onSetUp(kbps);
                  },
                  icon: const Icon(Icons.north, size: 18),
                  label: Text(
                    trFmtLimit(
                      kbps: session.speedLimitUp,
                      enabled: session.speedLimitUpEnabled,
                    ),
                  ),
                ),
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

/// Status and label filter chips, plus the sort control.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransmissionTorrent> all =
        ref.watch(transmissionRawTorrentsProvider(instance)).value ??
            const <TransmissionTorrent>[];
    final TransmissionFilter filter =
        ref.watch(transmissionFilterProvider(instance));
    final List<String> labels = transmissionLabels(all);

    // Only offer statuses that something is actually in, so the row does not
    // fill up with chips that can only ever show zero.
    final Set<TransmissionStatus> present = <TransmissionStatus>{
      for (final TransmissionTorrent t in all) t.status,
    };
    final List<TransmissionStatus> statuses = <TransmissionStatus>[
      for (final TransmissionStatus s in TransmissionStatus.values)
        if (present.contains(s)) s,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: Insets.xs),
                child: FilterChip(
                  label: Text('All (${all.length})'),
                  selected: filter.status == null,
                  onSelected: (_) => ref
                      .read(transmissionFilterProvider(instance).notifier)
                      .update(
                        (TransmissionFilter f) => f.copyWith(clearStatus: true),
                      ),
                ),
              ),
              for (final TransmissionStatus s in statuses)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.xs),
                  child: FilterChip(
                    label: Text(
                      '${s.label} '
                      '(${all.where((TransmissionTorrent t) => t.status == s).length})',
                    ),
                    selected: filter.status == s,
                    onSelected: (bool on) => ref
                        .read(transmissionFilterProvider(instance).notifier)
                        .update(
                          (TransmissionFilter f) => on
                              ? f.copyWith(status: s)
                              : f.copyWith(clearStatus: true),
                        ),
                  ),
                ),
            ],
          ),
        ),
        // Labels are a Transmission 4 feature and often unused, so the row is
        // only built when torrents actually carry some.
        if (labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final String l in labels)
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.xs),
                    child: FilterChip(
                      label: Text(l),
                      selected: filter.label == l,
                      onSelected: (bool on) => ref
                          .read(transmissionFilterProvider(instance).notifier)
                          .update(
                            (TransmissionFilter f) =>
                                f.copyWith(label: on ? l : ''),
                          ),
                    ),
                  ),
              ],
            ),
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

class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransmissionSortField field =
        ref.watch(transmissionSortFieldProvider(instance));
    final bool descending =
        ref.watch(transmissionSortDescendingProvider(instance));
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButton<TransmissionSortField>(
            isExpanded: true,
            value: field,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<TransmissionSortField>>[
              for (final TransmissionSortField f
                  in TransmissionSortField.values)
                DropdownMenuItem<TransmissionSortField>(
                  value: f,
                  child: Text(f.displayName),
                ),
            ],
            onChanged: (TransmissionSortField? f) {
              if (f != null) {
                ref
                    .read(transmissionSortFieldProvider(instance).notifier)
                    .state = f;
              }
            },
          ),
        ),
        IconButton(
          tooltip: descending ? 'Descending' : 'Ascending',
          icon: Icon(descending ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: () => ref
              .read(transmissionSortDescendingProvider(instance).notifier)
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
    required this.onStartStop,
    required this.onStartNow,
    required this.onRemove,
    required this.onVerify,
    required this.onReannounce,
    required this.onQueueTop,
    required this.onQueueUp,
    required this.onQueueDown,
    required this.onQueueBottom,
  });

  final TransmissionTorrent torrent;
  final VoidCallback onTap;
  final VoidCallback onStartStop;
  final VoidCallback onStartNow;
  final VoidCallback onRemove;
  final VoidCallback onVerify;
  final VoidCallback onReannounce;
  final VoidCallback onQueueTop;
  final VoidCallback onQueueUp;
  final VoidCallback onQueueDown;
  final VoidCallback onQueueBottom;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color color = trStatusColor(scheme, torrent);

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
                  Icon(trStatusIcon(torrent), size: 18, color: color),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      torrent.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  _RowMenu(
                    isStopped: torrent.status.isStopped,
                    onStartStop: onStartStop,
                    onStartNow: onStartNow,
                    onRemove: onRemove,
                    onVerify: onVerify,
                    onReannounce: onReannounce,
                    onQueueTop: onQueueTop,
                    onQueueUp: onQueueUp,
                    onQueueDown: onQueueDown,
                    onQueueBottom: onQueueBottom,
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              LinearProgressIndicator(
                value: torrent.percentDone.clamp(0, 1),
                color: color,
              ),
              const SizedBox(height: Insets.xs),
              DefaultTextStyle.merge(
                style: text.bodySmall,
                child: Row(
                  children: <Widget>[
                    Text('${(torrent.percentDone * 100).toStringAsFixed(1)}%'),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        '${trFmtBytes(torrent.doneBytes)}'
                        ' / ${trFmtBytes(torrent.sizeWhenDone)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      torrent.statusLabel,
                      style: text.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              if (torrent.hasError) ...<Widget>[
                const SizedBox(height: Insets.xxs),
                Text(
                  torrent.errorString,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: Insets.xxs),
              DefaultTextStyle.merge(
                style: text.bodySmall,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.south, size: 12),
                    Text(trFmtRate(torrent.downloadRate)),
                    const SizedBox(width: Insets.sm),
                    const Icon(Icons.north, size: 12),
                    Text(trFmtRate(torrent.uploadRate)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        'P ${torrent.peersSendingToUs}'
                        '/${torrent.peersConnected}'
                        '  R ${torrent.ratio.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (torrent.hasEta) Text(trFmtEta(torrent.eta)),
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
    required this.isStopped,
    required this.onStartStop,
    required this.onStartNow,
    required this.onRemove,
    required this.onVerify,
    required this.onReannounce,
    required this.onQueueTop,
    required this.onQueueUp,
    required this.onQueueDown,
    required this.onQueueBottom,
  });

  final bool isStopped;
  final VoidCallback onStartStop;
  final VoidCallback onStartNow;
  final VoidCallback onRemove;
  final VoidCallback onVerify;
  final VoidCallback onReannounce;
  final VoidCallback onQueueTop;
  final VoidCallback onQueueUp;
  final VoidCallback onQueueDown;
  final VoidCallback onQueueBottom;

  static PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _item(
          'startStop',
          isStopped ? Icons.play_arrow : Icons.pause,
          isStopped ? 'Start' : 'Stop',
        ),
        if (isStopped)
          _item('startNow', Icons.flash_on, 'Start now (skip queue)'),
        _item('verify', Icons.fact_check_outlined, 'Verify local data'),
        _item('reannounce', Icons.campaign_outlined, 'Ask tracker for peers'),
        const PopupMenuDivider(),
        _item('top', Icons.vertical_align_top, 'Queue to top'),
        _item('up', Icons.arrow_upward, 'Queue up'),
        _item('down', Icons.arrow_downward, 'Queue down'),
        _item('bottom', Icons.vertical_align_bottom, 'Queue to bottom'),
        const PopupMenuDivider(),
        _item('remove', Icons.delete_outline, 'Remove'),
      ],
      onSelected: (String value) {
        switch (value) {
          case 'startStop':
            onStartStop();
          case 'startNow':
            onStartNow();
          case 'verify':
            onVerify();
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
