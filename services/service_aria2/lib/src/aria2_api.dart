import 'dart:convert';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/aria2_download.dart';
import 'models/aria2_file.dart';
import 'models/aria2_global_stat.dart';
import 'models/aria2_peer.dart';
import 'models/aria2_server.dart';
import 'models/aria2_snapshot.dart';
import 'models/aria2_version.dart';

/// A method-level failure reported inside aria2's JSON-RPC envelope.
///
/// The HTTP request succeeded (200) but the daemon said no - a wrong RPC
/// secret, an unknown GID, a paused download that cannot be resumed.
class Aria2RpcException implements Exception {
  const Aria2RpcException(this.message, {this.code});

  final String message;

  /// aria2's numeric error code, when it sent one.
  ///
  /// aria2 sends 1 for every failure, a refused secret included, so the code
  /// alone says nothing about what went wrong.
  final int? code;

  /// Whether the daemon has no download under the GID asked for: it was
  /// removed and its result purged. Only the message tells this apart.
  bool get isGidNotFound =>
      message.startsWith('GID ') && message.endsWith(' is not found');

  @override
  String toString() => 'Aria2RpcException: $message';
}

/// Client over aria2's JSON-RPC interface (`POST /jsonrpc`).
///
/// The daemon's auth is a *secret token* rather than an HTTP credential: the
/// token is the first parameter of every call, prefixed with `token:`. It is
/// optional - an aria2 with no `--rpc-secret` answers anyone - so [secret]
/// may be empty, in which case no token parameter is sent at all.
///
/// Every numeric field in aria2's replies is a string; the models read them
/// through the helpers in `models/aria2_json.dart`.
class Aria2Api {
  Aria2Api(this._dio, {String secret = ''}) : _secret = secret;

  final Dio _dio;
  final String _secret;

  /// Whether a token is sent with the calls.
  bool get hasSecret => _secret.isNotEmpty;

  // -------------------------------------------------------------------------
  // Transport
  // -------------------------------------------------------------------------

  /// The parameters of one call, with the secret in front when there is one.
  List<dynamic> _withSecret(List<dynamic> params) {
    if (_secret.isEmpty) {
      return params;
    }
    return <dynamic>['token:$_secret', ...params];
  }

