import 'package:freezed_annotation/freezed_annotation.dart';

import 'instance_auth.dart';
import 'service_kind.dart';
import 'url_mode.dart';

part 'instance.freezed.dart';
part 'instance.g.dart';

/// One configured connection to a self-hosted service.
///
/// An instance is what the user adds when they "add a Sonarr" - it carries
/// the URLs to reach that Sonarr, the auth material to authenticate against
/// it, and a few preferences (URL mode, TLS leniency).
///
/// Users may have multiple instances of the same [kind] (e.g., two Sonarrs:
/// "Home" and "Seedbox"); each is a separate [Instance] with its own [id].
@Freezed(toStringOverride: false)
abstract class Instance with _$Instance {
  const Instance._();

  const factory Instance({
    /// Stable identifier, generated once at create time. Used as the key for
    /// secret storage and Riverpod scoping. Never reuse.
    required String id,

    /// Display name shown in lists and the title bar. Free-form.
    required String name,

    /// What service this instance speaks to.
    @JsonKey(fromJson: _serviceKindFromJson) required ServiceKind kind,

    /// URL reachable from the home LAN (e.g., `http://192.168.1.10:8989`).
    /// May be empty if the user only has remote access.
    required String localUrl,

    /// URL reachable from outside the LAN (e.g., `https://sonarr.example.com`).
    /// May be empty if the user only ever uses the LAN URL.
    required String externalUrl,

    /// Routing strategy between [localUrl] and [externalUrl].
    required UrlMode urlMode,

    /// Auth material. See [InstanceAuth].
    required InstanceAuth auth,

    /// Accept self-signed TLS certificates. Off by default - turning this on
    /// is the user explicitly opting out of cert validation for this
    /// instance only.
    @Default(false) bool allowSelfSignedCerts,

    /// How frequently this instance should be polled by the dashboard/widgets.
    /// Used by services that need high frequency updates like Glances.
    @Default(5) int pollingIntervalSeconds,

    /// Extra HTTP headers sent with every request to this instance, merged
    /// over the profile's global headers (instance wins on key collision).
    /// Values live in the profile JSON like URLs do; they are not secrets.
    @Default(<String, String>{}) Map<String, String> customHeaders,
  }) = _Instance;

  factory Instance.fromJson(Map<String, dynamic> json) =>
      _$InstanceFromJson(json);

  /// A diagnostic representation that deliberately excludes credentials and
  /// custom-header values. URLs with embedded user information are redacted.
  @override
  String toString() => 'Instance('
      'id: $id, '
      'name: $name, '
      'kind: $kind, '
      'localUrl: ${_redactUrlUserInfo(localUrl)}, '
      'externalUrl: ${_redactUrlUserInfo(externalUrl)}, '
      'urlMode: $urlMode, '
      'auth: $auth, '
      'allowSelfSignedCerts: $allowSelfSignedCerts, '
      'pollingIntervalSeconds: $pollingIntervalSeconds, '
      'customHeaderNames: ${customHeaders.keys.toList(growable: false)}'
      ')';
}

String _redactUrlUserInfo(String raw) {
  final Uri? uri = Uri.tryParse(raw);
  if (uri == null || uri.userInfo.isEmpty) {
    return raw;
  }
  return uri.replace(userInfo: '***redacted***').toString();
}

/// Decodes [ServiceKind], migrating the legacy `overseerr` value to
/// [ServiceKind.seerr]. Overseerr was archived upstream so the service was
/// renamed to Seerr (API-compatible); profiles saved before the rename still
/// store `overseerr` and must keep loading.
ServiceKind _serviceKindFromJson(String value) =>
    value == 'overseerr' ? ServiceKind.seerr : ServiceKind.values.byName(value);
