import 'package:hive_ce_flutter/hive_flutter.dart';

/// Initializes Hive for Atrium. Idempotent - safe to call multiple times.
///
/// Call once during app startup, before any code that opens a box. The box
/// names below are reserved for Atrium's own use; service packages that want
/// to cache their own data should use a prefixed name (e.g.,
/// `service.sonarr.queue`).
Future<void> initAtriumHive() async {
  if (_initialized) {
    return;
  }
  await Hive.initFlutter(_hiveSubdirectory);
  // TypeAdapter registrations go here as models grow.
  _initialized = true;
}

bool _initialized = false;

/// Subdirectory under the app's documents dir where Hive boxes are written.
/// Excluding this from Android auto-backup is handled by the manifest in
/// `app/android/app/src/main/res/xml/backup_rules.xml`.
const String _hiveSubdirectory = 'atrium';

/// Reserved Hive box names. Service packages should NOT use these.
abstract final class AtriumBoxes {
  /// App-level settings: theme mode, accent seed, last active profile id.
  static const String settings = 'atrium.settings';

  /// Profiles & instances (non-secret fields). Secrets live in
  /// `AtriumSecureStorage`.
  static const String profiles = 'atrium.profiles';

  /// Cache of the last-known good URL per instance per network fingerprint,
  /// so we don't probe LAN every cold start. Short-lived TTL.
  static const String connectionCache = 'atrium.connection_cache';

  /// Per-instance health snapshot, refreshed on app foreground.
  static const String healthCache = 'atrium.health_cache';
}
