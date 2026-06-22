import 'dart:convert';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'add_series_screen.dart';
import 'models/sonarr_blocklist.dart';
import 'models/sonarr_history.dart';
import 'models/sonarr_queue.dart';
import 'models/sonarr_series.dart';
import 'models/sonarr_settings_models.dart';
import 'models/sonarr_system.dart';
import 'models/sonarr_wanted.dart';
import 'series_detail_screen.dart';
import 'sonarr_api.dart';
import 'sonarr_providers.dart';
import 'sonarr_settings_form_screen.dart';

/// Sonarr's per-instance UI: a tabbed Series / Queue / Wanted / History / Blocklist / System view.
class SonarrHome extends ConsumerStatefulWidget {
  const SonarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<SonarrHome> createState() => _SonarrHomeState();
}

class _SonarrHomeState extends ConsumerState<SonarrHome> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(sonarrActiveTabBarIndexProvider(widget.instance).notifier).state = _tabController.index;
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      if (ref.read(sonarrActiveTabBarIndexProvider(widget.instance)) != _tabController.index) {
        ref.read(sonarrActiveTabBarIndexProvider(widget.instance).notifier).state = _tabController.index;
      }
    }
  }

  @override
  void didUpdateWidget(SonarrHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instance.id != widget.instance.id) {
      ref.read(sonarrActiveTabBarIndexProvider(widget.instance).notifier).state = _tabController.index;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const <Widget>[
              Tab(text: 'Series'),
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
              controller: _tabController,
              children: <Widget>[
                _SeriesTab(instance: widget.instance),
                _QueueTab(instance: widget.instance),
                _WantedTab(instance: widget.instance),
                _HistoryTab(instance: widget.instance),
                _BlocklistTab(instance: widget.instance),
                _SystemTab(instance: widget.instance),
                _SettingsTab(instance: widget.instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesTab extends ConsumerWidget {
  const _SeriesTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SonarrSeries>> filteredSeries =
        ref.watch(sonarrFilteredSeriesProvider(instance));
    final SonarrApi? api =
        ref.watch(sonarrApiProvider(instance)).value;
    final SonarrViewMode viewMode = ref.watch(sonarrViewModeProvider(instance));
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.xs),
              child: _SearchBar(instance: instance),
            ),
            _FilterChipsRow(instance: instance),
            const SizedBox(height: Insets.xs),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(sonarrSeriesProvider(instance));
                  await ref.read(sonarrSeriesProvider(instance).future);
                },
                child: AsyncValueView<List<SonarrSeries>>(
                  value: filteredSeries,
                  onRetry: () => ref.invalidate(sonarrSeriesProvider(instance)),
                  data: (List<SonarrSeries> list) {
                    if (list.isEmpty) {
                      return const EmptyView(
                        icon: Icons.live_tv_outlined,
                        title: 'No series found',
                        message: 'Try adjusting your search query or active filters.',
                      );
                    }
                    if (viewMode == SonarrViewMode.grid) {
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
                          final SonarrSeries s = list[index];
                          final SonarrImage? poster = s.images
                              .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
                          return _SeriesCard(
                            series: s,
                            imageUrl: poster == null ? null : api?.posterUrl(poster),
                            onTap: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SeriesDetailScreen(
                                  instance: instance,
                                  seriesId: s.id,
                                ),
                              ),
                            ),
                            onLongPress: () => _showQuickActions(context, ref, s),
                          );
                        },
                      );
                    } else {
                      return ListView.builder(
                        padding: Insets.page,
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int index) {
                          final SonarrSeries s = list[index];
                          return _SeriesBannerCard(
                            instance: instance,
                            series: s,
                            onTap: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SeriesDetailScreen(
                                  instance: instance,
                                  seriesId: s.id,
                                ),
                              ),
                            ),
                            onLongPress: () => _showQuickActions(context, ref, s),
                          );
                        },
                      );
                    }
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
            builder: (_) => AddSeriesScreen(instance: instance),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _toggleMonitored(WidgetRef ref, SonarrSeries s) async {
    final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
    final Map<String, dynamic> raw = await api.getSeriesRaw(s.id);
    raw['monitored'] = !s.monitored;
    await api.updateSeriesRaw(raw);
    ref.invalidate(sonarrSeriesProvider(instance));
  }

  void _showQuickActions(BuildContext context, WidgetRef ref, SonarrSeries s) {
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
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: s.year != null ? Text('${s.year}') : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  s.monitored ? Icons.bookmark : Icons.bookmark_border,
                ),
                title: Text(s.monitored ? 'Unmonitor' : 'Monitor'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _toggleMonitored(ref, s);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.monitored
                              ? 'Stopped monitoring ${s.title}'
                              : 'Monitoring ${s.title}',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search all episodes'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final SonarrApi api =
                      await ref.read(sonarrApiProvider(instance).future);
                  await api.searchSeries(s.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Search started for ${s.title}')),
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
                      builder: (_) => SeriesDetailScreen(
                        instance: instance,
                        seriesId: s.id,
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

/// Poster card for a single series.
///
/// Visual structure mirrors `service_jellyfin`'s `_PosterCard` so that
/// browsing across services feels consistent.
class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.imageUrl,
    required this.onTap,
    this.onLongPress,
  });

  final SonarrSeries series;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<SonarrSeasonStats> monitoredSeasons = series.seasons
        .where((SonarrSeasonStats s) => s.monitored)
        .sorted((SonarrSeasonStats a, SonarrSeasonStats b) => b.seasonNumber.compareTo(a.seasonNumber));

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
                  if (series.monitored)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        color: theme.colorScheme.primary,
                        child: Icon(
                          Icons.bookmark,
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  if (monitoredSeasons.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: monitoredSeasons.map((SonarrSeasonStats s) {
                            final double seasonProgress = (s.statistics == null || s.statistics!.totalEpisodeCount == 0)
                                ? 0
                                : (s.statistics!.episodeFileCount / s.statistics!.totalEpisodeCount).clamp(0, 1);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: seasonProgress.toDouble(),
                                    minHeight: 4,
                                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
                    series.title,
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
      if (series.year != null) '${series.year}',
    ];
    final List<SonarrSeasonStats> monitoredSeasons = series.seasons
        .where((SonarrSeasonStats s) => s.monitored)
        .sorted((SonarrSeasonStats a, SonarrSeasonStats b) => b.seasonNumber.compareTo(a.seasonNumber));
    if (monitoredSeasons.isNotEmpty) {
      final String seasonStatsList = monitoredSeasons.map((SonarrSeasonStats s) {
        final String label = s.seasonNumber == 0 ? 'Specials' : 'S${s.seasonNumber}';
        final int fileCount = s.statistics?.episodeFileCount ?? 0;
        final int totalCount = s.statistics?.totalEpisodeCount ?? 0;
        return '$label: $fileCount/$totalCount';
      }).join(', ');
      parts.add(seasonStatsList);
    }
    return parts.join(' • ');
  }
}

class _SeriesBannerCard extends ConsumerWidget {
  const _SeriesBannerCard({
    required this.instance,
    required this.series,
    required this.onTap,
    this.onLongPress,
  });

  final Instance instance;
  final SonarrSeries series;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SonarrApi? api = ref.watch(sonarrApiProvider(instance)).value;

    final SonarrImage? banner = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'banner');
    final String? bannerUrl = banner == null ? null : api?.posterUrl(banner);

    final SonarrImage? poster = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
    final String? posterUrl = poster == null ? null : api?.posterUrl(poster);

    final SonarrSeriesStatistics? stats = series.statistics;

    final List<SonarrSeasonStats> monitoredSeasons = series.seasons
        .where((SonarrSeasonStats s) => s.monitored)
        .sorted((SonarrSeasonStats a, SonarrSeasonStats b) => b.seasonNumber.compareTo(a.seasonNumber));

    Widget buildMetaChip(String label, {bool isPrimary = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isPrimary
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isPrimary ? theme.colorScheme.primary : Colors.white,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.md),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 142,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Background banner image aligned to the right
              if (bannerUrl != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: bannerUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              // Dark gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.2),
                      ],
                      stops: const <double>[0.4, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Content overlay
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: <Widget>[
                    // Show Cover (Poster) on the left
                    Container(
                      width: 75,
                      height: 112,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.live_tv, size: 24),
                                ),
                              )
                            : Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.live_tv, size: 24),
                              ),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    // Show Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: const <Shadow>[
                                Shadow(
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Meta tags
                          Wrap(
                            spacing: Insets.xs,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              if (series.year != null)
                                buildMetaChip('${series.year}'),
                              if (series.seasonCount > 0)
                                buildMetaChip(
                                  '${series.seasonCount} ${series.seasonCount == 1 ? 'season' : 'seasons'}',
                                ),
                              if (series.status != null)
                                buildMetaChip(
                                  series.status!,
                                  isPrimary: series.status?.toLowerCase() == 'continuing',
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Stats row (Size on disk)
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.sd_storage_outlined,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _fmtSize(stats?.sizeOnDisk ?? 0),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (monitoredSeasons.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 32,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: monitoredSeasons.length,
                                itemBuilder: (BuildContext context, int idx) {
                                  final SonarrSeasonStats s = monitoredSeasons[idx];
                                  final double seasonProgress = (s.statistics == null || s.statistics!.totalEpisodeCount == 0)
                                      ? 0
                                      : (s.statistics!.episodeFileCount / s.statistics!.totalEpisodeCount).clamp(0, 1);
                                  final String label = s.seasonNumber == 0 ? 'Specials' : 'S${s.seasonNumber}';
                                  final int fileCount = s.statistics?.episodeFileCount ?? 0;
                                  final int totalCount = s.statistics?.totalEpisodeCount ?? 0;
                                  return Container(
                                    width: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Text(
                                          '$label: $fileCount/$totalCount',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: seasonProgress.toDouble(),
                                            minHeight: 3,
                                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              theme.colorScheme.primary,
                                            ),
                                          ),
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
                    ),
                    const SizedBox(width: Insets.sm),
                    // Monitored badge
                    if (series.monitored)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bookmark,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtSize(int bytes) {
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
  final String text =
      value >= 100 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
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
    final String initialQuery = ref.read(sonarrSearchQueryProvider(widget.instance));
    _controller = TextEditingController(text: initialQuery);
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
      hintText: 'Search series...',
      leading: const Icon(Icons.search),
      trailing: <Widget>[
        if (_controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _controller.clear();
              });
              ref.read(sonarrSearchQueryProvider(widget.instance).notifier).state = '';
              _focusNode.unfocus();
            },
          ),
      ],
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(
        theme.colorScheme.surfaceContainerHigh,
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        StadiumBorder(),
      ),
      onChanged: (String val) {
        setState(() {}); // to show/hide the clear button
        ref.read(sonarrSearchQueryProvider(widget.instance).notifier).state = val;
      },
    );
  }
}

