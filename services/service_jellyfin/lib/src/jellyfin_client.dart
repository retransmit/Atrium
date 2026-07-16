import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'models/jellyfin_auth.dart';
import 'models/jellyfin_item.dart';
import 'models/jellyfin_remote_image.dart';
import 'models/jellyfin_remote_search.dart';
import 'models/jellyfin_session.dart';
import 'models/jellyfin_view.dart';

/// Client for the Jellyfin REST API.
///
/// Auth flow (token-session, like Emby): POST username/password to
/// `/Users/AuthenticateByName` with a `MediaBrowser` Authorization header.
/// The response carries an `AccessToken` and the `User.Id`; both are needed
/// for subsequent calls - the token goes back in the Authorization header,
/// the user id is part of most paths (`/Users/{id}/…`). We re-login once on a
/// 401 (expired token).
class JellyfinClient {
  JellyfinClient({
    required Dio dio,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.deviceId,
    this.getLocalOverride,
    this.setLocalOverride,
  }) : _dio = dio;

  final Dio _dio;
  final Uri baseUrl;
  final String username;
  final String password;

  /// Stable per-instance device id, so Jellyfin tracks one session per
  /// configured instance rather than spawning a new one each launch.
  final String deviceId;

  final String? Function(String itemId, String imageType)? getLocalOverride;
  final void Function(String itemId, String imageType, String tag)?
      setLocalOverride;

  String? _token;
  String? _userId;
  String? _serverId;
  bool _loggedIn = false;

  String? get userId => _userId;
  String? get serverId => _serverId;

  static JellyfinClient create({
    required Uri baseUrl,
    required String username,
    required String password,
    required String deviceId,
    required bool allowSelfSigned,
    Map<String, String> customHeaders = const <String, String>{},
    String? Function(String itemId, String imageType)? getLocalOverride,
    void Function(String itemId, String imageType, String tag)?
        setLocalOverride,
  }) {
    final String baseUrlStr = baseUrl.toString();
    final String normalizedBaseUrl =
        baseUrlStr.endsWith('/') ? baseUrlStr : '$baseUrlStr/';
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    // User-configured headers (global + per-instance, already merged by the
    // caller). The auth flow's own headers are set per-request and win last.
    dio.options.headers.addAll(customHeaders);
    if (allowSelfSigned) {
      final IOHttpClientAdapter adapter =
          dio.httpClientAdapter as IOHttpClientAdapter;
      adapter.createHttpClient = () => HttpClient()
        ..badCertificateCallback =
            (X509Certificate _, String __, int ___) => true;
    }
    return JellyfinClient(
      dio: dio,
      baseUrl: baseUrl,
      username: username,
      password: password,
      deviceId: deviceId,
      getLocalOverride: getLocalOverride,
      setLocalOverride: setLocalOverride,
    );
  }

  String _authHeader() {
    const String client = 'Atrium';
    const String version = '0.1.0';
    final String base = 'MediaBrowser Client="$client", Device="$client", '
        'DeviceId="$deviceId", Version="$version"';
    return _token == null ? base : '$base, Token="$_token"';
  }

  Future<void>? _loginFuture;

  Future<void> login() =>
      _loginFuture ??= _performLogin().whenComplete(() => _loginFuture = null);

