import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_detail.dart';
import 'models/transmission_torrent.dart';
import 'transmission_api.dart';
import 'transmission_format.dart';
import 'transmission_providers.dart';

/// Files, peers and trackers for one torrent.
///
/// The live scalars (status, speeds, progress) come from the list provider that
/// is already polling, so opening this screen does not start a second poll of
/// the same data.
class TransmissionDetailScreen extends ConsumerWidget {
  const TransmissionDetailScreen({
    required this.instance,
    required this.hashString,
    required this.initialName,
    super.key,
  });

  final Instance instance;

  /// Infohash, not the numeric id: Transmission reassigns ids when the daemon
  /// restarts, which would otherwise point this screen at another torrent.
  final String hashString;

  /// Shown until the list provider resolves, so the title is never empty.
  final String initialName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransmissionTorrent? torrent = ref
        .watch(transmissionRawTorrentsProvider(instance))
        .value
        ?.where((TransmissionTorrent t) => t.hashString == hashString)
        .firstOrNull;
    final AsyncValue<TransmissionDetail> detail =
        ref.watch(transmissionDetailProvider((instance, hashString)));

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
        body: AsyncValueView<TransmissionDetail>(
          value: detail,
          onRetry: () => ref.invalidate(
            transmissionDetailProvider((instance, hashString)),
          ),
          data: (TransmissionDetail d) => TabBarView(
            children: <Widget>[
              _OverviewTab(torrent: torrent, detail: d),
              _FilesTab(
                instance: instance,
                hashString: hashString,
                detail: d,
              ),
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

  final TransmissionTorrent? torrent;
  final TransmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TransmissionTorrent? t = torrent;
    return ListView(
      padding: Insets.page,
      children: <Widget>[
        if (t != null) ...<Widget>[
          LinearProgressIndicator(
            value: t.percentDone.clamp(0, 1),
            color: trStatusColor(scheme, t),
          ),
          const SizedBox(height: Insets.md),
          if (t.hasError)
            _KeyValue('Error', t.errorString),
          _KeyValue('Status', t.statusLabel),
          _KeyValue('Progress', '${(t.percentDone * 100).toStringAsFixed(1)}%'),
          _KeyValue(
            'Done',
            '${trFmtBytes(t.doneBytes)} of ${trFmtBytes(t.sizeWhenDone)}',
          ),
          if (t.totalSize != t.sizeWhenDone)
            _KeyValue('Total size', trFmtBytes(t.totalSize)),
          _KeyValue('Down', trFmtRate(t.downloadRate)),
          _KeyValue('Up', trFmtRate(t.uploadRate)),
          _KeyValue('Uploaded', trFmtBytes(t.uploadedEver)),
          _KeyValue('Ratio', t.ratio.toStringAsFixed(3)),
          _KeyValue(
            'Peers',
            '${t.peersSendingToUs} sending, ${t.peersGettingFromUs} '
                'receiving, ${t.peersConnected} connected',
          ),
          if (t.hasEta) _KeyValue('ETA', trFmtEta(t.eta)),
          _KeyValue(
            'Queue',
            t.queuePosition < 0 ? 'Not queued' : '${t.queuePosition}',
          ),
          if (t.labels.isNotEmpty) _KeyValue('Labels', t.labels.join(', ')),
          _KeyValue('Download folder', t.downloadDir),
          if (t.addedDate > 0)
            _KeyValue(
              'Added',
              DateTime.fromMillisecondsSinceEpoch(t.addedDate * 1000)
                  .toLocal()
                  .toString()
                  .split('.')
                  .first,
            ),
          _KeyValue('Hash', t.hashString),
        ],
        _KeyValue('Files', '${detail.files.length}'),
        _KeyValue('Private', detail.isPrivate ? 'Yes' : 'No'),
        if (detail.pieceCount > 0)
          _KeyValue(
            'Pieces',
            '${detail.pieceCount} x ${trFmtBytes(detail.pieceSize)}',
          ),
        if (detail.creator.isNotEmpty)
          _KeyValue('Created by', detail.creator),
        if (detail.comment.isNotEmpty) _KeyValue('Comment', detail.comment),
      ],
    );
  }
}

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({
    required this.instance,
    required this.hashString,
    required this.detail,
  });

  final Instance instance;
  final String hashString;
  final TransmissionDetail detail;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  bool _busy = false;

  Future<void> _setWanted(int index, bool wanted) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final TransmissionApi api =
          await ref.read(transmissionApiProvider(widget.instance).future);
      await api.setFileWanted(
        widget.hashString,
        <int>[index],
        wanted: wanted,
      );
      ref.invalidate(
        transmissionDetailProvider((widget.instance, widget.hashString)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TransmissionFile> files = widget.detail.files;
    if (files.isEmpty) {
      return const EmptyView(
        icon: Icons.insert_drive_file_outlined,
        title: 'No files',
        message: 'Transmission has no file list for this torrent yet.',
      );
    }
    return ListView.builder(
      padding: Insets.page,
      itemCount: files.length,
      itemBuilder: (BuildContext context, int i) {
        final TransmissionFile f = files[i];
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: f.wanted,
          // Unchecking tells Transmission to skip the file entirely.
          onChanged: _busy
              ? null
              : (bool? v) => _setWanted(i, v ?? false),
          title: Text(f.displayName, maxLines: 2),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.xxs),
              LinearProgressIndicator(value: f.progress),
              const SizedBox(height: Insets.xxs),
              Text(
                '${(f.progress * 100).toStringAsFixed(0)}% - '
                '${trFmtBytes(f.length)} - ${f.priorityLabel} priority',
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

  final TransmissionDetail detail;

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
        final TransmissionPeer p = detail.peers[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            p.isEncrypted ? Icons.lock_outline : Icons.lock_open_outlined,
          ),
          title: Text(p.address),
          subtitle: Text(
            '${p.clientName.isEmpty ? 'Unknown client' : p.clientName} - '
            '${(p.progress * 100).toStringAsFixed(0)}%',
          ),
          trailing: Text(
            '${trFmtRate(p.rateToClient)}\n${trFmtRate(p.rateToPeer)}',
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

  final TransmissionDetail detail;

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
        final TransmissionTracker tr = detail.trackers[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            tr.lastAnnounceSucceeded
                ? Icons.check_circle_outline
                : Icons.dns_outlined,
          ),
          title: Text(tr.host.isEmpty ? tr.announce : tr.host, maxLines: 2),
          subtitle: Text(
            // Counts are -1 until an announce has actually landed.
            'Tier ${tr.tier} - seeds ${trFmtPeerCount(tr.seederCount)}, '
            'peers ${trFmtPeerCount(tr.leecherCount)}'
            '${tr.lastAnnounceResult.isEmpty ? '' : ' - '
                '${tr.lastAnnounceResult}'}',
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
