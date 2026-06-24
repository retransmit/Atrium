import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_movie_screen.dart';
import 'models/radarr_movie.dart';
import 'models/radarr_queue.dart';
import 'movie_detail_screen.dart';
import 'radarr_api.dart';
import 'radarr_providers.dart';

/// Radarr's per-instance UI: a tabbed Movies / Queue view. Mirrors `SonarrHome`.
class RadarrHome extends StatelessWidget {
  const RadarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(text: 'Movies'),
                Tab(text: 'Queue'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _MoviesTab(instance: instance),
                  _QueueTab(instance: instance),
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
  RadarrSortOption.titleAsc || RadarrSortOption.titleDesc => _SortField.title,
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
  _SortField.title => asc ? RadarrSortOption.titleAsc : RadarrSortOption.titleDesc,
  _SortField.year => asc ? RadarrSortOption.yearAsc : RadarrSortOption.yearDesc,
  _SortField.size => asc ? RadarrSortOption.sizeAsc : RadarrSortOption.sizeDesc,
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
              child: RefreshIndicator(
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
                        message: 'Try adjusting your search query or active filters.',
                      );
                    }
                    return GridView.builder(
                      padding: Insets.page,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                        return _MovieCard(
                          movie: m,
                          imageUrl: poster == null ? null : api?.posterUrl(poster),
                          onTap: () =>
                              Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MovieDetailScreen(
                                instance: instance,
                                movieId: m.id,
                              ),
                            ),
                          ),
                          onLongPress: () => _showQuickActions(context, ref, m),
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
    final RadarrSortOption sortOption = ref.watch(radarrSortOptionProvider(instance));
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
              for (final RadarrMonitoredFilter f in RadarrMonitoredFilter.values)
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
      memCacheWidth: 500,
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
    return RefreshIndicator(
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
