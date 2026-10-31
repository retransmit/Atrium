import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_models.dart';
import '../slskd_providers.dart';
import '../transfers/slskd_transfer_flat_tile.dart';
import '../transfers/slskd_transfer_peer_card.dart';
import '../transfers/slskd_transfers_stats_bar.dart';

/// Available sort criteria for slskd transfer feed.
enum SlskdTransferSort {
  activeFirst,
  speed,
  peerName,
  progress,
  size;

  String get label => switch (this) {
        SlskdTransferSort.activeFirst => 'Active First',
        SlskdTransferSort.speed => 'Fastest Speed',
        SlskdTransferSort.peerName => 'Peer Name (A-Z)',
        SlskdTransferSort.progress => 'Progress (%)',
        SlskdTransferSort.size => 'File Size (Largest)',
      };
}

/// Top-level Transfers tab in [SlskdHome].
/// Implements the Sonarr/Radarr-inspired ergonomics:
/// - AppBar: Hamburger menu + SearchBar + Grouped/Flat View Toggle
/// - Mini FAB: Bottom-right thumb-accessible FloatingActionButton.small for Sort & Filter
/// - Dual Mode:
///   - Grouped Mode (Peer Card -> Collapsible Folder -> Files)
///   - Flat Mode (Standalone Track Cards with peer tags)
/// - Compact dual-stream stats banner (downstream & upstream live metrics).
class SlskdTransfersTab extends ConsumerStatefulWidget {
  const SlskdTransfersTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<SlskdTransfersTab> createState() => _SlskdTransfersTabState();
}

