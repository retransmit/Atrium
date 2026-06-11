import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/qbit_detail.dart';
import 'models/qbit_torrent.dart';
import 'qbittorrent_client.dart';
import 'qbittorrent_home.dart' show fmtBytes;
import 'qbittorrent_providers.dart';

/// Detail view for a single torrent: Overview / Files / Trackers tabs.
///
/// Pushed from the torrent list. Files can be toggled between "download"
/// and "skip" (priority 1 ↔ 0) with a checkbox.
class TorrentDetailScreen extends ConsumerWidget {
  const TorrentDetailScreen({
    required this.instance,
    required this.torrent,
    super.key,
  });

  final Instance instance;
  final QbitTorrent torrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            torrent.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Files'),
              Tab(text: 'Trackers'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _OverviewTab(instance: instance, torrent: torrent),
            _FilesTab(instance: instance, hash: torrent.hash),
            _TrackersTab(instance: instance, hash: torrent.hash),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.instance, required this.torrent});

  final Instance instance;
  final QbitTorrent torrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<QbitTorrentProperties> props =
        ref.watch(qbitPropertiesProvider((instance, torrent.hash)));

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(qbitPropertiesProvider((instance, torrent.hash))),
      child: AsyncValueView<QbitTorrentProperties>(
        value: props,
        onRetry: () =>
            ref.invalidate(qbitPropertiesProvider((instance, torrent.hash))),
        data: (QbitTorrentProperties p) {
          final DateFormat fmt = DateFormat.yMMMd().add_Hm();
          String date(int secs) => secs <= 0
              ? '-'
              : fmt.format(
                  DateTime.fromMillisecondsSinceEpoch(secs * 1000),
                );
          return ListView(
            padding: Insets.page,
            children: <Widget>[
              _kv('State', torrent.state),
              _kv('Progress',
                  '${(torrent.progress * 100).toStringAsFixed(1)}%',),
              _kv('Size', fmtBytes(p.totalSize)),
              _kv('Downloaded', fmtBytes(p.totalDownloaded)),
              _kv('Uploaded', fmtBytes(p.totalUploaded)),
              _kv('Ratio', p.shareRatio.toStringAsFixed(2)),
              _kv('Speed',
                  '↓ ${fmtBytes(p.dlSpeed)}/s • ↑ ${fmtBytes(p.upSpeed)}/s',),
              _kv('Seeds', '${p.seeds} connected (${p.seedsTotal} total)'),
              _kv('Peers', '${p.peers} connected (${p.peersTotal} total)'),
              _kv('Pieces',
                  '${p.piecesHave}/${p.piecesNum} × ${fmtBytes(p.pieceSize)}',),
              _kv('Save path', p.savePath),
              _kv('Added', date(p.additionDate)),
              _kv('Completed', date(p.completionDate)),
              if (torrent.category.isNotEmpty)
                _kv('Category', torrent.category),
              if (p.comment.isNotEmpty) _kv('Comment', p.comment),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              Expanded(
                child: Text(value, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilesTab extends ConsumerWidget {
  const _FilesTab({required this.instance, required this.hash});

  final Instance instance;
  final String hash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QbitFile>> files =
        ref.watch(qbitFilesProvider((instance, hash)));

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(qbitFilesProvider((instance, hash))),
      child: AsyncValueView<List<QbitFile>>(
        value: files,
        onRetry: () => ref.invalidate(qbitFilesProvider((instance, hash))),
        data: (List<QbitFile> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.description_outlined,
              title: 'No files',
              message: 'Metadata not downloaded yet.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final QbitFile f = list[index];
              final bool wanted = f.priority != 0;
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  f.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${fmtBytes(f.size)} • '
                  '${(f.progress * 100).toStringAsFixed(0)}%',
                ),
                value: wanted,
                onChanged: (bool? v) async {
                  final QbittorrentClient client = await ref
                      .read(qbittorrentClientProvider(instance).future);
                  await client.setFilePriority(
                    hash,
                    <int>[f.index],
                    (v ?? false) ? 1 : 0,
                  );
                  ref.invalidate(qbitFilesProvider((instance, hash)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TrackersTab extends ConsumerWidget {
  const _TrackersTab({required this.instance, required this.hash});

  final Instance instance;
  final String hash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QbitTracker>> trackers =
        ref.watch(qbitTrackersProvider((instance, hash)));

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(qbitTrackersProvider((instance, hash))),
      child: AsyncValueView<List<QbitTracker>>(
        value: trackers,
        onRetry: () => ref.invalidate(qbitTrackersProvider((instance, hash))),
        data: (List<QbitTracker> list) {
          // Hide qBittorrent's synthetic DHT/PeX/LSD pseudo-trackers.
          final List<QbitTracker> real = list
              .where((QbitTracker t) => !t.url.startsWith('** '))
              .toList();
          if (real.isEmpty) {
            return const EmptyView(
              icon: Icons.dns_outlined,
              title: 'No trackers',
              message: 'This torrent has no HTTP trackers (DHT only).',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: real.length,
            itemBuilder: (BuildContext context, int index) {
              final QbitTracker t = real[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  switch (t.status) {
                    2 => Icons.check_circle_outline,
                    3 => Icons.sync,
                    4 => Icons.error_outline,
                    _ => Icons.radio_button_unchecked,
                  },
                  size: 20,
                ),
                title: Text(
                  t.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  <String>[
                    switch (t.status) {
                      0 => 'Disabled',
                      1 => 'Not contacted',
                      2 => 'Working',
                      3 => 'Updating',
                      4 => 'Not working',
                      _ => 'Unknown',
                    },
                    if (t.numSeeds >= 0) '${t.numSeeds} seeds',
                    if (t.numPeers >= 0) '${t.numPeers} peers',
                    if (t.msg.isNotEmpty) t.msg,
                  ].join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
