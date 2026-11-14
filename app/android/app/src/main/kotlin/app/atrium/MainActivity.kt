package app.atrium

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so
// the BiometricPrompt can attach to a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "app.atrium/launcher"
    private val SHARE_CHANNEL = "app.atrium/share"

    // A .torrent is kilobytes. Anything this large is a mis-share (a video
    // sent to the wrong app), and reading it would just stall the UI.
    private val MAX_TORRENT_BYTES = 10 * 1024 * 1024

    // A batch this size is already unusual; anything beyond it is a mis-share
    // and reading it would block the UI thread for a long time.
    private val MAX_BATCH_FILES = 200

    private var shareChannel: MethodChannel? = null

    // The intent Atrium was launched with, held until Dart asks for it. Dart
    // is not running yet when a cold start arrives, so it cannot be pushed.
    private var pendingShareIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pendingShareIntent = intent

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialShare") {
                    // Consume it. Without clearing, a rotation or a resume
                    // would re-deliver the same torrent and add it twice.
                    val consumed = pendingShareIntent
                    pendingShareIntent = null
                    result.success(runCatching { sharePayload(consumed) }.getOrNull())
                } else {
                    result.notImplemented()
                }
            }
        }

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

    // Reached when Atrium is already running (launchMode is singleTop), so
    // Dart is live and the payload can be pushed straight across.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingShareIntent = null
        val payload = runCatching { sharePayload(intent) }.getOrNull() ?: return
        shareChannel?.invokeMethod("onShare", payload)
    }

    /// Normalises a share intent into a map Dart can consume, or null when the
    /// intent carries nothing to add (a plain launcher tap, for instance).
    ///
    /// Shared text is passed through verbatim: deciding whether it holds a
    /// magnet or a link is Dart's job, where it can be unit tested.
    private fun sharePayload(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return null
                when (uri.scheme?.lowercase()) {
                    "magnet" -> mapOf("kind" to "magnet", "uri" to uri.toString())
                    "atrium" -> mapOf("kind" to "link", "uri" to uri.toString())
                    "content" -> filePayload(uri)
                    else -> null
                }
            }
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    mapOf("kind" to "text", "value" to text)
                } else {
                    // ClipData as well as EXTRA_STREAM: a read grant only ever
                    // covers the data URI and the clip, never a bare extra, so
                    // senders that populate only the extra hand over a URI we
                    // are not allowed to open. Real share sheets set the clip.
                    val uri = streamUri(intent) ?: clipUri(intent)
                    if (uri == null) null else filePayload(uri)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = streamUris(intent).ifEmpty { clipUris(intent) }
                if (uris.isEmpty()) null else filesPayload(uris)
            }
            else -> null
        }
    }

    /// Reads a batch of shared torrents.
    ///
    /// One unreadable file does not sink the whole batch: it is counted and the
    /// rest still go through, because losing 49 torrents because the 50th was
    /// odd would be worse than telling the user one was skipped.
    private fun filesPayload(uris: List<Uri>): Map<String, Any?> {
        val items = ArrayList<Map<String, Any?>>()
        var skipped = 0
        for (uri in uris.take(MAX_BATCH_FILES)) {
            val one = filePayload(uri)
            if (one["kind"] == "file") {
                items.add(mapOf("name" to one["name"], "bytes" to one["bytes"]))
            } else {
                skipped++
            }
        }
        if (items.isEmpty()) return mapOf("kind" to "unreadable")
        return mapOf(
            "kind" to "files",
            "items" to items,
            "skipped" to skipped,
            "dropped" to maxOf(0, uris.size - MAX_BATCH_FILES),
        )
    }

    private fun streamUris(intent: Intent): List<Uri> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        } ?: emptyList()

    /// Every URI on the clip. Share sheets put the files here as well as in
    /// EXTRA_STREAM, and only the clip carries the read grant.
    private fun clipUris(intent: Intent): List<Uri> {
        val clip = intent.clipData ?: return emptyList()
        val out = ArrayList<Uri>(clip.itemCount)
        for (i in 0 until clip.itemCount) {
            clip.getItemAt(i)?.uri?.let { out.add(it) }
        }
        return out
    }

    /// Reads a content:// URI into bytes. The read grant belongs to this
    /// activity, so Dart cannot do this itself.
    ///
    /// Every failure reports a reason rather than returning null. Swallowing
    /// them silently left the user watching Atrium open and do nothing at all,
    /// with no clue why.
    private fun filePayload(uri: Uri): Map<String, Any?> {
        val bytes = try {
            contentResolver.openInputStream(uri)?.use { it.readAtMost(MAX_TORRENT_BYTES) }
        } catch (e: SecurityException) {
            // The sender did not actually grant read access to this URI.
            return mapOf("kind" to "unreadable")
        } catch (e: Exception) {
            return mapOf("kind" to "unreadable")
        } ?: return mapOf("kind" to "unreadable")

        if (bytes.size > MAX_TORRENT_BYTES) return mapOf("kind" to "tooLarge")
        if (bytes.isEmpty()) return mapOf("kind" to "empty")
        return mapOf("kind" to "file", "name" to displayName(uri), "bytes" to bytes)
    }

    /// The first URI on the intent's clip, which is where a share sheet puts
    /// the file it is handing over.
    private fun clipUri(intent: Intent): Uri? =
        intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri

    /// Reads just past [limit] so an oversized stream is detected without
    /// pulling the whole thing into memory first. The caller compares the
    /// returned size against the limit to tell the two cases apart.
    private fun java.io.InputStream.readAtMost(limit: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val chunk = ByteArray(8 * 1024)
        var total = 0
        while (total <= limit) {
            val read = read(chunk)
            if (read < 0) break
            out.write(chunk, 0, read)
            total += read
        }
        return out.toByteArray()
    }

    private fun displayName(uri: Uri): String? =
        runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null
                }
        }.getOrNull() ?: uri.lastPathSegment

    private fun streamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
}
