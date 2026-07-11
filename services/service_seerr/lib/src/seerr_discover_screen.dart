import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_discover.dart';
import 'seerr_genre_screen.dart';
import 'seerr_item_detail.dart';
import 'seerr_media_card.dart';
import 'seerr_providers.dart';

/// The Discover tab: Watchlist / Trending / Popular / Upcoming rows plus the
/// genre chip rows, each a horizontal list of shared tonal media cards under
/// a consistent bold header.
class SeerrDiscoverScreen extends ConsumerWidget {
  const SeerrDiscoverScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return M3RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(seerrWatchlistProvider(instance));
        ref.invalidate(seerrTrendingProvider(instance));
        ref.invalidate(seerrDiscoverMoviesProvider(instance));
        ref.invalidate(seerrDiscoverTvProvider(instance));
        ref.invalidate(seerrUpcomingMoviesProvider(instance));
        ref.invalidate(seerrUpcomingTvProvider(instance));
        ref.invalidate(seerrMovieGenresProvider(instance));
        ref.invalidate(seerrTvGenresProvider(instance));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        children: <Widget>[
          _DiscoverSection(
            title: 'Watchlist',
            provider: seerrWatchlistProvider(instance),
            instance: instance,
            // Optional row: most servers have an empty watchlist, and the
            // fetch can fail outright (expired Plex token, forks without the
            // endpoint) - collapse instead of showing an empty row or
            // banner-ing Discover with an error.
            hideWhenEmpty: true,
          ),
          _DiscoverSection(
            title: 'Trending',
            provider: seerrTrendingProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Popular Movies',
            provider: seerrDiscoverMoviesProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Upcoming Movies',
            provider: seerrUpcomingMoviesProvider(instance),
            instance: instance,
          ),
          _GenreSection(
            title: 'Movie Genres',
            isMovie: true,
            provider: seerrMovieGenresProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Popular TV Shows',
            provider: seerrDiscoverTvProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Upcoming TV Shows',
            provider: seerrUpcomingTvProvider(instance),
            instance: instance,
          ),
          _GenreSection(
            title: 'TV Genres',
            isMovie: false,
            provider: seerrTvGenresProvider(instance),
            instance: instance,
          ),
        ],
      ),
    );
  }
}

/// Bold section header shared by every Discover row so the media rows and the
/// genre chip rows read as one system.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Insets.pageH,
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DiscoverSection extends ConsumerWidget {
  const _DiscoverSection({
    required this.title,
    required this.provider,
    required this.instance,
    this.hideWhenEmpty = false,
  });

  final String title;
  final FutureProvider<List<SeerrDiscoverResult>> provider;
  final Instance instance;

  /// Collapse the whole section (header included) unless a non-empty list
  /// is available; optional rows like the Watchlist degrade like the detail
  /// screen's Recommendations / Similar rows and render nothing while
  /// loading, on error, and when empty.
  final bool hideWhenEmpty;

  /// Shared row height so every Discover section sizes identically.
  static const double _rowHeight = 250;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SeerrDiscoverResult>> items = ref.watch(provider);
    if (hideWhenEmpty && (items.hasError || (items.value?.isEmpty ?? true))) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(title: title),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: _rowHeight,
          child: AsyncValueView<List<SeerrDiscoverResult>>(
            value: items,
            onRetry: () => ref.invalidate(provider),
            data: (List<SeerrDiscoverResult> list) {
              if (list.isEmpty) {
                return const Center(child: Text('No results.'));
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: Insets.pageH,
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final SeerrDiscoverResult item = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: Insets.md),
                    child: SeerrMediaCard(
                      item: item,
                      onTap: () => pushScreen<void>(
                        context,
                        SeerrItemDetailScreen(
                          instance: instance,
                          item: item,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}

class _GenreSection extends ConsumerWidget {
  const _GenreSection({
    required this.title,
    required this.isMovie,
    required this.provider,
    required this.instance,
  });

  final String title;
  final bool isMovie;
  final FutureProvider<List<SeerrGenre>> provider;
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SeerrGenre>> genres = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(title: title),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 48,
          child: AsyncValueView<List<SeerrGenre>>(
            value: genres,
            onRetry: () => ref.invalidate(provider),
            data: (List<SeerrGenre> list) {
              if (list.isEmpty) return const SizedBox();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: Insets.pageH,
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final SeerrGenre genre = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: ActionChip(
                      avatar: Icon(
                        isMovie
                            ? Icons.movie_filter_outlined
                            : Icons.live_tv_outlined,
                        size: 16,
                      ),
                      label: Text(genre.name),
                      onPressed: () {
                        pushScreen<void>(
                          context,
                          SeerrGenreScreen(
                            instance: instance,
                            genre: genre,
                            isMovie: isMovie,
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}
