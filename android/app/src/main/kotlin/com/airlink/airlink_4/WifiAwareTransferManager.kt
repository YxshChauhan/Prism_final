package com.airlink.airlink_4

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.*
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * Wi-Fi Aware Transfer Manager
 * Handles file transfers using Wi-Fi Aware technology with proper session management,
 * progress tracking, and audit logging.
 */
class WifiAwareTransferManager(
    private val context: Context,
    private val methodChannel: MethodChannel?,
    private val auditLogger: AuditLogger?
) {
    companion object {
        private const val TAG = "WifiAwareTransferManager"
        private const val DEFAULT_PORT = 8888
        private const val BUFFER_SIZE = 64 * 1024 // 64KB chunks
        private const val PROGRESS_UPDATE_INTERVAL_MS = 500L
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val activeSessions = ConcurrentHashMap<String, TransferSession>()
    private val wifiAwareWrapper = WifiAwareManagerWrapper(context)

    /**
     * Transfer session data class
     */
    private data class TransferSession(
        val transferId: String,
        val filePath: String,
        val fileSize: Long,
        val peerDeviceId: String,
        val connectionMethod: String,
        var socket: Socket? = null,
        var serverSocket: ServerSocket? = null,
        var job: Job? = null,
        var bytesTransferred: AtomicLong = AtomicLong(0),
        var startTime: Long = System.currentTimeMillis(),
        var isPaused: Boolean = false,
        var isCancelled: Boolean = false
    )

    /**
     * Start a Wi-Fi Aware transfer
     * @param params Transfer parameters including transferId, filePath, fileSize, deviceId, connectionMethod
     * @return Transfer ID on success, empty string on failure
     */
    fun startTransfer(params: Map<String, Any?>): String {
        try {
            val transferId = params["transferId"] as? String ?: return ""
            val filePath = params["filePath"] as? String ?: return ""
            val fileSize = (params["fileSize"] as? Number)?.toLong() ?: return ""
            val deviceId = params["deviceId"] as? String ?: return ""
            val connectionMethod = params["connectionMethod"] as? String ?: "wifi_aware"

            Log.d(TAG, "Starting Wi-Fi Aware transfer: $transferId")
            auditLogger?.logEvent("transfer_start", mapOf(
                "transferId" to transferId,
                "fileSize" to fileSize,
                "connectionMethod" to connectionMethod
            ))

            // Validate file exists
            val file = File(filePath)
            if (!file.exists() || !file.canRead()) {
                Log.e(TAG, "File not found or not readable: $filePath")
                return ""
            }

            // Create transfer session
            val session = TransferSession(
                transferId = transferId,
                filePath = filePath,
                fileSize = fileSize,
                peerDeviceId = deviceId,
                connectionMethod = connectionMethod
            )
            activeSessions[transferId] = session

            // Start transfer in coroutine
            session.job = scope.launch {
                try {
                    executeTransfer(session)
                } catch (e: Exception) {
                    Log.e(TAG, "Transfer failed: ${e.message}", e)
                    handleTransferError(session, e)
                }
            }

            return transferId
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start transfer: ${e.message}", e)
            auditLogger?.logEvent("transfer_start_error", mapOf("error" to e.message))
            return ""
        }
    }

    /**
     * Start a multi-receiver transfer (send to multiple devices simultaneously)
     * @param params Transfer parameters including transferId, filePath, fileSize, deviceIds (list), connectionMethod
     * @return Transfer ID on success, empty string on failure
     */
    fun startMultiReceiverTransfer(params: Map<String, Any?>): String {
        try {
            val transferId = params["transferId"] as? String ?: return ""
            val filePath = params["filePath"] as? String ?: return ""
            val fileSize = (params["fileSize"] as? Number)?.toLong() ?: return ""
            val deviceIds = params["deviceIds"] as? List<String> ?: return ""
            val connectionMethod = params["connectionMethod"] as? String ?: "wifi_aware"

            if (deviceIds.isEmpty()) {
                Log.e(TAG, "No device IDs provided for multi-receiver transfer")
                return ""
            }

            Log.d(TAG, "Starting multi-receiver transfer: $transferId to ${deviceIds.size} devices")
            auditLogger?.logEvent("multi_receiver_transfer_start", mapOf(
                "transferId" to transferId,
                "fileSize" to fileSize,
                "receiverCount" to deviceIds.size,
                "connectionMethod" to connectionMethod
            ))

            // Validate file exists
            val file = File(filePath)
            if (!file.exists() || !file.canRead()) {
                Log.e(TAG, "File not found or not readable: $filePath")
                return ""
            }

            // Launch parallel transfers to each device
            val completedDevices = ConcurrentHashMap<String, Boolean>()
            val failedDevices = ConcurrentHashMap<String, String>()

            deviceIds.forEach { deviceId ->
                val peerTransferId = "${transferId}_${deviceId}"
                val session = TransferSession(
                    transferId = peerTransferId,
                    filePath = filePath,
                    fileSize = fileSize,
                    peerDeviceId = deviceId,
                    connectionMethod = connectionMethod
                )
                activeSessions[peerTransferId] = session

                // Start transfer to this peer in parallel
                session.job = scope.launch {
                    try {
                        executeTransfer(session)
                        completedDevices[deviceId] = true
                        Log.d(TAG, "Multi-receiver: Transfer to $deviceId completed")
                    } catch (e: Exception) {
                        failedDevices[deviceId] = e.message ?: "Unknown error"
                        Log.e(TAG, "Multi-receiver: Transfer to $deviceId failed: ${e.message}", e)
                    }

                    // Check if all transfers completed
                    if (completedDevices.size + failedDevices.size == deviceIds.size) {
                        handleMultiReceiverComplete(
                            transferId,
                            deviceIds.size,
                            completedDevices.size,
                            failedDevices.size
                        )
                    }
                }
            }

            return transferId
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start multi-receiver transfer: ${e.message}", e)
            auditLogger?.logEvent("multi_receiver_transfer_error", mapOf("error" to e.message))
            return ""
        }
    }

    /**
     * Handle multi-receiver transfer completion
     */
    private fun handleMultiReceiverComplete(
        transferId: String,
        totalDevices: Int,
        completedCount: Int,
        failedCount: Int
    ) {
        auditLogger?.logEvent("multi_receiver_complete", mapOf(
            "transferId" to transferId,
            "totalDevices" to totalDevices,
            "completedCount" to completedCount,
            "failedCount" to failedCount,
            "successRate" to (completedCount.toDouble() / totalDevices.toDouble())
        ))

        Log.d(TAG, "Multi-receiver transfer completed: $completedCount succeeded, $failedCount failed")

        // Notify Flutter layer
        scope.launch(Dispatchers.Main) {
            methodChannel?.invokeMethod("multiReceiverComplete", mapOf(
                "transferId" to transferId,
                "totalDevices" to totalDevices,
                "completedCount" to completedCount,
                "failedCount" to failedCount
            ))
        }
    }

    /**
     * Execute the actual file transfer
     */
    private suspend fun executeTransfer(session: TransferSession) {
        withContext(Dispatchers.IO) {
            try {
                // Setup Wi-Fi Aware connection
                val dataPath = wifiAwareWrapper.createDataPath(
                    session.peerDeviceId,
                    DEFAULT_PORT
                )

                if (dataPath == null) {
                    throw IOException("Failed to create Wi-Fi Aware data path")
                }

                // Create socket connection
                val socket = Socket()
                socket.connect(InetSocketAddress(dataPath.peerIpAddress, DEFAULT_PORT), 10000)
                session.socket = socket

                Log.d(TAG, "Wi-Fi Aware connection established for ${session.transferId}")
                auditLogger?.logEvent("connection_established", mapOf(
                    "transferId" to session.transferId,
                    "peerIp" to dataPath.peerIpAddress
                ))

                // Send file
                sendFile(session, socket)

                // Transfer completed successfully
                handleTransferComplete(session)
            } catch (e: Exception) {
                if (!session.isCancelled) {
                    throw e
                }
            } finally {
                cleanupSession(session)
            }
        }
    }

    /**
     * Send file through socket with progress tracking
     */
    private suspend fun sendFile(session: TransferSession, socket: Socket) {
        val file = File(session.filePath)
        val outputStream = socket.getOutputStream()
        val inputStream = FileInputStream(file)

        try {
            val buffer = ByteArray(BUFFER_SIZE)
            var lastProgressUpdate = System.currentTimeMillis()
            var bytesRead: Int

            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                // Check if transfer is paused or cancelled
                if (session.isPaused) {
                    delay(100)
                    continue
                }
                if (session.isCancelled) {
                    break
                }

                // Write data
                outputStream.write(buffer, 0, bytesRead)
                session.bytesTransferred.addAndGet(bytesRead.toLong())

                // Emit progress updates
                val now = System.currentTimeMillis()
                if (now - lastProgressUpdate >= PROGRESS_UPDATE_INTERVAL_MS) {
                    emitProgress(session)
                    lastProgressUpdate = now
                }
            }

            outputStream.flush()
            Log.d(TAG, "File sent successfully: ${session.transferId}")
        } finally {
            inputStream.close()
        }
    }

    /**
     * Emit progress update to Flutter
     */
    private fun emitProgress(session: TransferSession) {
        val progress = if (session.fileSize > 0) {
            (session.bytesTransferred.get().toDouble() / session.fileSize * 100).toInt()
        } else {
            0
        }

        val elapsedTime = System.currentTimeMillis() - session.startTime
        val speed = if (elapsedTime > 0) {
            (session.bytesTransferred.get().toDouble() / elapsedTime * 1000).toLong()
        } else {
            0L
        }

        methodChannel?.invokeMethod("onTransferProgress", mapOf(
            "transferId" to session.transferId,
            "progress" to progress,
            "bytesTransferred" to session.bytesTransferred.get(),
            "totalBytes" to session.fileSize,
            "speed" to speed
        ))

        auditLogger?.logMetric("transfer_progress", mapOf(
            "transferId" to session.transferId,
            "progress" to progress,
            "speed" to speed
        ))
    }

    /**
     * Handle transfer completion
     */
    private fun handleTransferComplete(session: TransferSession) {
        Log.d(TAG, "Transfer completed: ${session.transferId}")

        val duration = System.currentTimeMillis() - session.startTime
        val avgSpeed = if (duration > 0) {
            (session.fileSize.toDouble() / duration * 1000).toLong()
        } else {
            0L
        }

        methodChannel?.invokeMethod("onTransferComplete", mapOf(
            "transferId" to session.transferId,
            "success" to true,
            "bytesTransferred" to session.bytesTransferred.get(),
            "duration" to duration,
            "averageSpeed" to avgSpeed
        ))

        auditLogger?.logEvent("transfer_complete", mapOf(
            "transferId" to session.transferId,
            "fileSize" to session.fileSize,
            "duration" to duration,
            "averageSpeed" to avgSpeed
        ))

        activeSessions.remove(session.transferId)
    }

    /**
     * Handle transfer error
     */
    private fun handleTransferError(session: TransferSession, error: Exception) {
        Log.e(TAG, "Transfer error: ${session.transferId}", error)

        methodChannel?.invokeMethod("onTransferError", mapOf(
            "transferId" to session.transferId,
            "error" to error.message,
            "bytesTransferred" to session.bytesTransferred.get()
        ))

        auditLogger?.logEvent("transfer_error", mapOf(
            "transferId" to session.transferId,
            "error" to error.message,
            "bytesTransferred" to session.bytesTransferred.get()
        ))

        activeSessions.remove(session.transferId)
    }

    /**
     * Stop an active transfer
     * @param transferId Transfer ID to stop
     */
    fun stopTransfer(transferId: String) {
        val session = activeSessions[transferId] ?: return

        Log.d(TAG, "Stopping transfer: $transferId")
        session.isCancelled = true
        session.job?.cancel()

        cleanupSession(session)
        activeSessions.remove(transferId)

        methodChannel?.invokeMethod("onTransferCancelled", mapOf(
            "transferId" to transferId,
            "bytesTransferred" to session.bytesTransferred.get()
        ))

        auditLogger?.logEvent("transfer_cancelled", mapOf(
            "transferId" to transferId,
            "bytesTransferred" to session.bytesTransferred.get()
        ))
    }

    /**
     * Pause a transfer
     */
    fun pauseTransfer(transferId: String): Boolean {
        val session = activeSessions[transferId] ?: return false
        session.isPaused = true
        Log.d(TAG, "Transfer paused: $transferId")
        return true
    }

    /**
     * Resume a paused transfer
     */
    fun resumeTransfer(transferId: String): Boolean {
        val session = activeSessions[transferId] ?: return false
        session.isPaused = false
        Log.d(TAG, "Transfer resumed: $transferId")
        return true
    }

    /**
     * Cleanup session resources
     */
    private fun cleanupSession(session: TransferSession) {
        try {
            session.socket?.close()
            session.serverSocket?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error cleaning up session: ${e.message}")
        }
    }

    /**
     * Get active transfer count
     */
    fun getActiveTransferCount(): Int = activeSessions.size

    /**
     * Get transfer status
     */
    fun getTransferStatus(transferId: String): Map<String, Any>? {
        val session = activeSessions[transferId] ?: return null
        return mapOf(
            "transferId" to session.transferId,
            "progress" to (session.bytesTransferred.get().toDouble() / session.fileSize * 100).toInt(),
            "bytesTransferred" to session.bytesTransferred.get(),
            "totalBytes" to session.fileSize,
            "isPaused" to session.isPaused,
            "isCancelled" to session.isCancelled
        )
    }

    /**
     * Cleanup all resources
     */
    fun dispose() {
        Log.d(TAG, "Disposing WifiAwareTransferManager")
        activeSessions.values.forEach { cleanupSession(it) }
        activeSessions.clear()
        scope.cancel()
        wifiAwareWrapper.dispose()
    }
}

/**
 * Data path information from Wi-Fi Aware
 */
data class DataPathInfo(
    val peerIpAddress: String,
    val port: Int
)
