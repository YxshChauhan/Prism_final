package com.airlink.airlink_4

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * AirLink Plugin - Main entry point for Android platform features
 * 
 * Provides:
 * - Wi-Fi Aware device discovery and data transfer
 * - BLE advertising and scanning for non-Aware devices
 * - Foreground service for background transfers
 * - Real-time progress and event updates
 */
class AirLinkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    
    companion object {
        private const val TAG = "AirLinkPlugin"
        private const val METHOD_CHANNEL = "airlink/core"
        private const val EVENT_CHANNEL = "airlink/events"
    }
    
    // Plugin components
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var wifiAwareDataChannel: EventChannel
    
    // Platform features - initialized lazily when event sink is available
    private var wifiAwareManager: WifiAwareManagerWrapper? = null
    private var bleAdvertiser: BleAdvertiser? = null
    
    // Event sink for streaming updates
    private var eventSink: EventChannel.EventSink? = null
    private var wifiAwareDataSink: EventChannel.EventSink? = null
    private var controlReceiver: android.content.BroadcastReceiver? = null
    
    // Coroutine scope
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // Audit logger instance
    private lateinit var auditLogger: AuditLogger
    
    // Advanced features handler
    private lateinit var advancedFeaturesHandler: AdvancedFeaturesHandler

    // Active connections tracking
    private val activeConnections = mutableMapOf<String, ConnectionInfo>()
    
    // Transfer state tracking
    private val activeTransfers = mutableMapOf<String, TransferState>()
    private val transferProgress = mutableMapOf<String, TransferProgress>()
    
    // Transfer to transport mapping for per-transport audit metrics
    private val transferToTransport = mutableMapOf<String, String>() // transferId -> "wifi_aware" | "ble"
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        
        // Initialize audit logger
        auditLogger = AuditLogger(context)
        
        // Initialize advanced features handler
        advancedFeaturesHandler = AdvancedFeaturesHandler(context)
        
        // Initialize method channel
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        
        // Initialize event channel
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
        // Initialize Wi-Fi Aware data channel
        wifiAwareDataChannel = EventChannel(binding.binaryMessenger, "airlink/wifi_aware_data")
        wifiAwareDataChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                wifiAwareDataSink = events
                Log.d(TAG, "Wi-Fi Aware data channel listener attached")
            }
            override fun onCancel(arguments: Any?) {
                wifiAwareDataSink = null
                Log.d(TAG, "Wi-Fi Aware data channel listener detached")
            }
        })
        
        Log.i(TAG, "AirLink Plugin attached to engine")

        // Register BroadcastReceiver for foreground service control
        registerControlReceiver()
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        wifiAwareDataChannel.setStreamHandler(null)
        
        // Unregister receiver and clean up resources
        unregisterControlReceiver()
        cleanup()
        
        scope.cancel()
        
        Log.i(TAG, "AirLink Plugin detached from engine")
    }

    private fun registerControlReceiver() {
        if (controlReceiver != null) return
        controlReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                if (intent.action == "PLUGIN_CONTROL") {
                    val action = intent.getStringExtra("action") ?: return
                    val transferId = intent.getStringExtra("transferId") ?: return
                    scope.launch {
                        when (action) {
                            "pause" -> {
                                try { pauseTransfer(transferId) } catch (_: Exception) {}
                            }
                            "cancel" -> {
                                try { cancelTransfer(transferId) } catch (_: Exception) {}
                            }
                            "resume" -> {
                                try { resumeTransfer(transferId) } catch (_: Exception) {}
                            }
                        }
                    }
                }
            }
        }
        val filter = android.content.IntentFilter("PLUGIN_CONTROL")
        context.registerReceiver(controlReceiver, filter)
        Log.i(TAG, "Control BroadcastReceiver registered")
    }

    private fun unregisterControlReceiver() {
        try {
            if (controlReceiver != null) {
                context.unregisterReceiver(controlReceiver)
                controlReceiver = null
                Log.i(TAG, "Control BroadcastReceiver unregistered")
            }
        } catch (_: Exception) {}
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Handle namespaced method calls by splitting on '.'
        val methodParts = call.method.split('.')
        val service = if (methodParts.size > 1) methodParts[0] else null
        val method = if (methodParts.size > 1) methodParts[1] else call.method
        
        Log.d(TAG, "Method call: ${call.method} -> service: $service, method: $method")
        
        // Route based on service if provided
        when (service) {
            "discovery" -> handleDiscoveryMethod(method, call, result)
            "transfer" -> handleTransferMethod(method, call, result)
            "media" -> handleMediaMethod(method, call, result)
            "file" -> handleFileMethod(method, call, result)
            null -> {
                // Legacy routing for non-namespaced calls
                when (method) {
                    // Core Discovery & Transfer
                    "startDiscovery" -> handleStartDiscovery(result)
                    "stopDiscovery" -> handleStopDiscovery(result)
                    "startBleDiscovery" -> handleStartBleDiscovery(result)
                    "stopBleDiscovery" -> handleStopBleDiscovery(result)
                    "startWifiAwareDiscovery" -> handleStartWifiAwareDiscovery(result)
                    "stopWifiAwareDiscovery" -> handleStopWifiAwareDiscovery(result)
                    "startAdvertising" -> handleStartAdvertising(call, result)
                    "stopAdvertising" -> handleStopAdvertising(result)
                    "publishService" -> handlePublishService(call, result)
                    "subscribeService" -> handleSubscribeService(result)
                    "connectToPeer" -> handleConnectToPeer(call, result)
                    "createDatapath" -> handleCreateDatapath(call, result)
                    "closeDatapath" -> handleCloseDatapath(result)
                    "isWifiAwareSupported" -> handleIsWifiAwareSupported(result)
                    "isBleSupported" -> handleIsBleSupported(result)
                    
                    // Transfer Operations
                    "startTransfer" -> handleStartTransfer(call, result)
                    "pauseTransfer" -> handlePauseTransfer(call, result)
                    "resumeTransfer" -> handleResumeTransfer(call, result)
                    "cancelTransfer" -> handleCancelTransfer(call, result)
                    "getTransferProgress" -> handleGetTransferProgress(call, result)
                    
                    // BLE Transfer Methods
                    "startBleFileTransfer" -> handleStartBleFileTransfer(call, result)
                    "startReceivingBleFile" -> handleStartReceivingBleFile(call, result)
                    "getBleTransferProgress" -> handleGetBleTransferProgress(call, result)
                    "cancelBleFileTransfer" -> handleCancelBleFileTransfer(call, result)
                    "setBleEncryptionKey" -> handleSetBleEncryptionKey(call, result)
                    
                    // Wi-Fi Aware Transfer Methods
                    "sendWifiAwareData" -> handleSendWifiAwareData(call, result)
                    "startWifiAwareReceive" -> handleStartWifiAwareReceive(call, result)
                    "setEncryptionKey" -> handleSetEncryptionKey(call, result)
                    
                    // Service Methods
                    "startTransferService" -> handleStartTransferService(call, result)
                    "stopTransferService" -> handleStopTransferService(result)
                    
                    // Audit Mode Control
                    "enableAuditMode" -> handleEnableAuditMode(result)
                    "disableAuditMode" -> handleDisableAuditMode(result)
                    "getAuditMetrics" -> handleGetAuditMetrics(call, result)
                    "exportAuditLogs" -> handleExportAuditLogs(call, result)
                    
                    // Audit Evidence Collection
                    "getStorageStatus" -> handleGetStorageStatus(result)
                    "getCapabilities" -> handleGetCapabilities(result)
                    "captureScreenshot" -> handleCaptureScreenshot(call, result)
                    "exportDeviceLogs" -> handleExportDeviceLogs(call, result)
                    "listTransferredFiles" -> handleListTransferredFiles(result)
                    
                    // Advanced Features - APK Sharing
                    "getInstalledApps" -> advancedFeaturesHandler.getInstalledApps(result)
                    "extractApk" -> advancedFeaturesHandler.extractApk(call, result)
                    "installApk" -> advancedFeaturesHandler.installApk(call, result)
                    
                    // Advanced Features - File Manager
                    "getFileMetadata" -> advancedFeaturesHandler.getFileMetadata(call, result)
                    "bulkFileOperations" -> advancedFeaturesHandler.bulkFileOperations(call, result)
                    
                    // Advanced Features - Media Player
                    "getVideoInfo" -> advancedFeaturesHandler.getVideoInfo(call, result)
                    "extractAudioTrack" -> advancedFeaturesHandler.extractAudioTrack(call, result)
                    
                    // Advanced Features - Phone Replication
                    "exportContacts" -> advancedFeaturesHandler.exportContacts(call, result)
                    "exportCallLogs" -> advancedFeaturesHandler.exportCallLogs(call, result)
                    
                    // Advanced Features - Video Compression
                    "compressVideo" -> advancedFeaturesHandler.compressVideo(call, result)
                    "getCompressionProgress" -> advancedFeaturesHandler.getCompressionProgress(call, result)
                    "cancelCompression" -> advancedFeaturesHandler.cancelCompression(call, result)
                    
                    else -> result.notImplemented()
                }
            }
        }
    }

    // ==================== Event Channel ====================
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event channel listener attached")
        
        // Initialize platform managers now that event sink is available
        initializePlatformManagers()
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event channel listener detached")
    }
    
    // ==================== Method Handlers ====================
    
    private fun handleStartDiscovery(result: MethodChannel.Result) {
        scope.launch {
            try {
                val started = startDiscovery()
                result.success(started)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start discovery", e)
                result.error("DISCOVERY_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleStopDiscovery(result: MethodChannel.Result) {
        scope.launch {
            try {
                stopDiscovery()
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop discovery", e)
                result.error("DISCOVERY_ERROR", e.message, null)
            }
        }
    }

    private fun handleStartBleDiscovery(result: MethodChannel.Result) {
        scope.launch {
            try {
                val started = withContext(Dispatchers.IO) { bleAdvertiser?.startScanning() ?: false }
                result.success(started)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start BLE discovery", e)
                result.error("DISCOVERY_ERROR", e.message, null)
            }
        }
    }

    private fun handleStopBleDiscovery(result: MethodChannel.Result) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) { bleAdvertiser?.stopScanning() }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop BLE discovery", e)
                result.error("DISCOVERY_ERROR", e.message, null)
            }
        }
    }

    private fun handleStartWifiAwareDiscovery(result: MethodChannel.Result) {
        scope.launch {
            try {
                val started = withContext(Dispatchers.IO) { wifiAwareManager?.startDiscovery() ?: false }
                result.success(started)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Wi‑Fi Aware discovery", e)
                result.error("DISCOVERY_ERROR", e.message, null)
            }
        }
    }

    private fun handleStopWifiAwareDiscovery(result: MethodChannel.Result) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) { wifiAwareManager?.stopDiscovery() }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop Wi‑Fi Aware discovery", e)
                result.error("DISCOVERY_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleStartAdvertising(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val metadata = call.argument<Map<String, Any>>("metadata") ?: emptyMap()
                val success = startAdvertisingWithMetadata(metadata)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start advertising", e)
                result.error("ADVERTISING_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleStopAdvertising(result: MethodChannel.Result) {
        scope.launch {
            try {
                stopAdvertising()
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop advertising", e)
                result.error("ADVERTISING_ERROR", e.message, null)
            }
        }
    }
    
    private fun handlePublishService(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val metadata = call.argument<Map<String, Any>>("metadata") ?: emptyMap()
                publishService(metadata)
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to publish service", e)
                result.error("PUBLISH_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleSubscribeService(result: MethodChannel.Result) {
        scope.launch {
            try {
                subscribeService()
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to subscribe service", e)
                result.error("SUBSCRIBE_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleConnectToPeer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val peerId = call.argument<String>("peerId")
                    ?: throw IllegalArgumentException("peerId is required")
                
                val connectionToken = connectToPeer(peerId)
                result.success(connectionToken)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect to peer", e)
                result.error("CONNECTION_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleCreateDatapath(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val peerId = call.argument<String>("peerId")
                    ?: throw IllegalArgumentException("peerId is required")
                val datapathInfo = createDatapathWithPeer(peerId)
                // Always return a Map matching Dart expectations
                result.success(datapathInfo)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create datapath", e)
                result.error("DATAPATH_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleCloseDatapath(result: MethodChannel.Result) {
        scope.launch {
            try {
                closeDatapath()
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to close datapath", e)
                result.error("DATAPATH_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleIsWifiAwareSupported(result: MethodChannel.Result) {
        val supported = wifiAwareManager?.isSupported() ?: false
        result.success(supported)
    }
    
    private fun handleIsBleSupported(result: MethodChannel.Result) {
        val supported = bleAdvertiser?.isSupported() ?: false
        result.success(supported)
    }
    
    // Transfer handlers
    private fun handleStartTransfer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                val filePath = call.argument<String>("filePath")
                    ?: throw IllegalArgumentException("filePath is required")
                val fileSize = call.argument<Long>("fileSize")
                    ?: throw IllegalArgumentException("fileSize is required")
                val targetDeviceId = call.argument<String>("targetDeviceId")
                    ?: throw IllegalArgumentException("targetDeviceId is required")
                val connectionMethod = call.argument<String>("connectionMethod") ?: "wifi_aware"
                
                val success = startFileTransfer(transferId, filePath, fileSize, targetDeviceId, connectionMethod)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start transfer", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handlePauseTransfer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val success = pauseTransfer(transferId)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to pause transfer", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleResumeTransfer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val success = resumeTransfer(transferId)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to resume transfer", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleCancelTransfer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val success = cancelTransfer(transferId)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel transfer", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleGetTransferProgress(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val progress = getTransferProgress(transferId)
                result.success(progress)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get transfer progress", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    // ==================== Service Method Handlers ====================
    
    private fun handleDiscoveryMethod(method: String, call: MethodCall, result: MethodChannel.Result) {
        when (method) {
            "start" -> handleStartDiscovery(result)
            "stop" -> handleStopDiscovery(result)
            "publish" -> handlePublishService(call, result)
            "subscribe" -> handleSubscribeService(result)
            else -> result.notImplemented()
        }
    }
    
    private fun handleTransferMethod(method: String, call: MethodCall, result: MethodChannel.Result) {
        when (method) {
            "start" -> handleStartTransfer(call, result)
            "pause" -> handlePauseTransfer(call, result)
            "resume" -> handleResumeTransfer(call, result)
            "cancel" -> handleCancelTransfer(call, result)
            "progress" -> handleGetTransferProgress(call, result)
            "sendChunk" -> handleSendChunk(call, result)
            "receiveChunk" -> handleReceiveChunk(call, result)
            "getConnectionInfo" -> handleGetConnectionInfo(call, result)
            "closeConnection" -> handleCloseConnection(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun handleSendChunk(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                val chunkData = call.argument<ByteArray>("chunkData")
                    ?: throw IllegalArgumentException("chunkData is required")
                val chunkIndex = call.argument<Int>("chunkIndex")
                    ?: throw IllegalArgumentException("chunkIndex is required")
                val totalChunks = call.argument<Int>("totalChunks")
                    ?: throw IllegalArgumentException("totalChunks is required")
                
                val success = sendChunk(connectionToken, chunkData, chunkIndex, totalChunks)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send chunk", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleReceiveChunk(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                
                val chunkData = receiveChunk(connectionToken)
                result.success(chunkData)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to receive chunk", e)
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleGetConnectionInfo(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                
                val connectionInfo = getConnectionInfo(connectionToken)
                result.success(connectionInfo)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get connection info", e)
                result.error("CONNECTION_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleCloseConnection(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                
                val success = closeConnection(connectionToken)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to close connection", e)
                result.error("CONNECTION_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleMediaMethod(method: String, call: MethodCall, result: MethodChannel.Result) {
        when (method) {
            "getMediaInfo" -> {
                scope.launch {
                    try {
                        val filePath = call.argument<String>("filePath")
                        if (filePath != null) {
                            val mediaInfo = getMediaInfo(filePath)
                            result.success(mediaInfo)
                        } else {
                            result.error("INVALID_ARGUMENT", "filePath is required", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get media info", e)
                        result.error("MEDIA_ERROR", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
    
    private fun handleFileMethod(method: String, call: MethodCall, result: MethodChannel.Result) {
        when (method) {
            "listFiles" -> {
                scope.launch {
                    try {
                        val directory = call.argument<String>("directory") ?: "/"
                        val files = listFiles(directory)
                        result.success(files)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to list files", e)
                        result.error("FILE_ERROR", e.message, null)
                    }
                }
            }
            "getFileInfo" -> {
                scope.launch {
                    try {
                        val filePath = call.argument<String>("filePath")
                        if (filePath != null) {
                            val fileInfo = getFileInfo(filePath)
                            result.success(fileInfo)
                        } else {
                            result.error("INVALID_ARGUMENT", "filePath is required", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get file info", e)
                        result.error("FILE_ERROR", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
    
    // ==================== BLE Transfer Handlers ====================
    
    private fun handleStartBleFileTransfer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                val filePath = call.argument<String>("filePath")
                    ?: throw IllegalArgumentException("filePath is required")
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val success = bleAdvertiser?.startFileTransfer(connectionToken, filePath, transferId) ?: false
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start BLE file transfer", e)
                result.error("BLE_TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleStartReceivingBleFile(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                val savePath = call.argument<String>("savePath")
                    ?: throw IllegalArgumentException("savePath is required")
                
                val success = bleAdvertiser?.startReceivingFile(connectionToken, transferId, savePath) ?: false
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start receiving BLE file", e)
                result.error("BLE_TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleGetBleTransferProgress(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val progress = bleAdvertiser?.getTransferProgress(transferId) ?: emptyMap<String, Any>()
                result.success(progress)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get BLE transfer progress", e)
                result.error("BLE_TRANSFER_ERROR", e.message, null)
            }
        }
    }

    private fun handleSetBleEncryptionKey(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val key = call.argument<ByteArray>("key")
                    ?: throw IllegalArgumentException("key is required")
                if (isWeakKey(key)) {
                    Log.w(TAG, "Rejected weak BLE key (uniform or zero bytes)")
                    result.error("BLE_ENCRYPTION_ERROR", "Weak BLE encryption key", null)
                    return@launch
                }
                bleAdvertiser?.setEncryptionKey(key)
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set BLE encryption key", e)
                result.error("BLE_ENCRYPTION_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleCancelBleFileTransfer(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val success = bleAdvertiser?.cancelFileTransfer(transferId) ?: false
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel BLE file transfer", e)
                result.error("BLE_TRANSFER_ERROR", e.message, null)
            }
        }
    }
    
    // ==================== Wi-Fi Aware Transfer Handlers ====================
    
    private fun handleSendWifiAwareData(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                val data = call.argument<ByteArray>("data")
                    ?: throw IllegalArgumentException("data is required")
                
                val success = wifiAwareManager?.sendData(connectionToken, data) ?: false
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send Wi-Fi Aware data", e)
                result.error("WIFI_AWARE_ERROR", e.message, null)
            }
        }
    }

    private fun handleSetEncryptionKey(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                val key = call.argument<ByteArray>("key")
                    ?: throw IllegalArgumentException("key is required")
                if (isWeakKey(key)) {
                    Log.w(TAG, "Rejected weak Wi-Fi Aware key (uniform or zero bytes)")
                    result.error("ENCRYPTION_ERROR", "Weak encryption key", null)
                    return@launch
                }
                wifiAwareManager?.setEncryptionKey(connectionToken, key)
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set encryption key", e)
                result.error("ENCRYPTION_ERROR", e.message, null)
            }
        }
    }

    private fun isWeakKey(key: ByteArray): Boolean {
        if (key.isEmpty()) return true
        var allZero = true
        var allSame = true
        val first = key[0]
        for (i in 0 until key.size) {
            if (key[i].toInt() != 0) allZero = false
            if (key[i] != first) allSame = false
            if (!allZero && !allSame) break
        }
        return allZero || allSame
    }
    
    private fun handleStartWifiAwareReceive(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val connectionToken = call.argument<String>("connectionToken")
                    ?: throw IllegalArgumentException("connectionToken is required")
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                val savePath = call.argument<String>("savePath")
                    ?: throw IllegalArgumentException("savePath is required")
                startWifiAwareReceiveToFile(connectionToken, transferId, savePath)
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Wi-Fi Aware receive", e)
                result.error("WIFI_AWARE_ERROR", e.message, null)
            }
        }
    }
    
    // ==================== Service Handlers ====================
    
    private fun handleStartTransferService(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val transferId = call.argument<String>("transferId")
                    ?: throw IllegalArgumentException("transferId is required")
                
                val success = startTransferService(transferId)
                result.success(success)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start transfer service", e)
                result.error("SERVICE_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleStopTransferService(result: MethodChannel.Result) {
        scope.launch {
            try {
                stopTransferService()
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop transfer service", e)
                result.error("SERVICE_ERROR", e.message, null)
            }
        }
    }
    
    // ==================== Core Implementation ====================
    
    private fun initializePlatformManagers() {
        // Initialize Wi-Fi Aware manager with event sink
        wifiAwareManager = WifiAwareManagerWrapper(context, eventSink) { token, bytes ->
            try { emitWifiAwareData(token, bytes) } catch (_: Exception) {}
        }
        
        // Initialize BLE advertiser with event sink  
        bleAdvertiser = BleAdvertiser(context, eventSink)
        
        Log.i(TAG, "Platform managers initialized with event sink")
    }
    
    private suspend fun startDiscovery(): Boolean {
        return withContext(Dispatchers.IO) {
            var started = false
            
            // Try Wi-Fi Aware first
            if (wifiAwareManager?.isSupported() == true) {
                started = wifiAwareManager?.startDiscovery() ?: false
                if (started) {
                    Log.i(TAG, "Wi-Fi Aware discovery started")
                }
            }
            
            // Fallback to BLE if Wi-Fi Aware not available
            if (!started && bleAdvertiser?.isSupported() == true) {
                started = bleAdvertiser?.startScanning() ?: false
                if (started) {
                    Log.i(TAG, "BLE scanning started")
                }
            }
            
            if (!started) {
                Log.w(TAG, "No discovery method available")
            }
            
            started
        }
    }
    
    private suspend fun stopDiscovery() {
        withContext(Dispatchers.IO) {
            wifiAwareManager?.stopDiscovery()
            bleAdvertiser?.stopScanning()
            Log.i(TAG, "Discovery stopped")
        }
    }
    
    private suspend fun startAdvertisingWithMetadata(metadata: Map<String, Any>): Boolean {
        return withContext(Dispatchers.IO) {
            var started = false
            
            // Try Wi-Fi Aware first
            if (wifiAwareManager?.isSupported() == true) {
                wifiAwareManager?.publishService(metadata)
                started = true
                Log.i(TAG, "Wi-Fi Aware advertising started")
            }
            
            // Also start BLE advertising if supported
            if (bleAdvertiser?.isSupported() == true) {
                val bleStarted = bleAdvertiser?.startAdvertising() ?: false
                if (bleStarted) {
                    started = true
                    Log.i(TAG, "BLE advertising started")
                }
            }
            
            if (!started) {
                Log.w(TAG, "No advertising method available")
            }
            
            started
        }
    }
    
    private suspend fun stopAdvertising() {
        withContext(Dispatchers.IO) {
            wifiAwareManager?.stopDiscovery() // This stops both discovery and advertising
            bleAdvertiser?.stopAdvertising()
            Log.i(TAG, "Advertising stopped")
        }
    }
    
    private suspend fun publishService(metadata: Map<String, Any>) {
        withContext(Dispatchers.IO) {
            wifiAwareManager?.publishService(metadata)
            Log.i(TAG, "Service published with metadata: $metadata")
        }
    }
    
    private suspend fun subscribeService() {
        withContext(Dispatchers.IO) {
            wifiAwareManager?.subscribeService()
            Log.i(TAG, "Service subscription started")
        }
    }
    
    private suspend fun connectToPeer(peerId: String): String {
        return withContext(Dispatchers.IO) {
            val connectionToken = wifiAwareManager?.createDatapath(peerId) ?: "conn_${System.currentTimeMillis()}"
            activeConnections[connectionToken] = ConnectionInfo(
                peerId = peerId,
                status = "connecting",
                timestamp = System.currentTimeMillis()
            )
            Log.i(TAG, "Connected to peer: $peerId with token: $connectionToken")
            connectionToken
        }
    }
    
    private suspend fun createDatapathWithPeer(peerId: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val token = wifiAwareManager?.createDatapath(peerId) ?: "conn_${System.currentTimeMillis()}"
            mapOf(
                "connectionToken" to token,
                "peerId" to peerId,
                "status" to "connecting",
                "connectionMethod" to "wifi_aware"
            )
        }
    }
    
    private suspend fun closeDatapath() {
        withContext(Dispatchers.IO) {
            activeConnections.clear()
            Log.i(TAG, "Datapath closed")
        }
    }
    
    private suspend fun startFileTransfer(transferId: String, filePath: String, fileSize: Long, targetDeviceId: String, connectionMethod: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                // Find connection for target device
                val connection = activeConnections.values.find { it.peerId == targetDeviceId }
                if (connection == null) {
                    Log.e(TAG, "No connection found for device: $targetDeviceId")
                    return@withContext false
                }
                
                val connectionToken = activeConnections.entries.find { it.value.peerId == targetDeviceId }?.key
                if (connectionToken == null) {
                    Log.e(TAG, "No connection token found for device: $targetDeviceId")
                    return@withContext false
                }
                
                // Create transfer state
                val transferState = TransferState(
                    transferId = transferId,
                    filePath = filePath,
                    fileSize = fileSize,
                    targetDeviceId = targetDeviceId,
                    connectionToken = connectionToken,
                    connectionMethod = connectionMethod,
                    status = "starting",
                    startTime = System.currentTimeMillis()
                )
                
                activeTransfers[transferId] = transferState
                transferProgress[transferId] = TransferProgress(
                    transferId = transferId,
                    bytesTransferred = 0,
                    totalBytes = fileSize,
                    status = "starting"
                )
                
                // Start foreground service for long transfers
                if (fileSize > 10 * 1024 * 1024) { // 10MB threshold
                    startTransferService(transferId)
                }
                
                // Track transport method for per-transport audit metrics
                transferToTransport[transferId] = connectionMethod
                
                // Route to appropriate transport
                val success = when (connectionMethod) {
                    "wifi_aware" -> {
                        // Start Wi-Fi Aware file transfer with actual file streaming
                        startWifiAwareFileTransfer(connectionToken, filePath, transferId, fileSize)
                    }
                    "ble" -> {
                        bleAdvertiser?.startFileTransfer(connectionToken, filePath, transferId) ?: false
                    }
                    else -> {
                        Log.e(TAG, "Unsupported connection method: $connectionMethod")
                        false
                    }
                }
                
                if (success) {
                    activeTransfers[transferId] = transferState.copy(status = "transferring")
                    transferProgress[transferId]?.let { progress ->
                        transferProgress[transferId] = progress.copy(status = "transferring")
                    }
                    
                    sendTransferEvent("transferStarted", mapOf<String, Any>(
                        "transferId" to transferId,
                        "fileName" to java.io.File(filePath).name,
                        "fileSize" to fileSize,
                        "connectionMethod" to connectionMethod
                    ))
                } else {
                    activeTransfers[transferId] = transferState.copy(status = "failed")
                    transferProgress[transferId]?.let { progress ->
                        transferProgress[transferId] = progress.copy(status = "failed")
                    }
                }
                
                success
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start file transfer: $transferId", e)
                activeTransfers[transferId]?.let { transfer ->
                    activeTransfers[transferId] = transfer.copy(status = "failed")
                }
                transferProgress[transferId]?.let { progress ->
                    transferProgress[transferId] = progress.copy(status = "failed")
                }
                false
            }
        }
    }
    
    private suspend fun pauseTransfer(transferId: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val transfer = activeTransfers[transferId]
                if (transfer != null) {
                    activeTransfers[transferId] = transfer.copy(status = "paused")
                    transferProgress[transferId]?.let { progress ->
                        transferProgress[transferId] = progress.copy(status = "paused")
                    }
                    
                    // Pause transfer in native layer
                    when (transfer.connectionMethod) {
                        "wifi_aware" -> {
                            // Wi-Fi Aware pause logic
                            Log.i(TAG, "Pausing Wi-Fi Aware transfer: $transferId")
                        }
                        "ble" -> {
                            // BLE pause logic
                            Log.i(TAG, "Pausing BLE transfer: $transferId")
                        }
                    }
                    
                    sendTransferEvent("transferPaused", mapOf<String, Any>(
                        "transferId" to transferId
                    ))
                    
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to pause transfer: $transferId", e)
                false
            }
        }
    }
    
    private suspend fun resumeTransfer(transferId: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val transfer = activeTransfers[transferId]
                if (transfer != null && transfer.status == "paused") {
                    activeTransfers[transferId] = transfer.copy(status = "transferring")
                    transferProgress[transferId]?.let { progress ->
                        transferProgress[transferId] = progress.copy(status = "transferring")
                    }
                    
                    // Resume transfer in native layer
                    when (transfer.connectionMethod) {
                        "wifi_aware" -> {
                            // Wi-Fi Aware resume logic
                            Log.i(TAG, "Resuming Wi-Fi Aware transfer: $transferId")
                        }
                        "ble" -> {
                            // BLE resume logic
                            Log.i(TAG, "Resuming BLE transfer: $transferId")
                        }
                    }
                    
                    sendTransferEvent("transferResumed", mapOf<String, Any>(
                        "transferId" to transferId
                    ))
                    
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to resume transfer: $transferId", e)
                false
            }
        }
    }
    
    private suspend fun cancelTransfer(transferId: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val transfer = activeTransfers[transferId]
                if (transfer != null) {
                    // Cancel transfer in native layer
                    when (transfer.connectionMethod) {
                        "wifi_aware" -> {
                            // Wi-Fi Aware cancel logic
                            Log.i(TAG, "Cancelling Wi-Fi Aware transfer: $transferId")
                        }
                        "ble" -> {
                            bleAdvertiser?.cancelFileTransfer(transferId)
                        }
                    }
                    
                    activeTransfers[transferId] = transfer.copy(status = "cancelled")
                    transferProgress[transferId]?.let { progress ->
                        transferProgress[transferId] = progress.copy(status = "cancelled")
                    }
                    
                    sendTransferEvent("transferCancelled", mapOf<String, Any>(
                        "transferId" to transferId
                    ))
                    
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel transfer: $transferId", e)
                false
            }
        }
    }
    
    private suspend fun getTransferProgress(transferId: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val transfer = activeTransfers[transferId]
            val progress = transferProgress[transferId]
            
            if (transfer != null && progress != null) {
                mapOf(
                    "transferId" to transferId,
                    "bytesTransferred" to progress.bytesTransferred,
                    "totalBytes" to progress.totalBytes,
                    "progress" to (progress.bytesTransferred.toFloat() / progress.totalBytes * 100),
                    "status" to progress.status,
                    "speed" to progress.speed,
                    "eta" to progress.eta
                )
            } else {
                mapOf(
                    "transferId" to transferId,
                    "bytesTransferred" to 0,
                    "totalBytes" to 0,
                    "progress" to 0.0,
                    "status" to "not_found",
                    "speed" to 0,
                    "eta" to 0
                )
            }
        }
    }
    
    private suspend fun sendChunk(connectionToken: String, chunkData: ByteArray, chunkIndex: Int, totalChunks: Int): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val connection = activeConnections[connectionToken]
                if (connection != null) {
                    when (connection.connectionMethod) {
                        "wifi_aware" -> {
                            wifiAwareManager?.sendData(connectionToken, chunkData) ?: false
                        }
                        "ble" -> {
                            bleAdvertiser?.sendData(connectionToken, chunkData)
                            true
                        }
                        else -> false
                    }
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send chunk", e)
                false
            }
        }
    }
    
    private suspend fun receiveChunk(connectionToken: String): ByteArray? {
        return withContext(Dispatchers.IO) {
            try {
                val connection = activeConnections[connectionToken]
                if (connection != null) {
                    when (connection.connectionMethod) {
                        "wifi_aware" -> {
                            // Wi-Fi Aware receive logic
                            null // Simplified for now
                        }
                        "ble" -> {
                            // BLE receive logic
                            null // Simplified for now
                        }
                        else -> null
                    }
                } else {
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to receive chunk", e)
                null
            }
        }
    }
    
    private suspend fun getConnectionInfo(connectionToken: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            val connection = activeConnections[connectionToken]
            if (connection != null) {
                mapOf<String, Any>(
                    "connectionToken" to connectionToken,
                    "peerId" to connection.peerId,
                    "status" to connection.status,
                    "connectionMethod" to connection.connectionMethod,
                    "host" to (connection.host ?: ""),
                    "port" to (connection.port ?: 0)
                )
            } else {
                emptyMap<String, Any>()
            }
        }
    }
    
    private suspend fun closeConnection(connectionToken: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val connection = activeConnections[connectionToken]
                if (connection != null) {
                    when (connection.connectionMethod) {
                        "wifi_aware" -> {
                            wifiAwareManager?.closeConnection(connectionToken)
                        }
                        "ble" -> {
                            // BLE close logic
                            Log.i(TAG, "Closing BLE connection: $connectionToken")
                        }
                    }
                    
                    activeConnections.remove(connectionToken)
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to close connection", e)
                false
            }
        }
    }
    
    private suspend fun startTransferService(transferId: String) {
        withContext(Dispatchers.IO) {
            try {
                val intent = Intent(context, TransferForegroundService::class.java).apply {
                    action = TransferForegroundService.ACTION_START
                    putExtra(TransferForegroundService.EXTRA_TRANSFER_ID, transferId)
                    // Best-effort extras; connection token and file info if available
                    val state = activeTransfers[transferId]
                    if (state != null) {
                        putExtra(TransferForegroundService.EXTRA_CONNECTION_TOKEN, state.connectionToken)
                        putExtra(TransferForegroundService.EXTRA_FILE_NAME, java.io.File(state.filePath).name)
                        putExtra(TransferForegroundService.EXTRA_TOTAL_BYTES, state.fileSize)
                    }
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                
                Log.i(TAG, "Transfer foreground service started for: $transferId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start transfer service: $transferId", e)
            }
        }
    }
    
    private suspend fun stopTransferService() {
        withContext(Dispatchers.IO) {
            try {
                val intent = Intent(context, TransferForegroundService::class.java).apply {
                    action = TransferForegroundService.ACTION_STOP
                }
                
                context.startService(intent)
                Log.i(TAG, "Transfer foreground service stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop transfer service", e)
            }
        }
    }
    
    // ==================== Media and File Operations ====================
    
    private suspend fun getMediaInfo(filePath: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            try {
                val file = java.io.File(filePath)
                if (!file.exists()) {
                    throw IllegalArgumentException("File not found: $filePath")
                }
                
                // Basic file info - in a real implementation, you'd use MediaMetadataRetriever
                mapOf(
                    "filePath" to filePath,
                    "fileName" to file.name,
                    "fileSize" to file.length(),
                    "lastModified" to file.lastModified(),
                    "isDirectory" to file.isDirectory,
                    "duration" to 0, // Would be extracted from media file
                    "codec" to "unknown", // Would be extracted from media file
                    "resolution" to "unknown" // Would be extracted from media file
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get media info for: $filePath", e)
                throw e
            }
        }
    }
    
    private suspend fun listFiles(directory: String): List<Map<String, Any>> {
        return withContext(Dispatchers.IO) {
            try {
                val dir = java.io.File(directory)
                if (!dir.exists() || !dir.isDirectory) {
                    throw IllegalArgumentException("Directory not found: $directory")
                }
                
                val files = dir.listFiles() ?: emptyArray()
                files.map { file ->
                    mapOf(
                        "name" to file.name,
                        "path" to file.absolutePath,
                        "size" to file.length(),
                        "isDirectory" to file.isDirectory,
                        "lastModified" to file.lastModified()
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to list files in: $directory", e)
                throw e
            }
        }
    }
    
    private suspend fun getFileInfo(filePath: String): Map<String, Any> {
        return withContext(Dispatchers.IO) {
            try {
                val file = java.io.File(filePath)
                if (!file.exists()) {
                    throw IllegalArgumentException("File not found: $filePath")
                }
                
                mapOf(
                    "name" to file.name,
                    "path" to file.absolutePath,
                    "size" to file.length(),
                    "isDirectory" to file.isDirectory,
                    "isFile" to file.isFile,
                    "lastModified" to file.lastModified(),
                    "canRead" to file.canRead(),
                    "canWrite" to file.canWrite(),
                    "canExecute" to file.canExecute()
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get file info for: $filePath", e)
                throw e
            }
        }
    }
    
    private suspend fun startWifiAwareFileTransfer(connectionToken: String, filePath: String, transferId: String, fileSize: Long): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val file = java.io.File(filePath)
                if (!file.exists()) {
                    Log.e(TAG, "File not found: $filePath")
                    return@withContext false
                }
                
                val inputStream = file.inputStream()
                val buffer = ByteArray(256 * 1024) // 256KB chunks
                var bytesTransferred = 0L
                var chunkIndex = 0
                
                Log.i(TAG, "Starting Wi-Fi Aware file transfer: $filePath (${fileSize} bytes)")
                
                // Send minimal JSON meta first
                try {
                    // Compute checksum
                    var checksumHex = ""
                    try {
                        val digest = java.security.MessageDigest.getInstance("SHA-256")
                        val fis = java.io.FileInputStream(file)
                        val buf = ByteArray(1024 * 1024)
                        var r: Int
                        while (fis.read(buf).also { r = it } > 0) { digest.update(buf, 0, r) }
                        fis.close()
                        checksumHex = digest.digest().joinToString("") { b -> "%02x".format(b) }
                    } catch (_: Exception) {}

                    val meta = org.json.JSONObject(mapOf(
                        "type" to "file_meta",
                        "fileId" to transferId,
                        "name" to file.name,
                        "size" to fileSize,
                        "checksum" to checksumHex
                    )).toString().toByteArray(Charsets.UTF_8)
                    wifiAwareManager?.sendData(connectionToken, meta)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to send file_meta", e)
                }

                while (bytesTransferred < fileSize) {
                    val bytesRead = inputStream.read(buffer)
                    if (bytesRead == -1) break
                    
                    val chunk = buffer.copyOf(bytesRead)
                    // Build binary frame: [type=1][fileIdLen][fileId][offset:8][dataLen:4][data]
                    val fileIdBytes = transferId.toByteArray(Charsets.UTF_8)
                    val frame = java.io.ByteArrayOutputStream(1 + 1 + fileIdBytes.size + 8 + 4 + chunk.size)
                    frame.write(byteArrayOf(1))
                    frame.write(byteArrayOf(fileIdBytes.size.toByte()))
                    frame.write(fileIdBytes)
                    frame.write(java.nio.ByteBuffer.allocate(8).putLong(bytesTransferred).array())
                    frame.write(java.nio.ByteBuffer.allocate(4).putInt(chunk.size).array())
                    frame.write(chunk)
                    val success = wifiAwareManager?.sendData(connectionToken, frame.toByteArray()) ?: false
                    
                    if (!success) {
                        Log.e(TAG, "Failed to send chunk $chunkIndex for transfer $transferId")
                        inputStream.close()
                        return@withContext false
                    }
                    
                    bytesTransferred += bytesRead
                    chunkIndex++
                    
                    // Update progress
                    val progress = (bytesTransferred.toFloat() / fileSize * 100).toInt()
                    transferProgress[transferId]?.let { currentProgress ->
                        transferProgress[transferId] = currentProgress.copy(
                            bytesTransferred = bytesTransferred,
                            status = "transferring"
                        )
                    }
                    
                    // Emit progress event
                    sendTransferEvent("transferProgress", mapOf<String, Any>(
                        "transferId" to transferId,
                        "bytesTransferred" to bytesTransferred,
                        "totalBytes" to fileSize,
                        "progress" to progress,
                        "status" to "transferring"
                    ))
                    // Broadcast progress for foreground service UI
                    try {
                        val intent = Intent(TransferForegroundService.ACTION_UPDATE_PROGRESS)
                        intent.putExtra(TransferForegroundService.EXTRA_TRANSFER_ID, transferId)
                        intent.putExtra(TransferForegroundService.EXTRA_PROGRESS, progress)
                        androidx.localbroadcastmanager.content.LocalBroadcastManager.getInstance(context).sendBroadcast(intent)
                    } catch (_: Exception) {}
                    
                    Log.d(TAG, "Sent chunk $chunkIndex: $bytesRead bytes (${progress}%)")
                }
                
                inputStream.close()
                
                // Send file_end control JSON
                try {
                    val endMsg = org.json.JSONObject(mapOf(
                        "type" to "file_end",
                        "fileId" to transferId
                    )).toString().toByteArray(Charsets.UTF_8)
                    wifiAwareManager?.sendData(connectionToken, endMsg)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to send file_end", e)
                }

                // Mark transfer as completed
                transferProgress[transferId]?.let { currentProgress ->
                    transferProgress[transferId] = currentProgress.copy(
                        bytesTransferred = fileSize,
                        status = "completed"
                    )
                }
                
                sendTransferEvent("transferCompleted", mapOf<String, Any>(
                    "transferId" to transferId,
                    "bytesTransferred" to fileSize,
                    "totalBytes" to fileSize,
                    "progress" to 100,
                    "status" to "completed"
                ))
                try {
                    val intent = Intent(TransferForegroundService.ACTION_UPDATE_PROGRESS)
                    intent.putExtra(TransferForegroundService.EXTRA_TRANSFER_ID, transferId)
                    intent.putExtra(TransferForegroundService.EXTRA_PROGRESS, 100)
                    androidx.localbroadcastmanager.content.LocalBroadcastManager.getInstance(context).sendBroadcast(intent)
                } catch (_: Exception) {}
                
                Log.i(TAG, "Wi-Fi Aware file transfer completed: $transferId")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Wi-Fi Aware file transfer failed: $transferId", e)
                
                // Mark transfer as failed
                transferProgress[transferId]?.let { currentProgress ->
                    transferProgress[transferId] = currentProgress.copy(status = "failed")
                }
                
                sendTransferEvent("transferFailed", mapOf<String, Any>(
                    "transferId" to transferId,
                    "error" to (e.message ?: "Unknown error"),
                    "status" to "failed"
                ))
                
                false
            }
        }
    }

    // Bridge incoming Wi-Fi Aware data to the wifi_aware_data event stream
    private fun startWifiAwareReceiveToFile(connectionToken: String, transferId: String, savePath: String) {
        val outFile = java.io.File(savePath)
        val parent = outFile.parentFile
        if (parent != null && !parent.exists()) try { parent.mkdirs() } catch (_: Exception) {}
        val output = try { java.io.BufferedOutputStream(java.io.FileOutputStream(outFile)) } catch (e: Exception) { Log.e(TAG, "Failed to open output file", e); return }
        var expectedSize: Long = -1
        var checksumHex: String = ""
        var received: Long = 0
        var startedAt = System.currentTimeMillis()
        wifiAwareManager?.receiveData(connectionToken) { bytes ->
            try {
                if (bytes.isNotEmpty() && bytes[0].toInt() == 0x7B) { // JSON control
                    val text = try { String(bytes) } catch (_: Exception) { "" }
                    try {
                        val json = org.json.JSONObject(text)
                        val type = json.optString("type", "")
                        if (type == "file_meta") {
                            expectedSize = json.optLong("size", -1)
                            checksumHex = json.optString("checksum", "")
                            sendTransferEvent("transferStarted", mapOf(
                                "transferId" to transferId,
                                "fileName" to outFile.name,
                                "fileSize" to expectedSize
                            ))
                            transferProgress[transferId] = TransferProgress(transferId, 0, if (expectedSize > 0) expectedSize else 0, 0, 0, "receiving")
                            startedAt = System.currentTimeMillis()
                        } else if (type == "file_end") {
                            try { output.flush(); output.close() } catch (_: Exception) {}
                            // Verify checksum if provided
                            if (checksumHex.isNotEmpty()) {
                                try {
                                    val digest = java.security.MessageDigest.getInstance("SHA-256")
                                    val fis = java.io.FileInputStream(outFile)
                                    val buf = ByteArray(1024 * 1024)
                                    var r: Int
                                    while (fis.read(buf).also { r = it } > 0) { digest.update(buf, 0, r) }
                                    fis.close()
                                    val actual = digest.digest().joinToString("") { b -> "%02x".format(b) }
                                    if (!actual.equals(checksumHex, ignoreCase = true)) {
                                        sendTransferEvent("transferFailed", mapOf("transferId" to transferId, "error" to "CHECKSUM_MISMATCH"))
                                        return@receiveData
                                    }
                                } catch (ex: Exception) { Log.e(TAG, "Checksum verification failed", ex) }
                            }
                            transferProgress[transferId] = TransferProgress(transferId, received, if (expectedSize > 0) expectedSize else received, 0, 0, "completed")
                            sendTransferEvent("transferCompleted", mapOf(
                                "transferId" to transferId,
                                "bytesTransferred" to received,
                                "totalBytes" to (if (expectedSize > 0) expectedSize else received),
                                "progress" to 100,
                                "status" to "completed"
                            ))
                        }
                    } catch (_: Exception) {}
                } else {
                    // Binary frame: [type=1][fileIdLen][fileId][offset:8][dataLen:4][data]
                    if (bytes.size >= 1 + 1 + 8 + 4 && bytes[0].toInt() == 1) {
                        var index = 0
                        index++ // type
                        val fileIdLen = bytes[index++].toInt() and 0xFF
                        index += fileIdLen
                        val offset = java.nio.ByteBuffer.wrap(bytes, index, 8).getLong()
                        index += 8
                        val dataLen = java.nio.ByteBuffer.wrap(bytes, index, 4).getInt()
                        index += 4
                        if (bytes.size >= index + dataLen) {
                            output.write(bytes, index, dataLen)
                            received += dataLen
                            val total = if (expectedSize > 0) expectedSize else (received)
                            val progressPct = if (total > 0) ((received.toFloat() / total) * 100).toInt() else 0
                            val elapsedSec = (System.currentTimeMillis() - startedAt).coerceAtLeast(1) / 1000.0
                            val speed = if (elapsedSec > 0) (received / elapsedSec).toLong() else 0L
                            transferProgress[transferId] = TransferProgress(transferId, received, total, speed, if (speed > 0 && total > 0) ((total - received) / speed) else 0, "receiving")
                            sendTransferEvent("transferProgress", mapOf(
                                "transferId" to transferId,
                                "bytesTransferred" to received,
                                "totalBytes" to total,
                                "progress" to progressPct,
                                "speed" to speed,
                                "status" to "receiving"
                            ))
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Wi-Fi Aware receive error", e)
            }
        }
    }
    
    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        eventSink?.success(mapOf(
            "type" to eventType,
            "service" to "discovery",
            "data" to data,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    private fun sendDiscoveryEvent(eventType: String, data: Map<String, Any>) {
        eventSink?.success(mapOf(
            "type" to eventType,
            "service" to "discovery",
            "data" to data,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    private fun sendTransferEvent(eventType: String, data: Map<String, Any>) {
        eventSink?.success(mapOf(
            "type" to eventType,
            "service" to "transfer",
            "data" to data,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    private fun emitWifiAwareData(connectionToken: String, bytes: ByteArray) {
        wifiAwareDataSink?.success(mapOf(
            "connectionToken" to connectionToken,
            "bytes" to bytes
        ))
    }
    
    // ==================== Audit Mode Handlers ====================
    
    private fun handleEnableAuditMode(result: MethodChannel.Result) {
        try {
            AuditLogger.AUDIT_MODE = true
            Log.i(TAG, "Audit mode enabled")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable audit mode", e)
            result.error("AUDIT_ERROR", e.message, null)
        }
    }
    
    private fun handleDisableAuditMode(result: MethodChannel.Result) {
        try {
            AuditLogger.AUDIT_MODE = false
            Log.i(TAG, "Audit mode disabled")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disable audit mode", e)
            result.error("AUDIT_ERROR", e.message, null)
        }
    }
    
    private fun handleGetAuditMetrics(call: MethodCall, result: MethodChannel.Result) {
        try {
            val transferId = call.argument<String>("transferId")
            if (transferId == null) {
                result.error("INVALID_ARGUMENT", "transferId is required", null)
                return
            }
            
            // Try to get per-transport audit metrics first
            val transportMethod = transferToTransport[transferId]
            val metrics = when (transportMethod) {
                "wifi_aware" -> {
                    // Try to get Wi-Fi Aware specific metrics if available
                    wifiAwareManager?.getAuditMetrics(transferId) ?: auditLogger.getAuditLog(transferId)
                }
                "ble" -> {
                    // Try to get BLE specific metrics if available
                    bleAdvertiser?.getAuditMetrics(transferId) ?: auditLogger.getAuditLog(transferId)
                }
                else -> {
                    // Fall back to general audit logger
                    auditLogger.getAuditLog(transferId)
                }
            }
            
            Log.d(TAG, "Retrieved audit metrics for transfer: $transferId (transport: $transportMethod)")
            result.success(metrics)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get audit metrics", e)
            result.error("AUDIT_ERROR", e.message, null)
        }
    }
    
    private fun handleExportAuditLogs(call: MethodCall, result: MethodChannel.Result) {
        try {
            val outputPath = call.argument<String>("outputPath")
            if (outputPath == null) {
                result.error("INVALID_ARGUMENT", "outputPath is required", null)
                return
            }
            
            auditLogger.exportAuditLogs(outputPath)
            Log.i(TAG, "Audit logs export successful: $outputPath")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to export audit logs", e)
            result.error("AUDIT_ERROR", e.message, null)
        }
    }
    
    // ==================== Audit Evidence Collection Handlers ====================
    
    private fun handleGetStorageStatus(result: MethodChannel.Result) {
        try {
            val statFs = android.os.StatFs(android.os.Environment.getDataDirectory().path)
            val availableBytes = statFs.availableBytes
            val totalBytes = statFs.totalBytes
            
            val storageStatus = mapOf(
                "availableBytes" to availableBytes,
                "totalBytes" to totalBytes
            )
            
            Log.d(TAG, "Storage status: ${availableBytes / (1024 * 1024)} MB available of ${totalBytes / (1024 * 1024)} MB total")
            result.success(storageStatus)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get storage status", e)
            result.error("STORAGE_ERROR", e.message, null)
        }
    }
    
    private fun handleGetCapabilities(result: MethodChannel.Result) {
        try {
            val wifiAwareAvailable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_WIFI_AWARE)
            } else {
                false
            }
            
            val bleSupported = context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_BLUETOOTH_LE)
            
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
            val bleEnabled = bluetoothManager?.adapter?.isEnabled ?: false
            
            val capabilities = mapOf(
                "wifiAwareAvailable" to wifiAwareAvailable,
                "bleSupported" to bleSupported,
                "bleEnabled" to bleEnabled,
                "platform" to "android"
            )
            
            Log.d(TAG, "Device capabilities: Wi-Fi Aware=$wifiAwareAvailable, BLE=$bleSupported/$bleEnabled")
            result.success(capabilities)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get capabilities", e)
            result.error("CAPABILITY_ERROR", e.message, null)
        }
    }
    
    private fun handleCaptureScreenshot(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("INVALID_ARGUMENT", "path is required", null)
                return
            }
            
            // Note: Screenshot capture on Android requires activity context and proper permissions
            // This is a placeholder implementation that logs the request
            // Full implementation would use PixelCopy API with activity window
            Log.w(TAG, "Screenshot capture requested but not fully implemented: $path")
            Log.w(TAG, "Screenshot capture requires activity context and WRITE_EXTERNAL_STORAGE permission")
            
            // Return false to indicate screenshot not captured
            // In a full implementation, this would use PixelCopy.request() with the activity's window
            result.success(false)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to capture screenshot", e)
            result.error("SCREENSHOT_ERROR", e.message, null)
        }
    }
    
    private fun handleExportDeviceLogs(call: MethodCall, result: MethodChannel.Result) {
        scope.launch(Dispatchers.IO) {
            try {
                val destDir = call.argument<String>("destDir")
                if (destDir == null) {
                    result.error("INVALID_ARGUMENT", "destDir is required", null)
                    return@launch
                }
                
                val timestamp = System.currentTimeMillis()
                val logFile = java.io.File(destDir, "android_logcat_$timestamp.txt")
                
                // Execute logcat command to capture app logs
                val process = Runtime.getRuntime().exec(arrayOf(
                    "logcat",
                    "-d",  // Dump mode
                    "-s",  // Silent mode with filters
                    "AuditLogger:*",
                    "AirLink:*",
                    "AirLinkPlugin:*"
                ))
                
                val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
                val writer = java.io.BufferedWriter(java.io.FileWriter(logFile))
                
                writer.write("Android Device Logs\n")
                writer.write("Timestamp: ${java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).format(java.util.Date())}\n")
                writer.write("Device: ${Build.MANUFACTURER} ${Build.MODEL}\n")
                writer.write("Android Version: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})\n")
                writer.write("=".repeat(80) + "\n\n")
                
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    writer.write(line)
                    writer.write("\n")
                }
                
                writer.close()
                reader.close()
                process.waitFor()
                
                Log.i(TAG, "Device logs exported: ${logFile.absolutePath}")
                result.success(listOf(logFile.absolutePath))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to export device logs", e)
                result.error("LOG_EXPORT_ERROR", e.message, null)
            }
        }
    }
    
    private fun handleListTransferredFiles(result: MethodChannel.Result) {
        try {
            val transferredFiles = mutableListOf<Map<String, Any>>()
            
            // Collect files from active and completed transfers
            for ((transferId, state) in activeTransfers) {
                val file = java.io.File(state.filePath)
                if (file.exists()) {
                    transferredFiles.add(mapOf(
                        "transferId" to transferId,
                        "filePath" to state.filePath,
                        "fileSize" to state.fileSize,
                        "status" to state.status
                    ))
                }
            }
            
            Log.d(TAG, "Listed ${transferredFiles.size} transferred files")
            result.success(transferredFiles)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to list transferred files", e)
            result.error("LIST_ERROR", e.message, null)
        }
    }
    
    private fun cleanup() {
        scope.launch {
            try {
                stopDiscovery()
                activeConnections.clear()
                advancedFeaturesHandler.cleanup()
                Log.i(TAG, "Plugin cleanup completed")
            } catch (e: Exception) {
                Log.e(TAG, "Error during cleanup", e)
            }
        }
    }
}

// Data classes
data class ConnectionInfo(
    val peerId: String,
    var status: String,
    val timestamp: Long,
    val connectionMethod: String = "wifi_aware",
    val host: String? = null,
    val port: Int? = null
)

data class TransferState(
    val transferId: String,
    val filePath: String,
    val fileSize: Long,
    val targetDeviceId: String,
    val connectionToken: String,
    val connectionMethod: String,
    val status: String,
    val startTime: Long
)

data class TransferProgress(
    val transferId: String,
    val bytesTransferred: Long,
    val totalBytes: Long,
    val speed: Long = 0,
    val eta: Long = 0,
    val status: String
)