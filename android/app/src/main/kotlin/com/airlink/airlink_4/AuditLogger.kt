package com.airlink.airlink_4

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Debug
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * AuditLogger - Centralized audit logging for Android native layer
 * Collects audit-level metrics including CPU usage, memory consumption,
 * network throughput, and transfer events for production testing
 */
class AuditLogger(private val context: Context) {
    
    companion object {
        var AUDIT_MODE = false
        private const val TAG = "AuditLogger"
        private const val LOG_FILE_NAME = "audit_logs.json"
    }
    
    // Thread-safe collections for audit data
    private val transferLogs = ConcurrentHashMap<String, ConcurrentLinkedQueue<AuditEvent>>()
    private val systemMetricsCache = ConcurrentHashMap<String, SystemMetrics>()
    private val dateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    
    // CPU usage differential sampling
    private var previousCpuIdle: Long = 0
    private var previousCpuTotal: Long = 0
    private var lastCpuSampleTime: Long = 0
    private val cpuSampleIntervalMs: Long = 1000 // Sample every 1 second
    
    init {
        dateFormatter.timeZone = TimeZone.getTimeZone("UTC")
    }
    
    /**
     * Log transfer initiation with timestamp and metadata
     */
    fun logTransferStart(transferId: String, fileSize: Long, method: String) {
        if (!AUDIT_MODE) return
        
        try {
            val event = AuditEvent(
                type = "transfer_start",
                timestamp = getCurrentTimestamp(),
                transferId = transferId,
                data = mapOf(
                    "fileSize" to fileSize,
                    "method" to method,
                    "systemMetrics" to getCurrentSystemMetrics()
                )
            )
            addAuditEvent(transferId, event)
            Log.d(TAG, "Transfer start logged: $transferId, size: $fileSize, method: $method")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log transfer start: ${e.message}")
        }
    }
    
    /**
     * Log transfer progress with current metrics
     */
    fun logTransferProgress(transferId: String, bytesTransferred: Long, speed: Double) {
        if (!AUDIT_MODE) return
        
        try {
            val event = AuditEvent(
                type = "transfer_progress",
                timestamp = getCurrentTimestamp(),
                transferId = transferId,
                data = mapOf(
                    "bytesTransferred" to bytesTransferred,
                    "speed" to speed,
                    "systemMetrics" to getCurrentSystemMetrics()
                )
            )
            addAuditEvent(transferId, event)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log transfer progress: ${e.message}")
        }
    }
    
    /**
     * Log transfer completion with final metrics
     */
    fun logTransferComplete(transferId: String, duration: Long, checksum: String?) {
        if (!AUDIT_MODE) return
        
        try {
            val event = AuditEvent(
                type = "transfer_complete",
                timestamp = getCurrentTimestamp(),
                transferId = transferId,
                data = mapOf(
                    "duration" to duration,
                    "checksum" to checksum,
                    "systemMetrics" to getCurrentSystemMetrics()
                )
            )
            addAuditEvent(transferId, event)
            Log.d(TAG, "Transfer complete logged: $transferId, duration: ${duration}ms")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log transfer complete: ${e.message}")
        }
    }
    
    /**
     * Capture current system metrics (CPU, memory, battery)
     */
    fun logSystemMetrics(transferId: String) {
        if (!AUDIT_MODE) return
        
        try {
            val metrics = getCurrentSystemMetrics()
            systemMetricsCache[transferId] = metrics
            
            val event = AuditEvent(
                type = "system_metrics",
                timestamp = getCurrentTimestamp(),
                transferId = transferId,
                data = mapOf("systemMetrics" to metrics.toMap())
            )
            addAuditEvent(transferId, event)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log system metrics: ${e.message}")
        }
    }
    
