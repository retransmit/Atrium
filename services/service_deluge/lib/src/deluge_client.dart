import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'models/deluge_filter_tree.dart';
import 'models/deluge_session_status.dart';
import 'models/deluge_torrent.dart';
import 'models/deluge_torrent_detail.dart';

/// Deluge's own error codes, as returned in the JSON-RPC `error` object.
const int _notAuthenticated = 1;

/// An error carried inside a Deluge JSON-RPC envelope.
///
/// Deluge answers **HTTP 200 for everything**, including auth failures and
/// unknown methods, so Dio never raises for these - the envelope has to be
/// inspected. This is internal: [DelugeClient] converts it into the shared
/// `Network*Exception` types before anything else sees it.
class _DelugeRpcException implements Exception {
  const _DelugeRpcException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'Deluge RPC error $code: $message';
}

/// Client for the Deluge 2.x Web UI JSON-RPC API.
///
/// Three things make this unlike the other download clients in Atrium:
///
///  * **One endpoint.** Every call is `POST /json` with
///    `{"method": ..., "params": [...], "id": n}`; there are no REST paths.
///  * **HTTP 200 always.** Failures arrive in the body's `error` field, and a
///    wrong password comes back as `{"result": false, "error": null}` rather
///    than an error at all. Status codes tell you nothing.
///  * **Two processes.** The Web UI is a separate process from the daemon that
///    actually holds the torrents. Authenticating only gets you into the Web
///    UI; if it is not attached to a daemon every `core.*` call fails, so
///    [_ensureSession] attaches it before the first call.
///
/// Auth is a password with no username (Deluge has no user field in its Web
/// UI), exchanged for a `_session_id` cookie that a [CookieManager] carries on
/// subsequent requests.
class DelugeClient {
  DelugeClient({
    required Dio dio,
    required CookieJar cookies,
    required this.password,
  })  : _dio = dio,
        _cookies = cookies;

  final Dio _dio;
  final CookieJar _cookies;
  final String password;

  bool _loggedIn = false;
  bool _daemonAttached = false;
  int _nextId = 1;

  /// The status keys the torrent list needs. Deluge omits any key it does not
  /// know (`label` on a daemon without the Label plugin), so asking for extras
  /// is safe.
  static const List<String> _listKeys = <String>[
    'name',
    'state',
    'progress',
    'download_payload_rate',
    'upload_payload_rate',
    'eta',
    'total_wanted',
    'total_done',
    'total_uploaded',
    'ratio',
    'num_peers',
    'num_seeds',
    'total_peers',
    'total_seeds',
    'label',
    'save_path',
    'tracker_host',
    'time_added',
    'queue',
    'is_finished',
  ];

