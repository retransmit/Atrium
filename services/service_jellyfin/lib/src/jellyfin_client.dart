import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'models/jellyfin_auth.dart';
import 'models/jellyfin_item.dart';
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
  }) : _dio = dio;

  final Dio _dio;
  final Uri baseUrl;
  final String username;
  final String password;

  /// Stable per-instance device id, so Jellyfin tracks one session per
  /// configured instance rather than spawning a new one each launch.
  final String deviceId;

  String? _token;
  String? _userId;
  bool _loggedIn = false;

  String? get userId => _userId;

  static JellyfinClient create({
    required Uri baseUrl,
    required String username,
    required String password,
    required String deviceId,
    required bool allowSelfSigned,
  }) {
    final String baseUrlStr = baseUrl.toString();
    final String normalizedBaseUrl = baseUrlStr.endsWith('/') ? baseUrlStr : '$baseUrlStr/';
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
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
    );
  }

  String _authHeader() {
    const String client = 'Atrium';
    const String version = '0.1.0';
    final String base = 'MediaBrowser Client="$client", Device="$client", '
        'DeviceId="$deviceId", Version="$version"';
    return _token == null ? base : '$base, Token="$_token"';
  }

  Future<void> login() async {
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
                (dynamic e) => JellyfinView.fromJson(e as Map<String, dynamic>),)
            .toList();
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

  Future<List<JellyfinItem>> getWatchedItems({int startIndex = 0, int limit = 200}) => _guarded(() async {
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
        final items = JellyfinItemsResult.fromJson(resp.data as Map<String, dynamic>).items;
        // Nuclear option: Bypass broken Jellyfin API filters and filter 100% locally
        return items.where((item) => item.userData?.played == true).take(limit).toList();
      });

  Future<List<JellyfinItem>> getUnwatchedItems({int startIndex = 0, int limit = 200}) => _guarded(() async {
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
        final items = JellyfinItemsResult.fromJson(resp.data as Map<String, dynamic>).items;
        // Nuclear option: Bypass broken Jellyfin API filters and filter 100% locally
        return items.where((item) => item.userData?.played != true).take(limit).toList();
      });

  Future<void> markAsWatched(String itemId) => _guarded(() async {
        await _dio.post<dynamic>('Users/$_userId/PlayedItems/$itemId');
      });

  Future<void> markAsUnwatched(String itemId) => _guarded(() async {
        await _dio.delete<dynamic>('Users/$_userId/PlayedItems/$itemId');
      });

  Future<List<ActiveSession>> getSessions() => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>('Sessions');
        final List<dynamic> list = resp.data as List<dynamic>;

        final List<ActiveSession> active = <ActiveSession>[];
        for (final dynamic element in list) {
          if (element is! Map<String, dynamic>) continue;
          
          if (element['NowPlayingItem'] == null) continue;
          final Map<String, dynamic> nowPlaying = element['NowPlayingItem'] as Map<String, dynamic>;
          final Map<String, dynamic> playState = element['PlayState'] as Map<String, dynamic>;

          final int posTicks = playState['PositionTicks'] as int? ?? 0;
          final int posSec = posTicks ~/ 10000000;
          
          final int durTicks = nowPlaying['RunTimeTicks'] as int? ?? 0;
          final int durSec = durTicks ~/ 10000000;
          
          String formatTime(int sec) {
            final int h = sec ~/ 3600;
            final int m = (sec % 3600) ~/ 60;
            final int s = sec % 60;
            return '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
          }
          
          active.add(ActiveSession(
            user: element['UserName'] as String? ?? 'Unknown',
            device: element['Client'] as String? ?? 'Unknown',
            status: playState['IsPaused'] == true ? 'Paused' : 'Playing',
            showTitle: nowPlaying['SeriesName'] as String? ?? nowPlaying['Name'] as String? ?? 'Unknown',
            episodeName: nowPlaying['Name'] as String?,
            progressPercent: durTicks > 0 ? ((posTicks / durTicks) * 100).toInt() : 0,
            timePosition: formatTime(posSec),
            timeDuration: formatTime(durSec),
            posterUrl: '$_baseStr/Items/${nowPlaying['SeriesId'] ?? nowPlaying['Id']}/Images/Primary?quality=90&maxHeight=400${_token == null ? '' : '&api_key=$_token'}',
          ),);
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

        final List<Response<dynamic>> responses = await Future.wait([resumeFuture, nextUpFuture]);

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

  Future<JellyfinUserData> markFavorite(String itemId, bool isFavorite) => _guarded(() async {
        final Response<dynamic> resp = isFavorite 
            ? await _dio.post<dynamic>('Users/$_userId/FavoriteItems/$itemId')
            : await _dio.delete<dynamic>('Users/$_userId/FavoriteItems/$itemId');
            
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
            .map((dynamic e) => JellyfinItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<JellyfinItem> getItemDetails(String itemId) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Users/$_userId/Items/$itemId',
          queryParameters: <String, dynamic>{
            'Fields': 'Overview,People,CommunityRating,OfficialRating,RunTimeTicks',
          },
        );
        return JellyfinItem.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<List<JellyfinItem>> getSeasons(String seriesId) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          'Shows/$seriesId/Seasons',
          queryParameters: <String, dynamic>{
            'UserId': _userId,
            'Fields': 'PrimaryImageAspectRatio,Overview',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  Future<List<JellyfinItem>> getAllEpisodesForSeries(String seriesId) => _guarded(() async {
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
          'Shows/$seriesId/Episodes',
          queryParameters: <String, dynamic>{
            'SeasonId': seasonId,
            'UserId': _userId,
            'Fields': 'PrimaryImageAspectRatio,Overview,RunTimeTicks,CommunityRating,ImageTags',
            'ImageTypeLimit': 1,
            'EnableImageTypes': 'Primary',
          },
        );
        return JellyfinItemsResult.fromJson(
          resp.data as Map<String, dynamic>,
        ).items;
      });

  String get _baseStr => baseUrl.toString().replaceAll(RegExp(r'/+$'), '');

  /// Builds a primary-image (poster) URL for [item], or null if it has none.
  /// The image tag acts as a capability token; we also append `api_key` for
  /// servers configured to require auth on image endpoints.
  String? imageUrl(JellyfinItem item, {int maxHeight = 420}) {
    final String key = _token == null ? '' : '&api_key=$_token';

    // Prefer the Series poster (anime cover) over the episode thumbnail.
    if (item.type == 'Episode' && item.seriesId != null) {
      final String tagParam = item.seriesPrimaryImageTag != null
          ? '&tag=${item.seriesPrimaryImageTag}'
          : '';
      return '$_baseStr/Items/${item.seriesId}/Images/Primary'
          '?quality=90&maxHeight=$maxHeight$tagParam$key';
    }

    if (item.imageTags.containsKey('Primary')) {
      final String tag = item.imageTags['Primary']!;
      return '$_baseStr/Items/${item.id}/Images/Primary'
          '?tag=$tag&quality=90&maxHeight=$maxHeight$key';
    }

    if (item.seriesPrimaryImageTag != null && item.seriesId != null) {
      final String tag = item.seriesPrimaryImageTag!;
      return '$_baseStr/Items/${item.seriesId}/Images/Primary'
          '?tag=$tag&quality=90&maxHeight=$maxHeight$key';
    }

    if (item.parentPrimaryImageTag != null && item.parentId != null) {
      final String tag = item.parentPrimaryImageTag!;
      return '$_baseStr/Items/${item.parentId}/Images/Primary'
          '?tag=$tag&quality=90&maxHeight=$maxHeight$key';
    }

    return null;
  }

  /// Builds a backdrop image URL for [item], or null if it has none.
  String? backdropImageUrl(JellyfinItem item, {int maxWidth = 1920}) {
    final String key = _token == null ? '' : '&api_key=$_token';
    
    String targetId = item.id;
    String tagParam = '';
    
    if (item.imageTags.containsKey('Backdrop')) {
      tagParam = '&tag=${item.imageTags['Backdrop']}';
    } else if (item.seriesId != null) {
      // Fallback to series backdrop for episodes
      targetId = item.seriesId!;
    }
    
    return '$_baseStr/Items/$targetId/Images/Backdrop/0?quality=90&maxWidth=$maxWidth$tagParam$key';
  }

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
}


