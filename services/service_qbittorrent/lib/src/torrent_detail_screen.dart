import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/qbit_detail.dart';
import 'models/qbit_torrent.dart';
import 'qbittorrent_client.dart';
import 'qbittorrent_home.dart' show fmtBytes, friendlyState;
import 'qbittorrent_providers.dart';

/// Detail view for a single torrent: Overview / Files / Trackers / Peers tabs.
///
/// Pushed from the torrent list. Files can be toggled between "download"
/// and "skip" (priority 1 - 0) with a checkbox.
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            torrent.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: <Widget>[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String value) async {
                final QbittorrentClient client = await ref.read(qbittorrentClientProvider(instance).future);
                switch (value) {
                  case 'pause':
                    await client.pause(<String>[torrent.hash]);
                    ref.invalidate(qbitRawTorrentsProvider(instance));
                  case 'resume':
                    await client.resume(<String>[torrent.hash]);
                    ref.invalidate(qbitRawTorrentsProvider(instance));
                  case 'forcestart':
                    await client.setForceStart(<String>[torrent.hash], value: true);
                    ref.invalidate(qbitRawTorrentsProvider(instance));
                  case 'copy_magnet':
                    final String magnet = torrent.magnetUri.isNotEmpty 
                        ? torrent.magnetUri 
                        : 'magnet:?xt=urn:btih:${torrent.hash}&dn=${Uri.encodeComponent(torrent.name)}';
                    await Clipboard.setData(ClipboardData(text: magnet));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Magnet link copied')));
                    }
                  case 'copy_hash':
                    await Clipboard.setData(ClipboardData(text: torrent.hash));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Torrent hash copied')));
                    }
                  case 'recheck':
                    await client.recheck(<String>[torrent.hash]);
                    ref.invalidate(qbitRawTorrentsProvider(instance));
                  case 'reannounce':
                    await client.reannounce(<String>[torrent.hash]);
                    ref.invalidate(qbitRawTorrentsProvider(instance));
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'pause', child: Text('Pause')),
                const PopupMenuItem<String>(value: 'resume', child: Text('Resume')),
                const PopupMenuItem<String>(value: 'forcestart', child: Text('Force Start')),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'copy_magnet', child: Text('Copy Magnet Link')),
                const PopupMenuItem<String>(value: 'copy_hash', child: Text('Copy Hash')),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'recheck', child: Text('Force Recheck')),
                const PopupMenuItem<String>(value: 'reannounce', child: Text('Force Reannounce')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Files'),
              Tab(text: 'Trackers'),
              Tab(text: 'Peers'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _OverviewTab(instance: instance, torrent: torrent),
            _FilesTab(instance: instance, hash: torrent.hash),
            _TrackersTab(instance: instance, hash: torrent.hash),
            _PeersTab(instance: instance, hash: torrent.hash),
          ],
        ),
      ),
    );
  }
}

/// State -> accent color, matching the torrent list's color coding.
Color _accent(String state, ColorScheme cs) {
  switch (state) {
    case 'downloading':
    case 'forcedDL':
    case 'metaDL':
      return cs.primary;
    case 'uploading':
    case 'forcedUP':
    case 'stalledUP':
      return cs.tertiary;
    case 'pausedUP':
    case 'stoppedUP':
    case 'queuedDL':
    case 'queuedUP':
      return cs.secondary;
    case 'error':
    case 'missingFiles':
      return cs.error;
    default:
      return cs.outline;
  }
}

IconData _stateIcon(String state) {
  switch (state) {
    case 'downloading':
    case 'forcedDL':
    case 'metaDL':
      return Icons.download_rounded;
    case 'uploading':
    case 'forcedUP':
    case 'stalledUP':
      return Icons.upload_rounded;
    case 'pausedUP':
    case 'stoppedUP':
      return Icons.check_rounded;
    case 'queuedDL':
    case 'queuedUP':
      return Icons.schedule_rounded;
    case 'checkingDL':
    case 'checkingUP':
    case 'checkingResumeData':
      return Icons.sync_rounded;
    case 'error':
    case 'missingFiles':
      return Icons.error_outline_rounded;
    default:
      return state.contains('paused') || state.contains('stopped')
          ? Icons.pause_rounded
          : Icons.hourglass_empty_rounded;
  }
}

