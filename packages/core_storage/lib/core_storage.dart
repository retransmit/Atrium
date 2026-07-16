/// Public surface of `core_storage`.
///
/// Secure storage for API keys (Android Keystore via flutter_secure_storage),
/// Hive boxes for non-secret config, and biometric-unlock helpers.
library;

export 'package:hive_ce_flutter/hive_flutter.dart';

export 'src/biometric_gate.dart';
export 'src/hive_setup.dart';
export 'src/secure_storage.dart';
