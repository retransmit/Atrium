import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';

/// Adds the auth header(s) appropriate for the [Instance]'s service kind.
///
/// Decoder for the various conventions across the stack:
///
/// | Service                  | Where the secret goes                       |
/// |--------------------------|---------------------------------------------|
/// | *arr family, Seerr   | `X-Api-Key` header                          |
/// | SABnzbd, Tautulli        | `?apikey=` query param                      |
/// | Speedtest Tracker        | `Authorization: Bearer ...`                 |
/// | Plex                     | `X-Plex-Token` header                       |
/// | Jellyfin / Emby          | `X-Emby-Authorization` (token only after login) |
/// | qBittorrent              | `Cookie: SID=...` after `/api/v2/auth/login`    |
/// | NZBGet                   | HTTP Basic Authorization header             |
///
/// `Jellyfin/Emby` and `qBittorrent` both use the user/password auth flow:
/// the session token / cookie is acquired out of band and stored in the
/// service's own session manager, then attached at request time. This
/// interceptor only wires the *static* secret cases: api key, plex token,
/// and NZBGet's HTTP Basic credentials.
class AuthInterceptor extends Interceptor {
  const AuthInterceptor({required this.kind, required this.auth});

  final ServiceKind kind;
  final InstanceAuth auth;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    switch (auth) {
      case InstanceAuthApiKey(:final String apiKey):
        switch (kind) {
          case ServiceKind.speedtestTracker:
            options.headers['Authorization'] = 'Bearer $apiKey';
            options.headers['Accept'] = 'application/json';
          case ServiceKind.sabnzbd || ServiceKind.tautulli:
            options.queryParameters['apikey'] = apiKey;
            // Tautulli's endpoints all require `cmd=` too - that's the
            // service module's job, not the interceptor's.
            if (kind == ServiceKind.sabnzbd) {
              options.queryParameters['output'] = 'json';
            }
          case _:
            options.headers['X-Api-Key'] = apiKey;
        }
      case InstanceAuthPlex(:final String token):
        if (kind != ServiceKind.tracearr) {
          options.headers['X-Plex-Token'] = token;
          // Plex returns XML by default; ask for JSON where supported.
          options.headers['Accept'] = 'application/json';
        }
      case InstanceAuthUserPass(
          :final String username,
          :final String password,
        )
          when kind == ServiceKind.nzbget:
        // NZBGet uses plain HTTP Basic on every request; there is no login
        // flow. Never log this header.
        options.headers['Authorization'] =
            'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      case InstanceAuthUserPass() || InstanceAuthCookie():
        // Token / cookie auth is handled by the service's session manager,
        // not here.
        break;
    }
    handler.next(options);
  }
}