String _fmtEta(int eta) {
  if (eta >= 8640000 || eta < 0) return '∞';
  final Duration d = Duration(seconds: eta);
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.instance, required this.torrent});

  final Instance instance;
  final QbitTorrent torrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<QbitTorrentProperties> props =
        ref.watch(qbitPropertiesProvider((instance, torrent.hash)));
    final Color accent = _accent(torrent.state, cs);
    final double progress = torrent.progress.clamp(0, 1).toDouble();

    return M3RefreshIndicator(
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
              : fmt.format(DateTime.fromMillisecondsSinceEpoch(secs * 1000));
          return ListView(
            padding: Insets.page,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_stateIcon(torrent.state), color: accent),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                friendlyState(torrent.state),
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtBytes(p.totalSize)} • ratio ${p.shareRatio.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
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
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              color: accent,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    Row(
                      children: <Widget>[
                        _MiniPill(
                          icon: Icons.south,
                          label: '${fmtBytes(p.dlSpeed)}/s',
                          color: cs.primary,
                        ),
                        const SizedBox(width: Insets.sm),
                        _MiniPill(
                          icon: Icons.north,
                          label: '${fmtBytes(p.upSpeed)}/s',
                          color: cs.tertiary,
                        ),
                        const Spacer(),
                        if (progress < 1.0) ...<Widget>[
                          Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            _fmtEta(torrent.eta),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Insets.lg),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.pause, size: 18),
                          label: const Text('Pause'),
                          onPressed: () async {
                            final QbittorrentClient client = await ref.read(qbittorrentClientProvider(instance).future);
                            await client.pause(<String>[torrent.hash]);
                            ref.invalidate(qbitRawTorrentsProvider(instance));
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Resume'),
                          onPressed: () async {
                            final QbittorrentClient client = await ref.read(qbittorrentClientProvider(instance).future);
                            await client.resume(<String>[torrent.hash]);
                            ref.invalidate(qbitRawTorrentsProvider(instance));
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.fast_forward, size: 18),
                          label: const Text('Force Start'),
                          onPressed: () async {
                            final QbittorrentClient client = await ref.read(qbittorrentClientProvider(instance).future);
                            await client.setForceStart(<String>[torrent.hash], value: true);
                            ref.invalidate(qbitRawTorrentsProvider(instance));
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.link, size: 18),
                          label: const Text('Copy Magnet'),
                          onPressed: () async {
                            final String magnet = torrent.magnetUri.isNotEmpty 
                                ? torrent.magnetUri 
                                : 'magnet:?xt=urn:btih:${torrent.hash}&dn=${Uri.encodeComponent(torrent.name)}';
                            await Clipboard.setData(ClipboardData(text: magnet));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Magnet link copied')));
                            }
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.tag, size: 18),
                          label: const Text('Copy Hash'),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: torrent.hash));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Torrent hash copied')));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              _SectionCard(
                title: 'Transfer',
                rows: <(String, String)>[
                  ('Downloaded', fmtBytes(p.totalDownloaded)),
                  ('Uploaded', fmtBytes(p.totalUploaded)),
                  ('Ratio', p.shareRatio.toStringAsFixed(2)),
                  ('Seeds', '${p.seeds} connected (${p.seedsTotal} total)'),
                  ('Peers', '${p.peers} connected (${p.peersTotal} total)'),
                  (
                    'Pieces',
                    '${p.piecesHave}/${p.piecesNum} × ${fmtBytes(p.pieceSize)}',
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              _SectionCard(
                title: 'Info',
                rows: <(String, String)>[
                  ('Save path', p.savePath),
                  ('Added', date(p.additionDate)),
                  ('Completed', date(p.completionDate)),
                  if (torrent.category.isNotEmpty) ('Category', torrent.category),
                  if (p.comment.isNotEmpty) ('Comment', p.comment),
                ],
              ),
              const SizedBox(height: Insets.xl),
            ],
          );
        },
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                          ?.copyWith(color: cs.onSurfaceVariant),
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

