import 'dart:typed_data';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/rtorrent_detail.dart';
import 'models/rtorrent_torrent.dart';
import 'xmlrpc.dart';

/// Client for rTorrent's XML-RPC interface.
///
/// This is the odd one out among Atrium's download clients: rTorrent speaks
/// **XML-RPC**, not JSON, and it has no session, no login and no notion of a
/// "status" field.
///
///  * Everything is a POST of a `methodCall` document to a single endpoint.
///    Failures come back as a `fault` inside an HTTP **200**, so the body has
///    to be read rather than the status code.
///  * Lists come from `d.multicall2("", view, "d.name=", ...)`, which returns
///    **positional arrays** in the order the commands were given - there are no
///    keys, so the models are built from a row plus a field list that must stay
///    in step.
///  * There is no auth of its own. rTorrent is protected only by whatever
///    proxy sits in front, so credentials are optional HTTP Basic attached by
///    the shared [AuthInterceptor].
///
/// The endpoint is whatever URL the user configured: `host:8000` for a direct
/// XML-RPC port, or something like `host/RPC2` when ruTorrent's nginx fronts
/// it. Both are just "POST to the base URL" as far as this client cares.
class RtorrentApi {
  RtorrentApi(this._dio);

  final Dio _dio;

  /// Views rTorrent keeps by default; `main` is everything.
  static const String defaultView = 'main';

  Future<List<RtorrentTorrent>> getTorrents({
    String view = defaultView,
  }) async {
    final Object? result = await _call('d.multicall2', <Object?>[
      '',
      view,
      ...RtorrentTorrent.fields,
    ]);
    if (result is! List<Object?>) return <RtorrentTorrent>[];
    return result
        .whereType<List<Object?>>()
        .map(RtorrentTorrent.fromRow)
        .toList();
  }

  /// Session counters and limits, fetched in one round trip.
  ///
  /// `system.multicall` takes an array of `{methodName, params}` structs and
  /// returns an array of one-element arrays, which is why
  /// [RtorrentGlobal.fromRows] unwraps each result.
  Future<RtorrentGlobal> getGlobal() async {
    final Object? result = await _call('system.multicall', <Object?>[
      <Object?>[
        for (final String m in RtorrentGlobal.commands)
          <String, Object?>{'methodName': m, 'params': <Object?>[]},
      ],
    ]);
    if (result is! List<Object?>) return const RtorrentGlobal();
    return RtorrentGlobal.fromRows(result);
  }

  Future<RtorrentDetail> getDetail(String hash) async {
    final List<RtorrentFile> files = await _rows(
      'f.multicall',
      <Object?>[hash, '', ...RtorrentFile.fields],
      RtorrentFile.fromRow,
    );
    final List<RtorrentTracker> trackers = await _rows(
      't.multicall',
      <Object?>[hash, '', ...RtorrentTracker.fields],
      RtorrentTracker.fromRow,
    );
    // A stopped torrent has no peers and rTorrent faults rather than returning
    // an empty list on some builds, so this one is allowed to fail quietly.
    List<RtorrentPeer> peers;
    try {
      peers = await _rows(
        'p.multicall',
        <Object?>[hash, '', ...RtorrentPeer.fields],
        RtorrentPeer.fromRow,
      );
    } on NetworkException {
      peers = <RtorrentPeer>[];
    }
    return RtorrentDetail(files: files, trackers: trackers, peers: peers);
  }

  Future<List<T>> _rows<T>(
    String method,
    List<Object?> params,
    T Function(List<Object?> row) build,
  ) async {
    final Object? result = await _call(method, params);
    if (result is! List<Object?>) return <T>[];
    return result.whereType<List<Object?>>().map(build).toList();
  }

  // ---------------------------------------------------------------- actions

  Future<void> start(String hash) => _call('d.start', <Object?>[hash]);

  Future<void> stop(String hash) => _call('d.stop', <Object?>[hash]);

  /// Closes the torrent, releasing its files without removing it.
  Future<void> close(String hash) => _call('d.close', <Object?>[hash]);