/// Sort field, decoupled from direction so the chip can flip asc/desc in place.
enum _SortField { title, year, size, progress }

_SortField _sortFieldOf(SonarrSortOption o) => switch (o) {
  SonarrSortOption.titleAsc || SonarrSortOption.titleDesc => _SortField.title,
  SonarrSortOption.yearAsc || SonarrSortOption.yearDesc => _SortField.year,
  SonarrSortOption.sizeAsc || SonarrSortOption.sizeDesc => _SortField.size,
  SonarrSortOption.progressAsc ||
  SonarrSortOption.progressDesc =>
    _SortField.progress,
};

bool _sortIsAsc(SonarrSortOption o) => switch (o) {
  SonarrSortOption.titleAsc ||
  SonarrSortOption.yearAsc ||
  SonarrSortOption.sizeAsc ||
  SonarrSortOption.progressAsc =>
    true,
  _ => false,
};

SonarrSortOption _composeSort(_SortField field, bool asc) => switch (field) {
  _SortField.title => asc ? SonarrSortOption.titleAsc : SonarrSortOption.titleDesc,
  _SortField.year => asc ? SonarrSortOption.yearAsc : SonarrSortOption.yearDesc,
  _SortField.size => asc ? SonarrSortOption.sizeAsc : SonarrSortOption.sizeDesc,
  _SortField.progress =>
    asc ? SonarrSortOption.progressAsc : SonarrSortOption.progressDesc,
};

String _sortFieldLabel(_SortField f) => switch (f) {
  _SortField.title => 'Title',
  _SortField.year => 'Year',
  _SortField.size => 'Size',
  _SortField.progress => 'Progress',
};

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SonarrSortOption sortOption = ref.watch(sonarrSortOptionProvider(instance));
    final SonarrStatusFilter statusFilter = ref.watch(sonarrStatusFilterProvider(instance));
    final SonarrMonitoredFilter monitoredFilter = ref.watch(sonarrMonitoredFilterProvider(instance));

    final _SortField sortField = _sortFieldOf(sortOption);
    final bool asc = _sortIsAsc(sortOption);

    String statusLabel(SonarrStatusFilter flt) => switch (flt) {
      SonarrStatusFilter.all => 'All',
      SonarrStatusFilter.continuing => 'Continuing',
      SonarrStatusFilter.ended => 'Ended',
    };

    String monitoredLabel(SonarrMonitoredFilter flt) => switch (flt) {
      SonarrMonitoredFilter.all => 'All',
      SonarrMonitoredFilter.monitored => 'Monitored',
      SonarrMonitoredFilter.unmonitored => 'Unmonitored',
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
          // Sort field (menu) + direction (tap to flip A-Z / Z-A).
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
                      .read(sonarrSortOptionProvider(instance).notifier)
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
              ref.read(sonarrSortOptionProvider(instance).notifier).state =
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
                statusFilter == SonarrStatusFilter.all
                    ? Icons.filter_alt_outlined
                    : Icons.filter_alt,
                size: 18,
              ),
              label: Text('Status: ${statusLabel(statusFilter)}'),
              backgroundColor: statusFilter != SonarrStatusFilter.all
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
              for (final SonarrStatusFilter flt in SonarrStatusFilter.values)
                MenuItemButton(
                  leadingIcon: Icon(
                    flt == statusFilter ? Icons.check : Icons.tv_outlined,
                    size: 18,
                  ),
                  onPressed: () => ref
                      .read(sonarrStatusFilterProvider(instance).notifier)
                      .state = flt,
                  child: Text(statusLabel(flt)),
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
                monitoredFilter == SonarrMonitoredFilter.all
                    ? Icons.bookmark_border
                    : Icons.bookmark,
                size: 18,
              ),
              label: Text('Monitored: ${monitoredLabel(monitoredFilter)}'),
              backgroundColor: monitoredFilter != SonarrMonitoredFilter.all
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
              for (final SonarrMonitoredFilter flt
                  in SonarrMonitoredFilter.values)
                MenuItemButton(
                  leadingIcon: Icon(
                    flt == monitoredFilter
                        ? Icons.check
                        : Icons.bookmark_border,
                    size: 18,
                  ),
                  onPressed: () => ref
                      .read(sonarrMonitoredFilterProvider(instance).notifier)
                      .state = flt,
                  child: Text(monitoredLabel(flt)),
                ),
            ],
          ),
        ],
      ),
    );
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
      child: Icon(
        Icons.live_tv_outlined,
        color: theme.colorScheme.outline,
      ),
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
      errorWidget: (BuildContext context, String url, Object error) =>
          fallback,
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

class _QueueItem {
  _QueueItem({required this.downloadId, required this.records});

  final String? downloadId;
  final List<SonarrQueueRecord> records;

