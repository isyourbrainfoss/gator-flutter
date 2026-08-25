package org.gator.gator

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    private var shareSink: EventChannel.EventSink? = null
    private var pendingShare: Map<String, Any?>? = null
    private var pendingQrResult: MethodChannel.Result? = null
    private lateinit var crocRunner: CrocRunner
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val qrScanLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { activityResult ->
        val callback = pendingQrResult
        pendingQrResult = null
        if (callback == null) return@registerForActivityResult

        if (activityResult.resultCode == RESULT_OK) {
            callback.success(
                activityResult.data?.getStringExtra(QrScannerActivity.EXTRA_RESULT),
            )
        } else {
            callback.success(null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        crocRunner = CrocRunner(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ABI_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAbi") {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CROC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCrocPath" -> {
                        result.success(crocRunner.packagedCrocPath())
                    }
                    "verifyCroc" -> {
                        val replied = AtomicBoolean(false)
                        crocRunner.verifyCrocAsync { version ->
                            if (replied.compareAndSet(false, true)) {
                                try {
                                    result.success(version)
                                } catch (_: Exception) {
                                    // Already replied or engine gone.
                                }
                            }
                        }
                    }
                    "getCrocEnv" -> {
                        result.success(crocRunner.crocEnvironment())
                    }
                    "getCrocDiagnostics" -> {
                        result.success(crocRunner.diagnostics())
                    }
                    "getExecutableDir" -> {
                        val binDir = File(codeCacheDir, "bin")
                        if (!binDir.exists()) binDir.mkdirs()
                        result.success(binDir.absolutePath)
                    }
                    "setExecutable" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG", "path required", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("ENOENT", "file not found: $path", null)
                            return@setMethodCallHandler
                        }
                        val ok = file.setExecutable(true, false)
                        if (ok) {
                            try {
                                Os.chmod(path, OsConstants.S_IRWXU or OsConstants.S_IRGRP or OsConstants.S_IXGRP)
                            } catch (_: Exception) {
                                // setExecutable succeeded; chmod is best-effort.
                            }
                        }
                        result.success(ok)
                    }
                    else -> result.notImplemented()
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDirectory" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG", "path required", null)
                        } else {
                            result.success(openDirectory(path))
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanQrCode" -> {
                        if (pendingQrResult != null) {
                            result.error("BUSY", "QR scanner already open", null)
                            return@setMethodCallHandler
                        }
                        pendingQrResult = result
                        Log.i(TAG, "Launching native QR scanner")
                        qrScanLauncher.launch(Intent(this, QrScannerActivity::class.java))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEPALIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            ContextCompat.startForegroundService(
                                this,
                                Intent(this, TransferKeepaliveService::class.java),
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("START", e.message, null)
                        }
                    }
                    "stop" -> {
                        try {
                            stopService(Intent(this, TransferKeepaliveService::class.java))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STOP", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        handleShareIntent(intent)
    }

    override fun onDestroy() {
        val callback = pendingQrResult
        pendingQrResult = null
        if (callback != null) {
            try {
                callback.error("DESTROYED", "Activity destroyed before QR scan completed", null)
            } catch (_: Exception) {
                // Already replied.
            }
        }
        super.onDestroy()
    }

    private fun openDirectory(path: String): Boolean {
        val directory = File(path)
        if (!directory.exists()) {
            directory.mkdirs()
        }
        if (!directory.isDirectory) {
            return false
        }

        val documentUri = pathToDocumentUri(path) ?: return false

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(documentUri, DocumentsContract.Document.MIME_TYPE_DIR)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, documentUri)
            }
        }

        return try {
            startActivity(Intent.createChooser(intent, null))
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    private fun pathToDocumentUri(path: String): Uri? {
        val canonical = try {
            File(path).canonicalPath
        } catch (_: IOException) {
            path
        }

        val storageRoot = try {
            Environment.getExternalStorageDirectory().canonicalPath
        } catch (_: IOException) {
            return null
        }

        if (!canonical.startsWith(storageRoot)) {
            return null
        }

        val relative = canonical
            .removePrefix(storageRoot)
            .removePrefix("/")
        if (relative.isEmpty()) {
            return DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents",
                "primary:",
            )
        }

        val encoded = relative.split("/").joinToString("%2F") { segment ->
            URLEncoder.encode(segment, StandardCharsets.UTF_8.name()).replace("+", "%20")
        }
        return Uri.parse(
            "content://com.android.externalstorage.documents/document/primary:$encoded",
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val type = intent.type
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val uri = extraStreamUri(intent)
        val uris = extraStreamUris(intent)
        ioExecutor.execute {
            val payload = when (action) {
                Intent.ACTION_SEND -> buildSingleShare(type, text, uri)
                Intent.ACTION_SEND_MULTIPLE -> buildMultipleShare(uris)
                else -> null
            } ?: return@execute
            mainHandler.post { deliverShare(payload) }
        }
    }

    private fun deliverShare(payload: Map<String, Any?>) {
        val sink = shareSink
        if (sink != null) {
            sink.success(payload)
            pendingShare = null
        } else {
            pendingShare = payload
        }
    }

    private fun buildSingleShare(
        type: String?,
        text: String?,
        uri: Uri?,
    ): Map<String, Any?>? {
        if (uri != null) {
            val path = copyUriToCache(uri)
            if (path != null) {
                return mapOf("paths" to listOf(path), "text" to text)
            }
        }
        if (type?.startsWith("text/") == true && !text.isNullOrBlank()) {
            return mapOf("paths" to emptyList<String>(), "text" to text)
        }
        return null
    }

    private fun buildMultipleShare(uris: ArrayList<Uri>?): Map<String, Any?>? {
        if (uris.isNullOrEmpty()) return null
        val paths = uris.mapNotNull { copyUriToCache(it) }
        if (paths.isEmpty()) return null
        return mapOf("paths" to paths, "text" to null)
    }

    private fun extraStreamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun extraStreamUris(intent: Intent): ArrayList<Uri>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val name = queryDisplayName(uri) ?: "shared-${System.currentTimeMillis()}"
            val safeName = name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val outFile = File(cacheDir, "share-${System.nanoTime()}-$safeName")
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
        private const val TAG = "GatorMainActivity"
        private const val ABI_CHANNEL = "org.gator.gator/abi"
        private const val CROC_CHANNEL = "org.gator.gator/croc"
        private const val SHARE_METHOD_CHANNEL = "org.gator.gator/share"
        private const val SHARE_EVENT_CHANNEL = "org.gator.gator/share/events"
        private const val FILES_CHANNEL = "org.gator.gator/files"
        private const val QR_CHANNEL = "org.gator.gator/qr"
        private const val KEEPALIVE_CHANNEL = "org.gator.gator/keepalive"
    }
}
