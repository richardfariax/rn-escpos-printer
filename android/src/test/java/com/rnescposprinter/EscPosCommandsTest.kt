package com.rnescposprinter

import java.nio.charset.Charset
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class EscPosCommandsTest {
  @Test
  fun `text command selects CP850 and appends feed and cut`() {
    val bytes = EscPosCommands.text("ação", "cp850", feedLines = 1, cut = true)
    val expected = byteArrayOf(0x1B, '@'.code.toByte(), 0x1B, 't'.code.toByte(), 2) +
      "ação".toByteArray(Charset.forName("IBM850")) +
      byteArrayOf('\n'.code.toByte(), 0x1D, 'V'.code.toByte(), 66, 0)

    assertArrayEquals(expected, bytes)
  }

  @Test
  fun `bit image header encodes width in little endian`() {
    assertArrayEquals(
      byteArrayOf(0x1B, '*'.code.toByte(), 33, 0x40, 0x02),
      EscPosCommands.bitImageHeader(576)
    )
  }

  @Test
  fun `unsupported code page has stable error code`() {
    val error = assertThrows(EscPosException::class.java) {
      EscPosCommands.text("test", "utf8", feedLines = 0, cut = false)
    }

    assertEquals(EscPosErrorCode.INVALID_ARGUMENT, error.errorCode)
  }

  @Test
  fun `image height preserves the source aspect ratio`() {
    assertEquals(1152, EscPosImageEncoder.proportionalHeight(1000, 2000, 576))
  }
}
