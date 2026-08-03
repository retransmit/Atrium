import 'dart:convert';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_activity_concurrent.dart';
import 'models/tracearr_activity_engagement.dart';
import 'models/tracearr_activity_locations.dart';
import 'models/tracearr_activity_platform.dart';
import 'models/tracearr_activity_play.dart';
import 'models/tracearr_activity_play_dow.dart';
import 'models/tracearr_activity_play_hod.dart';
import 'models/tracearr_activity_quality.dart';
import 'models/tracearr_activity_stats.dart';
import 'models/tracearr_completion.dart';
import 'models/tracearr_dashboard_stats.dart';
import 'models/tracearr_library_roi.dart';
import 'models/tracearr_library_storage.dart';
import 'models/tracearr_library_watch_activity.dart';
import 'models/tracearr_patterns.dart';
import 'models/tracearr_session.dart';
import 'models/tracearr_stats.dart';
import 'models/tracearr_top_movies.dart';
import 'models/tracearr_top_shows.dart';

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

  /// Generates a proxied image URL through Tracearr's internal backend proxy,
  /// allowing authenticated retrieval of Plex and Jellyfin posters/thumbnails.
  String? proxyImageUrl({
    required String? path,
    String? serverId,
    int? width,
    int? height,
    String? fallback,
  }) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (serverId == null || serverId.isEmpty) return null;
    final String base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final Map<String, String> query = <String, String>{
      'server': serverId,
      'url': path,
      if (width != null) 'width': width.toString(),
      if (height != null) 'height': height.toString(),
      if (fallback != null && fallback.isNotEmpty) 'fallback': fallback,
      if (token != null && token!.isNotEmpty) 'token': token!,
    };
    final Uri uri = Uri.parse('$base/api/v1/images/proxy').replace(queryParameters: query);
    return uri.toString();
  }

  String _formatIsoDate(DateTime dt) {
    final String year = dt.year.toString().padLeft(4, '0');
    final String month = dt.month.toString().padLeft(2, '0');
    final String day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-${day}T00:00:00.000Z';
  }

  /// Retrieves the active sessions from the internal Tracearr API.
  Future<TracearrActiveSessions> getActiveSessions() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/v1/sessions/active');
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

  Future<TracearrStats> getStats(
    List<String> serverIds,
    String timezone, {
    String period = 'month',
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'timezone': timezone,
        'period': period,
      };
      if (from != null) query['startDate'] = _formatIsoDate(from);
      if (to != null) query['endDate'] = _formatIsoDate(to);
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/v1/library/stats',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );
      return TracearrStats.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<TracearrActivityStats> getActivityStats(
    List<String> serverIds,
    String timezone, {
    String period = 'month',
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'timezone': timezone,
        'period': period,
      };
      if (from != null) query['startDate'] = _formatIsoDate(from);
      if (to != null) query['endDate'] = _formatIsoDate(to);

      final Options opts = Options(listFormat: ListFormat.multi);
      final Future<Response<dynamic>> playsReq = _dio.get<dynamic>('api/v1/stats/plays', queryParameters: query, options: opts);
      final Future<Response<dynamic>> dowReq = _dio.get<dynamic>('api/v1/stats/plays-by-dayofweek', queryParameters: query, options: opts);
      final Future<Response<dynamic>> hodReq = _dio.get<dynamic>('api/v1/stats/plays-by-hourofday', queryParameters: query, options: opts);
      final Future<Response<dynamic>> platformsReq = _dio.get<dynamic>('api/v1/stats/platforms', queryParameters: query, options: opts);
      final Future<Response<dynamic>> qualityReq = _dio.get<dynamic>('api/v1/stats/quality', queryParameters: query, options: opts);
      final Future<Response<dynamic>> concurrentReq = _dio.get<dynamic>('api/v1/stats/concurrent', queryParameters: query, options: opts);
      final Future<Response<dynamic>> engagementReq = _dio.get<dynamic>('api/v1/stats/engagement', queryParameters: query, options: opts);

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
        options: Options(listFormat: ListFormat.multi),
      );
      if (resp.data is Map<String, dynamic> && resp.data['data'] is List) {
        return (resp.data['data'] as List).map((dynamic e) => TracearrSession.fromJson(e as Map<String, dynamic>)).toList();
      }
      return <TracearrSession>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<TracearrActivityLocationsResponse> getLocations(List<String> serverIds, String timezone) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'timezone': timezone,
        'period': 'month',
      };
      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/stats/locations',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );
      return TracearrActivityLocationsResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch locations: $e');
    }
  }

  Future<TracearrDashboardStats> getDashboardStats(List<String> serverIds, String timezone) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/stats/dashboard',
        queryParameters: <String, dynamic>{
          'serverIds': serverIds,
          'timezone': timezone,
        },
        options: Options(listFormat: ListFormat.multi),
      );
      
      dynamic rawData = res.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      Map<String, dynamic> data = <String, dynamic>{};
      if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else if (rawData is List && rawData.isNotEmpty) {
        final dynamic first = rawData.first;
        if (first is Map) {
          data = Map<String, dynamic>.from(first);
        }
      }
      
      if (data.containsKey('data')) {
        if (data['data'] is Map) {
          data = Map<String, dynamic>.from(data['data'] as Map);
        } else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
          final dynamic first = (data['data'] as List).first;
          if (first is Map) {
            data = Map<String, dynamic>.from(first);
          }
        }
      }

      double parseDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }
      
      int parseInt(dynamic value) {
        if (value == null) return 0;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }

      int activeStreams = parseInt(data['activeStreams'] ?? data['active_streams']);
      int todayPlays = parseInt(data['todayPlays'] ?? data['today_plays']);
      int todaySessions = parseInt(data['todaySessions'] ?? data['today_sessions']);
      double watchTimeHours = parseDouble(data['watchTimeHours'] ?? data['watch_time_hours']);
      int alertsLast24h = parseInt(data['alertsLast24h'] ?? data['alerts_last_24h']);
      int activeUsersToday = parseInt(data['activeUsersToday'] ?? data['active_users_today']);

      final TracearrDashboardStats stats = TracearrDashboardStats(
        activeStreams: activeStreams,
        todayPlays: todayPlays,
        todaySessions: todaySessions,
        watchTimeHours: watchTimeHours,
        alertsLast24h: alertsLast24h,
        activeUsersToday: activeUsersToday,
      );
      
      return stats;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  Future<TracearrLibraryWatchResponse> getLibraryWatchItems({
    required List<String> serverIds,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'page': page,
        'pageSize': pageSize,
      };

      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/library/watch',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (rawData is Map) {
        jsonMap = Map<String, dynamic>.from(rawData);
      }

      return TracearrLibraryWatchResponse.fromJson(jsonMap);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch library watch items: $e');
    }
  }

  Future<TracearrLibraryRoiResponse> getLibraryRoiItems({
    required List<String> serverIds,
    int page = 1,
    int pageSize = 10,
    String sortBy = 'watch_hours_per_gb',
    String sortOrder = 'desc',
    required String timezone,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'page': page,
        'pageSize': pageSize,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        'timezone': timezone,
      };

      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/library/roi',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (rawData is Map) {
        jsonMap = Map<String, dynamic>.from(rawData);
      }

      return TracearrLibraryRoiResponse.fromJson(jsonMap);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch library ROI items: $e');
    }
  }

  Future<TracearrStorageResponse> getLibraryStorage(String serverId, String period, String timezone) async {
    try {
      String formattedPeriod = period;
      if (formattedPeriod == 'month' || formattedPeriod == '30d') {
        formattedPeriod = '30d';
      } else if (formattedPeriod == 'week' || formattedPeriod == '7d') {
        formattedPeriod = '7d';
      } else if (formattedPeriod == 'year' || formattedPeriod == '1yr' || formattedPeriod == '1y') {
        formattedPeriod = '1y';
      } else if (formattedPeriod.toLowerCase() == 'all') {
        formattedPeriod = 'all';
      } else if (formattedPeriod == 'custom') {
        formattedPeriod = '30d';
      }

      final Map<String, dynamic> query = <String, dynamic>{
        'serverId': serverId,
        'period': formattedPeriod,
        'timezone': timezone,
      };
      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/library/storage',
        queryParameters: query,
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (rawData is Map) {
        jsonMap = Map<String, dynamic>.from(rawData);
      }

      return TracearrStorageResponse.fromJson(jsonMap);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch library storage stats for server $serverId: $e');
    }
  }

  Future<TracearrStorageResponse> getAggregatedLibraryStorage(List<String> serverIds, String period, String timezone) async {
    if (serverIds.isEmpty) {
      return TracearrStorageResponse.aggregate(<TracearrStorageResponse>[]);
    }
    final List<TracearrStorageResponse> responses = <TracearrStorageResponse>[];
    await Future.wait(
      serverIds.map((String id) async {
        try {
          final TracearrStorageResponse res = await getLibraryStorage(id, period, timezone);
          responses.add(res);
        } catch (_) {
          // Ignore individual server storage failures so indexed servers still render
        }
      }),
    );
    return TracearrStorageResponse.aggregate(responses);
  }

  Future<Map<String, TracearrStorageResponse>> getMultiServerLibraryStorage(List<String> serverIds, String period, String timezone) async {
    final Map<String, TracearrStorageResponse> result = <String, TracearrStorageResponse>{};
    if (serverIds.isEmpty) return result;
    await Future.wait(
      serverIds.map((String id) async {
        try {
          final TracearrStorageResponse res = await getLibraryStorage(id, period, timezone);
          result[id] = res;
        } catch (_) {
          // Ignore failures from inactive/unindexed servers
        }
      }),
    );
    return result;
  }

  Future<TracearrTopMoviesResponse> getTopMovies({
    required List<String> serverIds,
    String period = '30d',
    String sortBy = 'plays',
    String sortOrder = 'desc',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'period': period,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        'page': page,
        'pageSize': pageSize,
      };

      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/library/top-movies',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try { rawData = jsonDecode(rawData); } catch (_) {}
      }
      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (rawData is Map) {
        jsonMap = Map<String, dynamic>.from(rawData);
      }
      return TracearrTopMoviesResponse.fromJson(jsonMap);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch top movies: $e');
    }
  }

  Future<TracearrTopShowsResponse> getTopShows({
    required List<String> serverIds,
    String period = '30d',
    String sortBy = 'plays',
    String sortOrder = 'desc',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'period': period,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        'page': page,
        'pageSize': pageSize,
      };

      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/library/top-shows',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try { rawData = jsonDecode(rawData); } catch (_) {}
      }
      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (rawData is Map) {
        jsonMap = Map<String, dynamic>.from(rawData);
      }
      return TracearrTopShowsResponse.fromJson(jsonMap);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch top shows: $e');
    }
  }

  Future<TracearrCompletionSummary> getAggregatedLibraryCompletion(List<String> serverIds) async {
    final List<TracearrCompletionSummary> summaries = <TracearrCompletionSummary>[];
    await Future.wait(
      serverIds.map((String serverId) async {
        for (final String mediaType in <String>['movie', 'episode']) {
          try {
            final Map<String, dynamic> query = <String, dynamic>{
              'serverId': serverId,
              'aggregateLevel': 'item',
              'page': 1,
              'pageSize': 1,
              'mediaType': mediaType,
            };
            final Response<dynamic> res = await _dio.get<dynamic>(
              'api/v1/library/completion',
              queryParameters: query,
            );
            if (res.statusCode == 200 && res.data != null) {
              dynamic rawData = res.data;
              if (rawData is String) {
                try { rawData = jsonDecode(rawData); } catch (_) {}
              }
              if (rawData is Map) {
                final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(rawData);
                if (jsonMap['summary'] is Map) {
                  summaries.add(TracearrCompletionSummary.fromJson(Map<String, dynamic>.from(jsonMap['summary'] as Map)));
                }
              }
            }
          } catch (_) {
            // ignore
          }
        }
      }),
    );
    return TracearrCompletionSummary.aggregate(summaries);
  }

  Future<TracearrPatternsResponse> getLibraryPatterns({
    required List<String> serverIds,
    int periodWeeks = 12,
    required String timezone,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'serverIds': serverIds,
        'periodWeeks': periodWeeks,
        'timezone': timezone,
      };

      final Response<dynamic> res = await _dio.get<dynamic>(
        'api/v1/library/patterns',
        queryParameters: query,
        options: Options(listFormat: ListFormat.multi),
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try { rawData = jsonDecode(rawData); } catch (_) {}
      }
      Map<String, dynamic> jsonMap = <String, dynamic>{};
      if (rawData is Map) {
        jsonMap = Map<String, dynamic>.from(rawData);
      }
      return TracearrPatternsResponse.fromJson(jsonMap);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    } catch (e) {
      throw Exception('Failed to fetch library patterns: $e');
    }
  }
}

