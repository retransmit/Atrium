import 'dart:convert';

import 'package:dio/dio.dart';

import 'models/gluetun_models.dart';

/// REST client for the Gluetun HTTP control server API.
class GluetunApi {
  GluetunApi(this._dio);

  final Dio _dio;

  /// Whether this Gluetun only has the pre-v3.41 port forwarding route.
  bool _legacyPortRoute = false;

  Map<String, dynamic>? _toMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Fetches the current VPN status (e.g. running, stopped).
  ///
  /// Throws when Gluetun refuses, and when the answer is not Gluetun's JSON.
  /// That exception keeps the response, so a login page answering 200 can be
  /// told apart from a server that never answered.
  Future<GluetunVpnStatus> getVpnStatus() async {
    final Response<dynamic> resp = await _dio.get<dynamic>('v1/vpn/status');
    final Map<String, dynamic>? map = _toMap(resp.data);
    if (map != null) {
      return GluetunVpnStatus.fromJson(map);
    }
    throw DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: 'Invalid response from Gluetun VPN status endpoint',
    );
  }

  /// Starts or stops the VPN.
  ///
  /// Throws when Gluetun refuses; see [_put].
  Future<GluetunVpnStatus> setVpnStatus({required bool run}) async {
    await _put('v1/vpn/status', run: run);
    return GluetunVpnStatus(status: run ? 'running' : 'stopped');
  }

  /// Stops the VPN and starts it again.
  ///
  /// Gluetun has no reconnect route, but it answers a stop and a start within
  /// a second each and connects afresh on the start, which can land on
  /// another server with a new public IP and forwarded port. The tunnel is
  /// back within seconds. Throws when Gluetun refuses the stop, in which case
  /// nothing changed, and [GluetunRestartFailed] when the stop went through
  /// but the start did not, which leaves the VPN stopped.
  Future<void> reconnectVpn() async {
    await _put('v1/vpn/status', run: false);
    try {
      await _put('v1/vpn/status', run: true);
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(GluetunRestartFailed(error), stack);
    }
  }

  /// Fetches public IP details.
  ///
  /// Throws when Gluetun refuses; see [_getMap].
  Future<GluetunPublicIp?> getPublicIp() async {
    final Map<String, dynamic>? map = await _getMap('v1/publicip/ip');
    return map == null ? null : GluetunPublicIp.fromJson(map);
  }

  /// Fetches port forwarding info.
  ///
  /// Gluetun v3.41 renamed the route from `/v1/openvpn/portforwarded` to
  /// `/v1/portforward`, so the old one is asked when the new one fails the
  /// way an older Gluetun fails it: with 400, its answer to a route it does
  /// not have, or with a refusal from a role written before the rename. If
  /// the old route fails too, the first failure is the one thrown.
  ///
  /// Once the old route has answered it is asked directly from then on.
  /// Checked on a live v3.40.4, which will not even start with the new route
  /// in a role, so every poll there would otherwise add a refused request,
  /// and a 401 line in Gluetun's log.
  Future<GluetunPortForward?> getPortForward() async {
    Map<String, dynamic>? map;
    if (_legacyPortRoute) {
      map = await _getMap('v1/openvpn/portforwarded');
    } else {
      try {
        map = await _getMap('v1/portforward');
      } on DioException catch (error, stack) {
        final int? status = error.response?.statusCode;
        if (status != 400 && status != 401 && status != 403) {
          rethrow;
        }
        try {
          map = await _getMap('v1/openvpn/portforwarded');
          _legacyPortRoute = true;
        } on DioException {
          Error.throwWithStackTrace(error, stack);
        }
      }
    }
    return map == null ? null : GluetunPortForward.fromJson(map);
  }

  /// Fetches DNS server status.
  ///
  /// Throws when Gluetun refuses; see [_getMap].
  Future<GluetunDnsStatus?> getDnsStatus() async {
    final Map<String, dynamic>? map = await _getMap('v1/dns/status');
    return map == null ? null : GluetunDnsStatus.fromJson(map);
  }

  /// Starts or stops Gluetun's DNS server.
  ///
  /// Throws when Gluetun refuses; see [_put].
  Future<GluetunDnsStatus> setDnsStatus({required bool run}) async {
    await _put('v1/dns/status', run: run);
    return GluetunDnsStatus(status: run ? 'running' : 'stopped');
  }

  /// Fetches server database updater status.
  ///
  /// Throws when Gluetun refuses; see [_getMap].
  Future<GluetunUpdaterStatus?> getUpdaterStatus() async {
    final Map<String, dynamic>? map = await _getMap('v1/updater/status');
    return map == null ? null : GluetunUpdaterStatus.fromJson(map);
  }

  /// Starts or stops the server list updater.
  ///
  /// Throws when Gluetun refuses; see [_put].
  Future<GluetunUpdaterStatus> setUpdaterStatus({required bool run}) async {
    await _put('v1/updater/status', run: run);
    return GluetunUpdaterStatus(status: run ? 'running' : 'stopped');
  }

  /// Reads one of Gluetun's endpoints as a JSON object, or null if it is not.
  ///
  /// A refusal or an unreachable server throws. Catching those here used to
  /// show a route the API key's role does not grant as a DNS server in state
  /// UNKNOWN, an IDLE updater, or a public IP check that was switched off,
  /// when Gluetun had simply said no.
  Future<Map<String, dynamic>?> _getMap(String path) async {
    final Response<dynamic> resp = await _dio.get<dynamic>(path);
    return _toMap(resp.data);
  }

  /// Sends a status change to one of Gluetun's control endpoints.
  ///
  /// Two things about these endpoints shape this. A refusal has to reach the
  /// caller: current Gluetun refuses any route its auth config does not grant,
  /// and catching that here used to turn a 401 into a success message on
  /// screen. And a successful change answers `{"outcome": "..."}`, not the
  /// status object the matching GET returns, so the reply carries nothing the
  /// status models can read; callers get back the state they asked for.
  Future<void> _put(String path, {required bool run}) =>
      _dio.put<dynamic>(
        path,
        data: <String, String>{'status': run ? 'running' : 'stopped'},
      );
}

/// A reconnect stopped the VPN but could not start it again.
///
/// Kept apart from a plain failure because the VPN is now down, and
/// everything behind Gluetun with it, which the user has to be told.
class GluetunRestartFailed implements Exception {
  const GluetunRestartFailed(this.cause);

  /// Why the start failed.
  final DioException cause;

  @override
  String toString() => 'GluetunRestartFailed: $cause';
}
