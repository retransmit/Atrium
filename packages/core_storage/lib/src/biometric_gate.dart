import 'package:local_auth/local_auth.dart';

/// Optional biometric / device-credential unlock at app launch.
///
/// Atrium does not force this - it's an opt-in setting. When enabled, the
/// app shell calls [authenticate] before unlocking the UI; if the user
/// cancels or fails, the app stays at the lock screen.
///
/// The actual decryption of secrets does NOT depend on biometric - Android
/// Keystore keys aren't biometric-bound. This gate is a UI lock only. That's
/// a deliberate trade-off: it keeps the app usable when the user changes
/// biometrics or wipes fingerprints, but means a determined attacker with
/// device access can extract secrets. For the "media remote" threat model
/// this is the right level.
class BiometricGate {
  BiometricGate({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True if the device has any usable biometric / device-credential method
  /// enrolled. Settings UI grays out the toggle when this is false.
  Future<bool> isAvailable() async {
    final bool supported = await _auth.isDeviceSupported();
    if (!supported) {
      return false;
    }
    final bool canCheck = await _auth.canCheckBiometrics;
    return canCheck || await _auth.isDeviceSupported();
  }

  /// Prompts the user. Returns true on successful auth.
  ///
  /// [reason] is shown to the user in the system prompt - keep it short and
  /// concrete ("Unlock Atrium").
  Future<bool> authenticate({String reason = 'Unlock Atrium'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on Exception {
      return false;
    }
  }
}
