import 'package:flutter/services.dart';
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

  test('hint names a typed search', () {
    expect(
      prowlarrSearchHint(
        const ProwlarrSearchFilter(type: ProwlarrSearchType.movie),
      ),
      'Movie search, all indexers...',
    );
    expect(
      prowlarrSearchHint(
        const ProwlarrSearchFilter(
          type: ProwlarrSearchType.tv,
          indexerIds: <int>{prowlarrAllTorrents},
        ),
      ),
      'TV search, all torrents...',
    );
    expect(
      prowlarrSearchHint(
        const ProwlarrSearchFilter(
          type: ProwlarrSearchType.book,
          indexerIds: <int>{1, 5},
        ),
      ),
      'Book search, 2 indexers...',
    );
  });

  test('a non-basic type counts once', () {
    expect(
      const ProwlarrSearchFilter(
        type: ProwlarrSearchType.movie,
        categories: <int>{2000},
      ).count,
      2,
    );
    expect(
      const ProwlarrSearchFilter(type: ProwlarrSearchType.movie).isEmpty,
      isFalse,
    );
  });

  test('type is part of equality', () {
    expect(
      const ProwlarrSearchFilter(type: ProwlarrSearchType.movie) ==
          const ProwlarrSearchFilter(),
      isFalse,
    );
  });

  test('tokens per type', () {
    expect(ProwlarrSearchType.basic.tokens, isEmpty);
    expect(ProwlarrSearchType.tv.tokens, <String>[
      'ImdbId',
      'TvdbId',
      'TmdbId',
      'TvMazeId',
      'Season',
      'Episode',
      'Year',
    ]);
    expect(
      ProwlarrSearchType.movie.tokens,
      <String>['ImdbId', 'TmdbId', 'TraktId', 'Year'],
    );
    expect(
      ProwlarrSearchType.audio.tokens,
      <String>['Artist', 'Album', 'Label', 'Year'],
    );
    expect(
      ProwlarrSearchType.book.tokens,
      <String>['Author', 'Title', 'Publisher', 'Year'],
    );
    expect(
      ProwlarrSearchType.values.map((ProwlarrSearchType t) => t.apiValue),
      <String>['search', 'tvsearch', 'movie', 'music', 'book'],
    );
  });

  test('insert appends with no selection', () {
    final TextEditingValue out =
        prowlarrInsertToken(const TextEditingValue(text: 'dune'), 'ImdbId');
    expect(out.text, 'dune{ImdbId:}');
    expect(out.selection, const TextSelection.collapsed(offset: 12));
  });

  test('insert replaces the selection', () {
    final TextEditingValue out = prowlarrInsertToken(
      const TextEditingValue(
        text: 'ab',
        selection: TextSelection(baseOffset: 1, extentOffset: 2),
      ),
      'Year',
    );
    expect(out.text, 'a{Year:}');
    expect(out.selection, const TextSelection.collapsed(offset: 7));
  });
}
