package org.gator.gator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var shareSink: EventChannel.EventSink? = null
    private var pendingShare: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ABI_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAbi") {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingShare" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareSink = events
                    pendingShare?.let {
                        events?.success(it)
                        pendingShare = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    shareSink = null
                }
            })

        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val payload = extractSharePayload(intent) ?: return
        pendingShare = payload
        shareSink?.success(payload)
    }

    private fun extractSharePayload(intent: Intent): Map<String, Any?>? {
        return when (intent.action) {
            Intent.ACTION_SEND -> extractSingleShare(intent)
            Intent.ACTION_SEND_MULTIPLE -> extractMultipleShare(intent)
            else -> null
        }
    }

    private fun extractSingleShare(intent: Intent): Map<String, Any?>? {
        val type = intent.type ?: return null
        if (type.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!text.isNullOrBlank()) {
                return mapOf("paths" to emptyList<String>(), "text" to text)
            }
            return null
        }
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return null
        val path = copyUriToCache(uri) ?: return null
        return mapOf("paths" to listOf(path), "text" to null)
    }

    private fun extractMultipleShare(intent: Intent): Map<String, Any?>? {
        val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        if (uris.isNullOrEmpty()) return null
        val paths = uris.mapNotNull { copyUriToCache(it) }
        if (paths.isEmpty()) return null
        return mapOf("paths" to paths, "text" to null)
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val name = queryDisplayName(uri) ?: "shared-${System.currentTimeMillis()}"
            val safeName = name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val outFile = File(cacheDir, "share-$safeName")
            input.use { inputStream ->
                FileOutputStream(outFile).use { output ->
                    inputStream.copyTo(output)
                }
            }
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme != "content") return uri.lastPathSegment
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index)
            }
        }
        return uri.lastPathSegment
    }

    companion object {
        private const val ABI_CHANNEL = "org.gator.gator/abi"
        private const val SHARE_METHOD_CHANNEL = "org.gator.gator/share"
        private const val SHARE_EVENT_CHANNEL = "org.gator.gator/share/events"
    }
}