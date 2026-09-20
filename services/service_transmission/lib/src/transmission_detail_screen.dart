import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/transmission_detail.dart';
import 'models/transmission_torrent.dart';
import 'transmission_api.dart';
import 'transmission_dialogs.dart';
import 'transmission_files_tree.dart';
import 'transmission_format.dart';
import 'transmission_info_strings.dart';
import 'transmission_providers.dart';
import 'transmission_row_strings.dart';
import 'transmission_torrent_actions.dart';
import 'transmission_visuals.dart';

/// Everything the web UI's inspector shows for one torrent, and every action
/// its context menu offers, from the app bar.
///
/// The live scalars (status, speeds, progress) come from the list provider
/// that is already polling, so opening this screen does not start a second
/// poll of the same data.
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
    final bool labels = ref
            .watch(transmissionSessionProvider(instance))
            .value
            ?.supportsLabels ??
        false;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(torrent?.name ?? initialName, maxLines: 1),
          actions: <Widget>[
            if (torrent != null)
              PopupMenuButton<TransmissionTorrentAction>(
                tooltip: 'Torrent actions',
                itemBuilder: (BuildContext _) => transmissionActionMenuItems(
                  anyStopped: torrent.status.isStopped,
                  single: true,
                  labelsSupported: labels,
                ),
                onSelected: (TransmissionTorrentAction a) async {
                  await performTransmissionAction(
                    context,
                    ref,
                    instance,
                    a,
                    <TransmissionTorrent>[torrent],
                  );
                  // A removed torrent has no screen to stay on.
                  final bool removing = a == TransmissionTorrentAction.remove ||
                      a == TransmissionTorrentAction.trash;
                  if (!removing || !context.mounted) return;
                  final List<TransmissionTorrent> now =
                      ref.read(transmissionRawTorrentsProvider(instance)).value ??
                          const <TransmissionTorrent>[];
                  if (!now.any(
                    (TransmissionTorrent t) => t.hashString == hashString,
                  )) {
                    Navigator.of(context).pop();
                  }
                },
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Info'),
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
              _InfoTab(torrent: torrent, detail: d, labelsSupported: labels),
              _FilesTab(instance: instance, hashString: hashString, detail: d),
              _PeersTab(detail: d),
              _TrackersTab(detail: d),
            ],
          ),
        ),
      ),
    );
  }
}

