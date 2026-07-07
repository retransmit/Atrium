import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service_sonarr.dart';

class SeriesTab extends ConsumerStatefulWidget {
  const SeriesTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends ConsumerState<SeriesTab> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;
  bool _keyboardWasVisible = false;

  @override
  void initState() {
    super.initState();
    final String initialQuery = ref.read(sonarrSearchQueryProvider(widget.instance));
    _searchController = TextEditingController(text: initialQuery);
    _scrollController = ScrollController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<SonarrSeries>> filtered =
        ref.watch(sonarrFilteredSeriesProvider(widget.instance));
    final SonarrApi? api = ref.watch(sonarrApiProvider(widget.instance)).value;
    final SonarrViewMode viewMode = ref.watch(sonarrViewModeProvider(widget.instance));

    ref.listen<int>(sonarrSeriesScrollToTopProvider(widget.instance), (previous, next) {
      if (next > 0 && _scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });

    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (isKeyboardOpen) {
      _keyboardWasVisible = true;
    } else if (_keyboardWasVisible) {
      _keyboardWasVisible = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).unfocus();
      });
    }

    return PopScope<Object?>(
      canPop: _searchController.text.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        setState(() {
          _searchController.clear();
        });
        ref.read(sonarrSearchQueryProvider(widget.instance).notifier).state = '';
      },
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: AsyncValueView<List<SonarrSeries>>(
            value: filtered,
            onRetry: () => ref.invalidate(sonarrSeriesProvider(widget.instance)),
            data: (List<SonarrSeries> list) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(sonarrSeriesProvider(widget.instance));
                  await ref.read(sonarrSeriesProvider(widget.instance).future);
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: <Widget>[
                    // Built-in Material 3 SliverAppBar with floating & snap animation
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      scrolledUnderElevation: 0.0,
                      surfaceTintColor: Colors.transparent,
                      backgroundColor: theme.colorScheme.surface,
                      toolbarHeight: 72,
                      titleSpacing: 0,
                      leadingWidth: 56,
                      leading: IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Menu button pressed')),
                          );
                        },
                      ),
                      title: SearchBar(
                        focusNode: _searchFocusNode,
                        controller: _searchController,
                        hintText: 'Search series...',
                        elevation: const WidgetStatePropertyAll<double>(0),
                        backgroundColor: WidgetStatePropertyAll<Color>(
                          theme.colorScheme.surfaceContainerHigh,
                        ),
                        trailing: <Widget>[
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                                ref.read(sonarrSearchQueryProvider(widget.instance).notifier).state = '';
                              },
                            ),
                        ],
                        onChanged: (String value) {
                          setState(() {});
                          ref.read(sonarrSearchQueryProvider(widget.instance).notifier).state = value;
                        },
                      ),
                    actions: <Widget>[
                      IconButton(
                        icon: Icon(viewMode == SonarrViewMode.grid ? Icons.view_list : Icons.grid_view),
                        tooltip: viewMode == SonarrViewMode.grid ? 'Switch to list view' : 'Switch to grid view',
                        onPressed: () {
                          ref.read(sonarrViewModeProvider(widget.instance).notifier).state =
                              viewMode == SonarrViewMode.grid ? SonarrViewMode.list : SonarrViewMode.grid;
                        },
                      ),
                      const SizedBox(width: Insets.sm),
                    ],
                  ),
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
                      padding: const EdgeInsets.all(Insets.md),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140,
                          childAspectRatio: 0.5,
                          crossAxisSpacing: Insets.md,
                          mainAxisSpacing: Insets.md,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final SonarrSeries s = list[index];
                            final SonarrImage? poster = s.images
                                .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
                            return _SeriesCard(
                              series: s,
                              imageUrl: poster == null ? null : api?.posterUrl(poster, width: 500),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  FadePageRoute<void>(
                                    builder: (BuildContext context) => SeriesDetailScreen(
                                      instance: widget.instance,
                                      seriesId: s.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: list.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final SonarrSeries s = list[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: Insets.md),
                              child: _SeriesBannerCard(
                                instance: widget.instance,
                                series: s,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    FadePageRoute<void>(
                                      builder: (BuildContext context) => SeriesDetailScreen(
                                        instance: widget.instance,
                                        seriesId: s.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: list.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
}

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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Hero(
                    tag: 'series-poster-${series.id}',
                    child: _Poster(imageUrl: imageUrl, theme: theme),
                  ),
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
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
      if (series.status != null) series.status!,
    ];
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
    final String? bannerUrl = banner == null ? null : api?.posterUrl(banner, width: 70);

    final SonarrImage? poster = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
    final String? posterUrl = poster == null ? null : api?.posterUrl(poster, width: 500);

    final Color surfaceColor = theme.colorScheme.surface;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (bannerUrl != null)
                Positioned.fill(
                  child: Hero(
                    tag: 'series-banner-${series.id}',
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorWidget: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        surfaceColor,
                        surfaceColor.withValues(alpha: 0.7),
                        surfaceColor.withValues(alpha: 0.1),
                      ],
                      stops: const <double>[0.15, 0.5, 0.85],
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 80,
                    height: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: posterUrl != null
                          ? Hero(
                              tag: 'series-poster-${series.id}',
                              child: CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.live_tv, size: 20),
                                ),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.live_tv, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _metaText(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  if (series.monitored)
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.md),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bookmark,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metaText() {
    final List<String> parts = <String>[
      if (series.year != null) '${series.year}',
      if (series.network != null && series.network!.isNotEmpty) series.network!,
      if (series.status != null && series.status!.isNotEmpty) series.status!,
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
      child: Icon(Icons.live_tv_outlined, color: theme.colorScheme.outline),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
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

class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}
