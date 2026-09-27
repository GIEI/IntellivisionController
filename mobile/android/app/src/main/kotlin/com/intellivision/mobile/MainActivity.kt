package com.intellivision.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    @Volatile private var bluetoothSocket: BluetoothSocket? = null
    @Volatile private var pendingBluetoothSocket: BluetoothSocket? = null
    private var bluetoothSink: EventChannel.EventSink? = null
    private val bluetoothExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val bluetoothGeneration = AtomicInteger()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "intellivision_controller/preferences")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("controller", Context.MODE_PRIVATE)
                when (call.method) {
                    "getAll" -> result.success(mapOf("host" to prefs.getString("host", ""), "code" to prefs.getString("code", "482731"), "transport" to prefs.getString("transport", "wifi")))
                    "getPairedDevices" -> {
                        if (Build.VERSION.SDK_INT >= 31 && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 431)
                            result.error("permission_required", "Allow Bluetooth access, then refresh the device list.", null)
                        } else {
                            try {
                                val adapter = BluetoothAdapter.getDefaultAdapter()
                                result.success(adapter?.bondedDevices?.map { mapOf("name" to (it.name ?: it.address), "address" to it.address) }?.sortedBy { it["name"] as String } ?: emptyList<Map<String, String>>())
                            } catch (error: SecurityException) {
                                result.error("permission_required", error.message, null)
                            }
                        }
                    }
                    "connectBluetooth" -> {
                        val address = call.argument<String>("address")
                        val code = call.argument<String>("code") ?: "482731"
                        if (address == null) { result.error("invalid_device", "Select a paired PC.", null); return@setMethodCallHandler }
                        val generation = bluetoothGeneration.incrementAndGet()
                        bluetoothExecutor.execute {
                            try {
                                if (generation != bluetoothGeneration.get()) {
                                    mainHandler.post { result.error("connection_cancelled", "Bluetooth connection was cancelled.", null) }
                                    return@execute
                                }
                                closeBluetoothSockets()
                                val device = BluetoothAdapter.getDefaultAdapter()?.getRemoteDevice(address)
                                    ?: throw IllegalStateException("Bluetooth is unavailable")
                                val socket = device.createRfcommSocketToServiceRecord(sppUuid)
                                pendingBluetoothSocket = socket
                                socket.connect()
                                if (generation != bluetoothGeneration.get()) {
                                    socket.close()
                                    mainHandler.post { result.error("connection_cancelled", "Bluetooth connection was cancelled.", null) }
                                    return@execute
                                }
                                socket.outputStream.write(("$code\n").toByteArray(Charsets.US_ASCII))
                                socket.outputStream.flush()
                                bluetoothSocket = socket
                                pendingBluetoothSocket = null
                                mainHandler.post { result.success(null) }
                                Thread {
                                    try {
                                        val buffer = ByteArray(8192)
                                        while (bluetoothSocket === socket) {
                                            val count = socket.inputStream.read(buffer)
                                            if (count < 0) break
                                            val chunk = buffer.copyOf(count)
                                            mainHandler.post { bluetoothSink?.success(chunk) }
                                        }
                                    } catch (_: Exception) { }
                                    if (bluetoothSocket === socket && generation == bluetoothGeneration.get()) {
                                        bluetoothSocket = null
                                        try { socket.close() } catch (_: Exception) { }
                                        mainHandler.post { bluetoothSink?.error("disconnected", "Bluetooth connection ended", null) }
                                    }
                                }.start()
                            } catch (error: Exception) {
                                closeBluetoothSockets()
                                val code = if (generation == bluetoothGeneration.get()) "bluetooth_connect_failed" else "connection_cancelled"
                                mainHandler.post { result.error(code, error.message, null) }
                            }
                        }
                    }
                    "sendBluetooth" -> {
                        val packet = call.arguments as? ByteArray
                        bluetoothExecutor.execute {
                            try {
                                bluetoothSocket?.outputStream?.write(packet ?: byteArrayOf())
                                bluetoothSocket?.outputStream?.flush()
                            } catch (_: Exception) { }
                        }
                        result.success(null)
                    }
                    "disconnectBluetooth" -> { bluetoothGeneration.incrementAndGet(); closeBluetoothSockets(); result.success(null) }
                    "setAll" -> {
                        val values = call.arguments as? Map<*, *>
                        prefs.edit().putString("host", values?.get("host") as? String ?: "")
                            .putString("code", values?.get("code") as? String ?: "482731")
                            .putString("transport", values?.get("transport") as? String ?: "wifi")
                            .apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "intellivision_controller/bluetooth_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { bluetoothSink = events }
                override fun onCancel(arguments: Any?) { bluetoothSink = null }
            })
    }

    private fun disconnectBluetooth() {
        bluetoothGeneration.incrementAndGet()
        closeBluetoothSockets()
    }

    private fun closeBluetoothSockets() {
        try { pendingBluetoothSocket?.close() } catch (_: Exception) { }
        try { bluetoothSocket?.close() } catch (_: Exception) { }
        pendingBluetoothSocket = null
        bluetoothSocket = null
    }

    override fun onDestroy() {
        disconnectBluetooth()
        bluetoothExecutor.shutdownNow()
        super.onDestroy()
    }
}
