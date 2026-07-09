import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_movie_screen.dart';
import 'models/radarr_blocklist.dart';
import 'models/radarr_history.dart';
import 'models/radarr_movie.dart';
import 'models/radarr_queue.dart';
import 'models/radarr_settings_models.dart';
import 'models/radarr_system.dart';
import 'models/radarr_wanted.dart';
import 'movie_detail_screen.dart';
import 'radarr_api.dart';
import 'radarr_providers.dart';
import 'radarr_settings_form_screen.dart';
import 'package:m3_expressive/m3_expressive.dart';

/// Radarr's per-instance UI: a tabbed Movies / Queue view. Mirrors `SonarrHome`.
class RadarrHome extends StatelessWidget {
  const RadarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(text: 'Movies'),
                Tab(text: 'Queue'),
                Tab(text: 'Wanted'),
                Tab(text: 'History'),
                Tab(text: 'Blocklist'),
                Tab(text: 'System'),
                Tab(text: 'Settings'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _MoviesTab(instance: instance),
                  _QueueTab(instance: instance),
                  _WantedTab(instance: instance),
                  _HistoryTab(instance: instance),
                  _BlocklistTab(instance: instance),
                  _SystemTab(instance: instance),
                  _SettingsTab(instance: instance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sort field, decoupled from direction so the chip can flip asc/desc in place.
enum _SortField { title, year, size }

_SortField _sortFieldOf(RadarrSortOption o) => switch (o) {
      RadarrSortOption.titleAsc ||
      RadarrSortOption.titleDesc =>
        _SortField.title,
      RadarrSortOption.yearAsc || RadarrSortOption.yearDesc => _SortField.year,
      RadarrSortOption.sizeAsc || RadarrSortOption.sizeDesc => _SortField.size,
    };

bool _sortIsAsc(RadarrSortOption o) => switch (o) {
      RadarrSortOption.titleAsc ||
      RadarrSortOption.yearAsc ||
      RadarrSortOption.sizeAsc =>
        true,
      _ => false,
    };

RadarrSortOption _composeSort(_SortField field, bool asc) => switch (field) {
      _SortField.title =>
        asc ? RadarrSortOption.titleAsc : RadarrSortOption.titleDesc,
      _SortField.year =>
        asc ? RadarrSortOption.yearAsc : RadarrSortOption.yearDesc,
      _SortField.size =>
        asc ? RadarrSortOption.sizeAsc : RadarrSortOption.sizeDesc,
    };

String _sortFieldLabel(_SortField f) => switch (f) {
      _SortField.title => 'Title',
      _SortField.year => 'Year',
      _SortField.size => 'Size',
    };

class _MoviesTab extends ConsumerWidget {
  const _MoviesTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RadarrMovie>> filtered =
        ref.watch(radarrFilteredMoviesProvider(instance));
    final RadarrApi? api = ref.watch(radarrApiProvider(instance)).value;
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.xs,
              ),
              child: _SearchBar(instance: instance),
            ),
            _FilterChipsRow(instance: instance),
            const SizedBox(height: Insets.xs),
            Expanded(
              child: M3RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(radarrMoviesProvider(instance));
                  await ref.read(radarrMoviesProvider(instance).future);
                },
                child: AsyncValueView<List<RadarrMovie>>(
                  value: filtered,
                  onRetry: () => ref.invalidate(radarrMoviesProvider(instance)),
                  data: (List<RadarrMovie> list) {
                    if (list.isEmpty) {
                      return const EmptyView(
                        icon: Icons.movie_outlined,
                        title: 'No movies found',
                        message:
                            'Try adjusting your search query or active filters.',
                      );
                    }
                    return GridView.builder(
                      padding: Insets.page,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140,
                        childAspectRatio: 0.52,
                        crossAxisSpacing: Insets.md,
                        mainAxisSpacing: Insets.md,
                      ),
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        final RadarrMovie m = list[index];
                        final RadarrImage? poster = m.images.firstWhereOrNull(
                          (RadarrImage i) => i.coverType == 'poster',
                        );
                        return PerformanceLoggerWidget(
                          name: 'RadarrMovieGridItem',
                          child: _MovieCard(
                            movie: m,
                            imageUrl:
                                poster == null ? null : api?.posterUrl(poster),
                            onTap: () =>
                                Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MovieDetailScreen(
                                  instance: instance,
                                  movieId: m.id,
                                ),
                              ),
                            ),
                            onLongPress: () =>
                                _showQuickActions(context, ref, m),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => AddMovieScreen(instance: instance),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _toggleMonitored(WidgetRef ref, RadarrMovie m) async {
    final RadarrApi api = await ref.read(radarrApiProvider(instance).future);
    final Map<String, dynamic> raw = await api.getMovieRaw(m.id);
    raw['monitored'] = !m.monitored;
    await api.updateMovieRaw(raw);
    ref.invalidate(radarrMoviesProvider(instance));
  }

  void _showQuickActions(BuildContext context, WidgetRef ref, RadarrMovie m) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(
                  m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: m.year != null ? Text('${m.year}') : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  m.monitored ? Icons.bookmark : Icons.bookmark_border,
                ),
                title: Text(m.monitored ? 'Unmonitor' : 'Monitor'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _toggleMonitored(ref, m);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          m.monitored
                              ? 'Stopped monitoring ${m.title}'
                              : 'Monitoring ${m.title}',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final RadarrApi api =
                      await ref.read(radarrApiProvider(instance).future);
                  await api.searchMovie(m.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Search started for ${m.title}')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open details'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MovieDetailScreen(
                        instance: instance,
                        movieId: m.id,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        );
      },
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(radarrSearchQueryProvider(widget.instance)),
    );
    _focusNode = FocusNode(skipTraversal: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SearchBar(
      controller: _controller,
      focusNode: _focusNode,
      hintText: 'Search movies...',
      leading: const Icon(Icons.search),
      trailing: <Widget>[
        if (_controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() => _controller.clear());
              ref
                  .read(radarrSearchQueryProvider(widget.instance).notifier)
                  .state = '';
              _focusNode.unfocus();
            },
          ),
      ],
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(
        theme.colorScheme.surfaceContainerHigh,
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      onChanged: (String val) {
        setState(() {});
        ref.read(radarrSearchQueryProvider(widget.instance).notifier).state =
            val;
      },
    );
  }
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final RadarrSortOption sortOption =
        ref.watch(radarrSortOptionProvider(instance));
    final RadarrStatusFilter statusFilter =
        ref.watch(radarrStatusFilterProvider(instance));
    final RadarrMonitoredFilter monitoredFilter =
        ref.watch(radarrMonitoredFilterProvider(instance));
    final _SortField sortField = _sortFieldOf(sortOption);
    final bool asc = _sortIsAsc(sortOption);

    String statusLabel(RadarrStatusFilter f) => switch (f) {
          RadarrStatusFilter.all => 'All',
          RadarrStatusFilter.downloaded => 'Downloaded',
          RadarrStatusFilter.missing => 'Missing',
        };

    String monitoredLabel(RadarrMonitoredFilter f) => switch (f) {
          RadarrMonitoredFilter.all => 'All',
          RadarrMonitoredFilter.monitored => 'Monitored',
          RadarrMonitoredFilter.unmonitored => 'Unmonitored',
        };

    void unfocusSoon() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          FocusScope.of(context).unfocus();
        }
      });
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        children: <Widget>[
          // Sort field (menu) + direction (tap to flip).
          MenuAnchor(
            builder:
                (BuildContext context, MenuController controller, Widget? _) =>
                    ActionChip(
              avatar: const Icon(Icons.sort, size: 18),
              label: Text('Sort: ${_sortFieldLabel(sortField)}'),
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
                unfocusSoon();
              },
            ),
            menuChildren: <Widget>[
              for (final _SortField f in _SortField.values)
                MenuItemButton(
                  leadingIcon: Icon(
                    f == sortField ? Icons.check : Icons.sort,
                    size: 18,
                  ),
                  onPressed: () => ref
                      .read(radarrSortOptionProvider(instance).notifier)
                      .state = _composeSort(f, asc),
                  child: Text(_sortFieldLabel(f)),
                ),
            ],
          ),
          const SizedBox(width: Insets.sm),
          ActionChip(
            avatar: Icon(
              asc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
            ),
            label: Text(asc ? 'Asc' : 'Desc'),
            onPressed: () {
              ref.read(radarrSortOptionProvider(instance).notifier).state =
                  _composeSort(sortField, !asc);
              unfocusSoon();
            },
          ),
          const SizedBox(width: Insets.sm),
          // Status filter.
          MenuAnchor(
            builder:
                (BuildContext context, MenuController controller, Widget? _) =>
                    ActionChip(
              avatar: Icon(
                statusFilter == RadarrStatusFilter.all
                    ? Icons.filter_alt_outlined
                    : Icons.filter_alt,
                size: 18,
              ),
              label: Text('Status: ${statusLabel(statusFilter)}'),
              backgroundColor: statusFilter != RadarrStatusFilter.all
                  ? theme.colorScheme.secondaryContainer
                  : null,
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
                unfocusSoon();
              },
            ),
            menuChildren: <Widget>[
              for (final RadarrStatusFilter f in RadarrStatusFilter.values)
                MenuItemButton(
                  leadingIcon: Icon(
                    f == statusFilter ? Icons.check : Icons.movie_outlined,
                    size: 18,
                  ),
                  onPressed: () => ref
                      .read(radarrStatusFilterProvider(instance).notifier)
                      .state = f,
                  child: Text(statusLabel(f)),
                ),
            ],
          ),
          const SizedBox(width: Insets.sm),
          // Monitored filter.
          MenuAnchor(
            builder:
                (BuildContext context, MenuController controller, Widget? _) =>
                    ActionChip(
              avatar: Icon(
                monitoredFilter == RadarrMonitoredFilter.all
                    ? Icons.bookmark_border
                    : Icons.bookmark,
                size: 18,
              ),
              label: Text('Monitored: ${monitoredLabel(monitoredFilter)}'),
              backgroundColor: monitoredFilter != RadarrMonitoredFilter.all
                  ? theme.colorScheme.secondaryContainer
                  : null,
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
                unfocusSoon();
              },
            ),
            menuChildren: <Widget>[
              for (final RadarrMonitoredFilter f
                  in RadarrMonitoredFilter.values)
                MenuItemButton(
                  leadingIcon: Icon(
                    f == monitoredFilter ? Icons.check : Icons.bookmark_border,
                    size: 18,
                  ),
                  onPressed: () => ref
                      .read(radarrMonitoredFilterProvider(instance).notifier)
                      .state = f,
                  child: Text(monitoredLabel(f)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({
    required this.movie,
    required this.imageUrl,
    required this.onTap,
    this.onLongPress,
  });

  final RadarrMovie movie;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _Poster(imageUrl: imageUrl, theme: theme),
                  if (movie.hasFile)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        color: theme.colorScheme.primary,
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    )
                  else if (movie.monitored)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        color: theme.colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.bookmark,
                          size: 12,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final List<String> parts = <String>[
      if (movie.year != null) '${movie.year}',
      if (movie.hasFile) 'Downloaded' else 'Missing',
    ];
    return parts.join(' • ');
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.imageUrl, required this.theme});

  final String? imageUrl;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: theme.colorScheme.outline),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 300,
      placeholder: (BuildContext context, String url) =>
          Container(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (BuildContext context, String url, Object error) => fallback,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: child,
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RadarrQueuePage> queue =
        ref.watch(radarrQueueProvider(instance));
    return M3RefreshIndicator(
      onRefresh: () async => ref.invalidate(radarrQueueProvider(instance)),
      child: AsyncValueView<RadarrQueuePage>(
        value: queue,
        onRetry: () => ref.invalidate(radarrQueueProvider(instance)),
        data: (RadarrQueuePage page) {
          if (page.records.isEmpty) {
            return const EmptyView(
              icon: Icons.download_done_outlined,
              title: 'Queue is empty',
              message: 'Nothing downloading right now.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: page.records.length,
            itemBuilder: (BuildContext context, int index) {
              final RadarrQueueRecord r = page.records[index];
              final double progress = r.size <= 0
                  ? 0
                  : ((r.size - r.sizeleft) / r.size).clamp(0, 1).toDouble();
              return ListTile(
                title: Text(
                  r.title ?? 'Item ${r.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: Insets.xs),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: Insets.xs),
                    Text(
                      <String?>[
                        r.status,
                        if (r.timeleft != null) r.timeleft,
                      ].whereType<String>().join(' • '),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final RadarrApi api =
                        await ref.read(radarrApiProvider(instance).future);
                    await api.deleteQueueItem(r.id);
                    ref.invalidate(radarrQueueProvider(instance));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// History ------------------------------------------------------------------

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<RadarrHistoryPage> history =
        ref.watch(radarrHistoryProvider((widget.instance, _page)));
    return M3RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(radarrHistoryProvider((widget.instance, _page))),
      child: AsyncValueView<RadarrHistoryPage>(
        value: history,
        onRetry: () =>
            ref.invalidate(radarrHistoryProvider((widget.instance, _page))),
        data: (RadarrHistoryPage hp) {
          if (hp.records.isEmpty) {
            return const EmptyView(
              icon: Icons.history,
              title: 'No history',
              message: 'Grabs and imports will show up here.',
            );
          }
          final int totalPages = hp.pageSize > 0
              ? ((hp.totalRecords + hp.pageSize - 1) ~/ hp.pageSize)
              : 1;
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.separated(
                  padding: Insets.page,
                  itemCount: hp.records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final RadarrHistoryRecord r = hp.records[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _eventIcon(r.eventType),
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        r.sourceTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        <String>[
                          _eventLabel(r.eventType),
                          if (r.date != null) _fmtDate(r.date!.toLocal()),
                        ].where((String s) => s.isNotEmpty).join(' • '),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  page: _page,
                  totalPages: totalPages,
                  onPrev: _page > 1 ? () => setState(() => _page--) : null,
                  onNext:
                      _page < totalPages ? () => setState(() => _page++) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          TextButton(onPressed: onPrev, child: const Text('Prev')),
          Text('Page $page of $totalPages'),
          TextButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

String _eventLabel(String e) => switch (e) {
      'grabbed' => 'Grabbed',
      'downloadFolderImported' => 'Imported',
      'downloadFailed' => 'Download failed',
      'movieFileDeleted' => 'File deleted',
      'movieFileRenamed' => 'Renamed',
      _ => e,
    };

IconData _eventIcon(String e) => switch (e) {
      'grabbed' => Icons.download,
      'downloadFolderImported' => Icons.check_circle_outline,
      'downloadFailed' => Icons.error_outline,
      'movieFileDeleted' => Icons.delete_outline,
      'movieFileRenamed' => Icons.drive_file_rename_outline,
      _ => Icons.history,
    };

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// Wanted -------------------------------------------------------------------

class _WantedTab extends StatelessWidget {
  const _WantedTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Missing'),
              Tab(text: 'Cutoff Unmet'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _WantedList(instance: instance, cutoff: false),
                _WantedList(instance: instance, cutoff: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WantedList extends ConsumerStatefulWidget {
  const _WantedList({required this.instance, required this.cutoff});

  final Instance instance;
  final bool cutoff;

  @override
  ConsumerState<_WantedList> createState() => _WantedListState();
}

class _WantedListState extends ConsumerState<_WantedList> {
  int _page = 1;

  void _invalidate() {
    if (widget.cutoff) {
      ref.invalidate(radarrWantedCutoffProvider((widget.instance, _page)));
    } else {
      ref.invalidate(radarrWantedMissingProvider((widget.instance, _page)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RadarrWantedPage> wanted = widget.cutoff
        ? ref.watch(radarrWantedCutoffProvider((widget.instance, _page)))
        : ref.watch(radarrWantedMissingProvider((widget.instance, _page)));
    final RadarrApi? api = ref.watch(radarrApiProvider(widget.instance)).value;
    return M3RefreshIndicator(
      onRefresh: () async => _invalidate(),
      child: AsyncValueView<RadarrWantedPage>(
        value: wanted,
        onRetry: _invalidate,
        data: (RadarrWantedPage wp) {
          if (wp.records.isEmpty) {
            return EmptyView(
              icon: Icons.check_circle_outline,
              title: widget.cutoff ? 'Nothing below cutoff' : 'Nothing missing',
              message: 'All caught up.',
            );
          }
          final int totalPages = wp.pageSize > 0
              ? ((wp.totalRecords + wp.pageSize - 1) ~/ wp.pageSize)
              : 1;
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.separated(
                  padding: Insets.page,
                  itemCount: wp.records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) => _MovieRow(
                    instance: widget.instance,
                    movie: wp.records[index],
                    api: api,
                  ),
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  page: _page,
                  totalPages: totalPages,
                  onPrev: _page > 1 ? () => setState(() => _page--) : null,
                  onNext:
                      _page < totalPages ? () => setState(() => _page++) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MovieRow extends StatelessWidget {
  const _MovieRow({
    required this.instance,
    required this.movie,
    required this.api,
  });

  final Instance instance;
  final RadarrMovie movie;
  final RadarrApi? api;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RadarrImage? poster = movie.images
        .firstWhereOrNull((RadarrImage i) => i.coverType == 'poster');
    final String? url = poster == null ? null : api?.posterUrl(poster);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 40,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: url == null
              ? Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.movie_outlined,
                    color: theme.colorScheme.outline,
                    size: 18,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: 120,
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
        ),
      ),
      title: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: movie.year != null ? Text('${movie.year}') : null,
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MovieDetailScreen(instance: instance, movieId: movie.id),
        ),
      ),
    );
  }
}

// Blocklist ----------------------------------------------------------------

class _BlocklistTab extends ConsumerStatefulWidget {
  const _BlocklistTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_BlocklistTab> createState() => _BlocklistTabState();
}

class _BlocklistTabState extends ConsumerState<_BlocklistTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RadarrBlocklistPage> blocklist =
        ref.watch(radarrBlocklistProvider((widget.instance, _page)));
    return M3RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(radarrBlocklistProvider((widget.instance, _page))),
      child: AsyncValueView<RadarrBlocklistPage>(
        value: blocklist,
        onRetry: () =>
            ref.invalidate(radarrBlocklistProvider((widget.instance, _page))),
        data: (RadarrBlocklistPage bp) {
          if (bp.records.isEmpty) {
            return const EmptyView(
              icon: Icons.block,
              title: 'Blocklist is empty',
              message: 'Rejected releases will appear here.',
            );
          }
          final int totalPages = bp.pageSize > 0
              ? ((bp.totalRecords + bp.pageSize - 1) ~/ bp.pageSize)
              : 1;
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.separated(
                  padding: Insets.page,
                  itemCount: bp.records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final RadarrBlocklistRecord r = bp.records[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        r.sourceTitle ?? 'Unknown',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        <String>[
                          if (r.indexer != null) r.indexer!,
                          if (r.date != null) _fmtDate(r.date!.toLocal()),
                        ].join(' • '),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Remove from blocklist',
                        onPressed: () async {
                          final RadarrApi api = await ref
                              .read(radarrApiProvider(widget.instance).future);
                          await api.deleteBlocklist(r.id);
                          ref.invalidate(
                            radarrBlocklistProvider((widget.instance, _page)),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  page: _page,
                  totalPages: totalPages,
                  onPrev: _page > 1 ? () => setState(() => _page--) : null,
                  onNext:
                      _page < totalPages ? () => setState(() => _page++) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

// System -------------------------------------------------------------------

class _SystemTab extends ConsumerWidget {
  const _SystemTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return M3RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(radarrHealthProvider(instance));
        ref.invalidate(radarrSystemStatusProvider(instance));
        ref.invalidate(radarrDiskSpaceProvider(instance));
        ref.invalidate(radarrSystemTasksProvider(instance));
        ref.invalidate(radarrBackupsProvider(instance));
      },
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          const _SectionTitle('Health'),
          ref.watch(radarrHealthProvider(instance)).when(
                data: (List<RadarrHealth> items) => items.isEmpty
                    ? const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('All healthy'),
                      )
                    : Column(
                        children: items
                            .map(
                              (RadarrHealth h) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.warning_amber,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(h.message),
                                subtitle: Text(h.source),
                              ),
                            )
                            .toList(),
                      ),
                loading: () => const _Loading(),
                error: (Object e, _) => _ErrText('$e'),
              ),
          const SizedBox(height: Insets.lg),
          const _SectionTitle('Status'),
          ref.watch(radarrSystemStatusProvider(instance)).when(
                data: (RadarrSystemStatus s) => Column(
                  children: <Widget>[
                    _kv('Version', s.version),
                    _kv('App', s.appName),
                    _kv('OS', '${s.osName} ${s.osVersion}'.trim()),
                    if (s.databaseType != null)
                      _kv(
                        'Database',
                        '${s.databaseType} ${s.databaseVersion ?? ''}'.trim(),
                      ),
                    if (s.runtimeName != null)
                      _kv(
                        'Runtime',
                        '${s.runtimeName} ${s.runtimeVersion ?? ''}'.trim(),
                      ),
                  ],
                ),
                loading: () => const _Loading(),
                error: (Object e, _) => _ErrText('$e'),
              ),
          const SizedBox(height: Insets.lg),
          const _SectionTitle('Disk space'),
          ref.watch(radarrDiskSpaceProvider(instance)).when(
                data: (List<RadarrDiskSpace> disks) => Column(
                  children: disks.map((RadarrDiskSpace d) {
                    final double used = d.totalSpace <= 0
                        ? 0
                        : (d.totalSpace - d.freeSpace) / d.totalSpace;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            d.label.isNotEmpty ? d.label : d.path,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: used,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_fmtBytes(d.freeSpace)} free of ${_fmtBytes(d.totalSpace)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const _Loading(),
                error: (Object e, _) => _ErrText('$e'),
              ),
          const SizedBox(height: Insets.lg),
          const _SectionTitle('Tasks'),
          ref.watch(radarrSystemTasksProvider(instance)).when(
                data: (List<RadarrSystemTask> tasks) => Column(
                  children: tasks
                      .map(
                        (RadarrSystemTask t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.name),
                          subtitle: t.nextExecution != null
                              ? Text(
                                  'Next: ${_fmtDate(t.nextExecution!.toLocal())}')
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Run now',
                            onPressed: () async {
                              final RadarrApi api = await ref
                                  .read(radarrApiProvider(instance).future);
                              await api.runSystemTask(t.taskName);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Started ${t.name}')),
                                );
                              }
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
                loading: () => const _Loading(),
                error: (Object e, _) => _ErrText('$e'),
              ),
          const SizedBox(height: Insets.lg),
          const _SectionTitle('Backups'),
          ref.watch(radarrBackupsProvider(instance)).when(
                data: (List<RadarrBackup> backups) => backups.isEmpty
                    ? const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('No backups'),
                      )
                    : Column(
                        children: backups
                            .map(
                              (RadarrBackup b) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(b.name),
                                subtitle: b.time != null
                                    ? Text(_fmtDate(b.time!.toLocal()))
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final RadarrApi api = await ref.read(
                                        radarrApiProvider(instance).future);
                                    await api.deleteBackup(b.id);
                                    ref.invalidate(
                                        radarrBackupsProvider(instance));
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                loading: () => const _Loading(),
                error: (Object e, _) => _ErrText('$e'),
              ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.xs),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(Insets.md),
        child: Center(child: ExpressiveProgressIndicator()),
      );
}

class _ErrText extends StatelessWidget {
  const _ErrText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 96, child: Text(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );

String _fmtBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  final String text =
      v >= 100 || u == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$text ${units[u]}';
}

// Settings -----------------------------------------------------------------

/// Small helpers for reading values out of a raw settings map safely.
int _rawInt(Map<String, dynamic> m, String key, [int fallback = 0]) =>
    ((m[key] as num?) ?? fallback).toInt();

String _rawStr(Map<String, dynamic> m, String key, [String fallback = '']) =>
    (m[key] as String?) ?? fallback;

bool _rawBool(Map<String, dynamic> m, String key, [bool fallback = false]) =>
    (m[key] as bool?) ?? fallback;

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return M3RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(radarrIndexersRawProvider(instance));
        ref.invalidate(radarrDownloadClientsRawProvider(instance));
        ref.invalidate(radarrNotificationsRawProvider(instance));
        ref.invalidate(radarrImportListsRawProvider(instance));
        ref.invalidate(radarrTagsProvider(instance));
        ref.invalidate(radarrHostConfigRawProvider(instance));
        ref.invalidate(radarrNamingConfigRawProvider(instance));
        ref.invalidate(radarrMediaManagementConfigRawProvider(instance));
        ref.invalidate(radarrUiConfigRawProvider(instance));
        ref.invalidate(radarrMetadataProvidersRawProvider(instance));
        ref.invalidate(radarrDelayProfilesRawProvider(instance));
        ref.invalidate(radarrCustomFormatsProvider(instance));
        ref.invalidate(radarrQualityDefinitionsRawProvider(instance));
        ref.invalidate(radarrReleaseProfilesRawProvider(instance));
        ref.invalidate(radarrImportListExclusionsProvider(instance));
        ref.invalidate(radarrAutoTaggingRulesRawProvider(instance));
        ref.invalidate(radarrQualityProfilesRawProvider(instance));
        ref.invalidate(radarrQualityDefinitionsProvider(instance));
        await Future.wait(<Future<dynamic>>[
          ref.read(radarrIndexersRawProvider(instance).future),
          ref.read(radarrDownloadClientsRawProvider(instance).future),
          ref.read(radarrNotificationsRawProvider(instance).future),
          ref.read(radarrImportListsRawProvider(instance).future),
          ref.read(radarrTagsProvider(instance).future),
          ref.read(radarrHostConfigRawProvider(instance).future),
          ref.read(radarrNamingConfigRawProvider(instance).future),
          ref.read(radarrMediaManagementConfigRawProvider(instance).future),
          ref.read(radarrUiConfigRawProvider(instance).future),
          ref.read(radarrMetadataProvidersRawProvider(instance).future),
          ref.read(radarrDelayProfilesRawProvider(instance).future),
          ref.read(radarrCustomFormatsProvider(instance).future),
          ref.read(radarrQualityDefinitionsRawProvider(instance).future),
          ref.read(radarrReleaseProfilesRawProvider(instance).future),
          ref.read(radarrImportListExclusionsProvider(instance).future),
          ref.read(radarrAutoTaggingRulesRawProvider(instance).future),
          ref.read(radarrQualityProfilesRawProvider(instance).future),
          ref.read(radarrQualityDefinitionsProvider(instance).future),
        ]);
      },
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          _IndexerSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _DownloadClientSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _NotificationSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _ImportListSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _TagSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _HostSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _NamingSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _MediaManagementSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _UiSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _MetadataSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _DelayProfileSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _CustomFormatSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _QualityDefinitionSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _QualityProfileSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _ReleaseProfileSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _ImportListExclusionSettingsPanel(instance: instance),
          const SizedBox(height: Insets.md),
          _AutoTaggingSettingsPanel(instance: instance),
        ],
      ),
    );
  }
}

class _IndexerSettingsPanel extends ConsumerWidget {
  const _IndexerSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> indexers =
        ref.watch(radarrIndexersRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Indexers', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Indexer',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RadarrSettingsFormScreen(
                      instance: instance,
                      category: 'indexer',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: indexers,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) return const Text('No indexers configured.');
              return Column(
                children: list.map((Map<String, dynamic> indexer) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: _rawBool(indexer, 'enableRss'),
                      onChanged: (bool val) async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        final Map<String, dynamic> newRaw =
                            Map<String, dynamic>.of(indexer)
                              ..['enableRss'] = val;
                        await api.updateIndexerRaw(newRaw);
                        ref.invalidate(radarrIndexersRawProvider(instance));
                        ref.invalidate(radarrIndexersProvider(instance));
                      },
                    ),
                    title: Text(
                      _rawStr(indexer, 'name'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Protocol: ${_rawStr(indexer, 'protocol')}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Indexer',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            try {
                              await api.testIndexerRaw(indexer);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Indexer test successful!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Indexer test failed'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Indexer',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RadarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'indexer',
                                  itemRaw: indexer,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: 'Delete Indexer',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            await api.deleteIndexer(_rawInt(indexer, 'id'));
                            ref.invalidate(radarrIndexersRawProvider(instance));
                            ref.invalidate(radarrIndexersProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Indexer deleted')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DownloadClientSettingsPanel extends ConsumerWidget {
  const _DownloadClientSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> clients =
        ref.watch(radarrDownloadClientsRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Download Clients', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Download Client',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RadarrSettingsFormScreen(
                      instance: instance,
                      category: 'downloadclient',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: clients,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) {
                return const Text('No download clients configured.');
              }
              return Column(
                children: list.map((Map<String, dynamic> client) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: _rawBool(client, 'enable'),
                      onChanged: (bool val) async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        final Map<String, dynamic> newRaw =
                            Map<String, dynamic>.of(client)..['enable'] = val;
                        await api.updateDownloadClientRaw(newRaw);
                        ref.invalidate(
                          radarrDownloadClientsRawProvider(instance),
                        );
                        ref.invalidate(radarrDownloadClientsProvider(instance));
                      },
                    ),
                    title: Text(
                      _rawStr(client, 'name'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Protocol: ${_rawStr(client, 'protocol')}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Download Client',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            try {
                              await api.testDownloadClientRaw(client);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Download client test successful!',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Download client test failed'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Download Client',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RadarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'downloadclient',
                                  itemRaw: client,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: 'Delete Download Client',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            await api
                                .deleteDownloadClient(_rawInt(client, 'id'));
                            ref.invalidate(
                              radarrDownloadClientsRawProvider(instance),
                            );
                            ref.invalidate(
                              radarrDownloadClientsProvider(instance),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Download client deleted'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationSettingsPanel extends ConsumerWidget {
  const _NotificationSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> notifications =
        ref.watch(radarrNotificationsRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Notifications', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Notification',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RadarrSettingsFormScreen(
                      instance: instance,
                      category: 'notification',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: notifications,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) {
                return const Text('No notifications configured.');
              }
              return Column(
                children: list.map((Map<String, dynamic> notification) {
                  final List<String> activeTriggers = <String>[
                    if (_rawBool(notification, 'onGrab')) 'Grab',
                    if (_rawBool(notification, 'onDownload')) 'Download',
                    if (_rawBool(notification, 'onUpgrade')) 'Upgrade',
                  ];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _rawStr(notification, 'name'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Triggers: ${activeTriggers.isEmpty ? "None" : activeTriggers.join(", ")}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Notification',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            try {
                              await api.testNotificationRaw(notification);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Notification test successful!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notification test failed'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Notification',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RadarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'notification',
                                  itemRaw: notification,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: 'Delete Notification',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            await api.deleteNotification(
                                _rawInt(notification, 'id'));
                            ref.invalidate(
                              radarrNotificationsRawProvider(instance),
                            );
                            ref.invalidate(
                              radarrNotificationsProvider(instance),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notification deleted'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ImportListSettingsPanel extends ConsumerWidget {
  const _ImportListSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> lists =
        ref.watch(radarrImportListsRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Import Lists', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Import List',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RadarrSettingsFormScreen(
                      instance: instance,
                      category: 'importlist',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: lists,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty)
                return const Text('No import lists configured.');
              return Column(
                children: list.map((Map<String, dynamic> importList) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: _rawBool(importList, 'enable') ||
                          _rawBool(importList, 'enabled'),
                      onChanged: (bool val) async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        final Map<String, dynamic> newRaw =
                            Map<String, dynamic>.of(importList);
                        if (newRaw.containsKey('enabled')) {
                          newRaw['enabled'] = val;
                        }
                        newRaw['enable'] = val;
                        await api.updateImportListRaw(newRaw);
                        ref.invalidate(radarrImportListsRawProvider(instance));
                        ref.invalidate(radarrImportListsProvider(instance));
                      },
                    ),
                    title: Text(
                      _rawStr(importList, 'name'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Import List',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            try {
                              await api.testImportListRaw(importList);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Import list test successful!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Import list test failed'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Import List',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RadarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'importlist',
                                  itemRaw: importList,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: 'Delete Import List',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            await api
                                .deleteImportList(_rawInt(importList, 'id'));
                            ref.invalidate(
                              radarrImportListsRawProvider(instance),
                            );
                            ref.invalidate(radarrImportListsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Import list deleted'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TagSettingsPanel extends ConsumerWidget {
  const _TagSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<RadarrTag>> tags =
        ref.watch(radarrTagsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Tags', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Tag',
              onPressed: () => _showAddTagDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<RadarrTag>>(
            value: tags,
            data: (List<RadarrTag> tagList) {
              if (tagList.isEmpty) return const Text('No tags created yet.');
              return Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: tagList.map((RadarrTag tag) {
                  return Chip(
                    label: Text(tag.label),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      final RadarrApi api =
                          await ref.read(radarrApiProvider(instance).future);
                      await api.deleteTag(tag.id);
                      ref.invalidate(radarrTagsProvider(instance));
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Tag Label'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String label = controller.text.trim();
                if (label.isNotEmpty) {
                  final RadarrApi api =
                      await ref.read(radarrApiProvider(instance).future);
                  await api.createTag(label);
                  ref.invalidate(radarrTagsProvider(instance));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _HostSettingsPanel extends ConsumerWidget {
  const _HostSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> config =
        ref.watch(radarrHostConfigRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title:
            Text('General / Host Settings', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<Map<String, dynamic>>(
            value: config,
            data: (Map<String, dynamic> c) =>
                _HostSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _HostSettingsForm extends ConsumerStatefulWidget {
  const _HostSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final Map<String, dynamic> config;

  @override
  ConsumerState<_HostSettingsForm> createState() => _HostSettingsFormState();
}

class _HostSettingsFormState extends ConsumerState<_HostSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _portController;
  late final TextEditingController _branchController;
  late final TextEditingController _backupIntervalController;
  late final TextEditingController _backupRetentionController;
  late String _logLevel;
  late bool _enableSsl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
        text: _rawInt(widget.config, 'port', 7878).toString());
    _branchController =
        TextEditingController(text: _rawStr(widget.config, 'branch', 'master'));
    _backupIntervalController = TextEditingController(
      text: _rawInt(widget.config, 'backupInterval', 7).toString(),
    );
    _backupRetentionController = TextEditingController(
      text: _rawInt(widget.config, 'backupRetention', 28).toString(),
    );
    _logLevel = _rawStr(widget.config, 'logLevel', 'info');
    _enableSsl = _rawBool(widget.config, 'enableSsl');
  }

  @override
  void dispose() {
    _portController.dispose();
    _branchController.dispose();
    _backupIntervalController.dispose();
    _backupRetentionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final RadarrApi api =
        await ref.read(radarrApiProvider(widget.instance).future);
    final Map<String, dynamic> newRaw = Map<String, dynamic>.of(widget.config)
      ..['port'] =
          int.tryParse(_portController.text) ?? _rawInt(widget.config, 'port')
      ..['branch'] = _branchController.text.trim()
      ..['backupInterval'] = int.tryParse(_backupIntervalController.text) ??
          _rawInt(widget.config, 'backupInterval')
      ..['backupRetention'] = int.tryParse(_backupRetentionController.text) ??
          _rawInt(widget.config, 'backupRetention')
      ..['logLevel'] = _logLevel
      ..['enableSsl'] = _enableSsl;

    try {
      await api.updateHostConfigRaw(newRaw);
      ref.invalidate(radarrHostConfigRawProvider(widget.instance));
      ref.invalidate(radarrHostConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Server Port',
              border: OutlineInputBorder(),
            ),
            validator: (String? val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable SSL'),
            value: _enableSsl,
            onChanged: (bool val) => setState(() => _enableSsl = val),
          ),
          const SizedBox(height: Insets.sm),
          DropdownButtonFormField<String>(
            initialValue: _logLevel,
            decoration: const InputDecoration(
              labelText: 'Log Level',
              border: OutlineInputBorder(),
            ),
            items: <String>['trace', 'debug', 'info', 'warn', 'error']
                .map((String level) {
              return DropdownMenuItem<String>(
                value: level,
                child: Text(level.toUpperCase()),
              );
            }).toList(),
            onChanged: (String? val) {
              if (val != null) {
                setState(() => _logLevel = val);
              }
            },
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _branchController,
            decoration: const InputDecoration(
              labelText: 'Update Branch',
              border: OutlineInputBorder(),
            ),
            validator: (String? val) =>
                (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _backupIntervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Backup Interval (days)',
              border: OutlineInputBorder(),
            ),
            validator: (String? val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _backupRetentionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Backup Retention (backups)',
              border: OutlineInputBorder(),
            ),
            validator: (String? val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ExpressiveProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _NamingSettingsPanel extends ConsumerWidget {
  const _NamingSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> config =
        ref.watch(radarrNamingConfigRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Movie Naming', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<Map<String, dynamic>>(
            value: config,
            data: (Map<String, dynamic> c) =>
                _NamingSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _NamingSettingsForm extends ConsumerStatefulWidget {
  const _NamingSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final Map<String, dynamic> config;

  @override
  ConsumerState<_NamingSettingsForm> createState() =>
      _NamingSettingsFormState();
}

class _NamingSettingsFormState extends ConsumerState<_NamingSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _standardFormatController;
  late final TextEditingController _movieFolderFormatController;
  late bool _renameMovies;
  late bool _replaceIllegalCharacters;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _standardFormatController = TextEditingController(
      text: _rawStr(widget.config, 'standardMovieFormat'),
    );
    _movieFolderFormatController = TextEditingController(
      text: _rawStr(widget.config, 'movieFolderFormat'),
    );
    _renameMovies = _rawBool(widget.config, 'renameMovies');
    _replaceIllegalCharacters =
        _rawBool(widget.config, 'replaceIllegalCharacters');
  }

  @override
  void dispose() {
    _standardFormatController.dispose();
    _movieFolderFormatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final RadarrApi api =
        await ref.read(radarrApiProvider(widget.instance).future);
    final Map<String, dynamic> newRaw = Map<String, dynamic>.of(widget.config)
      ..['renameMovies'] = _renameMovies
      ..['replaceIllegalCharacters'] = _replaceIllegalCharacters
      ..['standardMovieFormat'] = _standardFormatController.text.trim()
      ..['movieFolderFormat'] = _movieFolderFormatController.text.trim();

    try {
      await api.updateNamingConfigRaw(newRaw);
      ref.invalidate(radarrNamingConfigRawProvider(widget.instance));
      ref.invalidate(radarrNamingConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naming settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rename Movies'),
            value: _renameMovies,
            onChanged: (bool val) => setState(() => _renameMovies = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Replace Illegal Characters'),
            value: _replaceIllegalCharacters,
            onChanged: (bool val) =>
                setState(() => _replaceIllegalCharacters = val),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _standardFormatController,
            decoration: const InputDecoration(
              labelText: 'Standard Movie Format',
              border: OutlineInputBorder(),
            ),
            validator: (String? val) =>
                (_renameMovies && (val == null || val.trim().isEmpty))
                    ? 'Required when Rename is enabled'
                    : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _movieFolderFormatController,
            decoration: const InputDecoration(
              labelText: 'Movie Folder Format',
              border: OutlineInputBorder(),
            ),
            validator: (String? val) =>
                (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ExpressiveProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _MediaManagementSettingsPanel extends ConsumerWidget {
  const _MediaManagementSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> config =
        ref.watch(radarrMediaManagementConfigRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Media Management', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<Map<String, dynamic>>(
            value: config,
            data: (Map<String, dynamic> c) =>
                _MediaManagementSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _MediaManagementSettingsForm extends ConsumerStatefulWidget {
  const _MediaManagementSettingsForm({
    required this.instance,
    required this.config,
  });

  final Instance instance;
  final Map<String, dynamic> config;

  @override
  ConsumerState<_MediaManagementSettingsForm> createState() =>
      _MediaManagementSettingsFormState();
}

class _MediaManagementSettingsFormState
    extends ConsumerState<_MediaManagementSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late bool _autoUnmonitor;
  late String _downloadPropers;
  late bool _createEmptyMovieFolders;
  late bool _deleteEmptyFolders;
  late bool _copyUsingHardlinks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoUnmonitor =
        _rawBool(widget.config, 'autoUnmonitorPreviouslyDownloadedMovies');
    _downloadPropers = _rawStr(
      widget.config,
      'downloadPropersAndRepacks',
      'preferAndUpgrade',
    );
    _createEmptyMovieFolders =
        _rawBool(widget.config, 'createEmptyMovieFolders');
    _deleteEmptyFolders = _rawBool(widget.config, 'deleteEmptyFolders');
    _copyUsingHardlinks = _rawBool(widget.config, 'copyUsingHardlinks');
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final RadarrApi api =
        await ref.read(radarrApiProvider(widget.instance).future);
    final Map<String, dynamic> newRaw = Map<String, dynamic>.of(widget.config)
      ..['autoUnmonitorPreviouslyDownloadedMovies'] = _autoUnmonitor
      ..['downloadPropersAndRepacks'] = _downloadPropers
      ..['createEmptyMovieFolders'] = _createEmptyMovieFolders
      ..['deleteEmptyFolders'] = _deleteEmptyFolders
      ..['copyUsingHardlinks'] = _copyUsingHardlinks;

    try {
      await api.updateMediaManagementConfigRaw(newRaw);
      ref.invalidate(radarrMediaManagementConfigRawProvider(widget.instance));
      ref.invalidate(radarrMediaManagementConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media management settings saved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Unmonitor Downloaded'),
            value: _autoUnmonitor,
            onChanged: (bool val) => setState(() => _autoUnmonitor = val),
          ),
          DropdownButtonFormField<String>(
            initialValue: _downloadPropers,
            decoration: const InputDecoration(
              labelText: 'Download Propers & Repacks',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'preferAndUpgrade',
                child: Text('Prefer and Upgrade'),
              ),
              DropdownMenuItem<String>(
                value: 'doNotUpgrade',
                child: Text('Do Not Upgrade'),
              ),
              DropdownMenuItem<String>(
                value: 'doNotPrefer',
                child: Text('Do Not Prefer'),
              ),
            ],
            onChanged: (String? val) {
              if (val != null) {
                setState(() => _downloadPropers = val);
              }
            },
          ),
          const SizedBox(height: Insets.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create Empty Movie Folders'),
            value: _createEmptyMovieFolders,
            onChanged: (bool val) =>
                setState(() => _createEmptyMovieFolders = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Delete Empty Folders'),
            value: _deleteEmptyFolders,
            onChanged: (bool val) => setState(() => _deleteEmptyFolders = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use Hardlinks instead of Copy'),
            value: _copyUsingHardlinks,
            onChanged: (bool val) => setState(() => _copyUsingHardlinks = val),
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ExpressiveProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _UiSettingsPanel extends ConsumerWidget {
  const _UiSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Map<String, dynamic>> config =
        ref.watch(radarrUiConfigRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('UI Configuration', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<Map<String, dynamic>>(
            value: config,
            data: (Map<String, dynamic> c) =>
                _UiSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _UiSettingsForm extends ConsumerStatefulWidget {
  const _UiSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final Map<String, dynamic> config;

  @override
  ConsumerState<_UiSettingsForm> createState() => _UiSettingsFormState();
}

class _UiSettingsFormState extends ConsumerState<_UiSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late String _theme;
  late String _timeFormat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _theme = _rawStr(widget.config, 'theme', 'dark');

    // Normalize timeFormat dropdown value.
    final String currentFormat = _rawStr(widget.config, 'timeFormat', 'h:mm a');
    if (currentFormat.contains('a') || currentFormat.contains('t')) {
      _timeFormat = 'h:mm a';
    } else {
      _timeFormat = 'HH:mm';
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final RadarrApi api =
        await ref.read(radarrApiProvider(widget.instance).future);
    final Map<String, dynamic> newRaw = Map<String, dynamic>.of(widget.config)
      ..['theme'] = _theme
      ..['timeFormat'] = _timeFormat;

    try {
      await api.updateUiConfigRaw(newRaw);
      ref.invalidate(radarrUiConfigRawProvider(widget.instance));
      ref.invalidate(radarrUiConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UI settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _theme,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: <String>['auto', 'dark', 'light'].map((String themeName) {
              return DropdownMenuItem<String>(
                value: themeName,
                child: Text(themeName.toUpperCase()),
              );
            }).toList(),
            onChanged: (String? val) {
              if (val != null) {
                setState(() => _theme = val);
              }
            },
          ),
          const SizedBox(height: Insets.md),
          DropdownButtonFormField<String>(
            initialValue: _timeFormat,
            decoration: const InputDecoration(
              labelText: 'Time Format',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'h:mm a', child: Text('12h')),
              DropdownMenuItem<String>(value: 'HH:mm', child: Text('24h')),
            ],
            onChanged: (String? val) {
              if (val != null) {
                setState(() => _timeFormat = val);
              }
            },
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ExpressiveProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _MetadataSettingsPanel extends ConsumerWidget {
  const _MetadataSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> providers =
        ref.watch(radarrMetadataProvidersRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Metadata Consumers', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: providers,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) return const Text('No metadata consumers.');
              return Column(
                children: list.map((Map<String, dynamic> provider) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: _rawBool(provider, 'enable'),
                      onChanged: (bool val) async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        final Map<String, dynamic> newRaw =
                            Map<String, dynamic>.of(provider)..['enable'] = val;
                        await api.updateMetadataProviderRaw(newRaw);
                        ref.invalidate(
                          radarrMetadataProvidersRawProvider(instance),
                        );
                        ref.invalidate(
                          radarrMetadataProvidersProvider(instance),
                        );
                      },
                    ),
                    title: Text(
                      _rawStr(provider, 'name'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Metadata Consumer',
                          onPressed: () async {
                            final RadarrApi api = await ref
                                .read(radarrApiProvider(instance).future);
                            try {
                              await api.testMetadataProviderRaw(provider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Metadata consumer test successful!',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Metadata consumer test failed'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DelayProfileSettingsPanel extends ConsumerWidget {
  const _DelayProfileSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> profiles =
        ref.watch(radarrDelayProfilesRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Delay Profiles', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: profiles,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) {
                return const Text('No delay profiles configured.');
              }
              return Column(
                children: list.map((Map<String, dynamic> profile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Torrent Delay'),
                        value: _rawBool(profile, 'enableTorrent'),
                        onChanged: (bool val) async {
                          final RadarrApi api = await ref
                              .read(radarrApiProvider(instance).future);
                          final Map<String, dynamic> newRaw =
                              Map<String, dynamic>.of(profile)
                                ..['enableTorrent'] = val;
                          await api.updateDelayProfileRaw(newRaw);
                          ref.invalidate(
                            radarrDelayProfilesRawProvider(instance),
                          );
                          ref.invalidate(radarrDelayProfilesProvider(instance));
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Usenet Delay'),
                        value: _rawBool(profile, 'enableUsenet'),
                        onChanged: (bool val) async {
                          final RadarrApi api = await ref
                              .read(radarrApiProvider(instance).future);
                          final Map<String, dynamic> newRaw =
                              Map<String, dynamic>.of(profile)
                                ..['enableUsenet'] = val;
                          await api.updateDelayProfileRaw(newRaw);
                          ref.invalidate(
                            radarrDelayProfilesRawProvider(instance),
                          );
                          ref.invalidate(radarrDelayProfilesProvider(instance));
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Preferred Protocol'),
                        trailing: DropdownButton<String>(
                          value:
                              _rawStr(profile, 'preferredProtocol', 'usenet'),
                          items: <String>['usenet', 'torrent']
                              .map((String protocol) {
                            return DropdownMenuItem<String>(
                              value: protocol,
                              child: Text(protocol.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (String? val) async {
                            if (val != null) {
                              final RadarrApi api = await ref
                                  .read(radarrApiProvider(instance).future);
                              final Map<String, dynamic> newRaw =
                                  Map<String, dynamic>.of(profile)
                                    ..['preferredProtocol'] = val;
                              await api.updateDelayProfileRaw(newRaw);
                              ref.invalidate(
                                radarrDelayProfilesRawProvider(instance),
                              );
                              ref.invalidate(
                                radarrDelayProfilesProvider(instance),
                              );
                            }
                          },
                        ),
                      ),
                      const Divider(),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CustomFormatSettingsPanel extends ConsumerWidget {
  const _CustomFormatSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<RadarrCustomFormat>> formats =
        ref.watch(radarrCustomFormatsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Custom Formats', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<RadarrCustomFormat>>(
            value: formats,
            data: (List<RadarrCustomFormat> list) {
              if (list.isEmpty) {
                return const Text('No custom formats configured.');
              }
              return Column(
                children: list.map((RadarrCustomFormat format) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      format.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Delete Custom Format',
                      onPressed: () async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        await api.deleteCustomFormat(format.id);
                        ref.invalidate(radarrCustomFormatsProvider(instance));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Custom format deleted'),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QualityDefinitionSettingsPanel extends ConsumerWidget {
  const _QualityDefinitionSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> definitions =
        ref.watch(radarrQualityDefinitionsRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Quality Definitions', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: definitions,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) return const Text('No quality definitions.');
              return Column(
                children: list.map((Map<String, dynamic> def) {
                  return _QualityDefinitionRow(
                    instance: instance,
                    definition: def,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QualityDefinitionRow extends ConsumerStatefulWidget {
  const _QualityDefinitionRow({
    required this.instance,
    required this.definition,
  });

  final Instance instance;
  final Map<String, dynamic> definition;

  @override
  ConsumerState<_QualityDefinitionRow> createState() =>
      _QualityDefinitionRowState();
}

class _QualityDefinitionRowState extends ConsumerState<_QualityDefinitionRow> {
  late bool _isUnlimited;
  bool _saving = false;

  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _preferredController;

  double get _origMin =>
      ((widget.definition['minSize'] as num?) ?? 0).toDouble();
  double get _origPreferred =>
      ((widget.definition['preferredSize'] as num?) ?? 0).toDouble();
  bool get _origUnlimited {
    final dynamic rawMax = widget.definition['maxSize'];
    return rawMax == null || (rawMax as num).toDouble() == 0.0;
  }

  double get _origMax => _origUnlimited
      ? 0.0
      : ((widget.definition['maxSize'] as num?) ?? 0).toDouble();

  String get _definitionName {
    final String? title = widget.definition['title'] as String?;
    if (title != null && title.isNotEmpty) return title;
    final Map<String, dynamic>? quality =
        widget.definition['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return (quality['name'] as String?) ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController();
    _maxController = TextEditingController();
    _preferredController = TextEditingController();
    _reset();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _preferredController.dispose();
    super.dispose();
  }

  void _reset() {
    _isUnlimited = _origUnlimited;
    _minController.text = _origMin.toStringAsFixed(1);
    _maxController.text = _isUnlimited ? '' : _origMax.toStringAsFixed(1);
    _preferredController.text = _origPreferred.toStringAsFixed(1);
  }

  @override
  void didUpdateWidget(covariant _QualityDefinitionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const DeepCollectionEquality()
        .equals(oldWidget.definition, widget.definition)) {
      _reset();
    }
  }

  String? get _minError {
    final double? val = double.tryParse(_minController.text);
    if (_minController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    if (val < 0) return 'Must be >= 0';
    return null;
  }

  String? get _preferredError {
    final double? val = double.tryParse(_preferredController.text);
    if (_preferredController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    final double? minVal = double.tryParse(_minController.text);
    if (minVal != null && val < minVal) return 'Must be >= Min';
    return null;
  }

  String? get _maxError {
    if (_isUnlimited) return null;
    final double? val = double.tryParse(_maxController.text);
    if (_maxController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    final double? prefVal = double.tryParse(_preferredController.text);
    if (prefVal != null && val < prefVal) return 'Must be >= Preferred';
    return null;
  }

  bool get _isValid =>
      _minError == null && _preferredError == null && _maxError == null;

  bool get _hasChanges {
    final double? minVal = double.tryParse(_minController.text);
    final double? prefVal = double.tryParse(_preferredController.text);
    final double? maxVal =
        _isUnlimited ? 0.0 : double.tryParse(_maxController.text);

    if (minVal == null ||
        prefVal == null ||
        (!_isUnlimited && maxVal == null)) {
      return true;
    }

    return minVal != _origMin ||
        prefVal != _origPreferred ||
        _isUnlimited != _origUnlimited ||
        (!_isUnlimited && maxVal != _origMax);
  }

  Future<void> _save() async {
    if (!_isValid) return;

    setState(() => _saving = true);
    final RadarrApi api =
        await ref.read(radarrApiProvider(widget.instance).future);

    final double minVal = double.parse(_minController.text);
    final double prefVal = double.parse(_preferredController.text);
    final double maxVal =
        _isUnlimited ? 0.0 : double.parse(_maxController.text);

    final Map<String, dynamic> newRaw =
        Map<String, dynamic>.of(widget.definition)
          ..['minSize'] = minVal
          ..['maxSize'] = maxVal
          ..['preferredSize'] = prefVal;

    try {
      await api.updateQualityDefinitionRaw(newRaw);
      ref.invalidate(radarrQualityDefinitionsRawProvider(widget.instance));
      ref.invalidate(radarrQualityDefinitionsProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quality definition $_definitionName saved!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save quality definition: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Material(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _hasChanges
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
            width: _hasChanges ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _definitionName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _hasChanges
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      if (_hasChanges && !_saving)
                        IconButton(
                          icon: const Icon(Icons.undo, size: 20),
                          tooltip: 'Discard changes',
                          onPressed: () => setState(_reset),
                        ),
                      if (_saving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: ExpressiveProgressIndicator(strokeWidth: 2),
                        )
                      else if (_hasChanges)
                        IconButton(
                          icon: Icon(
                            Icons.check,
                            color: _isValid
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                            size: 20,
                          ),
                          tooltip: _isValid
                              ? 'Save changes'
                              : 'Validation errors exist',
                          onPressed: _isValid ? _save : null,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Min Size',
                        suffixText: 'MB/min',
                        errorText: _minError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (String val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _preferredController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Preferred',
                        suffixText: 'MB/min',
                        errorText: _preferredError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (String val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      enabled: !_isUnlimited,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Max Size',
                        suffixText: _isUnlimited ? '' : 'MB/min',
                        hintText: _isUnlimited ? 'Unlimited' : null,
                        errorText: _maxError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (String val) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Unlimited Max Size',
                  style: theme.textTheme.bodyMedium,
                ),
                value: _isUnlimited,
                onChanged: (bool? val) {
                  setState(() {
                    _isUnlimited = val ?? false;
                    if (_isUnlimited) {
                      _maxController.text = '';
                    } else {
                      final double prefVal =
                          double.tryParse(_preferredController.text) ??
                              _origPreferred;
                      _maxController.text = prefVal.toStringAsFixed(1);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseProfileSettingsPanel extends ConsumerWidget {
  const _ReleaseProfileSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> profiles =
        ref.watch(radarrReleaseProfilesRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Release Profiles', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Release Profile',
              onPressed: () => _showAddProfileDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: profiles,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) {
                return const Text('No release profiles configured.');
              }
              return Column(
                children: list.map((Map<String, dynamic> profile) {
                  final int requiredCount =
                      (profile['required'] as List<dynamic>?)?.length ?? 0;
                  final int ignoredCount =
                      (profile['ignored'] as List<dynamic>?)?.length ?? 0;
                  final int preferredCount =
                      (profile['preferred'] as List<dynamic>?)?.length ?? 0;
                  final String name = _rawStr(profile, 'name');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: _rawBool(profile, 'enabled'),
                      onChanged: (bool val) async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        final Map<String, dynamic> newRaw =
                            Map<String, dynamic>.of(profile)..['enabled'] = val;
                        await api.updateReleaseProfileRaw(newRaw);
                        ref.invalidate(
                          radarrReleaseProfilesRawProvider(instance),
                        );
                        ref.invalidate(radarrReleaseProfilesProvider(instance));
                      },
                    ),
                    title: Text(
                      name.isEmpty ? 'Unnamed Release Profile' : name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Required: $requiredCount • Ignored: $ignoredCount • Preferred: $preferredCount',
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        await api.deleteReleaseProfile(_rawInt(profile, 'id'));
                        ref.invalidate(
                          radarrReleaseProfilesRawProvider(instance),
                        );
                        ref.invalidate(radarrReleaseProfilesProvider(instance));
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Release Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Profile Name'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String name = controller.text.trim();
                if (name.isNotEmpty) {
                  final RadarrApi api =
                      await ref.read(radarrApiProvider(instance).future);
                  await api.createReleaseProfileRaw(<String, dynamic>{
                    'name': name,
                    'enabled': true,
                    'required': <dynamic>[],
                    'ignored': <dynamic>[],
                    'preferred': <dynamic>[],
                    'tags': <dynamic>[],
                  });
                  ref.invalidate(radarrReleaseProfilesRawProvider(instance));
                  ref.invalidate(radarrReleaseProfilesProvider(instance));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _ImportListExclusionSettingsPanel extends ConsumerWidget {
  const _ImportListExclusionSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<RadarrImportListExclusion>> exclusions =
        ref.watch(radarrImportListExclusionsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Import List Exclusions', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Exclusion',
              onPressed: () => _showAddExclusionDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<RadarrImportListExclusion>>(
            value: exclusions,
            data: (List<RadarrImportListExclusion> list) {
              if (list.isEmpty) return const Text('No exclusions configured.');
              return Column(
                children: list.map((RadarrImportListExclusion exclusion) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      exclusion.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('TMDB ID: ${exclusion.tmdbId}'),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        await api.deleteImportListExclusion(exclusion.id);
                        ref.invalidate(
                          radarrImportListExclusionsProvider(instance),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddExclusionDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController tmdbController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Import List Exclusion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Movie Title'),
                autofocus: true,
              ),
              TextField(
                controller: tmdbController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'TMDB ID'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String title = titleController.text.trim();
                final int tmdbId =
                    int.tryParse(tmdbController.text.trim()) ?? 0;
                if (title.isNotEmpty && tmdbId > 0) {
                  final RadarrApi api =
                      await ref.read(radarrApiProvider(instance).future);
                  await api.createImportListExclusionRaw(<String, dynamic>{
                    'movieTitle': title,
                    'tmdbId': tmdbId,
                  });
                  ref.invalidate(
                    radarrImportListExclusionsProvider(instance),
                  );
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _AutoTaggingSettingsPanel extends ConsumerWidget {
  const _AutoTaggingSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> rules =
        ref.watch(radarrAutoTaggingRulesRawProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Auto Tagging Rules', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Auto Tagging Rule',
              onPressed: () => _showAddRuleDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: rules,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) return const Text('No auto tagging rules.');
              return Column(
                children: list.map((Map<String, dynamic> rule) {
                  final int specCount =
                      (rule['specifications'] as List<dynamic>?)?.length ?? 0;
                  final int tagCount =
                      (rule['tags'] as List<dynamic>?)?.length ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _rawStr(rule, 'name'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Specifications: $specCount • Tags: $tagCount',
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () async {
                        final RadarrApi api =
                            await ref.read(radarrApiProvider(instance).future);
                        await api.deleteAutoTaggingRule(_rawInt(rule, 'id'));
                        ref.invalidate(
                          radarrAutoTaggingRulesRawProvider(instance),
                        );
                        ref.invalidate(
                            radarrAutoTaggingRulesProvider(instance));
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Auto Tagging Rule'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Rule Name'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String name = controller.text.trim();
                if (name.isNotEmpty) {
                  final RadarrApi api =
                      await ref.read(radarrApiProvider(instance).future);
                  await api.createAutoTaggingRuleRaw(<String, dynamic>{
                    'name': name,
                    'tags': <dynamic>[],
                    'specifications': <dynamic>[],
                  });
                  ref.invalidate(radarrAutoTaggingRulesRawProvider(instance));
                  ref.invalidate(radarrAutoTaggingRulesProvider(instance));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _QualityProfileSettingsPanel extends ConsumerWidget {
  const _QualityProfileSettingsPanel({required this.instance});

  final Instance instance;

  int _getItemId(Map<String, dynamic> item) {
    final int? id = (item['id'] as num?)?.toInt();
    if (id != null && id != 0) return id;
    final Map<String, dynamic>? quality =
        item['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return ((quality['id'] as num?) ?? 0).toInt();
    }
    return 0;
  }

  String _getItemName(Map<String, dynamic> item) {
    final String? name = item['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final Map<String, dynamic>? quality =
        item['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return (quality['name'] as String?) ?? '';
    }
    return '';
  }

  List<Map<String, dynamic>> _getAllowedQualities(List<dynamic> items) {
    final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    void helper(List<dynamic> listItems) {
      for (final dynamic item in listItems) {
        final Map<String, dynamic> itemMap = item as Map<String, dynamic>;
        final List<dynamic>? nested = itemMap['items'] as List<dynamic>?;
        if (nested != null && nested.isNotEmpty) {
          helper(nested);
        } else {
          if (itemMap['allowed'] == true) {
            list.add(itemMap);
          }
        }
      }
    }

    helper(items);
    return list;
  }

  Widget _buildQualityItemTile(
    BuildContext context,
    Map<String, dynamic> item,
    StateSetter setState, {
    bool readOnly = false,
  }) {
    final List<dynamic>? nestedItems = item['items'] as List<dynamic>?;
    final String name = _getItemName(item);
    final bool allowed = (item['allowed'] as bool?) ?? false;

    if (nestedItems != null && nestedItems.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        child: ExpansionTile(
          initiallyExpanded: readOnly,
          title: Row(
            children: <Widget>[
              Checkbox(
                value: allowed,
                onChanged: readOnly
                    ? null
                    : (bool? val) {
                        setState(() {
                          item['allowed'] = val ?? false;
                          for (final dynamic sub in nestedItems) {
                            (sub as Map<String, dynamic>)['allowed'] =
                                val ?? false;
                          }
                        });
                      },
              ),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          children: nestedItems
              .map(
                (dynamic sub) => _buildQualityItemTile(
                  context,
                  sub as Map<String, dynamic>,
                  setState,
                  readOnly: readOnly,
                ),
              )
              .toList(),
        ),
      );
    } else {
      return CheckboxListTile(
        title: Text(name),
        value: allowed,
        onChanged: readOnly
            ? null
            : (bool? val) {
                setState(() {
                  item['allowed'] = val ?? false;
                });
              },
      );
    }
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? profile, {
    bool readOnly = false,
  }) async {
    final RadarrApi api = await ref.read(radarrApiProvider(instance).future);

    Map<String, dynamic> payload;
    if (profile != null) {
      payload = jsonDecode(jsonEncode(profile)) as Map<String, dynamic>;
    } else {
      final Map<String, dynamic> schema =
          await ref.read(radarrQualityProfileSchemaProvider(instance).future);
      payload = jsonDecode(jsonEncode(schema)) as Map<String, dynamic>;
      payload['name'] = '';
      payload['upgradeAllowed'] = true;
    }

    if (!context.mounted) return;

    final TextEditingController nameController =
        TextEditingController(text: payload['name'] as String? ?? '');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final ThemeData theme = Theme.of(context);
            final List<dynamic> itemsList =
                (payload['items'] as List<dynamic>?) ?? <dynamic>[];
            final List<Map<String, dynamic>> allowedQualities =
                _getAllowedQualities(itemsList);

            int cutoffId = (payload['cutoff'] as num? ?? 0).toInt();
            if (cutoffId == 0 && allowedQualities.isNotEmpty) {
              cutoffId = _getItemId(allowedQualities.first);
              payload['cutoff'] = cutoffId;
            } else if (allowedQualities.isNotEmpty &&
                !allowedQualities.any(
                    (Map<String, dynamic> q) => _getItemId(q) == cutoffId)) {
              cutoffId = _getItemId(allowedQualities.first);
              payload['cutoff'] = cutoffId;
            }

            return AlertDialog(
              title: Text(
                profile != null
                    ? (readOnly
                        ? 'View Quality Profile'
                        : 'Edit Quality Profile')
                    : 'Add Quality Profile',
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: ListView(
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      enabled: !readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Profile Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String val) => payload['name'] = val.trim(),
                    ),
                    const SizedBox(height: Insets.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Upgrades Allowed'),
                      value: (payload['upgradeAllowed'] as bool?) ?? false,
                      onChanged: readOnly
                          ? null
                          : (bool val) =>
                              setState(() => payload['upgradeAllowed'] = val),
                    ),
                    if (payload['upgradeAllowed'] == true &&
                        allowedQualities.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      DropdownButtonFormField<int>(
                        initialValue: cutoffId,
                        decoration: const InputDecoration(
                          labelText: 'Upgrade Cutoff',
                          border: OutlineInputBorder(),
                        ),
                        items: allowedQualities.map((Map<String, dynamic> q) {
                          final int qId = _getItemId(q);
                          final String qName = _getItemName(q);
                          return DropdownMenuItem<int>(
                            value: qId,
                            child: Text(qName),
                          );
                        }).toList(),
                        onChanged: readOnly
                            ? null
                            : (int? val) {
                                if (val != null) {
                                  setState(() => payload['cutoff'] = val);
                                }
                              },
                      ),
                    ],
                    const SizedBox(height: Insets.md),
                    Text('Allowed Qualities',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: Insets.xs),
                    ...itemsList.map(
                      (dynamic item) => _buildQualityItemTile(
                        context,
                        item as Map<String, dynamic>,
                        setState,
                        readOnly: readOnly,
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                if (readOnly)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  )
                else ...<Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final String name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        payload['name'] = name;
                        if (profile != null) {
                          await api.updateQualityProfileRaw(payload);
                        } else {
                          await api.createQualityProfileRaw(payload);
                        }
                        ref.invalidate(
                          radarrQualityProfilesRawProvider(instance),
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(profile != null ? 'Save' : 'Add'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> profiles =
        ref.watch(radarrQualityProfilesRawProvider(instance));
    final AsyncValue<List<RadarrQualityDefinition>> definitions =
        ref.watch(radarrQualityDefinitionsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Quality Profiles', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Quality Profile',
              onPressed: () => _showEditProfileDialog(context, ref, null),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          AsyncValueView<List<Map<String, dynamic>>>(
            value: profiles,
            data: (List<Map<String, dynamic>> list) {
              if (list.isEmpty) return const Text('No quality profiles.');
              return Column(
                children: list.map((Map<String, dynamic> profile) {
                  final String name = _rawStr(profile, 'name');
                  final bool upgradeAllowed =
                      _rawBool(profile, 'upgradeAllowed');
                  final int cutoffId = (profile['cutoff'] as num? ?? 0).toInt();

                  final String cutoffName = definitions.maybeWhen(
                    data: (List<RadarrQualityDefinition> defs) =>
                        defs
                            .firstWhereOrNull(
                              (RadarrQualityDefinition d) => d.id == cutoffId,
                            )
                            ?.name ??
                        'Unknown',
                    orElse: () => '...',
                  );

                  final List<dynamic> itemsList =
                      (profile['items'] as List<dynamic>?) ?? <dynamic>[];
                  final List<Map<String, dynamic>> allowedQualities =
                      _getAllowedQualities(itemsList);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showEditProfileDialog(
                      context,
                      ref,
                      profile,
                      readOnly: true,
                    ),
                    title: Text(
                      name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Upgrades: ${upgradeAllowed ? "Yes (Cutoff: $cutoffName)" : "No"}\n'
                      'Allowed: ${allowedQualities.length} qualities',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Quality Profile',
                          onPressed: () =>
                              _showEditProfileDialog(context, ref, profile),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: 'Delete Quality Profile',
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text('Delete Quality Profile?'),
                                content: Text(
                                  'Are you sure you want to delete profile "$name"?',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.colorScheme.error,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final RadarrApi api = await ref
                                  .read(radarrApiProvider(instance).future);
                              await api.deleteQualityProfile(
                                _rawInt(profile, 'id'),
                              );
                              ref.invalidate(
                                radarrQualityProfilesRawProvider(instance),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
