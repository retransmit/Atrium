import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_torrent_sheet.dart';
import 'models/qbit_torrent.dart';
import 'models/qbit_transfer_info.dart';
import 'qbittorrent_client.dart';
import 'qbittorrent_providers.dart';
import 'torrent_detail_screen.dart';
import 'package:m3_expressive/m3_expressive.dart';

/// qBittorrent's per-instance UI: a global up/down header (with pause-all /
/// resume-all), a torrent list with progress / speeds / per-item actions, and
/// a FAB to add new torrents from a magnet, URL, or `.torrent` file.
class QbittorrentHome extends ConsumerWidget {
  const QbittorrentHome({required this.instance, super.key});

  final Instance instance;

  void _refresh(WidgetRef ref) {
    ref.invalidate(qbitRawTorrentsProvider(instance));
    ref.invalidate(qbitTransferProvider(instance));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QbitTorrent>> torrents =
        ref.watch(qbitTorrentsProvider(instance));

    return Scaffold(
      bottomNavigationBar: _BottomControlBar(instance: instance),
      body: Column(
        children: <Widget>[
          Expanded(
            child: M3RefreshIndicator(
              onRefresh: () async => _refresh(ref),
              child: AsyncValueView<List<QbitTorrent>>(
                value: torrents,
                onRetry: () =>
                    ref.invalidate(qbitRawTorrentsProvider(instance)),
                data: (List<QbitTorrent> list) {
                  if (list.isEmpty) {
                    return const EmptyView(
                      icon: Icons.cloud_download_outlined,
                      title: 'No torrents',
                      message: 'Tap + to add a magnet, URL, or .torrent file.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: list.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _TorrentTile(instance: instance, torrent: list[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _ExpandableFab(
        builder: (BuildContext context, VoidCallback close) => <Widget>[
          FloatingActionButton(
            tooltip: 'Magnet link',
            onPressed: () async {
              close();
              final bool added = await AddTorrentSheet.show(
                context,
                instance,
              );
              if (added) {
                _refresh(ref);
              }
            },
            child: const Icon(Icons.link),
          ),
          FloatingActionButton(
            tooltip: 'Torrent file',
            onPressed: () async {
              close();
              final bool added = await AddTorrentSheet.show(
                context,
                instance,
                initialMode: AddTorrentMode.file,
              );
              if (added) {
                _refresh(ref);
              }
            },
            child: const Icon(Icons.attach_file),
          ),
        ],
      ),
    );
  }
}

class _BottomControlBar extends ConsumerStatefulWidget {
  const _BottomControlBar({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_BottomControlBar> createState() => _BottomControlBarState();
}

class _BottomControlBarState extends ConsumerState<_BottomControlBar> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _setAll(WidgetRef ref, {required bool paused}) async {
    final QbittorrentClient client =
        await ref.read(qbittorrentClientProvider(widget.instance).future);
    await client.setAllPaused(paused: paused);
    ref.invalidate(qbitRawTorrentsProvider(widget.instance));
    ref.invalidate(qbitTransferProvider(widget.instance));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QbitTransferInfo? info =
        ref.watch(qbitTransferProvider(widget.instance)).value;
    final ThemeData theme = Theme.of(context);
    final Color contrastColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return BottomAppBar(
      height: 56,
      color: Color.alphaBlend(contrastColor, theme.colorScheme.surface),
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: _isSearching
          ? Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      ref
                          .read(qbitSearchProvider(widget.instance).notifier)
                          .state = '';
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Filter torrents...',
                      border: InputBorder.none,
                    ),
                    onChanged: (String val) {
                      ref
                          .read(qbitSearchProvider(widget.instance).notifier)
                          .state = val;
                      // setState to show/hide the clear button
                      setState(() {});
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref
                          .read(qbitSearchProvider(widget.instance).notifier)
                          .state = '';
                      setState(() {});
                    },
                  ),
              ],
            )
          : Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Search torrents',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                const SizedBox(width: Insets.xs),
                _SpeedPill(
                  icon: Icons.south,
                  label: '${fmtBytes(info?.dlSpeed ?? 0)}/s',
                  color: theme.colorScheme.primary,
                  active: (info?.dlSpeed ?? 0) > 0,
                ),
                const SizedBox(width: Insets.sm),
                _SpeedPill(
                  icon: Icons.north,
                  label: '${fmtBytes(info?.upSpeed ?? 0)}/s',
                  color: theme.colorScheme.tertiary,
                  active: (info?.upSpeed ?? 0) > 0,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Resume all',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _setAll(ref, paused: false),
                ),
                IconButton(
                  tooltip: 'Pause all',
                  icon: const Icon(Icons.stop),
                  onPressed: () => _setAll(ref, paused: true),
                ),
              ],
            ),
    );
  }
}

class QbittorrentAppBarActions extends ConsumerWidget {
  const QbittorrentAppBarActions({required this.instance, super.key});

  final Instance instance;

  Future<void> _run(
      WidgetRef ref, Future<void> Function(QbittorrentClient) action) async {
    final QbittorrentClient client =
        await ref.read(qbittorrentClientProvider(instance).future);
    await action(client);
    ref.invalidate(qbitRawTorrentsProvider(instance));
    ref.invalidate(qbitSelectionProvider(instance));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Set<String> selectedHashes) async {
    bool deleteFiles = false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Delete select Torrents?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                  'Are you sure to delete the selected ${selectedHashes.length} torrents?'),
              const SizedBox(height: Insets.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Delete files'),
                value: deleteFiles,
                onChanged: (bool? v) =>
                    setState(() => deleteFiles = v ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('CONFIRM'),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) {
      final QbittorrentClient client =
          await ref.read(qbittorrentClientProvider(instance).future);
      await client.delete(selectedHashes.toList(), deleteFiles: deleteFiles);
      ref.invalidate(qbitSelectionProvider(instance));
      ref.invalidate(qbitRawTorrentsProvider(instance));
    }
  }

  Future<void> _editCategory(
      BuildContext context, WidgetRef ref, Set<String> selectedHashes) async {
    final List<String> cats =
        await ref.read(qbitCategoriesProvider(instance).future);
    if (!context.mounted) return;
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Set category'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('None'),
          ),
          for (final String c in cats)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(c),
              child: Text(c),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await _run(
          ref,
          (QbittorrentClient c) =>
              c.setCategory(selectedHashes.toList(), chosen));
    }
  }

