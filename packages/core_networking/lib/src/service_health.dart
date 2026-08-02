import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';

import 'dio_factory.dart';

/// How a service's health endpoint should be interpreted.
enum _HealthMode {
  /// Endpoint uses the attached auth (api key / token / query key).
  /// 2xx → ok, 401/403 → warning (reachable but bad creds), else → error.
  authed,

  /// Endpoint is public (no auth needed). 2xx → ok, else → error.
  publicEndpoint,

  /// We can't cheaply authenticate in a lightweight probe (cookie/login
  /// services), so any HTTP response - including 401/403 - proves the host is
  /// up. Only a transport failure is an error.
  reachable,
}

/// Per-[ServiceKind] health endpoint + interpretation mode.
///
/// Keeping this table here (rather than in each service module) lets the
/// dashboard probe every instance uniformly without depending on all 11
/// service packages.
({String path, _HealthMode mode}) _config(ServiceKind kind) {
  switch (kind) {
    // *arr family + Seerr: authed REST status endpoints.
    case ServiceKind.sonarr:
    case ServiceKind.radarr:
      return (path: 'api/v3/system/status', mode: _HealthMode.authed);
    case ServiceKind.prowlarr:
      return (path: 'api/v1/system/status', mode: _HealthMode.authed);
    case ServiceKind.bazarr:
      return (path: 'api/system/status', mode: _HealthMode.authed);
    case ServiceKind.seerr:
      return (path: 'api/v1/status', mode: _HealthMode.authed);
    // Query-key services - AuthInterceptor appends the key as a query param.
    case ServiceKind.tautulli:
      return (
        path: 'api/v2?cmd=get_server_friendly_name',
        mode: _HealthMode.authed,
      );
    case ServiceKind.sabnzbd:
      return (path: 'api?mode=version', mode: _HealthMode.authed);
    // Plex: X-Plex-Token is attached; /identity returns server identity.
    case ServiceKind.plex:
      return (path: 'identity', mode: _HealthMode.authed);
    // Media servers expose an unauthenticated public-info endpoint.
    case ServiceKind.jellyfin:
    case ServiceKind.emby:
      return (path: 'System/Info/Public', mode: _HealthMode.publicEndpoint);
    // qBittorrent needs a session cookie we don't mint in a probe; any
    // response means the WebUI is up.
    case ServiceKind.qbittorrent:
      return (path: 'api/v2/app/version', mode: _HealthMode.reachable);
    case ServiceKind.glances:
      return (path: 'api/4/core', mode: _HealthMode.authed);
    case ServiceKind.speedtestTracker:
      return (path: 'api/v1/results?page[size]=1', mode: _HealthMode.authed);
    case ServiceKind.nzbget:
      // JSON-RPC accepts GET for parameterless methods; Basic auth is
      // attached by the interceptor, so 401 means bad credentials.
      return (path: 'jsonrpc/version', mode: _HealthMode.authed);
    case ServiceKind.transmission:
      // The RPC endpoint answers an unprimed GET with 409 (its CSRF
      // rejection), which is a distinctive Transmission signature - better
      // evidence than the 200 a bare web root would give. A probe cannot do
      // the token handshake, and RPC auth is optional, so any response counts
      // as up.
      return (path: 'transmission/rpc', mode: _HealthMode.reachable);
    case ServiceKind.deluge:
      // Deluge's login is a POST, so a probe cannot authenticate cheaply.
      // `/json` answers GET with 405, which is a better liveness signal than
      // the root path: any web server returns 200 for `/`, but only Deluge's
      // RPC endpoint is there to refuse the method.
      return (path: 'json', mode: _HealthMode.reachable);
    case ServiceKind.rtorrent:
      // XML-RPC only answers POST - a GET makes the proxy in front return 502
      // whether the daemon is alive or dead, which is no signal at all. So this
      // is the one kind the probe POSTs (see [_probeBody]), and a real
      // `methodResponse` is required for ok.
      return (path: '', mode: _HealthMode.authed);
  }
}

/// The request body to POST for [kind], or null to probe with a plain GET.
///
/// Only rTorrent needs this: it has no GET-able status endpoint, so the probe
/// sends the cheapest XML-RPC call there is.
String? _probeBody(ServiceKind kind) => switch (kind) {
      ServiceKind.rtorrent => '<?xml version="1.0"?><methodCall>'
          '<methodName>system.client_version</methodName>'
          '<params></params></methodCall>',
      _ => null,
    };

/// Probes the real health of a configured [Instance].
///
/// Unlike a blind `GET /` (which treats a 404 or a login page as "up"), this
/// hits the service's own status endpoint with its real auth and returns a
/// [Health] the dashboard can trust:
///
/// * [Health.ok] - reachable and the credentials work.
/// * [Health.warning] - reachable but the API key / token was rejected
///   (so the user knows to fix it), or the server answered 5xx.
/// * [Health.error] - could not reach the server at all.
class HealthProbe {
  HealthProbe({required DioFactory dioFactory}) : _dioFactory = dioFactory;

  final DioFactory _dioFactory;

  Future<Health> check(Instance instance) async {
    final ({String path, _HealthMode mode}) cfg = _config(instance.kind);
    Dio? dio;
    try {
      dio = await _dioFactory.create(instance);
      final String? body = _probeBody(instance.kind);
      final Options options = Options(
        validateStatus: (_) => true,
        receiveTimeout: const Duration(seconds: 8),
        contentType: body == null ? null : 'text/xml',
        responseType: body == null ? null : ResponseType.plain,
      );
      final Response<dynamic> resp = body == null
          ? await dio.get<dynamic>(cfg.path, options: options)
          : await dio.post<dynamic>(cfg.path, data: body, options: options);
      final int status = resp.statusCode ?? 0;
      return interpretServiceHealthResponse(
        instance.kind,
        status,
        resp.data,
      );
    } on DioException {
      return Health.error;
    } on Object {
      return Health.error;
    } finally {
      dio?.close(force: true);
    }
  }
}

/// Interprets a completed HTTP health response without retaining or exposing
/// its body. Public for focused tests; callers should normally use
/// [HealthProbe].
Health interpretServiceHealthResponse(
  ServiceKind kind,
  int status,
  Object? data,
) {
  if (status == 0) {
    return Health.error;
  }
  final _HealthMode mode = _config(kind).mode;
  switch (mode) {
    case _HealthMode.authed:
      if (status >= 200 && status < 300) {
        if (kind == ServiceKind.speedtestTracker &&
            !_isSpeedtestResultsEnvelope(data)) {
          // The host answered, but not with the authenticated API contract.
          return Health.warning;
        }
        if (kind == ServiceKind.rtorrent &&
            !'$data'.contains('methodResponse')) {
          // A 200 from the web UI or a proxy landing page is not the XML-RPC
          // endpoint, so the URL is pointed at the wrong place.
          return Health.warning;
        }
        return Health.ok;
      }
      // 401/403, API-level 4xx, redirects, and 5xx all prove the host answered
      // while indicating credentials, compatibility, or server health needs
      // attention.
      return Health.warning;
    case _HealthMode.publicEndpoint:
      return (status >= 200 && status < 300) ? Health.ok : Health.error;
    case _HealthMode.reachable:
      return Health.ok;
  }
}

bool _isSpeedtestResultsEnvelope(Object? data) =>
    data is Map && data['data'] is List;
