import 'dart:convert';
import 'dart:typed_data';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/transmission_detail.dart';
import 'models/transmission_session.dart';
import 'models/transmission_torrent.dart';

/// The CSRF token header Transmission requires on every RPC call.
const String _sessionHeader = 'X-Transmission-Session-Id';

/// Client for the Transmission RPC API (spec version 19 / Transmission 4.x,
/// backwards compatible with 3.x).
///
/// Everything is a POST to `transmission/rpc` carrying
/// `{"method": ..., "arguments": {...}}`, and the reply is
/// `{"result": "success"|"<error text>", "arguments": {...}}` - so a failure
/// can arrive as HTTP 200 with `result` set to the error, and the envelope has
/// to be read rather than the status code.
///
/// **The CSRF dance is the thing to understand here.** Transmission answers any
/// call without a valid token with **HTTP 409** plus the correct token in the
/// [_sessionHeader] response header. The token also rotates, so this is not a
/// one-time handshake at construction: every call retries once on a 409 with
/// whatever token the rejection handed back. Treating 409 as a hard failure
/// makes the client look broken against a perfectly healthy daemon.
///
/// Auth is HTTP Basic and **optional** - a default install has none - and is
/// attached upstream by the shared `AuthInterceptor`, which sends no header at
/// all when no credentials are configured.
class TransmissionApi {
  TransmissionApi(this._dio);

  final Dio _dio;

  /// Last token seen. Null until the first call has been rejected once.
  String? _sessionId;

  /// Fields the torrent list needs.
  static const List<String> _listFields = <String>[
    'id',
    'hashString',
    'name',
    'status',
    'percentDone',
    'rateDownload',
    'rateUpload',
    'eta',
    'totalSize',
    'sizeWhenDone',
    'leftUntilDone',
    'uploadedEver',
    'uploadRatio',
    'peersConnected',
    'peersSendingToUs',
    'peersGettingFromUs',
    'downloadDir',
    'addedDate',
    'labels',
    'queuePosition',
    'isFinished',
    'isStalled',
    'error',
    'errorString',
    'recheckProgress',
  ];

