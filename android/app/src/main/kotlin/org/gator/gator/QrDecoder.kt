package org.gator.gator

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.LuminanceSource
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.common.HybridBinarizer

/**
 * QR decoding with ZXing (Apache-2.0, pure Java). Unlike ML Kit it needs no
 * Google Play Services, no proprietary model and no network, so scanning
 * works on de-Googled / microG ROMs and in F-Droid builds.
 */
class QrDecoder {
    private val reader = MultiFormatReader().apply {
        setHints(
            mapOf(
                DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
                DecodeHintType.TRY_HARDER to true,
                DecodeHintType.CHARACTER_SET to "UTF-8",
            ),
        )
    }

    /** Decode a greyscale (Y plane) camera frame; null when no QR is visible. */
    fun decodeLuminance(data: ByteArray, width: Int, height: Int): String? {
        val source = PlanarYUVLuminanceSource(
            data, width, height, 0, 0, width, height, false,
        )
        return decode(source)
    }

    /** Decode a QR from an image file (gallery / screenshot); null if none. */
    fun decodeImageFile(path: String): String? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_IMAGE_SIDE) {
            sample *= 2
        }
        val bitmap = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        return try {
            decodeBitmap(bitmap)
        } finally {
            bitmap.recycle()
        }
    }

    private fun decodeBitmap(bitmap: Bitmap): String? {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        return decode(RGBLuminanceSource(w, h, pixels))
    }

    private fun decode(source: LuminanceSource): String? {
        // Normal, then inverted (light-on-dark codes, e.g. dark-mode QR).
        for (candidate in listOf(source, source.invert())) {
            try {
                val text = reader.decodeWithState(BinaryBitmap(HybridBinarizer(candidate))).text
                if (!text.isNullOrBlank()) return text
            } catch (_: NotFoundException) {
            } catch (_: ReaderException) {
            } finally {
                reader.reset()
            }
        }
        return null
    }

    companion object {
        private const val MAX_IMAGE_SIDE = 2048
    }
}