  /// Removes the torrent from rTorrent. It does **not** delete data: rTorrent
  /// has no built-in "erase with data", so the caller must not promise one.
  Future<void> erase(String hash) => _call('d.erase', <Object?>[hash]);

  Future<void> recheck(String hash) => _call('d.check_hash', <Object?>[hash]);

  Future<void> reannounce(String hash) =>
      _call('d.tracker_announce', <Object?>[hash]);

  /// 0 off, 1 low, 2 normal, 3 high.
  Future<void> setPriority(String hash, int priority) =>
      _call('d.priority.set', <Object?>[hash, priority]);

  /// Sets one file's priority: 0 skip, 1 normal, 2 high.
  ///
  /// Files are addressed as `HASH:fINDEX`, and rTorrent does not act on the
  /// change until `d.update_priorities` runs, so both calls belong together.
  Future<void> setFilePriority(String hash, int index, int priority) async {
    await _call('f.priority.set', <Object?>['$hash:f$index', priority]);
    await _call('d.update_priorities', <Object?>[hash]);
  }

  // ------------------------------------------------------------------- add

  /// Adds a magnet link or an http(s) `.torrent` URL.
  ///
  /// rTorrent has no "download directory" parameter. Anything after the URI is
  /// run as a command against the new download, so a destination is set by
  /// passing `d.directory.set=` - the same trick ruTorrent uses.
  Future<void> addUrl(
    String urlOrMagnet, {
    bool start = true,
    String? directory,
  }) =>
      _call(start ? 'load.start_verbose' : 'load.verbose', <Object?>[
        '',
        urlOrMagnet,
        ..._directoryCommands(directory),
      ]);

  /// Adds a torrent from raw `.torrent` bytes, sent as XML-RPC base64.
  Future<void> addFile(
    Uint8List bytes, {
    bool start = true,
    String? directory,
  }) =>
      _call(start ? 'load.raw_start_verbose' : 'load.raw_verbose', <Object?>[
        '',
        bytes,
        ..._directoryCommands(directory),
      ]);

  List<String> _directoryCommands(String? directory) {
    final String dir = directory?.trim() ?? '';
    return dir.isEmpty ? const <String>[] : <String>['d.directory.set="$dir"'];
  }

  // ---------------------------------------------------------------- limits

  /// Global caps in **bytes per second**; 0 clears the limit.
  Future<void> setDownLimit(int bytesPerSec) =>
      _call('throttle.global_down.max_rate.set', <Object?>['', bytesPerSec]);

  Future<void> setUpLimit(int bytesPerSec) =>
      _call('throttle.global_up.max_rate.set', <Object?>['', bytesPerSec]);

  // ------------------------------------------------------------- internals

  Future<Object?> _call(String method, List<Object?> params) async {
    try {
      final Response<String> resp = await _dio.post<String>(
        '',
        data: XmlRpc.buildCall(method, params),
        options: Options(
          contentType: 'text/xml',
          responseType: ResponseType.plain,
          // Faults ride inside a 200; anything else is a transport or proxy
          // problem and is mapped below.
          validateStatus: (int? s) => s != null,
        ),
      );

      final int status = resp.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw NetworkAuthException(
          'rTorrent rejected the credentials (HTTP $status). Its XML-RPC has '
          'no login of its own, so this comes from the proxy in front of it: '
          'check the username and password, or leave both empty if it is not '
          'protected.',
        );
      }
      if (status != 200) {
        throw NetworkServerException(
          'rTorrent returned HTTP $status.',
          status: status,
        );
      }

      return XmlRpc.parseResponse(resp.data ?? '');
    } on XmlRpcFault catch (e) {
      throw NetworkServerException('rTorrent: ${e.message}', status: 200);
    } on FormatException catch (e) {
      throw NetworkBadResponseException(
        'rTorrent did not return XML-RPC (${e.message}). Point the URL at the '
        'SCGI/XML-RPC endpoint - often port 8000, or /RPC2 when ruTorrent is '
        'in front - rather than at the web UI.',
        status: 200,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
