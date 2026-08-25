package com.rnescposprinter

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableNativeArray
import com.facebook.react.bridge.WritableNativeMap
import java.util.concurrent.Executors

class RnEscposPrinterModule(reactContext: ReactApplicationContext) :
  NativeRnEscposPrinterSpec(reactContext) {
  private val transport = EscPosBluetoothTransport(reactContext)
  private val operationExecutor = Executors.newSingleThreadExecutor { runnable ->
    Thread(runnable, "rn-escpos-printer").apply { isDaemon = true }
  }

  override fun initialize(promise: Promise) = execute(promise) {
    transport.initialize()
    null
  }

  override fun getPrinters(_scanDurationMs: Double, promise: Promise) = execute(promise) {
    val devices = WritableNativeArray()
    transport.pairedDevices().forEach { printer ->
      devices.pushMap(WritableNativeMap().apply {
        putString("id", printer.id)
        putString("name", printer.name)
        putString("address", printer.address)
        putString("transport", "bluetooth-classic")
        putBoolean("connected", printer.connected)
      })
    }
    devices
  }

  override fun connect(identifier: String, timeoutMs: Double, promise: Promise) = execute(promise) {
    transport.connect(identifier, timeoutMs.toLong())
    null
  }

  override fun disconnect(promise: Promise) = execute(promise) {
    transport.disconnect()
    null
  }

  override fun isConnected(promise: Promise) = execute(promise) {
    transport.isConnected()
  }

  override fun printText(
    text: String,
    codePage: String,
    feedLines: Double,
    cut: Boolean,
    promise: Promise
  ) = execute(promise) {
    val bytes = EscPosCommands.text(
      text = text,
      codePage = codePage,
      feedLines = feedLines.toInt(),
      cut = cut
    )
    transport.write(bytes)
    null
  }

  override fun printImageBase64(
    base64: String,
    paperWidth: Double,
    threshold: Double,
    feedLines: Double,
    cut: Boolean,
    promise: Promise
  ) = execute(promise) {
    val bytes = EscPosImageEncoder.encode(
      value = base64,
      paperWidth = paperWidth.toInt(),
      threshold = threshold.toInt(),
      feedLines = feedLines.toInt(),
      cut = cut
    )
    transport.write(bytes)
    null
  }

  override fun invalidate() {
    transport.invalidate()
    operationExecutor.shutdownNow()
    super.invalidate()
  }

  private fun execute(promise: Promise, operation: () -> Any?) {
    operationExecutor.execute {
      try {
        promise.resolve(operation())
      } catch (error: EscPosException) {
        promise.reject(error.errorCode, error.message, error)
      } catch (error: Throwable) {
        promise.reject(EscPosErrorCode.WRITE_FAILED, error.message, error)
      }
    }
  }

  companion object {
    const val NAME = NativeRnEscposPrinterSpec.NAME
  }
}