  bool get isGrouped => records.length > 1;
  SonarrQueueRecord get primary => records.first;
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SonarrQueuePage> queue =
        ref.watch(sonarrQueueProvider(instance));
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        try {
          final SonarrApi api = await ref.read(
            sonarrApiProvider(instance).future,
          );
          await api.runSystemTask('RefreshMonitoredDownloads');
        } catch (_) {}
        ref.invalidate(sonarrQueueProvider(instance));
        await ref.read(sonarrQueueProvider(instance).future);
      },
      child: AsyncValueView<SonarrQueuePage>(
        value: queue,
        onRetry: () => ref.invalidate(sonarrQueueProvider(instance)),
        data: (SonarrQueuePage page) {
          if (page.records.isEmpty) {
            return const EmptyView(
              icon: Icons.download_done_outlined,
              title: 'Queue is empty',
              message: 'Nothing downloading right now.',
            );
          }

          // Group records by downloadId (season pack / sessional grab)
          final List<_QueueItem> items = <_QueueItem>[];
          final Map<String, List<SonarrQueueRecord>> groups = <String, List<SonarrQueueRecord>>{};

          for (final SonarrQueueRecord r in page.records) {
            final String? dId = r.downloadId;
            if (dId != null && dId.isNotEmpty) {
              groups.putIfAbsent(dId, () => <SonarrQueueRecord>[]).add(r);
            } else {
              items.add(_QueueItem(downloadId: null, records: <SonarrQueueRecord>[r]));
            }
          }

          groups.forEach((String dId, List<SonarrQueueRecord> list) {
            items.add(_QueueItem(downloadId: dId, records: list));
          });

          // Sort items by their original order in page.records
          items.sort((_QueueItem a, _QueueItem b) {
            final int indexA = page.records.indexOf(a.primary);
            final int indexB = page.records.indexOf(b.primary);
            return indexA.compareTo(indexB);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final _QueueItem item = items[index];
              final SonarrQueueRecord r = item.primary;
              final double progress = r.size <= 0
                  ? 0
                  : ((r.size - r.sizeleft) / r.size).clamp(0, 1).toDouble();
              final int progressPct = (progress * 100).round();
              final String sizeStr = _formatBytes(r.size.toInt());
              final String sizeLeftStr = _formatBytes(r.sizeleft.toInt());
              final String sizeDoneStr = _formatBytes((r.size - r.sizeleft).toInt());

              final bool hasWarning = item.records.any(
                (SonarrQueueRecord rec) =>
                    rec.trackedDownloadStatus?.toLowerCase() == 'warning' ||
                    rec.statusMessages.isNotEmpty,
              );
              final bool hasError = item.records.any(
                (SonarrQueueRecord rec) =>
                    rec.trackedDownloadStatus?.toLowerCase() == 'error',
              );

              IconData stateIcon = Icons.cloud_download_outlined;
              Color stateColor = colors.primary;

              if (hasError) {
                stateIcon = Icons.error_outline;
                stateColor = colors.error;
              } else if (hasWarning) {
                stateIcon = Icons.warning_amber_rounded;
                stateColor = Colors.orange;
              } else if (r.status?.toLowerCase() == 'paused') {
                stateIcon = Icons.pause_circle_outline;
                stateColor = colors.outline;
              } else if (r.status?.toLowerCase() == 'completed' || progress >= 0.999) {
                stateIcon = Icons.check_circle_outline;
                stateColor = Colors.green;
              }

              final List<SonarrQueueStatusMessage> combinedMessages = item.records
                  .expand((SonarrQueueRecord rec) => rec.statusMessages)
                  .toList();

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.md),
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: InkWell(
                  onTap: r.seriesId != null
                      ? () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SeriesDetailScreen(
                                instance: instance,
                                seriesId: r.seriesId!,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(stateIcon, color: stateColor, size: 24),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  r.title ?? 'Item ${r.id}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: Insets.xs,
                                  runSpacing: Insets.xs,
                                  children: <Widget>[
                                    if (item.isGrouped)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: colors.primary.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          'SEASON GRAB (${item.records.length} EPS)',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (r.downloadClient != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          r.downloadClient!,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    if (r.protocol != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          r.protocol!.toUpperCase(),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Insets.xs),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: colors.error.withValues(alpha: 0.8),
                            onPressed: () async {
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                  title: Text(item.isGrouped ? 'Remove Season Grab?' : 'Remove from Queue?'),
                                  content: Text(
                                    item.isGrouped
                                        ? 'Are you sure you want to remove the season grab for "${r.title ?? 'this series'}" (${item.records.length} episodes)?'
                                        : r.title ?? 'this item',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colors.error,
                                        foregroundColor: colors.onError,
                                      ),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final SonarrApi api =
                                    await ref.read(sonarrApiProvider(instance).future);
                                if (item.isGrouped) {
                                  await Future.wait(
                                    item.records.map((SonarrQueueRecord rec) => api.deleteQueueItem(rec.id)),
                                  );
                                } else {
                                  await api.deleteQueueItem(r.id);
                                }
                                ref.invalidate(sonarrQueueProvider(instance));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: colors.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Text(
                            '$progressPct%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: stateColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '$sizeDoneStr of $sizeStr ($sizeLeftStr left)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Flexible(
                            child: Text(
                              <String?>[
                                if (r.status != null) r.status,
                                if (r.timeleft != null) r.timeleft,
                              ].whereType<String>().join(' • '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (combinedMessages.isNotEmpty) ...<Widget>[
                        const SizedBox(height: Insets.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Insets.sm),
                          decoration: BoxDecoration(
                            color: (hasError ? colors.error : Colors.orange).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (hasError ? colors.error : Colors.orange).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    hasError ? Icons.error_outline : Icons.warning_amber_rounded,
                                    color: hasError ? colors.error : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      hasError ? 'Error Details' : 'Warning Details',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: hasError ? colors.error : Colors.orange[800] ?? Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...combinedMessages.map((SonarrQueueStatusMessage msg) {
                                final List<String> details = msg.messages;
                                final String text = msg.title ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (text.isNotEmpty)
                                        Text(
                                          '• $text',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: hasError ? colors.error : Colors.orange[800] ?? Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (details.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 12.0),
                                          child: Text(
                                            details.join('\n'),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: hasError ? colors.error.withValues(alpha: 0.8) : (Colors.orange[900] ?? Colors.orange).withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
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

class _WantedTab extends StatefulWidget {
  const _WantedTab({required this.instance});

  final Instance instance;

  @override
  State<_WantedTab> createState() => _WantedTabState();
}

class _WantedTabState extends State<_WantedTab> {
  int _missingPage = 1;
  int _cutoffPage = 1;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: <Widget>[
              Tab(text: 'Missing'),
              Tab(text: 'Cutoff Unmet'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _WantedMissingSubTab(
                  instance: widget.instance,
                  page: _missingPage,
                  onPageChanged: (p) => setState(() => _missingPage = p),
                ),
                _WantedCutoffSubTab(
                  instance: widget.instance,
                  page: _cutoffPage,
                  onPageChanged: (p) => setState(() => _cutoffPage = p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WantedEpisodeCard extends StatefulWidget {
  const _WantedEpisodeCard({
    required this.record,
    required this.imageUrl,
    required this.onSearch,
    required this.onTap,
    super.key,
  });

  final SonarrWantedRecord record;
  final String? imageUrl;
  final Future<void> Function() onSearch;
  final VoidCallback onTap;

  @override
  State<_WantedEpisodeCard> createState() => _WantedEpisodeCardState();
}

class _WantedEpisodeCardState extends State<_WantedEpisodeCard> {
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    String formattedAirDate = 'Unknown';
    if (widget.record.airDate != null) {
      try {
        final DateTime dt = DateTime.parse(widget.record.airDate!);
        formattedAirDate = DateFormat('yMMMd').format(dt);
      } catch (_) {
        formattedAirDate = widget.record.airDate!;
      }
    }

    final String epCode = 'S${widget.record.seasonNumber.toString().padLeft(2, '0')}E${widget.record.episodeNumber.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 68,
                  height: 102,
                  child: widget.imageUrl == null
                      ? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.live_tv_outlined,
                            color: theme.colorScheme.outline,
                            size: 24,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (BuildContext context, String url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.live_tv_outlined,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.record.series?.title ?? 'Unknown Series',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            epCode,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.record.title ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Aired: $formattedAirDate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Align(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: 'Search for this episode',
                          onPressed: () async {
                            setState(() {
                              _isSearching = true;
                            });
                            try {
                              await widget.onSearch();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isSearching = false;
                                });
                              }
                            }
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WantedMissingSubTab extends ConsumerStatefulWidget {
  const _WantedMissingSubTab({
    required this.instance,
    required this.page,
    required this.onPageChanged,
  });

  final Instance instance;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  ConsumerState<_WantedMissingSubTab> createState() => _WantedMissingSubTabState();
}

class _WantedMissingSubTabState extends ConsumerState<_WantedMissingSubTab> {
  bool _isSearchingAll = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SonarrWantedPage> missing =
        ref.watch(sonarrWantedMissingProvider((widget.instance, widget.page)));
    final SonarrApi? api = ref.watch(sonarrApiProvider(widget.instance)).value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrWantedMissingProvider((widget.instance, widget.page)));
        await ref.read(sonarrWantedMissingProvider((widget.instance, widget.page)).future);
      },
      child: AsyncValueView<SonarrWantedPage>(
        value: missing,
        onRetry: () => ref.invalidate(sonarrWantedMissingProvider((widget.instance, widget.page))),
        data: (SonarrWantedPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.check_circle_outline,
              title: 'No missing episodes',
              message: 'Everything is up to date!',
            );
          }

          final int totalPages = (dataPage.totalRecords / dataPage.pageSize).ceil().clamp(1, double.infinity).toInt();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${dataPage.totalRecords} missing episodes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    _isSearchingAll
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () async {
                              setState(() {
                                _isSearchingAll = true;
                              });
                              try {
                                final SonarrApi apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                                await apiObj.triggerMissingSearch();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Missing episode search triggered')),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isSearchingAll = false;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('Search All'),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: Insets.pageH,
                  itemCount: dataPage.records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SonarrWantedRecord record = dataPage.records[index];
                    final SonarrImage? poster = record.series?.images.firstWhereOrNull((SonarrImage img) => img.coverType == 'poster');
                    final String? imageUrl = poster != null ? api?.posterUrl(poster) : null;

                    return _WantedEpisodeCard(
                      key: ValueKey<int>(record.id),
                      record: record,
                      imageUrl: imageUrl,
                      onSearch: () async {
                        final SonarrApi apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                        await apiObj.searchEpisode(record.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Search triggered for S${record.seasonNumber}E${record.episodeNumber}')),
                          );
                        }
                      },
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SeriesDetailScreen(
                            instance: widget.instance,
                            seriesId: record.seriesId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  currentPage: widget.page,
                  totalPages: totalPages,
                  onPageChanged: widget.onPageChanged,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WantedCutoffSubTab extends ConsumerStatefulWidget {
  const _WantedCutoffSubTab({
    required this.instance,
    required this.page,
    required this.onPageChanged,
  });

  final Instance instance;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  ConsumerState<_WantedCutoffSubTab> createState() => _WantedCutoffSubTabState();
}

class _WantedCutoffSubTabState extends ConsumerState<_WantedCutoffSubTab> {
  bool _isSearchingAll = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SonarrWantedPage> cutoff =
        ref.watch(sonarrWantedCutoffProvider((widget.instance, widget.page)));
    final SonarrApi? api = ref.watch(sonarrApiProvider(widget.instance)).value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrWantedCutoffProvider((widget.instance, widget.page)));
        await ref.read(sonarrWantedCutoffProvider((widget.instance, widget.page)).future);
      },
      child: AsyncValueView<SonarrWantedPage>(
        value: cutoff,
        onRetry: () => ref.invalidate(sonarrWantedCutoffProvider((widget.instance, widget.page))),
        data: (SonarrWantedPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.check_circle_outline,
              title: 'No cutoff unmet episodes',
              message: 'All episodes meet the cutoff!',
            );
          }

          final int totalPages = (dataPage.totalRecords / dataPage.pageSize).ceil().clamp(1, double.infinity).toInt();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${dataPage.totalRecords} cutoff unmet episodes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    _isSearchingAll
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () async {
                              setState(() {
                                _isSearchingAll = true;
                              });
                              try {
                                final SonarrApi apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                                await apiObj.triggerCutoffUnmetSearch();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cutoff unmet search triggered')),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isSearchingAll = false;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('Search All'),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: Insets.pageH,
                  itemCount: dataPage.records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SonarrWantedRecord record = dataPage.records[index];
                    final SonarrImage? poster = record.series?.images.firstWhereOrNull((SonarrImage img) => img.coverType == 'poster');
                    final String? imageUrl = poster != null ? api?.posterUrl(poster) : null;

                    return _WantedEpisodeCard(
                      key: ValueKey<int>(record.id),
                      record: record,
                      imageUrl: imageUrl,
                      onSearch: () async {
                        final SonarrApi apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                        await apiObj.searchEpisode(record.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Search triggered for S${record.seasonNumber}E${record.episodeNumber}')),
                          );
                        }
                      },
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SeriesDetailScreen(
                            instance: widget.instance,
                            seriesId: record.seriesId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  currentPage: widget.page,
                  totalPages: totalPages,
                  onPageChanged: widget.onPageChanged,
                ),
            ],
          );
        },
      ),
    );
  }
}

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
    final AsyncValue<SonarrHistoryPage> history =
        ref.watch(sonarrHistoryProvider((widget.instance, _page)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrHistoryProvider((widget.instance, _page)));
        await ref.read(sonarrHistoryProvider((widget.instance, _page)).future);
      },
      child: AsyncValueView<SonarrHistoryPage>(
        value: history,
        onRetry: () => ref.invalidate(sonarrHistoryProvider((widget.instance, _page))),
        data: (SonarrHistoryPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.history,
              title: 'History is empty',
              message: 'No actions have been logged yet.',
            );
          }

          final int totalPages = (dataPage.totalRecords / dataPage.pageSize).ceil().clamp(1, double.infinity).toInt();

          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  padding: Insets.page,
                  itemCount: dataPage.records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SonarrHistoryRecord record = dataPage.records[index];
                    final (icon, color) = _getEventVisuals(record.eventType);
                    final String formattedDate = DateFormat.yMMMd().add_jm().format(record.date.toLocal());

                    final String? indexer = record.data['indexer'] as String?;
                    final String? client = record.data['downloadClient'] as String?;
                    final Map<String, dynamic>? qualityMap = record.quality?['quality'] as Map<String, dynamic>?;
                    final String? qualityName = qualityMap?['name'] as String?;

                    final List<String> details = [
                      if (indexer != null) 'Indexer: $indexer',
                      if (client != null) 'Client: $client',
                      if (qualityName != null) 'Quality: $qualityName',
                    ];

                    return Card(
                      margin: const EdgeInsets.only(bottom: Insets.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(
                          record.sourceTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: Insets.xxs),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: Insets.xxs),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(Radii.sm),
                                  ),
                                  child: Text(
                                    _formatEventType(record.eventType),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Insets.sm),
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: Insets.xs),
                              Text(
                                details.join(' • '),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SeriesDetailScreen(
                              instance: widget.instance,
                              seriesId: record.seriesId,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  currentPage: _page,
                  totalPages: totalPages,
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }

  (IconData, Color) _getEventVisuals(String eventType) {
    return switch (eventType) {
      'grabbed' => (Icons.downloading, Colors.blue),
      'downloadFolderImported' => (Icons.download_done, Colors.green),
      'episodeFileDeleted' => (Icons.delete_outline, Colors.red),
      'failed' => (Icons.error_outline, Colors.orange),
      _ => (Icons.info_outline, Colors.grey),
    };
  }

  String _formatEventType(String eventType) {
    final matches = RegExp(r'[A-Z]?[a-z]+|[A-Z]+(?=[A-Z]|$)');
    final words = matches.allMatches(eventType).map((m) => m.group(0)!).toList();
    if (words.isEmpty) return eventType;
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

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
    final AsyncValue<SonarrBlocklistPage> blocklist =
        ref.watch(sonarrBlocklistProvider((widget.instance, _page)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrBlocklistProvider((widget.instance, _page)));
        await ref.read(sonarrBlocklistProvider((widget.instance, _page)).future);
      },
      child: AsyncValueView<SonarrBlocklistPage>(
        value: blocklist,
        onRetry: () => ref.invalidate(sonarrBlocklistProvider((widget.instance, _page))),
        data: (SonarrBlocklistPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.block,
              title: 'Blocklist is empty',
              message: 'No releases have been blocklisted.',
            );
          }

          final int totalPages = (dataPage.totalRecords / dataPage.pageSize).ceil().clamp(1, double.infinity).toInt();

          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  padding: Insets.page,
                  itemCount: dataPage.records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SonarrBlocklistRecord record = dataPage.records[index];
                    final String formattedDate = record.date != null
                        ? DateFormat.yMMMd().add_jm().format(record.date!.toLocal())
                        : 'Unknown Date';

                    return Card(
                      margin: const EdgeInsets.only(bottom: Insets.sm),
                      child: ListTile(
                        title: Text(
                          record.sourceTitle ?? 'Unknown Release',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: Insets.xs),
                            Text(
                              'Indexer: ${record.indexer ?? 'Unknown'} • Protocol: ${record.protocol ?? 'Unknown'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Blocked: $formattedDate',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (record.message != null && record.message!.isNotEmpty) ...[
                              const SizedBox(height: Insets.xs),
                              Text(
                                'Reason: ${record.message}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                            await apiObj.deleteBlocklist(record.id);
                            ref.invalidate(sonarrBlocklistProvider((widget.instance, _page)));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Release removed from blocklist')),
                              );
                            }
                          },
                        ),
                        onTap: record.seriesId > 0
                            ? () => Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SeriesDetailScreen(
                                      instance: widget.instance,
                                      seriesId: record.seriesId,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  currentPage: _page,
                  totalPages: totalPages,
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SystemTab extends ConsumerWidget {
  const _SystemTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SonarrHealth>> health = ref.watch(sonarrHealthProvider(instance));
    final AsyncValue<SonarrSystemStatus> status = ref.watch(sonarrSystemStatusProvider(instance));
    final AsyncValue<List<SonarrDiskSpace>> diskSpace = ref.watch(sonarrDiskSpaceProvider(instance));
    final AsyncValue<List<SonarrSystemTask>> tasks = ref.watch(sonarrSystemTasksProvider(instance));
    final AsyncValue<List<SonarrBackup>> backups = ref.watch(sonarrBackupsProvider(instance));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrHealthProvider(instance));
        ref.invalidate(sonarrSystemStatusProvider(instance));
        ref.invalidate(sonarrDiskSpaceProvider(instance));
        ref.invalidate(sonarrSystemTasksProvider(instance));
        ref.invalidate(sonarrBackupsProvider(instance));
        await Future.wait(<Future<dynamic>>[
          ref.read(sonarrHealthProvider(instance).future),
          ref.read(sonarrSystemStatusProvider(instance).future),
          ref.read(sonarrDiskSpaceProvider(instance).future),
          ref.read(sonarrSystemTasksProvider(instance).future),
          ref.read(sonarrBackupsProvider(instance).future),
        ]);
      },
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          _HealthWarningsSection(health: health),
          _SystemStatusSection(status: status),
          const SizedBox(height: Insets.lg),
          _DiskSpaceSection(diskSpace: diskSpace),
          const SizedBox(height: Insets.lg),
          _TasksSection(tasks: tasks, instance: instance),
          const SizedBox(height: Insets.lg),
          _BackupsSection(backups: backups, instance: instance),
        ],
      ),
    );
  }
}

class _SystemStatusSection extends StatelessWidget {
  const _SystemStatusSection({required this.status});

  final AsyncValue<SonarrSystemStatus> status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('System Status', style: theme.textTheme.titleMedium),
            const Divider(height: Insets.lg),
            AsyncValueView<SonarrSystemStatus>(
              value: status,
              data: (stat) {
                return Column(
                  children: [
                    _infoRow(context, 'Version', stat.version),
                    _infoRow(context, 'OS', '${stat.osName} (${stat.osVersion})'),
                    _infoRow(context, 'Environment', stat.isDocker ? 'Docker' : 'Bare Metal'),
                    if (stat.databaseType != null)
                      _infoRow(context, 'Database', '${stat.databaseType} (v${stat.databaseVersion ?? '?'})'),
                    if (stat.runtimeName != null)
                      _infoRow(context, 'Runtime', '${stat.runtimeName} (${stat.runtimeVersion ?? '?'})'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiskSpaceSection extends StatelessWidget {
  const _DiskSpaceSection({required this.diskSpace});

  final AsyncValue<List<SonarrDiskSpace>> diskSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Disk Space', style: theme.textTheme.titleMedium),
            const Divider(height: Insets.lg),
            AsyncValueView<List<SonarrDiskSpace>>(
              value: diskSpace,
              data: (disks) {
                if (disks.isEmpty) {
                  return const Text('No disk information available');
                }
                return Column(
                  children: disks.map((disk) {
                    final double progress = disk.totalSpace <= 0
                        ? 0
                        : ((disk.totalSpace - disk.freeSpace) / disk.totalSpace).clamp(0, 1);
                    final String freeStr = _formatBytes(disk.freeSpace);
                    final String totalStr = _formatBytes(disk.totalSpace);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                disk.path,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Free: $freeStr / Total: $totalStr',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.xs),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress > 0.9 ? Colors.red : theme.colorScheme.primary,
                            ),
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
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (math.log(bytes) / math.log(1024)).floor();
  return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
}

class _TasksSection extends StatelessWidget {
  const _TasksSection({required this.tasks, required this.instance});

  final AsyncValue<List<SonarrSystemTask>> tasks;
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Scheduled Tasks', style: theme.textTheme.titleMedium),
            const Divider(height: Insets.lg),
            AsyncValueView<List<SonarrSystemTask>>(
              value: tasks,
              data: (taskList) {
                if (taskList.isEmpty) {
                  return const Text('No system tasks available');
                }
                return Column(
                  children: taskList.map((task) {
                    final String intervalStr = '${task.interval} min';
                    final String lastRun = task.lastExecution != null
                        ? DateFormat.yMMMd().add_jm().format(task.lastExecution!.toLocal())
                        : 'Never';

                    return Consumer(
                      builder: (context, ref, _) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(task.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Interval: $intervalStr\nLast Run: $lastRun',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Run task now',
                            onPressed: () async {
                              final apiObj = await ref.read(sonarrApiProvider(instance).future);
                              await apiObj.runSystemTask(task.taskName);
                              ref.invalidate(sonarrSystemTasksProvider(instance));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Task "${task.name}" triggered')),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm, horizontal: Insets.lg),
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            ),
            Text(
              'Page $currentPage of $totalPages',
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthWarningsSection extends StatelessWidget {
  const _HealthWarningsSection({required this.health});

  final AsyncValue<List<SonarrHealth>> health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AsyncValueView<List<SonarrHealth>>(
      value: health,
      data: (healthItems) {
        if (healthItems.isEmpty) return const SizedBox.shrink();
        return Card(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          margin: const EdgeInsets.only(bottom: Insets.lg),
          child: Padding(
            padding: Insets.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: Insets.sm),
                    Text(
                      'System Health Warnings',
                      style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const Divider(),
                ...healthItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                    child: Text(
                      '• ${item.message}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackupsSection extends StatelessWidget {
  const _BackupsSection({required this.backups, required this.instance});

  final AsyncValue<List<SonarrBackup>> backups;
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('System Backups', style: theme.textTheme.titleMedium),
                Consumer(
                  builder: (context, ref, _) {
                    return TextButton.icon(
                      icon: const Icon(Icons.backup),
                      label: const Text('Backup Now'),
                      onPressed: () async {
                        final apiObj = await ref.read(sonarrApiProvider(instance).future);
                        await apiObj.runSystemTask('Backup');
                        ref.invalidate(sonarrBackupsProvider(instance));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup task triggered')),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
            const Divider(height: Insets.lg),
            AsyncValueView<List<SonarrBackup>>(
              value: backups,
              data: (backupList) {
                if (backupList.isEmpty) {
                  return const Text('No backups found');
                }
                return Column(
                  children: backupList.map((backup) {
                    final String sizeStr = '${(backup.size / 1024 / 1024).toStringAsFixed(1)} MB';
                    final String timeStr = DateFormat.yMMMd().add_jm().format(backup.time.toLocal());

                    return Consumer(
                      builder: (context, ref, _) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(backup.name, style: theme.textTheme.bodyMedium),
                          subtitle: Text('Size: $sizeStr • Date: $timeStr'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            onPressed: () async {
                              final apiObj = await ref.read(sonarrApiProvider(instance).future);
                              await apiObj.deleteBackup(backup.id);
                              ref.invalidate(sonarrBackupsProvider(instance));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Backup deleted')),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrIndexersProvider(instance));
        ref.invalidate(sonarrDownloadClientsProvider(instance));
        ref.invalidate(sonarrNotificationsProvider(instance));
        ref.invalidate(sonarrImportListsProvider(instance));
        ref.invalidate(sonarrTagsProvider(instance));
        ref.invalidate(sonarrHostConfigProvider(instance));
        ref.invalidate(sonarrNamingConfigProvider(instance));
        ref.invalidate(sonarrMediaManagementConfigProvider(instance));
        ref.invalidate(sonarrUiConfigProvider(instance));
        ref.invalidate(sonarrMetadataProvidersProvider(instance));
        ref.invalidate(sonarrDelayProfilesProvider(instance));
        ref.invalidate(sonarrCustomFormatsProvider(instance));
        ref.invalidate(sonarrQualityDefinitionsProvider(instance));
        ref.invalidate(sonarrReleaseProfilesProvider(instance));
        ref.invalidate(sonarrImportListExclusionsProvider(instance));
        ref.invalidate(sonarrAutoTaggingRulesProvider(instance));
        ref.invalidate(sonarrQualityProfilesRawProvider(instance));
        ref.invalidate(sonarrQualityProfilesProvider(instance));
        await Future.wait(<Future<dynamic>>[
          ref.read(sonarrIndexersProvider(instance).future),
          ref.read(sonarrDownloadClientsProvider(instance).future),
          ref.read(sonarrNotificationsProvider(instance).future),
          ref.read(sonarrImportListsProvider(instance).future),
          ref.read(sonarrTagsProvider(instance).future),
          ref.read(sonarrHostConfigProvider(instance).future),
          ref.read(sonarrNamingConfigProvider(instance).future),
          ref.read(sonarrMediaManagementConfigProvider(instance).future),
          ref.read(sonarrUiConfigProvider(instance).future),
          ref.read(sonarrMetadataProvidersProvider(instance).future),
          ref.read(sonarrDelayProfilesProvider(instance).future),
          ref.read(sonarrCustomFormatsProvider(instance).future),
          ref.read(sonarrQualityDefinitionsProvider(instance).future),
          ref.read(sonarrReleaseProfilesProvider(instance).future),
          ref.read(sonarrImportListExclusionsProvider(instance).future),
          ref.read(sonarrAutoTaggingRulesProvider(instance).future),
          ref.read(sonarrQualityProfilesRawProvider(instance).future),
          ref.read(sonarrQualityProfilesProvider(instance).future),
        ]);
      },
      child: ListView(
        padding: Insets.page,
        children: [
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrIndexer>> indexers = ref.watch(sonarrIndexersProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Indexers', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Indexer',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'indexer',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrIndexer>>(
            value: indexers,
            data: (list) {
              if (list.isEmpty) return const Text('No indexers configured.');
              return Column(
                children: list.map((indexer) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: indexer.enableRss,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(indexer.raw)..['enableRss'] = val;
                        await api.updateIndexerRaw(newRaw);
                        ref.invalidate(sonarrIndexersProvider(instance));
                      },
                    ),
                    title: Text(indexer.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Protocol: ${indexer.protocol}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Indexer',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testIndexerRaw(indexer.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Indexer test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Indexer test failed')),
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
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'indexer',
                                  itemRaw: indexer.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Indexer',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteIndexer(indexer.id);
                            ref.invalidate(sonarrIndexersProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Indexer deleted')),
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrDownloadClient>> clients = ref.watch(sonarrDownloadClientsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Download Clients', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Download Client',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'downloadclient',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrDownloadClient>>(
            value: clients,
            data: (list) {
              if (list.isEmpty) return const Text('No download clients configured.');
              return Column(
                children: list.map((client) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: client.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(client.raw)..['enable'] = val;
                        await api.updateDownloadClientRaw(newRaw);
                        ref.invalidate(sonarrDownloadClientsProvider(instance));
                      },
                    ),
                    title: Text(client.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Protocol: ${client.protocol}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Download Client',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testDownloadClientRaw(client.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Download client test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Download client test failed')),
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
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'downloadclient',
                                  itemRaw: client.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Download Client',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteDownloadClient(client.id);
                            ref.invalidate(sonarrDownloadClientsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Download client deleted')),
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrNotification>> notifications = ref.watch(sonarrNotificationsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Notifications', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Notification',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'notification',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrNotification>>(
            value: notifications,
            data: (list) {
              if (list.isEmpty) return const Text('No notifications configured.');
              return Column(
                children: list.map((notification) {
                  final List<String> activeTriggers = [
                    if (notification.onGrab) 'Grab',
                    if (notification.onDownload) 'Download',
                    if (notification.onUpgrade) 'Upgrade',
                  ];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(notification.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Triggers: ${activeTriggers.isEmpty ? "None" : activeTriggers.join(", ")}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Notification',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testNotificationRaw(notification.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notification test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notification test failed')),
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
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'notification',
                                  itemRaw: notification.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Notification',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteNotification(notification.id);
                            ref.invalidate(sonarrNotificationsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notification deleted')),
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrImportList>> lists = ref.watch(sonarrImportListsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Import Lists', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Import List',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'importlist',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrImportList>>(
            value: lists,
            data: (list) {
              if (list.isEmpty) return const Text('No import lists configured.');
              return Column(
                children: list.map((importList) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: importList.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(importList.raw)..['enable'] = val;
                        await api.updateImportListRaw(newRaw);
                        ref.invalidate(sonarrImportListsProvider(instance));
                      },
                    ),
                    title: Text(importList.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Import List',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testImportListRaw(importList.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Import list test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Import list test failed')),
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
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'importlist',
                                  itemRaw: importList.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Import List',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteImportList(importList.id);
                            ref.invalidate(sonarrImportListsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Import list deleted')),
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrTag>> tags = ref.watch(sonarrTagsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tags', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Tag',
              onPressed: () => _showAddTagDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrTag>>(
            value: tags,
            data: (tagList) {
              if (tagList.isEmpty) return const Text('No tags created yet.');
              return Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: tagList.map((tag) {
                  return Chip(
                    label: Text(tag.label),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      final api = await ref.read(sonarrApiProvider(instance).future);
                      await api.deleteTag(tag.id);
                      ref.invalidate(sonarrTagsProvider(instance));
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
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Tag Label'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final label = controller.text.trim();
                if (label.isNotEmpty) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createTag(label);
                  ref.invalidate(sonarrTagsProvider(instance));
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
    final theme = Theme.of(context);
    final AsyncValue<SonarrHostConfig> config = ref.watch(sonarrHostConfigProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('General / Host Settings', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrHostConfig>(
            value: config,
            data: (c) => _HostSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _HostSettingsForm extends ConsumerStatefulWidget {
  const _HostSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrHostConfig config;

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
    _portController = TextEditingController(text: widget.config.port.toString());
    _branchController = TextEditingController(text: widget.config.branch);
    _backupIntervalController = TextEditingController(text: widget.config.backupInterval.toString());
    _backupRetentionController = TextEditingController(text: widget.config.backupRetention.toString());
    _logLevel = widget.config.logLevel;
    _enableSsl = widget.config.enableSsl;
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

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['port'] = int.tryParse(_portController.text) ?? widget.config.port
      ..['branch'] = _branchController.text.trim()
      ..['backupInterval'] = int.tryParse(_backupIntervalController.text) ?? widget.config.backupInterval
      ..['backupRetention'] = int.tryParse(_backupRetentionController.text) ?? widget.config.backupRetention
      ..['logLevel'] = _logLevel
      ..['enableSsl'] = _enableSsl;

    try {
      await api.updateHostConfigRaw(newRaw);
      ref.invalidate(sonarrHostConfigProvider(widget.instance));
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
        children: [
          TextFormField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Server Port',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
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
            onChanged: (val) => setState(() => _enableSsl = val),
          ),
          const SizedBox(height: Insets.sm),
          DropdownButtonFormField<String>(
            initialValue: _logLevel,
            decoration: const InputDecoration(
              labelText: 'Log Level',
              border: OutlineInputBorder(),
            ),
            items: ['trace', 'debug', 'info', 'warn', 'error'].map((level) {
              return DropdownMenuItem<String>(
                value: level,
                child: Text(level.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
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
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _backupIntervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Backup Interval (days)',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
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
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final theme = Theme.of(context);
    final AsyncValue<SonarrNamingConfig> config = ref.watch(sonarrNamingConfigProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Episode Naming', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrNamingConfig>(
            value: config,
            data: (c) => _NamingSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _NamingSettingsForm extends ConsumerStatefulWidget {
  const _NamingSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrNamingConfig config;

  @override
  ConsumerState<_NamingSettingsForm> createState() => _NamingSettingsFormState();
}

class _NamingSettingsFormState extends ConsumerState<_NamingSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _standardFormatController;
  late final TextEditingController _dailyFormatController;
  late final TextEditingController _animeFormatController;
  late final TextEditingController _seriesFolderFormatController;
  late bool _renameEpisodes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _standardFormatController = TextEditingController(text: widget.config.standardEpisodeFormat);
    _dailyFormatController = TextEditingController(text: widget.config.dailyEpisodeFormat);
    _animeFormatController = TextEditingController(text: widget.config.animeEpisodeFormat);
    _seriesFolderFormatController = TextEditingController(text: widget.config.seriesFolderFormat);
    _renameEpisodes = widget.config.renameEpisodes;
  }

  @override
  void dispose() {
    _standardFormatController.dispose();
    _dailyFormatController.dispose();
    _animeFormatController.dispose();
    _seriesFolderFormatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['renameEpisodes'] = _renameEpisodes
      ..['standardEpisodeFormat'] = _standardFormatController.text.trim()
      ..['dailyEpisodeFormat'] = _dailyFormatController.text.trim()
      ..['animeEpisodeFormat'] = _animeFormatController.text.trim()
      ..['seriesFolderFormat'] = _seriesFolderFormatController.text.trim();

    try {
      await api.updateNamingConfigRaw(newRaw);
      ref.invalidate(sonarrNamingConfigProvider(widget.instance));
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
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rename Episodes'),
            value: _renameEpisodes,
            onChanged: (val) => setState(() => _renameEpisodes = val),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _standardFormatController,
            decoration: const InputDecoration(
              labelText: 'Standard Episode Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (_renameEpisodes && (val == null || val.trim().isEmpty)) ? 'Required when Rename is enabled' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _dailyFormatController,
            decoration: const InputDecoration(
              labelText: 'Daily Episode Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (_renameEpisodes && (val == null || val.trim().isEmpty)) ? 'Required when Rename is enabled' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _animeFormatController,
            decoration: const InputDecoration(
              labelText: 'Anime Episode Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (_renameEpisodes && (val == null || val.trim().isEmpty)) ? 'Required when Rename is enabled' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _seriesFolderFormatController,
            decoration: const InputDecoration(
              labelText: 'Series Folder Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final theme = Theme.of(context);
    final AsyncValue<SonarrMediaManagementConfig> config = ref.watch(sonarrMediaManagementConfigProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Media Management', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrMediaManagementConfig>(
            value: config,
            data: (c) => _MediaManagementSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _MediaManagementSettingsForm extends ConsumerStatefulWidget {
  const _MediaManagementSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrMediaManagementConfig config;

  @override
  ConsumerState<_MediaManagementSettingsForm> createState() => _MediaManagementSettingsFormState();
}

class _MediaManagementSettingsFormState extends ConsumerState<_MediaManagementSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late bool _autoUnmonitor;
  late String _downloadPropers;
  late bool _createEmptySeriesFolders;
  late bool _deleteEmptyFolders;
  late bool _copyUsingHardlinks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoUnmonitor = widget.config.autoUnmonitorPreviouslyDownloadedEpisodes;
    _downloadPropers = widget.config.downloadPropersAndRepacks;
    _createEmptySeriesFolders = widget.config.createEmptySeriesFolders;
    _deleteEmptyFolders = widget.config.deleteEmptyFolders;
    _copyUsingHardlinks = widget.config.copyUsingHardlinks;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['autoUnmonitorPreviouslyDownloadedEpisodes'] = _autoUnmonitor
      ..['downloadPropersAndRepacks'] = _downloadPropers
      ..['createEmptySeriesFolders'] = _createEmptySeriesFolders
      ..['deleteEmptyFolders'] = _deleteEmptyFolders
      ..['copyUsingHardlinks'] = _copyUsingHardlinks;

    try {
      await api.updateMediaManagementConfigRaw(newRaw);
      ref.invalidate(sonarrMediaManagementConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media management settings saved successfully!')),
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
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Unmonitor Downloaded'),
            value: _autoUnmonitor,
            onChanged: (val) => setState(() => _autoUnmonitor = val),
          ),
          DropdownButtonFormField<String>(
            initialValue: _downloadPropers,
            decoration: const InputDecoration(
              labelText: 'Download Propers & Repacks',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'preferAndUpgrade',
                child: Text('Prefer and Upgrade'),
              ),
              DropdownMenuItem(
                value: 'doNotUpgrade',
                child: Text('Do Not Upgrade'),
              ),
              DropdownMenuItem(
                value: 'doNotPrefer',
                child: Text('Do Not Prefer'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _downloadPropers = val);
              }
            },
          ),
          const SizedBox(height: Insets.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create Empty Series Folders'),
            value: _createEmptySeriesFolders,
            onChanged: (val) => setState(() => _createEmptySeriesFolders = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Delete Empty Folders'),
            value: _deleteEmptyFolders,
            onChanged: (val) => setState(() => _deleteEmptyFolders = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use Hardlinks instead of Copy'),
            value: _copyUsingHardlinks,
            onChanged: (val) => setState(() => _copyUsingHardlinks = val),
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final theme = Theme.of(context);
    final AsyncValue<SonarrUiConfig> config = ref.watch(sonarrUiConfigProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('UI Configuration', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrUiConfig>(
            value: config,
            data: (c) => _UiSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _UiSettingsForm extends ConsumerStatefulWidget {
  const _UiSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrUiConfig config;

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
    _theme = widget.config.theme;

    // Normalize timeFormat dropdown value
    final currentFormat = widget.config.timeFormat;
    if (currentFormat.contains('a') || currentFormat.contains('t')) {
      _timeFormat = 'h:mm a';
    } else {
      _timeFormat = 'HH:mm';
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['theme'] = _theme
      ..['timeFormat'] = _timeFormat;

    try {
      await api.updateUiConfigRaw(newRaw);
      ref.invalidate(sonarrUiConfigProvider(widget.instance));
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
        children: [
          DropdownButtonFormField<String>(
            initialValue: _theme,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: ['auto', 'dark', 'light'].map((themeName) {
              return DropdownMenuItem<String>(
                value: themeName,
                child: Text(themeName.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
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
            items: const [
              DropdownMenuItem(value: 'h:mm a', child: Text('12h')),
              DropdownMenuItem(value: 'HH:mm', child: Text('24h')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _timeFormat = val);
              }
            },
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrMetadataProvider>> providers = ref.watch(sonarrMetadataProvidersProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Metadata Consumers', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrMetadataProvider>>(
            value: providers,
            data: (list) {
              if (list.isEmpty) return const Text('No metadata consumers.');
              return Column(
                children: list.map((provider) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: provider.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(provider.raw)..['enable'] = val;
                        await api.updateMetadataProviderRaw(newRaw);
                        ref.invalidate(sonarrMetadataProvidersProvider(instance));
                      },
                    ),
                    title: Text(provider.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Metadata Consumer',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testMetadataProviderRaw(provider.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Metadata consumer test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Metadata consumer test failed')),
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrDelayProfile>> profiles = ref.watch(sonarrDelayProfilesProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Delay Profiles', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrDelayProfile>>(
            value: profiles,
            data: (list) {
              if (list.isEmpty) return const Text('No delay profiles configured.');
              return Column(
                children: list.map((profile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Torrent Delay'),
                        value: profile.enableTorrent,
                        onChanged: (val) async {
                          final api = await ref.read(sonarrApiProvider(instance).future);
                          final newRaw = Map<String, dynamic>.of(profile.raw)..['enableTorrent'] = val;
                          await api.updateDelayProfileRaw(newRaw);
                          ref.invalidate(sonarrDelayProfilesProvider(instance));
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Usenet Delay'),
                        value: profile.enableUsenet,
                        onChanged: (val) async {
                          final api = await ref.read(sonarrApiProvider(instance).future);
                          final newRaw = Map<String, dynamic>.of(profile.raw)..['enableUsenet'] = val;
                          await api.updateDelayProfileRaw(newRaw);
                          ref.invalidate(sonarrDelayProfilesProvider(instance));
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Preferred Protocol'),
                        trailing: DropdownButton<String>(
                          value: profile.preferredProtocol,
                          items: ['usenet', 'torrent'].map((protocol) {
                            return DropdownMenuItem<String>(
                              value: protocol,
                              child: Text(protocol.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              final api = await ref.read(sonarrApiProvider(instance).future);
                              final newRaw = Map<String, dynamic>.of(profile.raw)..['preferredProtocol'] = val;
                              await api.updateDelayProfileRaw(newRaw);
                              ref.invalidate(sonarrDelayProfilesProvider(instance));
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrCustomFormat>> formats = ref.watch(sonarrCustomFormatsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Custom Formats', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrCustomFormat>>(
            value: formats,
            data: (list) {
              if (list.isEmpty) return const Text('No custom formats configured.');
              return Column(
                children: list.map((format) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(format.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      tooltip: 'Delete Custom Format',
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteCustomFormat(format.id);
                        ref.invalidate(sonarrCustomFormatsProvider(instance));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom format deleted')),
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrQualityDefinition>> definitions = ref.watch(sonarrQualityDefinitionsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Text('Quality Definitions', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrQualityDefinition>>(
            value: definitions,
            data: (list) {
              if (list.isEmpty) return const Text('No quality definitions.');
              return Column(
                children: list.map((def) {
                  return _QualityDefinitionRow(instance: instance, definition: def);
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
  const _QualityDefinitionRow({required this.instance, required this.definition});

  final Instance instance;
  final SonarrQualityDefinition definition;

  @override
  ConsumerState<_QualityDefinitionRow> createState() => _QualityDefinitionRowState();
}

class _QualityDefinitionRowState extends ConsumerState<_QualityDefinitionRow> {
  late bool _isUnlimited;
  bool _saving = false;

  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _preferredController;

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
    final double minVal = widget.definition.minSize;
    final rawMax = widget.definition.raw['maxSize'];
    _isUnlimited = rawMax == null || rawMax == 0.0 || widget.definition.maxSize == 0.0;
    final double maxVal = _isUnlimited ? 0.0 : widget.definition.maxSize;
    final double prefVal = widget.definition.preferredSize;

    _minController.text = minVal.toStringAsFixed(1);
    _maxController.text = _isUnlimited ? '' : maxVal.toStringAsFixed(1);
    _preferredController.text = prefVal.toStringAsFixed(1);
  }

  @override
  void didUpdateWidget(covariant _QualityDefinitionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition) {
      _reset();
    }
  }

  String? get _minError {
    final val = double.tryParse(_minController.text);
    if (_minController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    if (val < 0) return 'Must be >= 0';
    return null;
  }

  String? get _preferredError {
    final val = double.tryParse(_preferredController.text);
    if (_preferredController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    final minVal = double.tryParse(_minController.text);
    if (minVal != null && val < minVal) return 'Must be >= Min';
    return null;
  }

  String? get _maxError {
    if (_isUnlimited) return null;
    final val = double.tryParse(_maxController.text);
    if (_maxController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    final prefVal = double.tryParse(_preferredController.text);
    if (prefVal != null && val < prefVal) return 'Must be >= Preferred';
    return null;
  }

  bool get _isValid => _minError == null && _preferredError == null && _maxError == null;

  bool get _hasChanges {
    final double origMin = widget.definition.minSize;
    final double origPref = widget.definition.preferredSize;
    final bool origUnlimited = widget.definition.raw['maxSize'] == null || widget.definition.raw['maxSize'] == 0.0 || widget.definition.maxSize == 0.0;
    final double origMax = origUnlimited ? 0.0 : widget.definition.maxSize;

    final minVal = double.tryParse(_minController.text);
    final prefVal = double.tryParse(_preferredController.text);
    final maxVal = _isUnlimited ? 0.0 : double.tryParse(_maxController.text);

    if (minVal == null || prefVal == null || (!_isUnlimited && maxVal == null)) {
      return true;
    }

    return minVal != origMin || prefVal != origPref || _isUnlimited != origUnlimited || (!_isUnlimited && maxVal != origMax);
  }

  Future<void> _save() async {
    if (!_isValid) return;

    setState(() => _saving = true);
    final api = await ref.read(sonarrApiProvider(widget.instance).future);

    final double minVal = double.parse(_minController.text);
    final double prefVal = double.parse(_preferredController.text);
    final double maxVal = _isUnlimited ? 0.0 : double.parse(_maxController.text);

    final newRaw = Map<String, dynamic>.of(widget.definition.raw)
      ..['minSize'] = minVal
      ..['maxSize'] = maxVal
      ..['preferredSize'] = prefVal;

    try {
      await api.updateQualityDefinitionRaw(newRaw);
      ref.invalidate(sonarrQualityDefinitionsProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quality definition ${widget.definition.name} saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quality definition: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Material(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _hasChanges ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant,
            width: _hasChanges ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.definition.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _hasChanges ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_hasChanges)
                        IconButton(
                          icon: Icon(
                            Icons.check,
                            color: _isValid ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            size: 20,
                          ),
                          tooltip: _isValid ? 'Save changes' : 'Validation errors exist',
                          onPressed: _isValid ? _save : null,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Min Size',
                        suffixText: 'MB/h',
                        errorText: _minError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _preferredController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Preferred',
                        suffixText: 'MB/h',
                        errorText: _preferredError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      enabled: !_isUnlimited,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Max Size',
                        suffixText: _isUnlimited ? '' : 'MB/h',
                        hintText: _isUnlimited ? 'Unlimited' : null,
                        errorText: _maxError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Unlimited Max Size', style: theme.textTheme.bodyMedium),
                value: _isUnlimited,
                onChanged: (val) {
                  setState(() {
                    _isUnlimited = val ?? false;
                    if (_isUnlimited) {
                      _maxController.text = '';
                    } else {
                      final prefVal = double.tryParse(_preferredController.text) ?? widget.definition.preferredSize;
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrReleaseProfile>> profiles = ref.watch(sonarrReleaseProfilesProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Release Profiles', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Release Profile',
              onPressed: () => _showAddProfileDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrReleaseProfile>>(
            value: profiles,
            data: (list) {
              if (list.isEmpty) return const Text('No release profiles configured.');
              return Column(
                children: list.map((profile) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: profile.enabled,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(profile.raw)..['enabled'] = val;
                        await api.updateReleaseProfileRaw(newRaw);
                        ref.invalidate(sonarrReleaseProfilesProvider(instance));
                      },
                    ),
                    title: Text(profile.name.isEmpty ? 'Unnamed Release Profile' : profile.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Required: ${profile.requiredTerms.length} • Ignored: ${profile.ignoredTerms.length} • Preferred: ${profile.preferredTerms.length}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteReleaseProfile(profile.id);
                        ref.invalidate(sonarrReleaseProfilesProvider(instance));
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
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Release Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Profile Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createReleaseProfileRaw(<String, dynamic>{
                    'name': name,
                    'enabled': true,
                    'required': <dynamic>[],
                    'ignored': <dynamic>[],
                    'preferred': <dynamic>[],
                    'tags': <dynamic>[],
                  });
                  ref.invalidate(sonarrReleaseProfilesProvider(instance));
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrImportListExclusion>> exclusions = ref.watch(sonarrImportListExclusionsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Import List Exclusions', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Exclusion',
              onPressed: () => _showAddExclusionDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrImportListExclusion>>(
            value: exclusions,
            data: (list) {
              if (list.isEmpty) return const Text('No exclusions configured.');
              return Column(
                children: list.map((exclusion) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(exclusion.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('TVDB ID: ${exclusion.tvdbId}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteImportListExclusion(exclusion.id);
                        ref.invalidate(sonarrImportListExclusionsProvider(instance));
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
    final titleController = TextEditingController();
    final tvdbController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Import List Exclusion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Series Title'),
                autofocus: true,
              ),
              TextField(
                controller: tvdbController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'TVDB ID'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final tvdbId = int.tryParse(tvdbController.text.trim()) ?? 0;
                if (title.isNotEmpty && tvdbId > 0) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createImportListExclusionRaw(<String, dynamic>{
                    'title': title,
                    'tvdbId': tvdbId,
                  });
                  ref.invalidate(sonarrImportListExclusionsProvider(instance));
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
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrAutoTaggingRule>> rules = ref.watch(sonarrAutoTaggingRulesProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Auto Tagging Rules', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Auto Tagging Rule',
              onPressed: () => _showAddRuleDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrAutoTaggingRule>>(
            value: rules,
            data: (list) {
              if (list.isEmpty) return const Text('No auto tagging rules.');
              return Column(
                children: list.map((rule) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(rule.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Specifications: ${rule.specifications.length} • Tags: ${rule.tags.length}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteAutoTaggingRule(rule.id);
                        ref.invalidate(sonarrAutoTaggingRulesProvider(instance));
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
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Auto Tagging Rule'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Rule Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createAutoTaggingRuleRaw(<String, dynamic>{
                    'name': name,
                    'tags': <dynamic>[],
                    'specifications': <dynamic>[],
                  });
                  ref.invalidate(sonarrAutoTaggingRulesProvider(instance));
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
    final quality = item['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return ((quality['id'] as num?) ?? 0).toInt();
    }
    return 0;
  }

  String _getItemName(Map<String, dynamic> item) {
    final String? name = item['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final quality = item['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return (quality['name'] as String?) ?? '';
    }
    return '';
  }

  List<Map<String, dynamic>> _getAllowedQualities(List<dynamic> items) {
    final List<Map<String, dynamic>> list = [];
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

  Widget _buildQualityItemTile(BuildContext context, Map<String, dynamic> item, StateSetter setState, {bool readOnly = false}) {
    final List<dynamic>? nestedItems = item['items'] as List<dynamic>?;
    final String name = _getItemName(item);
    final bool allowed = (item['allowed'] as bool?) ?? false;

    if (nestedItems != null && nestedItems.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: ExpansionTile(
          initiallyExpanded: readOnly,
          title: Row(
            children: [
              Checkbox(
                value: allowed,
                onChanged: readOnly ? null : (val) {
                  setState(() {
                    item['allowed'] = val ?? false;
                    for (final dynamic sub in nestedItems) {
                      (sub as Map<String, dynamic>)['allowed'] = val ?? false;
                    }
                  });
                },
              ),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          children: nestedItems.map((dynamic sub) => _buildQualityItemTile(context, sub as Map<String, dynamic>, setState, readOnly: readOnly)).toList(),
        ),
      );
    } else {
      return CheckboxListTile(
        title: Text(name),
        value: allowed,
        onChanged: readOnly ? null : (val) {
          setState(() {
            item['allowed'] = val ?? false;
          });
        },
      );
    }
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? profile, {bool readOnly = false}) async {
    final api = await ref.read(sonarrApiProvider(instance).future);
    
    Map<String, dynamic> payload;
    if (profile != null) {
      payload = jsonDecode(jsonEncode(profile)) as Map<String, dynamic>;
    } else {
      final schema = await ref.read(sonarrQualityProfileSchemaProvider(instance).future);
      payload = jsonDecode(jsonEncode(schema)) as Map<String, dynamic>;
      payload['name'] = '';
      payload['upgradeAllowed'] = true;
    }

    if (!context.mounted) return;

    final nameController = TextEditingController(text: payload['name'] as String? ?? '');
    
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final itemsList = (payload['items'] as List<dynamic>?) ?? [];
            final allowedQualities = _getAllowedQualities(itemsList);
            
            int cutoffId = (payload['cutoff'] as num? ?? 0).toInt();
            if (cutoffId == 0 && allowedQualities.isNotEmpty) {
              cutoffId = _getItemId(allowedQualities.first);
              payload['cutoff'] = cutoffId;
            } else if (allowedQualities.isNotEmpty && !allowedQualities.any((q) => _getItemId(q) == cutoffId)) {
              cutoffId = _getItemId(allowedQualities.first);
              payload['cutoff'] = cutoffId;
            }

            return AlertDialog(
              title: Text(profile != null ? (readOnly ? 'View Quality Profile' : 'Edit Quality Profile') : 'Add Quality Profile'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: ListView(
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !readOnly,
                      decoration: const InputDecoration(
                        labelText: 'Profile Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => payload['name'] = val.trim(),
                    ),
                    const SizedBox(height: Insets.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Upgrades Allowed'),
                      value: (payload['upgradeAllowed'] as bool?) ?? false,
                      onChanged: readOnly ? null : (val) => setState(() => payload['upgradeAllowed'] = val),
                    ),
                    if (payload['upgradeAllowed'] == true && allowedQualities.isNotEmpty) ...[
                      const SizedBox(height: Insets.sm),
                      DropdownButtonFormField<int>(
                        initialValue: cutoffId,
                        decoration: const InputDecoration(
                          labelText: 'Upgrade Cutoff',
                          border: OutlineInputBorder(),
                        ),
                        items: allowedQualities.map((q) {
                          final qId = _getItemId(q);
                          final qName = _getItemName(q);
                          return DropdownMenuItem<int>(
                            value: qId,
                            child: Text(qName),
                          );
                        }).toList(),
                        onChanged: readOnly ? null : (val) {
                          if (val != null) {
                            setState(() => payload['cutoff'] = val);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: Insets.md),
                    Text('Allowed Qualities', style: theme.textTheme.titleSmall),
                    const SizedBox(height: Insets.xs),
                    ...itemsList.map((dynamic item) => _buildQualityItemTile(context, item as Map<String, dynamic>, setState, readOnly: readOnly)),
                  ],
                ),
              ),
              actions: [
                if (readOnly)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        payload['name'] = name;
                        if (profile != null) {
                          await api.updateQualityProfileRaw(payload);
                        } else {
                          await api.createQualityProfileRaw(payload);
                        }
                        ref.invalidate(sonarrQualityProfilesRawProvider(instance));
                        ref.invalidate(sonarrQualityProfilesProvider(instance));
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
    final theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> profiles = ref.watch(sonarrQualityProfilesRawProvider(instance));
    final AsyncValue<List<SonarrQualityDefinition>> definitions = ref.watch(sonarrQualityDefinitionsProvider(instance));

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quality Profiles', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Quality Profile',
              onPressed: () => _showEditProfileDialog(context, ref, null),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<Map<String, dynamic>>>(
            value: profiles,
            data: (list) {
              if (list.isEmpty) return const Text('No quality profiles.');
              return Column(
                children: list.map((profile) {
                  final name = (profile['name'] as String?) ?? '';
                  final upgradeAllowed = (profile['upgradeAllowed'] as bool?) ?? false;
                  final cutoffId = (profile['cutoff'] as num? ?? 0).toInt();

                  final cutoffName = definitions.maybeWhen(
                    data: (defs) => defs.firstWhereOrNull((d) => d.id == cutoffId)?.name ?? 'Unknown',
                    orElse: () => '...',
                  );

                  final itemsList = (profile['items'] as List<dynamic>?) ?? [];
                  final allowedQualities = _getAllowedQualities(itemsList);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showEditProfileDialog(context, ref, profile, readOnly: true),
                    title: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Upgrades: ${upgradeAllowed ? "Yes (Cutoff: $cutoffName)" : "No"}\n'
                      'Allowed: ${allowedQualities.length} qualities',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Quality Profile',
                          onPressed: () => _showEditProfileDialog(context, ref, profile),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Quality Profile',
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Quality Profile?'),
                                content: Text('Are you sure you want to delete profile "$name"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final api = await ref.read(sonarrApiProvider(instance).future);
                              await api.deleteQualityProfile(profile['id'] as int);
                              ref.invalidate(sonarrQualityProfilesRawProvider(instance));
                              ref.invalidate(sonarrQualityProfilesProvider(instance));
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

