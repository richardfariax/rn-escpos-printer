package com.rnescposprinter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

internal object EscPosImageEncoder {
  private const val MAX_BASE64_LENGTH = 24_000_000
  private const val MAX_IMAGE_HEIGHT = 30_000

  fun encode(
    value: String,
    paperWidth: Int,
    threshold: Int,
    feedLines: Int,
    cut: Boolean
  ): ByteArray {
    val payload = value.substringAfter(',', value).replace("\n", "").replace("\r", "")
    if (payload.isEmpty() || payload.length > MAX_BASE64_LENGTH) {
      throw EscPosException(
        EscPosErrorCode.INVALID_IMAGE,
        "The base64 image is empty or exceeds the 24 MB input limit"
      )
    }

    val bytes = try {
      Base64.decode(payload, Base64.DEFAULT)
    } catch (error: IllegalArgumentException) {
      throw EscPosException(EscPosErrorCode.INVALID_IMAGE, "Invalid base64 image", error)
    }
    val original = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
      ?: throw EscPosException(EscPosErrorCode.INVALID_IMAGE, "Unsupported image data")

    try {
      val targetWidth = when (paperWidth) {
        58 -> 384
        80 -> 576
        else -> throw EscPosException(
          EscPosErrorCode.INVALID_ARGUMENT,
          "Paper width must be 58 or 80"
        )
      }
      val targetHeight = proportionalHeight(original.width, original.height, targetWidth)
      if (targetHeight > MAX_IMAGE_HEIGHT) {
        throw EscPosException(
          EscPosErrorCode.INVALID_IMAGE,
          "The proportional image height exceeds $MAX_IMAGE_HEIGHT pixels"
        )
      }

      val scaled = Bitmap.createScaledBitmap(original, targetWidth, targetHeight, true)
      try {
        return encodeBitmap(scaled, threshold, feedLines, cut)
      } finally {
        if (scaled !== original) {
          scaled.recycle()
        }
      }
    } catch (error: OutOfMemoryError) {
      throw EscPosException(
        EscPosErrorCode.INVALID_IMAGE,
        "The image is too large to process safely",
        error
      )
    } finally {
      original.recycle()
    }
  }

  private fun encodeBitmap(
    bitmap: Bitmap,
    threshold: Int,
    feedLines: Int,
    cut: Boolean
  ): ByteArray = ByteArrayOutputStream().use { output ->
    output.write(EscPosCommands.initialize())
    output.write(EscPosCommands.setLineSpacing24())

    val pixels = IntArray(bitmap.width * 24)
    var stripeTop = 0
    while (stripeTop < bitmap.height) {
      val stripeHeight = minOf(24, bitmap.height - stripeTop)
      pixels.fill(0)
      bitmap.getPixels(
        pixels,
        0,
        bitmap.width,
        0,
        stripeTop,
        bitmap.width,
        stripeHeight
      )
      output.write(EscPosCommands.bitImageHeader(bitmap.width))

      for (x in 0 until bitmap.width) {
        for (byteIndex in 0 until 3) {
          var imageByte = 0
          for (bit in 0 until 8) {
            val y = byteIndex * 8 + bit
            if (y < stripeHeight && isBlack(pixels[y * bitmap.width + x], threshold)) {
              imageByte = imageByte or (1 shl (7 - bit))
            }
          }
          output.write(imageByte)
        }
      }
      output.write('\n'.code)
      stripeTop += 24
    }

    output.write(EscPosCommands.finish(feedLines, cut))
    output.toByteArray()
  }

  private fun isBlack(color: Int, threshold: Int): Boolean {
    val alpha = color ushr 24 and 0xFF
    val red = color ushr 16 and 0xFF
    val green = color ushr 8 and 0xFF
    val blue = color and 0xFF
    val luminance = (red * 299 + green * 587 + blue * 114) / 1_000
    val blendedWithWhite = (luminance * alpha + 255 * (255 - alpha)) / 255
    return blendedWithWhite < threshold
  }

  internal fun proportionalHeight(sourceWidth: Int, sourceHeight: Int, targetWidth: Int): Int =
    (sourceHeight * (targetWidth.toDouble() / sourceWidth))
      .roundToInt()
      .coerceAtLeast(1)
}
