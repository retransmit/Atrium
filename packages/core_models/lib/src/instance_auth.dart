import 'package:freezed_annotation/freezed_annotation.dart';

part 'instance_auth.freezed.dart';
part 'instance_auth.g.dart';

/// Authentication material attached to an [Instance].
///
/// Modeled as a sealed union so each variant carries exactly the fields it
/// needs and the connection layer can pattern-match on the kind:
///
/// ```dart
/// final header = switch (instance.auth) {
///   InstanceAuthApiKey(:final apiKey) => {'X-Api-Key': apiKey},
///   InstanceAuthUserPass(:final username, :final password) => ...,
///   InstanceAuthPlex(:final token) => {'X-Plex-Token': token},
///   InstanceAuthCookie(:final username, :final password) => ...,
/// };
/// ```
///
/// Secret material lives inside this object in memory. On disk, secrets are
/// stripped before the model is written to a Hive box; the storage layer
/// holds them in the platform secure store (Android Keystore via
/// flutter_secure_storage) keyed by `instance.id`.
@freezed
sealed class InstanceAuth with _$InstanceAuth {
  /// Static API key in a header or query param. Used by every *arr service,
  /// Overseerr / Jellyseerr, Tautulli, and SABnzbd.
  const factory InstanceAuth.apiKey({required String apiKey}) =
      InstanceAuthApiKey;

  /// Username + password login that returns a session token (Jellyfin, Emby).
  const factory InstanceAuth.userPass({
    required String username,
    required String password,
  }) = InstanceAuthUserPass;

  /// Plex `X-Plex-Token`. Obtained from plex.tv login (out of scope for v0.1)
  /// or pinned from the server's `Preferences.xml`.
  const factory InstanceAuth.plexToken({required String token}) =
      InstanceAuthPlex;

  /// Username + password login that exchanges for a session cookie carried on
  /// subsequent requests (qBittorrent's `/api/v2/auth/login`).
  const factory InstanceAuth.cookieLogin({
    required String username,
    required String password,
  }) = InstanceAuthCookie;

  factory InstanceAuth.fromJson(Map<String, dynamic> json) =>
      _$InstanceAuthFromJson(json);
}
