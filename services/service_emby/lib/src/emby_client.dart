import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'models/emby_auth.dart';
import 'models/emby_item.dart';
import 'models/emby_view.dart';

/// Client for the Emby REST API.
///
/// Emby's API is close to Jellyfin's, with two differences we handle here:
/// the request-identity header is `X-Emby-Authorization` (not `Authorization`)
/// and the session token rides in `X-Emby-Token` on subsequent calls. Auth
/// flow is otherwise the same: POST username/password to
/// `/Users/AuthenticateByName`, capture `AccessToken` + `User.Id`, re-login
/// once on a 401.
class EmbyClient {
  EmbyClient({
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
  final String deviceId;

  String? _token;
  String? _userId;
  bool _loggedIn = false;

  static EmbyClient create({
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
    return EmbyClient(
      dio: dio,
      baseUrl: baseUrl,
      username: username,
      password: password,
      deviceId: deviceId,
    );
  }

  String _identityHeader() {
    const String client = 'Atrium';
    const String version = '0.1.0';
    return 'MediaBrowser Client="$client", Device="$client", '
        'DeviceId="$deviceId", Version="$version"';
  }

  Future<void> login() async {
    try {
      _dio.options.headers['X-Emby-Authorization'] = _identityHeader();
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '/Users/AuthenticateByName',
        data: <String, dynamic>{'Username': username, 'Pw': password},
      );
      final EmbyAuthResult result =
          EmbyAuthResult.fromJson(resp.data as Map<String, dynamic>);
      _token = result.accessToken;
      _userId = result.user.id;
      _dio.options.headers['X-Emby-Token'] = _token;
      _loggedIn = true;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<EmbyView>> getViews() => _guarded(() async {
        final Response<dynamic> resp =
            await _dio.get<dynamic>('/Users/$_userId/Views');
        final Map<String, dynamic> map = resp.data as Map<String, dynamic>;
        final List<dynamic> items =
            (map['Items'] as List<dynamic>?) ?? <dynamic>[];
        return items
            .map((dynamic e) => EmbyView.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<EmbyItem>> getItems(String parentId) => _guarded(() async {
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
        return EmbyItemsResult.fromJson(resp.data as Map<String, dynamic>).items;
      });

  String get _baseStr => baseUrl.toString().replaceAll(RegExp(r'/+$'), '');

  /// Absolute direct-play stream URL. Same shape as Jellyfin; auth rides as
  /// `api_key`. media_kit (libmpv) decodes the original file locally.
  String streamUrl(String itemId) {
    return '$_baseStr/Videos/$itemId/stream'
        '?static=true&mediaSourceId=$itemId'
        '&deviceId=$deviceId&api_key=$_token';
  }

  /// Emby counts time in 100-nanosecond ticks (1s = 10,000,000 ticks).
  static int _ticks(Duration d) => d.inMicroseconds * 10;

  /// Marks an item as now-playing. Best-effort.
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
  String? imageUrl(EmbyItem item, {int maxHeight = 420}) {
    final String? tag = item.imageTags['Primary'];
    if (tag == null) {
      return null;
    }
    final String key = _token == null ? '' : '&api_key=$_token';
    return '$_baseStr/Items/${item.id}/Images/Primary'
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
