import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';

/// The headers an artwork request needs, worked out from its URL.
///
/// Artwork is the one thing in the app that does not go through Dio. Posters,
/// banners and backdrops are fetched by `CachedNetworkImage` on its own HTTP
/// client, which sends nothing but what it is handed, so the user-configured
/// headers the Dio factory installs never reached them. Behind a forward-auth
/// proxy (Authelia, Cloudflare Access, an nginx `auth_request`) that means the
/// proxy answered every image request instead of the service and every poster
/// came up blank, silently, while the rest of the app worked.
///
/// This is a static holder rather than a provider on purpose. Artwork is
/// requested from places that have no `ref` to read: `PaletteGenerator` calls
/// in plain `State` classes, `DecorationImage`, helper functions several
/// layers down a service module. Threading a ref to all of them would be a
/// far larger change than the bug warrants. It is written from exactly one
/// place, the profile listener in `app.dart`, alongside the existing
/// `globalHeadersProvider` sync, so there is one writer and many readers.
abstract final class ArtworkHeaders {
  /// Normalised instance base URL to the headers requests under it need.
  ///
  /// Both the local and external URL of an instance map to the same headers,
  /// since either may be the one the artwork URL was built from. Every
  /// configured base is a key, with an empty map when it has nothing to
  /// send, so a URL is matched to its own instance and never falls through
  /// to another one higher up the same host.
  static Map<String, Map<String, String>> _byBase =
      const <String, Map<String, String>>{};

  /// Headers a signed-in client set for its own base: the session token
  /// Jellyfin and Emby hand out at login, which no [Instance] holds.
  static Map<String, Map<String, String>> _sessions =
      <String, Map<String, String>>{};

  /// Which instance, and which account on it, each base belonged to when the
  /// lookup was last built. A session token is only good for that account.
  static Map<String, Object> _owners = const <String, Object>{};

  /// Rebuilds the lookup for [instances], merging each instance's headers
  /// over [global] exactly as the Dio factory does, then its own credential
  /// on top, as the auth interceptor does after the custom headers.
  static void update({
    required Iterable<Instance> instances,
    required Map<String, String> global,
  }) {
    final Map<String, Map<String, String>> next =
        <String, Map<String, String>>{};
    final Map<String, Object> owners = <String, Object>{};
    for (final Instance instance in instances) {
      final Map<String, String> headers = <String, String>{
        ...mergeHeaders(global, instance.customHeaders),
        ..._credential(instance),
      };
      for (final String base in <String>[
        instance.localUrl,
        instance.externalUrl,
      ]) {
        final String key = _normalise(base);
        if (key.isNotEmpty) {
          next[key] = headers;
          owners[key] = (instance.id, instance.auth);
        }
      }
    }
    // A token belongs to the account that signed in. When a base is removed,
    // or now belongs to another instance or account (a profile switch, a
    // changed user), its token goes; that client registers a new one when it
    // signs in.
    _sessions.removeWhere(
      (String base, _) => owners[base] == null || owners[base] != _owners[base],
    );
    _byBase = next;
    _owners = owners;
  }

  /// Records the headers a signed-in client needs on artwork under
  /// [baseUrl], or clears them when [headers] is null.
  static void setSession(String baseUrl, Map<String, String>? headers) {
    final String key = _normalise(baseUrl);
    if (headers == null || headers.isEmpty) {
      _sessions.remove(key);
    } else {
      _sessions[key] = Map<String, String>.unmodifiable(headers);
    }
  }

  /// Headers for [url], or null when it belongs to no configured instance.
  ///
  /// Null rather than an empty map because that is what `CachedNetworkImage`
  /// and `Image.network` already treat as "send nothing", and because artwork
  /// for something not in the library yet points at TMDB or Fanart.tv, where
  /// the user's proxy credentials and API keys have no business being sent.
  static Map<String, String>? forUrl(String? url) {
    if (url == null || url.isEmpty || _byBase.isEmpty) {
      return null;
    }
    final String target = _normalise(url);

    // Longest match wins, so an instance served from a sub-path is preferred
    // over another one sitting at the root of the same host.
    String? best;
    for (final String base in _byBase.keys) {
      if (target == base || target.startsWith('$base/')) {
        if (best == null || base.length > best.length) {
          best = base;
        }
      }
    }
    if (best == null) {
      return null;
    }
    final Map<String, String> headers = <String, String>{
      ..._byBase[best]!,
      ...?_sessions[best],
    };
    return headers.isEmpty ? null : headers;
  }

  /// The instance's own credential, as a header, for the kinds whose
  /// artwork Atrium builds URLs for.
  ///
  /// These used to ride in the URL (`?apikey=`, `?X-Plex-Token=`), which a
  /// reverse proxy writes to its access log in full. Each of these services
  /// takes the same header on its artwork that it takes on its API.
  static Map<String, String> _credential(Instance instance) =>
      switch ((instance.kind, instance.auth)) {
        (
          ServiceKind.radarr || ServiceKind.sonarr || ServiceKind.lidarr,
          InstanceAuthApiKey(:final String apiKey),
        )
            when apiKey.isNotEmpty =>
          <String, String>{'X-Api-Key': apiKey},
        (ServiceKind.plex, InstanceAuthPlex(:final String token))
            when token.isNotEmpty =>
          <String, String>{'X-Plex-Token': token},
        _ => const <String, String>{},
      };

  /// Drops every mapping. Only for tests, so one does not leak into the next.
  static void reset() {
    _byBase = const <String, Map<String, String>>{};
    _sessions = <String, Map<String, String>>{};
    _owners = const <String, Object>{};
  }

  /// Lowercased and stripped of trailing slashes so the comparison survives
  /// the ways a base URL and the URL built from it can differ in spelling.
  /// Case folding the path too is deliberate: hosts are case-insensitive, and
  /// treating a prefix loosely here can only widen the match to another URL on
  /// the user's own server.
  static String _normalise(String raw) {
    String value = raw.trim();
    // Through Uri first, the way the connection resolver builds the base the
    // artwork URLs start from: it drops a default port such as :443, and a
    // base typed with one would otherwise never match.
    final Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      value = uri.toString();
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value.toLowerCase();
  }
}
