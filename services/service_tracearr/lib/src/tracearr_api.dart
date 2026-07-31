import 'dart:convert';
import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_activity_platform.dart';
import 'models/tracearr_activity_play.dart';
import 'models/tracearr_activity_play_dow.dart';
import 'models/tracearr_activity_play_hod.dart';
import 'models/tracearr_activity_stats.dart';
import 'models/tracearr_activity_quality.dart';
import 'models/tracearr_activity_concurrent.dart';
import 'models/tracearr_activity_engagement.dart';
import 'models/tracearr_session.dart';
import 'models/tracearr_stats.dart';

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

  Future<TracearrActivityStats> getActivityStats(List<String> serverIds, String timezone) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'timezone': timezone,
        'period': 'month', // fixed to month for now
      };

      final Future<Response<dynamic>> playsReq = _dio.get<dynamic>('api/v1/stats/plays', queryParameters: query);
      final Future<Response<dynamic>> dowReq = _dio.get<dynamic>('api/v1/stats/plays-by-dayofweek', queryParameters: query);
      final Future<Response<dynamic>> hodReq = _dio.get<dynamic>('api/v1/stats/plays-by-hourofday', queryParameters: query);
      final Future<Response<dynamic>> platformsReq = _dio.get<dynamic>('api/v1/stats/platforms', queryParameters: query);
      final Future<Response<dynamic>> qualityReq = _dio.get<dynamic>('api/v1/stats/quality', queryParameters: query);
      final Future<Response<dynamic>> concurrentReq = _dio.get<dynamic>('api/v1/stats/concurrent', queryParameters: query);
      final Future<Response<dynamic>> engagementReq = _dio.get<dynamic>('api/v1/stats/engagement', queryParameters: query);

      final List<Response<dynamic>> resps = await Future.wait(<Future<Response<dynamic>>>[playsReq, dowReq, hodReq, platformsReq, qualityReq, concurrentReq, engagementReq]);

      final List<TracearrActivityPlay> plays = <TracearrActivityPlay>[];
      if (resps[0].data is Map<String, dynamic> && resps[0].data['data'] is List) {
        for (final dynamic item in resps[0].data['data'] as List<dynamic>) {
          plays.add(TracearrActivityPlay.fromJson(item as Map<String, dynamic>));
        }
      }

      final List<TracearrActivityPlayDow> playsDow = <TracearrActivityPlayDow>[];
      if (resps[1].data is Map<String, dynamic> && resps[1].data['data'] is List) {
        for (final dynamic item in resps[1].data['data'] as List<dynamic>) {
          playsDow.add(TracearrActivityPlayDow.fromJson(item as Map<String, dynamic>));
        }
      }

      final List<TracearrActivityPlayHod> playsHod = <TracearrActivityPlayHod>[];
      if (resps[2].data is Map<String, dynamic> && resps[2].data['data'] is List) {
        for (final dynamic item in resps[2].data['data'] as List<dynamic>) {
          playsHod.add(TracearrActivityPlayHod.fromJson(item as Map<String, dynamic>));
        }
      }

      final List<TracearrActivityPlatform> platforms = <TracearrActivityPlatform>[];
      if (resps[3].data is Map<String, dynamic> && resps[3].data['data'] is List) {
        for (final dynamic item in resps[3].data['data'] as List<dynamic>) {
          platforms.add(TracearrActivityPlatform.fromJson(item as Map<String, dynamic>));
        }
      }

      TracearrActivityQuality quality = TracearrActivityQuality();
      if (resps[4].data is Map<String, dynamic>) {
        quality = TracearrActivityQuality.fromJson(resps[4].data as Map<String, dynamic>);
      }

      final List<TracearrActivityConcurrent> concurrent = <TracearrActivityConcurrent>[];
      if (resps[5].data is Map<String, dynamic> && resps[5].data['data'] is List) {
        for (final dynamic item in resps[5].data['data'] as List<dynamic>) {
          concurrent.add(TracearrActivityConcurrent.fromJson(item as Map<String, dynamic>));
        }
      }

      TracearrActivityEngagement engagement = TracearrActivityEngagement(summary: TracearrEngagementSummary());
      if (resps[6].data is Map<String, dynamic>) {
        engagement = TracearrActivityEngagement.fromJson(resps[6].data as Map<String, dynamic>);
      }

      return TracearrActivityStats(
        plays: plays,
        playsByDayOfWeek: playsDow,
        playsByHourOfDay: playsHod,
        platforms: platforms,
        quality: quality,
        concurrentPlays: concurrent,
        engagement: engagement,
      );
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