class _SlskdTransfersTabState extends ConsumerState<SlskdTransfersTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGrouped = true;
  TransferDirection? _directionFilter;
  TransferCategory? _selectedCategory;
  SlskdTransferSort _selectedSort = SlskdTransferSort.activeFirst;
  String _searchQuery = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _directionFilter != null ||
      _selectedCategory != null ||
      _selectedSort != SlskdTransferSort.activeFirst;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    ref.listen<int>(
      slskdScrollToTopProvider((widget.instance, 0)),
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

    final downloadsAsync = ref.watch(slskdDownloadsProvider(widget.instance));
    final uploadsAsync = ref.watch(slskdUploadsProvider(widget.instance));

    final List<SlskdUserTransfers> downloads = downloadsAsync.value ?? const [];
    final List<SlskdUserTransfers> uploads = uploadsAsync.value ?? const [];

    // Only the first load, not every poll: an empty queue would otherwise
    // swap the whole list for a spinner and back on each refresh.
    final bool isLoading = (!downloadsAsync.hasValue || !uploadsAsync.hasValue) &&
        !downloadsAsync.hasError &&
        !uploadsAsync.hasError &&
        downloads.isEmpty &&
        uploads.isEmpty;
    final bool hasError = (downloadsAsync.hasError || uploadsAsync.hasError) &&
        downloads.isEmpty &&
        uploads.isEmpty;

    return Scaffold(
      floatingActionButton: _buildMiniFab(context, downloads: downloads, uploads: uploads),
      body: EasyRefresh(
        onRefresh: () async {
          try {
            await Future.wait([
              ref.refresh(slskdDownloadsProvider(widget.instance).future),
              ref.refresh(slskdUploadsProvider(widget.instance).future),
            ]);
          } catch (_) {
            // A failed refresh needs no snackbar: the providers hold the
            // error and the tab shows it in its error state.
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            // 1. Pinned AppBar (Hamburger + SearchBar + View Toggle)
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
                hintText: 'Search transfers or peers...',
                elevation: const WidgetStatePropertyAll<double>(0),
                backgroundColor: WidgetStatePropertyAll<Color>(
                  colorScheme.surfaceContainerHigh,
                ),
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: Insets.sm),
                ),
                leading: const Icon(Icons.search, size: 20),
                trailing: <Widget>[
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ),
                ],
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: _isGrouped ? 'Switch to plain list' : 'Switch to grouped view',
                  icon: Icon(
                    _isGrouped ? Icons.format_list_bulleted_rounded : Icons.group_work_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _isGrouped = !_isGrouped;
                    });
                  },
                ),
                const SizedBox(width: Insets.xs),
              ],
            ),

            if (isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(Insets.xl),
                    child: ExpressiveProgressIndicator(),
                  ),
                ),
              )
            else if (hasError)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
                        const SizedBox(height: Insets.md),
                        Text(
                          'Failed to load transfers: ${downloadsAsync.error ?? uploadsAsync.error}',
                          style: TextStyle(color: colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Insets.md),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          onPressed: () {
                            ref.invalidate(slskdDownloadsProvider(widget.instance));
                            ref.invalidate(slskdUploadsProvider(widget.instance));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._buildTransferContent(
                context,
                downloads: downloads,
                uploads: uploads,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniFab(
    BuildContext context, {
    required List<SlskdUserTransfers> downloads,
    required List<SlskdUserTransfers> uploads,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: 'slskd_transfers_sort_filter_fab',
      tooltip: 'Sort & Filter',
      elevation: 0,
      highlightElevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      backgroundColor:
          _hasActiveFilters ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
      foregroundColor:
          _hasActiveFilters ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
      onPressed: () => _openSortAndFilterSheet(
        context,
        downloads: downloads,
        uploads: uploads,
      ),
      child: _hasActiveFilters
          ? Badge(
              smallSize: 8,
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.tune_rounded, size: 20),
            )
          : const Icon(Icons.tune_rounded, size: 20),
    );
  }

  List<Widget> _buildTransferContent(
    BuildContext context, {
    required List<SlskdUserTransfers> downloads,
    required List<SlskdUserTransfers> uploads,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Filter and group transfers based on direction
    final List<SlskdPeerTransferGroup> allGroups = [];

    if (_directionFilter == null || _directionFilter == TransferDirection.download) {
      for (final u in downloads) {
        allGroups.add(SlskdPeerTransferGroup(direction: TransferDirection.download, user: u));
      }
    }

    if (_directionFilter == null || _directionFilter == TransferDirection.upload) {
      for (final u in uploads) {
        allGroups.add(SlskdPeerTransferGroup(direction: TransferDirection.upload, user: u));
      }
    }

    // Apply search, category filter, and sort to groups
    final List<SlskdPeerTransferGroup> filteredGroups = _filterAndSortGroups(
      allGroups,
      _searchQuery,
      _selectedCategory,
      _selectedSort,
    );

    return <Widget>[
      // 1. Dual-Stream Stats Banner (Speed pills + Counts + Clear completed)
      SliverToBoxAdapter(
        child: SlskdTransfersStatsBar(
          instance: widget.instance,
          downloads: downloads,
          uploads: uploads,
          selectedDirection: _directionFilter,
        ),
      ),

      // 2. Active Filter Chips Pill (visible only when filters are active)
      if (_hasActiveFilters)
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
            child: Row(
              children: <Widget>[
                Text(
                  'Filters active:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: Insets.xs),
                if (_directionFilter != null) ...<Widget>[
                  InputChip(
                    label: Text(
                      _directionFilter == TransferDirection.download ? 'Downloads' : 'Uploads',
                    ),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => setState(() => _directionFilter = null),
                  ),
                  const SizedBox(width: Insets.xs),
                ],
                if (_selectedCategory != null) ...<Widget>[
                  InputChip(
                    label: Text(_categoryLabel(_selectedCategory!)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => setState(() => _selectedCategory = null),
                  ),
                  const SizedBox(width: Insets.xs),
                ],
                if (_selectedSort != SlskdTransferSort.activeFirst) ...<Widget>[
                  InputChip(
                    label: Text(_selectedSort.label),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => setState(() => _selectedSort = SlskdTransferSort.activeFirst),
                  ),
                ],
                const SizedBox(width: Insets.sm),
                TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: _resetFilters,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),

      // 3. Feed List (Grouped or Flat) or Empty State
      if (filteredGroups.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(context),
        )
      else if (_isGrouped)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final group = filteredGroups[index];
              return SlskdTransferPeerCard(
                key: ValueKey('grouped_${group.direction.name}_${group.user.username}'),
                instance: widget.instance,
                userTransfers: group.user,
                direction: group.direction,
              );
            },
            childCount: filteredGroups.length,
          ),
        )
      else
        ..._buildFlatFeedList(filteredGroups),

      // Scroll clearance for Mini FAB
      if (filteredGroups.isNotEmpty)
        const SliverToBoxAdapter(
          child: SizedBox(height: Insets.xxl + Insets.lg),
        ),
    ];
  }

  List<Widget> _buildFlatFeedList(List<SlskdPeerTransferGroup> groups) {
    final List<SlskdFlatTransferItem> flatItems = _flattenGroups(groups, _selectedSort);

    return <Widget>[
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final item = flatItems[index];
            return SlskdTransferFlatTile(
              key: ValueKey('flat_${item.direction.name}_${item.transfer.id}'),
              instance: widget.instance,
              item: item,
            );
          },
          childCount: flatItems.length,
        ),
      ),
    ];
  }

  void _resetFilters() {
    setState(() {
      _directionFilter = null;
      _selectedCategory = null;
      _selectedSort = SlskdTransferSort.activeFirst;
    });
  }

  void _openSortAndFilterSheet(
    BuildContext context, {
    required List<SlskdUserTransfers> downloads,
    required List<SlskdUserTransfers> uploads,
  }) {
    final int dlCount = downloads.fold<int>(0, (sum, u) => sum + u.totalFileCount);
    final int ulCount = uploads.fold<int>(0, (sum, u) => sum + u.totalFileCount);
    final int totalCount = dlCount + ulCount;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Header Row
                    Row(
                      children: <Widget>[
                        Text(
                          'Sort & Filter',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _resetFilters();
                            setModalState(() {});
                          },
                          child: const Text('Reset All'),
                        ),
                      ],
                    ),
                    const Divider(),

                    // Section 1: Direction Scope
                    Text(
                      'Direction',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: Text('All ($totalCount)'),
                          selected: _directionFilter == null,
                          onSelected: (_) {
                            setModalState(() => _directionFilter = null);
                            setState(() => _directionFilter = null);
                          },
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.download_rounded, size: 16),
                          label: Text('Downloads ($dlCount)'),
                          selected: _directionFilter == TransferDirection.download,
                          onSelected: (_) {
                            setModalState(() => _directionFilter = TransferDirection.download);
                            setState(() => _directionFilter = TransferDirection.download);
                          },
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.upload_rounded, size: 16),
                          label: Text('Uploads ($ulCount)'),
                          selected: _directionFilter == TransferDirection.upload,
                          onSelected: (_) {
                            setModalState(() => _directionFilter = TransferDirection.upload);
                            setState(() => _directionFilter = TransferDirection.upload);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),

                    // Section 2: Lifecycle State
                    Text(
                      'Transfer Status',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('All States'),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setModalState(() => _selectedCategory = null);
                            setState(() => _selectedCategory = null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _selectedCategory == TransferCategory.inProgress,
                          onSelected: (_) {
                            setModalState(() => _selectedCategory = TransferCategory.inProgress);
                            setState(() => _selectedCategory = TransferCategory.inProgress);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Queued'),
                          selected: _selectedCategory == TransferCategory.queued,
                          onSelected: (_) {
                            setModalState(() => _selectedCategory = TransferCategory.queued);
                            setState(() => _selectedCategory = TransferCategory.queued);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Completed'),
                          selected: _selectedCategory == TransferCategory.completed,
                          onSelected: (_) {
                            setModalState(() => _selectedCategory = TransferCategory.completed);
                            setState(() => _selectedCategory = TransferCategory.completed);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Failed'),
                          selected: _selectedCategory == TransferCategory.failed,
                          onSelected: (_) {
                            setModalState(() => _selectedCategory = TransferCategory.failed);
                            setState(() => _selectedCategory = TransferCategory.failed);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),

                    // Section 3: Sort By
                    Text(
                      'Sort By',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      children: SlskdTransferSort.values.map((sort) {
                        return ChoiceChip(
                          label: Text(sort.label),
                          selected: _selectedSort == sort,
                          onSelected: (_) {
                            setModalState(() => _selectedSort = sort);
                            setState(() => _selectedSort = sort);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: Insets.lg),

                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. Search Query active but no matches
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.search_off_rounded, size: 56, color: colorScheme.outline),
              const SizedBox(height: Insets.md),
              Text(
                'No transfers match "$_searchQuery"',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Check your spelling or try searching with different keywords.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Search'),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    // 2. Filters active but no matches
    if (_hasActiveFilters) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.filter_alt_off_rounded, size: 56, color: colorScheme.outline),
              const SizedBox(height: Insets.md),
              Text(
                'No transfers match active filters',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Try clearing direction, status, or sorting filters.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Reset All Filters'),
                onPressed: _resetFilters,
              ),
            ],
          ),
        ),
      );
    }

    // 3. Queue is truly empty
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.cloud_download_outlined, size: 64, color: colorScheme.outline),
            const SizedBox(height: Insets.md),
            Text(
              'No transfers in queue',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Search Soulseek to find music, albums, and tracks.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.md),
            FilledButton.icon(
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search Music'),
              onPressed: () {
                ref.read(slskdActiveTabProvider(widget.instance).notifier).state = 1;
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(TransferCategory category) => switch (category) {
        TransferCategory.inProgress => 'Active',
        TransferCategory.queued => 'Queued',
        TransferCategory.completed => 'Completed',
        TransferCategory.failed => 'Failed',
      };

  /// Flattens all matching peer transfer groups into a flat list of individual files.
  static List<SlskdFlatTransferItem> _flattenGroups(
    List<SlskdPeerTransferGroup> groups,
    SlskdTransferSort sort,
  ) {
    final List<SlskdFlatTransferItem> items = [];
    for (final g in groups) {
      for (final d in g.user.directories) {
        for (final f in d.files) {
          items.add(
            SlskdFlatTransferItem(
              direction: g.direction,
              username: g.user.username,
              directory: d.directory,
              transfer: f,
            ),
          );
        }
      }
    }

    switch (sort) {
      case SlskdTransferSort.activeFirst:
        items.sort((a, b) {
          if (a.transfer.category == TransferCategory.inProgress &&
              b.transfer.category != TransferCategory.inProgress) {
            return -1;
          }
          if (b.transfer.category == TransferCategory.inProgress &&
              a.transfer.category != TransferCategory.inProgress) {
            return 1;
          }
          final speedComp = b.transfer.liveSpeed.compareTo(a.transfer.liveSpeed);
          if (speedComp != 0) return speedComp;
          return a.transfer.filename.toLowerCase().compareTo(b.transfer.filename.toLowerCase());
        });
        break;
      case SlskdTransferSort.speed:
        items.sort((a, b) {
          final comp = b.transfer.liveSpeed.compareTo(a.transfer.liveSpeed);
          if (comp != 0) return comp;
          return a.transfer.filename.toLowerCase().compareTo(b.transfer.filename.toLowerCase());
        });
        break;
      case SlskdTransferSort.peerName:
        items.sort((a, b) {
          final comp = a.username.toLowerCase().compareTo(b.username.toLowerCase());
          if (comp != 0) return comp;
          return a.transfer.filename.toLowerCase().compareTo(b.transfer.filename.toLowerCase());
        });
        break;
      case SlskdTransferSort.progress:
        items.sort((a, b) {
          final comp = b.transfer.progress.compareTo(a.transfer.progress);
          if (comp != 0) return comp;
          return a.transfer.filename.toLowerCase().compareTo(b.transfer.filename.toLowerCase());
        });
        break;
      case SlskdTransferSort.size:
        items.sort((a, b) {
          final comp = b.transfer.size.compareTo(a.transfer.size);
          if (comp != 0) return comp;
          return a.transfer.filename.toLowerCase().compareTo(b.transfer.filename.toLowerCase());
        });
        break;
    }

    return items;
  }

  /// Filters and sorts peer transfer groups.
  static List<SlskdPeerTransferGroup> _filterAndSortGroups(
    List<SlskdPeerTransferGroup> groups,
    String query,
    TransferCategory? category,
    SlskdTransferSort sort,
  ) {
    final List<SlskdPeerTransferGroup> result = [];
    final lowerQuery = query.toLowerCase();

    for (final group in groups) {
      final user = group.user;
      final bool userMatches = lowerQuery.isEmpty || user.username.toLowerCase().contains(lowerQuery);

      final List<SlskdDirectoryTransfers> filteredDirs = [];
      for (final dir in user.directories) {
        final bool dirMatches = lowerQuery.isEmpty || dir.directory.toLowerCase().contains(lowerQuery);

        final List<SlskdTransfer> filteredFiles = [];
        for (final file in dir.files) {
          final bool fileMatches =
              userMatches || dirMatches || file.filename.toLowerCase().contains(lowerQuery);
          final bool categoryMatches = category == null || file.category == category;

          if (fileMatches && categoryMatches) {
            filteredFiles.add(file);
          }
        }

        if (filteredFiles.isNotEmpty) {
          // Sort files within directory: active first, then speed, then name
          filteredFiles.sort((a, b) {
            if (a.category == TransferCategory.inProgress && b.category != TransferCategory.inProgress) {
              return -1;
            }
            if (b.category == TransferCategory.inProgress && a.category != TransferCategory.inProgress) {
              return 1;
            }
            final speedComp = b.liveSpeed.compareTo(a.liveSpeed);
            if (speedComp != 0) return speedComp;
            return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
          });

          filteredDirs.add(
            SlskdDirectoryTransfers(
              directory: dir.directory,
              fileCount: filteredFiles.length,
              files: filteredFiles,
            ),
          );
        }
      }

      if (filteredDirs.isNotEmpty) {
        result.add(
          SlskdPeerTransferGroup(
            direction: group.direction,
            user: SlskdUserTransfers(
              username: user.username,
              directories: filteredDirs,
            ),
          ),
        );
      }
    }

    // Sort peer groups
    switch (sort) {
      case SlskdTransferSort.activeFirst:
        result.sort((a, b) {
          final bool aActive = a.user.directories.any(
            (d) => d.files.any((f) => f.category == TransferCategory.inProgress),
          );
          final bool bActive = b.user.directories.any(
            (d) => d.files.any((f) => f.category == TransferCategory.inProgress),
          );
          if (aActive && !bActive) return -1;
          if (bActive && !aActive) return 1;
          final speedComp = b.user.liveSpeed.compareTo(a.user.liveSpeed);
          if (speedComp != 0) return speedComp;
          return a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase());
        });
        break;
      case SlskdTransferSort.speed:
        result.sort((a, b) {
          final comp = b.user.liveSpeed.compareTo(a.user.liveSpeed);
          if (comp != 0) return comp;
          return a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase());
        });
        break;
      case SlskdTransferSort.peerName:
        result.sort((a, b) => a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase()));
        break;
      case SlskdTransferSort.progress:
        result.sort((a, b) {
          final aProg = a.user.totalBytes > 0 ? a.user.transferredBytes / a.user.totalBytes : 0.0;
          final bProg = b.user.totalBytes > 0 ? b.user.transferredBytes / b.user.totalBytes : 0.0;
          final comp = bProg.compareTo(aProg);
          if (comp != 0) return comp;
          return a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase());
        });
        break;
      case SlskdTransferSort.size:
        result.sort((a, b) {
          final comp = b.user.totalBytes.compareTo(a.user.totalBytes);
          if (comp != 0) return comp;
          return a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase());
        });
        break;
    }

    return result;
  }
}
