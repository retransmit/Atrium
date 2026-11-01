import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/cleanuparr_event.dart';
import 'models/cleanuparr_job.dart';
import 'models/cleanuparr_stats.dart';
import 'models/cleanuparr_status.dart';
import 'models/cleanuparr_strike.dart';

/// REST client for communicating with a Cleanuparr daemon instance.
class CleanuparrApi {
  const CleanuparrApi(this._dio);

  final Dio _dio;

  /// Runs one request, turning a Dio failure into the [NetworkException] the
  /// screens word for people, rather than letting the raw Dio text through.
  Future<T> _send<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Extracts the items list from either a bare JSON array or a paginated
  /// envelope (`items` / `results` / `data` keys).
  static List<dynamic>? _extractList(
    dynamic data, {
    List<String> envelopeKeys = const <String>['items', 'results', 'data'],
  }) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      for (final String key in envelopeKeys) {
        final dynamic list = data[key];
        if (list is List) {
          return list;
        }
      }
    }
    return null;
  }

  /// Fetches system information, uptime, memory, and Arr/client connections.
  Future<CleanuparrStatus> getStatus() async {
    final Response<dynamic> response =
        await _send(() => _dio.get<dynamic>('api/status'));
    final dynamic data = response.data;

    List<dynamic>? rawClients;
    try {
      final Response<dynamic> clientResp =
          await _dio.get<dynamic>('api/status/download-client');
      final dynamic clientData = clientResp.data;
      if (clientData is Map<String, dynamic>) {
        final dynamic list = clientData['clients'] ?? clientData['Clients'];
        if (list is List) rawClients = list;
      } else if (clientData is List) {
        rawClients = clientData;
      }
    } catch (_) {
      // Optional endpoint; ignore if not reachable
    }

    if (data is Map<String, dynamic>) {
      final Map<String, dynamic> merged = Map<String, dynamic>.from(data);
      if (rawClients != null && !merged.containsKey('downloadClients')) {
        merged['downloadClients'] = rawClients;
      }
      return CleanuparrStatus.fromJson(merged);
    }
    return const CleanuparrStatus(version: 'Unknown', appName: 'Cleanuparr');
  }

  /// Fetches operational statistics rolled up over the requested [hours] (e.g. 24, 168, 720).
  Future<CleanuparrStats> getStats({int hours = 168}) async {
    final Response<dynamic> response = await _send(
      () => _dio.get<dynamic>(
        'api/v2/stats',
        queryParameters: <String, dynamic>{
          'hours': hours,
          'includeDryRun': false,
        },
      ),
    );
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      return CleanuparrStats.fromJson(data, hours: hours);
    }
    return CleanuparrStats(hours: hours);
  }

  /// Lists download items that currently hold active strikes.
  Future<List<CleanuparrStrikeItem>> getStrikes({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final Response<dynamic> response = await _send(
      () => _dio.get<dynamic>(
        'api/strikes',
        queryParameters: params,
      ),
    );
    final dynamic data = response.data;

    final List<CleanuparrStrikeItem> items = <CleanuparrStrikeItem>[];
    List<dynamic>? rawList;

    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      // Handles paginated responses with results or items list
      final dynamic list = data['items'] ?? data['results'] ?? data['data'];
      if (list is List) {
        rawList = list;
      }
    }

    if (rawList != null) {
      for (final dynamic item in rawList) {
        if (item is Map<String, dynamic>) {
          items.add(CleanuparrStrikeItem.fromJson(item));
        }
      }
    }

    return items;
  }

  /// Resets and clears all strikes for a download item by [downloadItemId].
  Future<void> deleteStrike(String downloadItemId) async {
    final String encodedId = Uri.encodeComponent(downloadItemId);
    await _send(() => _dio.delete<void>('api/strikes/$encodedId'));
  }

  /// Returns how many download items hold strikes and have not been removed,
  /// independent of any client-side search.
  ///
  /// The ledger keeps an item Cleanuparr already removed (`isRemoved`) until
  /// its strikes age out, so the envelope's `totalCount` alone overstates what
  /// is still active. This reads one page at the backend's largest size (500,
  /// Pagination.MaxPageSize) and counts the items not removed; items past that
  /// page are counted as active, since their state is not known.
  Future<int> getActiveStrikesCount() async {
    const int pageSize = 500;
    final Response<dynamic> response = await _send(
      () => _dio.get<dynamic>(
        'api/strikes',
        queryParameters: <String, dynamic>{'page': 1, 'pageSize': pageSize},
      ),
    );
    final dynamic data = response.data;
    final List<dynamic> rawList = _extractList(data) ?? const <dynamic>[];
    final List<CleanuparrStrikeItem> items = <CleanuparrStrikeItem>[
      for (final dynamic item in rawList)
        if (item is Map<String, dynamic>) CleanuparrStrikeItem.fromJson(item),
    ];
    final int notRemoved =
        items.where((CleanuparrStrikeItem i) => !i.isRemoved).length;
    final dynamic total = data is Map<String, dynamic> ? data['totalCount'] : null;
    final int beyondPage =
        total is num && total.toInt() > items.length ? total.toInt() - items.length : 0;
    return notRemoved + beyondPage;
  }

  /// Fetches historical audit and operational events as a single page.
  Future<List<CleanuparrEvent>> getEvents({
    int page = 1,
    int pageSize = 50,
    String? eventType,
    String? severity,
    String? search,
  }) =>
      getEventsPage(
        page: page,
        pageSize: pageSize,
        eventType: eventType,
        severity: severity,
        search: search,
      ).then((CleanuparrEventPage result) => result.items);

  /// Fetches one page of historical audit and operational events, carrying
  /// pagination metadata (`totalCount`, `totalPages`) so callers can walk
  /// subsequent pages. The real backend serves this as
  /// `PaginatedResult<EventListItem>`.
  Future<CleanuparrEventPage> getEventsPage({
    int page = 1,
    int pageSize = 50,
    String? eventType,
    String? severity,
    String? search,
  }) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final Response<dynamic> response = await _send(
      () => _dio.get<dynamic>(
        'api/events',
        queryParameters: params,
      ),
    );
    final dynamic data = response.data;

    final List<CleanuparrEvent> events = <CleanuparrEvent>[];
    int totalCount = 0;
    int totalPages = 1;

    if (data is Map<String, dynamic>) {
      final List<dynamic>? list = _extractList(data);
      if (list != null) {
        for (final dynamic item in list) {
          if (item is Map<String, dynamic>) {
            events.add(CleanuparrEvent.fromJson(item));
          }
        }
      }
      final dynamic rawTotal = data['totalCount'];
      final dynamic rawPages = data['totalPages'];
      if (rawTotal is num) totalCount = rawTotal.toInt();
      if (rawPages is num) totalPages = rawPages.toInt();
      if (totalCount == 0 && events.isNotEmpty) {
        totalCount = events.length;
      }
    } else {
      final List<dynamic>? rawList = _extractList(data);
      if (rawList != null) {
        for (final dynamic item in rawList) {
          if (item is Map<String, dynamic>) {
            events.add(CleanuparrEvent.fromJson(item));
          }
        }
      }
      totalCount = events.length;
    }

    return CleanuparrEventPage(
      items: List<CleanuparrEvent>.unmodifiable(events),
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
    );
  }

  /// Lists registered background jobs and their execution schedules.
  Future<List<CleanuparrJob>> getJobs() async {
    final Response<dynamic> response =
        await _send(() => _dio.get<dynamic>('api/jobs'));
    final dynamic data = response.data;

    final List<CleanuparrJob> jobs = <CleanuparrJob>[];
    List<dynamic>? rawList;

    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      final dynamic list = data['jobs'] ?? data['items'] ?? data['data'];
      if (list is List) {
        rawList = list;
      }
    }

    if (rawList != null) {
      for (final dynamic item in rawList) {
        if (item is Map<String, dynamic>) {
          jobs.add(CleanuparrJob.fromJson(item));
        }
      }
    }

    return jobs;
  }

  /// Triggers immediate on-demand execution of a background job by [jobType].
  Future<void> triggerJob(String jobType) async {
    final String encodedJob = Uri.encodeComponent(jobType);
    await _send(() => _dio.post<void>('api/jobs/$encodedJob/trigger'));
  }
}

/// One page of audit events plus the real backend's pagination metadata, so
/// callers can fetch subsequent pages until `totalPages` is exhausted.
class CleanuparrEventPage {
  const CleanuparrEventPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<CleanuparrEvent> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  bool get hasNext => page < totalPages;
}
