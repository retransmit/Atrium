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
    // pushScreen, not Navigator.push: a page pushed onto the branch navigator
    // is absent from GoRouter's route table and is dropped on the next shell
    // rebuild, which polling triggers constantly.
    pushScreen<void>(
      context,
      DelugeTorrentDetailScreen(
        instance: widget.instance,
        torrentId: torrent.id,
        initialName: torrent.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DelugeTorrent>> torrents =
        ref.watch(delugeTorrentsProvider(widget.instance));
    return Scaffold(
      // Adding a torrent is the one global action here, so it floats over the
      // list instead of crowding the session card.
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add torrent',
        onPressed: () => showDelugeAddSheet(context, widget.instance),
        child: const Icon(Icons.add),
      ),
      body: AsyncValueView<List<DelugeTorrent>>(
        value: torrents,
        onRetry: _refresh,
        data: (List<DelugeTorrent> list) {
          return EasyRefresh(
            header: const ClassicHeader(),
            onRefresh: () async => _refresh(),
            child: ListView(
              // Extra bottom inset so the add button never covers the last row.
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                80,
              ),
              children: <Widget>[
                _SessionSummary(
                  instance: widget.instance,
                  onTogglePause: (bool paused) => _run(
                    (DelugeClient c) => c.setSessionPaused(paused: paused),
                  ),
                  onSetDownLimit: (double kib) => _run(
                    (DelugeClient c) => c.setSpeedLimits(downloadKib: kib),
                  ),
                  onSetUpLimit: (double kib) => _run(
                    (DelugeClient c) => c.setSpeedLimits(uploadKib: kib),
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
                      onReannounce: () => _run(
                        (DelugeClient c) => c.reannounce(<String>[t.id]),
                      ),
                      onQueueTop: () =>
                          _run((DelugeClient c) => c.queueTop(<String>[t.id])),
                      onQueueUp: () =>
                          _run((DelugeClient c) => c.queueUp(<String>[t.id])),
                      onQueueDown: () => _run(
                        (DelugeClient c) => c.queueDown(<String>[t.id]),
                      ),
                      onQueueBottom: () => _run(
                        (DelugeClient c) => c.queueBottom(<String>[t.id]),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Live session rates and remaining disk space, one tile each, plus the global
/// pause and speed-limit controls.
class _SessionSummary extends ConsumerWidget {
  const _SessionSummary({
    required this.instance,
    required this.onTogglePause,
    required this.onSetDownLimit,
    required this.onSetUpLimit,
  });

  final Instance instance;
  final void Function(bool paused) onTogglePause;
  final void Function(double kib) onSetDownLimit;
  final void Function(double kib) onSetUpLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DelugeSessionStatus status =
        ref.watch(delugeSessionStatusProvider(instance)).value ??
            const DelugeSessionStatus();
    final bool paused =
        ref.watch(delugeSessionPausedProvider(instance)).value ?? false;
    final DelugeSpeedLimits limits =
        ref.watch(delugeSpeedLimitsProvider(instance)).value ??
            const DelugeSpeedLimits();
    final int? freeSpace = ref.watch(delugeFreeSpaceProvider(instance)).value;

    final (String downValue, String downUnit) =
        delugeSplitRate(status.downloadRate);
    final (String upValue, String upUnit) = delugeSplitRate(status.uploadRate);
    final (String freeValue, String freeUnit) = _splitSize(
      freeSpace == null ? '--' : delugeFmtBytes(freeSpace),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // IntrinsicHeight lets the three tiles stretch to the same height
            // even when one figure has to scale down to fit its tile.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _StatBox(
                      icon: Icons.south,
                      label: 'Download',
                      value: downValue,
                      unit: downUnit,
                      background: scheme.primaryContainer,
                      foreground: scheme.onPrimaryContainer,
                      accent: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _StatBox(
                      icon: Icons.north,
                      label: 'Upload',
                      value: upValue,
                      unit: upUnit,
                      background: scheme.tertiaryContainer,
                      foreground: scheme.onTertiaryContainer,
                      accent: scheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _StatBox(
                      icon: Icons.storage_outlined,
                      label: 'Free space',
                      value: freeValue,
                      unit: freeUnit,
                      background: scheme.surfaceContainerHighest,
                      foreground: scheme.onSurface,
                      accent: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            // The global controls sit under the live figures. Wrap keeps them
            // usable on narrow screens without clipping the limit labels.
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: paused ? 'Resume session' : 'Pause session',
                  onPressed: () => onTogglePause(!paused),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                ),
                _LimitButton(
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
                _LimitButton(
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
              ],
            ),
          ],
        ),
      ),
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

/// Splits `'123.4 GB'` into `('123.4', 'GB')`. A placeholder with no space is
/// kept whole so it still renders without a unit.
(String, String) _splitSize(String text) {
  final int space = text.lastIndexOf(' ');
  return space < 0
      ? (text, '')
      : (text.substring(0, space), text.substring(space + 1));
}

/// One session figure on a tinted tile: label, then the value and its unit.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color background;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          // The tile can be narrow on small phones; scale the figure down
          // rather than let a long rate wrap or clip.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: value,
                    style: text.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: text.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label filter chips, when the daemon offers labels, and the sort menu.
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
        // Only rendered when the daemon has the Label plugin; otherwise there
        // is nothing to filter on and the row would always be empty.
        if (tree.hasLabels) ...<Widget>[
          _ChipRow(
            buckets: tree.labels,
            selected: filter.label,
            onSelected: (String v) => ref
                .read(delugeFilterProvider(instance).notifier)
                .update((DelugeFilter f) => f.copyWith(label: v)),
          ),
          const SizedBox(height: Insets.xs),
        ],
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

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ColorScheme scheme = Theme.of(sheetContext).colorScheme;
        void run(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: Icon(
                  torrent.isPaused ? Icons.play_arrow : Icons.pause,
                ),
                title: Text(torrent.isPaused ? 'Resume' : 'Pause'),
                onTap: () => run(onPauseResume),
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Force recheck'),
                onTap: () => run(onRecheck),
              ),
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('Reannounce'),
                onTap: () => run(onReannounce),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.vertical_align_top),
                title: const Text('Queue to top'),
                onTap: () => run(onQueueTop),
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Queue up'),
                onTap: () => run(onQueueUp),
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Queue down'),
                onTap: () => run(onQueueDown),
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_bottom),
                title: const Text('Queue to bottom'),
                onTap: () => run(onQueueBottom),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(
                  'Remove',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () => run(onRemove),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color stateColor = delugeStateColor(scheme, torrent.state);
    final Color stateContainer =
        delugeStateContainerColor(scheme, torrent.state);
    final Color stateOnContainer =
        delugeStateOnContainerColor(scheme, torrent.state);
    final double progress = torrent.progressFraction;
    final bool complete = progress >= 1.0;
    final bool dlActive = torrent.downloadRate > 0;
    final bool upActive = torrent.uploadRate > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // The card carries no visible menu; the per-torrent actions live on
          // a long press, the same way qBittorrent's cards behave.
          onLongPress: () => _showActions(context),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: stateContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        delugeStateIcon(torrent.state),
                        size: 22,
                        color: stateOnContainer,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            torrent.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: Insets.sm,
                            runSpacing: Insets.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              _StatePill(
                                label: torrent.state.isEmpty
                                    ? 'Unknown'
                                    : torrent.state,
                                background: stateContainer,
                                foreground: stateOnContainer,
                              ),
                              Text(
                                '${delugeFmtBytes(torrent.totalDone)} / '
                                '${delugeFmtBytes(torrent.totalWanted)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicatorM3E(
                          shape: ProgressM3EShape.flat,
                          value: progress,
                          activeColor:
                              complete ? scheme.tertiary : stateColor,
                          trackColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: complete ? scheme.tertiary : stateColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                // Wrap instead of a Row: on a narrow phone or at a large text
                // scale the trailing ratio and ETA move to a second line
                // rather than clipping the speed pills.
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _SpeedPill(
                      icon: Icons.south,
                      label: delugeFmtRate(torrent.downloadRate),
                      color: scheme.primary,
                      active: dlActive,
                    ),
                    _SpeedPill(
                      icon: Icons.north,
                      label: delugeFmtRate(torrent.uploadRate),
                      color: scheme.tertiary,
                      active: upActive,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.swap_vert,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          torrent.ratio.toStringAsFixed(2),
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (!complete) ...<Widget>[
                          const SizedBox(width: Insets.sm),
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            delugeFmtEta(torrent.eta),
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// State word on the torrent card, tinted the same way qBittorrent's pill is.
class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// One live rate on the torrent card; muted while the direction is idle.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.icon,
    required this.label,
    required this.color,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = active ? color : scheme.onSurfaceVariant;
    final Color background = active
        ? color.withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
