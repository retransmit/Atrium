import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

/// Thin wrapper over `flutter_secure_storage` for storing secret material
/// (API keys, session tokens, passwords).
///
/// On Android this is backed by EncryptedSharedPreferences, which in turn
/// uses a key from the Android Keystore. The user has to either remove the
/// app or wipe app data to lose stored secrets.
///
/// Keys are namespaced by the caller - convention is `instance:<id>:<field>`
/// (e.g., `instance:9f3b...:apiKey`). The storage itself doesn't enforce
/// this, but every caller in Atrium follows the same pattern so the keys are
/// inspectable in tooling.
class AtriumSecureStorage {
  /// Creates a storage with a real backing store. Inject a custom
  /// [FlutterSecureStorage] in tests.
  AtriumSecureStorage({FlutterSecureStorage? store})
      : _store = store ??
            const FlutterSecureStorage();

  final FlutterSecureStorage _store;

  /// Reads a secret. Returns `null` if unset.
  Future<String?> read(String key) => _store.read(key: key);

  /// Writes a secret. Passing `null` deletes the key.
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _store.delete(key: key);
    } else {
      await _store.write(key: key, value: value);
    }
  }

  /// Deletes a secret. No-op if it doesn't exist.
  Future<void> delete(String key) => _store.delete(key: key);

  /// Removes every secret in the store. Use only for "log out everywhere"
  /// flows - there's no undo.
  Future<void> wipeAll() => _store.deleteAll();

  /// Returns true if [key] is present.
  Future<bool> contains(String key) => _store.containsKey(key: key);

  /// All keys currently in the store. Order is implementation-defined.
  Future<Iterable<String>> keys() async {
    final Map<String, String> all = await _store.readAll();
    return all.keys;
  }

  /// Build a namespaced secret key for the given [instanceId] and [field].
  /// Centralizing this here keeps the convention in one place.
  @visibleForTesting
  static String instanceKey(String instanceId, String field) =>
      'instance:$instanceId:$field';
}
