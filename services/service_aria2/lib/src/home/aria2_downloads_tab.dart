import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../aria2_add_sheet.dart';
import '../aria2_api.dart';
import '../aria2_download_detail_screen.dart';
import '../aria2_format.dart';
import '../aria2_providers.dart';
import '../aria2_speed_dialog.dart';
import '../models/aria2_download.dart';
import '../models/aria2_file.dart';
import '../models/aria2_snapshot.dart';

/// Tab 0: Unified transfers hub managing active, queued, completed, and errored downloads.
class Aria2DownloadsTab extends ConsumerStatefulWidget {
  const Aria2DownloadsTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<Aria2DownloadsTab> createState() => _Aria2DownloadsTabState();
}

class _Aria2DownloadsTabState extends ConsumerState<Aria2DownloadsTab> {
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(aria2SnapshotProvider(widget.instance));
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function(Aria2Api api) action,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final Aria2Api api = await ref.read(
        aria2ApiProvider(widget.instance).future,
      );
      await action(api);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) _refresh();
    }
  }

  Future<void> _showSpeedLimit(BuildContext context) async {
    final Map<String, String>? options = ref
        .read(aria2GlobalOptionsProvider(widget.instance))
        .value;
    final int currentBytes =
        int.tryParse(options?['max-overall-download-limit'] ?? '') ?? 0;
    final int? newBytes = await showAria2SpeedDialog(
      context,
      currentBytes: currentBytes,
    );
    if (newBytes == null || !mounted || !context.mounted) return;
    await _run(
      context,
      (Aria2Api api) => api.setGlobalDownloadLimit(newBytes),
    );
    ref.invalidate(aria2GlobalOptionsProvider(widget.instance));
  }

  String _decodeError(int code, String rawMessage) {
    if (rawMessage.isNotEmpty) return rawMessage;
    return switch (code) {
      1 => 'Unknown error',
      2 => 'Time out',
      3 => 'Resource not found',
      4 => 'Resource not found (max file size exceeded)',
      5 => 'Download speed was too slow',
      6 => 'Network problem occurred',
      7 => 'Unfinished download',
      8 => 'Remote server did not support resume',
      9 => 'Status 404 Not Found',
      10 => 'Redirection limit exceeded',
      11 => 'Could not parse Metalink document',
      12 => 'File already exists',
      13 => 'Renaming file failed',
      14 => 'Could not open existing file',
      15 => 'Could not create new file or truncate existing file',
      16 => 'File I/O error occurred',
      17 => 'Could not create directory',
      18 => 'Name resolution failed',
      19 => 'Could not parse Torrent file',
      24 => 'HTTP authorization failed',
      28 => 'BitTorrent info-hash error',
      32 => 'Checksum verification failed',
      _ => 'Error code $code',
    };
  }

  List<Aria2Download> _filterAndSort(
    List<Aria2Download> list,
    String query,
    Aria2TransfersFilter filter,
    Aria2SortField sortField,
    bool ascending,
  ) {
    Iterable<Aria2Download> filtered = list;

    // Filter by tab filter
    switch (filter) {
      case Aria2TransfersFilter.all:
        break;
      case Aria2TransfersFilter.active:
        filtered = filtered.where((d) => d.isActive);
        break;
      case Aria2TransfersFilter.waiting:
        filtered = filtered.where((d) => d.isWaiting);
        break;
      case Aria2TransfersFilter.completed:
        filtered = filtered.where((d) => d.isComplete);
        break;
      case Aria2TransfersFilter.paused:
        filtered = filtered.where((d) => d.isPaused);
        break;
      case Aria2TransfersFilter.error:
        filtered = filtered.where((d) => d.isError);
        break;
    }

    // Filter by search query
    if (query.isNotEmpty) {
      final String q = query.toLowerCase();
      filtered = filtered.where(
        (d) =>
            d.displayName.toLowerCase().contains(q) ||
            d.gid.toLowerCase().contains(q) ||
            d.dir.toLowerCase().contains(q) ||
            d.errorMessage.toLowerCase().contains(q),
      );
    }

    final List<Aria2Download> result = filtered.toList();
    result.sort((Aria2Download a, Aria2Download b) {
      int cmp = 0;
      switch (sortField) {
        case Aria2SortField.name:
          cmp = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
          break;
        case Aria2SortField.size:
          cmp = a.totalLength.compareTo(b.totalLength);
          break;
        case Aria2SortField.progress:
          cmp = a.progress.compareTo(b.progress);
          break;
        case Aria2SortField.downloadSpeed:
          cmp = a.downloadSpeed.compareTo(b.downloadSpeed);
          break;
        case Aria2SortField.uploadSpeed:
          cmp = a.uploadSpeed.compareTo(b.uploadSpeed);
          break;
        case Aria2SortField.eta:
          cmp = (a.etaSeconds ?? 999999).compareTo(b.etaSeconds ?? 999999);
          break;
      }
      return ascending ? cmp : -cmp;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<Aria2Snapshot> snapshot = ref.watch(
      aria2SnapshotProvider(widget.instance),
    );

    final Set<String> selection = ref.watch(
      aria2SelectionProvider(widget.instance),
    );
    final bool isSelecting = selection.isNotEmpty;

    final String query = ref.watch(aria2SearchQueryProvider(widget.instance));
    final Aria2TransfersFilter filter = ref.watch(
      aria2TransfersFilterProvider(widget.instance),
    );
    final Aria2SortField sortField = ref.watch(
      aria2SortFieldProvider(widget.instance),
    );
    final bool sortAscending = ref.watch(
      aria2SortAscendingProvider(widget.instance),
    );

    ref.listen<int>(aria2ScrollToTopProvider((widget.instance, 0)), (
      previous,
      next,
    ) {
      if (next > 0 && _scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });

    final bool isSearchActive = ref.watch(
      aria2SearchActiveProvider(widget.instance),
    );

    ref.listen<bool>(aria2SearchActiveProvider(widget.instance), (
      bool? prev,
      bool next,
    ) {
      if (!next && _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    return Scaffold(
      appBar: isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  ref.read(aria2SelectionProvider(widget.instance).notifier).state =
                      <String>{};
                },
              ),
              title: Text('${selection.length} selected'),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    final Aria2Snapshot? s = snapshot.value;
                    if (s == null) return;
                    final Set<String> allGids = <String>{
                      ...s.active.map((d) => d.gid),
                      ...s.waiting.map((d) => d.gid),
                      ...s.stopped.map((d) => d.gid),
                    };
                    ref.read(aria2SelectionProvider(widget.instance).notifier).state =
                        allGids;
                  },
                ),
                IconButton(
                  tooltip: 'Pause selected',
                  icon: const Icon(Icons.pause),
                  onPressed: () => _run(context, (Aria2Api api) async {
                    final Aria2Snapshot? s = snapshot.value;
                    final Set<String> activeGids =
                        s?.active.map((d) => d.gid).toSet() ?? <String>{};
                    final List<String> targets =
                        selection.where(activeGids.contains).toList();
                    if (targets.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No active downloads in selection'),
                        ),
                      );
                      return;
                    }
                    final ({int succeeded, int failed}) res =
                        await api.pauseGids(targets);
                    ref.read(aria2SelectionProvider(widget.instance).notifier).state =
                        <String>{};
                    if (context.mounted) {
                      final String message = res.failed == 0
                          ? 'Paused ${res.succeeded} download(s)'
                          : 'Paused ${res.succeeded} of ${res.succeeded + res.failed} download(s) (${res.failed} failed)';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Resume selected',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _run(context, (Aria2Api api) async {
                    final Aria2Snapshot? s = snapshot.value;
                    final Set<String> resumableGids = <String>{
                      ...?s?.waiting
                          .where((d) => d.canResume)
                          .map((d) => d.gid),
                      ...?s?.active
                          .where((d) => d.canResume)
                          .map((d) => d.gid),
                    };
                    final List<String> targets =
                        selection.where(resumableGids.contains).toList();
                    if (targets.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No resumable downloads in selection'),
                        ),
                      );
                      return;
                    }
                    final ({int succeeded, int failed}) res =
                        await api.unpauseGids(targets);
                    ref.read(aria2SelectionProvider(widget.instance).notifier).state =
                        <String>{};
                    if (context.mounted) {
                      final String message = res.failed == 0
                          ? 'Resumed ${res.succeeded} download(s)'
                          : 'Resumed ${res.succeeded} of ${res.succeeded + res.failed} download(s) (${res.failed} failed)';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Remove selected',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        title: const Text('Remove downloads'),
                        content: Text(
                          'Remove ${selection.length} selected download(s)?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    await _run(context, (Aria2Api api) async {
                      final Aria2Snapshot? s = snapshot.value;
                      final Set<String> stoppedGids =
                          s?.stopped.map((d) => d.gid).toSet() ?? <String>{};
                      final List<String> stoppedTargets =
                          selection.where(stoppedGids.contains).toList();
                      final List<String> activeOrWaitingTargets = selection
                          .where((String gid) => !stoppedGids.contains(gid))
                          .toList();
                      final ({int succeeded, int failed}) res =
                          await api.removeGids(
                        activeOrWaitingGids: activeOrWaitingTargets,
                        stoppedGids: stoppedTargets,
                      );
                      ref.read(aria2SelectionProvider(widget.instance).notifier).state =
                          <String>{};
                      if (context.mounted) {
                        final String message = res.failed == 0
                            ? 'Removed ${res.succeeded} download(s)'
                            : 'Removed ${res.succeeded} of ${res.succeeded + res.failed} download(s) (${res.failed} failed)';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      }
                    });
                  },
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer ??
                    () => Scaffold.of(context).openDrawer(),
              ),
              title: isSearchActive
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search all downloads...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(
                                  aria2SearchQueryProvider(
                                    widget.instance,
                                  ).notifier,
                                )
                                .state = '';
                            ref
                                .read(
                                  aria2SearchActiveProvider(
                                    widget.instance,
                                  ).notifier,
                                )
                                .state = false;
                          },
                        ),
                      ),
                      onChanged: (String val) {
                        ref
                            .read(
                              aria2SearchQueryProvider(
                                widget.instance,
                              ).notifier,
                            )
                            .state = val.trim();
                      },
                    )
                  : Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            widget.instance.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.instance.kind.isBeta) ...<Widget>[
                          const SizedBox(width: Insets.sm),
                          const BetaBadge(),
                        ],
                      ],
                    ),
              actions: <Widget>[
                if (!isSearchActive)
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      ref
                          .read(
                            aria2SearchActiveProvider(
                              widget.instance,
                            ).notifier,
                          )
                          .state = true;
                    },
                  ),
                PopupMenuButton<Aria2SortField>(
                  tooltip: 'Sort by',
                  icon: const Icon(Icons.sort),
                  onSelected: (Aria2SortField field) {
                    if (sortField == field) {
                      ref
                              .read(
                                aria2SortAscendingProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state =
                          !sortAscending;
                    } else {
                      ref
                              .read(
                                aria2SortFieldProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state =
                          field;
                      ref
                              .read(
                                aria2SortAscendingProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state =
                          true;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<Aria2SortField>>[
                        for (final Aria2SortField sf in Aria2SortField.values)
                          PopupMenuItem<Aria2SortField>(
                            value: sf,
                            child: Row(
                              children: <Widget>[
                                if (sortField == sf)
                                  Icon(
                                    sortAscending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                    color: cs.primary,
                                  )
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: Insets.sm),
                                Text(sf.label),
                              ],
                            ),
                          ),
                      ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (String val) {
                    if (val == 'pause_all') {
                      _run(context, (Aria2Api api) => api.pauseAll());
                    } else if (val == 'resume_all') {
                      _run(context, (Aria2Api api) => api.unpauseAll());
                    } else if (val == 'speed_limit') {
                      _showSpeedLimit(context);
                    } else if (val == 'purge_completed') {
                      _run(
                        context,
                        (Aria2Api api) => api.purgeDownloadResult(),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'pause_all',
                          child: ListTile(
                            leading: Icon(Icons.pause),
                            title: Text('Pause all'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'resume_all',
                          child: ListTile(
                            leading: Icon(Icons.play_arrow),
                            title: Text('Resume all'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'speed_limit',
                          child: ListTile(
                            leading: Icon(Icons.speed),
                            title: Text('Speed limit'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'purge_completed',
                          child: ListTile(
                            leading: Icon(Icons.cleaning_services_outlined),
                            title: Text('Clear finished results'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add download',
        onPressed: () => showAria2AddSheet(context, widget.instance),
        child: const Icon(Icons.add),
      ),
      body: AsyncValueView<Aria2Snapshot>(
        value: snapshot,
        onRetry: _refresh,
        data: (Aria2Snapshot data) {
          final List<Aria2Download> allDownloads = <Aria2Download>[
            ...data.active,
            ...data.waiting,
            ...data.stopped,
          ];
          final List<Aria2Download> visibleDownloads = _filterAndSort(
            allDownloads,
            query,
            filter,
            sortField,
            sortAscending,
          );

          final int activeCount = data.active.length;
          final int waitingCount = data.waiting
              .where((d) => d.isWaiting)
              .length;
          final int completedCount = data.stopped
              .where((d) => d.isComplete)
              .length;
          final int pausedCount = data.waiting.where((d) => d.isPaused).length;
          final int errorCount = data.stopped.where((d) => d.isError).length;

          return EasyRefresh(
            header: const ClassicHeader(),
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                // Global Telemetry Hero Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.sm,
                      Insets.md,
                      Insets.xs,
                    ),
                    child: Material(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _HeroMetric(
                                    icon: Icons.arrow_downward_rounded,
                                    value: aria2FmtRate(data.stat.downloadSpeed),
                                    label: 'Download',
                                    color: cs.primary,
                                  ),
                                ),
                                Expanded(
                                  child: _HeroMetric(
                                    icon: Icons.arrow_upward_rounded,
                                    value: aria2FmtRate(data.stat.uploadSpeed),
                                    label: 'Upload',
                                    color: cs.tertiary,
                                  ),
                                ),
                                Expanded(
                                  child: _HeroMetric(
                                    icon: data.version.version.isNotEmpty
                                        ? Icons.info_outline
                                        : Icons.swap_vert_rounded,
                                    value: data.version.version.isNotEmpty
                                        ? data.version.version
                                        : '$activeCount / ${data.waiting.length}',
                                    label: data.version.version.isNotEmpty
                                        ? 'aria2'
                                        : 'Active / Queued',
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (data.stopped.isNotEmpty || data.stat.numStopped > 0) ...<Widget>[
                              const SizedBox(height: Insets.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.cleaning_services_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Clear finished (${data.stat.numStopped > 0 ? data.stat.numStopped : data.stopped.length})',
                                    ),
                                    onPressed: () => _run(
                                      context,
                                      (Aria2Api api) => api.purgeDownloadResult(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Unified Filter Segmented Chips
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        for (final Aria2TransfersFilter f
                            in Aria2TransfersFilter.values) ...<Widget>[
                          FilterChip(
                            label: Text(switch (f) {
                              Aria2TransfersFilter.all =>
                                '${f.label} (${allDownloads.length})',
                              Aria2TransfersFilter.active =>
                                '${f.label} ($activeCount)',
                              Aria2TransfersFilter.waiting =>
                                '${f.label} ($waitingCount)',
                              Aria2TransfersFilter.completed =>
                                '${f.label} ($completedCount)',
                              Aria2TransfersFilter.paused =>
                                '${f.label} ($pausedCount)',
                              Aria2TransfersFilter.error =>
                                '${f.label} ($errorCount)',
                            }),
                            selected: filter == f,
                            onSelected: (bool selected) {
                              if (selected) {
                                ref
                                    .read(
                                      aria2TransfersFilterProvider(
                                        widget.instance,
                                      ).notifier,
                                    )
                                    .state = f;
                              }
                            },
                          ),
                          const SizedBox(width: Insets.xs),
                        ],
                      ],
                    ),
                  ),
                ),

                if (visibleDownloads.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Insets.xl * 2),
                      child: EmptyView(
                        icon: switch (filter) {
                          Aria2TransfersFilter.all =>
                            Icons.download_done_outlined,
                          Aria2TransfersFilter.active => Icons.arrow_downward,
                          Aria2TransfersFilter.waiting => Icons.schedule,
                          Aria2TransfersFilter.completed =>
                            Icons.check_circle_outline,
                          Aria2TransfersFilter.paused => Icons.pause,
                          Aria2TransfersFilter.error => Icons.error_outline,
                        },
                        title: switch (filter) {
                          Aria2TransfersFilter.all => 'No downloads yet',
                          Aria2TransfersFilter.active =>
                            'Nothing downloading right now',
                          Aria2TransfersFilter.waiting => 'Queue is empty',
                          Aria2TransfersFilter.completed =>
                            'No completed downloads',
                          Aria2TransfersFilter.paused => 'No paused downloads',
                          Aria2TransfersFilter.error => 'No errored downloads',
                        },
                        message: query.isNotEmpty
                            ? 'No downloads match "$query".'
                            : 'Tap "+" below to add a direct URL, magnet, or torrent file.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 90),
                    sliver: SliverList.builder(
                      itemCount: visibleDownloads.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Aria2Download download = visibleDownloads[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.md,
                            Insets.xs,
                            Insets.md,
                            Insets.xs,
                          ),
                          child: _UnifiedTransferCard(
                            download: download,
                            isSelected: selection.contains(download.gid),
                            isSelecting: isSelecting,
                            errorMessage: download.isError
                                ? _decodeError(
                                    download.errorCode,
                                    download.errorMessage,
                                  )
                                : '',
                            onToggleSelect: () {
                              final Set<String> updated = Set<String>.from(
                                selection,
                              );
                              if (updated.contains(download.gid)) {
                                updated.remove(download.gid);
                              } else {
                                updated.add(download.gid);
                              }
                              ref
                                  .read(
                                    aria2SelectionProvider(
                                      widget.instance,
                                    ).notifier,
                                  )
                                  .state = updated;
                            },
                            onTap: () {
                              if (isSelecting) {
                                final Set<String> updated = Set<String>.from(
                                  selection,
                                );
                                if (updated.contains(download.gid)) {
                                  updated.remove(download.gid);
                                } else {
                                  updated.add(download.gid);
                                }
                                ref
                                    .read(
                                      aria2SelectionProvider(
                                        widget.instance,
                                      ).notifier,
                                    )
                                    .state = updated;
                              } else {
                                pushScreen<void>(
                                  context,
                                  Aria2DownloadDetailScreen(
                                    instance: widget.instance,
                                    gid: download.gid,
                                    initialName: download.displayName,
                                  ),
                                );
                              }
                            },
                            onPauseResume: () => _run(
                              context,
                              (Aria2Api api) => download.canResume
                                  ? api.unpause(download.gid)
                                  : api.pause(download.gid),
                            ),
                            onMoveTop: () => _run(
                              context,
                              (Aria2Api api) => api.changePosition(
                                download.gid,
                                0,
                                'POS_SET',
                              ),
                            ),
                            onDeleteOrClear: () async {
                              if (download.isLive) {
                                final bool? confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext ctx) => AlertDialog(
                                    title: const Text('Remove download?'),
                                    content: Text(
                                      'Are you sure you want to stop and remove "${download.displayName}"?',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !context.mounted) return;
                                await _run(
                                  context,
                                  (Aria2Api api) => api.remove(download.gid),
                                );
                              } else {
                                await _run(
                                  context,
                                  (Aria2Api api) =>
                                      api.removeDownloadResult(download.gid),
                                );
                              }
                            },
                            onRetry: () => _run(context, (Aria2Api api) async {
                              // The URIs of one file are its mirrors, and
                              // addUri reads every URI it gets as a mirror of
                              // one file, so only a single-file download can
                              // be rebuilt from them.
                              final List<String> uris =
                                  download.files.length == 1
                                  ? download.files.single.uris
                                        .map((Aria2Uri u) => u.uri)
                                        .where((String u) => u.isNotEmpty)
                                        .toList()
                                  : const <String>[];

                              // Fetch original options to preserve user-specified settings
                              Map<String, dynamic> oldOptions =
                                  const <String, dynamic>{};
                              try {
                                oldOptions = await api.getOption(download.gid);
                              } catch (_) {
                                // Ignore if daemon cannot find options for stopped entry
                              }

                              final Map<String, dynamic> preserved =
                                  <String, dynamic>{};
                              for (final String key in const <String>[
                                'dir',
                                'out',
                                'header',
                                'split',
                                'max-connection-per-server',
                                'all-proxy',
                                'http-proxy',
                                'https-proxy',
                                'user-agent',
                              ]) {
                                dynamic val = oldOptions[key];
                                // aria2 hands headers back as one string, a
                                // header per line; they go out as a list.
                                if (key == 'header' && val is String) {
                                  val = val
                                      .split('\n')
                                      .where((String h) => h.isNotEmpty)
                                      .toList();
                                }
                                if (val != null &&
                                    (val is! String || val.isNotEmpty) &&
                                    (val is! List || val.isNotEmpty)) {
                                  preserved[key] = val;
                                }
                              }
                              if (!preserved.containsKey('dir') &&
                                  download.dir.isNotEmpty) {
                                preserved['dir'] = download.dir;
                              }

                              // A torrent comes back from its info-hash, even
                              // when its files list web seeds.
                              if (download.infoHash.isNotEmpty) {
                                final String magnet =
                                    'magnet:?xt=urn:btih:${download.infoHash}';
                                await api.addUri(
                                  <String>[magnet],
                                  options: preserved,
                                );
                              } else if (uris.isNotEmpty) {
                                await api.addUri(uris, options: preserved);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cannot retry this download here. Add it again instead.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              // Remove the failed download result from daemon memory to avoid duplicate
                              try {
                                await api.removeDownloadResult(download.gid);
                              } catch (_) {
                                // Ignore if already purged
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Download restarted'),
                                  ),
                                );
                              }
                            }),
                          ),
                        );
                      },
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UnifiedTransferCard extends StatelessWidget {
  const _UnifiedTransferCard({
    required this.download,
    required this.isSelected,
    required this.isSelecting,
    required this.errorMessage,
    required this.onToggleSelect,
    required this.onTap,
    required this.onPauseResume,
    required this.onMoveTop,
    required this.onDeleteOrClear,
    required this.onRetry,
  });

  final Aria2Download download;
  final bool isSelected;
  final bool isSelecting;
  final String errorMessage;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final VoidCallback onPauseResume;
  final VoidCallback onMoveTop;
  final VoidCallback onDeleteOrClear;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int? eta = download.etaSeconds;

    final String sizes =
        '${aria2FmtBytes(download.completedLength)} / ${aria2FmtBytes(download.totalLength)}';

    return Material(
      color: isSelected
          ? cs.primaryContainer.withAlpha(80)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onToggleSelect,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (isSelecting)
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.sm),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onToggleSelect(),
                      ),
                    ),
                  Icon(
                    download.isComplete
                        ? Icons.check_circle_outline
                        : download.isError
                        ? Icons.error_outline
                        : download.torrentName.isNotEmpty
                        ? Icons.cloud_download_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 20,
                    color: download.isComplete
                        ? cs.tertiary
                        : download.isError
                        ? cs.error
                        : cs.primary,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      download.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  Text(
                    download.isComplete
                        ? 'Done'
                        : download.isError
                        ? 'Error'
                        : '${(download.progress * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: download.isComplete
                          ? cs.tertiary
                          : download.isError
                          ? cs.error
                          : cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      sizes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                  if (download.downloadSpeed > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 12,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          aria2FmtRate(download.downloadSpeed),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  if (download.uploadSpeed > 0) ...<Widget>[
                    const SizedBox(width: Insets.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 12,
                          color: cs.tertiary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          aria2FmtRate(download.uploadSpeed),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (eta != null && !download.isStopped) ...<Widget>[
                    const SizedBox(width: Insets.sm),
                    Text(
                      aria2FormatEta(eta),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (download.isLive) ...<Widget>[
                const SizedBox(height: Insets.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicatorM3E(
                    size: LinearProgressM3ESize.s,
                    shape: ProgressM3EShape.flat,
                    value: download.progress,
                    activeColor: download.isPaused ? cs.outline : cs.primary,
                    trackColor: cs.surfaceContainerHighest,
                  ),
                ),
              ],
              if (download.isError && errorMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  errorMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: Insets.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (download.isError)
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      onPressed: onRetry,
                    ),
                  if (download.isWaiting)
                    IconButton(
                      tooltip: 'Move to top of queue',
                      icon: const Icon(Icons.vertical_align_top, size: 18),
                      onPressed: onMoveTop,
                    ),
                  if (download.canPause || download.canResume)
                    IconButton(
                      tooltip: download.canResume ? 'Resume' : 'Pause',
                      icon: Icon(
                        download.canResume ? Icons.play_arrow : Icons.pause,
                        size: 20,
                      ),
                      onPressed: onPauseResume,
                    ),
                  IconButton(
                    tooltip: download.isStopped ? 'Clear from list' : 'Remove',
                    icon: Icon(
                      download.isStopped
                          ? Icons.cleaning_services_outlined
                          : Icons.delete_outline,
                      size: 20,
                    ),
                    onPressed: onDeleteOrClear,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
