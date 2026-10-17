import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

/// Registry of hosts whose self-signed TLS certificates are explicitly trusted.
///
/// Dio clients created through `DioFactory` configure their own certificate
/// callback per instance. Network images, posters and backdrops, however, are
/// fetched outside Dio (via `CachedNetworkImage` and `Image.network`) using
/// standard `HttpClient` instances. Behind an instance that uses a self-signed
/// certificate, those image requests fail TLS validation silently unless
/// intercepted.
///
/// [AtriumHttpOverrides] queries this registry to allow bad certificates for
/// hosts explicitly configured with [Instance.allowSelfSignedCerts].
///
/// ### Trust Granularity
/// Trust is host-scoped rather than port-scoped or per-instance:
/// - Once a host is registered, any port on that host is trusted.
/// - All instances or image requests in the application targeting that host
///   share this trust setting.
/// This matches standard homelab deployments where multiple services on the
/// same machine or reverse proxy share a private root CA or wildcard cert.
///
/// Note on IPv6: `Uri.host` strips enclosing brackets; the TLS callback's
/// `host` parameter is similarly provided as a bare literal on standard paths.
abstract final class SelfSignedCertTrust {
  static Set<String> _selfSignedHosts = const <String>{};

  /// Updates the trusted hosts from [instances].
  static void update(Iterable<Instance> instances) {
    final Set<String> hosts = <String>{};
    for (final Instance instance in instances) {
      if (!instance.allowSelfSignedCerts) {
        continue;
      }
      for (final String raw in <String>[
        instance.localUrl,
        instance.externalUrl,
      ]) {
        final Uri? uri = _tryParse(raw);
        if (uri != null && uri.host.isNotEmpty) {
          hosts.add(uri.host.toLowerCase());
        }
      }
    }
    _selfSignedHosts = hosts;
  }

  /// Checks whether [host] is allowed to use a self-signed certificate.
  ///
  /// Trust is host-scoped: [port] is accepted for signature compatibility with
  /// Dart's `badCertificateCallback` but matching evaluates the hostname.
  static bool allows({required String host, int? port}) {
    if (_selfSignedHosts.isEmpty) {
      return false;
    }
    final String normalizedHost = host.toLowerCase().trim();
    return _selfSignedHosts.contains(normalizedHost);
  }

  /// Checks whether the host of [url] is allowed to use a self-signed
  /// certificate.
  @visibleForTesting
  static bool allowsUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }
    final Uri? uri = _tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }
    return allows(host: uri.host, port: uri.hasPort ? uri.port : null);
  }

  /// Clears the registry. Only for tests.
  @visibleForTesting
  static void reset() => _selfSignedHosts = const <String>{};

  static Uri? _tryParse(String raw) {
    String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!trimmed.contains('://')) {
      trimmed = 'https://$trimmed';
    }
    try {
      final Uri uri = Uri.parse(trimmed);
      if (uri.host.isEmpty) {
        return null;
      }
      return uri;
    } on FormatException {
      return null;
    }
  }
}

/// Global [HttpOverrides] that permits self-signed TLS certificates for hosts
/// registered in [SelfSignedCertTrust].
class AtriumHttpOverrides extends HttpOverrides {
  AtriumHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpClient client = super.createHttpClient(context);
    client.badCertificateCallback = badCertificateCallback;
    return client;
  }

  /// Verification callback applied to [HttpClient.badCertificateCallback].
  ///
  /// Exposed for testing because `badCertificateCallback` on `dart:io`'s
  /// [HttpClient] is a write-only setter without a getter in the Dart SDK.
  @visibleForTesting
  static bool badCertificateCallback(
    X509Certificate cert,
    String host,
    int port,
  ) {
    return SelfSignedCertTrust.allows(host: host, port: port);
  }
}
