package com.rnescposprinter

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.IOException
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

internal data class EscPosPrinterDevice(
  val id: String,
  val name: String,
  val address: String,
  val connected: Boolean
)

internal class EscPosBluetoothTransport(private val context: Context) {
  private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
  private val connectExecutor = Executors.newCachedThreadPool { runnable ->
    Thread(runnable, "rn-escpos-connect").apply { isDaemon = true }
  }

  @Volatile
  private var socket: BluetoothSocket? = null

  @Synchronized
  fun initialize() {
    adapter()
  }

  @Synchronized
  fun pairedDevices(): List<EscPosPrinterDevice> {
    val currentAddress = socket?.remoteDevice?.address
    return adapter().bondedDevices
      .sortedWith(compareBy({ it.name.orEmpty().lowercase() }, { it.address }))
      .map { device ->
        EscPosPrinterDevice(
          id = device.address,
          name = device.name?.takeIf(String::isNotBlank) ?: "Bluetooth printer",
          address = device.address,
          connected = device.address.equals(currentAddress, ignoreCase = true) &&
            socket?.isConnected == true
        )
      }
  }

  @Synchronized
  fun connect(identifier: String, timeoutMs: Long) {
    val bluetoothAdapter = adapter()
    val device = bluetoothAdapter.bondedDevices.firstOrNull {
      it.address.equals(identifier, ignoreCase = true)
    } ?: throw EscPosException(
      EscPosErrorCode.PRINTER_NOT_FOUND,
      "No paired Bluetooth device was found for $identifier"
    )

    if (socket?.isConnected == true &&
      socket?.remoteDevice?.address.equals(device.address, ignoreCase = true)
    ) {
      return
    }

    disconnect()
    val deadlineNanos = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMs)
    var lastError: Throwable? = null

    for (candidate in socketCandidates(device)) {
      val remainingNanos = deadlineNanos - System.nanoTime()
      if (remainingNanos <= 0) {
        candidate.closeQuietly()
        break
      }

      val connection = connectExecutor.submit { candidate.connect() }
      try {
        connection.get(remainingNanos, TimeUnit.NANOSECONDS)
        socket = candidate
        write(EscPosCommands.initialize())
        return
      } catch (error: TimeoutException) {
        connection.cancel(true)
        candidate.closeQuietly()
        throw EscPosException(
          EscPosErrorCode.CONNECTION_TIMEOUT,
          "Bluetooth connection timed out after $timeoutMs ms",
          error
        )
      } catch (error: Exception) {
        lastError = error.cause ?: error
        candidate.closeQuietly()
      }
    }

    throw EscPosException(
      EscPosErrorCode.CONNECTION_FAILED,
      "Unable to open an ESC/POS Bluetooth connection to ${device.name ?: device.address}",
      lastError
    )
  }

  @Synchronized
  fun disconnect() {
    socket?.closeQuietly()
    socket = null
  }

  fun isConnected(): Boolean = socket?.isConnected == true

  @Synchronized
  fun write(bytes: ByteArray) {
    val activeSocket = socket?.takeIf { it.isConnected }
      ?: throw EscPosException(EscPosErrorCode.NOT_CONNECTED, "No printer is connected")

    try {
      writeWithBackpressure(activeSocket.outputStream, bytes)
    } catch (error: IOException) {
      disconnect()
      throw EscPosException(
        EscPosErrorCode.CONNECTION_LOST,
        "The Bluetooth connection was lost while printing",
        error
      )
    }
  }

  fun invalidate() {
    disconnect()
    connectExecutor.shutdownNow()
  }

  private fun adapter(): BluetoothAdapter {
    requireConnectPermission()
    val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    val bluetoothAdapter = manager?.adapter
      ?: throw EscPosException(
        EscPosErrorCode.BLUETOOTH_DISABLED,
        "Bluetooth is not available on this device"
      )
    if (!bluetoothAdapter.isEnabled) {
      throw EscPosException(EscPosErrorCode.BLUETOOTH_DISABLED, "Bluetooth is disabled")
    }
    return bluetoothAdapter
  }

  private fun requireConnectPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
      context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) !=
      PackageManager.PERMISSION_GRANTED
    ) {
      throw EscPosException(
        EscPosErrorCode.BLUETOOTH_PERMISSION,
        "BLUETOOTH_CONNECT permission has not been granted"
      )
    }
  }

  private fun socketCandidates(device: BluetoothDevice): List<BluetoothSocket> = buildList {
    try {
      add(device.createInsecureRfcommSocketToServiceRecord(sppUuid))
    } catch (_: IOException) {
      // The secure RFCOMM attempt below remains available.
    }
    try {
      add(device.createRfcommSocketToServiceRecord(sppUuid))
    } catch (_: IOException) {
      // Reported as a connection failure when neither socket can be created.
    }
  }

  private fun writeWithBackpressure(output: OutputStream, bytes: ByteArray) {
    val chunkSize = 512
    var offset = 0
    while (offset < bytes.size) {
      val length = minOf(chunkSize, bytes.size - offset)
      output.write(bytes, offset, length)
      output.flush()
      offset += length
      if (offset < bytes.size) {
        try {
          Thread.sleep(12)
        } catch (error: InterruptedException) {
          Thread.currentThread().interrupt()
          throw IOException("Bluetooth write interrupted", error)
        }
      }
    }
  }

  private fun BluetoothSocket.closeQuietly() {
    try {
      close()
    } catch (_: IOException) {
      // The socket is already unusable; no recovery is possible here.
    }
  }
}