  Future<void> _editTags(
      BuildContext context, WidgetRef ref, Set<String> selectedHashes) async {
    final TextEditingController ctrl = TextEditingController();
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Set tags'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'tag1, tag2'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      await _run(ref,
          (QbittorrentClient c) => c.addTags(selectedHashes.toList(), chosen));
    }
  }

  Future<void> _editSavePath(
      BuildContext context, WidgetRef ref, Set<String> selectedHashes) async {
    final TextEditingController ctrl = TextEditingController();
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Set save path'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '/downloads/new_path'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      await _run(
          ref,
          (QbittorrentClient c) =>
              c.setLocation(selectedHashes.toList(), chosen));
    }
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, Set<String> selectedHashes) async {
    final TextEditingController ctrl = TextEditingController();
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      await _run(
          ref, (QbittorrentClient c) => c.rename(selectedHashes.first, chosen));
    }
  }

  void _showSortMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final QbitSortConfig config = ref.watch(qbitSortProvider(instance));
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              children: <Widget>[
                ListTile(
                  leading: Icon(config.ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward),
                  title: Text(config.ascending ? 'Ascending' : 'Descending'),
                  onTap: () {
                    ref.read(qbitSortProvider(instance).notifier).state =
                        config.copyWith(ascending: !config.ascending);
                  },
                ),
                const Divider(),
                for (final QbitSortField field in QbitSortField.values)
                  ListTile(
                    title: Text(field.displayName),
                    trailing:
                        config.field == field ? const Icon(Icons.check) : null,
                    onTap: () {
                      ref.read(qbitSortProvider(instance).notifier).state =
                          config.copyWith(field: field);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> selectedHashes =
        ref.watch(qbitSelectionProvider(instance));

    if (selectedHashes.isEmpty) {
      return IconButton(
        tooltip: 'Sort Torrents',
        icon: const Icon(Icons.sort),
        onPressed: () => _showSortMenu(context, ref),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text('${selectedHashes.length} Selected'),
          ),
        ),
        IconButton(
          tooltip: 'Clear Selection',
          icon: const Icon(Icons.close),
          onPressed: () => ref.invalidate(qbitSelectionProvider(instance)),
        ),
        IconButton(
          tooltip: 'Delete Selected',
          icon: const Icon(Icons.delete),
          onPressed: () => _confirmDelete(context, ref, selectedHashes),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) async {
            final List<String> hashes = selectedHashes.toList();
            switch (value) {
              case 'pause':
                await _run(ref, (QbittorrentClient c) => c.pause(hashes));
              case 'resume':
                await _run(ref, (QbittorrentClient c) => c.resume(hashes));
              case 'copy':
                await Clipboard.setData(ClipboardData(text: hashes.join('\n')));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hashes copied')));
                }
              case 'recheck':
                await _run(ref, (QbittorrentClient c) => c.recheck(hashes));
              case 'reannounce':
                await _run(ref, (QbittorrentClient c) => c.reannounce(hashes));
              case 'forcestart':
                await _run(
                    ref,
                    (QbittorrentClient c) =>
                        c.setForceStart(hashes, value: true));
              case 'rename':
                await _rename(context, ref, selectedHashes);
              case 'savepath':
                await _editSavePath(context, ref, selectedHashes);
              case 'category':
                await _editCategory(context, ref, selectedHashes);
              case 'tags':
                await _editTags(context, ref, selectedHashes);
              case 'export':
                try {
                  final QbittorrentClient client = await ref
                      .read(qbittorrentClientProvider(instance).future);
                  await client.exportTorrent(hashes.first);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Torrent exported successfully')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')));
                  }
                }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'pause', child: Text('Pause')),
            const PopupMenuItem<String>(value: 'resume', child: Text('Resume')),
            const PopupMenuItem<String>(value: 'copy', child: Text('Copy')),
            const PopupMenuItem<String>(
                value: 'recheck', child: Text('Force Recheck')),
            const PopupMenuItem<String>(
                value: 'reannounce', child: Text('Force Reannounce')),
            const PopupMenuItem<String>(
                value: 'forcestart', child: Text('Force Start')),
            PopupMenuItem<String>(
              value: 'rename',
              enabled: selectedHashes.length == 1,
              child: const Text('Rename'),
            ),
            const PopupMenuItem<String>(
                value: 'savepath', child: Text('Set SavePath')),
            const PopupMenuItem<String>(
                value: 'category', child: Text('Set Category')),
            const PopupMenuItem<String>(value: 'tags', child: Text('Set Tags')),
            PopupMenuItem<String>(
              value: 'export',
              enabled: selectedHashes.length == 1,
              child: const Text('Export .torrent'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TorrentTile extends ConsumerWidget {
  const _TorrentTile({required this.instance, required this.torrent});

  final Instance instance;
  final QbitTorrent torrent;

  String _formatEta(int eta) {
    if (eta >= 8640000 || eta < 0) {
      return '∞';
    }
    final Duration d = Duration(seconds: eta);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Set<String> selection = ref.watch(qbitSelectionProvider(instance));
    final bool selectionMode = selection.isNotEmpty;
    final bool isSelected = selection.contains(torrent.hash);
    final _QbitVisual v = _visualFor(torrent.state, cs);
    final double progress = torrent.progress.clamp(0, 1).toDouble();
    final bool complete = progress >= 1.0;
    final bool dlActive = torrent.dlspeed > 0;
    final bool upActive = torrent.upspeed > 0;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xs),
      child: Material(
        color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: () {
            if (!selectionMode) {
              ref.read(qbitSelectionProvider(instance).notifier).update(
                    (Set<String> s) => <String>{...s, torrent.hash},
                  );
            }
          },
          onTap: () {
            if (selectionMode) {
              ref
                  .read(qbitSelectionProvider(instance).notifier)
                  .update((Set<String> s) {
                final Set<String> next = Set<String>.of(s);
                if (next.contains(torrent.hash)) {
                  next.remove(torrent.hash);
                } else {
                  next.add(torrent.hash);
                }
                return next;
              });
            } else {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => TorrentDetailScreen(
                    instance: instance,
                    torrent: torrent,
                  ),
                ),
              );
            }
          },
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
                        color: isSelected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                            : v.container,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : v.icon,
                        size: 22,
                        color:
                            isSelected ? cs.onPrimaryContainer : v.onContainer,
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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? cs.onPrimaryContainer : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              _StatePill(
                                label: friendlyState(torrent.state),
                                visual: v,
                              ),
                              const SizedBox(width: Insets.sm),
                              Expanded(
                                child: Text(
                                  '${fmtBytes(torrent.downloaded)} / ${fmtBytes(torrent.size)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? cs.onPrimaryContainer
                                            .withValues(alpha: 0.8)
                                        : cs.onSurfaceVariant,
                                  ),
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
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          color: complete ? cs.tertiary : v.color,
                          backgroundColor: isSelected
                              ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                              : cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? cs.onPrimaryContainer : v.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Row(
                  children: <Widget>[
                    _SpeedPill(
                      icon: Icons.south,
                      label: '${fmtBytes(torrent.dlspeed)}/s',
                      color: cs.primary,
                      active: dlActive,
                    ),
                    const SizedBox(width: Insets.sm),
                    _SpeedPill(
                      icon: Icons.north,
                      label: '${fmtBytes(torrent.upspeed)}/s',
                      color: cs.tertiary,
                      active: upActive,
                    ),
                    const Spacer(),
                    Icon(Icons.swap_vert, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      torrent.ratio.toStringAsFixed(2),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (!complete) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      Icon(Icons.schedule,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        _formatEta(torrent.eta),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
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

/// Per-state color + icon mapping for the torrent card (downloading -> primary,
/// seeding -> tertiary, completed/queued -> secondary, error -> error, and a
/// muted outline look for paused/stalled).
class _QbitVisual {
  const _QbitVisual({
    required this.color,
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  final Color color;
  final Color container;
  final Color onContainer;
  final IconData icon;
}

_QbitVisual _visualFor(String state, ColorScheme cs) {
  switch (state) {
    case 'downloading':
    case 'forcedDL':
    case 'metaDL':
      return _QbitVisual(
        color: cs.primary,
        container: cs.primaryContainer,
        onContainer: cs.onPrimaryContainer,
        icon: Icons.download_rounded,
      );
    case 'uploading':
    case 'forcedUP':
    case 'stalledUP':
      return _QbitVisual(
        color: cs.tertiary,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        icon: Icons.upload_rounded,
      );
    case 'pausedUP':
    case 'stoppedUP':
      return _QbitVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.check_rounded,
      );
    case 'queuedDL':
    case 'queuedUP':
      return _QbitVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.schedule_rounded,
      );
    case 'checkingDL':
    case 'checkingUP':
    case 'checkingResumeData':
      return _QbitVisual(
        color: cs.tertiary,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        icon: Icons.sync_rounded,
      );
    case 'error':
    case 'missingFiles':
      return _QbitVisual(
        color: cs.error,
        container: cs.errorContainer,
        onContainer: cs.onErrorContainer,
        icon: Icons.error_outline_rounded,
      );
    default:
      return _QbitVisual(
        color: cs.outline,
        container: cs.surfaceContainerHighest,
        onContainer: cs.onSurfaceVariant,
        icon: state.contains('paused') || state.contains('stopped')
            ? Icons.pause_rounded
            : Icons.hourglass_empty_rounded,
      );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.visual});

  final String label;
  final _QbitVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: visual.container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.onContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = active ? color : cs.onSurfaceVariant;
    final Color bg =
        active ? color.withValues(alpha: 0.12) : cs.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Maps a raw qBittorrent state to a short friendly label.
String friendlyState(String state) {
  switch (state) {
    case 'downloading':
    case 'forcedDL':
      return 'Downloading';
    case 'uploading':
    case 'forcedUP':
      return 'Seeding';
    case 'stalledDL':
      return 'Stalled';
    case 'stalledUP':
      return 'Seeding (idle)';
    case 'pausedDL':
    case 'stoppedDL':
      return 'Paused';
    case 'pausedUP':
    case 'stoppedUP':
      return 'Completed';
    case 'queuedDL':
    case 'queuedUP':
      return 'Queued';
    case 'checkingDL':
    case 'checkingUP':
    case 'checkingResumeData':
      return 'Checking';
    case 'metaDL':
      return 'Fetching metadata';
    case 'error':
    case 'missingFiles':
      return 'Error';
    default:
      return state;
  }
}

/// Human-readable byte size (decimal units, matching qBittorrent's display).
String fmtBytes(num bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

class _ExpandableFab extends StatefulWidget {
  const _ExpandableFab({required this.builder});

  final List<Widget> Function(BuildContext context, VoidCallback close) builder;

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_open) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (BuildContext context, Widget? child) {
        return SizedBox(
          width: 56,
          height: 56.0 + (_expandAnimation.value * 136.0),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          ..._buildExpandingActionButtons(),
          FloatingActionButton(
            onPressed: _toggle,
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (BuildContext context, Widget? child) {
                return Transform.rotate(
                  angle: _expandAnimation.value * 0.7853981633974483,
                  child: const Icon(Icons.add),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final List<Widget> children = widget.builder(context, _close);
    final int count = children.length;
    const double step = 68.0;
    for (int i = 0; i < count; i++) {
      children[i] = _ExpandingActionButton(
        maxDistance: (i + 1) * step,
        progress: _expandAnimation,
        child: children[i],
      );
    }
    return children;
  }
}

class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? child) {
        final double offset = maxDistance * progress.value;
        return Positioned(
          bottom: offset,
          left: 0,
          right: 0,
          child: Transform.scale(
            scale: progress.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
