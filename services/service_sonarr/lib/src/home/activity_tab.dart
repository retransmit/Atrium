import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sonarr_blocklist_item.dart';
import '../models/sonarr_history_item.dart';
import '../models/sonarr_queue_item.dart';
import '../models/sonarr_series.dart';
import '../sonarr_providers.dart';

class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab>
    with WidgetsBindingObserver {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final String initialQuery =
        ref.read(sonarrActivitySearchQueryProvider(widget.instance));
    _searchController = TextEditingController(text: initialQuery);
    _searchFocusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    ref.read(sonarrSearchActiveProvider(widget.instance).notifier).state =
        false;
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final double bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset == 0 && _lastBottomInset > 0) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    }
    _lastBottomInset = bottomInset;
  }

  void _updateSearchActiveState() {
    final bool isActive =
        _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;
    ref.read(sonarrSearchActiveProvider(widget.instance).notifier).state =
        isActive;
  }

  void _onFocusChange() {
    _updateSearchActiveState();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final grouped = ref.watch(sonarrActivityGroupedProvider(widget.instance));

    return PopScope<Object?>(
      canPop: Scaffold.of(context).isDrawerOpen ||
          (!_searchFocusNode.hasFocus && _searchController.text.isEmpty),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (Scaffold.of(context).isDrawerOpen) return;
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          return;
        }
        setState(() {
          _searchController.clear();
        });
        ref.read(sonarrActivitySearchQueryProvider(widget.instance).notifier).state = '';
        _updateSearchActiveState();
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext innerContext, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: true,
                  scrolledUnderElevation: 0.0,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: theme.colorScheme.surface,
                  toolbarHeight: 72,
                  titleSpacing: 0,
                  leadingWidth: 56,
                  leading: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      // Call on outer context of the build method to resolve the parent Scaffold drawer.
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                  title: SearchBar(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    hintText: 'Search activity...',
                    onTapOutside: (event) {
                      if (_searchFocusNode.hasFocus) {
                        _searchFocusNode.unfocus();
                      }
                    },
                    elevation: const WidgetStatePropertyAll<double>(0),
                    backgroundColor: WidgetStatePropertyAll<Color>(
                      theme.colorScheme.surfaceContainerHigh,
                    ),
                    trailing: <Widget>[
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                            ref
                                .read(
                                  sonarrActivitySearchQueryProvider(
                                    widget.instance,
                                  ).notifier,
                                )
                                .state = '';
                            _updateSearchActiveState();
                          },
                        ),
                    ],
                    onChanged: (String value) {
                      setState(() {});
                      ref
                          .read(
                            sonarrActivitySearchQueryProvider(widget.instance)
                                .notifier,
                          )
                          .state = value;
                      _updateSearchActiveState();
                    },
                  ),
                  actions: <Widget>[
                    IconButton(
                      icon: Icon(
                        grouped ? Icons.format_list_bulleted : Icons.group_work_outlined,
                      ),
                      tooltip: grouped ? 'Switch to plain list' : 'Switch to grouped view',
                      onPressed: () {
                        ref
                            .read(
                              sonarrActivityGroupedProvider(widget.instance)
                                  .notifier,
                            )
                            .state = !grouped;
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: theme.textTheme.titleSmall,
                    tabs: const <Widget>[
                      Tab(text: 'Queue'),
                      Tab(text: 'History'),
                      Tab(text: 'Blocklist'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: <Widget>[
                _QueueView(instance: widget.instance),
                _HistoryView(instance: widget.instance),
                _BlocklistView(instance: widget.instance),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueView extends ConsumerWidget {
  const _QueueView({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueAsync = ref.watch(sonarrQueueProvider(instance));
    final searchQuery = ref.watch(sonarrActivitySearchQueryProvider(instance)).toLowerCase();

    return queueAsync.when(
      data: (List<SonarrQueueItem> items) {
        final filteredItems = items.where((item) {
          if (searchQuery.isEmpty) return true;
          final titleMatch = item.title?.toLowerCase().contains(searchQuery) ?? false;
          final seriesMatch = item.series?.title.toLowerCase().contains(searchQuery) ?? false;
          return titleMatch || seriesMatch;
        }).toList();

        // Group items by downloadId
        final Map<String, List<SonarrQueueItem>> groups = {};
        final List<List<SonarrQueueItem>> groupedList = [];

        for (final item in filteredItems) {
          final String? dlId = item.downloadId;
          if (dlId == null || dlId.isEmpty) {
            groupedList.add([item]);
          } else {
            if (!groups.containsKey(dlId)) {
              groups[dlId] = [];
              groupedList.add(groups[dlId]!);
            }
            groups[dlId]!.add(item);
          }
        }

        if (groupedList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.queue,
                  size: 48,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'Queue is empty' : 'No items match search',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sonarrQueueProvider(instance));
            await ref.read(sonarrQueueProvider(instance).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedList.length,
            itemBuilder: (BuildContext context, int index) {
              final group = groupedList[index];
              return _QueueItemCard(instance: instance, group: group);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load queue: $error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(sonarrQueueProvider(instance)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QueueItemCard extends ConsumerWidget {
  const _QueueItemCard({
    required this.instance,
    required this.group,
  });

  final Instance instance;
  final List<SonarrQueueItem> group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.watch(sonarrApiProvider(instance)).value;
    final item = group.first;

    // Calculate aggregated size and progress
    double totalSize = 0.0;
    double totalSizeLeft = 0.0;
    for (final i in group) {
      totalSize += i.size ?? 0.0;
      totalSizeLeft += i.sizeleft ?? 0.0;
    }

    final bool allSizesIdentical = group.every((i) => i.size == item.size && i.sizeleft == item.sizeleft);
    final double displaySize = allSizesIdentical ? (item.size ?? 0.0) : totalSize;
    final double displaySizeLeft = allSizesIdentical ? (item.sizeleft ?? 0.0) : totalSizeLeft;
    final double progress = displaySize > 0 ? (displaySize - displaySizeLeft) / displaySize : 0.0;

    // Construct episodes display list (e.g. S01E01, S01E02)
    final List<String> episodeTexts = [];
    for (final i in group) {
      if (i.episode != null) {
        final String seasonStr = i.seasonNumber != null ? 'S${i.seasonNumber.toString().padLeft(2, '0')}' : '';
        final String epStr = 'E${i.episode!.episodeNumber.toString().padLeft(2, '0')}';
        episodeTexts.add('$seasonStr$epStr');
      }
    }
    final String episodesDisplay = episodeTexts.isNotEmpty
        ? 'Episodes: ${episodeTexts.join(', ')}'
        : '';

    String? posterUrl;
    if (item.series?.images != null && api != null) {
      try {
        final img = item.series!.images.firstWhere(
          (i) => i.coverType == 'poster',
        );
        posterUrl = api.posterUrl(img);
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showQueueDetails(context, ref, group),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 75,
                  child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, err) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.live_tv,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.live_tv,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.series?.title ?? item.title ?? 'Unknown Release',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title ?? 'No release name',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episodesDisplay.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episodesDisplay,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        _buildStatusBadge(context, item.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              color: item.status == 'warning'
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '${_formatSize(displaySize - displaySizeLeft)} of ${_formatSize(displaySize)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (item.timeleft != null && item.timeleft != '00:00:00')
                          Text(
                            'ETA: ${item.timeleft}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.cancel_outlined,
                  color: theme.colorScheme.error,
                ),
                onPressed: () => _confirmDeleteQueueItem(context, ref, group),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String? status) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    final String label = status?.toLowerCase() ?? 'unknown';

    switch (label) {
      case 'downloading':
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        break;
      case 'completed':
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        break;
      case 'warning':
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
        break;
      case 'paused':
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
        break;
      case 'queued':
        bg = theme.colorScheme.secondaryContainer;
        fg = theme.colorScheme.onSecondaryContainer;
        break;
      default:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showQueueDetails(
    BuildContext context,
    WidgetRef ref,
    List<SonarrQueueItem> group,
  ) {
    final theme = Theme.of(context);
    final item = group.first;

    // Construct episodes list
    final List<String> episodeTexts = [];
    for (final i in group) {
      if (i.episode != null) {
        final String seasonStr = i.seasonNumber != null ? 'S${i.seasonNumber}' : '';
        final String epStr = 'E${i.episode!.episodeNumber}';
        episodeTexts.add('$seasonStr$epStr');
      }
    }
    final String episodesDisplay = episodeTexts.isNotEmpty
        ? episodeTexts.join(', ')
        : 'None';

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Queue Item Details',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DetailRow(label: 'Title', value: item.title ?? 'No title'),
                _DetailRow(label: 'Series', value: item.series?.title ?? 'Unknown Series'),
                _DetailRow(label: 'Episodes', value: episodesDisplay),
                _DetailRow(label: 'Status', value: item.status ?? 'Unknown'),
                _DetailRow(label: 'Tracked State', value: item.trackedDownloadState ?? 'None'),
                _DetailRow(label: 'Download Client', value: item.downloadClient ?? 'Unknown'),
                _DetailRow(label: 'Download ID', value: item.downloadId ?? 'Unknown'),
                _DetailRow(label: 'Indexer', value: item.indexer ?? 'Unknown'),
                _DetailRow(label: 'Output Path', value: item.outputPath ?? 'Unknown'),
                if (item.errorMessage != null && item.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Error Message:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.errorContainer),
                    ),
                    child: Text(
                      item.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteQueueItem(
    BuildContext context,
    WidgetRef ref,
    List<SonarrQueueItem> group,
  ) {
    final theme = Theme.of(context);
    bool removeFromClient = true;
    bool blocklist = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Text(
                'Remove from Queue',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    group.length > 1
                        ? 'Are you sure you want to remove all ${group.length} episodes of this item from the active queue?'
                        : 'Are you sure you want to remove this item from the active queue?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Remove from download client'),
                    value: removeFromClient,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? val) {
                      setState(() {
                        removeFromClient = val ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Blocklist this release'),
                    subtitle: const Text('Prevents Sonarr from grabbing this file again'),
                    value: blocklist,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? val) {
                      setState(() {
                        blocklist = val ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      final api = await ref.read(sonarrApiProvider(instance).future);
                      // Delete all items in the grouped torrent.
                      for (final i in group) {
                        await api.deleteQueueItem(
                          i.id,
                          removeFromClient: removeFromClient,
                          blocklist: blocklist,
                        );
                      }
                      ref.invalidate(sonarrQueueProvider(instance));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              group.length > 1
                                  ? 'All ${group.length} episodes removed from queue.'
                                  : 'Queue item deleted.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete item: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HistoryView extends ConsumerWidget {
  const _HistoryView({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(sonarrHistoryProvider(instance));
    final searchQuery = ref.watch(sonarrActivitySearchQueryProvider(instance)).toLowerCase();
    final grouped = ref.watch(sonarrActivityGroupedProvider(instance));

    return historyAsync.when(
      data: (List<SonarrHistoryItem> items) {
        final filteredItems = items.where((item) {
          if (searchQuery.isEmpty) return true;
          final titleMatch = item.sourceTitle?.toLowerCase().contains(searchQuery) ?? false;
          final seriesMatch = item.series?.title.toLowerCase().contains(searchQuery) ?? false;
          final episodeMatch = item.episode?.title.toLowerCase().contains(searchQuery) ?? false;
          return titleMatch || seriesMatch || episodeMatch;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.history,
                  size: 48,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'No history records' : 'No history matches search',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        if (grouped) {
          // Group by series
          final Map<int, List<SonarrHistoryItem>> groupedMap = {};
          final List<SonarrSeries> seriesList = [];
          final List<SonarrHistoryItem> unknownSeriesItems = [];

          for (final item in filteredItems) {
            if (item.series != null) {
              final seriesId = item.series!.id;
              if (!groupedMap.containsKey(seriesId)) {
                groupedMap[seriesId] = [];
                seriesList.add(item.series!);
              }
              groupedMap[seriesId]!.add(item);
            } else {
              unknownSeriesItems.add(item);
            }
          }

          // Sort series by date of latest event
          seriesList.sort((a, b) {
            final latestA = groupedMap[a.id]!.first.date ?? '';
            final latestB = groupedMap[b.id]!.first.date ?? '';
            return latestB.compareTo(latestA);
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sonarrHistoryProvider(instance));
              await ref.read(sonarrHistoryProvider(instance).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: seriesList.length + (unknownSeriesItems.isNotEmpty ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index < seriesList.length) {
                  final series = seriesList[index];
                  final seriesItems = groupedMap[series.id]!;
                  return _GroupedHistoryCard(
                    instance: instance,
                    series: series,
                    items: seriesItems,
                  );
                } else {
                  return _GroupedHistoryCard(
                    instance: instance,
                    series: null,
                    items: unknownSeriesItems,
                  );
                }
              },
            ),
          );
        } else {
          // Plain list layout
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sonarrHistoryProvider(instance));
              await ref.read(sonarrHistoryProvider(instance).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = filteredItems[index];
                return _PlainHistoryCard(instance: instance, item: item);
              },
            ),
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load history: $error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(sonarrHistoryProvider(instance)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupedHistoryCard extends ConsumerStatefulWidget {
  const _GroupedHistoryCard({
    required this.instance,
    required this.series,
    required this.items,
  });

  final Instance instance;
  final SonarrSeries? series;
  final List<SonarrHistoryItem> items;

  @override
  ConsumerState<_GroupedHistoryCard> createState() => _GroupedHistoryCardState();
}

class _GroupedHistoryCardState extends ConsumerState<_GroupedHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = ref.watch(sonarrApiProvider(widget.instance)).value;

    String? posterUrl;
    if (widget.series?.images != null && api != null) {
      try {
        final img = widget.series!.images.firstWhere((i) => i.coverType == 'poster');
        posterUrl = api.posterUrl(img);
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row wrapped in InkWell to toggle expansion
          InkWell(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(_isExpanded ? 0 : 20),
              bottomRight: Radius.circular(_isExpanded ? 0 : 20),
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 36,
                      height: 54,
                      child: posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (context, url, err) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.live_tv,
                                  size: 18,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.live_tv,
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.series?.title ?? 'Other / Unknown Releases',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.series != null)
                          Text(
                            '${widget.series!.network ?? ''} • ${widget.series!.year ?? ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                itemBuilder: (BuildContext context, int index) {
                  final item = widget.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: <Widget>[
                        _buildHistoryEventIcon(context, item.eventType),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.episode != null
                                    ? 'S${item.episode!.seasonNumber.toString().padLeft(2, '0')}E${item.episode!.episodeNumber.toString().padLeft(2, '0')} - ${item.episode!.title}'
                                    : item.sourceTitle ?? 'Unknown Episode',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateTime(item.date),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () => _showHistoryDetails(context, ref, widget.instance, item),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlainHistoryCard extends ConsumerWidget {
  const _PlainHistoryCard({
    required this.instance,
    required this.item,
  });

  final Instance instance;
  final SonarrHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _buildHistoryEventIcon(context, item.eventType),
        title: Text(
          item.episode != null
              ? 'S${item.episode!.seasonNumber.toString().padLeft(2, '0')}E${item.episode!.episodeNumber.toString().padLeft(2, '0')} - ${item.episode!.title}'
              : item.sourceTitle ?? 'Unknown Release',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.series != null)
              Text(
                item.series!.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            Text(
              _formatDateTime(item.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline, size: 20),
          onPressed: () => _showHistoryDetails(context, ref, instance, item),
        ),
      ),
    );
  }
}

class _BlocklistView extends ConsumerWidget {
  const _BlocklistView({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocklistAsync = ref.watch(sonarrBlocklistProvider(instance));
    final searchQuery = ref.watch(sonarrActivitySearchQueryProvider(instance)).toLowerCase();
    final grouped = ref.watch(sonarrActivityGroupedProvider(instance));

    return blocklistAsync.when(
      data: (List<SonarrBlocklistItem> items) {
        final filteredItems = items.where((item) {
          if (searchQuery.isEmpty) return true;
          final titleMatch = item.sourceTitle?.toLowerCase().contains(searchQuery) ?? false;
          final seriesMatch = item.series?.title.toLowerCase().contains(searchQuery) ?? false;
          final messageMatch = item.message?.toLowerCase().contains(searchQuery) ?? false;
          return titleMatch || seriesMatch || messageMatch;
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.block,
                  size: 48,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'No blocklisted items' : 'No blocklist matches search',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        if (grouped) {
          // Group by series
          final Map<int, List<SonarrBlocklistItem>> groupedMap = {};
          final List<SonarrSeries> seriesList = [];
          final List<SonarrBlocklistItem> unknownSeriesItems = [];

          for (final item in filteredItems) {
            if (item.series != null) {
              final seriesId = item.series!.id;
              if (!groupedMap.containsKey(seriesId)) {
                groupedMap[seriesId] = [];
                seriesList.add(item.series!);
              }
              groupedMap[seriesId]!.add(item);
            } else {
              unknownSeriesItems.add(item);
            }
          }

          // Sort series by date of latest event
          seriesList.sort((a, b) {
            final latestA = groupedMap[a.id]!.first.date ?? '';
            final latestB = groupedMap[b.id]!.first.date ?? '';
            return latestB.compareTo(latestA);
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sonarrBlocklistProvider(instance));
              await ref.read(sonarrBlocklistProvider(instance).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: seriesList.length + (unknownSeriesItems.isNotEmpty ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index < seriesList.length) {
                  final series = seriesList[index];
                  final seriesItems = groupedMap[series.id]!;
                  return _GroupedBlocklistCard(
                    instance: instance,
                    series: series,
                    items: seriesItems,
                  );
                } else {
                  return _GroupedBlocklistCard(
                    instance: instance,
                    series: null,
                    items: unknownSeriesItems,
                  );
                }
              },
            ),
          );
        } else {
          // Plain list layout
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sonarrBlocklistProvider(instance));
              await ref.read(sonarrBlocklistProvider(instance).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = filteredItems[index];
                return _PlainBlocklistCard(instance: instance, item: item);
              },
            ),
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load blocklist: $error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(sonarrBlocklistProvider(instance)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupedBlocklistCard extends ConsumerStatefulWidget {
  const _GroupedBlocklistCard({
    required this.instance,
    required this.series,
    required this.items,
  });

  final Instance instance;
  final SonarrSeries? series;
  final List<SonarrBlocklistItem> items;

  @override
  ConsumerState<_GroupedBlocklistCard> createState() => _GroupedBlocklistCardState();
}

class _GroupedBlocklistCardState extends ConsumerState<_GroupedBlocklistCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = ref.watch(sonarrApiProvider(widget.instance)).value;

    String? posterUrl;
    if (widget.series?.images != null && api != null) {
      try {
        final img = widget.series!.images.firstWhere((i) => i.coverType == 'poster');
        posterUrl = api.posterUrl(img);
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row wrapped in InkWell to toggle expansion
          InkWell(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(_isExpanded ? 0 : 20),
              bottomRight: Radius.circular(_isExpanded ? 0 : 20),
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 36,
                      height: 54,
                      child: posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (context, url, err) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.live_tv,
                                  size: 18,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.live_tv,
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.series?.title ?? 'Other / Unknown Releases',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.series != null)
                          Text(
                            '${widget.series!.network ?? ''} • ${widget.series!.year ?? ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                itemBuilder: (BuildContext context, int index) {
                  final item = widget.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.block_outlined,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.sourceTitle ?? 'Unknown Release',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.message != null && item.message!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    item.message!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontSize: 11,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Row(
                                children: <Widget>[
                                  if (item.indexer != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.indexer!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    _formatDateTime(item.date),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => _confirmDeleteBlocklistItem(context, ref, widget.instance, item),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlainBlocklistCard extends ConsumerWidget {
  const _PlainBlocklistCard({
    required this.instance,
    required this.item,
  });

  final Instance instance;
  final SonarrBlocklistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          Icons.block_outlined,
          color: theme.colorScheme.error,
          size: 22,
        ),
        title: Text(
          item.sourceTitle ?? 'Unknown Release',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.series != null)
              Text(
                item.series!.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (item.message != null && item.message!.isNotEmpty)
              Text(
                item.message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              _formatDateTime(item.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.error,
          ),
          onPressed: () => _confirmDeleteBlocklistItem(context, ref, instance, item),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}

// File level helper utilities to avoid code duplication
Widget _buildHistoryEventIcon(BuildContext context, String? eventType) {
  final theme = Theme.of(context);
  final String label = eventType?.toLowerCase() ?? '';

  IconData icon;
  Color color;

  switch (label) {
    case 'grabbed':
      icon = Icons.cloud_download_outlined;
      color = theme.colorScheme.secondary;
      break;
    case 'downloadfolderimported':
    case 'seriesfolderimported':
      icon = Icons.download_done_outlined;
      color = theme.colorScheme.primary;
      break;
    case 'downloadfailed':
      icon = Icons.error_outline;
      color = theme.colorScheme.error;
      break;
    case 'episodefiledeleted':
      icon = Icons.delete_outline;
      color = theme.colorScheme.outline;
      break;
    case 'episodefilerenamed':
      icon = Icons.edit_outlined;
      color = theme.colorScheme.primary;
      break;
    case 'downloadignored':
      icon = Icons.block_outlined;
      color = theme.colorScheme.outline;
      break;
    default:
      icon = Icons.history;
      color = theme.colorScheme.onSurfaceVariant;
  }

  return Icon(icon, color: color, size: 22);
}

void _showHistoryDetails(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  SonarrHistoryItem item,
) {
  final theme = Theme.of(context);
  final String eventType = item.eventType ?? 'Unknown';

  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'History Event Details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DetailRow(label: 'Event Type', value: eventType.toUpperCase()),
              _DetailRow(label: 'Date', value: _formatDateTime(item.date)),
              _DetailRow(label: 'Source Title', value: item.sourceTitle ?? 'None'),
              if (item.downloadId != null)
                _DetailRow(label: 'Download ID', value: item.downloadId!),
              if (item.data != null && item.data!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Metadata:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: item.data!.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          if (eventType.toLowerCase() == 'grabbed')
            TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.failHistoryItem(item.id);
                  ref.invalidate(sonarrHistoryProvider(instance));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Marked release as failed. Sonarr will search for replacements.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to flag release: $e')),
                    );
                  }
                }
              },
              child: const Text('Mark as Failed'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

void _confirmDeleteBlocklistItem(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  SonarrBlocklistItem item,
) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Remove from Blocklist',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this release from the blocklist? This allows Sonarr to grab this release again.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final api = await ref.read(sonarrApiProvider(instance).future);
                await api.deleteBlocklistItem(item.id);
                ref.invalidate(sonarrBlocklistProvider(instance));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item removed from blocklist.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove item: $e')),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );
}

String _formatSize(double bytes) {
  if (bytes <= 0) return '0 B';
  final double gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
  final double mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

String _formatDateTime(String? isoDate) {
  if (isoDate == null) return 'Unknown Date';
  try {
    final DateTime dt = DateTime.parse(isoDate).toLocal();
    final String monthStr = dt.month.toString().padLeft(2, '0');
    final String dayStr = dt.day.toString().padLeft(2, '0');
    final String hourStr = dt.hour.toString().padLeft(2, '0');
    final String minStr = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$monthStr-$dayStr $hourStr:$minStr';
  } catch (_) {
    return isoDate;
  }
}
