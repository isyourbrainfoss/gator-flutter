package org.gator.gator

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Locates and runs the packaged croc binary (jniLibs/libcroc.so). */
class CrocRunner(private val context: Context) {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val homeDir: File
        get() = File(context.filesDir, "croc-home").also { it.mkdirs() }

    private val tmpDir: File
        get() = File(context.cacheDir, "croc-tmp").also { it.mkdirs() }

    fun packagedCrocPath(): String? {
        val file = File(context.applicationInfo.nativeLibraryDir, LIB_NAME)
        return if (file.exists() && file.length() > 0L) file.absolutePath else null
    }

    fun crocEnvironment(extra: Map<String, String> = emptyMap()): Map<String, String> {
        return buildMap {
            put("HOME", homeDir.absolutePath)
            put("TMPDIR", tmpDir.absolutePath)
            putAll(extra)
        }
    }

    /** Run croc --version off the main thread; [callback] is invoked on the main looper. */
    fun verifyCrocAsync(callback: (String?) -> Unit) {
        executor.execute {
            val version = verifyCroc()
            mainHandler.post { callback(version) }
        }
    }

    /** Blocking `--version` for diagnostics. Prefer [verifyCrocAsync] on the UI path. */
    private fun verifyCroc(): String? {
        val path = packagedCrocPath() ?: return null
        return try {
            val pb = ProcessBuilder(path, "--version")
                .redirectErrorStream(true)
                .directory(homeDir)
            pb.environment().putAll(crocEnvironment())
            val proc = pb.start()
            val finished = proc.waitFor(5, TimeUnit.SECONDS)
            if (!finished) {
                proc.destroyForcibly()
                Log.w(TAG, "verifyCroc timed out for $path")
                return null
            }
            val output = proc.inputStream.bufferedReader().readText().trim()
            val code = proc.exitValue()
            if (code == 0 && output.isNotEmpty()) output else null
        } catch (e: Exception) {
            Log.e(TAG, "verifyCroc failed for $path", e)
            null
        }
    }

    fun diagnostics(): Map<String, Any?> {
        val path = packagedCrocPath()
        val file = path?.let { File(it) }
        return mapOf(
            "path" to path,
            "exists" to (file?.exists() == true),
            "size" to (file?.length() ?: 0L),
            "abis" to Build.SUPPORTED_ABIS.toList(),
            "nativeLibDir" to context.applicationInfo.nativeLibraryDir,
        )
    }

    companion object {
        private const val TAG = "CrocRunner"
        private const val LIB_NAME = "libcroc.so"
    }
}
