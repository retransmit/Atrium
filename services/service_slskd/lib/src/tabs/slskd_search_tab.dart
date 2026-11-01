import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_models.dart';
import '../searches/slskd_search_album_card.dart';
import '../searches/slskd_search_filter_sheet.dart';
import '../searches/slskd_search_flat_tile.dart';
import '../searches/slskd_search_models_ui.dart';
import '../slskd_providers.dart';

/// Top-level P2P Music Search tab in [SlskdHome].
/// Implements:
/// - Pinned SliverAppBar with SearchBar & Grouped/Flat toggle
/// - Concurrent Active Searches ribbon with live response counters
/// - Dual Mode: Album Grouped View (with 1-tap "Download Album") vs. Flat Track Stream
/// - Mini FAB for thumb-zone Sort & Filter modal sheet
/// - Instant batch and single-file download enqueueing with "View Transfers" navigation handoff.
class SlskdSearchTab extends ConsumerStatefulWidget {
  const SlskdSearchTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<SlskdSearchTab> createState() => _SlskdSearchTabState();
}

class _SlskdSearchTabState extends ConsumerState<SlskdSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGrouped = true;

  // Filter & sort state
  SlskdSearchFormatFilter _selectedFormat = SlskdSearchFormatFilter.all;
  SlskdSearchSort _selectedSort = SlskdSearchSort.fastestSpeed;
  bool _freeSlotOnly = false;
  bool _hideLocked = true;

  bool get _hasActiveFilters =>
      _selectedFormat != SlskdSearchFormatFilter.all ||
      _selectedSort != SlskdSearchSort.fastestSpeed ||
      _freeSlotOnly ||
      !_hideLocked;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedFormat = SlskdSearchFormatFilter.all;
      _selectedSort = SlskdSearchSort.fastestSpeed;
      _freeSlotOnly = false;
      _hideLocked = true;
    });
  }

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      final search = await api.initiateSearch(SlskdSearchRequest(searchText: trimmed));
      if (!mounted) return;
      ref.read(slskdSelectedSearchIdProvider(widget.instance).notifier).state = search.id;
      ref.invalidate(slskdSearchesProvider(widget.instance));
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to initiate search: $e';
        if (e is DioException) {
          if (e.response?.statusCode == 429 || e.response?.statusCode == 409) {
            msg = 'A search is already in progress. slskd permits only 1 concurrent search.';
          } else if (e.response?.data != null) {
            msg = 'Search rejected: ${e.response?.data}';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopSearch(String id) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      await api.stopSearch(id);
      if (!mounted) return;
      ref.invalidate(slskdSearchesProvider(widget.instance));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search stopped')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to stop search: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAlbum(SlskdAlbumGroup group, [String? searchId]) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      final EnqueueDownloadBatchResponse response = await api.enqueueBatch(
        EnqueueDownloadBatchRequest(
          username: group.username,
          searchId: searchId,
          options: EnqueueDownloadBatchOptions(
            externalId: '${group.username}_${DateTime.now().millisecondsSinceEpoch}_${group.albumTitle.hashCode.abs()}',
          ),
          // The peer refuses locked files, so leave them out of the batch.
          files: group.files
              .where((f) => !f.isLocked)
              .map(
                (f) => EnqueueDownloadBatchItem(
                  filename: f.filename,
                  size: f.size,
                ),
              )
              .toList(),
        ),
      );

      if (mounted) {
        ref.invalidate(slskdDownloadsProvider(widget.instance));
        final enqueuedCount = response.batch?.transfers.length ?? 0;
        final failureCount = response.failures.length;

        if (enqueuedCount == 0 && failureCount > 0) {
          final firstFailure = response.failures.first.message ?? 'already downloading or queued';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not queue "${group.albumTitle}": $firstFailure',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else {
          final summaryMsg = failureCount > 0
              ? 'Downloading "${group.albumTitle}" ($enqueuedCount tracks queued, $failureCount failed/already queued)'
              : 'Downloading "${group.albumTitle}" ($enqueuedCount tracks)';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(summaryMsg),
              action: SnackBarAction(
                label: 'View Transfers',
                onPressed: () {
                  ref.read(slskdActiveTabProvider(widget.instance).notifier).state = 0;
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to enqueue album: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadTrack(
    SlskdAlbumGroup group,
    SlskdSearchFile file, [
    String? searchId,
  ]) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      final EnqueueDownloadBatchResponse response = await api.enqueueBatch(
        EnqueueDownloadBatchRequest(
          username: group.username,
          searchId: searchId,
          files: <EnqueueDownloadBatchItem>[
            EnqueueDownloadBatchItem(filename: file.filename, size: file.size),
          ],
        ),
      );

      if (mounted) {
        ref.invalidate(slskdDownloadsProvider(widget.instance));
        if (response.failures.isNotEmpty) {
          final failMsg = response.failures.first.message ?? 'already queued or downloading';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not queue "${file.trackTitle}": $failMsg',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading "${file.trackTitle}"'),
              action: SnackBarAction(
                label: 'View Transfers',
                onPressed: () {
                  ref.read(slskdActiveTabProvider(widget.instance).notifier).state = 0;
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to enqueue track: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext _) => SlskdSearchFilterSheet(
        selectedFormat: _selectedFormat,
        selectedSort: _selectedSort,
        freeSlotOnly: _freeSlotOnly,
        hideLocked: _hideLocked,
        onApply: ({
          required SlskdSearchFormatFilter format,
          required SlskdSearchSort sort,
          required bool freeSlotOnly,
          required bool hideLocked,
        }) {
          setState(() {
            _selectedFormat = format;
            _selectedSort = sort;
            _freeSlotOnly = freeSlotOnly;
            _hideLocked = hideLocked;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    ref.listen<int>(
      slskdScrollToTopProvider((widget.instance, 1)),
      (previous, next) {
        if (next > 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );

    final searchesAsync = ref.watch(slskdSearchesProvider(widget.instance));
    final List<SlskdSearch> searches = searchesAsync.value ?? const <SlskdSearch>[];
    final selectedSearchId = ref.watch(slskdSelectedSearchIdProvider(widget.instance));

    // Determine current active search
    SlskdSearch? activeSearch;
    if (selectedSearchId != null) {
      activeSearch = searches.where((s) => s.id == selectedSearchId).firstOrNull;
    }
    if (activeSearch == null && searches.isNotEmpty && selectedSearchId == null) {
      activeSearch = searches.first;
    }

    return Scaffold(
      floatingActionButton: searches.isNotEmpty ? _buildMiniFab(context) : null,
      body: SafeArea(
        bottom: false,
        child: EasyRefresh(
          onRefresh: () async {
            ref.invalidate(slskdSearchesProvider(widget.instance));
            final selectedId =
                ref.read(slskdSelectedSearchIdProvider(widget.instance));
            if (selectedId != null) {
              ref.invalidate(
                slskdSearchResponsesProvider((widget.instance, selectedId)),
              );
            }
          },
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
            // 1. Pinned Search & App Bar
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: true,
              scrolledUnderElevation: 0.0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: colorScheme.surface,
              toolbarHeight: 68,
              leadingWidth: 52,
              leading: (widget.onOpenDrawer != null ||
                      (Scaffold.maybeOf(context)?.hasDrawer ?? false))
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        if (widget.onOpenDrawer != null) {
                          widget.onOpenDrawer!();
                        } else {
                          Scaffold.maybeOf(context)?.openDrawer();
                        }
                      },
                    )
                  : null,
              titleSpacing: Insets.xs,
              title: SearchBar(
                controller: _searchController,
                hintText: 'Search artist, album, track...',
                elevation: const WidgetStatePropertyAll<double>(0),
                backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surfaceContainerHigh),
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: Insets.sm),
                ),
                leading: const Icon(Icons.search, size: 20),
                onChanged: (_) => setState(() {}),
                trailing: <Widget>[
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(_searchController.clear),
                    ),
                ],
                onSubmitted: _executeSearch,
              ),
              actions: <Widget>[
                if (activeSearch != null && !activeSearch.isComplete)
                  IconButton(
                    tooltip: 'Stop search',
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: () => _stopSearch(activeSearch!.id),
                  ),
                IconButton(
                  tooltip: _isGrouped ? 'Switch to plain list' : 'Switch to album groups',
                  icon: Icon(
                    _isGrouped ? Icons.format_list_bulleted_rounded : Icons.album_outlined,
                  ),
                  onPressed: () => setState(() => _isGrouped = !_isGrouped),
                ),
                const SizedBox(width: Insets.xs),
              ],
            ),

            // 2. Concurrent Active Searches Ribbon
            if (searches.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 6),
                    itemCount: searches.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Insets.xs),
                    itemBuilder: (BuildContext context, int index) {
                      final s = searches[index];
                      final bool isSelected = s.id == activeSearch?.id;

                      return InputChip(
                        selected: isSelected,
                        avatar: !s.isComplete
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: ExpressiveProgressIndicator(
                                  strokeWidth: 2,
                                  color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                              ),
                        label: Text('${s.searchText} (${s.fileCount})'),
                        onSelected: (_) {
                          ref.read(slskdSelectedSearchIdProvider(widget.instance).notifier).state = s.id;
                        },
                        onDeleted: () async {
                          try {
                            final api = await ref.read(slskdApiProvider(widget.instance).future);
                            await api.deleteSearch(s.id);
                            if (!mounted) return;
                            ref.invalidate(slskdSearchesProvider(widget.instance));
                            if (ref.read(slskdSelectedSearchIdProvider(widget.instance)) == s.id) {
                              ref.read(slskdSelectedSearchIdProvider(widget.instance).notifier).state = null;
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete search: $e',
                                    style: TextStyle(color: colorScheme.onError),
                                  ),
                                  backgroundColor: colorScheme.error,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ),

            // 3. Active Filters Strip (if any)
            if (_hasActiveFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'Filters active:',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      if (_selectedFormat != SlskdSearchFormatFilter.all) ...<Widget>[
                        InputChip(
                          label: Text(_selectedFormat.label),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setState(() => _selectedFormat = SlskdSearchFormatFilter.all),
                        ),
                        const SizedBox(width: Insets.xs),
                      ],
                      if (_freeSlotOnly) ...<Widget>[
                        InputChip(
                          label: const Text('Free Slot'),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setState(() => _freeSlotOnly = false),
                        ),
                        const SizedBox(width: Insets.xs),
                      ],
                      if (!_hideLocked) ...<Widget>[
                        InputChip(
                          label: const Text('Include Locked'),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setState(() => _hideLocked = true),
                        ),
                        const SizedBox(width: Insets.xs),
                      ],
                      if (_selectedSort != SlskdSearchSort.fastestSpeed) ...<Widget>[
                        InputChip(
                          label: Text(_selectedSort.label),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setState(() => _selectedSort = SlskdSearchSort.fastestSpeed),
                        ),
                      ],
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: _resetFilters,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Search Content Feed or Empty States
            if (activeSearch == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildInitialEmptyState(context),
              )
            else
              ..._buildSearchContent(context, activeSearch),

            // Bottom clearance for Mini FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: Insets.xxl + Insets.lg),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMiniFab(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: 'slskd_search_sort_filter_fab',
      tooltip: 'Sort & Filter Results',
      elevation: 0,
      highlightElevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      backgroundColor:
          _hasActiveFilters ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
      foregroundColor:
          _hasActiveFilters ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
      onPressed: () => _openFilterSheet(context),
      child: _hasActiveFilters
          ? Badge(
              smallSize: 8,
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.tune_rounded, size: 20),
            )
          : const Icon(Icons.tune_rounded, size: 20),
    );
  }

  List<Widget> _buildSearchContent(BuildContext context, SlskdSearch search) {
    // If responses are embedded on the search model or need provider lookup
    final responsesAsync = ref.watch(slskdSearchResponsesProvider((widget.instance, search.id)));
    final List<SlskdSearchResponse> responses =
        responsesAsync.value ?? search.responses;

    // Group files into SlskdAlbumGroup by directory and peer
    final List<SlskdAlbumGroup> rawGroups = _groupResponses(responses);

    // Filter and sort album groups
    final List<SlskdAlbumGroup> filteredGroups = _filterAndSortGroups(rawGroups);

    // Waiting on the first responses only: they poll, and a finished search
    // with none would otherwise flip back to searching on every refresh.
    if ((!search.isComplete || !responsesAsync.hasValue) &&
        rawGroups.isEmpty &&
        !responsesAsync.hasError) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const ExpressiveProgressIndicator(),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Searching Soulseek network...',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Querying connected peers for "${search.searchText}"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: Insets.md),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Stop Search'),
                    onPressed: () => _stopSearch(search.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (filteredGroups.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildNoMatchesState(
            context,
            search,
            error: responsesAsync.hasError ? responsesAsync.error : null,
          ),
        ),
      ];
    }

    if (_isGrouped) {
      return <Widget>[
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final group = filteredGroups[index];
              return SlskdSearchAlbumCard(
                key: ValueKey('album_${group.username}_${group.albumDirectory}'),
                instance: widget.instance,
                group: group,
                onDownloadAlbum: (group) => _downloadAlbum(group, search.id),
                onDownloadTrack: (group, file) =>
                    _downloadTrack(group, file, search.id),
              );
            },
            childCount: filteredGroups.length,
          ),
        ),
      ];
    }

    // Flat view: list of individual tracks
    final List<({SlskdAlbumGroup group, SlskdSearchFile file})> flatItems = [];
    for (final group in filteredGroups) {
      for (final file in group.files) {
        flatItems.add((group: group, file: file));
      }
    }

    return <Widget>[
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final item = flatItems[index];
            return SlskdSearchFlatTile(
              key: ValueKey('flat_${item.group.username}_${item.file.filename}'),
              instance: widget.instance,
              file: item.file,
              group: item.group,
              onDownload: () =>
                  _downloadTrack(item.group, item.file, search.id),
            );
          },
          childCount: flatItems.length,
        ),
      ),
    ];
  }

  Widget _buildInitialEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.library_music_rounded, size: 64, color: colorScheme.outline),
            const SizedBox(height: Insets.md),
            Text(
              'P2P Music Search',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Search artists, albums, or tracks across millions of Soulseek peer shares.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesState(
    BuildContext context,
    SlskdSearch search, {
    Object? error,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // A failed search is complete with no responses too, but it is not an
    // empty result, so it must not read as one.
    final bool failed = search.isErrored || error != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              failed
                  ? Icons.error_outline_rounded
                  : (_hasActiveFilters ? Icons.filter_alt_off_rounded : Icons.search_off_rounded),
              size: 56,
              color: failed ? colorScheme.error : colorScheme.outline,
            ),
            const SizedBox(height: Insets.md),
            Text(
              failed
                  ? 'Search for "${search.searchText}" failed'
                  : (_hasActiveFilters
                      ? 'No results match active filters'
                      : 'No results found for "${search.searchText}"'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              failed
                  ? (error != null
                      ? '$error'
                      : 'slskd could not run it. Check that it is connected to Soulseek in System.')
                  : (_hasActiveFilters
                      ? 'Try relaxing audio format or slot availability filters.'
                      : 'Check spelling or try broader artist or album keywords.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_hasActiveFilters && !failed) ...<Widget>[
              const SizedBox(height: Insets.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Reset All Filters'),
                onPressed: _resetFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<SlskdAlbumGroup> _groupResponses(List<SlskdSearchResponse> responses) {
    final List<SlskdAlbumGroup> groups = [];

    for (final response in responses) {
      final Map<String, List<SlskdSearchFile>> dirMap = {};
      final List<SlskdSearchFile> allFiles = [
        ...response.files,
        if (!_hideLocked) ...response.lockedFiles,
      ];

      for (final file in allFiles) {
        if (_hideLocked && file.isLocked) continue;

        // Apply audio format filter
        if (!_selectedFormat.matchesExtension(file.extension)) continue;

        final dir = file.albumDirectory;
        dirMap.putIfAbsent(dir, () => []).add(file);
      }

      for (final entry in dirMap.entries) {
        // Natural track sort by filename
        entry.value.sort((a, b) => a.filename.compareTo(b.filename));

        groups.add(
          SlskdAlbumGroup(
            albumDirectory: entry.key,
            username: response.username,
            hasFreeUploadSlot: response.hasFreeUploadSlot,
            queueLength: response.queueLength,
            uploadSpeed: response.uploadSpeed,
            files: entry.value,
          ),
        );
      }
    }

    return groups;
  }

  List<SlskdAlbumGroup> _filterAndSortGroups(List<SlskdAlbumGroup> groups) {
    var result = groups;

    if (_freeSlotOnly) {
      result = result.where((g) => g.hasFreeUploadSlot).toList();
    }

    switch (_selectedSort) {
      case SlskdSearchSort.fastestSpeed:
        result.sort((a, b) => b.uploadSpeed.compareTo(a.uploadSpeed));
        break;
      case SlskdSearchSort.shortestQueue:
        result.sort((a, b) => a.queueLength.compareTo(b.queueLength));
        break;
      case SlskdSearchSort.highestQuality:
        result.sort((a, b) {
          final aIsFlac = a.qualityBadge.contains('FLAC');
          final bIsFlac = b.qualityBadge.contains('FLAC');
          if (aIsFlac && !bIsFlac) return -1;
          if (!aIsFlac && bIsFlac) return 1;
          final aMaxBitrate = a.files.fold<int>(
            0,
            (max, f) => (f.bitRate ?? 0) > max ? (f.bitRate ?? 0) : max,
          );
          final bMaxBitrate = b.files.fold<int>(
            0,
            (max, f) => (f.bitRate ?? 0) > max ? (f.bitRate ?? 0) : max,
          );
          if (aMaxBitrate != bMaxBitrate) {
            return bMaxBitrate.compareTo(aMaxBitrate);
          }
          return b.uploadSpeed.compareTo(a.uploadSpeed);
        });
        break;
      case SlskdSearchSort.fileCount:
        result.sort((a, b) => b.files.length.compareTo(a.files.length));
        break;
    }

    return result;
  }
}
