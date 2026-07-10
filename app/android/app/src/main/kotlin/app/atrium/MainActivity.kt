package app.atrium

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so
// the BiometricPrompt can attach to a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "app.atrium/launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchPackage") {
                val packageName = call.argument<String>("package")
                if (packageName != null) {
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
                        startActivity(launchIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Package name is required", null)
                }
            } else if (call.method == "launchDeepLink") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
                        intent.addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URL is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
