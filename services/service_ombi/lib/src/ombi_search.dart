import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_request_sheet.dart';

/// Searches Ombi for movies and shows; tapping one opens its request sheet.
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
      return const Center(child: Text('Search for a movie or a show.'));
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
            return ListView.builder(
              itemCount: hits.length,
              itemBuilder: (BuildContext context, int i) {
                final OmbiSearchHit hit = hits[i];
                final String? poster = hit.posterUrl;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40,
                      height: 60,
                      child: poster == null
                          ? const Icon(Icons.image_not_supported_outlined)
                          : AtriumNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                            ),
                    ),
                  ),
                  title: Text(hit.title),
                  subtitle: Text(
                    hit.kind == OmbiMediaKind.movie ? 'Movie' : 'TV show',
                  ),
                  onTap: () => showOmbiRequestSheet(
                    context: context,
                    instance: instance,
                    hit: hit,
                  ),
                );
              },
            );
          },
        );
  }
}
