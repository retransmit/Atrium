import '../generated/generated.dart';
import '../models/ombi_mapping.dart';
import '../models/ombi_models.dart';
import 'ombi_result.dart';

/// Ombi's requests: listing, approving, denying, deleting and making them.
class OmbiRequestService {
  OmbiRequestService(this._v1, this._v2, this._music, this._lidarr);

  final RawRequestApi _v1;
  final RawRequestsApi _v2;
  final RawMusicRequestApi _music;
  final RawLidarrApi _lidarr;

  static const int pageSize = 25;
  static const String _sort = 'requestedDate';
  static const String _order = 'desc';

  /// Retrieves details for a specific movie request by ID.
  Future<MovieRequests?> getMovieRequestInfo(String requestId) async {
    final ApiResponse<MovieRequests> response =
        await _v1.getRequestMovieInfoByRequestId(requestId: requestId);
    if (response.isSuccess) {
      return response.data;
    }
    throw OmbiException(
      response.error?.message ?? 'Movie request info failed',
      statusCode: response.statusCode,
      error: response.error,
    );
  }

  /// One page of [kind] requests matching [filter], newest first.
  Future<OmbiRequestPage> list(
    OmbiMediaKind kind,
    OmbiRequestFilter filter, {
    int page = 0,
  }) async {
    const String count = '$pageSize';
    final String position = '${page * pageSize}';
    switch (kind) {
      case OmbiMediaKind.movie:
        final UIRequestsViewModelMovieRequests data = requireData(
          await switch (filter) {
            OmbiRequestFilter.all =>
              _v2.getRequestsMovieByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.pending =>
              _v2.getRequestsMoviePendingByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.processing =>
              _v2.getRequestsMovieProcessingByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.available =>
              _v2.getRequestsMovieAvailableByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.denied =>
              _v2.getRequestsMovieDeniedByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
          },
          'Loading movie requests',
        );
        return OmbiRequestPage(
          items: <OmbiRequest>[
            for (final MovieRequests m
                in data.collection ?? const <MovieRequests>[])
              ombiRequestFromMovie(m),
          ],
          total: data.total ?? 0,
        );
      case OmbiMediaKind.tv:
        final UIRequestsViewModelChildRequests data = requireData(
          await switch (filter) {
            OmbiRequestFilter.all =>
              _v2.getRequestsTvByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.pending =>
              _v2.getRequestsTvPendingByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.processing =>
              _v2.getRequestsTvProcessingByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.available =>
              _v2.getRequestsTvAvailableByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.denied =>
              _v2.getRequestsTvDeniedByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
          },
          'Loading TV requests',
        );
        return OmbiRequestPage(
          items: <OmbiRequest>[
            for (final ChildRequests c
                in data.collection ?? const <ChildRequests>[])
              ombiRequestFromChild(c),
          ],
          total: data.total ?? 0,
        );
      case OmbiMediaKind.music:
        final UIRequestsViewModelAlbumRequest data = requireData(
          await switch (filter) {
            OmbiRequestFilter.all =>
              _v2.getRequestsAlbumByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.pending =>
              _v2.getRequestsAlbumPendingByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.processing =>
              _v2.getRequestsAlbumProcessingByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.available =>
              _v2.getRequestsAlbumAvailableByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
            OmbiRequestFilter.denied =>
              _v2.getRequestsAlbumDeniedByCountPositionSortSortOrder(
                count: count,
                position: position,
                sort: _sort,
                sortOrder: _order,
              ),
          },
          'Loading music requests',
        );
        return OmbiRequestPage(
          items: <OmbiRequest>[
            for (final AlbumRequest a
                in data.collection ?? const <AlbumRequest>[])
              ombiRequestFromAlbum(a),
          ],
          total: data.total ?? 0,
        );
    }
  }

  /// The newest movie and TV requests together, for the dashboard.
  Future<List<OmbiRequest>> recent({int take = 10}) async {
    final List<OmbiRequestPage> pages = await Future.wait(
      <Future<OmbiRequestPage>>[
        list(OmbiMediaKind.movie, OmbiRequestFilter.all),
        list(OmbiMediaKind.tv, OmbiRequestFilter.all),
      ],
    );
    final List<OmbiRequest> all = <OmbiRequest>[
      for (final OmbiRequestPage p in pages) ...p.items,
    ]..sort(
        (OmbiRequest a, OmbiRequest b) => (b.requestedAt ?? DateTime(1970))
            .compareTo(a.requestedAt ?? DateTime(1970)),
      );
    return all.take(take).toList();
  }

  Future<void> approve(OmbiMediaKind kind, int id) async {
    requireDone(
      await switch (kind) {
        OmbiMediaKind.movie => _v1.postRequestMovieApprove(
            body: <String, dynamic>{'id': id, 'is4K': false},
          ),
        OmbiMediaKind.tv =>
          _v1.postRequestTvApprove(body: <String, dynamic>{'id': id}),
        OmbiMediaKind.music =>
          _music.postRequestMusicApprove(body: <String, dynamic>{'id': id}),
      },
      'Approving',
    );
  }

  Future<void> deny(OmbiMediaKind kind, int id, {String reason = ''}) async {
    requireDone(
      await switch (kind) {
        OmbiMediaKind.movie => _v1.putRequestMovieDeny(
            body: <String, dynamic>{'id': id, 'reason': reason, 'is4K': false},
          ),
        OmbiMediaKind.tv => _v1.putRequestTvDeny(
            body: <String, dynamic>{'id': id, 'reason': reason},
          ),
        OmbiMediaKind.music => _music.putRequestMusicDeny(
            body: <String, dynamic>{'id': id, 'reason': reason},
          ),
      },
      'Denying',
    );
  }

  /// Removes the request from Ombi. Anything Sonarr, Radarr or Lidarr has
  /// already grabbed stays where it is.
  Future<void> delete(OmbiMediaKind kind, int id) async {
    final String requestId = '$id';
    requireDone(
      await switch (kind) {
        OmbiMediaKind.movie =>
          _v1.deleteRequestMovieByRequestId(requestId: requestId),
        OmbiMediaKind.tv =>
          _v1.deleteRequestTvChildByRequestId(requestId: requestId),
        OmbiMediaKind.music =>
          _music.deleteRequestMusicByRequestId(requestId: requestId),
      },
      'Deleting',
    );
  }

  Future<OmbiCounts> counts() async => ombiCountsFrom(
        requireData(await _v1.getRequestCount(), 'Loading request counts'),
      );

  /// Whether Ombi has Lidarr set up, which is what decides whether it takes
  /// music requests at all.
  Future<bool> musicEnabled() async =>
      requireData<dynamic>(
        await _lidarr.getLidarrEnabled(),
        'Checking music',
      ) ==
      true;

  Future<void> requestMovie(int tmdbId) async {
    requireDone(
      await _v1.postRequestMovie(
        body: <String, dynamic>{'theMovieDbId': tmdbId, 'is4kRequest': false},
      ),
      'Requesting',
    );
  }

  /// Requests a show by its TMDB id. This is the v2 route: v1 takes a TVDB
  /// id, and search hands back TMDB ones.
  Future<void> requestTv(int tmdbId, OmbiTvSeasons seasons) async {
    requireDone(
      await _v2.postRequestsTv(
        body: <String, dynamic>{
          'theMovieDbId': tmdbId,
          'requestAll': seasons == OmbiTvSeasons.all,
          'firstSeason': seasons == OmbiTvSeasons.first,
          'latestSeason': seasons == OmbiTvSeasons.latest,
        },
      ),
      'Requesting',
    );
  }
}
