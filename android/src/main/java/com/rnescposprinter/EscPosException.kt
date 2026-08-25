package com.rnescposprinter

internal class EscPosException(
  val errorCode: String,
  message: String,
  cause: Throwable? = null
) : Exception(message, cause)

internal object EscPosErrorCode {
  const val BLUETOOTH_DISABLED = "ERR_BLUETOOTH_DISABLED"
  const val BLUETOOTH_PERMISSION = "ERR_BLUETOOTH_PERMISSION"
  const val CONNECTION_FAILED = "ERR_CONNECTION_FAILED"
  const val CONNECTION_LOST = "ERR_CONNECTION_LOST"
  const val CONNECTION_TIMEOUT = "ERR_CONNECTION_TIMEOUT"
  const val INVALID_ARGUMENT = "ERR_INVALID_ARGUMENT"
  const val INVALID_IMAGE = "ERR_INVALID_IMAGE"
  const val NOT_CONNECTED = "ERR_NOT_CONNECTED"
  const val PRINTER_NOT_FOUND = "ERR_PRINTER_NOT_FOUND"
  const val WRITE_FAILED = "ERR_WRITE_FAILED"
}
