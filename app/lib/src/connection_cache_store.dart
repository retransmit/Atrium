import 'package:core_networking/core_networking.dart';
import 'package:hive_ce/hive.dart';

/// Hive-backed [ConnectionCacheStore]: persists the resolver's LAN/WAN verdicts
/// into the [AtriumBoxes.connectionCache] box so a cold start can reuse the last
/// decision (while still within its TTL) instead of re-probing the LAN.
///
/// Each verdict is encoded as a `"useLocal;expiresAtMs"` string (the box is a
/// `Box<String>`, matching the app's other Hive boxes).
class HiveConnectionCacheStore implements ConnectionCacheStore {
  HiveConnectionCacheStore(this._box);

  final Box<String> _box;

  @override
  PersistedConnectionVerdict? get(String key) {
    final String? raw = _box.get(key);
    if (raw == null) {
      return null;
    }
    final List<String> parts = raw.split(';');
    if (parts.length != 2) {
      return null;
    }
    final int? expiresAtMs = int.tryParse(parts[1]);
    if (expiresAtMs == null) {
      return null;
    }
    return PersistedConnectionVerdict(
      useLocal: parts[0] == 'true',
      expiresAtMs: expiresAtMs,
    );
  }

  @override
  void save(String key, PersistedConnectionVerdict verdict) {
    _box.put(key, '${verdict.useLocal};${verdict.expiresAtMs}');
  }

  @override
  void deleteWhereKeyStartsWith(String prefix) {
    final List<String> stale = _box.keys
        .whereType<String>()
        .where((String k) => k.startsWith(prefix))
        .toList();
    if (stale.isNotEmpty) {
      _box.deleteAll(stale);
    }
  }
}
