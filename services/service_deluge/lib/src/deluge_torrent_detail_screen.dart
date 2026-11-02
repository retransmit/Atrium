import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'deluge_client.dart';
import 'deluge_format.dart';
import 'deluge_providers.dart';
import 'models/deluge_torrent.dart';
import 'models/deluge_torrent_detail.dart';

/// Files, trackers and peers for one torrent.
///
/// The live scalars (state, speeds, progress) come from the list provider that
/// is already polling, so opening this screen does not start a second poll of
/// the same data - only the heavier per-torrent detail is fetched here.
class DelugeTorrentDetailScreen extends ConsumerWidget {
  const DelugeTorrentDetailScreen({
    required this.instance,
    required this.torrentId,
    required this.initialName,
    super.key,
  });

  final Instance instance;
  final String torrentId;

  /// Shown in the app bar until the list provider resolves, so the title is
  /// never empty on the first frame.
  final String initialName;

  /// Runs one torrent action, refreshes the data and, when the torrent is gone,
  /// leaves the screen.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(DelugeClient client) action, {
    bool removed = false,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final DelugeClient client =
          await ref.read(delugeClientProvider(instance).future);
      await action(client);
      // The screen may have been popped while the action was in flight; using
      // ref after disposal throws and would report a completed action as failed.
      if (!context.mounted) return;
      ref.invalidate(delugeRawTorrentsProvider(instance));
      // A removed torrent has no detail left to fetch, and this screen is about
      // to go away anyway.
      if (removed) {
        Navigator.of(context).pop();
      } else {
        ref.invalidate(delugeTorrentDetailProvider((instance, torrentId)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
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
              Text(name),
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
    if (go != true || !context.mounted) return;
    await _run(
      context,
      ref,
      (DelugeClient c) =>
          c.remove(<String>[torrentId], removeData: withData),
      removed: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DelugeTorrent? torrent = ref
        .watch(delugeRawTorrentsProvider(instance))
        .value
        ?.where((DelugeTorrent t) => t.id == torrentId)
        .firstOrNull;
    final AsyncValue<DelugeTorrentDetail> detail =
        ref.watch(delugeTorrentDetailProvider((instance, torrentId)));
    final bool paused = torrent?.isPaused ?? false;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            torrent?.name ?? initialName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: <Widget>[
            PopupMenuButton<String>(
              tooltip: 'Torrent actions',
              onSelected: (String value) async {
                switch (value) {
                  case 'pause':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.pause(<String>[torrentId]),
                    );
                  case 'resume':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.resume(<String>[torrentId]),
                    );
                  case 'recheck':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.recheck(<String>[torrentId]),
                    );
                  case 'reannounce':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.reannounce(<String>[torrentId]),
                    );
                  case 'queue_top':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.queueTop(<String>[torrentId]),
                    );
                  case 'queue_up':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.queueUp(<String>[torrentId]),
                    );
                  case 'queue_down':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.queueDown(<String>[torrentId]),
                    );
                  case 'queue_bottom':
                    await _run(
                      context,
                      ref,
                      (DelugeClient c) => c.queueBottom(<String>[torrentId]),
                    );
                  case 'remove':
                    await _confirmRemove(
                      context,
                      ref,
                      torrent?.name ?? initialName,
                    );
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: paused ? 'resume' : 'pause',
                  child: Text(paused ? 'Resume' : 'Pause'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'recheck',
                  child: Text('Force recheck'),
                ),
                const PopupMenuItem<String>(
                  value: 'reannounce',
                  child: Text('Reannounce'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'queue_top',
                  child: Text('Queue to top'),
                ),
                const PopupMenuItem<String>(
                  value: 'queue_up',
                  child: Text('Queue up'),
                ),
                const PopupMenuItem<String>(
                  value: 'queue_down',
                  child: Text('Queue down'),
                ),
                const PopupMenuItem<String>(
                  value: 'queue_bottom',
                  child: Text('Queue to bottom'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text(
                    'Remove',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            // Four short labels always fit, so a fixed-fill bar spaces them
            // evenly instead of packing a scrollable one to the left.
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Files'),
              Tab(text: 'Trackers'),
              Tab(text: 'Peers'),
            ],
          ),
        ),
        body: AsyncValueView<DelugeTorrentDetail>(
          value: detail,
          onRetry: () => ref.invalidate(
            delugeTorrentDetailProvider((instance, torrentId)),
          ),
          data: (DelugeTorrentDetail d) => TabBarView(
            children: <Widget>[
              _OverviewTab(torrent: torrent, detail: d),
              _FilesTab(detail: d),
              _TrackersTab(detail: d),
              _PeersTab(detail: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.torrent, required this.detail});

  final DelugeTorrent? torrent;
  final DelugeTorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final DelugeTorrent? t = torrent;
    final String state =
        (t?.state ?? '').isEmpty ? 'Unknown' : t!.state;
    final Color accent = delugeStateColor(scheme, t?.state ?? '');
    final Color container = delugeStateContainerColor(scheme, t?.state ?? '');
    final Color onContainer =
        delugeStateOnContainerColor(scheme, t?.state ?? '');
    final double progress = t?.progressFraction ?? 0;
    final bool complete = progress >= 1.0;
    final DateFormat dateFormat = DateFormat.yMMMd().add_Hm();
    String added(int seconds) => seconds <= 0
        ? '-'
        : dateFormat.format(
            DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal(),
          );

    return ListView(
      padding: Insets.page,
      children: <Widget>[
        _Panel(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _IconBlock(
                    icon: delugeStateIcon(state),
                    background: container,
                    foreground: onContainer,
                    size: 48,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${delugeFmtBytes(detail.totalSize)} • '
                          'ratio ${(t?.ratio ?? 0).toStringAsFixed(2)}',
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
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
                        activeColor: accent,
                        trackColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: <Widget>[
                        _SpeedPill(
                          icon: Icons.south,
                          label: delugeFmtRate(t?.downloadRate ?? 0),
                          color: scheme.primary,
                          active: (t?.downloadRate ?? 0) > 0,
                        ),
                        _SpeedPill(
                          icon: Icons.north,
                          label: delugeFmtRate(t?.uploadRate ?? 0),
                          color: scheme.tertiary,
                          active: (t?.uploadRate ?? 0) > 0,
                        ),
                      ],
                    ),
                  ),
                  if (t != null && !complete) ...<Widget>[
                    const SizedBox(width: Insets.sm),
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      delugeFmtEta(t.eta),
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        if (t != null) ...<Widget>[
          _SectionCard(
            title: 'Transfer',
            rows: <(String, String)>[
              (
                'Downloaded',
                '${delugeFmtBytes(t.totalDone)} of '
                    '${delugeFmtBytes(t.totalWanted)}',
              ),
              ('Uploaded', delugeFmtBytes(t.totalUploaded)),
              ('Ratio', t.ratio.toStringAsFixed(3)),
              ('Seeds', '${t.numSeeds} connected (${t.totalSeeds} total)'),
              ('Peers', '${t.numPeers} connected (${t.totalPeers} total)'),
              ('Queue', t.queue < 0 ? 'Not queued' : 'Position ${t.queue}'),
              if (t.eta > 0) ('ETA', delugeFmtEta(t.eta)),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        _SectionCard(
          title: 'Details',
          rows: <(String, String)>[
            ('Total size', delugeFmtBytes(detail.totalSize)),
            ('Files', '${detail.numFiles}'),
            ('Privacy', detail.private ? 'Private' : 'Public'),
            ('Save path', t?.savePath ?? '-'),
            if (t != null && t.trackerHost.isNotEmpty)
              ('Tracker', t.trackerHost),
            if (t != null && t.label.isNotEmpty) ('Label', t.label),
            if (t != null && t.timeAdded > 0) ('Added', added(t.timeAdded)),
            ('Download limit', delugeFmtLimitKib(detail.maxDownloadKib)),
            ('Upload limit', delugeFmtLimitKib(detail.maxUploadKib)),
            if (detail.comment.isNotEmpty) ('Comment', detail.comment),
          ],
        ),
        const SizedBox(height: Insets.xl),
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.detail});

  final DelugeTorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.files.isEmpty) {
      return const EmptyView(
        icon: Icons.insert_drive_file_outlined,
        title: 'No files',
        message: 'Deluge has not received this torrent\'s metadata yet.',
      );
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.files.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _TabHeading('Files (${detail.files.length})');
        }
        final DelugeFile f = detail.files[index - 1];
        return _Panel(
          margin: const EdgeInsets.only(bottom: Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _IconBlock(
                icon: f.priority == 0
                    ? Icons.visibility_off_outlined
                    : Icons.insert_drive_file_outlined,
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
                size: 40,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      f.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicatorM3E(
                        value: f.progress.clamp(0, 1).toDouble(),
                        shape: ProgressM3EShape.flat,
                        size: LinearProgressM3ESize.s,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      '${(f.progress * 100).toStringAsFixed(0)}% • '
                      '${delugeFmtBytes(f.size)} • '
                      '${delugeFilePriorityLabel(f.priority)}',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackersTab extends StatelessWidget {
  const _TrackersTab({required this.detail});

  final DelugeTorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.trackers.isEmpty) {
      return const EmptyView(
        icon: Icons.dns_outlined,
        title: 'No trackers',
        message: 'This torrent announces to no trackers.',
      );
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.trackers.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _TabHeading('Trackers (${detail.trackers.length})');
        }
        final DelugeTracker tracker = detail.trackers[index - 1];
        return _Panel(
          margin: const EdgeInsets.only(bottom: Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _IconBlock(
                icon: tracker.verified
                    ? Icons.verified_outlined
                    : Icons.dns_outlined,
                background: tracker.verified
                    ? scheme.tertiaryContainer
                    : scheme.surfaceContainerHighest,
                foreground: tracker.verified
                    ? scheme.onTertiaryContainer
                    : scheme.onSurfaceVariant,
                size: 40,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tracker.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      tracker.message.isEmpty
                          ? 'Tier ${tracker.tier}'
                          : '${tracker.message} • tier ${tracker.tier}',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({required this.detail});

  final DelugeTorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.peers.isEmpty) {
      return const EmptyView(
        icon: Icons.people_outline,
        title: 'No peers',
        message: 'Nothing is connected right now.',
      );
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.peers.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _TabHeading('Peers (${detail.peers.length})');
        }
        final DelugePeer peer = detail.peers[index - 1];
        return _Panel(
          margin: const EdgeInsets.only(bottom: Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _IconBlock(
                icon: peer.seed
                    ? Icons.upload_outlined
                    : Icons.download_outlined,
                background: peer.seed
                    ? scheme.tertiaryContainer
                    : scheme.primaryContainer,
                foreground: peer.seed
                    ? scheme.onTertiaryContainer
                    : scheme.onPrimaryContainer,
                size: 40,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      peer.ip.isEmpty ? 'Unknown peer' : peer.ip,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${peer.client.isEmpty ? 'Unknown client' : peer.client}'
                      ' • ${(peer.progress * 100).toStringAsFixed(0)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SpeedPill(
                            icon: Icons.south,
                            label: delugeFmtRate(peer.downSpeed),
                            color: scheme.primary,
                            active: peer.downSpeed > 0,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: _SpeedPill(
                            icon: Icons.north,
                            label: delugeFmtRate(peer.upSpeed),
                            color: scheme.tertiary,
                            active: peer.upSpeed > 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rounded titled card of label/value rows, used for the Overview sections.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return _Panel(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Insets.sm),
          for (final (String label, String value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 104,
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Surface-colored rounded container shared by every panel on this screen.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Rounded square holding a state or list icon.
class _IconBlock extends StatelessWidget {
  const _IconBlock({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.size,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}

/// Small tinted pill for a live rate; muted while that direction is idle.
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

/// Section heading above the Files, Trackers and Peers lists.
class _TabHeading extends StatelessWidget {
  const _TabHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
