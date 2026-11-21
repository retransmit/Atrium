import 'package:flutter_test/flutter_test.dart';
import 'package:service_prowlarr/service_prowlarr.dart';

void main() {
  test('hint follows the indexer filter', () {
    String hint(Set<int> ids) =>
        prowlarrSearchHint(ProwlarrSearchFilter(indexerIds: ids));
    expect(hint(<int>{}), 'Search all indexers...');
    expect(hint(<int>{prowlarrAllTorrents}), 'Search all torrents...');
    expect(hint(<int>{prowlarrAllUsenet}), 'Search all usenet...');
    expect(
      hint(<int>{prowlarrAllTorrents, prowlarrAllUsenet}),
      'Search all indexers...',
    );
    expect(hint(<int>{1}), 'Search 1 indexer...');
    expect(hint(<int>{1, 5}), 'Search 2 indexers...');
    expect(
      hint(<int>{prowlarrAllTorrents, 5}),
      'Search all torrents and 1 indexer...',
    );
  });

  test('categories alone leave the hint at all indexers', () {
    expect(
      prowlarrSearchHint(
        const ProwlarrSearchFilter(categories: <int>{2000}),
      ),
      'Search all indexers...',
    );
  });

  test('filters with the same sets are equal', () {
    expect(
      const ProwlarrSearchFilter(indexerIds: <int>{1, 2}),
      const ProwlarrSearchFilter(indexerIds: <int>{2, 1}),
    );
    expect(
      const ProwlarrSearchFilter(indexerIds: <int>{1}) ==
          const ProwlarrSearchFilter(),
      isFalse,
    );
  });

  test('count is indexers plus categories', () {
    expect(
      const ProwlarrSearchFilter(
        indexerIds: <int>{prowlarrAllTorrents},
        categories: <int>{2000, 5040},
      ).count,
      3,
    );
  });
}
