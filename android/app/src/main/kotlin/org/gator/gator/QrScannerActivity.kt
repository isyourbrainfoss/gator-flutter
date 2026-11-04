package org.gator.gator

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.Log
import android.util.Size
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Full-screen camera QR scanner: CameraX preview + ZXing decoding.
 *
 * Result contract (see [MainActivity]):
 * - RESULT_OK with [EXTRA_RESULT]: decoded text
 * - RESULT_CANCELED: user closed the scanner
 * - RESULT_ERROR with [EXTRA_ERROR_CODE] / [EXTRA_ERROR_MESSAGE]: permission
 *   denied, no camera, or the camera failed to start. Never fail silently.
 */
class QrScannerActivity : ComponentActivity() {
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val finished = AtomicBoolean(false)
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var torchOn = false
    private val decoder = QrDecoder()

    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            startCamera()
        } else {
            // No rationale after a denial means "Don't ask again" / blocked by
            // policy: only the system settings can re-enable it.
            val permanent = !shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)
            Log.w(TAG, "Camera permission denied (permanent=$permanent)")
            finishWithError(
                if (permanent) ERROR_PERMISSION_PERMANENT else ERROR_PERMISSION,
                "Camera permission denied",
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = cancel()
            },
        )

        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            finishWithError(ERROR_NO_CAMERA, "This device has no camera")
            return
        }
        if (hasCameraPermission()) {
            startCamera()
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    override fun onDestroy() {
        try {
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
        }
        analysisExecutor.shutdown()
        super.onDestroy()
    }

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()

    private fun buildUi(): PreviewView {
        val previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        val frame = android.view.View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(240), dp(240), Gravity.CENTER)
            background = GradientDrawable().apply {
                setStroke(dp(2), Color.argb(200, 255, 255, 255))
                cornerRadius = dp(16).toFloat()
            }
        }
        val hint = TextView(this).apply {
            text = getString(R.string.qr_scan_hint)
            setTextColor(Color.WHITE)
            setShadowLayer(4f, 0f, 0f, Color.BLACK)
            textSize = 16f
            gravity = Gravity.CENTER
        }
        val torch = Button(this).apply {
            text = getString(R.string.qr_scan_torch)
            setOnClickListener { toggleTorch() }
        }
        val close = Button(this).apply {
            text = getString(R.string.qr_scan_cancel)
            setOnClickListener { cancel() }
        }
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(torch)
            addView(close)
        }
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            )
            setPadding(dp(24), dp(16), dp(24), dp(24))
            addView(hint)
            addView(buttons)
        }
        ViewCompat.setOnApplyWindowInsetsListener(bottom) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(dp(24), dp(16), dp(24), dp(24) + bars.bottom)
            insets
        }
        setContentView(
            FrameLayout(this).apply {
                setBackgroundColor(Color.BLACK)
                addView(previewView)
                addView(frame)
                addView(bottom)
            },
        )
        return previewView
    }

    private fun startCamera() {
        val previewView = buildUi()
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                bindCamera(provider, previewView)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start camera", e)
                finishWithError(ERROR_CAMERA, e.message ?: "Camera unavailable")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCamera(provider: ProcessCameraProvider, previewView: PreviewView) {
        provider.unbindAll()
        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }
        val analysis = ImageAnalysis.Builder()
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            Size(1280, 720),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                        ),
                    )
                    .build(),
            )
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
        analysis.setAnalyzer(analysisExecutor) { image -> processFrame(image) }

        val selectors = buildList {
            if (provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
                add(CameraSelector.DEFAULT_BACK_CAMERA)
            }
            if (provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                add(CameraSelector.DEFAULT_FRONT_CAMERA)
            }
        }
        if (selectors.isEmpty()) {
            finishWithError(ERROR_NO_CAMERA, "No usable camera found")
            return
        }
        var lastError: Exception? = null
        for (selector in selectors) {
            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(this, selector, preview, analysis)
                Log.i(TAG, "Camera started")
                return
            } catch (e: Exception) {
                Log.w(TAG, "Camera bind failed", e)
                lastError = e
            }
        }
        finishWithError(ERROR_CAMERA, lastError?.message ?: "Could not open the camera")
    }

    private fun toggleTorch() {
        val cam = camera ?: return
        if (!cam.cameraInfo.hasFlashUnit()) return
        torchOn = !torchOn
        cam.cameraControl.enableTorch(torchOn)
    }

    private fun processFrame(image: ImageProxy) {
        try {
            if (finished.get()) return
            val plane = image.planes.firstOrNull() ?: return
            val width = image.width
            val height = image.height
            val buffer = plane.buffer
            val rowStride = plane.rowStride
            val pixelStride = plane.pixelStride
            val data = ByteArray(width * height)
            if (pixelStride == 1 && rowStride == width) {
                buffer.rewind()
                buffer.get(data, 0, minOf(data.size, buffer.remaining()))
            } else {
                for (y in 0 until height) {
                    val rowStart = y * rowStride
                    for (x in 0 until width) {
                        val index = rowStart + x * pixelStride
                        if (index < buffer.limit()) data[y * width + x] = buffer.get(index)
                    }
                }
            }
            val code = decoder.decodeLuminance(data, width, height) ?: return
            if (finished.compareAndSet(false, true)) {
                Log.i(TAG, "QR code detected")
                runOnUiThread {
                    setResult(RESULT_OK, Intent().putExtra(EXTRA_RESULT, code))
                    finish()
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Frame analysis failed", t)
        } finally {
            image.close()
        }
    }

    private fun cancel() {
        if (finished.compareAndSet(false, true)) {
            setResult(RESULT_CANCELED)
            finish()
        }
    }

    private fun finishWithError(code: String, message: String) {
        if (!finished.compareAndSet(false, true)) return
        setResult(
            RESULT_ERROR,
            Intent()
                .putExtra(EXTRA_ERROR_CODE, code)
                .putExtra(EXTRA_ERROR_MESSAGE, message),
        )
        finish()
    }

    companion object {
        const val EXTRA_RESULT = "qr_code"
        const val EXTRA_ERROR_CODE = "qr_error_code"
        const val EXTRA_ERROR_MESSAGE = "qr_error_message"
        const val RESULT_ERROR = RESULT_FIRST_USER + 1
        const val ERROR_PERMISSION = "PERMISSION"
        const val ERROR_PERMISSION_PERMANENT = "PERMISSION_PERMANENT"
        const val ERROR_NO_CAMERA = "NO_CAMERA"
        const val ERROR_CAMERA = "CAMERA"
        private const val TAG = "GatorQrScanner"
    }
}
