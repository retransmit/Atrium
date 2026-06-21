part of '../sonarr_home.dart';

class _WantedTab extends StatefulWidget {
  const _WantedTab({required this.instance});

  final Instance instance;

  @override
  State<_WantedTab> createState() => _WantedTabState();
}

class _WantedTabState extends State<_WantedTab> {
  int _wantedSubTab = 0;
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
      final show = _scrollController.offset > 200;
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Builder(builder: (BuildContext tabCtx) {
        return Scaffold(
          body: Stack(
            children: [
              NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    const _OneUIAppBar(
                      title: 'Wanted',
                      showLeading: false,
                      expandedHeight: 280, // Expanded height matching One UI 8.5 Specs
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: _OneUISegmentedBar(
                          items: const <String>['Missing', 'Cutoff', 'Import'],
                          selectedIndex: _wantedSubTab,
                          onSelected: (int i) {
                            setState(() => _wantedSubTab = i);
                            DefaultTabController.of(tabCtx).animateTo(i);
                          },
                        ),
                      ),
                    ),
                  ];
                },
                // NeverScrollableScrollPhysics: horizontal drags belong to PageView.
                body: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    _WantedMissingSubTab(
                      instance: widget.instance,
                    ),
                    _WantedCutoffSubTab(
                      instance: widget.instance,
                    ),
                    _WantedManualImportSubTab(
                      instance: widget.instance,
                    ),
                  ],
                ),
              ),

              // Floating scroll-up button
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
                      heroTag: 'scroll_up_wanted',
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
          ),
        );
      },),
    );
  }
}

class _GroupedSeriesCard extends StatefulWidget {
  const _GroupedSeriesCard({
    required this.series,
    required this.records,
    required this.subtitle,
    required this.api,
    required this.onSearchEpisode,
    required this.onTapSeries,
    required this.statusColor,
  });

  final SonarrSeries series;
  final List<SonarrWantedRecord> records;
  final String subtitle;
  final SonarrApi? api;
  final Future<void> Function(int episodeId, String label) onSearchEpisode;
  final VoidCallback onTapSeries;
  final Color statusColor;

  @override
  State<_GroupedSeriesCard> createState() => _GroupedSeriesCardState();
}

class _GroupedSeriesCardState extends State<_GroupedSeriesCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..addStatusListener(_onExpandStatusChanged);
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController
      ..removeStatusListener(_onExpandStatusChanged)
      ..dispose();
    super.dispose();
  }

  void _onExpandStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final SonarrImage? poster = widget.series.images.firstWhereOrNull((img) => img.coverType == 'poster');
    final String? imageUrl = poster != null ? widget.api?.posterUrl(poster) : null;
    final bool shouldBuildEpisodes = _isExpanded || _expandController.value > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: theme.brightness == Brightness.dark ? 0.12 : 0.2),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Series Title and Poster
          InkWell(
            onTap: _toggleExpand,
            splashFactory: InkRipple.splashFactory,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: Radius.circular(_isExpanded ? 0 : 24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 60,
                      child: imageUrl == null
                          ? Container(
                              color: colors.surfaceContainerHighest,
                              child: Icon(Icons.live_tv, color: colors.outline, size: 20),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: colors.surfaceContainerHighest,
                                child: Icon(Icons.live_tv, color: colors.outline, size: 20),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.series.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dedicated Info Button to go to Series detail
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    color: colors.onSurfaceVariant,
                    tooltip: 'View series details',
                    onPressed: widget.onTapSeries,
                  ),
                  // Expand arrow rotating
                  RotationTransition(
                    turns: Tween<double>(begin: 0.0, end: 0.5).animate(_expandAnimation),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: !shouldBuildEpisodes
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: colors.outlineVariant.withValues(alpha: 0.3),
                      ),
                      Column(
                        children: [
                          for (int i = 0; i < widget.records.length; i++) ...[
                            _GroupedEpisodeTile(
                              record: widget.records[i],
                              onSearch: () => widget.onSearchEpisode(
                                widget.records[i].id,
                                'S${widget.records[i].seasonNumber}E${widget.records[i].episodeNumber}',
                              ),
                            ),
                            if (i < widget.records.length - 1)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 16,
                                endIndent: 16,
                                color: colors.outlineVariant.withValues(alpha: 0.3),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupedEpisodeTile extends StatefulWidget {
  const _GroupedEpisodeTile({
    required this.record,
    required this.onSearch,
  });

  final SonarrWantedRecord record;
  final Future<void> Function() onSearch;

  @override
  State<_GroupedEpisodeTile> createState() => _GroupedEpisodeTileState();
}

class _GroupedEpisodeTileState extends State<_GroupedEpisodeTile> {
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Text(
              epCode,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.record.title ?? 'Episode ${widget.record.episodeNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: colors.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Aired: $formattedAirDate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            height: 38,
            child: _isSearching
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search_rounded, size: 18),
                      color: colors.primary,
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
    );
  }
}

class _WantedMissingSubTab extends ConsumerStatefulWidget {
  const _WantedMissingSubTab({
    required this.instance,
  });

  final Instance instance;

  @override
  ConsumerState<_WantedMissingSubTab> createState() => _WantedMissingSubTabState();
}

class _WantedMissingSubTabState extends ConsumerState<_WantedMissingSubTab> {
  bool _isSearchingAll = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SonarrWantedPage> missing =
        ref.watch(sonarrWantedMissingProvider(widget.instance));
    final SonarrApi? api = ref.watch(sonarrApiProvider(widget.instance)).value;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrWantedMissingProvider(widget.instance));
        await ref.read(sonarrWantedMissingProvider(widget.instance).future);
      },
      child: AsyncValueView<SonarrWantedPage>(
        value: missing,
        onRetry: () => ref.invalidate(sonarrWantedMissingProvider(widget.instance)),
        data: (SonarrWantedPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.check_circle_outline,
              title: 'No missing episodes',
              message: 'Everything is up to date!',
            );
          }

          // Group records by seriesId
          final Map<int, List<SonarrWantedRecord>> grouped = {};
          for (final record in dataPage.records) {
            grouped.putIfAbsent(record.seriesId, () => []).add(record);
          }

          final List<int> sortedSeriesIds = grouped.keys.toList()
            ..sort((a, b) {
              final titleA = grouped[a]!.first.series?.title ?? '';
              final titleB = grouped[b]!.first.series?.title ?? '';
              return titleA.toLowerCase().compareTo(titleB.toLowerCase());
            });

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // 20px padding left/right
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
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Search All'),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                  itemCount: sortedSeriesIds.length,
                  itemBuilder: (context, index) {
                    final seriesId = sortedSeriesIds[index];
                    final records = grouped[seriesId]!;
                    final series = records.first.series ?? SonarrSeries(id: seriesId, title: 'Unknown Series');
                    final Color statusColor = theme.brightness == Brightness.dark
                        ? Colors.orangeAccent
                        : Colors.orange.shade800;

                    return _GroupedSeriesCard(
                      series: series,
                      records: records,
                      subtitle: '${records.length} missing ${records.length == 1 ? 'episode' : 'episodes'}',
                      statusColor: statusColor,
                      api: api,
                      onSearchEpisode: (episodeId, label) async {
                        final SonarrApi apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                        await apiObj.searchEpisode(episodeId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Search triggered for $label')),
                          );
                        }
                      },
                      onTapSeries: () => _pushSeriesDetail(
                        context,
                        widget.instance,
                        seriesId,
                      ),
                    );
                  },
                ),
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
  });

  final Instance instance;

  @override
  ConsumerState<_WantedCutoffSubTab> createState() => _WantedCutoffSubTabState();
}