    /**
     * Retrieve structured audit log for a transfer
     */
    fun getAuditLog(transferId: String): Map<String, Any> {
        if (!AUDIT_MODE) return emptyMap()
        
        return try {
            val events = transferLogs[transferId]?.toList() ?: emptyList()
            val metrics = systemMetricsCache[transferId]
            
            mapOf(
                "transferId" to transferId,
                "events" to events.map { it.toMap() },
                "latestMetrics" to (metrics?.toMap() ?: emptyMap<String, Any>()),
                "eventCount" to events.size,
                "generatedAt" to getCurrentTimestamp()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get audit log: ${e.message}")
            emptyMap()
        }
    }

    /**
     * Generic event logger to support older code paths calling `logEvent`
     */
    fun logEvent(eventName: String, data: Map<String, Any?>) {
        if (!AUDIT_MODE) return
        try {
            val transferId = (data["transferId"] as? String) ?: (data["connectionToken"] as? String) ?: "system"
            val event = AuditEvent(
                type = eventName,
                timestamp = getCurrentTimestamp(),
                transferId = transferId,
                data = data.filterValues { it != null }
            )
            addAuditEvent(transferId, event)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log event $eventName: ${e.message}")
        }
    }

    /**
     * Generic metric logger to support older code paths calling `logMetric`
     */
    fun logMetric(metricName: String, data: Map<String, Any?>) {
        if (!AUDIT_MODE) return
        try {
            val transferId = (data["transferId"] as? String) ?: (data["connectionToken"] as? String) ?: "system"
            val event = AuditEvent(
                type = metricName,
                timestamp = getCurrentTimestamp(),
                transferId = transferId,
                data = data.filterValues { it != null }
            )
            addAuditEvent(transferId, event)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log metric $metricName: ${e.message}")
        }
    }
    
    /**
     * Export all audit logs to JSON file
     */
    fun exportAuditLogs(outputPath: String) {
        if (!AUDIT_MODE) return
        
        try {
            val allLogs = mutableMapOf<String, Any>()
            
            // Export all transfer logs
            transferLogs.forEach { (transferId, events) ->
                allLogs[transferId] = mapOf(
                    "events" to events.map { it.toMap() },
                    "metrics" to (systemMetricsCache[transferId]?.toMap() ?: emptyMap<String, Any>())
                )
            }
            
            val exportData = mapOf(
                "auditLogs" to allLogs,
                "exportedAt" to getCurrentTimestamp(),
                "deviceInfo" to getDeviceInfo()
            )
            
            val jsonString = JSONObject(exportData).toString(2)
            val file = File(if (outputPath.isNotEmpty()) outputPath else getDefaultLogPath())
            FileWriter(file).use { writer ->
                writer.write(jsonString)
            }
            
            Log.i(TAG, "Audit logs exported to: ${file.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to export audit logs: ${e.message}")
        }
    }
    
    /**
     * Clear audit logs for a specific transfer
     */
    fun clearTransferLogs(transferId: String) {
        transferLogs.remove(transferId)
        systemMetricsCache.remove(transferId)
    }
    
    /**
     * Clear all audit logs
     */
    fun clearAllLogs() {
        transferLogs.clear()
        systemMetricsCache.clear()
    }
    
    // Private helper methods
    
    private fun addAuditEvent(transferId: String, event: AuditEvent) {
        val eventQueue = transferLogs.getOrPut(transferId) { ConcurrentLinkedQueue() }
        eventQueue.offer(event)
        
        // Limit queue size to prevent memory issues
        while (eventQueue.size > 1000) {
            eventQueue.poll()
        }
    }
    
    private fun getCurrentTimestamp(): String {
        return dateFormatter.format(Date())
    }
    
    private fun getCurrentSystemMetrics(): SystemMetrics {
        return SystemMetrics(
            cpuUsagePercent = getCpuUsagePercent(),
            memoryUsageMB = getMemoryUsageMB(),
            batteryLevel = getBatteryLevel(),
            availableMemoryMB = getAvailableMemoryMB(),
            timestamp = getCurrentTimestamp()
        )
    }
    
    private fun getCpuUsagePercent(): Double {
        return try {
            val currentTime = System.currentTimeMillis()
            
            // Read current CPU stats
            val reader = BufferedReader(FileReader("/proc/stat"))
            val line = reader.readLine()
            reader.close()
            
            val tokens = line.split(" ").filter { it.isNotEmpty() }
            val idle = tokens[4].toLong()
            val total = tokens.drop(1).take(7).sumOf { it.toLong() }
            
            // Use differential sampling if we have previous values and enough time has passed
            if (previousCpuTotal > 0 && (currentTime - lastCpuSampleTime) >= cpuSampleIntervalMs) {
                val idleDelta = idle - previousCpuIdle
                val totalDelta = total - previousCpuTotal
                
                // Update previous values for next sample
                previousCpuIdle = idle
                previousCpuTotal = total
                lastCpuSampleTime = currentTime
                
                // Calculate usage from delta
                if (totalDelta > 0) {
                    val usage = ((totalDelta - idleDelta).toDouble() / totalDelta.toDouble()) * 100.0
                    return Math.round(usage * 100.0) / 100.0
                }
            } else if (previousCpuTotal == 0L) {
                // Initialize on first call
                previousCpuIdle = idle
                previousCpuTotal = total
                lastCpuSampleTime = currentTime
            }
            
            // Fallback to instantaneous calculation
            val usage = ((total - idle).toDouble() / total.toDouble()) * 100.0
            Math.round(usage * 100.0) / 100.0
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get CPU usage: ${e.message}")
            0.0
        }
    }
    
    private fun getMemoryUsageMB(): Double {
        return try {
            val memoryInfo = Debug.MemoryInfo()
            Debug.getMemoryInfo(memoryInfo)
            val totalPss = memoryInfo.totalPss
            Math.round((totalPss / 1024.0) * 100.0) / 100.0
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get memory usage: ${e.message}")
            0.0
        }
    }
    
    private fun getAvailableMemoryMB(): Double {
        return try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            Math.round((memoryInfo.availMem / (1024.0 * 1024.0)) * 100.0) / 100.0
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get available memory: ${e.message}")
            0.0
        }
    }
    
    private fun getBatteryLevel(): Int {
        return try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get battery level: ${e.message}")
            -1
        }
    }
    
    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "manufacturer" to android.os.Build.MANUFACTURER,
            "model" to android.os.Build.MODEL,
            "androidVersion" to android.os.Build.VERSION.RELEASE,
            "apiLevel" to android.os.Build.VERSION.SDK_INT,
            "brand" to android.os.Build.BRAND,
            "device" to android.os.Build.DEVICE
        )
    }
    
    private fun getDefaultLogPath(): String {
        val externalDir = context.getExternalFilesDir(null)
        return File(externalDir, LOG_FILE_NAME).absolutePath
    }
    
    // Data classes
    
    private data class AuditEvent(
        val type: String,
        val timestamp: String,
        val transferId: String,
        val data: Map<String, Any?>
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "type" to type,
                "timestamp" to timestamp,
                "transferId" to transferId,
                "data" to data
            )
        }
    }
    
    private data class SystemMetrics(
        val cpuUsagePercent: Double,
        val memoryUsageMB: Double,
        val batteryLevel: Int,
        val availableMemoryMB: Double,
        val timestamp: String
    ) {
        fun toMap(): Map<String, Any> {
            return mapOf(
                "cpuUsagePercent" to cpuUsagePercent,
                "memoryUsageMB" to memoryUsageMB,
                "batteryLevel" to batteryLevel,
                "availableMemoryMB" to availableMemoryMB,
                "timestamp" to timestamp
            )
        }
    }
}
