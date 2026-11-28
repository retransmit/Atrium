import 'dart:convert';

import 'package:dio/dio.dart';

import 'models/technitium_blocked_zone.dart';
import 'models/technitium_query_log.dart';
import 'models/technitium_settings.dart';
import 'models/technitium_stats.dart';
import 'models/technitium_status.dart';
import 'models/technitium_top_stats.dart';
import 'technitium_errors.dart';
import 'technitium_session.dart';

/// HTTP API client for Technitium DNS Server.
class TechnitiumApi {
  TechnitiumApi(this._dio, [TechnitiumSession? session])
      : _session = session ?? TechnitiumSession();

  final Dio _dio;
  final TechnitiumSession _session;
  String? _queryLoggerName;
  String? _queryLoggerClassPath;

  TechnitiumSession get session => _session;

  /// Validates and extracts JSON map from a response.
  Map<String, dynamic> _unwrapResponse(Response<dynamic> response) {
    Object? data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        throw const TechnitiumUnexpectedAnswer('Response is not valid JSON');
      }
    }
    if (data is! Map) {
      throw const TechnitiumUnexpectedAnswer(
        'Response body is not a JSON object',
      );
    }
    final Map<String, dynamic> map =
        data is Map<String, dynamic> ? data : data.cast<String, dynamic>();

    final Object? status = map['status'];
    if (status == 'invalid-token' || status == '2fa-required') {
      _session.recordAuthRefusal();
      final String msg = (map['errorMessage'] ??
              (status == '2fa-required'
                  ? 'Two-factor authentication required'
                  : 'Invalid or expired API token'))
          .toString();
      throw TechnitiumAuthException(msg);
    }
    if (status == 'error') {
      final String msg =
          (map['errorMessage'] ?? map['message'] ?? 'Technitium API error')
              .toString();
      final String lower = msg.toLowerCase();
      if (lower.contains('token') ||
          lower.contains('auth') ||
          lower.contains('unauthorized') ||
          lower.contains('forbidden') ||
          lower.contains('invalid session')) {
        _session.recordAuthRefusal();
        throw TechnitiumAuthException(msg);
      }
      throw TechnitiumRequestException(msg);
    }
    if (status != 'ok' && status != 'success') {
      throw const TechnitiumUnexpectedAnswer('Response status was not ok');
    }
    _session.resetAuthRefusal();
    return map;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(validateStatus: (int? s) => s != null && s < 500),
      );
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        _session.recordAuthRefusal();
        throw const TechnitiumAuthException();
      }
      if (resp.statusCode == 404) {
        throw const TechnitiumUnexpectedAnswer('Endpoint not found (404)');
      }
      if (resp.statusCode != null && resp.statusCode! >= 400) {
        throw TechnitiumRequestException('HTTP ${resp.statusCode}');
      }
      return _unwrapResponse(resp);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _session.recordAuthRefusal();
        throw const TechnitiumAuthException();
      }
      rethrow;
    }
  }

  /// Checks server status and health via `/api/status`.
  Future<TechnitiumStatus> getStatus() async {
    final DateTime readAt = DateTime.now();
    final Map<String, dynamic> json = await _get('api/status');
    // Also try to inspect settings if available, else return status from response
    return TechnitiumStatus.fromJson(json, readAt: readAt);
  }

  /// Retrieves dashboard stats for the given range ([type]: `LastHour`, `LastDay`, `LastWeek`, `LastMonth`).
  Future<TechnitiumStats> getStats({String type = 'LastDay'}) async {
    Map<String, dynamic> json;
    try {
      json = await _get(
        'api/dashboard/stats/get',
        query: <String, dynamic>{'type': type, 'utc': true},
      );
    } on TechnitiumUnexpectedAnswer {
      json = await _get(
        'api/dashboard/stats',
        query: <String, dynamic>{'type': type, 'utc': true},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        json = await _get(
          'api/dashboard/stats',
          query: <String, dynamic>{'type': type, 'utc': true},
        );
      } else {
        rethrow;
      }
    }
    return TechnitiumStats.fromJson(json);
  }

  /// Retrieves top statistics (top clients, top domains, and top blocked domains).
  Future<TechnitiumTopStats> getTopStats({String type = 'LastDay'}) async {
    Map<String, dynamic> json;
    try {
      json = await _get(
        'api/dashboard/stats/get',
        query: <String, dynamic>{'type': type, 'utc': true},
      );
    } on TechnitiumUnexpectedAnswer {
      json = await _get(
        'api/dashboard/stats',
        query: <String, dynamic>{'type': type, 'utc': true},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        json = await _get(
          'api/dashboard/stats',
          query: <String, dynamic>{'type': type, 'utc': true},
        );
      } else {
        rethrow;
      }
    }
    return TechnitiumTopStats.fromJson(json);
  }

  /// Retrieves server configuration and blocking settings via `/api/settings/get`.
  Future<TechnitiumSettings> getSettings() async {
    final Map<String, dynamic> json = await _get('api/settings/get');
    return TechnitiumSettings.fromJson(json);
  }

  /// Toggles ad-blocking on or off via `/api/settings/set`.
  Future<void> setBlocking({required bool enabled}) async {
    await _get(
      'api/settings/set',
      query: <String, dynamic>{'enableBlocking': enabled},
    );
  }

  /// Temporarily pauses blocking for integer [minutes].
  ///
  /// Passing `minutes: 0` re-enables blocking immediately.
  Future<void> temporaryDisableBlocking({required num minutes}) async {
    await _get(
      'api/settings/temporaryDisableBlocking',
      query: <String, dynamic>{'minutes': minutes.toInt()},
    );
  }

  /// Forces an immediate update and download of all configured block lists.
  Future<void> forceUpdateBlockLists() async {
    try {
      await _get('api/settings/forceUpdateBlockLists');
    } on TechnitiumUnexpectedAnswer {
      await _get('api/blockLists/forceUpdate');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await _get('api/blockLists/forceUpdate');
      } else {
        rethrow;
      }
    }
  }

  /// Flushes the DNS resolver cache via `/api/cache/flush`.
  Future<void> flushDnsCache() async {
    await _get('api/cache/flush');
  }

  /// Lists manually configured blocked zones / domains.
  ///
  /// Uses `/api/blocked/export` for a flat domain list on Technitium v13+,
  /// falling back to `/api/blocked/list` (supporting both object-with-`zones`
  /// and flat-array shapes).
  Future<List<TechnitiumBlockedZone>> listBlockedZones() async {
    try {
      final Response<dynamic> exportResp = await _dio.get<dynamic>(
        'api/blocked/export',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (int? s) => s != null && s < 500,
        ),
      );
      if (exportResp.statusCode == 401 || exportResp.statusCode == 403) {
        _session.recordAuthRefusal();
        throw const TechnitiumAuthException();
      }
      if (exportResp.statusCode == 200 && exportResp.data is String) {
        final String text = (exportResp.data as String).trim();
        if (text.isEmpty) return const <TechnitiumBlockedZone>[];
        if (text.startsWith('{')) {
          final Object? decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic> &&
              decoded['status'] != null &&
              decoded['status'] != 'ok') {
            _unwrapResponse(exportResp);
          }
        } else {
          _session.resetAuthRefusal();
          return <TechnitiumBlockedZone>[
            for (final String line in text.split(RegExp(r'\r?\n')))
              if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
                TechnitiumBlockedZone(domain: line.trim()),
          ];
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _session.recordAuthRefusal();
        throw const TechnitiumAuthException();
      }
      if (e.response?.statusCode != 404) rethrow;
    }

    Map<String, dynamic> json;
    try {
      json = await _get('api/blocked/list');
    } on TechnitiumUnexpectedAnswer {
      json = await _get('api/blockedZones/list');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        json = await _get('api/blockedZones/list');
      } else {
        rethrow;
      }
    }

    final Object? raw =
        json['response'] ?? json['blockedZones'] ?? json['zones'];
    final List<TechnitiumBlockedZone> result = <TechnitiumBlockedZone>[];
    if (raw is List) {
      for (final Object? item in raw) {
        if (item is String) {
          result.add(TechnitiumBlockedZone(domain: item));
        } else if (item is Map<String, dynamic>) {
          result.add(TechnitiumBlockedZone.fromJson(item));
        } else if (item is Map) {
          result.add(
            TechnitiumBlockedZone.fromJson(item.cast<String, dynamic>()),
          );
        }
      }
    } else if (raw is Map) {
      final Object? zones = raw['zones'] ?? raw['records'];
      if (zones is List) {
        for (final Object? item in zones) {
          if (item is String && item.isNotEmpty) {
            result.add(TechnitiumBlockedZone(domain: item));
          } else if (item is Map) {
            result.add(
              TechnitiumBlockedZone.fromJson(item.cast<String, dynamic>()),
            );
          }
        }
      }
    }
    return result;
  }

  /// Adds a domain or zone to the block list.
  Future<void> addBlockedZone(String domain) async {
    try {
      await _get('api/blocked/add', query: <String, dynamic>{'domain': domain});
    } on TechnitiumUnexpectedAnswer {
      await _get(
        'api/blockedZones/add',
        query: <String, dynamic>{'domain': domain},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await _get(
          'api/blockedZones/add',
          query: <String, dynamic>{'domain': domain},
        );
      } else {
        rethrow;
      }
    }
  }

  /// Deletes a domain or zone from the block list.
  Future<void> deleteBlockedZone(String domain) async {
    try {
      await _get(
        'api/blocked/delete',
        query: <String, dynamic>{'domain': domain},
      );
    } on TechnitiumUnexpectedAnswer {
      await _get(
        'api/blockedZones/delete',
        query: <String, dynamic>{'domain': domain},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await _get(
          'api/blockedZones/delete',
          query: <String, dynamic>{'domain': domain},
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _ensureQueryLoggerApp() async {
    if (_queryLoggerName != null && _queryLoggerClassPath != null) return;
    final Map<String, dynamic> json = await _get('api/apps/list');
    final Object? response = json['response'];
    final Object? apps = response is Map ? response['apps'] : json['apps'];
    if (apps is List) {
      for (final Object? app in apps) {
        if (app is! Map) continue;
        final String appName = (app['name'] ?? '').toString();
        final Object? dnsApps = app['dnsApps'];
        if (dnsApps is List) {
          for (final Object? dnsApp in dnsApps) {
            if (dnsApp is Map && dnsApp['isQueryLogger'] == true) {
              _queryLoggerName = appName;
              _queryLoggerClassPath = (dnsApp['classPath'] ?? '').toString();
              return;
            }
          }
        }
      }
    }
    throw const TechnitiumRequestException(
      'No DNS Query Logger app is installed on this Technitium server',
    );
  }

  /// Queries DNS logs with optional pagination and filters.
  Future<TechnitiumQueryLogPage> getQueryLogs({
    int pageNumber = 1,
    int entriesPerPage = 50,
    String? filter,
    String? domain,
  }) async {
    await _ensureQueryLoggerApp();
    final Map<String, dynamic> query = <String, dynamic>{
      'name': _queryLoggerName,
      'classPath': _queryLoggerClassPath,
      'pageNumber': pageNumber,
      'entriesPerPage': entriesPerPage,
      'descendingOrder': true,
    };
    if (filter != null && filter.isNotEmpty && filter.toLowerCase() != 'all') {
      query['filter'] = filter;
      query['responseType'] = filter;
    }
    if (domain != null && domain.isNotEmpty) {
      query['search'] = domain;
      query['domain'] = domain;
      query['qname'] = domain;
    }

    final Map<String, dynamic> json =
        await _get('api/logs/query', query: query);
    return TechnitiumQueryLogPage.fromJson(json);
  }
}
