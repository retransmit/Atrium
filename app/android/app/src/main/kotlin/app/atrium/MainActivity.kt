package app.atrium

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so
// the BiometricPrompt can attach to a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
