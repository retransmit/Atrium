/// Public surface of `core_profile`.
///
/// Profile + Instance CRUD over Hive (non-secret) and the Android Keystore
/// (secrets), Riverpod providers for the active profile and per-service
/// instance lookup, and JSON import/export.
library;

export 'src/profile_providers.dart';
export 'src/profile_repository.dart';