const EdgeInsets _tabPadding =
    EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xl);

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.torrent,
    required this.detail,
    required this.labelsSupported,
  });

  final TransmissionTorrent? torrent;
  final TransmissionDetail detail;
  final bool labelsSupported;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final TransmissionTorrent? t = torrent;
    final TransmissionDetail d = detail;
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (t == null) {
      return const EmptyView(
        icon: Icons.hourglass_empty_rounded,
        title: 'Not in the list yet',
        message: 'The torrent list has not answered for this one.',
      );
    }
    final TransmissionVisual v = transmissionVisualFor(cs, t);
    final bool commentIsLink =
        d.comment.startsWith('http://') || d.comment.startsWith('https://');
    return ListView(
      padding: _tabPadding,
      children: <Widget>[
        // The one large figure on the screen: how far along it is, with the
        // state beside it and the bar under both.
        TransmissionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  TransmissionIconBlock(
                    icon: v.icon,
                    background: v.container,
                    foreground: v.onContainer,
                  ),
                  const SizedBox(width: Insets.md),
                  Text(
                    '${trPct(trBarValue(t))}%',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: v.color,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      children: <Widget>[
                        TransmissionPill(
                          label: t.stateString,
                          foreground: v.onContainer,
                          background: v.container,
                        ),
                        if (labelsSupported)
                          for (final String label in t.labels)
                            TransmissionPill(
                              label: label,
                              icon: Icons.label_outline,
                              foreground: cs.onSecondaryContainer,
                              background: cs.secondaryContainer,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicatorM3E(
                  value: trBarValue(t),
                  shape: (t.downloadRate > 0 || t.uploadRate > 0)
                      ? ProgressM3EShape.wavy
                      : ProgressM3EShape.flat,
                  activeColor: v.color,
                  trackColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  TransmissionSpeedPill(
                    icon: Icons.south,
                    label: trFmtRate(t.downloadRate),
                    color: cs.primary,
                    active: t.downloadRate > 0,
                  ),
                  const SizedBox(width: Insets.sm),
                  TransmissionSpeedPill(
                    icon: Icons.north,
                    label: trFmtRate(t.uploadRate),
                    color: cs.tertiary,
                    active: t.uploadRate > 0,
                  ),
                  const SizedBox(width: Insets.sm),
                  TransmissionPill(
                    icon: Icons.people_outline,
                    label: '${t.peersSendingToUs}/${t.peersConnected} peers',
                    foreground: cs.onSurfaceVariant,
                    background: cs.surfaceContainerHighest,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        TransmissionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const TransmissionPanelTitle('Activity'),
              _KeyValue('Have', trHaveLine(t, d)),
              _KeyValue('Availability', trAvailability(t, d)),
              _KeyValue('Uploaded', trUploadedLine(t, d)),
              _KeyValue('Downloaded', trDownloadedLine(d)),
              _KeyValue('State', t.stateString),
              _KeyValue('Running time', trRunningTime(t, d, now: now)),
              _KeyValue('Remaining', trRemaining(t)),
              _KeyValue('Last activity', trLastActivity(t, now: now)),
              if (t.errorString.isNotEmpty)
                _KeyValue('Error', t.errorString, color: cs.error),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        TransmissionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const TransmissionPanelTitle('Details'),
              _KeyValue('Size', trSizeLine(t, d)),
              _KeyValue('Location', t.downloadDir),
              _KeyValue('Hash', t.hashString, monospace: true),
              _KeyValue('Privacy', trPrivacy(d)),
              _KeyValue('Origin', trOrigin(d)),
              if (t.addedDate > 0)
                _KeyValue('Date added', trTimestamp(t.addedDate)),
              _KeyValue(
                'Comment',
                d.comment.isEmpty ? 'None' : d.comment,
                onTap: commentIsLink
                    ? () => launchUrl(
                          Uri.parse(d.comment),
                          mode: LaunchMode.externalApplication,
                        )
                    : null,
              ),
              if (labelsSupported)
                _KeyValue(
                  'Labels',
                  t.labels.isEmpty ? 'None' : t.labels.join(', '),
                ),
              _KeyValue(
                'Magnet link',
                d.magnetLink.isEmpty ? 'None' : d.magnetLink,
                monospace: true,
                trailing: d.magnetLink.isEmpty
                    ? null
                    : IconButton.filledTonal(
                        tooltip: 'Copy magnet link',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: d.magnetLink),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Magnet link copied'),
                              ),
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
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

  Future<void> _write(Future<void> Function(TransmissionApi api) action) async {
    setState(() => _busy = true);
    await runTransmissionAction(context, ref, widget.instance, action);
    ref.invalidate(
      transmissionDetailProvider((widget.instance, widget.hashString)),
    );
    if (mounted) setState(() => _busy = false);
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
    final List<int> all = <int>[for (int i = 0; i < files.length; i++) i];
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, 0),
          child: Row(
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _write(
                          (TransmissionApi api) => api.setFileWanted(
                            widget.hashString,
                            all,
                            wanted: true,
                          ),
                        ),
                icon: const Icon(Icons.select_all),
                label: const Text('Select all'),
              ),
              const SizedBox(width: Insets.sm),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _write(
                          (TransmissionApi api) => api.setFileWanted(
                            widget.hashString,
                            all,
                            wanted: false,
                          ),
                        ),
                icon: const Icon(Icons.deselect),
                label: const Text('Select none'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TransmissionFilesTree(
            root: buildTransmissionFileTree(files),
            busy: _busy,
            onWanted: (List<int> indices, bool wanted) => _write(
              (TransmissionApi api) => api.setFileWanted(
                widget.hashString,
                indices,
                wanted: wanted,
              ),
            ),
            onPriority: (List<int> indices, TransmissionPriority p) => _write(
              (TransmissionApi api) =>
                  api.setFilePriority(widget.hashString, indices, p),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({required this.detail});

  final TransmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    return ListView(
      padding: _tabPadding,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
          child: Row(
            children: <Widget>[
              Text(
                'Peers (${detail.peers.length})',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Peer flags',
                icon: const Icon(Icons.help_outline),
                onPressed: () => showTransmissionPeerFlagsSheet(context),
              ),
            ],
          ),
        ),
        if (detail.peers.isEmpty)
          const TransmissionPanel(
            child: Text('Nothing is connected right now.'),
          ),
        for (final TransmissionPeer p in detail.peers)
          TransmissionPanel(
            margin: const EdgeInsets.only(bottom: Insets.sm),
            child: Row(
              children: <Widget>[
                TransmissionIconBlock(
                  icon: p.isEncrypted
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  background: p.isEncrypted
                      ? cs.tertiaryContainer
                      : cs.surfaceContainerHighest,
                  foreground: p.isEncrypted
                      ? cs.onTertiaryContainer
                      : cs.onSurfaceVariant,
                  size: 40,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${p.address}:${p.port}',
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.clientName.isEmpty ? 'Unknown client' : p.clientName}'
                        ' - ${trPct(p.progress)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: Insets.sm),
                      Wrap(
                        spacing: Insets.xs,
                        runSpacing: Insets.xs,
                        children: <Widget>[
                          TransmissionSpeedPill(
                            icon: Icons.south,
                            label: trFmtRate(p.rateToClient),
                            color: cs.primary,
                            active: p.rateToClient > 0,
                          ),
                          TransmissionSpeedPill(
                            icon: Icons.north,
                            label: trFmtRate(p.rateToPeer),
                            color: cs.tertiary,
                            active: p.rateToPeer > 0,
                          ),
                          if (p.flagStr.isNotEmpty)
                            TransmissionPill(
                              label: p.flagStr,
                              monospace: true,
                              foreground: cs.onSecondaryContainer,
                              background: cs.secondaryContainer,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (detail.webseeds.isNotEmpty)
          TransmissionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const TransmissionPanelTitle('Web seeds'),
                for (final String url in detail.webseeds)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.public, size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            url,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrackersTab extends StatelessWidget {
  const _TrackersTab({required this.detail});

  final TransmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    if (detail.trackers.isEmpty) {
      return const EmptyView(
        icon: Icons.dns_outlined,
        title: 'No trackers',
        message: 'This torrent announces to no trackers.',
      );
    }
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<Widget> rows = <Widget>[];
    int? tier;
    for (final TransmissionTracker tr in detail.trackers) {
      if (tr.tier != tier) {
        tier = tr.tier;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xs,
              Insets.sm,
              Insets.xs,
              Insets.sm,
            ),
            // Transmission counts tiers from zero; the web UI shows them
            // from one.
            child: Text(
              'Tier ${tier + 1}',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        );
      }
      final (String announceLabel, String announceValue) = trLastAnnounce(tr);
      final (String scrapeLabel, String scrapeValue) = trLastScrape(tr);
      final bool ok = !tr.hasAnnounced || tr.lastAnnounceSucceeded;
      rows.add(
        TransmissionPanel(
          margin: const EdgeInsets.only(bottom: Insets.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TransmissionIconBlock(
                    icon: ok ? Icons.dns_rounded : Icons.error_outline_rounded,
                    background:
                        ok ? cs.secondaryContainer : cs.errorContainer,
                    foreground:
                        ok ? cs.onSecondaryContainer : cs.onErrorContainer,
                    size: 40,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tr.sitename.isNotEmpty
                              ? tr.sitename
                              : (tr.host.isEmpty ? tr.announce : tr.host),
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          tr.announce,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text(trAnnounceState(tr, now: now), style: text.bodyMedium),
              const SizedBox(height: Insets.xxs),
              Text(
                '$announceLabel: $announceValue',
                style: text.bodySmall?.copyWith(
                  color: ok ? cs.onSurfaceVariant : cs.error,
                ),
              ),
              Text(
                '$scrapeLabel: $scrapeValue',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: <Widget>[
                  TransmissionPill(
                    icon: Icons.upload_rounded,
                    label: '${trFmtPeerCount(tr.seederCount)} seeders',
                    foreground: cs.onTertiaryContainer,
                    background: cs.tertiaryContainer,
                  ),
                  TransmissionPill(
                    icon: Icons.download_rounded,
                    label: '${trFmtPeerCount(tr.leecherCount)} leechers',
                    foreground: cs.onPrimaryContainer,
                    background: cs.primaryContainer,
                  ),
                  TransmissionPill(
                    icon: Icons.check_circle_outline,
                    label: '${trFmtPeerCount(tr.downloadCount)} downloads',
                    foreground: cs.onSurfaceVariant,
                    background: cs.surfaceContainerHighest,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return ListView(padding: _tabPadding, children: rows);
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(
    this.label,
    this.value, {
    this.onTap,
    this.trailing,
    this.color,
    this.monospace = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onTap != null ? cs.primary : color,
                  fontFamily: monospace ? 'monospace' : null,
                  fontSize: monospace ? 12 : null,
                ),
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Insets.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}
