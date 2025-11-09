package com.airlink.airlink_4

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkRequest
import android.net.wifi.aware.WifiAwareManager
import android.net.wifi.aware.WifiAwareNetworkSpecifier
import android.net.wifi.aware.WifiAwareSession
import android.net.wifi.aware.AttachCallback
import android.net.wifi.aware.DiscoverySessionCallback
import android.net.wifi.aware.PublishDiscoverySession
import android.net.wifi.aware.SubscribeDiscoverySession
import android.net.wifi.aware.PeerHandle
import android.net.NetworkSpecifier
import android.net.wifi.aware.PublishConfig
import android.net.wifi.aware.SubscribeConfig
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import java.net.InetAddress
import java.net.Socket
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.io.OutputStream
import java.io.InputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlin.random.Random

/**
 * Wi-Fi Aware Manager Wrapper
 * 
 * Provides Wi-Fi Aware discovery and data transfer functionality
 * Requires Android 8.0+ (API 26+) and Wi-Fi Aware hardware support
 * 
 * NOTE: Simplified implementation for compilation compatibility
 */
class WifiAwareManagerWrapper(
    private val context: Context,
    private val eventSink: EventChannel.EventSink? = null,
    private val dataForwarder: ((String, ByteArray) -> Unit)? = null
) {
    
    // Audit logging
    private val auditLogger = AuditLogger(context)
    
    companion object {
        private const val TAG = "WifiAwareManager"
        private const val SERVICE_NAME = "AirLinkService"
        private const val MAX_FRAME_BYTES: Int = 16 * 1024 * 1024
    }
    
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val activeConnections = ConcurrentHashMap<String, ConnectionInfo>()
    
    // Wi-Fi Aware components
    private var wifiAwareManager: WifiAwareManager? = null
    private var wifiAwareSession: WifiAwareSession? = null
    private var publishSession: PublishDiscoverySession? = null
    private var subscribeSession: SubscribeDiscoverySession? = null
    private var connectivityManager: ConnectivityManager? = null
    // Removed global currentNetwork to avoid races; track per-connection
    
    // PeerHandle mapping for Wi-Fi Aware connections
    private val peerHandleMap = ConcurrentHashMap<String, PeerHandle>()
    private val connectionPeerHandles = ConcurrentHashMap<String, PeerHandle>()
    private val serverSockets = ConcurrentHashMap<String, ServerSocket>()
    private val clientSockets = ConcurrentHashMap<String, Socket>()
    private val outputStreams = ConcurrentHashMap<String, OutputStream>()
    private val inputStreams = ConcurrentHashMap<String, InputStream>()
    private val networkCallbacks = ConcurrentHashMap<String, ConnectivityManager.NetworkCallback>()
    private val negotiatedPorts = ConcurrentHashMap<String, Int>()
    private val encryptionKeys = ConcurrentHashMap<String, ByteArray>() // connectionToken -> AES key
    private val portCounter = AtomicInteger(40000)
    private val recvBuffers = ConcurrentHashMap<String, java.io.ByteArrayOutputStream>()
    private val expectedLengths = ConcurrentHashMap<String, Int>()
    private val negotiationAck = ConcurrentHashMap<String, Boolean>()
    private val invalidFrameCounters = ConcurrentHashMap<String, Int>()
    
    // Audit tracking
    private val transferStartTimes = ConcurrentHashMap<String, Long>()
    private val transferByteCounts = ConcurrentHashMap<String, Long>()
    
    data class ConnectionInfo(
        val peerId: String,
        val connectionToken: String,
        val isConnected: Boolean = false,
        val host: String? = null,
        val port: Int? = null,
        val network: Network? = null,
        val isServer: Boolean = false,
        val listeningPort: Int? = null
    )
    
    init {
        initializeWifiAware()
    }
    
    private fun initializeWifiAware() {
        try {
            wifiAwareManager = context.getSystemService(Context.WIFI_AWARE_SERVICE) as WifiAwareManager
            connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            Log.i(TAG, "Wi-Fi Aware components initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Wi-Fi Aware", e)
        }
    }
    
    fun isSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                wifiAwareManager?.isAvailable == true
            } catch (e: Exception) {
                Log.e(TAG, "Error checking Wi-Fi Aware support", e)
                false
            }
        } else {
            false
        }
    }
    
    fun startDiscovery(): Boolean {
        return if (isSupported()) {
            scope.launch {
                try {
                    // Gate attach by SDK version for API compatibility
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        wifiAwareManager?.attach(createAttachCallback(), null)
                    } else {
                        wifiAwareManager?.attach(createAttachCallback(), Handler(Looper.getMainLooper()))
                    }
                    Log.i(TAG, "Wi-Fi Aware discovery started")
                    sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start Wi-Fi Aware discovery", e)
                    sendEvent("discoveryUpdate", mapOf<String, Any>("error" to (e.message ?: "Unknown error")))
                }
            }
            true
        } else {
            Log.w(TAG, "Wi-Fi Aware not supported")
            false
        }
    }
    
    fun stopDiscovery() {
        scope.launch {
            try {
                publishSession?.close()
                subscribeSession?.close()
                wifiAwareSession?.close()
                publishSession = null
                subscribeSession = null
                wifiAwareSession = null
                Log.i(TAG, "Wi-Fi Aware discovery stopped")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "stopped"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop Wi-Fi Aware discovery", e)
            }
        }
    }
    
    fun publishService(metadata: Map<String, Any>) {
        scope.launch {
            try {
                val json = org.json.JSONObject(metadata)
                if (!json.has("deviceId")) {
                    json.put("deviceId", getStableDeviceId())
                }
                val publishConfig = PublishConfig.Builder()
                    .setServiceName(SERVICE_NAME)
                    .setServiceSpecificInfo(json.toString().toByteArray(Charsets.UTF_8))
                    .build()
                
                wifiAwareSession?.publish(publishConfig, createPublishDiscoverySessionCallback(), null)
                Log.i(TAG, "Wi-Fi Aware service published")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to publish service", e)
                sendEvent("service_publish_failed", mapOf<String, Any>("error" to (e.message ?: "Unknown error")))
            }
        }
    }

    private fun getStableDeviceId(): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown_android_id"
        } catch (_: Exception) { "unknown_android_id" }
    }
    
    fun subscribeService() {
        scope.launch {
            try {
                val subscribeConfig = SubscribeConfig.Builder()
                    .setServiceName(SERVICE_NAME)
                    .build()
                
                wifiAwareSession?.subscribe(subscribeConfig, createSubscribeDiscoverySessionCallback(), null)
                Log.i(TAG, "Wi-Fi Aware service subscribed")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to subscribe service", e)
                sendEvent("service_subscribe_failed", mapOf<String, Any>("error" to (e.message ?: "Unknown error")))
            }
        }
    }
    
    fun createDatapath(peerId: String): String {
        val connectionToken = "conn_${System.currentTimeMillis()}"
        
        scope.launch {
            try {
                // Get stored PeerHandle for this peerId
                val peerHandle = peerHandleMap[peerId]
                if (peerHandle == null) {
                    Log.e(TAG, "No PeerHandle found for peerId: $peerId")
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "connectionToken" to connectionToken,
                        "error" to "PeerHandle not found"
                    ))
                    return@launch
                }
                
                // Build specifier with correct discovery session (publisher or subscriber)
                val session: android.net.wifi.aware.DiscoverySession? = publishSession ?: subscribeSession
                if (session == null) {
                    Log.e(TAG, "No active discovery session. Call publishService/subscribeService first.")
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "connectionToken" to connectionToken,
                        "error" to "No active discovery session"
                    ))
                    return@launch
                }
                val isPublisher = publishSession != null

                // Do not send host pre-datapath. Port will be sent after server binds.
                if (isPublisher) {
                    activeConnections[connectionToken] = ConnectionInfo(
                        peerId = peerId,
                        connectionToken = connectionToken,
                        isConnected = false,
                        isServer = true,
                        listeningPort = negotiatedPorts[connectionToken]
                    )
                } else {
                    activeConnections[connectionToken] = ConnectionInfo(
                        peerId = peerId,
                        connectionToken = connectionToken,
                        isConnected = false,
                        isServer = false
                    )
                }

                // Map connection to its PeerHandle for later negotiation messages
                connectionPeerHandles[connectionToken] = peerHandle
                val builder = WifiAwareNetworkSpecifier.Builder(session, peerHandle)
                activeConnections[connectionToken]?.listeningPort?.let { lp -> if (lp > 0) builder.setPort(lp) }
                val networkSpecifier = builder.build()
                
                // Request network with Wi-Fi Aware transport
                val networkRequest = NetworkRequest.Builder()
                    .addTransportType(android.net.NetworkCapabilities.TRANSPORT_WIFI_AWARE)
                    .setNetworkSpecifier(networkSpecifier)
                    .build()
                
                val callback = createNetworkCallback(connectionToken)
                networkCallbacks[connectionToken] = callback
                connectivityManager?.requestNetwork(networkRequest, callback)
                
                Log.i(TAG, "Wi-Fi Aware datapath created: $connectionToken")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create datapath", e)
                sendEvent("discoveryUpdate", mapOf<String, Any>(
                    "connectionToken" to connectionToken,
                    "error" to (e.message ?: "Unknown error")
                ))
            }
        }
        
        return connectionToken
    }
    
    /**
     * Create a server socket for incoming connections
     */
    suspend fun createServerSocket(connectionToken: String, port: Int = 8080): Pair<String, Int>? {
        val connection = activeConnections[connectionToken] ?: return null
        val network = connection.network ?: return null
        return withContext(Dispatchers.IO) {
            try {
                val linkProperties = connectivityManager?.getLinkProperties(network)
                val linkAddresses = linkProperties?.linkAddresses
                if (linkAddresses != null && linkAddresses.isNotEmpty()) {
                    val ipv6Address = linkAddresses.find { it.address is java.net.Inet6Address && !it.address.isLoopbackAddress }
                    if (ipv6Address != null) {
                        val serverSocket = java.net.ServerSocket()
                        serverSocket.soTimeout = 15000
                        serverSocket.bind(java.net.InetSocketAddress(ipv6Address.address, port))
                        serverSockets[connectionToken] = serverSocket
                        val host = ipv6Address.address.hostAddress
                        val boundPort = serverSocket.localPort
                        Log.i(TAG, "Server socket created and bound to ${ipv6Address.address}:$boundPort for connection: $connectionToken")
                        Pair(host, boundPort)
                    } else {
                        Log.e(TAG, "No IPv6 address found in link properties")
                        null
                    }
                } else {
                    Log.e(TAG, "No link properties available for network")
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create server socket for connection: $connectionToken", e)
                null
            }
        }
    }
    
    /**
     * Create a client socket using the network's socket factory
     */
    fun createSocket(connectionToken: String, host: String, port: Int): Socket? {
        val connection = activeConnections[connectionToken] ?: return null
        val network = connection.network ?: return null
        
        return try {
            // Use network.getSocketFactory().createSocket(host, port) for clients
            val socketFactory = network.socketFactory
            val socket = socketFactory.createSocket(host, port)
            
            // Bind the socket to the network to ensure it uses the Aware network
            network.bindSocket(socket)
            
            Log.i(TAG, "Client socket created and bound to network for connection: $connectionToken to $host:$port")
            socket
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create client socket for connection: $connectionToken", e)
            null
        }
    }
    
    /**
     * Get connection info with host and port
     */
    fun getConnectionInfo(connectionToken: String): ConnectionInfo? {
        return activeConnections[connectionToken]
    }
    
    /**
     * Get the listening port for a connection (for port negotiation)
     */
    fun getListeningPort(connectionToken: String): Int? {
        val serverSocket = serverSockets[connectionToken]
        return serverSocket?.localPort
    }
    
    /**
     * Send data over Wi-Fi Aware connection
     */
    fun sendData(connectionToken: String, data: ByteArray): Boolean {
        return try {
            // Audit logging - transfer start
            if (AuditLogger.AUDIT_MODE) {
                auditLogger.logTransferStart(connectionToken, data.size.toLong(), "wifi_aware")
            }
            
            val outputStream = outputStreams[connectionToken]
            if (outputStream != null) {
                if (data.size > MAX_FRAME_BYTES) {
                    Log.w(TAG, "Attempting to send large frame: ${data.size} bytes for $connectionToken")
                }
                val key = encryptionKeys[connectionToken]
                if (key != null) {
                    // Encrypt with AES-GCM and frame: [enc:1][len:4][nonce:12][ciphertext:n]
                    val nonce = Random.Default.nextBytes(12)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    val keySpec = SecretKeySpec(key, "AES")
                    val gcmSpec = GCMParameterSpec(128, nonce)
                    cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec)
                    val encrypted = cipher.doFinal(data)
                    val totalLen = 12 + encrypted.size
                    outputStream.write(byteArrayOf(1))
                    outputStream.write(java.nio.ByteBuffer.allocate(4).putInt(totalLen).array())
                    outputStream.write(nonce)
                    outputStream.write(encrypted)
                } else {
                    // Frame unencrypted data: [enc=0][len:4][payload]
                    val totalLen = data.size
                    outputStream.write(byteArrayOf(0))
                    outputStream.write(java.nio.ByteBuffer.allocate(4).putInt(totalLen).array())
                    outputStream.write(data)
                }
                outputStream.flush()
                
                // Audit logging - transfer progress
                if (AuditLogger.AUDIT_MODE) {
                    val speed = calculateThroughput(connectionToken, data.size)
                    auditLogger.logTransferProgress(connectionToken, data.size.toLong(), speed)
                }
                
                Log.d(TAG, "Sent ${data.size} bytes via connection: $connectionToken")
                true
            } else {
                Log.e(TAG, "No output stream found for connection: $connectionToken")
                false
            }
        } catch (e: IOException) {
            Log.e(TAG, "Failed to send data via connection: $connectionToken", e)
            false
        }
    }
    
    /**
     * Receive data from Wi-Fi Aware connection
     */
    fun receiveData(connectionToken: String, callback: (ByteArray) -> Unit) {
        scope.launch(Dispatchers.IO) {
            try {
                val inputStream = inputStreams[connectionToken]
                if (inputStream != null) {
                    val dataIn = java.io.DataInputStream(java.io.BufferedInputStream(inputStream))
                    while (true) {
                        val encFlag: Int = try { dataIn.readUnsignedByte() } catch (_: Exception) { break }
                        val length: Int = try { dataIn.readInt() } catch (_: Exception) { break }
                        if (!validateFrameLength(length)) {
                            val current = (invalidFrameCounters[connectionToken] ?: 0) + 1
                            invalidFrameCounters[connectionToken] = current
                            Log.e(TAG, "Invalid frame length: $length (count=$current) for $connectionToken")
                            if (current >= 3) {
                                Log.e(TAG, "Too many invalid frames; closing connection $connectionToken")
                                closeConnection(connectionToken)
                                break
                            } else {
                                // Skip this frame payload safely
                                if (length > 0 && length <= MAX_FRAME_BYTES) {
                                    try { dataIn.skipBytes(length) } catch (_: Exception) {}
                                }
                                continue
                            }
                        }
                        val key = encryptionKeys[connectionToken]
                        if (encFlag == 1) {
                            if (length < 13) {
                                Log.e(TAG, "Encrypted frame too small: $length")
                                closeConnection(connectionToken)
                                break
                            }
                            val nonce = ByteArray(12)
                            dataIn.readFully(nonce)
                            val cipherText = ByteArray(length - 12)
                            dataIn.readFully(cipherText)
                            
                            // Audit logging - received bytes
                            if (AuditLogger.AUDIT_MODE) {
                                val speed = calculateThroughput(connectionToken, length)
                                auditLogger.logTransferProgress(connectionToken, length.toLong(), speed)
                            }
                            
                            if (key == null) {
                                Log.e(TAG, "Encrypted frame received but no key set; dropping")
                                continue
                            }
                            try {
                                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                val keySpec = SecretKeySpec(key, "AES")
                                val gcmSpec = GCMParameterSpec(128, nonce)
                                cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec)
                                val plain = cipher.doFinal(cipherText)
                                callback(plain)
                            } catch (ex: Exception) {
                                Log.e(TAG, "Decryption failed for connection: $connectionToken", ex)
                            }
                        } else {
                            val payload = ByteArray(length)
                            dataIn.readFully(payload)
                            callback(payload)
                        }
                    }
                } else {
                    Log.e(TAG, "No input stream found for connection: $connectionToken")
                }
            } catch (e: IOException) {
                Log.e(TAG, "Failed to receive data via connection: $connectionToken", e)
            }
        }
    }

    fun setEncryptionKey(connectionToken: String, key: ByteArray) {
        val valid = key.size == 16 || key.size == 24 || key.size == 32
        if (!valid) {
            Log.e(TAG, "Invalid AES key length: ${key.size} for $connectionToken")
            sendEvent("encryptionError", mapOf<String, Any>(
                "connectionToken" to connectionToken,
                "error" to "INVALID_KEY_LENGTH"
            ))
            return
        }
        val copy = key.copyOf()
        encryptionKeys[connectionToken] = copy
        try { java.util.Arrays.fill(key, 0.toByte()) } catch (_: Exception) {}
        Log.i(TAG, "Encryption key set for $connectionToken (len=${copy.size})")
    }
    
    /**
     * Close a connection and clean up resources
     */
    fun closeConnection(connectionToken: String) {
        try {
            // Audit logging - transfer completion
            if (AuditLogger.AUDIT_MODE) {
                val duration = System.currentTimeMillis() - (transferStartTimes[connectionToken] ?: System.currentTimeMillis())
                auditLogger.logTransferComplete(connectionToken, duration, null)
                transferStartTimes.remove(connectionToken)
            }
            // Close streams
            outputStreams[connectionToken]?.close()
            inputStreams[connectionToken]?.close()
            outputStreams.remove(connectionToken)
            inputStreams.remove(connectionToken)
            
            // Close sockets
            serverSockets[connectionToken]?.close()
            clientSockets[connectionToken]?.close()
            serverSockets.remove(connectionToken)
            clientSockets.remove(connectionToken)
            
            // Unregister callback
            try {
                val cb = networkCallbacks.remove(connectionToken)
                if (cb != null) {
                    connectivityManager?.unregisterNetworkCallback(cb)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unregister network callback for $connectionToken", e)
            }
            
            // Remove connection info
            activeConnections.remove(connectionToken)
            
            Log.i(TAG, "Connection closed: $connectionToken")
            sendEvent("discoveryUpdate", mapOf<String, Any>(
                "connectionToken" to connectionToken,
                "status" to "closed"
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close connection: $connectionToken", e)
        }
    }
    
    /**
     * Create server socket and start listening
     */
    private fun createServerSocketAndListen(connectionToken: String, network: Network) {
        scope.launch(Dispatchers.IO) {
            try {
                val created = createServerSocket(connectionToken, activeConnections[connectionToken]?.listeningPort ?: 0)
                if (created == null) return@launch
                val (host, actualPort) = created
                // Update connection info
                activeConnections[connectionToken]?.let { connection ->
                    activeConnections[connectionToken] = connection.copy(
                        host = host,
                        port = actualPort,
                        isServer = true,
                        listeningPort = actualPort
                    )
                }
                negotiatedPorts[connectionToken] = actualPort
                // Send negotiation to peer: send only port to avoid IPv6 literal issues
                try {
                    val peerHandle = connectionPeerHandles[connectionToken]
                    val json = org.json.JSONObject(mapOf("port" to actualPort)).toString()
                    if (peerHandle != null) {
                        if (publishSession != null) publishSession?.sendMessage(peerHandle, 0, json.toByteArray(Charsets.UTF_8))
                        else subscribeSession?.sendMessage(peerHandle, 0, json.toByteArray(Charsets.UTF_8))
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send negotiation message", e)
                }
                // Accept incoming connections with timeout/retry
                val serverSocket = serverSockets[connectionToken] ?: return@launch
                var attempts = 0
                while (isActive && attempts < 5) {
                    try {
                        val clientSocket = serverSocket.accept()
                        network.bindSocket(clientSocket)
                        clientSockets[connectionToken] = clientSocket
                        // Set up streams
                        outputStreams[connectionToken] = clientSocket.getOutputStream()
                        inputStreams[connectionToken] = clientSocket.getInputStream()
                        Log.i(TAG, "Client connected to server socket for connection: $connectionToken")
                        val current = activeConnections[connectionToken]
                        if (current != null) {
                            sendEvent("connectionReady", mapOf<String, Any>(
                                "deviceId" to current.peerId,
                                "connectionToken" to connectionToken,
                                "host" to (current.host ?: host),
                                "port" to (current.port ?: actualPort),
                                "connectionMethod" to "wifi_aware"
                            ))
                        }
                        try {
                            receiveData(connectionToken) { payload ->
                                try { dataForwarder?.invoke(connectionToken, payload) } catch (_: Exception) {}
                            }
                        } catch (_: Exception) {}
                        break
                    } catch (e: IOException) {
                        if (serverSocket.isClosed) break
                        attempts += 1
                        Log.e(TAG, "Error accepting connection (attempt $attempts)", e)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create server socket for connection: $connectionToken", e)
            }
        }
    }
    
    /**
     * Create client socket and connect to peer
     */
    private fun createClientSocketAndConnect(connectionToken: String, network: Network, host: String, port: Int) {
        scope.launch(Dispatchers.IO) {
            try {
                val socketFactory = network.socketFactory
                val socket = socketFactory.createSocket()
                // Harden IPv6 link-local: resolve via LinkProperties when available
                try {
                    val linkProps = connectivityManager?.getLinkProperties(network)
                    val inet6 = linkProps?.linkAddresses?.firstOrNull { it.address is java.net.Inet6Address && !it.address.isLoopbackAddress }?.address
                    if (inet6 != null) {
                        Log.i(TAG, "Resolved IPv6 ${'$'}{inet6.hostAddress} for token=${'$'}connectionToken; connecting to port ${'$'}port")
                        socket.connect(InetSocketAddress(inet6, port), 10000)
                    } else {
                        socket.connect(InetSocketAddress(host, port), 10000)
                    }
                } catch (_: Exception) {
                    socket.connect(InetSocketAddress(host, port), 10000)
                }
                network.bindSocket(socket)
                clientSockets[connectionToken] = socket
                
                // Set up streams
                outputStreams[connectionToken] = socket.getOutputStream()
                inputStreams[connectionToken] = socket.getInputStream()
                
                // Update connection info
                activeConnections[connectionToken]?.let { connection ->
                    activeConnections[connectionToken] = connection.copy(
                        host = host,
                        port = port,
                        isConnected = true
                    )
                }
                
                Log.i(TAG, "Client socket connected to $host:$port for connection: $connectionToken")
                
                // Emit connection ready event
                val current = activeConnections[connectionToken]
                if (current != null) {
                    sendEvent("connectionReady", mapOf<String, Any>(
                        "deviceId" to current.peerId,
                        "connectionToken" to connectionToken,
                        "host" to (current.host ?: host),
                        "port" to port,
                        "connectionMethod" to "wifi_aware"
                    ))
                }
                try {
                    receiveData(connectionToken) { payload ->
                        try { dataForwarder?.invoke(connectionToken, payload) } catch (_: Exception) {}
                    }
                } catch (_: Exception) {}
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create client socket for connection: $connectionToken", e)
                sendEvent("connectionFailed", mapOf<String, Any>(
                    "connectionToken" to connectionToken,
                    "code" to "CLIENT_CONNECT_FAILED",
                    "error" to (e.message ?: "Connection failed")
                ))
            }
        }
    }
    
    private fun createAttachCallback(): AttachCallback {
        return object : AttachCallback() {
            override fun onAttached(session: WifiAwareSession) {
                wifiAwareSession = session
                Log.i(TAG, "Wi-Fi Aware session attached")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "attached"))
            }
            
            override fun onAttachFailed() {
                Log.e(TAG, "Wi-Fi Aware session attach failed")
                sendEvent("discoveryUpdate", mapOf<String, Any>("error" to "attach_failed"))
            }
        }
    }
    
    private fun createPublishDiscoverySessionCallback(): DiscoverySessionCallback {
        return object : DiscoverySessionCallback() {
            override fun onPublishStarted(session: PublishDiscoverySession) {
                publishSession = session
                Log.i(TAG, "Publish session started")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "started"))
            }
            
            
            override fun onSessionConfigUpdated() {
                Log.i(TAG, "Publish session config updated")
            }
            
            override fun onSessionConfigFailed() {
                Log.e(TAG, "Publish session config failed")
                sendEvent("discoveryUpdate", mapOf<String, Any>("error" to "config_failed"))
            }
            
            override fun onSessionTerminated() {
                Log.i(TAG, "Publish session terminated")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "terminated"))
            }
            
            override fun onMessageReceived(peerHandle: PeerHandle, message: ByteArray) {
                val text = try { String(message) } catch (e: Exception) { "" }
                val deviceId = peerHandleMap.entries.firstOrNull { it.value == peerHandle }?.key
                try {
                    val json = org.json.JSONObject(text)
                    val host = json.optString("host", null)
                    val port = json.optInt("port", -1)
                    if (port > 0) {
                        activeConnections.entries.firstOrNull { it.value.peerId == deviceId }?.key?.let { token ->
                            negotiatedPorts[token] = port
                            activeConnections[token]?.let { c ->
                                activeConnections[token] = c.copy(port = port)
                            }
                            // ACK
                            try { publishSession?.sendMessage(peerHandle, 0, "{\"ack\":true}".toByteArray()) } catch (_: Exception) {}
                            Log.i(TAG, "Received port $port for $token (publisher)")
                        }
                    } else if (!host.isNullOrEmpty()) {
                        activeConnections.entries.firstOrNull { it.value.peerId == deviceId }?.key?.let { token ->
                            activeConnections[token]?.let { c ->
                                activeConnections[token] = c.copy(host = host)
                            }
                            Log.i(TAG, "Received host $host for $token (publisher)")
                        }
                    } else if (text.contains("\"ack\"")) {
                        // mark ACK for any pending token to this peer
                        val pending = activeConnections.entries.firstOrNull { it.value.peerId == deviceId && negotiationAck[it.key] == false }
                        if (pending != null) negotiationAck[pending.key] = true
                        Log.i(TAG, "Received ACK from peer (publisher view)")
                    }
                } catch (_: Exception) {
                    Log.w(TAG, "Non-JSON negotiation message ignored: $text")
                }
            }
        }
    }
    
    private fun createSubscribeDiscoverySessionCallback(): DiscoverySessionCallback {
        return object : DiscoverySessionCallback() {
            override fun onSubscribeStarted(session: SubscribeDiscoverySession) {
                subscribeSession = session
                Log.i(TAG, "Subscribe session started")
            }
            
            override fun onServiceDiscovered(peerHandle: PeerHandle, serviceSpecificInfo: ByteArray, matchFilter: List<ByteArray>) {
                val parsedId = try {
                    val s = String(serviceSpecificInfo)
                    val json = org.json.JSONObject(s)
                    json.optString("deviceId", json.optString("id", ""))
                } catch (_: Exception) { "" }
                val deviceId = if (parsedId.isNotEmpty()) parsedId else "peer_${System.currentTimeMillis()}"
                
                // Store PeerHandle mapping for later use in createDatapath
                peerHandleMap[deviceId] = peerHandle
                
                Log.i(TAG, "Service discovered: $deviceId")
                sendEvent("discoveryUpdate", mapOf<String, Any>(
                    "deviceId" to deviceId,
                    "peerId" to deviceId,
                    "serviceInfo" to String(serviceSpecificInfo),
                    "deviceName" to "Wi-Fi Aware Device",
                    "deviceType" to "android",
                    "discoveryMethod" to "wifi_aware",
                    "rssi" to -50,
                    "metadata" to mapOf(
                        "deviceType" to "android",
                        "discoveryMethod" to "wifi_aware",
                        "peerHandle" to peerHandle.hashCode(),
                        "serviceInfo" to String(serviceSpecificInfo)
                    )
                ))
            }
            
            override fun onServiceDiscoveredWithinRange(peerHandle: PeerHandle, serviceSpecificInfo: ByteArray, matchFilter: List<ByteArray>, distanceMm: Int) {
                val parsedId = try {
                    val s = String(serviceSpecificInfo)
                    val json = org.json.JSONObject(s)
                    json.optString("deviceId", json.optString("id", ""))
                } catch (_: Exception) { "" }
                val deviceId = if (parsedId.isNotEmpty()) parsedId else "peer_${System.currentTimeMillis()}"
                
                // Store PeerHandle mapping for later use in createDatapath
                peerHandleMap[deviceId] = peerHandle
                
                Log.i(TAG, "Service discovered within range: $deviceId, distance: ${distanceMm}mm")
                sendEvent("discoveryUpdate", mapOf<String, Any>(
                    "deviceId" to deviceId,
                    "peerId" to deviceId,
                    "serviceInfo" to String(serviceSpecificInfo),
                    "deviceName" to "Wi-Fi Aware Device (Close)",
                    "deviceType" to "android",
                    "discoveryMethod" to "wifi_aware",
                    "rssi" to -30,
                    "distanceMm" to distanceMm,
                    "metadata" to mapOf(
                        "deviceType" to "android",
                        "discoveryMethod" to "wifi_aware",
                        "peerHandle" to peerHandle.hashCode(),
                        "serviceInfo" to String(serviceSpecificInfo),
                        "distanceMm" to distanceMm
                    )
                ))
            }
            
            override fun onSessionConfigUpdated() {
                Log.i(TAG, "Subscribe session config updated")
            }
            
            override fun onSessionConfigFailed() {
                Log.e(TAG, "Subscribe session config failed")
                sendEvent("discoveryUpdate", mapOf<String, Any>("error" to "config_failed"))
            }
            
            override fun onSessionTerminated() {
                Log.i(TAG, "Subscribe session terminated")
                sendEvent("discoveryUpdate", mapOf<String, Any>("status" to "terminated"))
            }
            
            override fun onMessageReceived(peerHandle: PeerHandle, message: ByteArray) {
                val text = try { String(message) } catch (e: Exception) { "" }
                val deviceId = peerHandleMap.entries.firstOrNull { it.value == peerHandle }?.key ?: "device_${peerHandle.hashCode()}"
                try {
                    val json = org.json.JSONObject(text)
                    val port = json.optInt("port", -1)
                    val host = json.optString("host", null)
                    if (!host.isNullOrEmpty() && port > 0) {
                        activeConnections.entries.firstOrNull { it.value.peerId == deviceId }?.key?.let { token ->
                            negotiatedPorts[token] = port
                            activeConnections[token]?.let { c ->
                                activeConnections[token] = c.copy(host = host, port = port)
                            }
                            // ACK
                            try { subscribeSession?.sendMessage(peerHandle, 0, "{\"ack\":true}".toByteArray()) } catch (_: Exception) {}
                            Log.i(TAG, "Received host/port $host:$port for $token (subscriber)")
                            // If network already available, connect now
                            activeConnections[token]?.network?.let { net ->
                                createClientSocketAndConnect(token, net, host, port)
                            }
                        }
                    } else if (text.contains("\"ack\"")) {
                        val pending = activeConnections.entries.firstOrNull { it.value.peerId == deviceId && negotiationAck[it.key] == false }
                        if (pending != null) negotiationAck[pending.key] = true
                        Log.i(TAG, "Received ACK from peer (subscriber view)")
                    }
                } catch (_: Exception) {
                    Log.w(TAG, "Non-JSON negotiation message ignored: $text")
                }
            }
        }
    }
    
    private fun createNetworkCallback(connectionToken: String): ConnectivityManager.NetworkCallback {
        return object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Store the network in the connection info (no global network)
                activeConnections[connectionToken]?.let { connection ->
                    activeConnections[connectionToken] = connection.copy(
                        isConnected = true,
                        network = network
                    )
                }
                Log.i(TAG, "Network available for connection: $connectionToken")
                val infoNow = activeConnections[connectionToken]
                if (infoNow != null) {
                    sendEvent("connectionEstablished", mapOf<String, Any>(
                        "deviceId" to infoNow.peerId,
                        "connectionToken" to connectionToken,
                        "connectionMethod" to "wifi_aware"
                    ))
                } else {
                    sendEvent("discoveryUpdate", mapOf<String, Any>(
                        "connectionToken" to connectionToken,
                        "status" to "connected"
                    ))
                }
                
                // Decide server/client based on role and negotiated port
                val info = activeConnections[connectionToken]
                if (info?.isServer == true || info?.listeningPort != null) {
                    createServerSocketAndListen(connectionToken, network)
                } else {
                    val port = negotiatedPorts[connectionToken]
                    val host = info?.host
                    if (port != null && port > 0 && !host.isNullOrEmpty()) {
                        createClientSocketAndConnect(connectionToken, network, host, port)
                    } else {
                        Log.i(TAG, "Negotiated port not yet available for $connectionToken")
                    }
                }
            }
            
            override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
                // Update only if this callback's network matches the connection's network
                val conn = activeConnections[connectionToken]
                if (conn?.network == network) {
                    // Extract IPv6 address from link properties (Wi-Fi Aware uses IPv6)
                    val ipv6Address = linkProperties.linkAddresses
                        .firstOrNull { !it.address.isLoopbackAddress && it.address is java.net.Inet6Address }
                        ?.address?.hostAddress
                    
                    if (ipv6Address != null) {
                        activeConnections[connectionToken]?.let { connection ->
                            activeConnections[connectionToken] = connection.copy(
                                host = ipv6Address,
                                port = connection.listeningPort ?: 8080
                            )
                        }
                        
                        Log.i(TAG, "Link properties changed - IPv6: $ipv6Address for connection: $connectionToken")
                        // Do not emit discoveryUpdate:ready; rely on connectionReady only
                    }
                }
            }
            
            override fun onLost(network: Network) {
                val conn = activeConnections[connectionToken]
                if (conn?.network == network) {
                    activeConnections[connectionToken]?.let { connection ->
                        activeConnections[connectionToken] = connection.copy(
                            isConnected = false,
                            host = null,
                            port = null,
                            network = null
                        )
                    }
                    Log.i(TAG, "Network lost for connection: $connectionToken")
                    val infoNow = activeConnections[connectionToken]
                    if (infoNow != null) {
                        sendEvent("connectionLost", mapOf<String, Any>(
                            "deviceId" to infoNow.peerId,
                            "connectionToken" to connectionToken,
                            "connectionMethod" to "wifi_aware"
                        ))
                    } else {
                        sendEvent("discoveryUpdate", mapOf<String, Any>(
                            "connectionToken" to connectionToken,
                            "status" to "disconnected"
                        ))
                    }
                    
                    // Close connection and clean up
                    closeConnection(connectionToken)
                }
            }
        }
    }
    
    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        try {
            eventSink?.success(mapOf(
                "type" to eventType,
                "service" to "discovery",
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send event: $eventType", e)
        }
    }

    private fun validateFrameLength(length: Int): Boolean {
        return length > 0 && length <= MAX_FRAME_BYTES
    }
    
    /**
     * Calculate throughput for audit logging
     */
    private fun calculateThroughput(connectionToken: String, bytes: Int): Double {
        val currentTime = System.currentTimeMillis()
        val startTime = transferStartTimes.getOrPut(connectionToken) { currentTime }
        val totalBytes = transferByteCounts.getOrPut(connectionToken) { 0L } + bytes
        transferByteCounts[connectionToken] = totalBytes
        
        val duration = currentTime - startTime
        return if (duration > 0) {
            (totalBytes * 1000.0) / (duration * 1024.0) // KB/s
        } else {
            0.0
        }
    }
    
    /**
     * Get audit metrics for a connection
     */
    fun getAuditMetrics(connectionToken: String): Map<String, Any> {
        return if (AuditLogger.AUDIT_MODE) {
            auditLogger.getAuditLog(connectionToken)
        } else {
            emptyMap()
        }
    }

    /**
     * Dispose of Wi-Fi Aware resources and cancel coroutines.
     */
    fun dispose() {
        try {
            scope.cancel()
            // Close all streams and sockets
            outputStreams.values.forEach { try { it.close() } catch (_: Exception) {} }
            inputStreams.values.forEach { try { it.close() } catch (_: Exception) {} }
            serverSockets.values.forEach { try { it.close() } catch (_: Exception) {} }
            clientSockets.values.forEach { try { it.close() } catch (_: Exception) {} }
            // Unregister network callbacks
            try {
                networkCallbacks.values.forEach { cb -> try { connectivityManager?.unregisterNetworkCallback(cb) } catch (_: Exception) {} }
            } catch (_: Exception) {}
            activeConnections.clear()
            peerHandleMap.clear()
            connectionPeerHandles.clear()
            serverSockets.clear()
            clientSockets.clear()
            outputStreams.clear()
            inputStreams.clear()
            networkCallbacks.clear()
            negotiatedPorts.clear()
            encryptionKeys.clear()
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing WifiAwareManagerWrapper: ${e.message}")
        }
    }

    /**
     * Compatibility helper: attempt to return a DataPathInfo when a connection for the given peerId
     * has an established host/port. Returns null if not available yet.
     */
    fun createDataPath(peerId: String, port: Int): DataPathInfo? {
        // Try to find an active connection matching the peerId
        val entry = activeConnections.entries.firstOrNull { it.value.peerId == peerId }?.value
        if (entry != null) {
            val host = entry.host
            val p = entry.port ?: entry.listeningPort
            if (!host.isNullOrEmpty() && p != null) {
                return DataPathInfo(peerIpAddress = host, port = p)
            }
        }
        return null
    }
}