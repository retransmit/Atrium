import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/nzbget_group.dart';
import 'models/nzbget_history_entry.dart';
import 'models/nzbget_status.dart';

/// A method-level failure reported inside NZBGet's JSON-RPC envelope
/// (HTTP was 200, but the server said no).
class NzbgetRpcException implements Exception {
  const NzbgetRpcException(this.message);

  final String message;

  @override
  String toString() => 'NzbgetRpcException: $message';
}

/// Thin client over NZBGet's JSON-RPC API.
///
/// Auth is HTTP Basic, attached per-request by `core_networking`'s
/// AuthInterceptor, so this rides the shared `instanceDioProvider` Dio.
/// Every call POSTs `{"method": ..., "params": [...]}` to `jsonrpc` and
/// unwraps the `result` / `error` envelope; NZBGet returns HTTP 200 even for
/// method-level failures.
class NzbgetApi {
  NzbgetApi(this._dio);

  final Dio _dio;

  Future<dynamic> _call(
    String method, [
    List<dynamic> params = const <dynamic>[],
  ]) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        'jsonrpc',
        data: <String, dynamic>{'method': method, 'params': params},
      );
      final dynamic data = resp.data;
      if (data is! Map<String, dynamic>) {
        throw const NzbgetRpcException('Unexpected response shape');
      }
      final dynamic error = data['error'];
      if (error != null) {
        final String message = error is Map<String, dynamic>
            ? (error['message']?.toString() ?? 'code ${error['code']}')
            : error.toString();
        throw NzbgetRpcException(message);
      }
      return data['result'];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// For methods whose result is a bool success flag.
  Future<void> _command(
    String method, [
    List<dynamic> params = const <dynamic>[],
  ]) async {
    final dynamic result = await _call(method, params);
    if (result != true) {
      throw NzbgetRpcException('$method failed');
    }
  }

  Future<String> getVersion() async => (await _call('version')).toString();

  Future<NzbgetStatus> getStatus() async =>
      NzbgetStatus.fromJson(await _call('status') as Map<String, dynamic>);

  Future<List<NzbgetGroup>> getGroups() async =>
      ((await _call('listgroups')) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NzbgetGroup.fromJson)
          .toList();

  /// Completed / failed downloads, newest first. `false` = visible only.
  Future<List<NzbgetHistoryEntry>> getHistory() async =>
      ((await _call('history', <dynamic>[false])) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NzbgetHistoryEntry.fromJson)
          .toList();

  /// Pause / resume the whole download queue.
  Future<void> pauseAll() => _command('pausedownload');
  Future<void> resumeAll() => _command('resumedownload');

  /// The queue/history swiss army knife. `ids` are NZBIDs.
  ///
  /// Failures name the subcommand: 'editqueue failed' alone would leave
  /// no clue whether a pause, delete or move went wrong.
  Future<void> editQueue(String command, String param, List<int> ids) async {
    final dynamic result =
        await _call('editqueue', <dynamic>[command, param, ids]);
    if (result != true) {
      throw NzbgetRpcException('editqueue $command failed');
    }
  }

  Future<void> pauseItems(List<int> ids) => editQueue('GroupPause', '', ids);
  Future<void> resumeItems(List<int> ids) => editQueue('GroupResume', '', ids);
  Future<void> deleteItems(List<int> ids) => editQueue('GroupDelete', '', ids);
  Future<void> moveTop(List<int> ids) => editQueue('GroupMoveTop', '', ids);
  Future<void> moveBottom(List<int> ids) =>
      editQueue('GroupMoveBottom', '', ids);

  /// Moves one group by [offset] positions (negative = up).
  Future<void> moveOffset(int id, int offset) =>
      editQueue('GroupMoveOffset', '$offset', <int>[id]);

  /// -100 very low, -50 low, 0 normal, 50 high, 100 very high, 900 force.
  Future<void> setPriority(List<int> ids, int priority) =>
      editQueue('GroupSetPriority', '$priority', ids);

  /// Applies a category (and its side effects) to queued groups.
  Future<void> setCategory(List<int> ids, String category) =>
      editQueue('GroupApplyCategory', category, ids);

  Future<void> retryHistoryItem(int id) =>
      editQueue('HistoryRedownload', '', <int>[id]);
  Future<void> deleteHistoryItem(int id) =>
      editQueue('HistoryDelete', '', <int>[id]);

  /// Global download limit in KB/s; 0 removes the limit.
  Future<void> setSpeedLimit(int kbPerSec) =>
      _command('rate', <dynamic>[kbPerSec]);

  /// Adds an NZB. [content] is a URL or the base64 of an .nzb file.
  /// Returns the new NZBID; a result of 0 or less means the server
  /// rejected it.
  Future<int> append({
    required String name,
    required String content,
    String category = '',
    int priority = 0,
    bool addPaused = false,
  }) async {
    final dynamic result = await _call('append', <dynamic>[
      name, content, category, priority, false, addPaused, '', 0, 'SCORE',
    ]);
    final int id = result is int ? result : -1;
    if (id <= 0) {
      throw const NzbgetRpcException('append rejected the NZB');
    }
    return id;
  }

  /// Category names from the server config (Category1.Name, Category2.Name...).
  Future<List<String>> getCategories() async {
    final List<dynamic> entries = (await _call('config')) as List<dynamic>;
    final RegExp namePattern = RegExp(r'^Category\d+\.Name$');
    return <String>[
      for (final dynamic e in entries)
        if (e is Map<String, dynamic> &&
            namePattern.hasMatch(e['Name']?.toString() ?? '') &&
            (e['Value']?.toString() ?? '').isNotEmpty)
          e['Value'].toString(),
    ];
  }
}
