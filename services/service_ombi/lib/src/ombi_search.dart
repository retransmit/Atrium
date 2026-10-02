import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_request_sheet.dart';
import 'widgets/ombi_visuals.dart';

/// Searches Ombi for movies and shows; tapping one opens its title sheet.
class OmbiSearchDelegate extends SearchDelegate<void> {
  OmbiSearchDelegate({required this.instance})
      : super(searchFieldLabel: 'Search movies and shows');

  final Instance instance;

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context);

  @override
  List<Widget>? buildActions(BuildContext context) => query.isEmpty
      ? const <Widget>[]
      : <Widget>[
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
        ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) =>
      _OmbiSearchResults(instance: instance, query: query);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _OmbiSearchResults(instance: instance, query: query);
}

class _OmbiSearchResults extends ConsumerWidget {
  const _OmbiSearchResults({required this.instance, required this.query});

  final Instance instance;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String q = query.trim();
    if (q.length < 2) {
      return const EmptyView(
        icon: Icons.search,
        title: 'Search for a movie or a show.',
      );
    }
    final OmbiSearchKey key = (instance: instance, query: q);
    return ref.watch(ombiSearchProvider(key)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => ErrorView(
            title: 'Search failed',
            message: describeOmbiFailure(error, lookup: OmbiLookup.search),
            onRetry: () => ref.invalidate(ombiSearchProvider(key)),
          ),
          data: (List<OmbiSearchHit> hits) {
            if (hits.isEmpty) {
              return EmptyView(
                icon: Icons.search_off,
                title: 'No results',
                message: 'Nothing on Ombi matches "$q".',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.sm,
                Insets.lg,
                Insets.xl,
              ),
              itemCount: hits.length,
              separatorBuilder: (BuildContext _, int __) =>
                  const SizedBox(height: Insets.md),
              itemBuilder: (BuildContext context, int i) => _ResultCard(
                hit: hits[i],
                onTap: () => showOmbiRequestSheet(
                  context: context,
                  instance: instance,
                  hit: hits[i],
                ),
              ),
            );
          },
        );
  }
}

/// One result: its poster, title, whether it is a movie or a show, and the
/// opening of its overview, which is what tells two films of one name apart.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.hit, required this.onTap});

  final OmbiSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? overview = hit.overview;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              OmbiPoster(url: hit.posterUrl, kind: hit.kind, width: 60),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Insets.xs),
                    OmbiPill(
                      label:
                          hit.kind == OmbiMediaKind.movie ? 'Movie' : 'TV show',
                      icon: ombiKindIcon(hit.kind),
                      foreground: cs.onSurfaceVariant,
                      background: cs.surfaceContainerHighest,
                    ),
                    if (overview != null) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
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
