import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lidarr_formatters.dart';
import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';

/// Sorting options for artist activity history.
enum ArtistHistorySort {
  dateDesc('Newest First', Icons.schedule),
  dateAsc('Oldest First', Icons.history),
  titleAsc('Title (A–Z)', Icons.sort_by_alpha),
  titleDesc('Title (Z–A)', Icons.sort_by_alpha),
  qualityDesc('Quality', Icons.high_quality_outlined),
  eventType('Event Type', Icons.category_outlined);

  const ArtistHistorySort(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Activity history tab specifically displaying events for an individual artist.
class ArtistHistoryView extends ConsumerStatefulWidget {
  const ArtistHistoryView({
    required this.instance,
    required this.artistId,
    this.artistName,
    this.showAppBar = false,
    super.key,
  });

  final Instance instance;
  final int artistId;
  final String? artistName;
  final bool showAppBar;

  @override
  ConsumerState<ArtistHistoryView> createState() => _ArtistHistoryViewState();
}

class _ArtistHistoryViewState extends ConsumerState<ArtistHistoryView>
    with WidgetsBindingObserver {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _scrollController;
  double _lastBottomInset = 0.0;
  bool _isSearchVisible = false;
  String _filterQuery = '';
  String _selectedFilter = 'all';
  ArtistHistorySort _sortOption = ArtistHistorySort.dateDesc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
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

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedFilter != 'all') count++;
    if (_sortOption != ArtistHistorySort.dateDesc) count++;
    if (_filterQuery.trim().isNotEmpty) count++;
    return count;
  }

  IconData _getEventIcon(EntityHistoryEventType? eventType) {
    switch (eventType) {
      case EntityHistoryEventType.grabbed:
        return Icons.cloud_download_outlined;
      case EntityHistoryEventType.downloadImported:
      case EntityHistoryEventType.artistFolderImported:
      case EntityHistoryEventType.trackFileImported:
        return Icons.check_circle_outline;
      case EntityHistoryEventType.downloadFailed:
        return Icons.error_outline;
      case EntityHistoryEventType.trackFileDeleted:
        return Icons.delete_outline;
      case EntityHistoryEventType.trackFileRenamed:
        return Icons.drive_file_rename_outline;
      case EntityHistoryEventType.trackFileRetagged:
        return Icons.label_outline;
      default:
        return Icons.history;
    }
  }

  Color _getEventColor(EntityHistoryEventType? eventType, ColorScheme cs) {
    switch (eventType) {
      case EntityHistoryEventType.grabbed:
        return cs.primary;
      case EntityHistoryEventType.downloadImported:
      case EntityHistoryEventType.artistFolderImported:
      case EntityHistoryEventType.trackFileImported:
        return cs.tertiary;
      case EntityHistoryEventType.downloadFailed:
        return cs.error;
      case EntityHistoryEventType.trackFileDeleted:
        return cs.outline;
      case EntityHistoryEventType.trackFileRenamed:
        return cs.secondary;
      case EntityHistoryEventType.trackFileRetagged:
        return Colors.teal;
      default:
        return cs.secondary;
    }
  }

