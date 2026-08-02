import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/rtorrent_detail.dart';
import 'models/rtorrent_torrent.dart';
import 'rtorrent_add_sheet.dart';
import 'rtorrent_api.dart';
import 'rtorrent_detail_screen.dart';
import 'rtorrent_format.dart';
import 'rtorrent_providers.dart';
import 'rtorrent_speed_dialog.dart';

/// rTorrent's per-instance UI: the torrent list plus global controls.
///
/// No tabs: rTorrent keeps finished torrents in the same view as running ones,
/// so there is no separate history to show.
class RtorrentHome extends ConsumerStatefulWidget {
  const RtorrentHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<RtorrentHome> createState() => _RtorrentHomeState();
}

class _RtorrentHomeState extends ConsumerState<RtorrentHome> {
  void _refresh() {
    // The raw provider owns the fetch; invalidating only the derived filtered
    // one would re-filter stale data without going back to the server.
    ref.invalidate(rtorrentRawTorrentsProvider(widget.instance));
    ref.invalidate(rtorrentGlobalProvider(widget.instance));
  }

  Future<void> _run(Future<void> Function(RtorrentApi api) action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final RtorrentApi api =
          await ref.read(rtorrentApiProvider(widget.instance).future);
      await action(api);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) _refresh();
    }
  }

  Future<void> _confirmRemove(RtorrentTorrent t) async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove torrent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(t.name),
            const SizedBox(height: Insets.md),
            // Said plainly because it is the one place rTorrent differs from
            // every other client Atrium talks to: there is no delete-with-data.
            Text(
              'rTorrent cannot delete the downloaded files. They stay in\n'
              '${t.directory}\n'
              'until you remove them on the server.',
              style: Theme.of(context).textTheme.bodySmall,
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
    );
    if (go != true) return;
    await _run((RtorrentApi api) => api.erase(t.hash));
  }

  Future<void> _pickPriority(RtorrentTorrent t) async {
    final int? priority = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Priority'),
        children: <Widget>[
          for (final (int value, String label) in const <(int, String)>[
            (0, 'Off'),
            (1, 'Low'),
            (2, 'Normal'),
            (3, 'High'),
          ])
            ListTile(
              selected: value == t.priority,
              title: Text(label),
              trailing:
                  value == t.priority ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(value),
            ),
        ],
      ),
    );
    if (priority == null || priority == t.priority) return;
    await _run((RtorrentApi api) => api.setPriority(t.hash, priority));
  }

  void _openDetail(RtorrentTorrent t) {
    // pushScreen, not Navigator.push: a page pushed onto the branch navigator
    // is absent from GoRouter's route table and is dropped on the next shell
    // rebuild, which polling triggers constantly.
    pushScreen<void>(
      context,
      RtorrentDetailScreen(
        instance: widget.instance,
        hash: t.hash,
        initialName: t.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RtorrentTorrent>> torrents =
        ref.watch(rtorrentTorrentsProvider(widget.instance));
    return AsyncValueView<List<RtorrentTorrent>>(
      value: torrents,
      onRetry: _refresh,
      data: (List<RtorrentTorrent> list) {
        return EasyRefresh(
          header: const ClassicHeader(),
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: Insets.page,
            children: <Widget>[
              _GlobalSummary(
                instance: widget.instance,
                onAdd: () => showRtorrentAddSheet(context, widget.instance),
                onSetDown: (int bytesPerSec) =>
                    _run((RtorrentApi api) => api.setDownLimit(bytesPerSec)),
                onSetUp: (int bytesPerSec) =>
                    _run((RtorrentApi api) => api.setUpLimit(bytesPerSec)),
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
                for (final RtorrentTorrent t in list)
                  _TorrentRow(
                    torrent: t,
                    onTap: () => _openDetail(t),
                    onStartStop: () => _run(
                      (RtorrentApi api) =>
                          t.state == 0 ? api.start(t.hash) : api.stop(t.hash),
                    ),
                    onClose: () => _run((RtorrentApi api) => api.close(t.hash)),
                    onRemove: () => _confirmRemove(t),
                    onRecheck: () =>
                        _run((RtorrentApi api) => api.recheck(t.hash)),
                    onReannounce: () =>
                        _run((RtorrentApi api) => api.reannounce(t.hash)),
                    onPriority: () => _pickPriority(t),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalSummary extends ConsumerWidget {
  const _GlobalSummary({
    required this.instance,
    required this.onAdd,
    required this.onSetDown,
    required this.onSetUp,
  });

  final Instance instance;
  final VoidCallback onAdd;
  final void Function(int bytesPerSec) onSetDown;
  final void Function(int bytesPerSec) onSetUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RtorrentGlobal g = ref.watch(rtorrentGlobalProvider(instance)).value ??
        const RtorrentGlobal();
    final List<RtorrentTorrent> all =
        ref.watch(rtorrentRawTorrentsProvider(instance)).value ??
            const <RtorrentTorrent>[];
    final int active =
        all.where((RtorrentTorrent t) => t.isActive).length;
    final int stopped =
        all.where((RtorrentTorrent t) => t.state == 0).length;

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
                    bytesPerSec: g.downRate,
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: _SpeedReadout(
                    icon: Icons.north,
                    bytesPerSec: g.upRate,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              <String>[
                '$active active',
                '$stopped stopped of ${all.length}',
                if (g.version.isNotEmpty) 'rTorrent ${g.version}',
                if (g.listenPort > 0) 'port ${g.listenPort}',
              ].join(' - '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Divider(height: Insets.xl),
            Row(
              children: <Widget>[
                // Limits read as status first and controls second, so they are
                // quiet text rather than buttons competing with Add.
                Expanded(
                  child: _LimitButton(
                    icon: Icons.south,
                    label: rtFmtLimit(g.downLimit),
                    onPressed: () async {
                      final int? bytes = await showRtorrentSpeedDialog(
                        context,
                        title: 'Download limit',
                        currentBytesPerSec: g.downLimit,
                      );
                      if (bytes != null) onSetDown(bytes);
                    },
                  ),
                ),
                Expanded(
                  child: _LimitButton(
                    icon: Icons.north,
                    label: rtFmtLimit(g.upLimit),
                    onPressed: () async {
                      final int? bytes = await showRtorrentSpeedDialog(
                        context,
                        title: 'Upload limit',
                        currentBytesPerSec: g.upLimit,
                      );
                      if (bytes != null) onSetUp(bytes);
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
    final (String value, String unit) = rtSplitRate(bytesPerSec);
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
    final List<RtorrentTorrent> all =
        ref.watch(rtorrentRawTorrentsProvider(instance)).value ??
            const <RtorrentTorrent>[];
    final RtorrentFilter filter = ref.watch(rtorrentFilterProvider(instance));
    final List<String> labels = rtorrentLabels(all);

    // Only offer statuses that something is actually in, so the row does not
    // fill up with chips that can only ever show zero.
    final Set<RtorrentStatus> present = <RtorrentStatus>{
      for (final RtorrentTorrent t in all) t.status,
    };
    final List<RtorrentStatus> statuses = <RtorrentStatus>[
      for (final RtorrentStatus s in RtorrentStatus.values)
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
                      .read(rtorrentFilterProvider(instance).notifier)
                      .update(
                        (RtorrentFilter f) => f.copyWith(clearStatus: true),
                      ),
                ),
              ),
              for (final RtorrentStatus s in statuses)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.xs),
                  child: FilterChip(
                    label: Text(
                      '${s.label} '
                      '(${all.where((RtorrentTorrent t) => t.status == s).length})',
                    ),
                    selected: filter.status == s,
                    onSelected: (bool on) => ref
                        .read(rtorrentFilterProvider(instance).notifier)
                        .update(
                          (RtorrentFilter f) => on
                              ? f.copyWith(status: s)
                              : f.copyWith(clearStatus: true),
                        ),
                  ),
                ),
            ],
          ),
        ),
        // Labels come from ruTorrent writing d.custom1, so a plain rTorrent has
        // none and the row is simply not built.
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
                          .read(rtorrentFilterProvider(instance).notifier)
                          .update(
                            (RtorrentFilter f) =>
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
    final RtorrentSortField field =
        ref.watch(rtorrentSortFieldProvider(instance));
    final bool descending =
        ref.watch(rtorrentSortDescendingProvider(instance));
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButton<RtorrentSortField>(
            isExpanded: true,
            value: field,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<RtorrentSortField>>[
              for (final RtorrentSortField f in RtorrentSortField.values)
                DropdownMenuItem<RtorrentSortField>(
                  value: f,
                  child: Text(f.displayName),
                ),
            ],
            onChanged: (RtorrentSortField? f) {
              if (f != null) {
                ref.read(rtorrentSortFieldProvider(instance).notifier).state =
                    f;
              }
            },
          ),
        ),
        IconButton(
          tooltip: descending ? 'Descending' : 'Ascending',
          icon: Icon(descending ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: () => ref
              .read(rtorrentSortDescendingProvider(instance).notifier)
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
    required this.onClose,
    required this.onRemove,
    required this.onRecheck,
    required this.onReannounce,
    required this.onPriority,
  });

  final RtorrentTorrent torrent;
  final VoidCallback onTap;
  final VoidCallback onStartStop;
  final VoidCallback onClose;
  final VoidCallback onRemove;
  final VoidCallback onRecheck;
  final VoidCallback onReannounce;
  final VoidCallback onPriority;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color color = rtStatusColor(scheme, torrent);
    final bool done = torrent.isComplete;
    final bool moving = torrent.downRate > 0 || torrent.upRate > 0;
    final String eta = rtFmtEta(torrent);

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
                  Icon(rtStatusIcon(torrent), size: 18, color: color),
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
                    isStopped: torrent.state == 0,
                    isOpen: torrent.isOpen,
                    onStartStop: onStartStop,
                    onClose: onClose,
                    onRemove: onRemove,
                    onRecheck: onRecheck,
                    onReannounce: onReannounce,
                    onPriority: onPriority,
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
                    : torrent.progress,
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
                                : '${(torrent.progress * 100)
                                    .toStringAsFixed(0)}%',
                            style: text.titleSmall
                                ?.copyWith(color: scheme.onSurface),
                          ),
                          TextSpan(
                            text: done
                                ? '  ${rtFmtBytes(torrent.uploadedTotal)} '
                                    'shared of '
                                    '${rtFmtBytes(torrent.sizeBytes)}'
                                : '  ${rtFmtBytes(torrent.completedBytes)} of '
                                    '${rtFmtBytes(torrent.sizeBytes)}',
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
                    torrent.status.label,
                    style: text.labelMedium?.copyWith(color: color),
                  ),
                ],
              ),
              if (torrent.hasError) ...<Widget>[
                const SizedBox(height: Insets.xxs),
                Text(
                  torrent.message,
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
                    Text(rtFmtRate(torrent.downRate)),
                    const SizedBox(width: Insets.sm),
                    Icon(Icons.north, size: 12, color: scheme.onSurfaceVariant),
                    Text(rtFmtRate(torrent.upRate)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        '${torrent.peersComplete}/'
                        '${torrent.peersConnected} peers',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (eta != '-') Text(eta),
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
    required this.isOpen,
    required this.onStartStop,
    required this.onClose,
    required this.onRemove,
    required this.onRecheck,
    required this.onReannounce,
    required this.onPriority,
  });

  final bool isStopped;
  final bool isOpen;
  final VoidCallback onStartStop;
  final VoidCallback onClose;
  final VoidCallback onRemove;
  final VoidCallback onRecheck;
  final VoidCallback onReannounce;
  final VoidCallback onPriority;

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
        // Closing frees the file handles, which is rTorrent's own step between
        // stopped and removed. Only worth offering while the torrent is open.
        if (isOpen) _item('close', Icons.eject_outlined, 'Close'),
        _item('recheck', Icons.fact_check_outlined, 'Check hash'),
        _item('reannounce', Icons.campaign_outlined, 'Ask tracker for peers'),
        const PopupMenuDivider(),
        _item('priority', Icons.low_priority, 'Priority'),
        const PopupMenuDivider(),
        _item('remove', Icons.delete_outline, 'Remove'),
      ],
      onSelected: (String value) {
        switch (value) {
          case 'startStop':
            onStartStop();
          case 'close':
            onClose();
          case 'recheck':
            onRecheck();
          case 'reannounce':
            onReannounce();
          case 'priority':
            onPriority();
          case 'remove':
            onRemove();
        }
      },
    );
  }
}
