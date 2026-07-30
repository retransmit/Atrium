import 'dart:convert';
import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_stats.dart';
import 'models/tracearr_session.dart';

/// Thin typed client over the Tracearr API.
class TracearrApi {
  TracearrApi(this._dio, {this.token});

  final Dio _dio;
  final String? token;

  String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final String base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    if (token == null || token!.isEmpty) return '$base$cleanPath';
    final String sep = cleanPath.contains('?') ? '&' : '?';
    return '$base$cleanPath${sep}token=$token';
  }

  /// Retrieves the active sessions from the internal Tracearr API.
  Future<TracearrActiveSessions> getActiveSessions() async {
    try {
      try {
        File('/data/user/0/app.atrium/app_flutter/tracearr_token.txt').writeAsStringSync(token ?? 'none');
      } catch (_) {}
      final Response<dynamic> resp = await _dio.get<dynamic>('api/v1/sessions/active');
      try {
        File('/home/blazar/Projects/Atrium/tracearr_payload_dump.json').writeAsStringSync(jsonEncode(resp.data));
      } catch (_) {}
      if (resp.data is List) {
        return TracearrActiveSessions(
          sessions: (resp.data as List).map((dynamic e) => TracearrSession.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return TracearrActiveSessions.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<TracearrStats> getStats(List<String> serverIds, String timezone) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'timezone': timezone,
      };
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/v1/library/stats',
        queryParameters: query,
      );
      return TracearrStats.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
  Future<List<TracearrSession>> getHistory(List<String> serverIds, {int page = 1}) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'pageSize': 50,
        'page': page,
      };
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/v1/sessions/history',
        queryParameters: query,
      );
      try {
        File('/home/blazar/Projects/Atrium/tracearr_history_dump.json').writeAsStringSync(jsonEncode(resp.data));
      } catch (e) {
        print('Dump failed: $e');
      }
      if (resp.data is Map<String, dynamic> && resp.data['data'] is List) {
        return (resp.data['data'] as List).map((dynamic e) => TracearrSession.fromJson(e as Map<String, dynamic>)).toList();
      }
      return <TracearrSession>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
