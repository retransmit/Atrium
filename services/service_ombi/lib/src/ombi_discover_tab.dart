import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_request_sheet.dart';

/// What is popular, coming soon and trending, as Ombi lists it. Every poster
/// opens the same request sheet as search.
class OmbiDiscoverTab extends ConsumerWidget {
  const OmbiDiscoverTab({required this.instance, super.key});

  final Instance instance;

  static const List<(OmbiDiscoverRow, String)> _rows =
      <(OmbiDiscoverRow, String)>[
    (OmbiDiscoverRow.popularMovies, 'Popular movies'),
    (OmbiDiscoverRow.upcomingMovies, 'Upcoming movies'),
    (OmbiDiscoverRow.popularTv, 'Popular TV'),
    (OmbiDiscoverRow.trendingTv, 'Trending TV'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EasyRefresh(
      onRefresh: () {
        for (final (OmbiDiscoverRow row, String _) in _rows) {
          ref.invalidate(ombiDiscoverProvider((instance: instance, row: row)));
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: Insets.xl),
        children: <Widget>[
          for (final (OmbiDiscoverRow row, String title) in _rows)
            _DiscoverRow(instance: instance, row: row, title: title),
        ],
      ),
    );
  }
}

/// One list, as a strip of posters. It loads and fails on its own, so one
/// list Ombi could not fetch does not take the rest of the tab with it.
class _DiscoverRow extends ConsumerWidget {
  const _DiscoverRow({
    required this.instance,
    required this.row,
    required this.title,
  });

  final Instance instance;
  final OmbiDiscoverRow row;
  final String title;

  static const double _stripHeight = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OmbiDiscoverKey key = (instance: instance, row: row);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.sm,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: _stripHeight,
          child: ref.watch(ombiDiscoverProvider(key)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          describeOmbiFailure(error, lookup: OmbiLookup.list),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(ombiDiscoverProvider(key)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (List<OmbiSearchHit> hits) => hits.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing here right now',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: Insets.lg),
                        itemCount: hits.length,
                        separatorBuilder: (BuildContext _, int __) =>
                            const SizedBox(width: Insets.md),
                        itemBuilder: (BuildContext context, int i) =>
                            _PosterCard(
                          hit: hits[i],
                          onTap: () => showOmbiRequestSheet(
                            context: context,
                            instance: instance,
                            hit: hits[i],
                          ),
                        ),
                      ),
              ),
        ),
      ],
    );
  }
}

/// A poster with its title under it, and a small mark when Ombi says the
/// title is already requested or available.
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.hit, required this.onTap});

  final OmbiSearchHit hit;
  final VoidCallback onTap;

  static const double _width = 112;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? poster = hit.posterUrl;
    final IconData? mark = hit.available
        ? Icons.check_circle
        : (hit.requested ? Icons.schedule : null);

    final Widget fallback = Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        hit.kind == OmbiMediaKind.movie
            ? Icons.movie_outlined
            : Icons.live_tv_outlined,
        color: cs.onSurfaceVariant,
      ),
    );

    return SizedBox(
      width: _width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (poster == null)
                      fallback
                    else
                      AtriumNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        memCacheWidth: 224,
                        errorWidget: (_, __, ___) => fallback,
                      ),
                    if (mark != null)
                      Positioned(
                        top: Insets.xs,
                        right: Insets.xs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(mark, size: 16, color: cs.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              hit.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