  /// Builds a client with a cookie-aware Dio pointed at [baseUrl].
  static DelugeClient create({
    required Uri baseUrl,
    required String password,
    required bool allowSelfSigned,
    Map<String, String> customHeaders = const <String, String>{},
  }) {
    final String baseUrlStr = baseUrl.toString();
    final String normalizedBaseUrl =
        baseUrlStr.endsWith('/') ? baseUrlStr : '$baseUrlStr/';
    final CookieJar cookies = CookieJar();
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      ),
    );
    dio.options.headers.addAll(customHeaders);
    dio.interceptors.add(CookieManager(cookies));
    if (allowSelfSigned) {
      final IOHttpClientAdapter adapter =
          dio.httpClientAdapter as IOHttpClientAdapter;
      adapter.createHttpClient = () => HttpClient()
        ..badCertificateCallback =
            (X509Certificate _, String __, int ___) => true;
    }
    return DelugeClient(dio: dio, cookies: cookies, password: password);
  }

  /// Authenticates against the Web UI and stores the session cookie.
  Future<void> login() async {
    // Start clean so a stale `_session_id` cannot shadow the new one.
    await _cookies.deleteAll();
    final Object? result = await _rpc('auth.login', <Object?>[password]);
    if (result != true) {
      throw const NetworkAuthException(
        'Deluge rejected the password. Deluge has no username - check the Web '
        'UI password (Preferences -> Interface -> Password). It defaults to '
        '"deluge" on a fresh install.',
      );
    }
    _loggedIn = true;
    _daemonAttached = false;
  }

  /// Attaches the Web UI to a daemon if it is not already.
  ///
  /// A Web UI that is authenticated but detached answers every `core.*` call
  /// with an error, which reads like a broken server. `web.get_hosts` returns
  /// `[[id, host, port, username], ...]`; the first entry is the local daemon
  /// in every default install.
  Future<void> _attachDaemon() async {
    if (await _rpc('web.connected', <Object?>[]) == true) {
      _daemonAttached = true;
      return;
    }
    final Object? hosts = await _rpc('web.get_hosts', <Object?>[]);
    if (hosts is! List<dynamic> || hosts.isEmpty) {
      throw const NetworkServerException(
        'Deluge has no daemon configured for its Web UI to connect to. Add '
        'one in the Web UI under Connection Manager.',
        status: 200,
      );
    }
    final Object? first = hosts.first;
    final Object? hostId =
        first is List<dynamic> && first.isNotEmpty ? first.first : null;
    if (hostId is! String) {
      throw const NetworkBadResponseException(
        'Deluge returned a host list Atrium could not read.',
        status: 200,
      );
    }
    await _rpc('web.connect', <Object?>[hostId]);
    _daemonAttached = true;
  }

  Future<List<DelugeTorrent>> getTorrents({
    String? state,
    String? label,
    String? trackerHost,
  }) =>
      _guarded(() async {
        // "All" is the filter tree's own label for "no filter"; sending it as a
        // literal value would match nothing.
        final Map<String, Object?> filter = <String, Object?>{
          if (state != null && state.isNotEmpty && state != 'All')
            'state': state,
          if (label != null && label.isNotEmpty && label != 'All')
            'label': label,
          if (trackerHost != null &&
              trackerHost.isNotEmpty &&
              trackerHost != 'All')
            'tracker_host': trackerHost,
        };
        final Object? result = await _rpc(
          'core.get_torrents_status',
          <Object?>[filter, _listKeys],
        );
        if (result is! Map<String, dynamic>) return <DelugeTorrent>[];
        return result.entries
            .map(
              (MapEntry<String, dynamic> e) => DelugeTorrent.fromStatus(
                e.key,
                (e.value as Map<String, dynamic>?) ?? <String, dynamic>{},
              ),
            )
            .toList();
      });

  Future<DelugeSessionStatus> getSessionStatus() => _guarded(() async {
        final Object? result = await _rpc(
          'core.get_session_status',
          <Object?>[DelugeSessionStatus.keys],
        );
        if (result is! Map<String, dynamic>) {
          return const DelugeSessionStatus();
        }
        return DelugeSessionStatus.fromJson(result);
      });

  Future<DelugeFilterTree> getFilterTree() => _guarded(() async {
        final Object? result =
            await _rpc('core.get_filter_tree', <Object?>[]);
        if (result is! Map<String, dynamic>) return const DelugeFilterTree();
        return DelugeFilterTree.fromJson(result);
      });

  Future<DelugeTorrentDetail> getTorrentDetail(String id) => _guarded(() async {
        final Object? result = await _rpc(
          'core.get_torrent_status',
          <Object?>[id, DelugeTorrentDetail.keys],
        );
        if (result is! Map<String, dynamic>) {
          return const DelugeTorrentDetail();
        }
        return DelugeTorrentDetail.fromStatus(result);
      });

  /// Free space at Deluge's download path, in bytes.
  Future<int> getFreeSpace() => _guarded(() async {
        final Object? result = await _rpc('core.get_free_space', <Object?>[]);
        return result is num ? result.toInt() : 0;
      });

  // ---------------------------------------------------------------- actions

  /// Deluge 2.1 split the singular `pause_torrent` (one id) from the plural
  /// `pause_torrents` (a list). Atrium only ever uses the plural forms, which
  /// exist on every 2.x daemon, so there is no version sniffing here.
  Future<void> pause(List<String> ids) =>
      _guarded(() => _rpc('core.pause_torrents', <Object?>[ids]));

  Future<void> resume(List<String> ids) =>
      _guarded(() => _rpc('core.resume_torrents', <Object?>[ids]));

  Future<void> remove(List<String> ids, {required bool removeData}) =>
      _guarded(() async {
        final Object? result = await _rpc(
          'core.remove_torrents',
          <Object?>[ids, removeData],
        );
        // Unlike everything else, this reports per-torrent failures in its
        // result: a non-empty list means some ids did not go away.
        if (result is List<dynamic> && result.isNotEmpty) {
          throw NetworkServerException(
            'Deluge could not remove ${result.length} of ${ids.length} '
            'torrents.',
            status: 200,
          );
        }
      });

  Future<void> recheck(List<String> ids) =>
      _guarded(() => _rpc('core.force_recheck', <Object?>[ids]));

  Future<void> reannounce(List<String> ids) =>
      _guarded(() => _rpc('core.force_reannounce', <Object?>[ids]));

  Future<void> queueUp(List<String> ids) =>
      _guarded(() => _rpc('core.queue_up', <Object?>[ids]));

  Future<void> queueDown(List<String> ids) =>
      _guarded(() => _rpc('core.queue_down', <Object?>[ids]));

  Future<void> queueTop(List<String> ids) =>
      _guarded(() => _rpc('core.queue_top', <Object?>[ids]));

  Future<void> queueBottom(List<String> ids) =>
      _guarded(() => _rpc('core.queue_bottom', <Object?>[ids]));

  /// Pauses or resumes the whole session (every torrent at once).
  Future<void> setSessionPaused({required bool paused}) => _guarded(
        () => _rpc(
          paused ? 'core.pause_session' : 'core.resume_session',
          <Object?>[],
        ),
      );

  /// Whether the whole session is paused, so the UI can offer the right action
  /// rather than guessing from the torrent states.
  Future<bool> isSessionPaused() => _guarded(() async {
        final Object? result =
            await _rpc('core.is_session_paused', <Object?>[]);
        return result == true;
      });

  // ------------------------------------------------------------------- add

  Future<void> addMagnet(
    String magnet, {
    String? savePath,
    bool paused = false,
  }) =>
      _guarded(
        () => _rpc(
          'core.add_torrent_magnet',
          <Object?>[magnet, _addOptions(savePath: savePath, paused: paused)],
        ),
      );

  Future<void> addUrl(
    String url, {
    String? savePath,
    bool paused = false,
  }) =>
      _guarded(
        () => _rpc(
          'core.add_torrent_url',
          <Object?>[url, _addOptions(savePath: savePath, paused: paused)],
        ),
      );

  /// Adds a `.torrent` from its raw bytes.
  ///
  /// Deluge takes the file as base64 in the JSON body (`filedump`) - there is
  /// no multipart upload on this API.
  Future<void> addFile(
    Uint8List bytes, {
    required String filename,
    String? savePath,
    bool paused = false,
  }) =>
      _guarded(
        () => _rpc(
          'core.add_torrent_file',
          <Object?>[
            filename,
            base64Encode(bytes),
            _addOptions(savePath: savePath, paused: paused),
          ],
        ),
      );

  static Map<String, Object?> _addOptions({
    String? savePath,
    required bool paused,
  }) =>
      <String, Object?>{
        if (savePath != null && savePath.isNotEmpty) 'download_location':
            savePath,
        'add_paused': paused,
      };

  // ---------------------------------------------------------------- limits

  /// Reads the global bandwidth caps, in KiB/s (-1 meaning unlimited).
  Future<DelugeSpeedLimits> getSpeedLimits() => _guarded(() async {
        final Object? result = await _rpc(
          'core.get_config_values',
          <Object?>[DelugeSpeedLimits.keys],
        );
        if (result is! Map<String, dynamic>) {
          return const DelugeSpeedLimits();
        }
        return DelugeSpeedLimits.fromJson(result);
      });

  /// Writes the global bandwidth caps. Values are **KiB/s**, and -1 clears a
  /// limit; pass null to leave one untouched.
  Future<void> setSpeedLimits({double? downloadKib, double? uploadKib}) =>
      _guarded(() async {
        final Map<String, Object?> config = <String, Object?>{
          if (downloadKib != null) 'max_download_speed': downloadKib,
          if (uploadKib != null) 'max_upload_speed': uploadKib,
        };
        if (config.isEmpty) return;
        await _rpc('core.set_config', <Object?>[config]);
      });

  void close() => _dio.close(force: true);

  // ------------------------------------------------------------- internals

  /// One raw JSON-RPC round trip. Throws [_DelugeRpcException] when the
  /// envelope carries an error, so callers never have to look at it.
  Future<Object?> _rpc(String method, List<Object?> params) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        'json',
        data: <String, Object?>{
          'method': method,
          'params': params,
          'id': _nextId++,
        },
      );
      final dynamic body = resp.data;
      if (body is! Map<String, dynamic>) {
        throw const NetworkBadResponseException(
          'Deluge returned a body Atrium could not parse as JSON-RPC. Check '
          'that the URL points at Deluge itself and not a reverse proxy error '
          'page.',
          status: 200,
        );
      }
      final Object? error = body['error'];
      if (error is Map<String, dynamic>) {
        final Object? code = error['code'];
        throw _DelugeRpcException(
          code is num ? code.toInt() : -1,
          (error['message'] as String?) ?? 'unknown error',
        );
      }
      return body['result'];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Ensures there is a session attached to a daemon, runs [call], and retries
  /// once if Deluge says the session went away.
  Future<T> _guarded<T>(Future<T> Function() call) async {
    await _ensureSession();
    try {
      return await call();
    } on _DelugeRpcException catch (e) {
      if (e.code == _notAuthenticated) {
        // The session expired or the daemon dropped us. Rebuild both and try
        // exactly once more so a stale cookie is not a user-visible failure.
        _loggedIn = false;
        _daemonAttached = false;
        await _ensureSession();
        try {
          return await call();
        } on _DelugeRpcException catch (e2) {
          throw _asNetworkException(e2);
        }
      }
      throw _asNetworkException(e);
    }
  }

  Future<void> _ensureSession() async {
    if (!_loggedIn) await login();
    if (!_daemonAttached) await _attachDaemon();
  }

  /// Maps a Deluge RPC error onto the shared exception types. The `status: 200`
  /// is not a placeholder - Deluge really does answer 200 for its own errors,
  /// which is why the code has to come out of the body.
  NetworkException _asNetworkException(_DelugeRpcException e) =>
      switch (e.code) {
        _notAuthenticated => NetworkAuthException(
            'Deluge refused the session: ${e.message}',
          ),
        _ => NetworkServerException('Deluge: ${e.message}', status: 200),
      };
}
