import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DelugeTorrent? torrent = ref
        .watch(delugeRawTorrentsProvider(instance))
        .value
        ?.where((DelugeTorrent t) => t.id == torrentId)
        .firstOrNull;
    final AsyncValue<DelugeTorrentDetail> detail =
        ref.watch(delugeTorrentDetailProvider((instance, torrentId)));

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DelugeTorrent? t = torrent;
    return ListView(
      padding: Insets.page,
      children: <Widget>[
        if (t != null) ...<Widget>[
          LinearProgressIndicatorM3E(
            value: t.progressFraction,
            shape: (t.downloadRate > 0 || t.uploadRate > 0)
                ? ProgressM3EShape.wavy
                : ProgressM3EShape.flat,
            activeColor: delugeStateColor(scheme, t.state),
            trackColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(height: Insets.md),
        ],
        _KeyValue('State', t?.state ?? 'Unknown'),
        if (t != null) ...<Widget>[
          _KeyValue('Progress', '${t.progress.toStringAsFixed(1)}%'),
          _KeyValue(
            'Done',
            '${delugeFmtBytes(t.totalDone)} of '
                '${delugeFmtBytes(t.totalWanted)}',
          ),
          _KeyValue('Down', delugeFmtRate(t.downloadRate)),
          _KeyValue('Up', delugeFmtRate(t.uploadRate)),
          _KeyValue('Uploaded', delugeFmtBytes(t.totalUploaded)),
          _KeyValue('Ratio', t.ratio.toStringAsFixed(3)),
          _KeyValue('Seeds', '${t.numSeeds} of ${t.totalSeeds}'),
          _KeyValue('Peers', '${t.numPeers} of ${t.totalPeers}'),
          if (t.eta > 0) _KeyValue('ETA', delugeFmtEta(t.eta)),
          _KeyValue('Queue', t.queue < 0 ? 'Not queued' : '${t.queue}'),
          if (t.label.isNotEmpty) _KeyValue('Label', t.label),
          _KeyValue('Tracker', t.trackerHost),
          _KeyValue('Save path', t.savePath),
          if (t.timeAdded > 0)
            _KeyValue(
              'Added',
              DateTime.fromMillisecondsSinceEpoch(t.timeAdded * 1000)
                  .toLocal()
                  .toString()
                  .split('.')
                  .first,
            ),
        ],
        _KeyValue('Total size', delugeFmtBytes(detail.totalSize)),
        _KeyValue('Files', '${detail.numFiles}'),
        _KeyValue('Private', detail.private ? 'Yes' : 'No'),
        _KeyValue(
          'Down limit',
          delugeFmtLimitKib(detail.maxDownloadKib),
        ),
        _KeyValue('Up limit', delugeFmtLimitKib(detail.maxUploadKib)),
        if (detail.comment.isNotEmpty) _KeyValue('Comment', detail.comment),
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
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.files.length,
      itemBuilder: (BuildContext context, int i) {
        final DelugeFile f = detail.files[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.displayName, maxLines: 2),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.xxs),
              LinearProgressIndicatorM3E(
                value: f.progress.clamp(0, 1).toDouble(),
                // A file's own progress never animates, so it stays flat.
                shape: ProgressM3EShape.flat,
                size: LinearProgressM3ESize.s,
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                '${(f.progress * 100).toStringAsFixed(0)}% - '
                '${delugeFmtBytes(f.size)} - '
                '${delugeFilePriorityLabel(f.priority)}',
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
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.trackers.length,
      itemBuilder: (BuildContext context, int i) {
        final DelugeTracker tr = detail.trackers[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            tr.verified ? Icons.verified_outlined : Icons.dns_outlined,
          ),
          title: Text(tr.url, maxLines: 2),
          subtitle: Text(
            tr.message.isEmpty ? 'Tier ${tr.tier}' : '${tr.message} - tier ${tr.tier}',
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
    return ListView.builder(
      padding: Insets.page,
      itemCount: detail.peers.length,
      itemBuilder: (BuildContext context, int i) {
        final DelugePeer p = detail.peers[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(p.seed ? Icons.upload_outlined : Icons.download_outlined),
          title: Text(p.ip),
          subtitle: Text(
            '${p.client.isEmpty ? 'Unknown client' : p.client} - '
            '${(p.progress * 100).toStringAsFixed(0)}%',
          ),
          trailing: Text(
            '${delugeFmtRate(p.downSpeed)}\n${delugeFmtRate(p.upSpeed)}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
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
            width: 110,
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
