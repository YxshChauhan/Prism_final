package com.airlink.airlink_4

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

/**
 * Foreground Service for Background Transfers
 * 
 * Manages file transfers in the background to ensure they continue
 * even when the app is not in the foreground
 */
class TransferForegroundService : Service() {
    
    companion object {
        private const val TAG = "TransferForegroundService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "airlink_transfer_channel"
        
        const val ACTION_START = "com.airlink.airlink_4.START_TRANSFER"
        const val ACTION_STOP = "com.airlink.airlink_4.STOP_TRANSFER"
        const val ACTION_UPDATE_PROGRESS = "com.airlink.airlink_4.UPDATE_PROGRESS"
        const val ACTION_PAUSE = "com.airlink.airlink_4.PAUSE_TRANSFER"
        const val ACTION_CANCEL = "com.airlink.airlink_4.CANCEL_TRANSFER"
        
        const val EXTRA_CONNECTION_TOKEN = "connection_token"
        const val EXTRA_TRANSFER_ID = "transfer_id"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_FILE_NAME = "file_name"
        const val EXTRA_TOTAL_BYTES = "total_bytes"
    }
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isServiceRunning = false
    private var connectionToken: String? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var progressReceiver: BroadcastReceiver? = null
    private lateinit var prefs: android.content.SharedPreferences
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerProgressReceiver()
        prefs = getSharedPreferences("airlink_transfers", Context.MODE_PRIVATE)
        Log.i(TAG, "Transfer foreground service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                connectionToken = intent.getStringExtra(EXTRA_CONNECTION_TOKEN)
                startForegroundService()
                persistState()
            }
            ACTION_STOP -> {
                stopForegroundService()
                clearState()
            }
            ACTION_PAUSE -> {
                val transferId = intent.getStringExtra(EXTRA_TRANSFER_ID) ?: ""
                sendControlCommandToPlugin("pauseTransfer", transferId)
            }
            ACTION_CANCEL -> {
                val transferId = intent.getStringExtra(EXTRA_TRANSFER_ID) ?: ""
                sendControlCommandToPlugin("cancelTransfer", transferId)
                stopForegroundService()
            }
            ACTION_UPDATE_PROGRESS -> {
                val transferId = intent.getStringExtra(EXTRA_TRANSFER_ID)
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                updateProgressNotification(transferId, progress)
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        isServiceRunning = false
        unregisterProgressReceiver()
        releaseWakeLock()
        Log.i(TAG, "Transfer foreground service destroyed")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AirLink Transfer Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Manages file transfers in the background"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun startForegroundService() {
        if (isServiceRunning) {
            Log.w(TAG, "Service already running")
            return
        }
        
        val notification = createNotification("Starting transfer...", "Preparing file transfer")
        
        startForeground(NOTIFICATION_ID, notification)
        isServiceRunning = true
        acquireWakeLock()
        restoreAndResubscribe()
        
        Log.i(TAG, "Transfer foreground service started with connection: $connectionToken")
    }
    
    private fun stopForegroundService() {
        if (!isServiceRunning) {
            Log.w(TAG, "Service not running")
            return
        }
        
        stopForeground(true)
        stopSelf()
        isServiceRunning = false
        clearState()
        
        Log.i(TAG, "Transfer foreground service stopped")
    }

    private fun persistState() {
        try {
            prefs.edit().putString("connection_token", connectionToken).apply()
        } catch (_: Exception) {}
    }

    private fun clearState() {
        try {
            prefs.edit().clear().apply()
        } catch (_: Exception) {}
    }

    private fun restoreAndResubscribe() {
        try {
            if (connectionToken.isNullOrEmpty()) {
                connectionToken = prefs.getString("connection_token", null)
            }
            // In a full implementation, we would re-attach to plugin streams here
        } catch (_: Exception) {}
    }
    
    private fun updateProgressNotification(transferId: String?, progress: Int) {
        if (!isServiceRunning) return
        
        val title = "Transferring files..."
        val content = "Progress: $progress%"
        
        val notification = createNotification(title, content)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        Log.d(TAG, "Progress updated: $progress% for transfer: $transferId")
    }
    
    private fun createNotification(title: String, content: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val pauseIntent = Intent(this, TransferForegroundService::class.java).apply { action = ACTION_PAUSE }
        val pausePending = PendingIntent.getService(this, 1, pauseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val cancelIntent = Intent(this, TransferForegroundService::class.java).apply { action = ACTION_CANCEL }
        val cancelPending = PendingIntent.getService(this, 2, cancelIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(android.R.drawable.ic_media_pause, "Pause", pausePending)
            .addAction(android.R.drawable.ic_delete, "Cancel", cancelPending)
            .build()
    }
    
    fun updateTransferProgress(transferId: String, sentBytes: Long, totalBytes: Long, speed: Double) {
        if (!isServiceRunning) return
        
        val progress = if (totalBytes > 0) {
            ((sentBytes * 100) / totalBytes).toInt()
        } else {
            0
        }
        
        val title = "Transferring files..."
        val content = "Progress: $progress% (${formatBytes(sentBytes)}/${formatBytes(totalBytes)}) - ${formatSpeed(speed)}"
        
        val notification = createNotification(title, content)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        Log.d(TAG, "Transfer progress: $progress% - ${formatBytes(sentBytes)}/${formatBytes(totalBytes)} at ${formatSpeed(speed)}")
    }
    
    private fun formatBytes(bytes: Long): String {
        return when {
            bytes >= 1024 * 1024 * 1024 -> "${bytes / (1024 * 1024 * 1024)}GB"
            bytes >= 1024 * 1024 -> "${bytes / (1024 * 1024)}MB"
            bytes >= 1024 -> "${bytes / 1024}KB"
            else -> "${bytes}B"
        }
    }
    
    private fun formatSpeed(bytesPerSecond: Double): String {
        return when {
            bytesPerSecond >= 1024 * 1024 -> "${String.format("%.1f", bytesPerSecond / (1024 * 1024))}MB/s"
            bytesPerSecond >= 1024 -> "${String.format("%.1f", bytesPerSecond / 1024)}KB/s"
            else -> "${String.format("%.1f", bytesPerSecond)}B/s"
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$TAG:WakeLock").apply {
                setReferenceCounted(false)
                acquire(30 * 60 * 1000L) // 30 min safety timeout
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wakelock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wakelock", e)
        } finally {
            wakeLock = null
        }
    }

    private fun registerProgressReceiver() {
        val filter = IntentFilter(ACTION_UPDATE_PROGRESS)
        progressReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return
                val transferId = intent.getStringExtra(EXTRA_TRANSFER_ID)
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                updateProgressNotification(transferId, progress)
            }
        }
        LocalBroadcastManager.getInstance(this).registerReceiver(progressReceiver!!, filter)
    }

    private fun unregisterProgressReceiver() {
        progressReceiver?.let {
            LocalBroadcastManager.getInstance(this).unregisterReceiver(it)
            progressReceiver = null
        }
    }

    private fun sendControlCommandToPlugin(method: String, transferId: String) {
        try {
            val intent = Intent("com.airlink.airlink_4.PLUGIN_CONTROL")
            intent.putExtra("method", method)
            intent.putExtra(EXTRA_TRANSFER_ID, transferId)
            LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send control command to plugin", e)
        }
    }
}