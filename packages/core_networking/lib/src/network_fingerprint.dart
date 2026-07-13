import 'package:connectivity_plus/connectivity_plus.dart';

/// A coarse identifier for "what network am I currently on", used as the
/// cache key for the LAN/WAN routing decision.
///
/// We deliberately do NOT include the Wi-Fi SSID - reading the SSID on
/// modern Android requires `ACCESS_FINE_LOCATION`, which is a poor UX cost
/// for a one-line cache key. Probing the LAN URL itself is the real signal;
/// the fingerprint just buckets cache entries so a phone bouncing between
/// Wi-Fi and mobile data doesn't keep using a stale "LAN reachable" verdict.
class NetworkFingerprint {
  const NetworkFingerprint(this.transports);

  /// Empty fingerprint - used before connectivity is known.
  static const NetworkFingerprint unknown =
      NetworkFingerprint(<ConnectivityResult>[]);

  /// Connectivity transports currently active (Wi-Fi, mobile, ethernet…).
  /// `connectivity_plus` returns a list because a device can be on more than
  /// one transport simultaneously (Wi-Fi + ethernet via dock, for example).
  final List<ConnectivityResult> transports;

  /// Cache key form. Stable across runs.
  String get key {
    if (transports.isEmpty) {
      return 'net:none';
    }
    final List<String> names =
        transports.map((ConnectivityResult t) => t.name).toList()..sort();
    return 'net:${names.join(',')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetworkFingerprint && other.key == key);

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}
