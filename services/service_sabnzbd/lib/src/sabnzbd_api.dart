import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/sab_history.dart';
import 'models/sab_queue.dart';
import 'models/sab_stats.dart';

/// Thin client over the SABnzbd API.
///
/// SABnzbd auth is an `apikey` query param, and `output=json` selects JSON -
/// both are appended by `core_networking`'s [AuthInterceptor], so this rides
/// the shared `instanceDioProvider` Dio and only needs to add `mode=…`.
class SabnzbdApi {
  SabnzbdApi(this._dio);

  final Dio _dio;

  Future<SabQueue> getQueue() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api',
        queryParameters: <String, dynamic>{'mode': 'queue'},
      );
      return SabQueueResponse.fromJson(resp.data as Map<String, dynamic>)
              .queue ??
          const SabQueue();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Pause the whole queue.
  Future<void> pauseAll() => _simple(<String, dynamic>{'mode': 'pause'});

  /// Resume the whole queue.
  Future<void> resumeAll() => _simple(<String, dynamic>{'mode': 'resume'});

  Future<void> pauseItem(String nzoId) => _simple(<String, dynamic>{
        'mode': 'queue',
        'name': 'pause',
        'value': nzoId,
      });

  Future<void> resumeItem(String nzoId) => _simple(<String, dynamic>{
        'mode': 'queue',
        'name': 'resume',
        'value': nzoId,
      });

  Future<void> deleteItem(String nzoId) => _simple(<String, dynamic>{
        'mode': 'queue',
        'name': 'delete',
        'value': nzoId,
      });

  /// Completed / failed download history, newest first.
  Future<SabHistory> getHistory({int limit = 50}) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api',
        queryParameters: <String, dynamic>{'mode': 'history', 'limit': limit},
      );
      return SabHistoryResponse.fromJson(resp.data as Map<String, dynamic>)
              .history ??
          const SabHistory();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Bytes downloaded over day / week / month / total.
  Future<SabServerStats> getServerStats() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api',
        queryParameters: <String, dynamic>{'mode': 'server_stats'},
      );
      return SabServerStats.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// SABnzbd version string.
  Future<String> getVersion() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api',
        queryParameters: <String, dynamic>{'mode': 'version'},
      );
      return (resp.data as Map<String, dynamic>)['version']?.toString() ?? '';
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Sets the global download speed limit as a percentage (0 = unlimited).
  Future<void> setSpeedLimit(int percent) => _simple(<String, dynamic>{
        'mode': 'config',
        'name': 'speedlimit',
        'value': percent,
      });

  /// Removes one history entry (and its downloaded files).
  Future<void> deleteHistoryItem(String nzoId) => _simple(<String, dynamic>{
        'mode': 'history',
        'name': 'delete',
        'value': nzoId,
        'del_files': 1,
      });

  /// Retries a failed history entry.
  Future<void> retryHistoryItem(String nzoId) => _simple(<String, dynamic>{
        'mode': 'retry',
        'value': nzoId,
      });

  Future<void> _simple(Map<String, dynamic> params) async {
    try {
      await _dio.get<dynamic>('api', queryParameters: params);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