  Future<void> _performLogin() async {
    try {
      _dio.options.headers['Authorization'] = _authHeader();
      final Response<dynamic> resp = await _dio.post<dynamic>(
        'Users/AuthenticateByName',
        data: <String, dynamic>{'Username': username, 'Pw': password},
      );
      final JellyfinAuthResult result =
          JellyfinAuthResult.fromJson(resp.data as Map<String, dynamic>);
      _token = result.accessToken;
      _userId = result.user.id;
      _serverId = result.serverId;
      _dio.options.headers['Authorization'] = _authHeader();
      _loggedIn = true;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<JellyfinView>> getViews() => _guarded(() async {
        final Response<dynamic> resp =
            await _dio.get<dynamic>('Users/$_userId/Views');
        final Map<String, dynamic> map = resp.data as Map<String, dynamic>;
        final List<dynamic> items =
            (map['Items'] as List<dynamic>?) ?? <dynamic>[];
        return items
            .map(
              (dynamic e) => JellyfinView.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      });

  Future<List<JellyfinVirtualFolder>> getVirtualFolders() => _guarded(() async {
        final Response<dynamic> resp =
            await _dio.get<dynamic>('Library/VirtualFolders');
        final List<dynamic> items =
            (resp.data as List<dynamic>?) ?? <dynamic>[];
        return items
            .map(
              (dynamic e) =>
                  JellyfinVirtualFolder.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      });

  Future<List<JellyfinItem>> getLibraryItems(
    String parentId,
    String? collectionType,
  ) =>
      _guarded(() async {
        String? includeItemTypes;
        switch (collectionType) {
          case 'movies':
            includeItemTypes = 'Movie';
            break;
          case 'tvshows':
            includeItemTypes = 'Series';
            break;
          case 'music':
            includeItemTypes = 'MusicAlbum';
            break;
          default:
            includeItemTypes = 'Movie,Series,MusicAlbum'; // Fallback
            break;
        }

        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'ParentId': parentId,
            'Recursive': true,
            'IncludeItemTypes': includeItemTypes,
            'SortBy': 'SortName',
            'SortOrder': 'Ascending',
            'Fields':
                'PrimaryImageAspectRatio,ImageTags,Overview,CommunityRating,ParentId',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
            'Limit': 200,
          },
        );
        return JellyfinItemsResult.fromJson(resp.data as Map<String, dynamic>)
            .items;
      });

  Future<List<JellyfinItem>> getItems(String parentId) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'ParentId': parentId,
            'SortBy': 'SortName',
            'SortOrder': 'Ascending',
            'Fields': 'PrimaryImageAspectRatio',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
            'Limit': 200,
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> getWatchedItems({
    int startIndex = 0,
    int limit = 200,
  }) =>
      _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'Recursive': true,
            'IncludeItemTypes': 'Series,Movie',
            'SortBy': 'SortName',
            'SortOrder': 'Ascending',
            'Fields': 'PrimaryImageAspectRatio,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
            'StartIndex': startIndex,
            'Limit': 2000,
          },
        );
        final items =
            JellyfinItemsResult.fromJson(resp.data as Map<String, dynamic>)
                .items;
        // Nuclear option: Bypass broken Jellyfin API filters and filter 100% locally
        return items
            .where((item) => item.userData?.played == true)
            .take(limit)
            .toList();
      });

  Future<List<JellyfinItem>> getUnwatchedItems({
    int startIndex = 0,
    int limit = 200,
  }) =>
      _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'Recursive': true,
            'IncludeItemTypes': 'Series,Movie',
            'SortBy': 'SortName',
            'SortOrder': 'Ascending',
            'Fields': 'PrimaryImageAspectRatio,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
            'StartIndex': startIndex,
            'Limit': 2000,
          },
        );
        final items =
            JellyfinItemsResult.fromJson(resp.data as Map<String, dynamic>)
                .items;
        // Nuclear option: Bypass broken Jellyfin API filters and filter 100% locally
        return items
            .where((item) => item.userData?.played != true)
            .take(limit)
            .toList();
      });

  Future<void> markAsWatched(String itemId) => _guarded(() async {
        await _dio.post<dynamic>('Users/$_userId/PlayedItems/$itemId');
      });

  Future<void> markAsUnwatched(String itemId) => _guarded(() async {
        await _dio.delete<dynamic>('Users/$_userId/PlayedItems/$itemId');
      });

  Future<void> stopSession(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>('Sessions/$sessionId/Playing/Stop');
      });

  Future<void> pauseSession(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>('Sessions/$sessionId/Playing/Pause');
      });

  Future<void> unpauseSession(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>('Sessions/$sessionId/Playing/Unpause');
      });

  Future<void> playPauseSession(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>('Sessions/$sessionId/Playing/PlayPause');
      });

  Future<void> nextTrack(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>('Sessions/$sessionId/Playing/NextTrack');
      });

  Future<void> previousTrack(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>('Sessions/$sessionId/Playing/PreviousTrack');
      });

  Future<void> seekSession(String sessionId, int positionTicks) =>
      _guarded(() async {
        await _dio.post<dynamic>(
          'Sessions/$sessionId/Playing/Seek',
          queryParameters: <String, dynamic>{
            'SeekPositionTicks': positionTicks,
          },
        );
      });

  Future<void> setVolume(String sessionId, int volume) => _guarded(() async {
        await _dio.post<dynamic>(
          'Sessions/$sessionId/Command',
          data: <String, dynamic>{
            'Name': 'SetVolume',
            'Arguments': <String, String>{
              'Volume': volume.toString(),
            },
          },
        );
      });

  Future<void> toggleMute(String sessionId) => _guarded(() async {
        await _dio.post<dynamic>(
          'Sessions/$sessionId/Command',
          data: <String, dynamic>{
            'Name': 'ToggleMute',
          },
        );
      });

  Future<List<ActiveSession>> getSessions() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>('Sessions');
        final List<dynamic> list = resp.data as List<dynamic>;

        final List<ActiveSession> active = <ActiveSession>[];
        for (final dynamic element in list) {
          if (element is! Map<String, dynamic>) continue;
          if (element['NowPlayingItem'] == null) continue;
          final Map<String, dynamic> nowPlaying =
              element['NowPlayingItem'] as Map<String, dynamic>;
          final playState = element['PlayState'] as Map<String, dynamic>?;
          if (playState == null) continue;

          final int posTicks = playState['PositionTicks'] as int? ?? 0;
          final int durTicks = nowPlaying['RunTimeTicks'] as int? ?? 0;

          final int posSec = posTicks ~/ 10000000;
          final int durSec = durTicks ~/ 10000000;

          String formatTime(int sec) {
            final int h = sec ~/ 3600;
            final int m = (sec % 3600) ~/ 60;
            final int s = sec % 60;
            return '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
          }

          final List<dynamic>? artistsList =
              nowPlaying['Artists'] as List<dynamic>?;
          final String? artistName =
              artistsList != null && artistsList.isNotEmpty
                  ? artistsList.join(', ')
                  : null;

          final String type = nowPlaying['Type'] as String? ?? '';
          final double computedAspectRatio = type == 'Episode'
              ? (2 / 3)
              : ((nowPlaying['PrimaryImageAspectRatio'] as num?)?.toDouble() ??
                  (type == 'Audio' ||
                          type == 'MusicAlbum' ||
                          type == 'MusicArtist'
                      ? 1.0
                      : (2 / 3)));

          active.add(
            ActiveSession(
              id: element['Id'] as String? ?? '',
              user: element['UserName'] as String? ?? 'Unknown',
              device: element['Client'] as String? ?? 'Unknown',
              status: playState['IsPaused'] == true ? 'Paused' : 'Playing',
              showTitle: nowPlaying['Name'] as String? ?? 'Unknown',
              episodeName: type == 'Audio'
                  ? artistName
                  : nowPlaying['SeriesName'] as String?,
              progressPercent:
                  durTicks > 0 ? ((posTicks / durTicks) * 100).toInt() : 0,
              timePosition: formatTime(posSec),
              timeDuration: formatTime(durSec),
              positionTicks: posTicks,
              durationTicks: durTicks,
              volumeLevel: playState['VolumeLevel'] as int? ?? 100,
              isMuted: playState['IsMuted'] as bool? ?? false,
              posterUrl:
                  '$_baseStr/Items/${nowPlaying['SeriesId'] ?? nowPlaying['Id']}/Images/Primary?quality=100${_token == null ? '' : '&api_key=$_token'}',
              backdropUrl:
                  '$_baseStr/Items/${nowPlaying['SeriesId'] ?? nowPlaying['Id']}/Images/Backdrop/0?quality=100${_token == null ? '' : '&api_key=$_token'}',
              aspectRatio: computedAspectRatio,
              itemId: nowPlaying['SeriesId'] as String? ??
                  nowPlaying['Id'] as String?,
            ),
          );
        }
        return active;
      });

  Future<List<JellyfinItem>> getResumeItems() => _guarded(() async {
        // Jellyfin's Resume endpoint strictly returns in-progress items, unlike Emby
        // which mixes in-progress and NextUp episodes. To match Emby's behavior,
        // we fetch both and merge them.
        final Future<Response<dynamic>> resumeFuture = _dio.get<dynamic>(
          'UserItems/Resume',
          queryParameters: <String, dynamic>{
            'userId': _userId,
            'Limit': 24,
            'Fields': 'PrimaryImageAspectRatio,Overview,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );

        final Future<Response<dynamic>> nextUpFuture = _dio.get<dynamic>(
          'Shows/NextUp',
          queryParameters: <String, dynamic>{
            'UserId': _userId,
            'Limit': 24,
            'Fields': 'PrimaryImageAspectRatio,Overview,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );

        final List<Response<dynamic>> responses =
            await Future.wait([resumeFuture, nextUpFuture]);

        final List<JellyfinItem> resumeItems = JellyfinItemsResult.fromJson(
          responses[0].data as Map<String, dynamic>,
        ).items;

        final List<JellyfinItem> nextUpItems = JellyfinItemsResult.fromJson(
          responses[1].data as Map<String, dynamic>,
        ).items;

        // Merge and remove duplicates by ID
        final Map<String, JellyfinItem> merged = <String, JellyfinItem>{};
        for (final item in [...resumeItems, ...nextUpItems]) {
          merged[item.id] = item;
        }

        return merged.values.toList();
      });

  Future<List<JellyfinItem>> getNextUp() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Shows/NextUp',
          queryParameters: <String, dynamic>{
            'UserId': _userId,
            'Limit': 24,
            'Fields': 'PrimaryImageAspectRatio,Overview,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> searchItems(String query) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'SearchTerm': query,
            'Limit': 50,
            'Recursive': true,
            'IncludeItemTypes': 'Series,Movie,Episode',
            'Fields': 'PrimaryImageAspectRatio,Overview',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> getFavorites() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'Filters': 'IsFavorite',
            'Recursive': true,
            'Limit': 24,
            'Fields': 'PrimaryImageAspectRatio,Overview,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<JellyfinUserData> markFavorite(String itemId, bool isFavorite) =>
      _guarded(() async {
        final Response<dynamic> resp = isFavorite
            ? await _dio.post<dynamic>('Users/$_userId/FavoriteItems/$itemId')
            : await _dio
                .delete<dynamic>('Users/$_userId/FavoriteItems/$itemId');

        return JellyfinUserData.fromJson(
          resp.data as Map<String, dynamic>,
        );
      });

  Future<List<JellyfinItem>> getLatestItems() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items/Latest',
          queryParameters: <String, dynamic>{
            'Limit': 20,
            'Fields': 'PrimaryImageAspectRatio,Overview',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        final List<dynamic> list = resp.data as List<dynamic>;
        return list
            .map(
              (dynamic e) => JellyfinItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      });

  Future<JellyfinItem> getItemDetails(String itemId) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items/$itemId',
          queryParameters: <String, dynamic>{
            'Fields':
                'Overview,People,CommunityRating,OfficialRating,RunTimeTicks,ImageTags,BackdropImageTags',
          },
        );
        return JellyfinItem.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<List<JellyfinItem>> getSeasons(String seriesId) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'ParentId': seriesId,
            'IncludeItemTypes': 'Season',
            'Fields': 'PrimaryImageAspectRatio,Overview,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> getAllEpisodesForSeries(String seriesId) =>
      _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'ParentId': seriesId,
            'Recursive': true,
            'IncludeItemTypes': 'Episode',
            'Fields': 'PrimaryImageAspectRatio,Overview',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> getEpisodes(String seriesId, String seasonId) =>
      _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'ParentId': seasonId,
            'IncludeItemTypes': 'Episode',
            'Fields':
                'PrimaryImageAspectRatio,Overview,RunTimeTicks,CommunityRating,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> getAlbumSongs(String albumId) =>
      _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'ParentId': albumId,
            'Fields':
                'PrimaryImageAspectRatio,ImageTags,Overview,ParentId,ProductionYear',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<JellyfinItem?> getArtistBio(String artistName) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items',
          queryParameters: <String, dynamic>{
            'Recursive': true,
            'IncludeItemTypes': 'MusicArtist',
            'SearchTerm': artistName,
            'Fields': 'Overview',
          },
        );
        final items = JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
        return items.isNotEmpty ? items.first : null;
      });

  String get _baseStr => baseUrl.toString().replaceAll(RegExp(r'/+$'), '');

  /// Builds a primary-image (poster) URL for [item], or null if it has none.
  String? imageUrl(JellyfinItem item, {int maxHeight = 420}) {
    final String key = _token == null ? '' : '&api_key=$_token';

    // Prefer the Series poster (anime cover) over the episode thumbnail.
    if (item.type == 'Episode' && item.seriesId != null) {
      final String tagParam = item.seriesPrimaryImageTag != null
          ? '&tag=${item.seriesPrimaryImageTag}'
          : '';
      return '$_baseStr/Items/${item.seriesId}/Images/Primary'
          '?quality=100$tagParam$key';
    }

    if (item.type == 'Audio') {
      if (item.albumPrimaryImageTag != null && item.albumId != null) {
        return '$_baseStr/Items/${item.albumId}/Images/Primary'
            '?quality=100&tag=${item.albumPrimaryImageTag}$key';
      }
      if (item.parentPrimaryImageTag != null && item.parentId != null) {
        return '$_baseStr/Items/${item.parentId}/Images/Primary'
            '?quality=100&tag=${item.parentPrimaryImageTag}$key';
      }
      if (item.imageTags.containsKey('Primary')) {
        return '$_baseStr/Items/${item.id}/Images/Primary'
            '?quality=100&tag=${item.imageTags['Primary']}$key';
      }
      final String targetId = item.albumId ?? item.parentId ?? item.id;
      return '$_baseStr/Items/$targetId/Images/Primary'
          '?quality=100$key';
    }

    if (item.primaryImageItemId != null) {
      final String tagParam =
          item.primaryImageTag != null ? '&tag=${item.primaryImageTag}' : '';
      return '$_baseStr/Items/${item.primaryImageItemId}/Images/Primary'
          '?quality=100$tagParam$key';
    }

    if (item.imageTags.containsKey('Primary')) {
      final String tag = item.imageTags['Primary']!;
      return '$_baseStr/Items/${item.id}/Images/Primary'
          '?tag=$tag&quality=100$key';
    }

    if (item.seriesPrimaryImageTag != null && item.seriesId != null) {
      final String tag = item.seriesPrimaryImageTag!;
      return '$_baseStr/Items/${item.seriesId}/Images/Primary'
          '?tag=$tag&quality=100$key';
    }

    if (item.parentPrimaryImageTag != null && item.parentId != null) {
      final String tag = item.parentPrimaryImageTag!;
      return '$_baseStr/Items/${item.parentId}/Images/Primary'
          '?tag=$tag&quality=100$key';
    }

    // Fallback: If no tags were provided in the payload, try fetching the primary image directly.
    return '$_baseStr/Items/${item.id}/Images/Primary'
        '?quality=100$key';
  }

  /// Builds a banner image URL for [item], or null if it has none.
  String? bannerImageUrl(JellyfinItem item, {int maxWidth = 1920}) {
    final String key = _token == null ? '' : '&api_key=$_token';

    if (item.imageTags.containsKey('Banner')) {
      return '$_baseStr/Items/${item.id}/Images/Banner/0?quality=100&tag=${item.imageTags['Banner']}$key';
    } else if (item.seriesId != null && item.seriesPrimaryImageTag != null) {
      // Sometimes series have banners under their own ID
      return '$_baseStr/Items/${item.seriesId}/Images/Banner/0?quality=100$key';
    }

    return null;
  }

  /// Builds an optimal wide image URL (banner or backdrop) for [item].
  /// Falls back to poster. For music items, exclusively returns the poster.
  String? bannerOrPosterUrl(JellyfinItem item, {int maxWidth = 1920}) {
    if (item.type == 'MusicAlbum' ||
        item.type == 'MusicArtist' ||
        item.type == 'Audio') {
      return imageUrl(item);
    }
    return bannerImageUrl(item, maxWidth: maxWidth) ??
        backdropImageUrl(item, maxWidth: maxWidth) ??
        imageUrl(item);
  }

  /// Builds a backdrop image URL for [item], or null if it has none.
  String? backdropImageUrl(JellyfinItem item, {int maxWidth = 1920}) {
    final String key = _token == null ? '' : '&api_key=$_token';

    String targetId = item.id;
    String tagParam = '';
    int targetIndex = 0;

    if (item.seriesId != null &&
        item.backdropImageTags.isEmpty &&
        !item.imageTags.containsKey('Backdrop')) {
      targetId = item.seriesId!;
    }

    final String? overrideTag = getLocalOverride?.call(targetId, 'Backdrop');
    if (overrideTag != null && overrideTag.isNotEmpty) {
      final int foundIndex = item.backdropImageTags.indexOf(overrideTag);
      if (foundIndex != -1) {
        targetIndex = foundIndex;
        tagParam = '&tag=$overrideTag';
      }
    }

    if (targetIndex == 0) {
      if (item.backdropImageTags.isNotEmpty) {
        tagParam = '&tag=${item.backdropImageTags.first}';
      } else if (item.imageTags.containsKey('Backdrop')) {
        tagParam = '&tag=${item.imageTags['Backdrop']}';
      } else if (targetId == item.id) {
        // If the item has no backdrop tags and we aren't falling back to the series, it doesn't have a backdrop.
        return null;
      }
    }

    return '$_baseStr/Items/$targetId/Images/Backdrop/$targetIndex?quality=100$tagParam$key';
  }

  String untaggedImageUrl(String itemId, String imageType) {
    final String targetType =
        imageType == 'Backdrop' ? 'Backdrop/0' : imageType;
    final String key = _token == null ? '' : '&api_key=$_token';
    return '$_baseStr/Items/$itemId/Images/$targetType?quality=100$key';
  }

  Future<List<JellyfinRemoteImage>> getRemoteImages(
    String itemId,
    String imageType,
  ) =>
      _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Items/$itemId/RemoteImages',
          queryParameters: <String, dynamic>{
            'Type': imageType,
            'IncludeAllLanguages': 'true',
          },
        );
        return JellyfinRemoteImagesResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).images;
      });

  Future<void> setRemoteImage(
    String itemId,
    String imageUrl,
    String imageType,
  ) =>
      _guarded(() async {
        List<String> oldBackdrops = <String>[];
        if (imageType == 'Backdrop') {
          try {
            final item = await getItemDetails(itemId);
            oldBackdrops = item.backdropImageTags;
          } catch (_) {}
        }

        await _dio.post<dynamic>(
          'Items/$itemId/RemoteImages/Download',
          queryParameters: <String, dynamic>{
            'Type': imageType,
            'ImageUrl': imageUrl,
          },
        );

        if (imageType == 'Backdrop') {
          final newItem = await getItemDetails(itemId);
          final newBackdrops = newItem.backdropImageTags;

          int indexToMove = -1;
          for (int i = 0; i < newBackdrops.length; i++) {
            if (!oldBackdrops.contains(newBackdrops[i])) {
              indexToMove = i;
              break;
            }
          }

          if (indexToMove != -1 && indexToMove > 0) {
            try {
              await _dio.post<dynamic>(
                'Items/$itemId/Images/Backdrop/$indexToMove/Index',
                queryParameters: <String, dynamic>{
                  'newIndex': 0,
                },
              );
              // Cleared successfully on server, remove any local override.
              setLocalOverride?.call(itemId, 'Backdrop', '');
            } catch (e) {
              if (e is DioException && e.response?.statusCode == 500) {
                // Fallback: save the tag locally.
                final String localTag = newBackdrops[indexToMove];
                setLocalOverride?.call(itemId, 'Backdrop', localTag);
              } else {
                rethrow;
              }
            }
          }
        }
      });

  Future<void> startLibraryScan() => _guarded(() async {
        await _dio.post<dynamic>('Library/Refresh');
      });

  Future<({String state, double progress})?> getLibraryScanProgress() =>
      _guarded(() async {
        final Response<dynamic> resp =
            await _dio.get<dynamic>('ScheduledTasks');
        final List<dynamic> tasks =
            (resp.data as List<dynamic>?) ?? <dynamic>[];
        for (final dynamic t in tasks) {
          final Map<String, dynamic> task = t as Map<String, dynamic>;
          if (task['Key'] == 'RefreshLibrary') {
            return (
              state: (task['State'] as String?) ?? 'Idle',
              progress:
                  (task['CurrentProgressPercentage'] as num?)?.toDouble() ??
                      0.0,
            );
          }
        }
        return null;
      });

  Future<List<JellyfinUser>> getUsers() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>('Users');
        List<dynamic> users = <dynamic>[];
        if (resp.data is List) {
          users = resp.data as List<dynamic>;
        } else if (resp.data is Map<String, dynamic>) {
          final Map<String, dynamic> map = resp.data as Map<String, dynamic>;
          if (map['Items'] != null) {
            users = map['Items'] as List<dynamic>;
          }
        }
        return users
            .map(
              (dynamic u) => JellyfinUser.fromJson(u as Map<String, dynamic>),
            )
            .toList();
      });

  Future<List<JellyfinUser>> getPublicUsers() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('Users/Public');
      List<dynamic> users = <dynamic>[];
      if (resp.data is List) {
        users = resp.data as List<dynamic>;
      } else if (resp.data is Map<String, dynamic>) {
        final Map<String, dynamic> map = resp.data as Map<String, dynamic>;
        if (map['Items'] != null) {
          users = map['Items'] as List<dynamic>;
        }
      }
      return users
          .map((dynamic u) => JellyfinUser.fromJson(u as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return <JellyfinUser>[];
    }
  }

  Future<JellyfinUser> getCurrentUser() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>('Users/Me');
        return JellyfinUser.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<JellyfinUser> getUser(String id) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>('Users/$id');
        return JellyfinUser.fromJson(resp.data as Map<String, dynamic>);
      });

  void close() => _dio.close(force: true);

  Future<T> _guarded<T>(Future<T> Function() call) async {
    if (!_loggedIn) {
      await login();
    }
    try {
      return await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _loggedIn = false;
        await login();
        try {
          return await call();
        } on DioException catch (e2) {
          throw NetworkException.fromDio(e2);
        }
      }
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<JellyfinRemoteSearchResult>> remoteSearch(
    String itemId,
    String type,
    JellyfinRemoteSearchInfo searchInfo,
  ) =>
      _guarded(() async {
        final Response<dynamic> res = await _dio.post<dynamic>(
          '/Items/RemoteSearch/$type',
          data: JellyfinRemoteSearchQuery(
            searchInfo: searchInfo,
            itemId: itemId,
          ).toJson(),
        );
        final List<dynamic> list = res.data as List<dynamic>;
        return list
            .map(
              (dynamic e) => JellyfinRemoteSearchResult.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
      });

  Future<void> applyRemoteSearch(
    String itemId,
    JellyfinRemoteSearchResult result, {
    bool replaceAllImages = true,
  }) =>
      _guarded(() async {
        await _dio.post<dynamic>(
          '/Items/RemoteSearch/Apply/$itemId?ReplaceAllImages=$replaceAllImages',
          data: result.toJson(),
        );
      });

  /// Queues a non-destructive metadata refresh. ReplaceAll* stays false so
  /// manual edits and custom images survive; the scan only fills gaps.
  Future<void> refreshMetadata(String itemId) => _guarded(() async {
        await _dio.post<dynamic>(
          '/Items/$itemId/Refresh',
          queryParameters: <String, dynamic>{
            'Recursive': true,
            'ImageRefreshMode': 'FullRefresh',
            'MetadataRefreshMode': 'FullRefresh',
            'ReplaceAllImages': false,
            'ReplaceAllMetadata': false,
          },
        );
      });
}