class _BuilderNode {
  _BuilderNode(this.name, this.fullPath, this.depth, this.isFile);
  final String name;
  final String fullPath;
  final int depth;
  final bool isFile;
  int size = 0;
  double downloaded = 0.0;
  final List<int> fileIndices = <int>[];
  bool isWanted = false;
  final Map<String, _BuilderNode> children = <String, _BuilderNode>{};

  _FileNode toFileNode(bool isCollapsed) {
    return _FileNode(
      name: name,
      fullPath: fullPath,
      isFile: isFile,
      depth: depth,
      size: size,
      downloaded: downloaded,
      progress: size == 0 ? (isWanted ? 0.0 : 1.0) : downloaded / size,
      fileIndices: fileIndices,
      isWanted: isWanted,
      isCollapsed: isCollapsed,
    );
  }
}

class _FileNode {
  _FileNode({
    required this.name,
    required this.fullPath,
    required this.isFile,
    required this.depth,
    required this.size,
    required this.downloaded,
    required this.progress,
    required this.fileIndices,
    required this.isWanted,
    required this.isCollapsed,
  });

  final String name;
  final String fullPath;
  final bool isFile;
  final int depth;
  final int size;
  final double downloaded;
  final double progress;
  final List<int> fileIndices;
  final bool isWanted;
  final bool isCollapsed;
}

