package com.rnescposprinter

import java.io.ByteArrayOutputStream
import java.nio.charset.Charset

internal object EscPosCommands {
  private const val ESC = 0x1B
  private const val GS = 0x1D

  fun text(text: String, codePage: String, feedLines: Int, cut: Boolean): ByteArray {
    val (codeTable, charset) = when (codePage) {
      "cp850" -> 2 to Charset.forName("IBM850")
      "windows1252" -> 16 to Charset.forName("windows-1252")
      else -> throw EscPosException(
        EscPosErrorCode.INVALID_ARGUMENT,
        "Unsupported code page: $codePage"
      )
    }

    return ByteArrayOutputStream().use { output ->
      output.write(byteArrayOf(ESC.toByte(), '@'.code.toByte()))
      output.write(byteArrayOf(ESC.toByte(), 't'.code.toByte(), codeTable.toByte()))
      output.write(text.toByteArray(charset))
      repeat(feedLines) { output.write('\n'.code) }
      if (cut) {
        output.write(partialCut())
      }
      output.toByteArray()
    }
  }

  fun initialize(): ByteArray = byteArrayOf(ESC.toByte(), '@'.code.toByte())

  fun setLineSpacing24(): ByteArray =
    byteArrayOf(ESC.toByte(), '3'.code.toByte(), 24)

  fun defaultLineSpacing(): ByteArray = byteArrayOf(ESC.toByte(), '2'.code.toByte())

  fun bitImageHeader(width: Int): ByteArray = byteArrayOf(
    ESC.toByte(),
    '*'.code.toByte(),
    33,
    (width and 0xFF).toByte(),
    ((width shr 8) and 0xFF).toByte()
  )

  fun finish(feedLines: Int, cut: Boolean): ByteArray =
    ByteArrayOutputStream().use { output ->
      output.write(defaultLineSpacing())
      repeat(feedLines) { output.write('\n'.code) }
      if (cut) {
        output.write(partialCut())
      }
      output.toByteArray()
    }

  private fun partialCut(): ByteArray =
    byteArrayOf(GS.toByte(), 'V'.code.toByte(), 66, 0)
}
