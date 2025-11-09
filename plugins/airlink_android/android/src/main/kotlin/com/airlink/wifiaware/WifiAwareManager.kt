package com.airlink.wifiaware

import android.content.Context
import android.net.wifi.aware.WifiAwareManager
import android.net.wifi.aware.WifiAwareSession
import android.net.wifi.aware.AttachCallback
import android.net.wifi.aware.DiscoverySessionCallback
import android.net.wifi.aware.PublishDiscoverySession
import android.net.wifi.aware.SubscribeDiscoverySession
import android.net.wifi.aware.PublishConfig
import android.net.wifi.aware.SubscribeConfig
import android.net.wifi.aware.DiscoverySession
import android.net.wifi.aware.PeerHandle
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Wi-Fi Aware manager for device discovery
 * Implements publish/subscribe with service discovery and peer connection
 */
class WifiAwareManager(
    private val context: Context,
    private val eventSink: EventChannel.EventSink?
) {
    private val wifiAwareManager = context.getSystemService(Context.WIFI_AWARE_SERVICE) as WifiAwareManager
    private var wifiAwareSession: WifiAwareSession? = null
    private var publishSession: PublishDiscoverySession? = null
    private var subscribeSession: SubscribeDiscoverySession? = null
    private var isPublishing = false
    private var isSubscribing = false

    companion object {
        private const val TAG = "WifiAwareManager"
        private const val SERVICE_NAME = "AirLinkService"
        private const val SERVICE_TYPE = "_airlink._tcp"
    }

    /**
     * Check if Wi-Fi Aware is available
     */
    fun isAvailable(): Boolean {
        return wifiAwareManager.isAvailable
    }

    /**
     * Start Wi-Fi Aware session
     */
    fun startSession() {
        if (!isAvailable()) {
            Log.w(TAG, "Wi-Fi Aware is not available")
            return
        }

        wifiAwareManager.attach(attachCallback, null)
    }

    /**
     * Stop Wi-Fi Aware session
     */
    fun stopSession() {
        publishSession?.close()
        subscribeSession?.close()
        wifiAwareSession?.close()
        isPublishing = false
        isSubscribing = false
    }

    /**
     * Start publishing service
     */
    fun startPublishing(metadata: Map<String, Any>) {
        if (wifiAwareSession == null) {
            Log.w(TAG, "Wi-Fi Aware session not attached")
            return
        }

        if (isPublishing) {
            Log.w(TAG, "Already publishing")
            return
        }

        val publishConfig = PublishConfig.Builder()
            .setServiceName(SERVICE_NAME)
            .setServiceSpecificInfo(createServiceInfo(metadata))
            .build()

        wifiAwareSession?.publish(publishConfig, discoveryCallback, null)
        isPublishing = true
        Log.d(TAG, "Started Wi-Fi Aware publishing")
    }

    /**
     * Start subscribing to services
     */
    fun startSubscribing() {
        if (wifiAwareSession == null) {
            Log.w(TAG, "Wi-Fi Aware session not attached")
            return
        }

        if (isSubscribing) {
            Log.w(TAG, "Already subscribing")
            return
        }

        val subscribeConfig = SubscribeConfig.Builder()
            .setServiceName(SERVICE_NAME)
            .build()

        wifiAwareSession?.subscribe(subscribeConfig, discoveryCallback, null)
        isSubscribing = true
        Log.d(TAG, "Started Wi-Fi Aware subscribing")
    }

    /**
     * Create service info from metadata
     */
    private fun createServiceInfo(metadata: Map<String, Any>): ByteArray {
        val deviceName = metadata["deviceName"] as? String ?: "Unknown Device"
        val deviceType = metadata["deviceType"] as? String ?: "unknown"
        return "$deviceName|$deviceType".toByteArray()
    }

    /**
     * Parse service info from discovered device
     */
    private fun parseServiceInfo(serviceInfo: ByteArray): Map<String, String> {
        val info = String(serviceInfo)
        val parts = info.split("|")
        return mapOf(
            "deviceName" to (parts.getOrNull(0) ?: "Unknown Device"),
            "deviceType" to (parts.getOrNull(1) ?: "unknown")
        )
    }

    private val attachCallback = object : AttachCallback() {
        override fun onAttached(session: WifiAwareSession) {
            Log.d(TAG, "Wi-Fi Aware session attached")
            wifiAwareSession = session
        }

        override fun onAttachFailed() {
            Log.e(TAG, "Failed to attach to Wi-Fi Aware session")
        }
    }

    private val discoveryCallback = object : DiscoverySessionCallback() {
        override fun onPublishStarted(session: PublishDiscoverySession) {
            Log.d(TAG, "Publish session started")
            publishSession = session
        }

        override fun onSubscribeStarted(session: SubscribeDiscoverySession) {
            Log.d(TAG, "Subscribe session started")
            subscribeSession = session
        }

        override fun onServiceDiscovered(peerHandle: PeerHandle, serviceSpecificInfo: ByteArray, matchFilter: List<ByteArray>) {
            Log.d(TAG, "Service discovered via Wi-Fi Aware")
            
            val deviceInfo = parseServiceInfo(serviceSpecificInfo)
            val deviceId = "wifi_aware_${peerHandle.hashCode()}"
            
            // Emit discovery event
            eventSink?.success(mapOf(
                "type" to "discoveryUpdate",
                "data" to mapOf(
                    "deviceId" to deviceId,
                    "deviceName" to deviceInfo["deviceName"],
                    "deviceType" to deviceInfo["deviceType"],
                    "discoveryMethod" to "wifi_aware",
                    "metadata" to mapOf(
                        "deviceType" to deviceInfo["deviceType"],
                        "discoveryMethod" to "wifi_aware"
                    ),
                    "timestamp" to System.currentTimeMillis()
                )
            ))
        }

        override fun onServiceDiscoveredWithinRange(peerHandle: PeerHandle, serviceSpecificInfo: ByteArray, matchFilter: List<ByteArray>, distanceMm: Int) {
            Log.d(TAG, "Service discovered within range: ${distanceMm}mm")
            
            val deviceInfo = parseServiceInfo(serviceSpecificInfo)
            val deviceId = "wifi_aware_${peerHandle.hashCode()}"
            
            // Calculate approximate RSSI from distance
            val rssi = when {
                distanceMm < 1000 -> -30  // Very close
                distanceMm < 3000 -> -50  // Close
                distanceMm < 10000 -> -70 // Medium
                else -> -90               // Far
            }
            
            // Emit discovery event with distance info
            eventSink?.success(mapOf(
                "type" to "discoveryUpdate",
                "data" to mapOf(
                    "deviceId" to deviceId,
                    "deviceName" to deviceInfo["deviceName"],
                    "deviceType" to deviceInfo["deviceType"],
                    "rssi" to rssi,
                    "discoveryMethod" to "wifi_aware",
                    "metadata" to mapOf(
                        "deviceType" to deviceInfo["deviceType"],
                        "discoveryMethod" to "wifi_aware",
                        "distanceMm" to distanceMm
                    ),
                    "timestamp" to System.currentTimeMillis()
                )
            ))
        }

        override fun onSessionConfigUpdated() {
            Log.d(TAG, "Session config updated")
        }

        override fun onSessionConfigFailed() {
            Log.e(TAG, "Session config failed")
        }

        override fun onSessionTerminated() {
            Log.d(TAG, "Session terminated")
            isPublishing = false
            isSubscribing = false
        }
    }
}
