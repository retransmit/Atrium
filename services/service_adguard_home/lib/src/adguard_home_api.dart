import 'package:dio/dio.dart';

import 'adguard_home_errors.dart';
import 'adguard_home_session.dart';
import 'models/adguard_home_access.dart';
import 'models/adguard_home_clients.dart';
import 'models/adguard_home_filtering.dart';
import 'models/adguard_home_filters.dart';
import 'models/adguard_home_json.dart';
import 'models/adguard_home_query_log.dart';
import 'models/adguard_home_services.dart';
import 'models/adguard_home_settings.dart';
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

  /// How long a request that makes the server fetch lists may take. The
  /// server answers only once every list is in, and a large one on a slow
  /// line takes far longer than an ordinary request is given.
  static const Duration listFetchTimeout = Duration(minutes: 3);

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

  /// `GET control/clients`: the clients with settings, the devices the
  /// server has seen, and the tags a client can be given.
  Future<AdguardHomeClientList> getClients() async =>
      AdguardHomeClientList.fromJson(await _get('control/clients'));

  /// `POST control/clients/search`: whose each of [ids] is, an id being an
  /// address, a MAC address or a ClientID. Keyed by the id asked about.
  ///
  /// Servers older than v0.107.56 have no such path and turn it down.
  Future<Map<String, AdguardHomeFoundClient>> searchClients(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <String, AdguardHomeFoundClient>{};
    final Object? answer = await _session.run(() async {
      final Response<dynamic> response = await _dio.post<dynamic>(
        'control/clients/search',
        data: <String, dynamic>{
          'clients': <Map<String, dynamic>>[
            for (final String id in ids) <String, dynamic>{'id': id},
          ],
        },
      );
      return response.data as Object?;
    });
    if (answer is! List) throw const AdguardHomeUnexpectedAnswer();
    return AdguardHomeFoundClient.mapFromJson(answer);
  }

  /// `POST control/clients/add`. [client] has to spell out every setting:
  /// what it leaves out the server takes as off.
  Future<void> addClient(Map<String, dynamic> client) =>
      _post('control/clients/add', client);

  /// `POST control/clients/update`: replaces the client now called [name]
  /// with [client], which may carry another name. What [client] leaves out
  /// the server resets.
  Future<void> updateClient(String name, Map<String, dynamic> client) =>
      _post(
        'control/clients/update',
        <String, dynamic>{'name': name, 'data': client},
      );

  /// `POST control/clients/delete`.
  Future<void> deleteClient(String name) =>
      _post('control/clients/delete', <String, dynamic>{'name': name});

  /// `GET control/blocked_services/all`: every service the server can
  /// block, with its icon. A few hundred kilobytes.
  Future<AdguardHomeServiceCatalogue> getBlockedServices() async =>
      AdguardHomeServiceCatalogue.fromJson(
        await _get('control/blocked_services/all'),
      );

  /// `GET control/safesearch/status`: the server's own safe search.
  Future<AdguardHomeSafeSearch> getSafeSearch() async =>
      AdguardHomeSafeSearch.fromJson(await _get('control/safesearch/status'));

  /// `POST control/filtering/add_url`. The server fetches the list at once,
  /// and turns it down in plain words if it cannot, or if any list, block
  /// or allow, already has that address.
  Future<void> addFilterList({
    required String name,
    required String url,
    required bool allowlist,
  }) =>
      _post(
        'control/filtering/add_url',
        <String, dynamic>{
          'name': name,
          'url': url,
          'whitelist': allowlist,
        },
        listFetchTimeout,
      );

  /// `POST control/filtering/set_url`: the list now at [url] gets [name],
  /// [newUrl] and [enabled]. [allowlist] has to say which kind it is.
  Future<void> updateFilterList({
    required String url,
    required bool allowlist,
    required String name,
    required String newUrl,
    required bool enabled,
  }) =>
      _post(
        'control/filtering/set_url',
        <String, dynamic>{
          'url': url,
          'whitelist': allowlist,
          'data': <String, dynamic>{
            'name': name,
            'url': newUrl,
            'enabled': enabled,
          },
        },
        // A list switched on, or given a new address, is fetched there and
        // then.
        listFetchTimeout,
      );

  /// `POST control/filtering/remove_url`.
  Future<void> removeFilterList({
    required String url,
    required bool allowlist,
  }) =>
      _post('control/filtering/remove_url', <String, dynamic>{
        'url': url,
        'whitelist': allowlist,
      });

  /// `POST control/filtering/refresh`: fetches the lists of one kind again,
  /// and says how many changed.
  Future<int> refreshFilterLists({required bool allowlist}) async {
    final Object? answer = await _session.run(() async {
      final Response<dynamic> response = await _dio.post<dynamic>(
        'control/filtering/refresh',
        data: <String, dynamic>{'whitelist': allowlist},
        options: Options(receiveTimeout: listFetchTimeout),
      );
      return response.data as Object?;
    });
    if (answer is! Map<Object?, Object?>) {
      throw const AdguardHomeUnexpectedAnswer();
    }
    return readInt(answer['updated']);
  }

  /// `POST control/filtering/config`. Both go every time: the server resets
  /// whichever is left out, the interval to never.
  Future<void> setFilteringConfig({
    required bool enabled,
    required int intervalHours,
  }) =>
      _post('control/filtering/config', <String, dynamic>{
        'enabled': enabled,
        'interval': intervalHours,
      });

  /// `GET control/filtering/check_host`: what the server would do with
  /// [name], for [client] when one is given.
  Future<AdguardHomeHostCheck> checkHost(String name, {String? client}) async =>
      AdguardHomeHostCheck.fromJson(
        name,
        await _get('control/filtering/check_host', <String, dynamic>{
          'name': name,
          if (client != null && client.isNotEmpty) 'client': client,
        }),
      );

  /// `GET control/blocked_services/get`.
  Future<AdguardHomeGlobalServices> getGlobalServices() async =>
      AdguardHomeGlobalServices.fromJson(
        await _get('control/blocked_services/get'),
      );

  /// `PUT control/blocked_services/update`, services and schedule together.
  Future<void> setGlobalServices(AdguardHomeGlobalServices services) =>
      _put('control/blocked_services/update', services.toJson());

  /// `GET control/rewrite/list`.
  Future<List<AdguardHomeRewrite>> getRewrites() async {
    final Object? answer = await _session.run(() async {
      final Response<dynamic> response =
          await _dio.get<dynamic>('control/rewrite/list');
      return response.data as Object?;
    });
    if (answer != null && answer is! List) {
      throw const AdguardHomeUnexpectedAnswer();
    }
    return AdguardHomeRewrite.listFromJson(answer);
  }

  /// `POST control/rewrite/add`.
  Future<void> addRewrite(AdguardHomeRewrite rewrite) =>
      _post('control/rewrite/add', rewrite.toJson());

  /// `PUT control/rewrite/update`: the rewrite that is [target] becomes
  /// [update]. The server finds it by domain and answer.
  Future<void> updateRewrite(
    AdguardHomeRewrite target,
    AdguardHomeRewrite update,
  ) =>
      _put('control/rewrite/update', <String, dynamic>{
        'target': target.toJson(),
        'update': update.toJson(),
      });

  /// `POST control/rewrite/delete`.
  Future<void> deleteRewrite(AdguardHomeRewrite rewrite) =>
      _post('control/rewrite/delete', rewrite.toJson());

  /// Whether rewrites apply at all: `GET control/rewrite/settings`.
  Future<bool> getRewritesEnabled() async =>
      readBool((await _get('control/rewrite/settings'))['enabled']);

  /// `PUT control/rewrite/settings/update`.
  Future<void> setRewritesEnabled({required bool enabled}) => _put(
        'control/rewrite/settings/update',
        <String, dynamic>{'enabled': enabled},
      );

  /// `GET control/safebrowsing/status`.
  Future<bool> getSafeBrowsing() async =>
      readBool((await _get('control/safebrowsing/status'))['enabled']);

  /// `POST control/safebrowsing/enable` or `.../disable`.
  Future<void> setSafeBrowsing({required bool enabled}) =>
      _post('control/safebrowsing/${enabled ? 'enable' : 'disable'}');

  /// `GET control/parental/status`.
  Future<bool> getParental() async =>
      readBool((await _get('control/parental/status'))['enabled']);

  /// `POST control/parental/enable` or `.../disable`.
  Future<void> setParental({required bool enabled}) =>
      _post('control/parental/${enabled ? 'enable' : 'disable'}');

  /// `PUT control/safesearch/settings`. Whole: an engine left out is
  /// switched off.
  Future<void> setSafeSearch(AdguardHomeSafeSearch safeSearch) =>
      _put('control/safesearch/settings', safeSearch.toJson());

  /// `GET control/querylog/config`, as the settings write it back.
  Future<AdguardHomeRetention> getQueryLogRetention() async =>
      AdguardHomeRetention.fromJson(await _get('control/querylog/config'));

  /// `PUT control/querylog/config/update`. Whole: a field left out is
  /// refused.
  Future<void> setQueryLogRetention(AdguardHomeRetention retention) =>
      _put('control/querylog/config/update', retention.toJson());

  /// `GET control/stats/config`.
  Future<AdguardHomeRetention> getStatsRetention() async =>
      AdguardHomeRetention.fromJson(await _get('control/stats/config'));

  /// `PUT control/stats/config/update`. Whole, as the query log's.
  Future<void> setStatsRetention(AdguardHomeRetention retention) =>
      _put('control/stats/config/update', retention.toJson());

  /// `POST control/stats_reset`: the statistics start again from nothing.
  Future<void> resetStats() => _post('control/stats_reset');

  /// `GET control/dns_info`.
  Future<AdguardHomeDnsConfig> getDnsConfig() async =>
      AdguardHomeDnsConfig(await _get('control/dns_info'));

  /// `POST control/dns_config` with only what is to change: the server
  /// keeps what is left out.
  Future<void> setDnsConfig(Map<String, dynamic> changes) =>
      _post('control/dns_config', changes);

  /// `POST control/test_upstream_dns`: whether each server answers, for the
  /// lists as given, saved or not.
  Future<List<AdguardHomeUpstreamResult>> testUpstreams({
    required List<String> upstreams,
    required List<String> bootstrap,
    required List<String> fallback,
    required List<String> privateUpstreams,
  }) async =>
      AdguardHomeUpstreamResult.listFromJson(
        await _postForJson('control/test_upstream_dns', <String, dynamic>{
          'upstream_dns': upstreams,
          'bootstrap_dns': bootstrap,
          'fallback_dns': fallback,
          'private_upstream': privateUpstreams,
        }),
      );

  /// `POST control/cache_clear`.
  Future<void> clearDnsCache() => _post('control/cache_clear');

  /// `GET control/tls/status`.
  Future<AdguardHomeTlsStatus> getTlsStatus() async =>
      AdguardHomeTlsStatus.fromJson(await _get('control/tls/status'));

  /// `GET control/dhcp/status`.
  Future<AdguardHomeDhcpStatus> getDhcpStatus() async =>
      AdguardHomeDhcpStatus.fromJson(await _get('control/dhcp/status'));

  /// `POST control/version.json`. With [recheck] the server asks for the
  /// latest version now rather than answering from what it last heard.
  Future<AdguardHomeVersionCheck> checkVersion({bool recheck = false}) async =>
      AdguardHomeVersionCheck.fromJson(
        await _postForJson(
          'control/version.json',
          <String, dynamic>{'recheck_now': recheck},
        ),
      );

  Future<Map<String, dynamic>> _postForJson(
    String path,
    Map<String, dynamic> body,
  ) =>
      _session.run(() async {
        final Response<dynamic> response =
            await _dio.post<dynamic>(path, data: body);
        final Object? data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw const AdguardHomeUnexpectedAnswer();
      });

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

  Future<void> _post(
    String path, [
    Map<String, dynamic>? body,
    Duration? timeout,
  ]) =>
      _session.run(() async {
        await _dio.post<dynamic>(
          path,
          data: body,
          options: timeout == null ? null : Options(receiveTimeout: timeout),
        );
      });

  Future<void> _put(String path, Map<String, dynamic> body) =>
      _session.run(() async {
        await _dio.put<dynamic>(path, data: body);
      });
}
