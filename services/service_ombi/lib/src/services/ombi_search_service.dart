import '../generated/generated.dart';
import '../models/ombi_mapping.dart';
import '../models/ombi_models.dart';
import 'ombi_result.dart';

/// Ombi's search, and whether a title found there can still be requested.
class OmbiSearchService {
  OmbiSearchService(this._rawSearchApi);

  final RawSearchApi _rawSearchApi;

  static const Map<String, dynamic> _moviesAndShows = <String, dynamic>{
    'movies': true,
    'tvShows': true,
    'music': false,
    'people': false,
  };

  /// Performs a multi-search across movies and TV shows.
  Future<List<MultiSearchResult>> searchMulti(String searchTerm) async =>
      requireData(
        await _rawSearchApi.postSearchMultiBySearchTerm(
          searchTerm: searchTerm,
        ),
        'Multi search',
      );

  /// Retrieves movie details by Movie DB ID.
  Future<MovieFullInfoViewModel?> getMovieInfo(String movieDbId) async =>
      requireData(
        await _rawSearchApi.getSearchMovieByMovieDbId(movieDbId: movieDbId),
        'Movie lookup',
      );

  /// Movies and shows matching [term]. People and music are left out:
  /// requests from search are movies and TV only.
  Future<List<OmbiSearchHit>> search(String term) async {
    final String q = term.trim();
    if (q.isEmpty) {
      return const <OmbiSearchHit>[];
    }
    final List<MultiSearchResult> results = requireData(
      await _rawSearchApi.postSearchMultiBySearchTerm(
        // The term is a path segment, so a slash or a question mark in it
        // must not split the route or start a query.
        searchTerm: Uri.encodeComponent(q),
        body: _moviesAndShows,
      ),
      'Searching',
    );
    return <OmbiSearchHit>[
      for (final MultiSearchResult r in results)
        if (ombiSearchHitFrom(r) case final OmbiSearchHit hit) hit,
    ];
  }

  /// One Discover row: the first [take] entries of one of Ombi's lists.
  Future<List<OmbiSearchHit>> discover(
    OmbiDiscoverRow row, {
    int take = 20,
  }) async {
    const String from = '0';
    final String count = '$take';
    switch (row) {
      case OmbiDiscoverRow.popularMovies:
      case OmbiDiscoverRow.upcomingMovies:
        final List<SearchMovieViewModel> movies = requireData(
          await (row == OmbiDiscoverRow.popularMovies
              ? _rawSearchApi
                  .getSearchMoviePopularByCurrentPositionAmountToLoad(
                  currentPosition: from,
                  amountToLoad: count,
                )
              : _rawSearchApi
                  .getSearchMovieUpcomingByCurrentPositionAmountToLoad(
                  currentPosition: from,
                  amountToLoad: count,
                )),
          'Loading movies',
        );
        return <OmbiSearchHit>[
          for (final SearchMovieViewModel m in movies)
            if (ombiSearchHitFromMovie(m) case final OmbiSearchHit hit) hit,
        ];
      case OmbiDiscoverRow.popularTv:
      case OmbiDiscoverRow.trendingTv:
        final List<SearchTvShowViewModel> shows = requireData(
          await (row == OmbiDiscoverRow.popularTv
              ? _rawSearchApi.getSearchTvPopularByCurrentPositionAmountToLoad(
                  currentPosition: from,
                  amountToLoad: count,
                )
              : _rawSearchApi.getSearchTvTrendingByCurrentPositionAmountToLoad(
                  currentPosition: from,
                  amountToLoad: count,
                )),
          'Loading shows',
        );
        return <OmbiSearchHit>[
          for (final SearchTvShowViewModel t in shows)
            if (ombiSearchHitFromShow(t) case final OmbiSearchHit hit) hit,
        ];
    }
  }

  /// Whether the title is requested, approved, available or denied.
  Future<OmbiTitleState> titleState(OmbiMediaKind kind, int tmdbId) async {
    final String id = '$tmdbId';
    switch (kind) {
      case OmbiMediaKind.movie:
        return ombiTitleStateFromMovie(
          requireData(
            await _rawSearchApi.getSearchMovieByMovieDbId(movieDbId: id),
            'Loading the movie',
          ),
        );
      case OmbiMediaKind.tv:
        return ombiTitleStateFromTv(
          requireData(
            await _rawSearchApi.getSearchTvMoviedbByMoviedbid(moviedbid: id),
            'Loading the show',
          ),
        );
      case OmbiMediaKind.music:
        return const OmbiTitleState();
    }
  }
}
