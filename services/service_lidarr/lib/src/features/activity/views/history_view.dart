import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lidarr_formatters.dart';
import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';

/// Activity history view with event filtering, chronological grouping, deep event details inspection, and infinite scroll pagination.
class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<HistoryView> createState() => HistoryViewState();
}

class HistoryViewState extends ConsumerState<HistoryView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<HistoryResource> _history = <HistoryResource>[];
  int _currentPage = 1;
  static const int _pageSize = 50;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  /// Programmatic initial load / refresh.
  Future<void> loadInitial() => _loadInitial();

  /// Programmatic pagination load more.
  Future<void> loadMore() => _loadMore();

  /// Total records currently loaded in memory.
  int get totalLoaded => _history.length;

  /// Current pagination page.
  int get currentPage => _currentPage;

  /// Whether additional pages can be fetched.
  bool get hasMore => _hasMore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final HistoryResourcePagingResource data = await ref.refresh(
        lidarrHistoryPagedProvider(
          (
            widget.instance,
            page: 1,
            pageSize: _pageSize,
            eventType: null,
          ),
        ).future,
      );

      final List<HistoryResource> records =
          data.records ?? <HistoryResource>[];
      final int totalRecords = data.totalRecords ?? 0;

      if (mounted) {
        setState(() {
          _history = List<HistoryResource>.from(records);
          _hasMore = _history.length < totalRecords;
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    try {
      final int nextPage = _currentPage + 1;
      final HistoryResourcePagingResource data = await ref.read(
        lidarrHistoryPagedProvider(
          (
            widget.instance,
            page: nextPage,
            pageSize: _pageSize,
            eventType: null,
          ),
        ).future,
      );

      final List<HistoryResource> records =
          data.records ?? <HistoryResource>[];
      final int totalRecords = data.totalRecords ?? 0;

      if (mounted) {
        setState(() {
          _history = <HistoryResource>[..._history, ...records];
          _currentPage = nextPage;
          _hasMore = _history.length < totalRecords;
        });
      }
    } catch (e) {
      // Soft fail on pagination
    }
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
        return cs.error;
      case EntityHistoryEventType.trackFileRenamed:
        return cs.secondary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Future<void> _markAsFailed(HistoryResource item) async {
    final int? id = item.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Mark as Failed?'),
        content: Text(
          'Mark "${item.sourceTitle ?? 'Release'}" as failed and search for an alternative release?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark Failed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final ApiResponse<void> resp =
          await api.history.postHistoryFailedById(id: id);

      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to mark as failed');
      }

      await _loadInitial();
      ref.invalidate(lidarrQueueProvider(widget.instance));
      ref.invalidate(lidarrBlocklistProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked release as failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showHistoryDetails(HistoryResource item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          final ThemeData theme = Theme.of(context);
          final ColorScheme cs = theme.colorScheme;
          final IconData icon = _getEventIcon(item.eventType);
          final Color color = _getEventColor(item.eventType, cs);

          return Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              title: const Text('Event Details'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: <Widget>[
                if (item.eventType == EntityHistoryEventType.grabbed)
                  IconButton(
                    icon: Icon(Icons.report_problem_outlined, color: cs.error),
                    tooltip: 'Mark as Failed',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _markAsFailed(item);
                    },
                  ),
              ],
            ),
            body: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(icon, color: color, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.sourceTitle ??
                                item.album?.title ??
                                'Activity Event',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.artist?.artistName != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.artist!.artistName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (item.album?.title != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Album: ${item.album!.title!}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Column(
                      children: <Widget>[
                        _buildDetailRow(
                          'Event Type',
                          item.eventType?.name ?? '--',
                          context,
                        ),
                        const Divider(height: 12),
                        _buildDetailRow(
                          'Date',
                          item.date != null
                              ? LidarrFormatters.formatRelativeDate(item.date)
                              : '--',
                          context,
                        ),
                        if (item.quality?.quality?.name != null) ...[
                          const Divider(height: 12),
                          _buildDetailRow(
                            'Quality',
                            item.quality!.quality!.name!,
                            context,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (item.data != null && item.data!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Event Data',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final entry in item.data!.entries)
                            if (entry.value != null && entry.value!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${entry.key}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value!,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDateSection(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown Date';
    final DateTime? dt = DateTime.tryParse(dateStr);
    if (dt == null) return 'Unknown Date';

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime itemDate = DateTime(dt.year, dt.month, dt.day);
    final int diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return 'This Week';
    if (diffDays < 30) return 'Last 30 Days';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String filterQuery =
        ref.watch(lidarrActivitySearchQueryProvider(widget.instance));
    final bool grouped =
        ref.watch(lidarrActivityGroupedProvider(widget.instance));
    final EntityHistoryEventType? activeFilter =
        ref.watch(lidarrHistoryEventTypeFilterProvider(widget.instance));

    if (_loading && _history.isEmpty) {
      return const Center(child: ExpressiveProgressIndicator());
    }

    if (_error != null && _history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load history',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.error,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _loadInitial,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    List<HistoryResource> history = _history;

    // Filter by event type
    if (activeFilter != null) {
      history = history.where((HistoryResource item) {
        if (activeFilter == EntityHistoryEventType.downloadImported) {
          return item.eventType ==
                  EntityHistoryEventType.downloadImported ||
              item.eventType == EntityHistoryEventType.trackFileImported ||
              item.eventType == EntityHistoryEventType.artistFolderImported;
        }
        return item.eventType == activeFilter;
      }).toList();
    }

    // Filter by query
    if (filterQuery.trim().isNotEmpty) {
      final String q = filterQuery.trim().toLowerCase();
      history = history.where((HistoryResource item) {
        final String sourceTitle = (item.sourceTitle ?? '').toLowerCase();
        final String artist = (item.artist?.artistName ?? '').toLowerCase();
        final String album = (item.album?.title ?? '').toLowerCase();
        return sourceTitle.contains(q) ||
            artist.contains(q) ||
            album.contains(q);
      }).toList();
    }

    Widget content;
    if (history.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.history_outlined,
                  size: 48,
                  color: cs.outlineVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  filterQuery.trim().isNotEmpty
                      ? 'No history matching "$filterQuery"'
                      : activeFilter != null
                          ? 'No history for selected filter'
                          : 'No history records found',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (!grouped) {
      content = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: history.length,
        itemBuilder: (BuildContext context, int index) {
          final HistoryResource item = history[index];
          return _buildHistoryCard(item, theme, cs);
        },
      );
    } else {
      // Chronological section grouping
      final Map<String, List<HistoryResource>> sections =
          <String, List<HistoryResource>>{};
      for (final item in history) {
        final String sec = _getDateSection(item.date);
        sections.putIfAbsent(sec, () => <HistoryResource>[]).add(item);
      }

      final List<String> sectionKeys = sections.keys.toList();

      content = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sectionKeys.length,
        itemBuilder: (BuildContext context, int sIdx) {
          final String sectionTitle = sectionKeys[sIdx];
          final List<HistoryResource> sectionItems = sections[sectionTitle]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  sectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
              for (final item in sectionItems)
                _buildHistoryCard(item, theme, cs),
            ],
          );
        },
      );
    }

    return EasyRefresh(
      onRefresh: _loadInitial,
      onLoad: _hasMore ? _loadMore : null,
      child: content,
    );
  }

  Widget _buildHistoryCard(
    HistoryResource item,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final IconData icon = _getEventIcon(item.eventType);
    final Color color = _getEventColor(item.eventType, cs);
    final String timeStr = LidarrFormatters.formatRelativeDate(item.date);
    final bool canMarkFailed = item.eventType == EntityHistoryEventType.grabbed;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showHistoryDetails(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.sourceTitle ?? item.album?.title ?? 'Unknown Event',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist?.artistName ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Text(
                          timeStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (item.quality?.quality?.name != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.quality!.quality!.name!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canMarkFailed)
                IconButton(
                  icon: Icon(
                    Icons.report_problem_outlined,
                    size: 18,
                    color: cs.error,
                  ),
                  tooltip: 'Mark as Failed',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _markAsFailed(item),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for filtering and grouping Lidarr history events.
class HistoryFilterBottomSheet extends ConsumerWidget {
  const HistoryFilterBottomSheet({required this.instance, super.key});

  final Instance instance;

  static void show(BuildContext context, Instance instance) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext ctx) =>
          HistoryFilterBottomSheet(instance: instance),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final EntityHistoryEventType? activeFilter =
        ref.watch(lidarrHistoryEventTypeFilterProvider(instance));
    final bool grouped = ref.watch(lidarrActivityGroupedProvider(instance));

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'View Mode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.group_work_outlined),
                    label: Text('Grouped by Date'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.format_list_bulleted),
                    label: Text('Plain List'),
                  ),
                ],
                selected: <bool>{grouped},
                onSelectionChanged: (Set<bool> newSelection) {
                  ref
                      .read(lidarrActivityGroupedProvider(instance).notifier)
                      .setGrouped(newSelection.first);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Event Type Filter',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (activeFilter != null)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(
                              lidarrHistoryEventTypeFilterProvider(
                                instance,
                              ).notifier,
                            )
                            .state = null;
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('All Events'),
                    selected: activeFilter == null,
                    onSelected: (bool val) {
                      if (val) {
                        ref
                            .read(
                              lidarrHistoryEventTypeFilterProvider(
                                instance,
                              ).notifier,
                            )
                            .state = null;
                      }
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.cloud_download_outlined, size: 16),
                    label: const Text('Grabbed'),
                    selected: activeFilter == EntityHistoryEventType.grabbed,
                    onSelected: (bool val) {
                      ref
                          .read(
                            lidarrHistoryEventTypeFilterProvider(
                              instance,
                            ).notifier,
                          )
                          .state = val ? EntityHistoryEventType.grabbed : null;
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Imported'),
                    selected: activeFilter ==
                            EntityHistoryEventType.downloadImported ||
                        activeFilter ==
                            EntityHistoryEventType.trackFileImported,
                    onSelected: (bool val) {
                      ref
                              .read(
                                lidarrHistoryEventTypeFilterProvider(
                                  instance,
                                ).notifier,
                              )
                              .state =
                          val ? EntityHistoryEventType.downloadImported : null;
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.error_outline, size: 16),
                    label: const Text('Failed'),
                    selected:
                        activeFilter == EntityHistoryEventType.downloadFailed,
                    onSelected: (bool val) {
                      ref
                              .read(
                                lidarrHistoryEventTypeFilterProvider(
                                  instance,
                                ).notifier,
                              )
                              .state =
                          val ? EntityHistoryEventType.downloadFailed : null;
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Deleted'),
                    selected:
                        activeFilter == EntityHistoryEventType.trackFileDeleted,
                    onSelected: (bool val) {
                      ref
                              .read(
                                lidarrHistoryEventTypeFilterProvider(
                                  instance,
                                ).notifier,
                              )
                              .state =
                          val ? EntityHistoryEventType.trackFileDeleted : null;
                    },
                  ),
                  ChoiceChip(
                    avatar:
                        const Icon(Icons.drive_file_rename_outline, size: 16),
                    label: const Text('Renamed'),
                    selected:
                        activeFilter == EntityHistoryEventType.trackFileRenamed,
                    onSelected: (bool val) {
                      ref
                              .read(
                                lidarrHistoryEventTypeFilterProvider(
                                  instance,
                                ).notifier,
                              )
                              .state =
                          val ? EntityHistoryEventType.trackFileRenamed : null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
