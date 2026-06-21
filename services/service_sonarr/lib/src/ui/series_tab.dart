part of '../sonarr_home.dart';

class _SeriesTab extends ConsumerStatefulWidget {
  const _SeriesTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends ConsumerState<_SeriesTab> {
  late final ScrollController _scrollController;
  bool _showScrollUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 300;
      if (show != _showScrollUp) {
        setState(() {
          _showScrollUp = show;
        });
      }
    }
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SonarrSeries>> filteredSeries =
        ref.watch(sonarrFilteredSeriesProvider(widget.instance));
    final SonarrApi? api =
        ref.watch(sonarrApiProvider(widget.instance)).value;
    final SonarrViewMode viewMode = ref.watch(sonarrViewModeProvider(widget.instance));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: NotificationListener<ScrollStartNotification>(
        onNotification: (ScrollStartNotification notification) {
          if (notification.dragDetails != null) {
            FocusScope.of(context).unfocus();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sonarrSeriesProvider(widget.instance));
            await ref.read(sonarrSeriesProvider(widget.instance).future);
          },
          child: AsyncValueView<List<SonarrSeries>>(
            value: filteredSeries,
            onRetry: () => ref.invalidate(sonarrSeriesProvider(widget.instance)),
            data: (List<SonarrSeries> list) {
              return Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: <Widget>[
                      _OneUIAppBar(
                        title: widget.instance.name,
                        showLeading: false,
                        expandedHeight: 280, // Expanded height matching One UI 8.5 Specs
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: _SearchBar(
                            instance: widget.instance,
                            scrollController: _scrollController,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _FilterChipsRow(instance: widget.instance),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      if (list.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyView(
                            icon: Icons.live_tv_outlined,
                            title: 'No series found',
                            message: 'Try adjusting your search query or active filters.',
                          ),
                        )
                      else if (viewMode == SonarrViewMode.grid)
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100), // padding for bottom nav space
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 150, // Slightly smaller grid cards
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 16, // One UI 8.5 Spacing
                              mainAxisSpacing: 20, // One UI 8.5 Spacing
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                                final SonarrSeries s = list[index];
                                final SonarrImage? poster = s.images
                                    .firstWhereOrNull(
                                        (SonarrImage img) => img.coverType == 'poster',);
                                return _SeriesCard(
                                  series: s,
                                  imageUrl: poster == null
                                      ? null
                                      : api?.posterUrl(poster),
                                  onTap: () => _pushSeriesDetail(
                                      context, widget.instance, s.id,),
                                );
                              },
                              childCount: list.length,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (BuildContext context, int index) {
                                final SonarrSeries s = list[index];
                                return _SeriesBannerCard(
                                  instance: widget.instance,
                                  series: s,
                                  onTap: () =>
                                      _pushSeriesDetail(context, widget.instance, s.id),
                                );
                              },
                              childCount: list.length,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Floating Action Capsule pinned at top-right
                  _FloatingActionCapsule(
                    scrollController: _scrollController,
                    actions: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Add Series',
                        onPressed: () => _pushAddSeries(context, widget.instance),
                      ),
                      IconButton(
                        icon: Icon(
                          viewMode == SonarrViewMode.grid
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                        ),
                        tooltip: viewMode == SonarrViewMode.grid
                            ? 'Switch to Banner List'
                            : 'Switch to Grid',
                        onPressed: () {
                          ref
                              .read(sonarrViewModeProvider(widget.instance).notifier)
                              .setViewMode(
                                viewMode == SonarrViewMode.grid
                                    ? SonarrViewMode.banner
                                    : SonarrViewMode.grid,
                              );
                        },
                      ),
                    ],
                  ),

                  // Floating scroll-up button with slide/fade entry animation
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    bottom: _showScrollUp ? 96 : 40,
                    right: 24,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showScrollUp ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton.small(
                          heroTag: 'scroll_up_library',
                          onPressed: _scrollToTop,
                          backgroundColor: colors.secondaryContainer,
                          foregroundColor: colors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Poster card for a single series.
class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.imageUrl,
    required this.onTap,
  });

  final SonarrSeries series;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final colors = theme.colorScheme;
    final List<SonarrSeasonStats> monitoredSeasons = series.seasons
        .where((SonarrSeasonStats s) => s.monitored)
        .sorted((SonarrSeasonStats a, SonarrSeasonStats b) => b.seasonNumber.compareTo(a.seasonNumber));

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16), // Rounded matching One UI 8.5
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashFactory: InkRipple.splashFactory, // Uniform circular ripple splash
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
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.bookmark,
                            size: 10,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    if (monitoredSeasons.isNotEmpty)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: monitoredSeasons.map((SonarrSeasonStats s) {
                              final double seasonProgress = (s.statistics == null || s.statistics!.totalEpisodeCount == 0)
                                  ? 0
                                  : (s.statistics!.episodeFileCount / s.statistics!.totalEpisodeCount).clamp(0, 1);
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(1.5),
                                    child: LinearProgressIndicator(
                                      value: seasonProgress.toDouble(),
                                      minHeight: 3,
                                      backgroundColor: Colors.white24,
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
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Text(
                  series.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
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
  });

  final Instance instance;
  final SonarrSeries series;
  final VoidCallback onTap;

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
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 16dp rounded corners
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashFactory: InkRipple.splashFactory, // Uniform circular splash
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
                      stops: const <double>[0.3, 0.7, 1.0],
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
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: monitoredSeasons.map((SonarrSeasonStats s) {
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
                                  }).toList(),
                                ),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.bookmark,
                          color: theme.colorScheme.onPrimary,
                          size: 14,
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
  const _SearchBar({
    required this.instance,
    required this.scrollController,
  });

  final Instance instance;
  final ScrollController scrollController;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final String initialQuery = ref.read(sonarrSearchQueryProvider(widget.instance));
    _controller = TextEditingController(text: initialQuery);
    _focusNode = FocusNode(skipTraversal: true);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _lastBottomInset = View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final double bottomInset = View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio;
    if (bottomInset == 0 && _lastBottomInset > 0) {
      // Keyboard went from open to closed
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
    _lastBottomInset = bottomInset;
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            224, // 280 (expandedHeight) - 56 (collapsedHeight)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } else {
      if (_controller.text.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.scrollController.hasClients) {
            widget.scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
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
        theme.colorScheme.surfaceContainerLow,
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // Pill shape for One UI 8.5
        ),
      ),
      onChanged: (String val) {
        setState(() {}); // to show/hide the clear button
        ref.read(sonarrSearchQueryProvider(widget.instance).notifier).state = val;
      },
    );
  }
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SonarrSortOption sortOption = ref.watch(sonarrSortOptionProvider(instance));
    final SonarrStatusFilter statusFilter = ref.watch(sonarrStatusFilterProvider(instance));
    final SonarrMonitoredFilter monitoredFilter = ref.watch(sonarrMonitoredFilterProvider(instance));
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    String sortLabel(SonarrSortOption opt) => switch (opt) {
      SonarrSortOption.titleAsc => 'Title (A-Z)',
      SonarrSortOption.titleDesc => 'Title (Z-A)',
      SonarrSortOption.yearAsc => 'Year (Oldest)',
      SonarrSortOption.yearDesc => 'Year (Newest)',
      SonarrSortOption.sizeAsc => 'Size (Smallest)',
      SonarrSortOption.sizeDesc => 'Size (Largest)',
      SonarrSortOption.progressAsc => 'Progress (Lowest)',
      SonarrSortOption.progressDesc => 'Progress (Highest)',
    };

    String statusLabel(SonarrStatusFilter flt) => switch (flt) {
      SonarrStatusFilter.all => 'Status: All',
      SonarrStatusFilter.continuing => 'Status: Continuing',
      SonarrStatusFilter.ended => 'Status: Ended',
    };

    String monitoredLabel(SonarrMonitoredFilter flt) => switch (flt) {
      SonarrMonitoredFilter.all => 'Monitored: All',
      SonarrMonitoredFilter.monitored => 'Monitored: Yes',
      SonarrMonitoredFilter.unmonitored => 'Monitored: No',
    };

    final bool isSortActive = sortOption != SonarrSortOption.titleAsc;
    final bool isStatusActive = statusFilter != SonarrStatusFilter.all;
    final bool isMonitoredActive = monitoredFilter != SonarrMonitoredFilter.all;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          // Sort Chip
          PopupMenuButton<SonarrSortOption>(
            onSelected: (SonarrSortOption opt) {
              ref.read(sonarrSortOptionProvider(instance).notifier).state = opt;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  FocusScope.of(context).unfocus();
                }
              });
            },
            itemBuilder: (BuildContext context) => SonarrSortOption.values.map(
              (SonarrSortOption opt) => PopupMenuItem<SonarrSortOption>(
                value: opt,
                child: Text(sortLabel(opt)),
              ),
            ).toList(),
            child: IgnorePointer(
              child: ChoiceChip(
                avatar: Icon(
                  Icons.sort,
                  size: 16,
                  color: isSortActive ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                ),
                label: Text('Sort: ${sortLabel(sortOption)}'),
                selected: isSortActive,
                selectedColor: colors.secondaryContainer,
                backgroundColor: colors.surfaceContainerLow, // Tonal background when inactive
                labelStyle: TextStyle(
                  color: isSortActive ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                  fontWeight: isSortActive ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide.none, // No border for Ambient Design
                onSelected: (_) {},
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Status Filter Chip
          PopupMenuButton<SonarrStatusFilter>(
            onSelected: (SonarrStatusFilter flt) {
              ref.read(sonarrStatusFilterProvider(instance).notifier).state = flt;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  FocusScope.of(context).unfocus();
                }
              });
            },
            itemBuilder: (BuildContext context) => SonarrStatusFilter.values.map(
              (SonarrStatusFilter flt) => PopupMenuItem<SonarrStatusFilter>(
                value: flt,
                child: Text(statusLabel(flt)),
              ),
            ).toList(),
            child: IgnorePointer(
              child: ChoiceChip(
                avatar: Icon(
                  statusFilter == SonarrStatusFilter.all
                      ? Icons.filter_alt_outlined
                      : Icons.filter_alt,
                  size: 16,
                  color: isStatusActive ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                ),
                label: Text(statusLabel(statusFilter)),
                selected: isStatusActive,
                selectedColor: colors.secondaryContainer,
                backgroundColor: colors.surfaceContainerLow, // Tonal background when inactive
                labelStyle: TextStyle(
                  color: isStatusActive ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                  fontWeight: isStatusActive ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide.none, // No border for Ambient Design
                onSelected: (_) {},
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Monitored Filter Chip
          PopupMenuButton<SonarrMonitoredFilter>(
            onSelected: (SonarrMonitoredFilter flt) {
              ref.read(sonarrMonitoredFilterProvider(instance).notifier).state = flt;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  FocusScope.of(context).unfocus();
                }
              });
            },
            itemBuilder: (BuildContext context) => SonarrMonitoredFilter.values.map(
              (SonarrMonitoredFilter flt) => PopupMenuItem<SonarrMonitoredFilter>(
                value: flt,
                child: Text(monitoredLabel(flt)),
              ),
            ).toList(),
            child: IgnorePointer(
              child: ChoiceChip(
                avatar: Icon(
                  monitoredFilter == SonarrMonitoredFilter.all
                      ? Icons.bookmark_border
                      : Icons.bookmark,
                  size: 16,
                  color: isMonitoredActive ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                ),
                label: Text(monitoredLabel(monitoredFilter)),
                selected: isMonitoredActive,
                selectedColor: colors.secondaryContainer,
                backgroundColor: colors.surfaceContainerLow, // Tonal background when inactive
                labelStyle: TextStyle(
                  color: isMonitoredActive ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                  fontWeight: isMonitoredActive ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide.none, // No border for Ambient Design
                onSelected: (_) {},
              ),
            ),
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
      memCacheWidth: 200,
      placeholder: (BuildContext context, String url) =>
          Container(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (BuildContext context, String url, Object error) =>
          fallback,
    );
  }
}

class _FloatingActionCapsule extends StatefulWidget {
  const _FloatingActionCapsule({
    required this.scrollController,
    required this.actions,
  });

  final ScrollController scrollController;
  final List<Widget> actions;

  @override
  State<_FloatingActionCapsule> createState() => _FloatingActionCapsuleState();
}

class _FloatingActionCapsuleState extends State<_FloatingActionCapsule> {
  // Only track whether we are in the "blurred" state, not the raw pixel offset.
  // This means setState is called at most twice (false→true, true→false) during
  // any given scroll session instead of 60+ times per second.
  bool _isBlurred = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FloatingActionCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final bool blurred = widget.scrollController.offset > 120;
    // Only rebuild when the boolean state actually flips.
    if (blurred != _isBlurred) {
      setState(() => _isBlurred = blurred);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final double safeTop = MediaQuery.of(context).padding.top;

    final Widget capsuleContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: _isBlurred ? 8 : 0,
        vertical: _isBlurred ? 4 : 0,
      ),
      decoration: BoxDecoration(
        color: _isBlurred
            ? colors.surfaceContainerHighest.withValues(alpha: 0.65)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: _isBlurred
            ? Border.all(color: colors.outlineVariant.withValues(alpha: 0.2), width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.actions,
      ),
    );

    return Positioned(
      top: safeTop + 8,
      right: 16,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          // Only pay the BackdropFilter saveLayer cost when blur is actually needed.
          child: _isBlurred
              ? BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: capsuleContent,
                )
              : capsuleContent,
        ),
      ),
    );
  }
}
