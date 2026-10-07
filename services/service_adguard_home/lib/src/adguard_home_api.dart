import 'package:dio/dio.dart';

import 'adguard_home_errors.dart';
import 'adguard_home_session.dart';
import 'models/adguard_home_filtering.dart';
import 'models/adguard_home_json.dart';
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

  Future<Map<String, dynamic>> _get(String path) => _session.run(() async {
        final Response<dynamic> response = await _dio.get<dynamic>(path);
        final Object? data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw const AdguardHomeUnexpectedAnswer();
      });

  Future<void> _post(String path, Map<String, dynamic> body) =>
      _session.run(() async {
        await _dio.post<dynamic>(path, data: body);
      });
}
