import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'models/jellyfin_auth.dart';
import 'models/jellyfin_item.dart';
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

  static JellyfinClient create({
    required Uri baseUrl,
    required String username,
    required String password,
    required String deviceId,
    required bool allowSelfSigned,
  }) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.toString(),
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
    final String base =
        'MediaBrowser Client="$client", Device="$client", '
        'DeviceId="$deviceId", Version="$version"';
    return _token == null ? base : '$base, Token="$_token"';
  }

  Future<void> login() async {
    try {
      _dio.options.headers['Authorization'] = _authHeader();
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '/Users/AuthenticateByName',
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
            await _dio.get<dynamic>('/Users/$_userId/Views');
        final Map<String, dynamic> map = resp.data as Map<String, dynamic>;
        final List<dynamic> items =
            (map['Items'] as List<dynamic>?) ?? <dynamic>[];
        return items
            .map((dynamic e) => JellyfinView.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<JellyfinItem>> getItems(String parentId) => _guarded(() async {
        final Response<dynamic> resp = await _dio.get<dynamic>(
          '/Users/$_userId/Items',
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

  String get _baseStr =>
      baseUrl.toString().replaceAll(RegExp(r'/+$'), '');

  /// Absolute direct-play stream URL for a video item.
  ///
  /// `static=true` serves the original file without transcoding - media_kit
  /// (libmpv) decodes it locally, which is the whole reason we use libmpv over
  /// the platform player. Auth rides as `api_key` because media_kit fetches
  /// the bytes outside our Dio.
  String streamUrl(String itemId) {
    return '$_baseStr/Videos/$itemId/stream'
        '?static=true&mediaSourceId=$itemId'
        '&deviceId=$deviceId&api_key=$_token';
  }

  /// Jellyfin counts time in 100-nanosecond ticks (1s = 10,000,000 ticks).
  static int _ticks(Duration d) => d.inMicroseconds * 10;

  /// Marks an item as now-playing. Fire-and-forget - a failed report must
  /// never interrupt playback.
  Future<void> reportPlaybackStart(
    String itemId, {
    Duration position = Duration.zero,
  }) =>
      _postQuietly('/Sessions/Playing', <String, dynamic>{
        'ItemId': itemId,
        'PositionTicks': _ticks(position),
        'PlayMethod': 'DirectStream',
        'CanSeek': true,
      });

  /// Persists the current resume point.
  Future<void> reportPlaybackProgress(
    String itemId, {
    required Duration position,
    required bool isPaused,
  }) =>
      _postQuietly('/Sessions/Playing/Progress', <String, dynamic>{
        'ItemId': itemId,
        'PositionTicks': _ticks(position),
        'IsPaused': isPaused,
        'PlayMethod': 'DirectStream',
        'CanSeek': true,
      });

  /// Marks playback stopped and stores the final resume point.
  Future<void> reportPlaybackStopped(
    String itemId, {
    required Duration position,
  }) =>
      _postQuietly('/Sessions/Playing/Stopped', <String, dynamic>{
        'ItemId': itemId,
        'PositionTicks': _ticks(position),
      });

  Future<void> _postQuietly(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(path, data: body);
    } on DioException {
      // Reporting is best-effort; ignore failures.
    }
  }

  /// Builds a primary-image (poster) URL for [item], or null if it has none.
  /// The image tag acts as a capability token; we also append `api_key` for
  /// servers configured to require auth on image endpoints.
  String? imageUrl(JellyfinItem item, {int maxHeight = 420}) {
    final String? tag = item.imageTags['Primary'];
    if (tag == null) {
      return null;
    }
    final String b = baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    final String key = _token == null ? '' : '&api_key=$_token';
    return '$b/Items/${item.id}/Images/Primary'
        '?tag=$tag&quality=90&maxHeight=$maxHeight$key';
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
