import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_discover.dart';
import 'seerr_genre_screen.dart';
import 'seerr_item_detail.dart';
import 'seerr_providers.dart';
import 'seerr_status_badge.dart';
import 'package:m3_expressive/m3_expressive.dart';

class SeerrDiscoverScreen extends ConsumerWidget {
  const SeerrDiscoverScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return M3RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(seerrTrendingProvider(instance));
        ref.invalidate(seerrUpcomingMoviesProvider(instance));
        ref.invalidate(seerrUpcomingTvProvider(instance));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        children: <Widget>[
          _GenreSection(
            title: 'Movie Genres',
            isMovie: true,
            provider: seerrMovieGenresProvider(instance),
            instance: instance,
          ),
          _GenreSection(
            title: 'TV Genres',
            isMovie: false,
            provider: seerrTvGenresProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Trending',
            provider: seerrTrendingProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Upcoming Movies',
            provider: seerrUpcomingMoviesProvider(instance),
            instance: instance,
          ),
          _DiscoverSection(
            title: 'Upcoming TV Shows',
            provider: seerrUpcomingTvProvider(instance),
            instance: instance,
          ),
        ],
      ),
    );
  }
}

class _DiscoverSection extends ConsumerWidget {
  const _DiscoverSection(
      {required this.title, required this.provider, required this.instance});

  final String title;
  final FutureProvider<List<SeerrDiscoverResult>> provider;
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SeerrDiscoverResult>> items = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: Insets.pageH,
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 250,
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
                  return Container(
                    width: 128,
                    margin: const EdgeInsets.only(right: Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Material(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => pushScreen<void>(
                                context,
                                SeerrItemDetailScreen(
                                  instance: instance,
                                  item: item,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  item.posterPath != null
                                      ? Image.network(
                                          'https://image.tmdb.org/t/p/w500${item.posterPath}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const _Placeholder(),
                                        )
                                      : const _Placeholder(),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: SeerrStatusBadge(
                                      status: item.mediaInfo?.status,
                                    ),
                                  ),
                                  if (item.voteAverage != null &&
                                      item.voteAverage! > 0)
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: _RatingBadge(
                                          value: item.voteAverage!),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          item.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (item.displayDate != null)
                          Text(
                            item.displayDate!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
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

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.movie_outlined)),
    );
  }
}

/// A small rating pill (star + score) overlaid on a poster.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star, size: 11, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        Padding(
          padding: Insets.pageH,
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: Insets.xs),
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
