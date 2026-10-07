import 'package:dio/dio.dart';

import 'adguard_home_errors.dart';
import 'adguard_home_session.dart';
import 'models/adguard_home_access.dart';
import 'models/adguard_home_filtering.dart';
import 'models/adguard_home_json.dart';
import 'models/adguard_home_query_log.dart';
import 'models/adguard_home_stats.dart';
import 'models/adguard_home_status.dart';

/// AdGuard Home's HTTP API, the part under `control/`.
///
/// The Dio it is given signs each request with HTTP Basic. Every call goes
/// through the instance's [AdguardHomeSession], which is what keeps a wrong
/// password from being sent more than once.
class AdguardHomeApi {
  AdguardHomeApi(
    this._dio,
    this._session, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Dio _dio;
  final AdguardHomeSession _session;
  final DateTime Function() _now;

  /// How many entries one request for the query log asks for.
  static const int queryLogPageSize = 50;

  /// `GET control/status`.
  Future<AdguardHomeStatus> getStatus() async {
    final Map<String, dynamic> json = await _get('control/status');
    return AdguardHomeStatus.fromJson(json, readAt: _now());
  }

  /// `GET control/stats`.
  Future<AdguardHomeStats> getStats() async =>
      AdguardHomeStats.fromJson(await _get('control/stats'));

  /// `GET control/filtering/status`.
  Future<AdguardHomeFiltering> getFiltering() async =>
      AdguardHomeFiltering.fromJson(await _get('control/filtering/status'));

  /// How far back the statistics go, from `GET control/stats/config`.
  Future<Duration> getStatsPeriod() async {
    final Map<String, dynamic> json = await _get('control/stats/config');
    return Duration(milliseconds: readInt(json['interval']));
  }

  /// `POST control/protection`.
  ///
  /// With [enabled] false and a [pause], protection comes back on by itself
  /// after that long. With no [pause] it stays off until turned back on.
  Future<void> setProtection({required bool enabled, Duration? pause}) =>
      _post('control/protection', <String, dynamic>{
        'enabled': enabled,
        if (!enabled && pause != null) 'duration': pause.inMilliseconds,
      });

  /// `POST control/filtering/set_rules`: replaces the custom filtering
  /// rules with [rules], one rule per entry.
  Future<void> setUserRules(List<String> rules) =>
      _post('control/filtering/set_rules', <String, dynamic>{'rules': rules});

  /// `GET control/querylog`: the entries older than [olderThan], newest
  /// first, or the newest of all when it is empty.
  ///
  /// [olderThan] is the `oldest` of the page before, exactly as the server
  /// wrote it. [search] matches the domain and the client; in double quotes
  /// it has to match whole.
  Future<AdguardHomeQueryLogPage> getQueryLog({
    String olderThan = '',
    int limit = queryLogPageSize,
    String search = '',
    AdguardHomeLogFilter filter = AdguardHomeLogFilter.all,
  }) async {
    final Map<String, dynamic> json = await _get(
      'control/querylog',
      <String, dynamic>{
        if (olderThan.isNotEmpty) 'older_than': olderThan,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (filter != AdguardHomeLogFilter.all) 'response_status': filter.query,
      },
    );
    return AdguardHomeQueryLogPage.fromJson(json);
  }

  /// `GET control/querylog/config`.
  Future<AdguardHomeQueryLogConfig> getQueryLogConfig() async =>
      AdguardHomeQueryLogConfig.fromJson(
        await _get('control/querylog/config'),
      );

  /// `POST control/querylog_clear`: throws the whole log away.
  Future<void> clearQueryLog() => _post('control/querylog_clear');

  /// `GET control/access/list`.
  Future<AdguardHomeAccessList> getAccessList() async =>
      AdguardHomeAccessList.fromJson(await _get('control/access/list'));

  /// `POST control/access/set`: replaces all three lists with those of
  /// [list].
  Future<void> setAccessList(AdguardHomeAccessList list) =>
      _post('control/access/set', list.toJson());

  /// The clients the server has settings for, from `GET control/clients`.
  Future<List<AdguardHomeClientRef>> getPersistentClients() async =>
      AdguardHomeClientRef.listFromJson(await _get('control/clients'));

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) =>
      _session.run(() async {
        final Response<dynamic> response =
            await _dio.get<dynamic>(path, queryParameters: query);
        final Object? data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw const AdguardHomeUnexpectedAnswer();
      });

  Future<void> _post(String path, [Map<String, dynamic>? body]) =>
      _session.run(() async {
        await _dio.post<dynamic>(path, data: body);
      });
}