class _WantedCutoffSubTabState extends ConsumerState<_WantedCutoffSubTab> {
  bool _isSearchingAll = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SonarrWantedPage> cutoff =
        ref.watch(sonarrWantedCutoffProvider(widget.instance));
    final SonarrApi? api = ref.watch(sonarrApiProvider(widget.instance)).value;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrWantedCutoffProvider(widget.instance));
        await ref.read(sonarrWantedCutoffProvider(widget.instance).future);
      },
      child: AsyncValueView<SonarrWantedPage>(
        value: cutoff,
        onRetry: () => ref.invalidate(sonarrWantedCutoffProvider(widget.instance)),
        data: (SonarrWantedPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.check_circle_outline,
              title: 'No cutoff unmet episodes',
              message: 'All episodes meet the cutoff!',
            );
          }

          // Group records by seriesId
          final Map<int, List<SonarrWantedRecord>> grouped = {};
          for (final record in dataPage.records) {
            grouped.putIfAbsent(record.seriesId, () => []).add(record);
          }

          final List<int> sortedSeriesIds = grouped.keys.toList()
            ..sort((a, b) {
              final titleA = grouped[a]!.first.series?.title ?? '';
              final titleB = grouped[b]!.first.series?.title ?? '';
              return titleA.toLowerCase().compareTo(titleB.toLowerCase());
            });

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // 20px padding left/right
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
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Search All'),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                  itemCount: sortedSeriesIds.length,
                  itemBuilder: (context, index) {
                    final seriesId = sortedSeriesIds[index];
                    final records = grouped[seriesId]!;
                    final series = records.first.series ?? SonarrSeries(id: seriesId, title: 'Unknown Series');
                    final Color statusColor = colors.secondary;

                    return _GroupedSeriesCard(
                      series: series,
                      records: records,
                      subtitle: '${records.length} cutoff unmet ${records.length == 1 ? 'episode' : 'episodes'}',
                      statusColor: statusColor,
                      api: api,
                      onSearchEpisode: (episodeId, label) async {
                        final SonarrApi apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                        await apiObj.searchEpisode(episodeId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Search triggered for $label')),
                          );
                        }
                      },
                      onTapSeries: () => _pushSeriesDetail(
                        context,
                        widget.instance,
                        seriesId,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