  Future<List<TransmissionTorrent>> getTorrents() async {
    final Map<String, dynamic> args = await _rpc(
      'torrent-get',
      <String, Object?>{'fields': _listFields},
    );
    final List<dynamic> torrents =
        (args['torrents'] as List<dynamic>?) ?? const <dynamic>[];
    return torrents
        .map(
          (dynamic e) =>
              TransmissionTorrent.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Detail for one torrent, addressed by infohash so a daemon restart (which
  /// reassigns the numeric ids) cannot point this at the wrong torrent.
  Future<TransmissionDetail> getDetail(String hashString) async {
    final Map<String, dynamic> args = await _rpc(
      'torrent-get',
      <String, Object?>{
        'ids': <String>[hashString],
        'fields': TransmissionDetail.fields,
      },
    );
    final List<dynamic> torrents =
        (args['torrents'] as List<dynamic>?) ?? const <dynamic>[];
    if (torrents.isEmpty) return const TransmissionDetail();
    return TransmissionDetail.fromTorrentJson(
      torrents.first as Map<String, dynamic>,
    );
  }

  Future<TransmissionSession> getSession() async {
    final Map<String, dynamic> args = await _rpc(
      'session-get',
      <String, Object?>{'fields': TransmissionSession.fields},
    );
    return TransmissionSession.fromJson(args);
  }

  Future<TransmissionSessionStats> getSessionStats() async {
    final Map<String, dynamic> args = await _rpc('session-stats');
    return TransmissionSessionStats.fromJson(args);
  }

  // Free space deliberately comes from `session-get`'s
  // `download-dir-free-space` (see [TransmissionSession.knowsFreeSpace]) rather
  // than the separate `free-space` method. `free-space` *errors* when it cannot
  // stat the path - which a containerised Transmission whose download dir is
  // not actually mounted will do - and a decorative number must not be able to
  // fail the whole screen. The session field simply reports -1 instead.

  // ---------------------------------------------------------------- actions

  Future<void> start(List<String> hashes) =>
      _rpc('torrent-start', <String, Object?>{'ids': hashes});

  /// Starts immediately, jumping the queue.
  Future<void> startNow(List<String> hashes) =>
      _rpc('torrent-start-now', <String, Object?>{'ids': hashes});

  Future<void> stop(List<String> hashes) =>
      _rpc('torrent-stop', <String, Object?>{'ids': hashes});

  Future<void> remove(
    List<String> hashes, {
    required bool deleteLocalData,
  }) =>
      _rpc('torrent-remove', <String, Object?>{
        'ids': hashes,
        'delete-local-data': deleteLocalData,
      });

  Future<void> verify(List<String> hashes) =>
      _rpc('torrent-verify', <String, Object?>{'ids': hashes});

  Future<void> reannounce(List<String> hashes) =>
      _rpc('torrent-reannounce', <String, Object?>{'ids': hashes});

  Future<void> queueTop(List<String> hashes) =>
      _rpc('queue-move-top', <String, Object?>{'ids': hashes});

  Future<void> queueUp(List<String> hashes) =>
      _rpc('queue-move-up', <String, Object?>{'ids': hashes});

  Future<void> queueDown(List<String> hashes) =>
      _rpc('queue-move-down', <String, Object?>{'ids': hashes});

  Future<void> queueBottom(List<String> hashes) =>
      _rpc('queue-move-bottom', <String, Object?>{'ids': hashes});

  /// Sets which files are wanted, and their priority.
  Future<void> setFileWanted(
    String hashString,
    List<int> indices, {
    required bool wanted,
  }) =>
      _rpc('torrent-set', <String, Object?>{
        'ids': <String>[hashString],
        if (wanted) 'files-wanted': indices else 'files-unwanted': indices,
      });

  // ------------------------------------------------------------------- add

  /// Adds a magnet link or an http(s) `.torrent` URL.
  ///
  /// Returns true when a new torrent was added, false when Transmission
  /// recognised it as a duplicate - which it reports as a *success*, under a
  /// different key, rather than as an error.
  Future<bool> addUrl(
    String urlOrMagnet, {
    String? downloadDir,
    bool paused = false,
  }) async {
    final Map<String, dynamic> args = await _rpc('torrent-add', <String, Object?>{
      'filename': urlOrMagnet,
      'paused': paused,
      if (downloadDir != null && downloadDir.isNotEmpty)
        'download-dir': downloadDir,
    });
    return !args.containsKey('torrent-duplicate');
  }

  /// Adds a torrent from a `.torrent` file's bytes, which Transmission takes as
  /// base64 in `metainfo`.
  Future<bool> addFile(
    Uint8List bytes, {
    String? downloadDir,
    bool paused = false,
  }) async {
    final Map<String, dynamic> args = await _rpc('torrent-add', <String, Object?>{
      'metainfo': base64Encode(bytes),
      'paused': paused,
      if (downloadDir != null && downloadDir.isNotEmpty)
        'download-dir': downloadDir,
    });
    return !args.containsKey('torrent-duplicate');
  }

  // ---------------------------------------------------------------- limits

  /// Writes a global limit. Values are **KB/s**. Passing null for a flag leaves
  /// it as it is, so the value and its enabled state can be set independently.
  Future<void> setSpeedLimits({
    int? downKbps,
    bool? downEnabled,
    int? upKbps,
    bool? upEnabled,
  }) {
    final Map<String, Object?> args = <String, Object?>{
      if (downKbps != null) 'speed-limit-down': downKbps,
      if (downEnabled != null) 'speed-limit-down-enabled': downEnabled,
      if (upKbps != null) 'speed-limit-up': upKbps,
      if (upEnabled != null) 'speed-limit-up-enabled': upEnabled,
    };
    if (args.isEmpty) return Future<void>.value();
    return _rpc('session-set', args);
  }

  /// Turtle mode: swaps in the alternate limits without touching the main ones.
  Future<void> setAltSpeed({required bool enabled}) =>
      _rpc('session-set', <String, Object?>{'alt-speed-enabled': enabled});

  // ------------------------------------------------------------- internals

  /// One RPC call, retrying once when Transmission rejects the CSRF token.
  Future<Map<String, dynamic>> _rpc(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      Response<dynamic> resp = await _post(method, arguments);
      if (resp.statusCode == 409) {
        final String? fresh = resp.headers.value(_sessionHeader);
        if (fresh == null || fresh.isEmpty) {
          throw const NetworkBadResponseException(
            'Transmission rejected the request as a CSRF risk but did not '
            'return a session id. Check that the URL points at Transmission '
            'and not a proxy that strips headers.',
            status: 409,
          );
        }
        _sessionId = fresh;
        resp = await _post(method, arguments);
      }

      final int status = resp.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw NetworkAuthException(
          'Transmission rejected the credentials (HTTP $status). RPC auth is '
          'optional: leave both fields empty if the server has it turned off, '
          'otherwise check the username and password.',
        );
      }
      if (status != 200) {
        throw NetworkServerException(
          'Transmission returned HTTP $status.',
          status: status,
        );
      }

      final dynamic body = resp.data;
      if (body is! Map<String, dynamic>) {
        throw const NetworkBadResponseException(
          'Transmission returned a body Atrium could not parse. Check that the '
          'URL points at the RPC endpoint.',
          status: 200,
        );
      }
      // `result` is the string "success", or the error text itself.
      final String result = (body['result'] as String?) ?? '';
      if (result != 'success') {
        throw NetworkServerException(
          'Transmission: ${result.isEmpty ? 'unknown error' : result}',
          status: 200,
        );
      }
      return (body['arguments'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Response<dynamic>> _post(
    String method,
    Map<String, Object?>? arguments,
  ) {
    return _dio.post<dynamic>(
      'transmission/rpc',
      data: <String, Object?>{
        'method': method,
        if (arguments != null) 'arguments': arguments,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        // 409 is expected on the first call and whenever the token rotates, so
        // it has to reach us rather than being raised as a transport error.
        validateStatus: (int? s) => s != null,
        headers: <String, dynamic>{
          if (_sessionId != null) _sessionHeader: _sessionId,
        },
      ),
    );
  }
}
