import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'network_fingerprint.dart';

/// Picks between the LAN URL and WAN URL of an [Instance] for outgoing
/// requests.
///
/// Strategy:
///
/// * `UrlMode.forceLocal`  → always returns the LAN URL.
/// * `UrlMode.forceExternal` → always returns the WAN URL.
/// * `UrlMode.auto` (default) → on first request for the instance under the
///   current [NetworkFingerprint], probes the LAN URL with a short timeout.
///   If the probe gets *any* HTTP response (even 401/404), the host is
///   reachable on the LAN and we cache "use LAN" until the TTL expires or
///   connectivity changes. If the probe fails, we fall back to WAN and cache
///   "use WAN" with the same TTL.
///
/// The cache is per-instance per-network, so a phone moving from home Wi-Fi
/// to mobile data invalidates only the home-Wi-Fi entry.
class ConnectionResolver {
  ConnectionResolver({
    required Connectivity connectivity,
    Dio? probeClient,
    this.probeTimeout = const Duration(milliseconds: 1500),
    this.cacheTtl = const Duration(minutes: 5),
  })  : _connectivity = connectivity,
        _probeClient = probeClient ?? _buildProbeClient();

  final Connectivity _connectivity;
  final Dio _probeClient;

  /// How long to wait for a LAN probe to respond before giving up.
  final Duration probeTimeout;

  /// How long a cached LAN/WAN verdict stays trusted for a given
  /// (instance, network) pair before being re-probed.
  final Duration cacheTtl;

  final Map<_CacheKey, _CacheEntry> _cache = <_CacheKey, _CacheEntry>{};
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  NetworkFingerprint _currentFingerprint = NetworkFingerprint.unknown;

  /// Begin listening to connectivity changes. Call once at app start.
  Future<void> start() async {
    final List<ConnectivityResult> initial =
        await _connectivity.checkConnectivity();
    _currentFingerprint = NetworkFingerprint(initial);
    _connectivitySub = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> transports,
    ) {
      final NetworkFingerprint next = NetworkFingerprint(transports);
      if (next != _currentFingerprint) {
        _currentFingerprint = next;
        // Connectivity changed - drop every cached verdict so the next
        // request re-probes under the new network.
        _cache.clear();
      }
    });
  }

  /// Release resources. Call on app dispose.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _probeClient.close(force: true);
  }

  /// Resolve the URL to use for [instance] right now. Always returns a
  /// non-null `Uri` even if both URLs are blank - callers should validate
  /// instances before they get here.
  Future<Uri> resolve(Instance instance) async {
    final Uri? local = _tryParse(instance.localUrl);
    final Uri? external = _tryParse(instance.externalUrl);

    switch (instance.urlMode) {
      case UrlMode.forceLocal:
        return local ?? external ?? Uri();
      case UrlMode.forceExternal:
        return external ?? local ?? Uri();
      case UrlMode.auto:
        // If only one URL is configured, no choice to make.
        if (local == null) {
          return external ?? Uri();
        }
        if (external == null) {
          return local;
        }

        final _CacheKey key = _CacheKey(instance.id, _currentFingerprint);
        final _CacheEntry? hit = _cache[key];
        if (hit != null && !hit.isExpired) {
          return hit.useLocal ? local : external;
        }

        final bool reachable = await _probe(local);
        _cache[key] = _CacheEntry(
          useLocal: reachable,
          expiresAt: DateTime.now().add(cacheTtl),
        );
        return reachable ? local : external;
    }
  }

  /// Force the next [resolve] for [instanceId] to re-probe instead of using
  /// any cached verdict. Useful when the user just edited the URLs.
  void invalidate(String instanceId) {
    _cache.removeWhere((_CacheKey k, _) => k.instanceId == instanceId);
  }

  Future<bool> _probe(Uri url) async {
    try {
      final Response<dynamic> response = await _probeClient.requestUri(
        url,
        options: Options(
          method: 'GET',
          sendTimeout: probeTimeout,
          receiveTimeout: probeTimeout,
          // Treat any HTTP response (even 401 / 404) as "host is up".
          validateStatus: (_) => true,
        ),
      );
      // Any non-zero status means we got bytes back from the host.
      return response.statusCode != null;
    } on Exception {
      return false;
    }
  }

  static Uri? _tryParse(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    try {
      final Uri uri = Uri.parse(raw);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return null;
      }
      return uri;
    } on FormatException {
      return null;
    }
  }

  static Dio _buildProbeClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 1500),
        sendTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
        followRedirects: false,
      ),
    );
  }

  @visibleForTesting
  NetworkFingerprint get currentFingerprint => _currentFingerprint;

  @visibleForTesting
  int get cacheSize => _cache.length;
}

class _CacheKey {
  const _CacheKey(this.instanceId, this.fingerprint);

  final String instanceId;
  final NetworkFingerprint fingerprint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CacheKey &&
          other.instanceId == instanceId &&
          other.fingerprint == fingerprint);

  @override
  int get hashCode => Object.hash(instanceId, fingerprint);
}

class _CacheEntry {
  const _CacheEntry({required this.useLocal, required this.expiresAt});

  final bool useLocal;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
