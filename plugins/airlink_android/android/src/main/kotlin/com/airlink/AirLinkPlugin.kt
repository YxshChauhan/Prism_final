package com.airlink

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.airlink.wifiaware.WifiAwareManager
import com.airlink.airlink_4.BleAdvertiser

/**
 * AirLink plugin entry point
 * TODO: Implement method channel interface for Flutter communication
 */
class AirLinkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var wifiAwareManager: WifiAwareManager
    private lateinit var bleAdvertiser: BleAdvertiser

    companion object {
        private const val CHANNEL_NAME = "com.airlink/airlink"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        wifiAwareManager = WifiAwareManager(context)
        bleAdvertiser = BleAdvertiser(context, null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isWifiAwareAvailable" -> {
                result.success(wifiAwareManager.isAvailable())
            }
            "startWifiAwareDiscovery" -> {
                wifiAwareManager.startSession()
                result.success(null)
            }
            "stopWifiAwareDiscovery" -> {
                wifiAwareManager.stopSession()
                result.success(null)
            }
            "isBleAvailable" -> {
                result.success(bleAdvertiser.isAvailable())
            }
            "startBleDiscovery" -> {
                bleAdvertiser.startScanning()
                result.success(null)
            }
            "stopBleDiscovery" -> {
                bleAdvertiser.stopScanning()
                result.success(null)
            }
            "connectToDevice" -> {
                val deviceId = call.argument<String>("deviceId")
                // TODO: Implement device connection
                result.success(null)
            }
            "disconnectFromDevice" -> {
                bleAdvertiser.disconnectFromDevice()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        wifiAwareManager.stopSession()
        bleAdvertiser.stopScanning()
    }
}
