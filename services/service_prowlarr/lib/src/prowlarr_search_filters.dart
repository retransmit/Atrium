import 'package:flutter/foundation.dart';

/// Prowlarr's ids for "every usenet indexer" and "every torrent indexer".
/// Sent as indexer ids, they cover indexers added later too.
const int prowlarrAllUsenet = -1;
const int prowlarrAllTorrents = -2;

/// What a search is narrowed to. Empty means all, as in Prowlarr.
@immutable
class ProwlarrSearchFilter {
  const ProwlarrSearchFilter({
    this.indexerIds = const <int>{},
    this.categories = const <int>{},
  });

  final Set<int> indexerIds;
  final Set<int> categories;

  bool get isEmpty => indexerIds.isEmpty && categories.isEmpty;

  /// How many things are picked, for the filter button's badge.
  int get count => indexerIds.length + categories.length;

  ProwlarrSearchFilter copyWith({Set<int>? indexerIds, Set<int>? categories}) =>
      ProwlarrSearchFilter(
        indexerIds: indexerIds ?? this.indexerIds,
        categories: categories ?? this.categories,
      );

  @override
  bool operator ==(Object other) =>
      other is ProwlarrSearchFilter &&
      setEquals(other.indexerIds, indexerIds) &&
      setEquals(other.categories, categories);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(indexerIds),
        Object.hashAllUnordered(categories),
      );
}

/// The search field's hint: what a search with [filter] will reach.
String prowlarrSearchHint(ProwlarrSearchFilter filter) {
  final Set<int> ids = filter.indexerIds;
  final bool torrents = ids.contains(prowlarrAllTorrents);
  final bool usenet = ids.contains(prowlarrAllUsenet);
  final int others = ids
      .where((int id) => id != prowlarrAllTorrents && id != prowlarrAllUsenet)
      .length;
  final String count = '$others ${others == 1 ? 'indexer' : 'indexers'}';
  if (ids.isEmpty || (torrents && usenet)) {
    return 'Search all indexers...';
  }
  if (!torrents && !usenet) {
    return 'Search $count...';
  }
  final String group = torrents ? 'all torrents' : 'all usenet';
  return others == 0 ? 'Search $group...' : 'Search $group and $count...';
}
