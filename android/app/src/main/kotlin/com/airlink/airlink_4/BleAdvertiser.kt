package com.airlink.airlink_4

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.EventChannel
import com.google.gson.Gson
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap
import java.util.UUID

/**
 * BLE Advertiser and Scanner
 * 
 * Provides Bluetooth Low Energy advertising and scanning functionality
 * for devices that don't support Wi-Fi Aware
 */
class BleAdvertiser(
    private val context: Context,
    private val eventSink: EventChannel.EventSink?
) {
    
    // Audit logging
    private val auditLogger = AuditLogger(context)
    
    companion object {
        private const val TAG = "BleAdvertiser"
        private const val SERVICE_UUID = "12345678-1234-1234-1234-123456789abc"
        private const val CHARACTERISTIC_UUID = "87654321-4321-4321-4321-cba987654321"
        private const val METADATA_CHARACTERISTIC_UUID = "11111111-1111-1111-1111-111111111111"
        private const val CHUNK_CHARACTERISTIC_UUID = "22222222-2222-2222-2222-222222222222"
        private const val ACK_CHARACTERISTIC_UUID = "33333333-3333-3333-3333-333333333333"
        private const val MAX_CHUNK_SIZE = 512 // BLE MTU - 3 bytes overhead
        private const val WINDOW_SIZE = 5 // Sliding window size
        private const val ACK_TIMEOUT_MS = 5000L
    }
    
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var isAdvertising = false
    private var isScanning = false
    private var isGattServerRunning = false
    
    // Reusable callback instances
    private var scanCallback: ScanCallback? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var gattServerCallback: BluetoothGattServerCallback? = null
    
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val discoveredDevices = ConcurrentHashMap<String, ScanResult>()
    private val activeConnections = ConcurrentHashMap<String, ConnectionInfo>()
    private val gattConnections = ConcurrentHashMap<String, BluetoothGatt>()
    
    // Write queue for chunked transfer with backpressure control
    private val writeQueues = ConcurrentHashMap<String, MutableList<ByteArray>>()
    private val isWriting = ConcurrentHashMap<String, Boolean>()
    private val maxPendingWrites = 5 // Limit pending writes for backpressure
    private val writeRetryDelays = ConcurrentHashMap<String, Long>() // Exponential backoff
    
    // File transfer state
    private val activeTransfers = ConcurrentHashMap<String, TransferState>()
    private val chunkBuffers = ConcurrentHashMap<String, MutableMap<Int, ByteArray>>()
    private val ackTimeouts = ConcurrentHashMap<String, MutableMap<Int, Job>>()
    private val receivedChunks = ConcurrentHashMap<String, MutableSet<Int>>()
    private val transferProgress = ConcurrentHashMap<String, TransferProgress>()
    private var encryptionKey: ByteArray? = null // AES-GCM key
    
    data class ConnectionInfo(
        val deviceId: String,
        val deviceAddress: String,
        val isConnected: Boolean = false,
        val gatt: BluetoothGatt? = null
    )
    
    data class TransferState(
        val transferId: String,
        val filePath: String,
        val fileSize: Long,
        val totalChunks: Int,
        val bytesTransferred: Long = 0,
        val status: String = "pending", // pending, sending, receiving, completed, failed
        val startTime: Long = System.currentTimeMillis(),
        val connectionToken: String
    )
    
    data class TransferProgress(
        val transferId: String,
        val bytesTransferred: Long,
        val totalBytes: Long,
        val speed: Long = 0, // bytes per second
        val eta: Long = 0, // estimated time remaining in seconds
        val status: String
    )
    
    data class ChunkHeader(
        val sequenceNumber: Int,
        val totalChunks: Int,
        val data: ByteArray
    ) {
        fun toByteArray(): ByteArray {
            val header = ByteArray(8) // 4 bytes for sequence, 4 bytes for total
            header[0] = (sequenceNumber shr 24).toByte()
            header[1] = (sequenceNumber shr 16).toByte()
            header[2] = (sequenceNumber shr 8).toByte()
            header[3] = sequenceNumber.toByte()
            header[4] = (totalChunks shr 24).toByte()
            header[5] = (totalChunks shr 16).toByte()
            header[6] = (totalChunks shr 8).toByte()
            header[7] = totalChunks.toByte()
            return header + data
        }
        
        companion object {
            fun fromByteArray(data: ByteArray): ChunkHeader {
                val sequenceNumber = ((data[0].toInt() and 0xFF) shl 24) or
                        ((data[1].toInt() and 0xFF) shl 16) or
                        ((data[2].toInt() and 0xFF) shl 8) or
                        (data[3].toInt() and 0xFF)
                val totalChunks = ((data[4].toInt() and 0xFF) shl 24) or
                        ((data[5].toInt() and 0xFF) shl 16) or
                        ((data[6].toInt() and 0xFF) shl 8) or
                        (data[7].toInt() and 0xFF)
                val chunkData = data.sliceArray(8 until data.size)
                return ChunkHeader(sequenceNumber, totalChunks, chunkData)
            }
        }
    }
    
    init {
        initializeBluetooth()
    }
    
    fun isSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                bluetoothAdapter = bluetoothManager.adapter
                bluetoothAdapter?.isEnabled == true && 
                context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
            } catch (e: Exception) {
                Log.e(TAG, "Error checking BLE support", e)
                false
            }
        } else {
            false
        }
    }
    
    fun startScanning(): Boolean {
        return if (isSupported() && !isScanning) {
            scope.launch {
                try {
                    bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
                    val scanFilter = ScanFilter.Builder()
                        .setServiceUuid(ParcelUuid.fromString(SERVICE_UUID))
                        .build()
                    
                    val scanSettings = ScanSettings.Builder()
                        .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                        .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
                        .build()
                    
                    scanCallback = createScanCallback()
                    bluetoothLeScanner?.startScan(listOf(scanFilter), scanSettings, scanCallback!!)
                    isScanning = true
                    Log.i(TAG, "BLE scanning started")
                    sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start BLE scanning", e)
                    sendEvent("discoveryUpdate", mapOf<String, Any>("error" to (e.message ?: "Unknown error")))
                }
            }
            true
        } else {
            Log.w(TAG, "BLE not supported or already scanning")
            false
        }
    }
    
    fun stopScanning() {
        scope.launch {
            try {
                scanCallback?.let { callback ->
                    bluetoothLeScanner?.stopScan(callback)
                }
                isScanning = false
                Log.i(TAG, "BLE scanning stopped")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "stopped"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop BLE scanning", e)
            }
        }
    }
    
    fun startAdvertising(): Boolean {
        return if (isSupported() && !isAdvertising) {
            scope.launch {
                try {
                    bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
                    
                    val advertiseData = AdvertiseData.Builder()
                        .setIncludeDeviceName(true)
                        .addServiceUuid(ParcelUuid.fromString(SERVICE_UUID))
                        .build()
                    
                    val advertiseSettings = AdvertiseSettings.Builder()
                        .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
                        .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                        .setConnectable(true)
                        .build()
                    
                    advertiseCallback = createAdvertiseCallback()
                    bluetoothLeAdvertiser?.startAdvertising(advertiseSettings, advertiseData, advertiseCallback!!)
                    isAdvertising = true
                    
                    // Start GATT server for peripheral mode
                    startGattServer()
                    
                    Log.i(TAG, "BLE advertising started")
                    sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start BLE advertising", e)
                    sendEvent("discoveryUpdate", mapOf<String, Any>("error" to (e.message ?: "Unknown error")))
                }
            }
            true
        } else {
            Log.w(TAG, "BLE not supported or already advertising")
            false
        }
    }
    
    fun stopAdvertising() {
        scope.launch {
            try {
                advertiseCallback?.let { callback ->
                    bluetoothLeAdvertiser?.stopAdvertising(callback)
                }
                isAdvertising = false
                
                // Stop GATT server
                stopGattServer()
                
                Log.i(TAG, "BLE advertising stopped")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "stopped"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop BLE advertising", e)
            }
        }
    }
    
    fun connectToDevice(deviceAddress: String): String {
        return try {
            val connectionToken = "ble_conn_${System.currentTimeMillis()}"
            val device = bluetoothAdapter?.getRemoteDevice(deviceAddress)
            
            if (device != null) {
                val gatt = device.connectGatt(context, false, createGattCallback(connectionToken))
                gattConnections[connectionToken] = gatt
                
                activeConnections[connectionToken] = ConnectionInfo(
                    deviceId = deviceAddress,
                    deviceAddress = deviceAddress,
                    isConnected = false,
                    gatt = gatt
                )
                
                Log.i(TAG, "Connecting to BLE device: $deviceAddress")
                sendEvent("discoveryUpdate", mapOf<String, Any>(
                    "connectionToken" to connectionToken,
                    "deviceAddress" to deviceAddress,
                    "connectionMethod" to "ble"
                ))
                
                connectionToken
            } else {
                throw IllegalArgumentException("Device not found: $deviceAddress")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect to device: $deviceAddress", e)
            throw e
        }
    }
    
    private fun initializeBluetooth() {
        try {
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            bluetoothAdapter = bluetoothManager.adapter
            Log.i(TAG, "Bluetooth initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Bluetooth", e)
        }
    }
    
    private fun createScanCallback(): ScanCallback {
        return object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val deviceAddress = result.device.address
                discoveredDevices[deviceAddress] = result
                
                Log.i(TAG, "BLE device discovered: $deviceAddress")
                sendEvent("discoveryUpdate", mapOf<String, Any>(
                    "deviceAddress" to deviceAddress,
                    "deviceName" to result.device.name,
                    "rssi" to result.rssi,
                    "connectionMethod" to "ble"
                ))
            }
            
            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "BLE scan failed with error: $errorCode")
                sendEvent("discoveryUpdate", mapOf<String, Any>("error" to "scan_failed", "errorCode" to errorCode))
            }
        }
    }
    
    private fun createAdvertiseCallback(): AdvertiseCallback {
        return object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.i(TAG, "BLE advertising started successfully")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
            }
            
            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "BLE advertising failed to start: $errorCode")
                sendEvent("discoveryUpdate", mapOf<String, Any>("error" to "start_failed", "errorCode" to errorCode))
            }
        }
    }
    
    private fun createGattCallback(connectionToken: String): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        Log.i(TAG, "BLE device connected: ${gatt.device.address}")
                        gatt.discoverServices()
                        
                        activeConnections[connectionToken]?.let { connection ->
                            activeConnections[connectionToken] = connection.copy(isConnected = true)
                        }
                        
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "connectionToken" to connectionToken,
                            "deviceAddress" to gatt.device.address,
                            "connectionMethod" to "ble"
                        ))
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        Log.i(TAG, "BLE device disconnected: ${gatt.device.address}")
                        
                        activeConnections[connectionToken]?.let { connection ->
                            activeConnections[connectionToken] = connection.copy(isConnected = false)
                        }
                        
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "connectionToken" to connectionToken,
                            "deviceAddress" to gatt.device.address,
                            "connectionMethod" to "ble"
                        ))
                    }
                }
            }
            
            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "BLE services discovered for: ${gatt.device.address}")
                    
                    // Find our custom service and characteristics
                    val service = gatt.getService(java.util.UUID.fromString(SERVICE_UUID))
                    if (service != null) {
                        val characteristic = service.getCharacteristic(java.util.UUID.fromString(CHARACTERISTIC_UUID))
                        val metadataCharacteristic = service.getCharacteristic(java.util.UUID.fromString(METADATA_CHARACTERISTIC_UUID))
                        if (characteristic != null) {
                            // Request MTU for higher throughput (API 21+)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                gatt.requestMtu(517)
                            }
                            
                            // Enable notifications/indications
                            gatt.setCharacteristicNotification(characteristic, true)
                            
                            // Set up write queue for chunked transfer
                            setupWriteQueue(gatt, characteristic, connectionToken)
                            
                            sendEvent("discoveryUpdate", mapOf<String, Any>(
                                "connectionToken" to connectionToken,
                                "deviceAddress" to gatt.device.address,
                                "connectionMethod" to "ble",
                                "serviceUuid" to SERVICE_UUID,
                                "characteristicUuid" to CHARACTERISTIC_UUID
                            ))

                            // Attempt to read metadata characteristic to obtain remote public key (if provided)
                            try {
                                if (metadataCharacteristic != null) {
                                    gatt.readCharacteristic(metadataCharacteristic)
                                }
                            } catch (_: Exception) {}
                        } else {
                            Log.e(TAG, "Characteristic not found")
                            sendEvent("discoveryUpdate", mapOf<String, Any>(
                                "connectionToken" to connectionToken,
                                "error" to "characteristic_not_found"
                            ))
                        }
                    } else {
                        Log.e(TAG, "Service not found")
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "connectionToken" to connectionToken,
                            "error" to "service_not_found"
                        ))
                    }
                } else {
                    Log.e(TAG, "Failed to discover services: $status")
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "connectionToken" to connectionToken,
                        "error" to "service_discovery_failed",
                        "status" to status
                    ))
                }
            }
            
            override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val value = characteristic.value
                    Log.d(TAG, "Characteristic read: ${String(value)}")
                    if (characteristic.uuid.toString() == METADATA_CHARACTERISTIC_UUID) {
                        try {
                            val json = String(value)
                            val gson = Gson()
                            val meta = gson.fromJson(json, Map::class.java) as Map<String, Any>
                            val pk = meta["publicKey"]
                            if (pk is List<*>) {
                                val keyBytes = (pk.filterIsInstance<Double>().map { it.toInt().toByte() }).toByteArray()
                                sendEvent("discoveryUpdate", mapOf<String, Any>(
                                    "connectionToken" to connectionToken,
                                    "connectionMethod" to "ble",
                                    "publicKey" to keyBytes.toList()
                                ))
                            }
                        } catch (_: Exception) {}
                    }
                }
            }
            
            override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "Characteristic write successful")
                    isWriting[connectionToken] = false
                    // Reset retry delay on success
                    writeRetryDelays[connectionToken] = 100L
                    // Process next item in write queue
                    processWriteQueue(connectionToken)
                } else {
                    Log.e(TAG, "Characteristic write failed: $status")
                    isWriting[connectionToken] = false
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "connectionToken" to connectionToken,
                        "error" to "write_failed",
                        "status" to status
                    ))
                    // Retry with exponential backoff
                    scheduleRetry(connectionToken)
                }
            }
            
            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "MTU changed to: $mtu")
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "connectionToken" to connectionToken,
                        "mtu" to mtu
                    ))
                } else {
                    Log.e(TAG, "MTU change failed: $status")
                }
            }
            
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                val value = characteristic.value
                Log.d(TAG, "Characteristic changed: ${String(value)}")
                sendEvent("discoveryUpdate", mapOf<String, Any>(
                    "connectionToken" to connectionToken,
                    "data" to String(value)
                ))
            }
        }
    }
    
    private fun setupWriteQueue(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, connectionToken: String) {
        writeQueues[connectionToken] = mutableListOf()
        isWriting[connectionToken] = false
        Log.i(TAG, "Write queue setup for connection: $connectionToken")
    }
    
    private fun processWriteQueue(connectionToken: String) {
        val queue = writeQueues[connectionToken] ?: return
        val gatt = gattConnections[connectionToken] ?: return
        
        if (isWriting[connectionToken] == true || queue.isEmpty()) {
            return
        }
        
        // Check backpressure - limit pending writes
        if (queue.size > maxPendingWrites) {
            Log.w(TAG, "Write queue full, dropping oldest write for connection: $connectionToken")
            queue.removeAt(0) // Remove oldest write
        }
        
        isWriting[connectionToken] = true
        val data = queue.removeAt(0)
        
        scope.launch {
            try {
                val service = gatt.getService(java.util.UUID.fromString(SERVICE_UUID))
                val characteristic = service?.getCharacteristic(java.util.UUID.fromString(CHARACTERISTIC_UUID))
                
                if (characteristic != null) {
                    characteristic.value = data
                    gatt.writeCharacteristic(characteristic)
                } else {
                    Log.e(TAG, "Characteristic not found for write")
                    isWriting[connectionToken] = false
                    // Retry with exponential backoff
                    scheduleRetry(connectionToken)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write characteristic", e)
                isWriting[connectionToken] = false
                // Retry with exponential backoff
                scheduleRetry(connectionToken)
            }
        }
    }
    
    private fun scheduleRetry(connectionToken: String) {
        val currentDelay = writeRetryDelays[connectionToken] ?: 100L
        val newDelay = (currentDelay * 2).coerceAtMost(5000L) // Max 5 seconds
        writeRetryDelays[connectionToken] = newDelay
        
        scope.launch {
            delay(newDelay)
            processWriteQueue(connectionToken)
        }
    }
    
    fun sendData(connectionToken: String, data: ByteArray) {
        val queue = writeQueues[connectionToken] ?: return
        queue.add(data)
        processWriteQueue(connectionToken)
    }
    
    /**
     * Start file transfer over BLE
     */
    fun startFileTransfer(connectionToken: String, filePath: String, transferId: String): Boolean {
        return try {
            val file = java.io.File(filePath)
            if (!file.exists()) {
                Log.e(TAG, "File not found: $filePath")
                return false
            }
            
            // Audit logging - transfer start
            if (AuditLogger.AUDIT_MODE) {
                auditLogger.logTransferStart(transferId, file.length(), "ble")
                auditLogger.logSystemMetrics(transferId)
            }
            if (!file.canRead()) {
                Log.e(TAG, "File not readable: $filePath")
                return false
            }
            val maxFileSize = 2L * 1024L * 1024L * 1024L // 2GB limit
            if (file.length() > maxFileSize) {
                Log.w(TAG, "Very large file: ${file.length()} bytes")
            }
            
            val fileSize = file.length()
            val totalChunks = ((fileSize + MAX_CHUNK_SIZE - 1) / MAX_CHUNK_SIZE).toInt()
            
            val transferState = TransferState(
                transferId = transferId,
                filePath = filePath,
                fileSize = fileSize,
                totalChunks = totalChunks,
                connectionToken = connectionToken
            )
            
            activeTransfers[transferId] = transferState
            transferProgress[transferId] = TransferProgress(
                transferId = transferId,
                bytesTransferred = 0,
                totalBytes = fileSize,
                status = "starting"
            )
            
            // Send file metadata first
            sendFileMetadata(connectionToken, transferId, file.name, fileSize, totalChunks)
            
            // Start sending chunks
            scope.launch(Dispatchers.IO) {
                sendFileChunks(transferId)
            }
            
            Log.i(TAG, "File transfer started: $transferId")
            sendEvent("transferStarted", mapOf<String, Any>(
                "transferId" to transferId,
                "fileName" to file.name,
                "fileSize" to fileSize,
                "totalChunks" to totalChunks
            ))
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start file transfer: $transferId", e)
            false
        }
    }
    
    /**
     * Send file metadata
     */
    private fun sendFileMetadata(connectionToken: String, transferId: String, fileName: String, fileSize: Long, totalChunks: Int) {
        // Compute SHA-256 checksum (hex) of the file to include in metadata
        var checksumHex = ""
        try {
            val file = java.io.File(activeTransfers[transferId]?.filePath ?: "")
            if (file.exists()) {
                val digest = java.security.MessageDigest.getInstance("SHA-256")
                file.inputStream().use { input ->
                    val buf = ByteArray(1024 * 1024)
                    var read: Int
                    while (input.read(buf).also { read = it } > 0) {
                        digest.update(buf, 0, read)
                    }
                }
                checksumHex = digest.digest().joinToString("") { b -> "%02x".format(b) }
            }
        } catch (_: Exception) {}

        val metadata = mapOf(
            "transferId" to transferId,
            "fileName" to fileName,
            "fileSize" to fileSize,
            "totalChunks" to totalChunks,
            "timestamp" to System.currentTimeMillis(),
            "checksum" to checksumHex
        )
        
        val gson = Gson()
        val metadataJson = gson.toJson(metadata)
        val metadataBytes = metadataJson.toByteArray()
        
        // Send metadata in chunks if too large
        val metadataChunks = metadataBytes.toList().chunked(MAX_CHUNK_SIZE)
        metadataChunks.forEachIndexed { index: Int, chunk: List<Byte> ->
            val header = ChunkHeader(index, metadataChunks.size, chunk.toByteArray())
            sendData(connectionToken, header.toByteArray())
        }
    }
    
    /**
     * Send file chunks with sliding window protocol
     */
    private suspend fun sendFileChunks(transferId: String) {
        val transfer = activeTransfers[transferId] ?: return
        val connectionToken = transfer.connectionToken
        val file = java.io.File(transfer.filePath)
        
        if (!file.exists()) {
            Log.e(TAG, "File not found during transfer: ${transfer.filePath}")
            return
        }
        
        val inputStream = file.inputStream()
        val buffer = ByteArray(MAX_CHUNK_SIZE)
        var chunkIndex = 0
        var bytesRead: Int
        var windowStart = 0
        
        try {
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                val chunkData = buffer.copyOf(bytesRead)
                val header = ChunkHeader(chunkIndex, transfer.totalChunks, chunkData)
                
                // Send chunk
                sendData(connectionToken, header.toByteArray())
                
                // Set up ACK timeout
                setupAckTimeout(transferId, chunkIndex)
                
                // Update progress
                updateTransferProgress(transferId, bytesRead.toLong())
                
                chunkIndex++
                
                // Implement sliding window
                if (chunkIndex - windowStart >= WINDOW_SIZE) {
                    // Wait for ACK before sending more chunks
                    waitForAck(transferId, windowStart)
                    windowStart++
                }
            }
            
            // Wait for all remaining ACKs
            while (windowStart < chunkIndex) {
                waitForAck(transferId, windowStart)
                windowStart++
            }
            
            // Transfer completed
            activeTransfers[transferId] = transfer.copy(status = "completed")
            transferProgress[transferId]?.let { progress ->
                transferProgress[transferId] = progress.copy(status = "completed")
            }
            
            // Audit logging - transfer completion
            if (AuditLogger.AUDIT_MODE) {
                val duration = System.currentTimeMillis() - transfer.startTime
                auditLogger.logTransferComplete(transferId, duration, null)
            }
            
            sendEvent("transferCompleted", mapOf<String, Any>(
                "transferId" to transferId,
                "bytesTransferred" to transfer.fileSize
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during file transfer: $transferId", e)
            activeTransfers[transferId] = transfer.copy(status = "failed")
            transferProgress[transferId]?.let { progress ->
                transferProgress[transferId] = progress.copy(status = "failed")
            }
            
            // Audit logging - transfer failure
            if (AuditLogger.AUDIT_MODE) {
                val duration = System.currentTimeMillis() - transfer.startTime
                auditLogger.logTransferComplete(transferId, duration, null)
            }
            
            sendEvent("transferFailed", mapOf<String, Any>(
                "transferId" to transferId,
                "error" to (e.message ?: "Unknown error")
            ))
        } finally {
            inputStream.close()
        }
    }
    
    /**
     * Setup ACK timeout for a chunk
     */
    private fun setupAckTimeout(transferId: String, chunkIndex: Int) {
        val timeoutJob = scope.launch {
            delay(ACK_TIMEOUT_MS)
            // Timeout occurred, retry sending chunk
            retryChunk(transferId, chunkIndex)
        }
        
        ackTimeouts[transferId]?.put(chunkIndex, timeoutJob)
    }
    
    /**
     * Wait for ACK for a specific chunk
     */
    private suspend fun waitForAck(transferId: String, chunkIndex: Int) {
        // This is a simplified implementation
        // In a real implementation, you'd wait for the actual ACK
        delay(100) // Small delay to simulate waiting
    }
    
    /**
     * Retry sending a chunk
     */
    private fun retryChunk(transferId: String, chunkIndex: Int) {
        // Implementation for retrying failed chunks
        Log.w(TAG, "Retrying chunk $chunkIndex for transfer $transferId")
    }
    
    /**
     * Update transfer progress
     */
    private fun updateTransferProgress(transferId: String, bytesTransferred: Long) {
        val transfer = activeTransfers[transferId] ?: return
        val newBytesTransferred = transfer.bytesTransferred + bytesTransferred
        
        activeTransfers[transferId] = transfer.copy(bytesTransferred = newBytesTransferred)
        
        // Audit logging - transfer progress (every 10% progress)
        if (AuditLogger.AUDIT_MODE) {
            val progressPercent = (newBytesTransferred.toFloat() / transfer.fileSize * 100).toInt()
            if (progressPercent % 10 == 0 && progressPercent > 0) {
                val currentSpeed = calculateSpeed(transferId).toDouble()
                auditLogger.logTransferProgress(transferId, newBytesTransferred, currentSpeed)
            }
        }
        
        val progress = transferProgress[transferId] ?: return
        val newProgress = progress.copy(
            bytesTransferred = newBytesTransferred,
            speed = calculateSpeed(transferId),
            eta = calculateETA(transferId)
        )
        transferProgress[transferId] = newProgress
        
        // Emit progress event every 1 second
        if (System.currentTimeMillis() - transfer.startTime > 1000) {
            sendEvent("transferProgress", mapOf<String, Any>(
                "transferId" to transferId,
                "bytesTransferred" to newBytesTransferred,
                "totalBytes" to transfer.fileSize,
                "progress" to (newBytesTransferred.toFloat() / transfer.fileSize * 100),
                "speed" to newProgress.speed,
                "eta" to newProgress.eta
            ))
        }
    }
    
    /**
     * Calculate transfer speed
     */
    private fun calculateSpeed(transferId: String): Long {
        val transfer = activeTransfers[transferId] ?: return 0
        val elapsedTime = (System.currentTimeMillis() - transfer.startTime) / 1000.0
        return if (elapsedTime > 0) (transfer.bytesTransferred / elapsedTime).toLong() else 0
    }
    
    /**
     * Calculate estimated time remaining
     */
    private fun calculateETA(transferId: String): Long {
        val transfer = activeTransfers[transferId] ?: return 0
        val speed = calculateSpeed(transferId)
        return if (speed > 0) (transfer.fileSize - transfer.bytesTransferred) / speed else 0
    }
    
    /**
     * Get transfer progress
     */
    fun getTransferProgress(transferId: String): TransferProgress? {
        return transferProgress[transferId]
    }
    
    /**
     * Cancel file transfer
     */
    fun cancelFileTransfer(transferId: String): Boolean {
        return try {
            val transfer = activeTransfers[transferId]
            if (transfer != null) {
                activeTransfers[transferId] = transfer.copy(status = "cancelled")
                transferProgress[transferId]?.let { progress ->
                    transferProgress[transferId] = progress.copy(status = "cancelled")
                }
                
                // Cancel all ACK timeouts
                ackTimeouts[transferId]?.values?.forEach { it.cancel() }
                ackTimeouts[transferId]?.clear()
                
                sendEvent("transferCancelled", mapOf<String, Any>(
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
    
    /**
     * Start receiving file transfer
     */
    fun startReceivingFile(connectionToken: String, transferId: String, savePath: String): Boolean {
        return try {
            // Audit logging - receive start
            if (AuditLogger.AUDIT_MODE) {
                auditLogger.logTransferStart(transferId, 0L, "ble")
                auditLogger.logSystemMetrics(transferId)
            }
            val transferState = TransferState(
                transferId = transferId,
                filePath = savePath,
                fileSize = 0, // Will be set when metadata is received
                totalChunks = 0, // Will be set when metadata is received
                status = "receiving",
                connectionToken = connectionToken
            )
            
            activeTransfers[transferId] = transferState
            chunkBuffers[transferId] = mutableMapOf()
            receivedChunks[transferId] = mutableSetOf()
            
            Log.i(TAG, "Started receiving file transfer: $transferId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start receiving file: $transferId", e)
            false
        }
    }
    
    /**
     * Start GATT server for peripheral mode
     */
    fun startGattServer(): Boolean {
        return if (isSupported() && !isGattServerRunning) {
            scope.launch {
                try {
                    val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                    bluetoothGattServer = bluetoothManager.openGattServer(context, createGattServerCallback())
                    
                    if (bluetoothGattServer != null) {
                        // Add our custom service
                        val service = BluetoothGattService(
                            UUID.fromString(SERVICE_UUID),
                            BluetoothGattService.SERVICE_TYPE_PRIMARY
                        )
                        
                        // Add metadata characteristic
                        val metadataCharacteristic = BluetoothGattCharacteristic(
                            UUID.fromString(METADATA_CHARACTERISTIC_UUID),
                            BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_WRITE or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                            BluetoothGattCharacteristic.PERMISSION_READ or
                            BluetoothGattCharacteristic.PERMISSION_WRITE
                        )
                        
                        // Add chunk characteristic
                        val chunkCharacteristic = BluetoothGattCharacteristic(
                            UUID.fromString(CHUNK_CHARACTERISTIC_UUID),
                            BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_WRITE or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                            BluetoothGattCharacteristic.PERMISSION_READ or
                            BluetoothGattCharacteristic.PERMISSION_WRITE
                        )
                        
                        // Add ACK characteristic
                        val ackCharacteristic = BluetoothGattCharacteristic(
                            UUID.fromString(ACK_CHARACTERISTIC_UUID),
                            BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_WRITE or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                            BluetoothGattCharacteristic.PERMISSION_READ or
                            BluetoothGattCharacteristic.PERMISSION_WRITE
                        )
                        
                        // Add legacy characteristic for backward compatibility
                        val characteristic = BluetoothGattCharacteristic(
                            UUID.fromString(CHARACTERISTIC_UUID),
                            BluetoothGattCharacteristic.PROPERTY_READ or
                            BluetoothGattCharacteristic.PROPERTY_WRITE or
                            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                            BluetoothGattCharacteristic.PERMISSION_READ or
                            BluetoothGattCharacteristic.PERMISSION_WRITE
                        )
                        
                        // Add CCCD descriptors for notifications
                        val cccdDescriptor = BluetoothGattDescriptor(
                            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"), // CCCD UUID
                            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
                        )
                        
                        metadataCharacteristic.addDescriptor(cccdDescriptor)
                        chunkCharacteristic.addDescriptor(cccdDescriptor)
                        ackCharacteristic.addDescriptor(cccdDescriptor)
                        characteristic.addDescriptor(cccdDescriptor)
                        
                        service.addCharacteristic(metadataCharacteristic)
                        service.addCharacteristic(chunkCharacteristic)
                        service.addCharacteristic(ackCharacteristic)
                        service.addCharacteristic(characteristic)
                        bluetoothGattServer?.addService(service)
                        
                        isGattServerRunning = true
                        Log.i(TAG, "GATT server started")
                        sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "gatt_server_started"))
                    } else {
                        Log.e(TAG, "Failed to create GATT server")
                        sendEvent("discoveryUpdate", mapOf<String, Any>("error" to "gatt_server_failed"))
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start GATT server", e)
                    sendEvent("discoveryUpdate", mapOf<String, Any>("error" to (e.message ?: "Unknown error")))
                }
            }
            true
        } else {
            Log.w(TAG, "BLE not supported or GATT server already running")
            false
        }
    }
    
    /**
     * Stop GATT server
     */
    fun stopGattServer() {
        scope.launch {
            try {
                bluetoothGattServer?.close()
                bluetoothGattServer = null
                isGattServerRunning = false
                Log.i(TAG, "GATT server stopped")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "gatt_server_stopped"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop GATT server", e)
            }
        }
    }
    
    private fun createGattServerCallback(): BluetoothGattServerCallback {
        return object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        Log.i(TAG, "GATT server: Device connected: ${device.address}")
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "deviceAddress" to device.address,
                            "connectionMethod" to "ble",
                            "status" to "connected"
                        ))
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        Log.i(TAG, "GATT server: Device disconnected: ${device.address}")
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "deviceAddress" to device.address,
                            "connectionMethod" to "ble",
                            "status" to "disconnected"
                        ))
                    }
                }
            }
            
            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                Log.d(TAG, "GATT server: Characteristic read request from ${device.address}")
                
                // Send response with some data
                val responseData = "Hello from AirLink".toByteArray()
                bluetoothGattServer?.sendResponse(
                    device,
                    requestId,
                    BluetoothGatt.GATT_SUCCESS,
                    offset,
                    responseData
                )
            }
            
            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray
            ) {
                Log.d(TAG, "GATT server: Characteristic write request from ${device.address}")
                // Basic validation for incoming data sizes and offsets
                if (value.isEmpty() || value.size > 1024 * 64) { // 64KB sanity limit for a single write
                    Log.w(TAG, "Malformed characteristic write: size=${value.size}")
                }
                if (offset != 0) {
                    Log.w(TAG, "Non-zero write offset not supported: $offset")
                }
                
                when (characteristic.uuid.toString()) {
                    METADATA_CHARACTERISTIC_UUID -> {
                        val plain = tryDecryptIfNeeded(value)
                        handleMetadataWrite(device, plain)
                    }
                    CHUNK_CHARACTERISTIC_UUID -> {
                        val plain = tryDecryptIfNeeded(value)
                        handleChunkWrite(device, plain)
                    }
                    ACK_CHARACTERISTIC_UUID -> {
                        handleAckWrite(device, value)
                    }
                    CHARACTERISTIC_UUID -> {
                        // Legacy characteristic
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "deviceAddress" to device.address,
                            "data" to String(value),
                            "connectionMethod" to "ble"
                        ))
                    }
                }
                
                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        null
                    )
                }
            }
            
            /**
             * Handle metadata write (file info)
             */
            private fun handleMetadataWrite(device: BluetoothDevice, value: ByteArray) {
                try {
                    val metadataJson = String(value)
                    if (metadataJson.length > 8192) {
                        Log.w(TAG, "Metadata JSON unusually large: ${metadataJson.length}")
                    }
                    val gson = Gson()
                    val metadata = gson.fromJson(metadataJson, Map::class.java) as Map<String, Any>
                    
                    val transferId = (metadata["transferId"] as? String) ?: return
                    val fileName = (metadata["fileName"] as? String) ?: "file.bin"
                    val fileSize = ((metadata["fileSize"] as? Number)?.toLong()) ?: 0L
                    val totalChunks = ((metadata["totalChunks"] as? Number)?.toInt()) ?: 0
                    if (fileSize < 0 || totalChunks < 0) {
                        Log.w(TAG, "Invalid metadata values: size=$fileSize chunks=$totalChunks")
                    }
                    
                    // Update transfer state
                    activeTransfers[transferId]?.let { transfer ->
                        activeTransfers[transferId] = transfer.copy(
                            fileSize = fileSize,
                            totalChunks = totalChunks
                        )
                    }
                    
                    Log.i(TAG, "Received file metadata: $fileName, size: $fileSize, chunks: $totalChunks")
                    sendEvent("transferStarted", mapOf<String, Any>(
                        "transferId" to transferId,
                        "fileName" to fileName,
                        "fileSize" to fileSize,
                        "totalChunks" to totalChunks
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse metadata", e)
                }
            }
            
            /**
             * Handle chunk write (file data)
             */
            private fun handleChunkWrite(device: BluetoothDevice, value: ByteArray) {
                try {
                    val chunkHeader = ChunkHeader.fromByteArray(value)
                    if (chunkHeader.sequenceNumber < 0 || chunkHeader.totalChunks <= 0 ||
                        chunkHeader.sequenceNumber >= chunkHeader.totalChunks) {
                        Log.w(TAG, "Invalid chunk header: seq=${chunkHeader.sequenceNumber} total=${chunkHeader.totalChunks}")
                        return
                    }
                    if (chunkHeader.data.isEmpty() || chunkHeader.data.size > MAX_CHUNK_SIZE) {
                        Log.w(TAG, "Invalid chunk data size: ${chunkHeader.data.size}")
                        return
                    }
                    val transferId = findTransferIdByDevice(device.address)
                    
                    if (transferId != null) {
                        // Store chunk in buffer
                        chunkBuffers[transferId]?.put(chunkHeader.sequenceNumber, chunkHeader.data)
                        receivedChunks[transferId]?.add(chunkHeader.sequenceNumber)
                        
                        // Send ACK
                        sendAck(device, chunkHeader.sequenceNumber)
                        
                        // Check if all chunks received
                        val transfer = activeTransfers[transferId]
                        if (transfer != null && receivedChunks[transferId]?.size == transfer.totalChunks) {
                            assembleFile(transferId)
                        }
                        
                        // Emit progress event
                        val progress = (receivedChunks[transferId]?.size ?: 0).toFloat() / (transfer?.totalChunks ?: 1) * 100
                        
                        // Audit logging - receive progress (every 10% progress)
                        if (AuditLogger.AUDIT_MODE && progress.toInt() % 10 == 0 && progress > 0) {
                            val receivedBytes = (receivedChunks[transferId]?.size ?: 0) * MAX_CHUNK_SIZE.toLong()
                            auditLogger.logTransferProgress(transferId, receivedBytes, 0.0)
                        }
                        
                        sendEvent("transferProgress", mapOf<String, Any>(
                            "transferId" to transferId,
                            "progress" to progress,
                            "chunksReceived" to (receivedChunks[transferId]?.size ?: 0),
                            "totalChunks" to (transfer?.totalChunks ?: 0)
                        ))
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to process chunk", e)
                }
            }
            
            /**
             * Handle ACK write
             */
            private fun handleAckWrite(device: BluetoothDevice, value: ByteArray) {
                try {
                    val ackData = String(value)
                    val chunkIndex = ackData.toInt()
                    
                    // Cancel timeout for this chunk
                    val transferId = findTransferIdByDevice(device.address)
                    if (transferId != null) {
                        ackTimeouts[transferId]?.get(chunkIndex)?.cancel()
                        ackTimeouts[transferId]?.remove(chunkIndex)
                    }
                    
                    Log.d(TAG, "Received ACK for chunk $chunkIndex")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to process ACK", e)
                }
            }
            
            /**
             * Send ACK for a chunk
             */
            private fun sendAck(device: BluetoothDevice, chunkIndex: Int) {
                try {
                    val ackData = chunkIndex.toString().toByteArray()
                    val service = bluetoothGattServer?.getService(UUID.fromString(SERVICE_UUID))
                    val ackCharacteristic = service?.getCharacteristic(UUID.fromString(ACK_CHARACTERISTIC_UUID))
                    
                    if (ackCharacteristic != null) {
                        ackCharacteristic.value = ackData
                        bluetoothGattServer?.notifyCharacteristicChanged(device, ackCharacteristic, false)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send ACK", e)
                }
            }
            
            /**
             * Find transfer ID by device address
             */
            private fun findTransferIdByDevice(deviceAddress: String): String? {
                return activeTransfers.values.find { transfer ->
                    // This is a simplified lookup - in real implementation you'd track device connections
                    true // For now, return first transfer
                }?.transferId
            }
            
            /**
             * Assemble received file
             */
            private fun assembleFile(transferId: String) {
                try {
                    val transfer = activeTransfers[transferId] ?: return
                    val chunks = chunkBuffers[transferId] ?: return
                    
                    val outputFile = java.io.File(transfer.filePath)
                    val outputStream = outputFile.outputStream()
                    
                    // Write chunks in order
                    for (i in 0 until transfer.totalChunks) {
                        val chunk = chunks[i]
                        if (chunk != null) {
                            outputStream.write(chunk)
                        }
                    }
                    
                    outputStream.close()
                    
                    // Update transfer status
                    activeTransfers[transferId] = transfer.copy(status = "completed")
                    
                    Log.i(TAG, "File assembled successfully: ${transfer.filePath}")
                    sendEvent("transferCompleted", mapOf<String, Any>(
                        "transferId" to transferId,
                        "filePath" to transfer.filePath,
                        "fileSize" to transfer.fileSize
                    ))
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to assemble file: $transferId", e)
                    activeTransfers[transferId]?.let { transfer ->
                        activeTransfers[transferId] = transfer.copy(status = "failed")
                    }
                    
                    sendEvent("transferFailed", mapOf<String, Any>(
                        "transferId" to transferId,
                        "error" to (e.message ?: "File assembly failed")
                    ))
                }
            }
            
            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray
            ) {
                Log.d(TAG, "GATT server: Descriptor write request from ${device.address}")
                
                // Handle CCCD descriptor writes for notifications
                if (descriptor.uuid == UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")) {
                    val isNotificationEnabled = value.isNotEmpty() && (value[0].toInt() and 0x01) != 0
                    Log.i(TAG, "Notifications ${if (isNotificationEnabled) "enabled" else "disabled"} for ${device.address}")
                    
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "deviceAddress" to device.address,
                        "notificationsEnabled" to isNotificationEnabled,
                        "connectionMethod" to "ble"
                    ))
                }
                
                if (responseNeeded) {
                    bluetoothGattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        null
                    )
                }
            }
        }
    }

    private fun tryDecryptIfNeeded(value: ByteArray): ByteArray {
        return try {
            if (value.isNotEmpty() && value[0].toInt() == 1 && value.size > 13) {
                // Envelope: [1][nonce:12][ciphertext...]
                val key = encryptionKey
                if (key == null) return value
                val nonce = value.copyOfRange(1, 13)
                val cipherText = value.copyOfRange(13, value.size)
                val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
                val keySpec = javax.crypto.spec.SecretKeySpec(key, "AES")
                val gcmSpec = javax.crypto.spec.GCMParameterSpec(128, nonce)
                cipher.init(javax.crypto.Cipher.DECRYPT_MODE, keySpec, gcmSpec)
                cipher.doFinal(cipherText)
            } else {
                value
            }
        } catch (e: Exception) {
            Log.e(TAG, "BLE decrypt failed", e)
            value
        }
    }

    fun setEncryptionKey(key: ByteArray) {
        // Accept 16/24/32 byte AES keys
        if (key.size != 16 && key.size != 24 && key.size != 32) {
            Log.e(TAG, "Invalid BLE AES key length: ${key.size}")
            return
        }
        encryptionKey = key.copyOf()
        try { java.util.Arrays.fill(key, 0.toByte()) } catch (_: Exception) {}
        Log.i(TAG, "BLE encryption key set (len=${encryptionKey?.size})")
    }
    
    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        try {
            // Determine service based on event type
            val service = when {
                eventType.startsWith("transfer") -> "transfer"
                else -> "discovery"
            }
            
            eventSink?.success(mapOf(
                "type" to eventType,
                "service" to service,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send event: $eventType", e)
        }
    }
    
    /**
     * Get BLE audit metrics for a transfer
     */
    fun getBleAuditMetrics(transferId: String): Map<String, Any> {
        return getAuditMetrics(transferId)
    }
    
    /**
     * Get audit metrics for a transfer (consistent API with WifiAwareManagerWrapper)
     */
    fun getAuditMetrics(transferId: String): Map<String, Any> {
        return if (AuditLogger.AUDIT_MODE) {
            auditLogger.getAuditLog(transferId)
        } else {
            emptyMap()
        }
    }
}