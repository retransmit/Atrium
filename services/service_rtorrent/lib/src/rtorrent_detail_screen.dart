import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/rtorrent_detail.dart';
import 'models/rtorrent_torrent.dart';
import 'rtorrent_api.dart';
import 'rtorrent_format.dart';
import 'rtorrent_providers.dart';

/// Files, peers and trackers for one torrent.
///
/// The live scalars (status, speeds, progress) come from the list provider that
/// is already polling, so opening this screen does not start a second poll of
/// the same data.
class RtorrentDetailScreen extends ConsumerWidget {
  const RtorrentDetailScreen({
    required this.instance,
    required this.hash,
    required this.initialName,
    super.key,
  });

  final Instance instance;

  /// The infohash. rTorrent addresses everything by it, and it is stable across
  /// daemon restarts.
  final String hash;

  /// Shown until the list provider resolves, so the title is never empty.
  final String initialName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RtorrentDetailArgs args = RtorrentDetailArgs(instance, hash);
    final RtorrentTorrent? torrent =
        ref.watch(rtorrentTorrentProvider(args)).value;
    final AsyncValue<RtorrentDetail> detail =
        ref.watch(rtorrentDetailProvider(args));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(torrent?.name ?? initialName, maxLines: 1),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Files'),
              Tab(text: 'Peers'),
              Tab(text: 'Trackers'),
            ],
          ),
        ),
        body: AsyncValueView<RtorrentDetail>(
          value: detail,
          onRetry: () => ref.invalidate(rtorrentDetailProvider(args)),
          data: (RtorrentDetail d) => TabBarView(
            children: <Widget>[
              _OverviewTab(torrent: torrent, detail: d),
              _FilesTab(instance: instance, hash: hash, detail: d),
              _PeersTab(detail: d),
              _TrackersTab(detail: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.torrent, required this.detail});

  final RtorrentTorrent? torrent;
  final RtorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RtorrentTorrent? t = torrent;
    return ListView(
      padding: Insets.page,
      children: <Widget>[
        if (t != null) ...<Widget>[
          LinearProgressIndicatorM3E(
            value: t.progress,
            shape: (t.downRate > 0 || t.upRate > 0)
                ? ProgressM3EShape.wavy
                : ProgressM3EShape.flat,
            activeColor: rtStatusColor(scheme, t),
            trackColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(height: Insets.md),
          if (t.hasError) _KeyValue('Message', t.message),
          _KeyValue('Status', t.status.label),
          _KeyValue('Progress', '${(t.progress * 100).toStringAsFixed(1)}%'),
          _KeyValue(
            'Done',
            '${rtFmtBytes(t.completedBytes)} of ${rtFmtBytes(t.sizeBytes)}',
          ),
          _KeyValue('Remaining', rtFmtBytes(t.leftBytes)),
          _KeyValue('Down', rtFmtRate(t.downRate)),
          _KeyValue('Up', rtFmtRate(t.upRate)),
          _KeyValue('Uploaded', rtFmtBytes(t.uploadedTotal)),
          _KeyValue('Ratio', t.ratio.toStringAsFixed(3)),
          _KeyValue(
            'Peers',
            '${t.peersComplete} seeds, ${t.peersConnected} connected',
          ),
          if (rtFmtEta(t) != '-') _KeyValue('ETA', rtFmtEta(t)),
          _KeyValue('Priority', t.priorityLabel),
          // The three flags are shown as they are rather than folded away: on
          // rTorrent "stopped", "closed" and "inactive" are genuinely different
          // states, and the single status line above cannot say all three.
          _KeyValue('Started', t.state == 1 ? 'Yes' : 'No'),
          _KeyValue('Open', t.isOpen ? 'Yes' : 'No'),
          _KeyValue('Active', t.isActive ? 'Yes' : 'No'),
          if (t.label.isNotEmpty) _KeyValue('Label', t.label),
          _KeyValue('Directory', t.directory),
          _KeyValue('Hash', t.hash),
        ],
        _KeyValue('Files', '${detail.files.length}'),
        _KeyValue('Trackers', '${detail.trackers.length}'),
      ],
    );
  }
}

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({
    required this.instance,
    required this.hash,
    required this.detail,
  });

  final Instance instance;
  final String hash;
  final RtorrentDetail detail;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  bool _busy = false;

  Future<void> _setPriority(int index, int priority) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final RtorrentApi api =
          await ref.read(rtorrentApiProvider(widget.instance).future);
      await api.setFilePriority(widget.hash, index, priority);
      ref.invalidate(
        rtorrentDetailProvider(
          RtorrentDetailArgs(widget.instance, widget.hash),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RtorrentFile> files = widget.detail.files;
    if (files.isEmpty) {
      return const EmptyView(
        icon: Icons.insert_drive_file_outlined,
        title: 'No files',
        message: 'rTorrent has no file list for this torrent yet.',
      );
    }
    return ListView.builder(
      padding: Insets.page,
      itemCount: files.length,
      itemBuilder: (BuildContext context, int i) {
        final RtorrentFile f = files[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.displayName, maxLines: 2),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.xxs),
              LinearProgressIndicatorM3E(
                value: f.progress,
                // A file's own progress never animates, so it stays flat.
                shape: ProgressM3EShape.flat,
                size: LinearProgressM3ESize.s,
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                '${(f.progress * 100).toStringAsFixed(0)}% - '
                '${rtFmtBytes(f.sizeBytes)} - ${f.priorityLabel} priority',
              ),
            ],
          ),
          // Three states, not a checkbox: rTorrent distinguishes high from
          // normal, which a tick box cannot express.
          trailing: PopupMenuButton<int>(
            enabled: !_busy,
            icon: const Icon(Icons.more_vert),
            initialValue: f.priority,
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<int>>[
              PopupMenuItem<int>(value: 0, child: Text('Skip')),
              PopupMenuItem<int>(value: 1, child: Text('Normal')),
              PopupMenuItem<int>(value: 2, child: Text('High')),
            ],
            onSelected: (int p) => _setPriority(i, p),
          ),
        );
      },
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({required this.detail});

  final RtorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.peers.isEmpty) {
      return const EmptyView(
        icon: Icons.people_outline,
        title: 'No peers',
        message: 'Nothing is connected right now.',
      );
    }
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.peers.length,
      itemBuilder: (BuildContext context, int i) {
        final RtorrentPeer p = detail.peers[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            p.isEncrypted ? Icons.lock_outline : Icons.lock_open_outlined,
          ),
          title: Text(p.address),
          subtitle: Text(
            '${p.client.isEmpty ? 'Unknown client' : p.client} - '
            '${(p.progress * 100).toStringAsFixed(0)}%',
          ),
          trailing: Text(
            '${rtFmtRate(p.downRate)}\n${rtFmtRate(p.upRate)}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

class _TrackersTab extends StatelessWidget {
  const _TrackersTab({required this.detail});

  final RtorrentDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.trackers.isEmpty) {
      return const EmptyView(
        icon: Icons.dns_outlined,
        title: 'No trackers',
        message: 'This torrent announces to no trackers.',
      );
    }
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.trackers.length,
      itemBuilder: (BuildContext context, int i) {
        final RtorrentTracker tr = detail.trackers[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            tr.isEnabled ? Icons.check_circle_outline : Icons.block_outlined,
          ),
          title: Text(tr.url, maxLines: 2),
          // rTorrent exposes no per-tracker seed/peer counts, so the group
          // (its name for a tier) and the enabled flag are all there is.
          subtitle: Text(
            'Tier ${tr.group}${tr.isEnabled ? '' : ' - disabled'}',
          ),
        );
      },
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