  Future<void> _markFailed(HistoryResource item) async {
    final int? id = item.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Failed?'),
        content: Text(
          'Mark "${item.sourceTitle ?? 'item'}" as failed and blocklist this release?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark Failed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final resp = await api.history.postHistoryFailedById(id: id);
      if (resp.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as failed and added to blocklist'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          ref.invalidate(
            lidarrArtistHistoryProvider(
              (widget.instance, widget.artistId),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed: ${resp.error?.message ?? 'Unknown error'}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFilterAndSortSheet(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle & Header
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 22, color: cs.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Filter & Sort History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_activeFilterCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFilter = 'all';
                                _sortOption = ArtistHistorySort.dateDesc;
                                _filterQuery = '';
                                _searchController.clear();
                              });
                              setSheetState(() {});
                            },
                            child: const Text('Reset'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort section
                    Text(
                      'SORT BY',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ArtistHistorySort.values.map((ArtistHistorySort opt) {
                        final bool isSelected = _sortOption == opt;
                        return ChoiceChip(
                          avatar: Icon(
                            opt.icon,
                            size: 16,
                            color: isSelected
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                          label: Text(
                            opt.label,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() {
                                _sortOption = opt;
                              });
                              setSheetState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Filter section
                    Text(
                      'EVENT TYPE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypeChip(
                          'all',
                          'All Events',
                          Icons.all_inclusive,
                          setSheetState,
                          cs,
                        ),
                        _buildTypeChip(
                          'grabbed',
                          'Grabbed',
                          Icons.cloud_download_outlined,
                          setSheetState,
                          cs,
                        ),
                        _buildTypeChip(
                          'imported',
                          'Imported',
                          Icons.check_circle_outline,
                          setSheetState,
                          cs,
                        ),
                        _buildTypeChip(
                          'renamed',
                          'Renamed',
                          Icons.drive_file_rename_outline,
                          setSheetState,
                          cs,
                        ),
                        _buildTypeChip(
                          'retagged',
                          'Retagged',
                          Icons.label_outline,
                          setSheetState,
                          cs,
                        ),
                        _buildTypeChip(
                          'deleted',
                          'Deleted',
                          Icons.delete_outline,
                          setSheetState,
                          cs,
                        ),
                        _buildTypeChip(
                          'failed',
                          'Failed',
                          Icons.error_outline,
                          setSheetState,
                          cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('Apply'),
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

  Widget _buildTypeChip(
    String key,
    String label,
    IconData icon,
    StateSetter setSheetState,
    ColorScheme cs,
  ) {
    final bool isSelected = _selectedFilter == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = key;
          });
          setSheetState(() {});
        }
      },
    );
  }

  void _showHistoryDetails(BuildContext context, HistoryResource item) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Map<String, dynamic>? data = item.data;
    final String? qualityName = item.quality?.quality?.name;
    final bool canMarkFailed =
        item.eventType == EntityHistoryEventType.grabbed && item.id != null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'History Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (canMarkFailed)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                      ),
                      icon: const Icon(Icons.error_outline, size: 18),
                      label: const Text('Mark Failed'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _markFailed(item);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.sourceTitle ?? item.album?.title ?? 'Unknown Release',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.artist?.artistName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Artist: ${item.artist?.artistName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (item.album?.title != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Album: ${item.album?.title}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const Divider(height: 24),
              _buildDetailRow(
                'Event Type',
                item.eventType?.value ?? 'Unknown',
                cs,
              ),
              if (item.date != null)
                _buildDetailRow(
                  'Date',
                  item.date!.replaceAll('T', ' ').replaceAll('Z', ' UTC'),
                  cs,
                ),
              if (qualityName != null)
                _buildDetailRow('Quality', qualityName, cs),
              if (item.downloadId != null && item.downloadId!.isNotEmpty)
                _buildDetailRow('Download ID', item.downloadId!, cs),
              if (data != null && data.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Event Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...data.entries.map((e) {
                  final String k = e.key;
                  final String v = e.value?.toString() ?? '';
                  if (v.isEmpty) return const SizedBox.shrink();
                  return _buildDetailRow(k, v, cs);
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<List<HistoryResource>> asyncHistory = ref
        .watch(lidarrArtistHistoryProvider((widget.instance, widget.artistId)));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: cs.surface,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity History',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.artistName != null)
                    Text(
                      widget.artistName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon:
                      Icon(_isSearchVisible ? Icons.search_off : Icons.search),
                  tooltip: 'Search History',
                  onPressed: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                      if (!_isSearchVisible) {
                        _filterQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFilterAndSortSheet(context),
        icon: _activeFilterCount > 0
            ? Badge(
                label: Text('$_activeFilterCount'),
                backgroundColor: cs.error,
                child: const Icon(Icons.tune_rounded),
              )
            : const Icon(Icons.tune_rounded),
        label: Text(
          _activeFilterCount > 0
              ? 'Filtered ($_activeFilterCount)'
              : 'Filter & Sort',
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // Collapsible Search bar
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _isSearchVisible || _filterQuery.isNotEmpty
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Filter artist history...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _filterQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _filterQuery = '';
                                });
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _isSearchVisible = false;
                                  _filterQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      isDense: true,
                    ),
                    onChanged: (String val) {
                      setState(() {
                        _filterQuery = val;
                      });
                    },
                  ),
                ),
              ),
            ),

            // Active filter indicator bar
            if (_activeFilterCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Sort: ${_sortOption.label}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    if (_selectedFilter != 'all') ...[
                      Text(
                        ' • Type: ${_selectedFilter.isNotEmpty ? _selectedFilter[0].toUpperCase() + _selectedFilter.substring(1) : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'all';
                          _sortOption = ArtistHistorySort.dateDesc;
                          _filterQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: cs.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content List
            Expanded(
              child: asyncHistory.when(
                loading: () =>
                    const Center(child: ExpressiveProgressIndicator()),
                error: (Object error, StackTrace stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load history',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          onPressed: () => ref.invalidate(
                            lidarrArtistHistoryProvider(
                              (widget.instance, widget.artistId),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (List<HistoryResource> rawHistory) {
                  if (rawHistory.isEmpty) {
                    return const Center(
                      child: EmptyView(
                        icon: Icons.history_outlined,
                        title: 'No History',
                        message:
                            'No activity history recorded for this artist.',
                      ),
                    );
                  }

                  // Filter by query
                  final List<HistoryResource> filtered =
                      rawHistory.where((HistoryResource item) {
                    if (_filterQuery.trim().isNotEmpty) {
                      final String q = _filterQuery.trim().toLowerCase();
                      final String title =
                          (item.sourceTitle ?? item.album?.title ?? '')
                              .toLowerCase();
                      final String eventType =
                          (item.eventType?.value ?? '').toLowerCase();
                      final String quality =
                          (item.quality?.quality?.name ?? '').toLowerCase();
                      if (!title.contains(q) &&
                          !eventType.contains(q) &&
                          !quality.contains(q)) {
                        return false;
                      }
                    }

                    if (_selectedFilter != 'all') {
                      final EntityHistoryEventType? t = item.eventType;
                      switch (_selectedFilter) {
                        case 'grabbed':
                          if (t != EntityHistoryEventType.grabbed) return false;
                        case 'imported':
                          if (t != EntityHistoryEventType.downloadImported &&
                              t !=
                                  EntityHistoryEventType.artistFolderImported &&
                              t != EntityHistoryEventType.trackFileImported) {
                            return false;
                          }
                        case 'renamed':
                          if (t != EntityHistoryEventType.trackFileRenamed) {
                            return false;
                          }
                        case 'retagged':
                          if (t != EntityHistoryEventType.trackFileRetagged) {
                            return false;
                          }
                        case 'deleted':
                          if (t != EntityHistoryEventType.trackFileDeleted) {
                            return false;
                          }
                        case 'failed':
                          if (t != EntityHistoryEventType.downloadFailed) {
                            return false;
                          }
                      }
                    }
                    return true;
                  }).toList();

                  // Sort in memory
                  filtered.sort((HistoryResource a, HistoryResource b) {
                    switch (_sortOption) {
                      case ArtistHistorySort.dateDesc:
                        final String da = a.date ?? '';
                        final String db = b.date ?? '';
                        return db.compareTo(da);
                      case ArtistHistorySort.dateAsc:
                        final String da = a.date ?? '';
                        final String db = b.date ?? '';
                        return da.compareTo(db);
                      case ArtistHistorySort.titleAsc:
                        final String ta =
                            (a.sourceTitle ?? a.album?.title ?? '')
                                .toLowerCase();
                        final String tb =
                            (b.sourceTitle ?? b.album?.title ?? '')
                                .toLowerCase();
                        return ta.compareTo(tb);
                      case ArtistHistorySort.titleDesc:
                        final String ta =
                            (a.sourceTitle ?? a.album?.title ?? '')
                                .toLowerCase();
                        final String tb =
                            (b.sourceTitle ?? b.album?.title ?? '')
                                .toLowerCase();
                        return tb.compareTo(ta);
                      case ArtistHistorySort.qualityDesc:
                        final int qa = a.quality?.quality?.id ?? 0;
                        final int qb = b.quality?.quality?.id ?? 0;
                        return qb.compareTo(qa);
                      case ArtistHistorySort.eventType:
                        final String ea = a.eventType?.value ?? '';
                        final String eb = b.eventType?.value ?? '';
                        return ea.compareTo(eb);
                    }
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.filter_list_off,
                              size: 48,
                              color: cs.outline.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Matching Events',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try changing or resetting your active filters.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Reset Filters'),
                              onPressed: () {
                                setState(() {
                                  _filterQuery = '';
                                  _searchController.clear();
                                  _selectedFilter = 'all';
                                  _sortOption = ArtistHistorySort.dateDesc;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return EasyRefresh(
                    onRefresh: () => ref.refresh(
                      lidarrArtistHistoryProvider(
                        (widget.instance, widget.artistId),
                      ),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final HistoryResource item = filtered[index];
                        final Color eventColor =
                            _getEventColor(item.eventType, cs);
                        final IconData eventIcon =
                            _getEventIcon(item.eventType);
                        final String? qualityName = item.quality?.quality?.name;
                        final String timeStr =
                            LidarrFormatters.formatRelativeDate(item.date);
                        final bool canMarkFailed =
                            item.eventType == EntityHistoryEventType.grabbed &&
                                item.id != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: cs.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _showHistoryDetails(context, item),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Icon badge
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: eventColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      eventIcon,
                                      size: 20,
                                      color: eventColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Title and event details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.sourceTitle ??
                                              item.album?.title ??
                                              'Unknown item',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.eventType?.value ?? 'Event',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (qualityName != null &&
                                                qualityName.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 1,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs
                                                      .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  qualityName,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            Text(
                                              timeStr,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: cs.outline,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Trailing indicator or action
                                  if (canMarkFailed) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.error_outline,
                                        size: 20,
                                        color: cs.error.withValues(alpha: 0.8),
                                      ),
                                      tooltip: 'Mark as Failed',
                                      onPressed: () => _markFailed(item),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: cs.outline.withValues(alpha: 0.6),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated page showing activity history for an artist.
class LidarrArtistHistoryScreen extends StatelessWidget {
  const LidarrArtistHistoryScreen({
    required this.instance,
    required this.artistId,
    required this.artistName,
    super.key,
  });

  final Instance instance;
  final int artistId;
  final String artistName;

  @override
  Widget build(BuildContext context) {
    return ArtistHistoryView(
      instance: instance,
      artistId: artistId,
      artistName: artistName,
      showAppBar: true,
    );
  }
}
