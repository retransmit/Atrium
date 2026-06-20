part of '../sonarr_home.dart';

class _WantedTab extends StatefulWidget {
  const _WantedTab({required this.instance});

  final Instance instance;

  @override
  State<_WantedTab> createState() => _WantedTabState();
}

class _WantedTabState extends State<_WantedTab> {
  int _missingPage = 1;
  int _cutoffPage = 1;
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
                      page: _missingPage,
                      onPageChanged: (p) => setState(() => _missingPage = p),
                    ),
                    _WantedCutoffSubTab(
                      instance: widget.instance,
                      page: _cutoffPage,
                      onPageChanged: (p) => setState(() => _cutoffPage = p),
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

    return InkWell(
      onTap: widget.onTap,
      splashFactory: InkRipple.splashFactory, // Uniform circular splash
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Padding matching One UI 8.5 list elements
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12), // 12dp rounded corner
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
            const SizedBox(width: 16),
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
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer, // Tonal fill, no borders
                          borderRadius: BorderRadius.circular(8), // 8dp corners
                        ),
                        child: Text(
                          epCode,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
            const SizedBox(width: 12),
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
                        icon: const Icon(Icons.search_rounded), // Rounded icon
                        color: colors.onSurfaceVariant, // Subtle coloring
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
                child: ListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100), // padding bottom for bottom nav
                  children: <Widget>[
                    _OneUIGroupCard(
                      margin: EdgeInsets.zero,
                      children: dataPage.records.map((SonarrWantedRecord record) {
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
                          onTap: () => _pushSeriesDetail(
                            context,
                            widget.instance,
                            record.seriesId,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
                child: ListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100), // padding bottom for bottom nav
                  children: <Widget>[
                    _OneUIGroupCard(
                      margin: EdgeInsets.zero,
                      children: dataPage.records.map((SonarrWantedRecord record) {
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
                          onTap: () => _pushSeriesDetail(
                            context,
                            widget.instance,
                            record.seriesId,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
