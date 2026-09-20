import 'dart:convert';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'service_auth_headers.dart';

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
/// | Transmission             | HTTP Basic, and only when configured        |
/// | Deluge                   | `Cookie: _session_id=…` after `auth.login`  |
/// | Navidrome                | `?u=` + `?t=` salted MD5 + `?s=` query params |
/// | Ombi                     | `ApiKey` header                             |
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
          case ServiceKind.speedtestTracker || ServiceKind.tracearr:
            options.headers['Authorization'] = 'Bearer $apiKey';
            options.headers['Accept'] = 'application/json';
          case ServiceKind.sabnzbd || ServiceKind.tautulli:
            options.queryParameters['apikey'] = apiKey;
            // Tautulli's endpoints all require `cmd=` too - that's the
            // service module's job, not the interceptor's.
            if (kind == ServiceKind.sabnzbd) {
              options.queryParameters['output'] = 'json';
            }
          case ServiceKind.ombi:
            // Ombi reads only its own header; X-Api-Key gets a 401.
            options.headers['ApiKey'] = apiKey;
          case ServiceKind.myspeed:
            // MySpeed 1.0.9 reads a raw 'password' header; newer builds
            // prefer a URL-encoded 'x-password' and fall back to the raw
            // one. The raw header only goes when Dart will let it through:
            // a password outside printable ASCII would otherwise throw
            // inside every request.
            if (apiKey.isNotEmpty) {
              options.headers['x-password'] = Uri.encodeComponent(apiKey);
              if (fitsHeaderValue(apiKey)) options.headers['password'] = apiKey;
            }
          case _:
            options.headers['X-Api-Key'] = apiKey;
        }
      case InstanceAuthPlex(:final String token):
        options.headers['X-Plex-Token'] = token;
        // Plex returns XML by default; ask for JSON where supported.
        options.headers['Accept'] = 'application/json';
      case InstanceAuthUserPass(
            :final String username,
            :final String password,
          )
          when kind == ServiceKind.nzbget ||
              kind == ServiceKind.transmission ||
              kind == ServiceKind.rtorrent:
        // All three use plain HTTP Basic on every request; there is no login
        // flow. Never log this header.
        //
        // Transmission's RPC auth is optional and off by default, and rTorrent
        // has no auth of its own at all (only whatever proxy fronts it), so
        // send nothing when no credentials were entered - an empty `Basic :` is
        // worse than no header.
        if (username.isNotEmpty || password.isNotEmpty) {
          options.headers['Authorization'] =
              'Basic ${base64Encode(utf8.encode('$username:$password'))}';
        }
      case InstanceAuthUserPass(
            :final String username,
            :final String password,
          )
          when kind == ServiceKind.navidrome:
        // Subsonic puts its credentials in the query string rather than a
        // header: the username, a random salt, and an MD5 of the password
        // with that salt appended.
        //
        // This has to live here and not only in the service package, because
        // the dashboard health probe and the connection tester build their
        // requests from this interceptor alone. Without it they send an
        // unauthenticated request, Subsonic answers 200 with a `failed`
        // envelope rather than a 401, and every Navidrome instance reads as
        // healthy no matter what its credentials are.
        if (username.isNotEmpty) {
          options.queryParameters['u'] = username;
          if (password.isNotEmpty) {
            final String salt = _subsonicSalt();
            options.queryParameters['t'] =
                md5.convert(utf8.encode('$password$salt')).toString();
            options.queryParameters['s'] = salt;
          }
        }
        // Subsonic rejects a request that omits these, so the probe needs
        // them as much as the service module does.
        options.queryParameters['v'] = subsonicApiVersion;
        options.queryParameters['c'] = subsonicClientName;
        options.queryParameters['f'] = 'json';
      case InstanceAuthUserPass() || InstanceAuthCookie():
        // Token / cookie auth is handled by the service's session manager,
        // not here.
        break;
    }
    handler.next(options);
  }

  /// A fresh salt per request, which is what the Subsonic spec asks for.
  ///
  /// [Random.secure] rather than [Random]: the salt is sent in the clear
  /// beside the hash, so a predictable one lets an attacker who captures a
  /// single request precompute against it.
  static String _subsonicSalt([int length = 16]) {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random.secure();
    return String.fromCharCodes(
      Iterable<int>.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}

/// The Subsonic protocol version Atrium speaks, and the client name it
/// identifies itself with. Shared so the interceptor and the service module
/// cannot drift apart.
const String subsonicApiVersion = '1.16.1';
const String subsonicClientName = 'Atrium';