List<_FileNode> _buildFileTree(List<QbitFile> files, Set<String> collapsedPaths) {
  final _BuilderNode root = _BuilderNode('', '', -1, false);

  for (final QbitFile f in files) {
    final List<String> parts = f.name.split('/');
    _BuilderNode current = root;
    String currentPath = '';
    for (int i = 0; i < parts.length; i++) {
      final String part = parts[i];
      if (part.isEmpty) continue;
      currentPath = currentPath.isEmpty ? part : '$currentPath/$part';

      final bool isFile = i == parts.length - 1;
      current = current.children.putIfAbsent(part, () => _BuilderNode(part, currentPath, i, isFile));

      current.size += f.size;
      current.downloaded += f.size * f.progress;
      current.fileIndices.add(f.index);
      if (f.priority > 0) {
        current.isWanted = true;
      }
    }
  }

  final List<_FileNode> flattened = <_FileNode>[];
  void traverse(_BuilderNode node) {
    if (node.depth >= 0) {
      flattened.add(node.toFileNode(collapsedPaths.contains(node.fullPath)));
    }
    if (!node.isFile && collapsedPaths.contains(node.fullPath)) {
      return;
    }
    for (final _BuilderNode child in node.children.values) {
      traverse(child);
    }
  }

  traverse(root);
  return flattened;
}

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({required this.instance, required this.hash});

  final Instance instance;
  final String hash;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> with AutomaticKeepAliveClientMixin {
  final Set<String> _collapsedPaths = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<QbitFile>> files =
        ref.watch(qbitFilesProvider((widget.instance, widget.hash)));

    return M3RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(qbitFilesProvider((widget.instance, widget.hash))),
      child: AsyncValueView<List<QbitFile>>(
        value: files,
        onRetry: () => ref.invalidate(qbitFilesProvider((widget.instance, widget.hash))),
        data: (List<QbitFile> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.description_outlined,
              title: 'No files',
              message: 'Metadata not downloaded yet.',
            );
          }
          final List<_FileNode> nodes = _buildFileTree(list, _collapsedPaths);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            itemCount: nodes.length,
            itemBuilder: (BuildContext context, int index) {
              final _FileNode f = nodes[index];
              final Color barColor = f.isWanted ? cs.primary : cs.outline;
              return InkWell(
                onTap: f.isFile ? null : () {
                  setState(() {
                    if (f.isCollapsed) {
                      _collapsedPaths.remove(f.fullPath);
                    } else {
                      _collapsedPaths.add(f.fullPath);
                    }
                  });
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Insets.md + f.depth * 16.0,
                    4,
                    Insets.sm,
                    4,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (!f.isFile)
                        Icon(
                          f.isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 4),
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          f.isFile
                              ? Icons.insert_drive_file_outlined
                              : (f.isCollapsed ? Icons.folder_outlined : Icons.folder_open_outlined),
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              f.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: f.progress.clamp(0, 1).toDouble(),
                                minHeight: 5,
                                color: barColor,
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${fmtBytes(f.size)} • ${(f.progress * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Checkbox(
                        value: f.isWanted,
                        onChanged: (bool? v) async {
                          final QbittorrentClient client = await ref
                              .read(qbittorrentClientProvider(widget.instance).future);
                          await client.setFilePriority(
                            widget.hash,
                            f.fileIndices,
                            (v ?? false) ? 1 : 0,
                          );
                          ref.invalidate(qbitFilesProvider((widget.instance, widget.hash)));
                        },
                      ),
                    ],
                  ),
                ),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<QbitTracker>> trackers =
        ref.watch(qbitTrackersProvider((instance, hash)));

    return M3RefreshIndicator(
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
          return ListView.separated(
            padding: Insets.page,
            itemCount: real.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) {
              final QbitTracker t = real[index];
              final (Color c, IconData ic, String label) = switch (t.status) {
                2 => (cs.tertiary, Icons.check_circle, 'Working'),
                3 => (cs.primary, Icons.sync, 'Updating'),
                4 => (cs.error, Icons.error_outline, 'Not working'),
                1 => (cs.outline, Icons.radio_button_unchecked, 'Not contacted'),
                0 => (cs.outline, Icons.block, 'Disabled'),
                _ => (cs.outline, Icons.help_outline, 'Unknown'),
              };
              return Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(ic, size: 18, color: c),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            t.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            <String>[
                              label,
                              if (t.numSeeds >= 0) '${t.numSeeds} seeds',
                              if (t.numPeers >= 0) '${t.numPeers} peers',
                              if (t.msg.isNotEmpty) t.msg,
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _getCountryFlag(String countryCode) {
  if (countryCode.isEmpty || countryCode.length != 2) return '❓';
  const int offset = 127397;
  final int c1 = countryCode.toUpperCase().codeUnitAt(0) + offset;
  final int c2 = countryCode.toUpperCase().codeUnitAt(1) + offset;
  return String.fromCharCode(c1) + String.fromCharCode(c2);
}

class _PeersTab extends ConsumerWidget {
  const _PeersTab({required this.instance, required this.hash});

  final Instance instance;
  final String hash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<QbitPeer>> peers =
        ref.watch(qbitPeersProvider((instance, hash)));

    return M3RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(qbitPeersProvider((instance, hash))),
      child: AsyncValueView<List<QbitPeer>>(
        value: peers,
        onRetry: () => ref.invalidate(qbitPeersProvider((instance, hash))),
        data: (List<QbitPeer> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.people_outline,
              title: 'No peers',
              message: 'Not connected to any peers.',
            );
          }
          return ListView.separated(
            padding: Insets.page,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) {
              final QbitPeer p = list[index];
              return Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          _getCountryFlag(p.countryCode),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            p.client.isEmpty ? 'Unknown client' : p.client,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Text(
                          p.ip,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: p.progress.clamp(0, 1).toDouble(),
                        minHeight: 5,
                        color: cs.primary,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: <Widget>[
                        _MiniPill(
                          icon: Icons.south,
                          label: '${fmtBytes(p.dlSpeed)}/s',
                          color: cs.primary,
                        ),
                        const SizedBox(width: Insets.sm),
                        _MiniPill(
                          icon: Icons.north,
                          label: '${fmtBytes(p.upSpeed)}/s',
                          color: cs.tertiary,
                        ),
                        const Spacer(),
                        Text(
                          '${(p.progress * 100).toStringAsFixed(0)}%'
                          '${p.connection.isNotEmpty ? ' • ${p.connection}' : ''}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