  /// Sends one JSON-RPC call and returns its `result`.
  ///
  /// [sendSecret] is false for `system.multicall`, which carries the token
  /// in its nested calls rather than in its own parameters.
  Future<dynamic> _call(
    String method, [
    List<dynamic> params = const <dynamic>[],
    bool sendSecret = true,
  ]) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        'jsonrpc',
        data: <String, dynamic>{
          'jsonrpc': '2.0',
          'id': 'atrium',
          'method': method,
          'params': sendSecret ? _withSecret(params) : params,
        },
      );
      return _unwrap(resp.data);
    } on DioException catch (e) {
      // aria2 answers a refused secret with HTTP 400 and an `error` envelope
      // rather than 401, so the envelope is read before the generic HTTP
      // mapping - otherwise a wrong secret reads as a bare "HTTP 400".
      final Object? error = _errorEnvelope(e.response?.data);
      if (error != null) {
        throw Aria2RpcException(_errorMessage(error), code: _errorCode(error));
      }
      throw NetworkException.fromDio(e);
    }
  }

  /// The `error` object of a JSON-RPC answer, or null when there is none.
  Object? _errorEnvelope(Object? data) {
    Object? body = data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is! Map) {
      return null;
    }
    return body['error'];
  }

  /// Unwraps a JSON-RPC envelope, turning an `error` object into an
  /// [Aria2RpcException].
  ///
  /// aria2 labels its replies `application/json-rpc`, which Dio does parse
  /// as JSON, but a body that arrives as text (a proxy's error page, a
  /// daemon answering something unexpected) is decoded here rather than
  /// rejected.
  dynamic _unwrap(Object? data) {
    Object? body = data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        throw const Aria2RpcException('Response was not JSON');
      }
    }
    if (body is! Map) {
      throw const Aria2RpcException('Unexpected response shape');
    }
    final Object? error = body['error'];
    if (error != null) {
      throw Aria2RpcException(_errorMessage(error), code: _errorCode(error));
    }
    return body['result'];
  }

  String _errorMessage(Object? error) {
    if (error is Map) {
      final Object? message = error['message'] ?? error['faultString'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return error.toString();
  }

  int? _errorCode(Object? error) {
    if (error is Map) {
      final Object? code = error['code'] ?? error['faultCode'];
      if (code is int) {
        return code;
      }
      if (code is String) {
        return int.tryParse(code);
      }
    }
    return null;
  }

  /// Sends several calls in one request.
  ///
  /// aria2 recommends batching: the secret check is deliberately slow, so
  /// one request with five calls is much cheaper on the daemon's side than
  /// five requests. `system.multicall` takes no token of its own - each
  /// nested call carries it.
  Future<List<dynamic>> _multicall(
    List<({String method, List<dynamic> params})> calls,
  ) async {
    final List<Map<String, dynamic>> nested = <Map<String, dynamic>>[
      for (final ({String method, List<dynamic> params}) call in calls)
        <String, dynamic>{
          'methodName': call.method,
          'params': _withSecret(call.params),
        },
    ];
    final dynamic result = await _call('system.multicall', <dynamic>[
      nested,
    ], false);
    if (result is! List) {
      throw const Aria2RpcException('Unexpected multicall response shape');
    }
    return result.cast<dynamic>();
  }

  /// The value of one nested call inside a multicall answer.
  ///
  /// A successful call comes back as a one-item array; a failed one comes
  /// back as a fault struct.
  dynamic _multicallValue(List<dynamic> results, int index) {
    if (index >= results.length) {
      throw const Aria2RpcException('Multicall answer is missing a result');
    }
    final dynamic element = results[index];
    if (element is List) {
      return element.isEmpty ? null : element.first;
    }
    if (element is Map) {
      throw Aria2RpcException(
        _errorMessage(element),
        code: _errorCode(element),
      );
    }
    return element;
  }

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  /// Keys requested for transfers list views to avoid transferring heavy fields
  /// like `bitfield` every polling cycle.
  static const List<String> snapshotKeys = <String>[
    'gid',
    'status',
    'totalLength',
    'completedLength',
    'uploadLength',
    'downloadSpeed',
    'uploadSpeed',
    'connections',
    'numSeeders',
    'seeder',
    'errorCode',
    'errorMessage',
    'dir',
    'infoHash',
    'bittorrent',
    'files',
  ];

  /// Everything the screen needs, in one batched request.
  ///
  /// The stopped list is asked with offset -1 so aria2 hands out the most
  /// recently stopped downloads first.
  Future<Aria2Snapshot> getSnapshot({
    int waitingLimit = 1000,
    int stoppedLimit = 200,
  }) async {
    final List<dynamic> results = await _multicall(
      <({String method, List<dynamic> params})>[
        (method: 'aria2.getGlobalStat', params: const <dynamic>[]),
        (method: 'aria2.getVersion', params: const <dynamic>[]),
        (method: 'aria2.tellActive', params: const <dynamic>[snapshotKeys]),
        (method: 'aria2.tellWaiting', params: <dynamic>[0, waitingLimit, snapshotKeys]),
        (method: 'aria2.tellStopped', params: <dynamic>[-1, stoppedLimit, snapshotKeys]),
      ],
    );

    final Aria2GlobalStat stat = Aria2GlobalStat.fromJson(
      _asMap(_multicallValue(results, 0)),
    );
    final Aria2Version version = Aria2Version.fromJson(
      _asMap(_multicallValue(results, 1)),
    );
    final List<Aria2Download> active = _asDownloads(
      _multicallValue(results, 2),
    );
    final List<Aria2Download> waiting = _asDownloads(
      _multicallValue(results, 3),
    );
    final List<Aria2Download> stopped = _asDownloads(
      _multicallValue(results, 4),
    );

    return Aria2Snapshot(
      stat: stat,
      version: version,
      active: active,
      waiting: waiting,
      stopped: stopped,
    );
  }

  Future<Aria2GlobalStat> getGlobalStat() async =>
      Aria2GlobalStat.fromJson(_asMap(await _call('aria2.getGlobalStat')));

  Future<Aria2Version> getVersion() async =>
      Aria2Version.fromJson(_asMap(await _call('aria2.getVersion')));

  Future<List<Aria2Download>> tellActive({List<String>? keys}) async {
    final List<dynamic> params = <dynamic>[
      ?keys,
    ];
    return _asDownloads(await _call('aria2.tellActive', params));
  }

  Future<List<Aria2Download>> tellWaiting({
    int offset = 0,
    int num = 1000,
    List<String>? keys,
  }) async {
    final List<dynamic> params = <dynamic>[
      offset,
      num,
      ?keys,
    ];
    return _asDownloads(await _call('aria2.tellWaiting', params));
  }

  Future<List<Aria2Download>> tellStopped({
    int offset = -1,
    int num = 200,
    List<String>? keys,
  }) async {
    final List<dynamic> params = <dynamic>[
      offset,
      num,
      ?keys,
    ];
    return _asDownloads(await _call('aria2.tellStopped', params));
  }

  /// One download's own status.
  Future<Aria2Download> tellStatus(String gid) async => Aria2Download.fromJson(
    _asMap(await _call('aria2.tellStatus', <dynamic>[gid])),
  );

  /// The files behind a download.
  Future<List<Aria2File>> getFiles(String gid) async {
    final dynamic result = await _call('aria2.getFiles', <dynamic>[gid]);
    if (result is! List) {
      return const <Aria2File>[];
    }
    return <Aria2File>[
      for (final dynamic item in result)
        if (item is Map) Aria2File.fromJson(item.cast<String, dynamic>()),
    ];
  }

  /// The global options as the daemon has them (`aria2.getGlobalOption`).
  Future<Map<String, String>> getGlobalOption() async {
    final dynamic result = await _call('aria2.getGlobalOption');
    if (result is! Map) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final MapEntry<Object?, Object?> entry in result.entries)
        entry.key.toString(): entry.value.toString(),
    };
  }

  /// The session id of the running daemon.
  Future<String> getSessionId() async {
    final Map<String, dynamic> info = _asMap(
      await _call('aria2.getSessionInfo'),
    );
    return info['sessionId']?.toString() ?? '';
  }

  /// The active peers for a BitTorrent download (`aria2.getPeers`).
  Future<List<Aria2Peer>> getPeers(String gid) async {
    final dynamic result = await _call('aria2.getPeers', <dynamic>[gid]);
    if (result is! List) {
      return const <Aria2Peer>[];
    }
    return <Aria2Peer>[
      for (final dynamic item in result)
        if (item is Map) Aria2Peer.fromJson(item.cast<String, dynamic>()),
    ];
  }

  /// The active server connections for a download (`aria2.getServers`).
  Future<List<Aria2Server>> getServers(String gid) async {
    final dynamic result = await _call('aria2.getServers', <dynamic>[gid]);
    if (result is! List) {
      return const <Aria2Server>[];
    }
    return <Aria2Server>[
      for (final dynamic item in result)
        if (item is Map) Aria2Server.fromJson(item.cast<String, dynamic>()),
    ];
  }

  /// The URIs used for a download (`aria2.getUris`).
  Future<List<Aria2Uri>> getUris(String gid) async {
    final dynamic result = await _call('aria2.getUris', <dynamic>[gid]);
    if (result is! List) {
      return const <Aria2Uri>[];
    }
    return <Aria2Uri>[
      for (final dynamic item in result)
        if (item is Map) Aria2Uri.fromJson(item.cast<String, dynamic>()),
    ];
  }

  /// The options of one download (`aria2.getOption`).
  Future<Map<String, dynamic>> getOption(String gid) async {
    final dynamic result = await _call('aria2.getOption', <dynamic>[gid]);
    if (result is! Map) {
      return const <String, dynamic>{};
    }
    return result.cast<String, dynamic>();
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  /// Adds a download by URI (http, https, ftp, magnet, ...).
  ///
  /// [uris] are mirrors of the *same* resource, which is what aria2's
  /// `addUri` means. Returns the new GID.
  Future<String> addUri(
    List<String> uris, {
    Map<String, dynamic> options = const <String, dynamic>{},
    int? position,
  }) async {
    final List<dynamic> params = <dynamic>[uris];
    // aria2 reads the options and the position by position, so the options
    // have to be there for the position to land in the right slot.
    if (options.isNotEmpty || position != null) {
      params.add(options);
    }
    if (position != null) {
      params.add(position);
    }
    return _asGid(await _call('aria2.addUri', params));
  }

  /// Adds a torrent from the bytes of a `.torrent` file, base64 encoded.
  ///
  /// [uris] are web-seeding sources; they are optional.
  Future<String> addTorrent(
    String torrentBase64, {
    List<String> uris = const <String>[],
    Map<String, dynamic> options = const <String, dynamic>{},
    int? position,
  }) async {
    // The list of sources goes out even when it is empty, and for the same
    // reason: aria2 reads the options by position, so leaving the list out
    // would hand it the options as the list of sources and it would answer
    // 'The parameter at 1 has wrong type.'
    final List<dynamic> params = <dynamic>[torrentBase64, uris];
    // The options have to be there for the position to land in the right
    // slot too.
    if (options.isNotEmpty || position != null) {
      params.add(options);
    }
    if (position != null) {
      params.add(position);
    }
    return _asGid(await _call('aria2.addTorrent', params));
  }

  /// Adds a metalink download from base64 encoded bytes (`aria2.addMetalink`).
  ///
  /// Returns the list of GIDs added.
  Future<List<String>> addMetalink(
    String metalinkBase64, {
    Map<String, dynamic> options = const <String, dynamic>{},
    int? position,
  }) async {
    final List<dynamic> params = <dynamic>[metalinkBase64];
    if (options.isNotEmpty || position != null) {
      params.add(options);
    }
    if (position != null) {
      params.add(position);
    }
    final dynamic result = await _call('aria2.addMetalink', params);
    if (result is! List) {
      return const <String>[];
    }
    return result.map((dynamic item) => item.toString()).toList();
  }

  /// Pauses a download (active or waiting).
  Future<void> pause(String gid) => _command('aria2.pause', <dynamic>[gid]);

  /// Pauses a download without waiting for it to stop first.
  Future<void> forcePause(String gid) =>
      _command('aria2.forcePause', <dynamic>[gid]);

  /// Resumes a paused download.
  Future<void> unpause(String gid) => _command('aria2.unpause', <dynamic>[gid]);

  /// Pauses every active download daemon-wide.
  Future<void> pauseAll() => _command('aria2.pauseAll');

  /// Pauses every active download daemon-wide without waiting for them to stop first.
  Future<void> forcePauseAll() => _command('aria2.forcePauseAll');

  /// Resumes every paused download daemon-wide.
  Future<void> unpauseAll() => _command('aria2.unpauseAll');

  /// Counts the calls of a multicall answer that went through.
  ///
  /// A call that worked comes back as a one-item array and a failed one as
  /// an error struct, `{code, message}` over JSON-RPC.
  ({int succeeded, int failed}) _tally(List<dynamic> results) {
    final int failed = results.whereType<Map<dynamic, dynamic>>().length;
    return (succeeded: results.length - failed, failed: failed);
  }

  /// Batches pause calls for specific GIDs into a single system.multicall.
  Future<({int succeeded, int failed})> pauseGids(Iterable<String> gids) async {
    final List<String> list = gids.toList();
    if (list.isEmpty) return (succeeded: 0, failed: 0);
    final List<dynamic> results = await _multicall(
      list
          .map((String gid) => (method: 'aria2.pause', params: <dynamic>[gid]))
          .toList(),
    );
    return _tally(results);
  }

  /// Batches unpause calls for specific GIDs into a single system.multicall.
  Future<({int succeeded, int failed})> unpauseGids(
    Iterable<String> gids,
  ) async {
    final List<String> list = gids.toList();
    if (list.isEmpty) return (succeeded: 0, failed: 0);
    final List<dynamic> results = await _multicall(
      list
          .map((String gid) => (method: 'aria2.unpause', params: <dynamic>[gid]))
          .toList(),
    );
    return _tally(results);
  }

  /// Batches removal calls for specific GIDs into a single system.multicall.
  Future<({int succeeded, int failed})> removeGids({
    Iterable<String> activeOrWaitingGids = const <String>[],
    Iterable<String> stoppedGids = const <String>[],
  }) async {
    final List<({String method, List<dynamic> params})> calls =
        <({String method, List<dynamic> params})>[
      for (final String gid in activeOrWaitingGids)
        (method: 'aria2.remove', params: <dynamic>[gid]),
      for (final String gid in stoppedGids)
        (method: 'aria2.removeDownloadResult', params: <dynamic>[gid]),
    ];
    if (calls.isEmpty) return (succeeded: 0, failed: 0);
    final List<dynamic> results = await _multicall(calls);
    return _tally(results);
  }

  /// Removes a download: it stops and its files are left alone.
  Future<void> remove(String gid) => _command('aria2.remove', <dynamic>[gid]);

  /// Removes a download without waiting for it to stop.
  Future<void> forceRemove(String gid) =>
      _command('aria2.forceRemove', <dynamic>[gid]);

  /// Forgets a stopped download's result, freeing the daemon's memory.
  Future<void> removeDownloadResult(String gid) =>
      _command('aria2.removeDownloadResult', <dynamic>[gid]);

  /// Forgets every stopped download's result.
  Future<void> purgeDownloadResult() => _command('aria2.purgeDownloadResult');

  /// Moves a download inside the waiting queue.
  ///
  /// [how] is `POS_SET` (absolute), `POS_CUR` (relative) or `POS_END`
  /// (relative to the end).
  Future<void> changePosition(String gid, int position, String how) =>
      _command('aria2.changePosition', <dynamic>[gid, position, how]);

  /// Changes the options of one download.
  Future<void> changeOption(String gid, Map<String, dynamic> options) =>
      _command('aria2.changeOption', <dynamic>[gid, options]);

  /// Changes the daemon's global options.
  Future<void> changeGlobalOption(Map<String, dynamic> options) =>
      _command('aria2.changeGlobalOption', <dynamic>[options]);

  /// Sets the global download limit in bytes per second; 0 removes it.
  Future<void> setGlobalDownloadLimit(int bytesPerSec) => changeGlobalOption(
    <String, String>{'max-overall-download-limit': '$bytesPerSec'},
  );

  /// Sets the global upload limit in bytes per second; 0 removes it.
  Future<void> setGlobalUploadLimit(int bytesPerSec) => changeGlobalOption(
    <String, String>{'max-overall-upload-limit': '$bytesPerSec'},
  );

  /// Adds or removes mirror URIs for a download (`aria2.changeUri`).
  ///
  /// Returns `[deletedCount, addedCount]`.
  Future<List<int>> changeUri(
    String gid,
    int fileIndex, {
    List<String> delUris = const <String>[],
    List<String> addUris = const <String>[],
    int? position,
  }) async {
    final List<dynamic> params = <dynamic>[gid, fileIndex, delUris, addUris];
    if (position != null) {
      params.add(position);
    }
    final dynamic result = await _call('aria2.changeUri', params);
    if (result is! List) {
      return const <int>[0, 0];
    }
    return <int>[
      for (final dynamic v in result)
        if (v is int) v else int.tryParse(v.toString()) ?? 0,
    ];
  }

  /// Flushes the current session to disk (`aria2.saveSession`).
  Future<void> saveSession() => _command('aria2.saveSession');

  /// Shuts down the aria2 daemon gracefully (`aria2.shutdown`).
  Future<void> shutdown() => _command('aria2.shutdown');

  /// Forcefully shuts down the aria2 daemon (`aria2.forceShutdown`).
  Future<void> forceShutdown() => _command('aria2.forceShutdown');

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Runs a call whose result is not interesting.
  Future<void> _command(
    String method, [
    List<dynamic> params = const <dynamic>[],
  ]) async {
    await _call(method, params);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const Aria2RpcException('Unexpected response shape');
    }
    return value.cast<String, dynamic>();
  }

  List<Aria2Download> _asDownloads(Object? value) {
    if (value is! List) {
      return const <Aria2Download>[];
    }
    return <Aria2Download>[
      for (final dynamic item in value)
        if (item is Map) Aria2Download.fromJson(item.cast<String, dynamic>()),
    ];
  }

  String _asGid(Object? value) {
    final String gid = value?.toString() ?? '';
    if (gid.isEmpty) {
      throw const Aria2RpcException('aria2 returned no GID');
    }
    return gid;
  }
}
