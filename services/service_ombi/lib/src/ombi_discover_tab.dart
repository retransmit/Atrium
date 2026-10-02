import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_request_sheet.dart';
import 'widgets/ombi_visuals.dart';

/// What is popular, coming soon and trending, as Ombi lists it. Every card
/// opens the same title sheet as search.
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

/// One list, as a strip of cards. It loads and fails on its own, so one
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
            Insets.md,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: _DiscoverCard.heightFor(context),
          child: ref.watch(ombiDiscoverProvider(key)).when(
                loading: () => const _Placeholders(),
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
                            _DiscoverCard(
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

/// A poster with where the title stands and its score laid over it, and its
/// title and year underneath.
class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.hit, required this.onTap});

  final OmbiSearchHit hit;
  final VoidCallback onTap;

  static const double width = 132;
  static const double _posterHeight = width / Sizes.posterAspect;

  /// How tall a strip of cards is: the poster, two lines of title and a line
  /// for the year, at whatever size the user has their text.
  static double heightFor(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return _posterHeight + Insets.sm + scaler.scale(20) * 2 + scaler.scale(18);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double? rating = hit.rating;
    final int? year = hit.year;

    final Widget card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: _posterHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                OmbiPoster(
                  url: hit.posterUrl,
                  kind: hit.kind,
                  width: width,
                  radius: 0,
                ),
                if (hit.available || hit.requested)
                  Positioned(
                    top: 6,
                    right: 6,
                    // Left of the pill stays clear of the poster's edge
                    // however long the word is.
                    left: 6,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: hit.available
                          ? OmbiPill(
                              label: 'Available',
                              icon: Icons.check_circle_outline_rounded,
                              foreground: cs.onTertiaryContainer,
                              background: cs.tertiaryContainer,
                            )
                          : OmbiPill(
                              label: 'Requested',
                              icon: Icons.schedule_rounded,
                              foreground: cs.onPrimaryContainer,
                              background: cs.primaryContainer,
                            ),
                    ),
                  ),
                if (rating != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: OmbiRatingPill(rating: rating),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          hit.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, height: 20 / 14),
        ),
        if (year != null)
          Text(
            '$year',
            maxLines: 1,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );

    // The whole card takes the tap, title included, and the ink is laid
    // over the artwork so the press shows on the poster too.
    return SizedBox(
      width: width,
      child: Stack(
        children: <Widget>[
          card,
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the cards will be, while a list loads: the row keeps its shape, so
/// the tab does not jump when the posters arrive.
class _Placeholders extends StatelessWidget {
  const _Placeholders();

  @override
  Widget build(BuildContext context) {
    final Color tone = Theme.of(context).colorScheme.surfaceContainerHigh;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      itemCount: 4,
      separatorBuilder: (BuildContext _, int __) =>
          const SizedBox(width: Insets.md),
      itemBuilder: (BuildContext _, int __) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: _DiscoverCard.width,
          height: _DiscoverCard._posterHeight,
          decoration: BoxDecoration(
            color: tone,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
        ),
      ),
    );
  }
}
