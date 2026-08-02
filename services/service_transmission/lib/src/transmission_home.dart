import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

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
    // pushScreen, not Navigator.push: a page pushed onto the branch navigator
    // is absent from GoRouter's route table and is dropped on the next shell
    // rebuild, which polling triggers constantly.
    pushScreen<void>(
      context,
      TransmissionDetailScreen(
        instance: widget.instance,
        hashString: t.hashString,
        initialName: t.name,
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
            // The two live rates are the point of this card, so they get the
            // only large type on the screen. Everything else stays quiet.
            Row(
              children: <Widget>[
                Expanded(
                  child: _SpeedReadout(
                    icon: Icons.south,
                    bytesPerSec: stats.downloadSpeed,
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: _SpeedReadout(
                    icon: Icons.north,
                    bytesPerSec: stats.uploadSpeed,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              <String>[
                '${stats.activeTorrentCount} active',
                '${stats.pausedTorrentCount} paused of ${stats.torrentCount}',
                // Only shown when the daemon actually knows: a containerised
                // Transmission commonly reports -1 here.
                if (session.knowsFreeSpace)
                  '${trFmtBytes(session.downloadDirFreeSpace)} free',
              ].join(' - '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Divider(height: Insets.xl),
            Row(
              children: <Widget>[
                // Turtle mode overrides both limits while on, so it is a
                // distinct control rather than another limit value.
                IconButton.filledTonal(
                  tooltip: session.altSpeedEnabled
                      ? 'Turtle on: ${session.altSpeedDown}/'
                          '${session.altSpeedUp} KB/s'
                      : 'Turtle off',
                  isSelected: session.altSpeedEnabled,
                  onPressed: () => onToggleTurtle(!session.altSpeedEnabled),
                  icon: const Icon(Icons.slow_motion_video),
                ),
                const SizedBox(width: Insets.xs),
                // Limits read as status first and controls second, so they are
                // quiet text rather than buttons competing with Add.
                Expanded(
                  child: _LimitButton(
                    icon: Icons.south,
                    label: trFmtLimit(
                      kbps: session.speedLimitDown,
                      enabled: session.speedLimitDownEnabled,
                    ),
                    onPressed: () async {
                      final int? kbps = await showTransmissionSpeedDialog(
                        context,
                        title: 'Download limit',
                        currentKbps: session.speedLimitDown,
                        currentEnabled: session.speedLimitDownEnabled,
                      );
                      if (kbps != null) onSetDown(kbps);
                    },
                  ),
                ),
                Expanded(
                  child: _LimitButton(
                    icon: Icons.north,
                    label: trFmtLimit(
                      kbps: session.speedLimitUp,
                      enabled: session.speedLimitUpEnabled,
                    ),
                    onPressed: () async {
                      final int? kbps = await showTransmissionSpeedDialog(
                        context,
                        title: 'Upload limit',
                        currentKbps: session.speedLimitUp,
                        currentEnabled: session.speedLimitUpEnabled,
                      );
                      if (kbps != null) onSetUp(kbps);
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final (String value, String unit) = trSplitRate(bytesPerSec);
    final bool idle = bytesPerSec <= 0;
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
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
    final bool done = torrent.percentDone >= 1.0;
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
                  Icon(trStatusIcon(torrent), size: 18, color: color),
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
              // Once a torrent is finished its progress bar is pinned at 100%
              // and says nothing. Give the bar a second job: show share ratio
              // toward 1.0, which is the one number still moving.
              LinearProgressIndicatorM3E(
                value: done
                    ? torrent.ratio.clamp(0, 1).toDouble()
                    : torrent.percentDone.clamp(0, 1).toDouble(),
                // The expressive wave reads as "moving right now", so it is
                // spent only on torrents actually shifting bytes. A torrent
                // parked at 100% stays flat.
                shape: moving ? ProgressM3EShape.wavy : ProgressM3EShape.flat,
                size: LinearProgressM3ESize.s,
                activeColor: color,
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
                                : '${(torrent.percentDone * 100)
                                    .toStringAsFixed(0)}%',
                            style: text.titleSmall
                                ?.copyWith(color: scheme.onSurface),
                          ),
                          TextSpan(
                            text: done
                                ? '  ${trFmtBytes(torrent.uploadedEver)} '
                                    'shared of '
                                    '${trFmtBytes(torrent.sizeWhenDone)}'
                                : '  ${trFmtBytes(torrent.doneBytes)} of '
                                    '${trFmtBytes(torrent.sizeWhenDone)}',
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    torrent.statusLabel,
                    style: text.labelMedium?.copyWith(color: color),
                  ),
                ],
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
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.south, size: 12, color: scheme.onSurfaceVariant),
                    Text(trFmtRate(torrent.downloadRate)),
                    const SizedBox(width: Insets.sm),
                    Icon(Icons.north, size: 12, color: scheme.onSurfaceVariant),
                    Text(trFmtRate(torrent.uploadRate)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        '${torrent.peersSendingToUs}/'
                        '${torrent.peersConnected} peers',
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
