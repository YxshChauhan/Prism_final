import 'package:flutter/services.dart';

class AirLinkPlugin {
  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final EventChannel _wifiAwareDataChannel;
  
  // Default constructor for backwards compatibility
  AirLinkPlugin({
    MethodChannel? channel,
    EventChannel? eventChannel,
    EventChannel? wifiAwareDataChannel,
  }) : _channel = channel ?? const MethodChannel('airlink/core'),
       _eventChannel = eventChannel ?? const EventChannel('airlink/events'),
       _wifiAwareDataChannel = wifiAwareDataChannel ?? const EventChannel('airlink/wifi_aware_data');
  
  // Static instance for backwards compatibility
  static AirLinkPlugin? _instance;
  static AirLinkPlugin get instance => _instance ??= AirLinkPlugin();
  
  /// Initialize the plugin with injected channels
  static void initializeWithChannels({
    required MethodChannel channel,
    required EventChannel eventChannel,
    required EventChannel wifiAwareDataChannel,
  }) {
    _instance = AirLinkPlugin(
      channel: channel,
      eventChannel: eventChannel,
      wifiAwareDataChannel: wifiAwareDataChannel,
    );
  }
  
  // Static methods delegate to instance for backwards compatibility
  static MethodChannel get _staticChannel => instance._channel;
  static EventChannel get _staticEventChannel => instance._eventChannel;
  static EventChannel get _staticWifiAwareDataChannel => instance._wifiAwareDataChannel;
  
  /// Initialize the AirLink plugin
  static Future<String> initialize() async {
    try {
      final String result = await _staticChannel.invokeMethod('initialize');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to initialize AirLink: ${e.message}');
    }
  }
  
  /// Start advertising this device
  static Future<String> startAdvertising() async {
    try {
      final String result = await _staticChannel.invokeMethod('startAdvertising');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start advertising: ${e.message}');
    }
  }
  
  /// Stop advertising this device
  static Future<String> stopAdvertising() async {
    try {
      final String result = await _staticChannel.invokeMethod('stopAdvertising');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop advertising: ${e.message}');
    }
  }
  
  /// Start discovering nearby devices
  static Future<bool> startDiscovery() async {
    try {
      final bool result = await _staticChannel.invokeMethod('startDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start discovery: ${e.message}');
    }
  }

  /// Start BLE-only discovery
  static Future<bool> startBleDiscovery() async {
    try {
      final bool result = await _staticChannel.invokeMethod('startBleDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start BLE discovery: ${e.message}');
    }
  }

  /// Stop BLE-only discovery
  static Future<bool> stopBleDiscovery() async {
    try {
      final bool result = await _staticChannel.invokeMethod('stopBleDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop BLE discovery: ${e.message}');
    }
  }

  /// Start Wi‑Fi Aware-only discovery
  static Future<bool> startWifiAwareDiscovery() async {
    try {
      final bool result = await _staticChannel.invokeMethod('startWifiAwareDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start Wi‑Fi Aware discovery: ${e.message}');
    }
  }

  /// Stop Wi‑Fi Aware-only discovery
  static Future<bool> stopWifiAwareDiscovery() async {
    try {
      final bool result = await _staticChannel.invokeMethod('stopWifiAwareDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop Wi‑Fi Aware discovery: ${e.message}');
    }
  }
  
  /// Stop discovering devices
  static Future<bool> stopDiscovery() async {
    try {
      final bool result = await _staticChannel.invokeMethod('stopDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop discovery: ${e.message}');
    }
  }
  
  /// Check if Wi-Fi Aware is supported (Android only)
  static Future<bool> isWifiAwareSupported() async {
    try {
      final bool result = await _staticChannel.invokeMethod('isWifiAwareSupported');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to check Wi-Fi Aware support: ${e.message}');
    }
  }
  
  /// Check if BLE is supported
  static Future<bool> isBLESupported() async {
    try {
      final bool result = await _staticChannel.invokeMethod('isBLESupported');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to check BLE support: ${e.message}');
    }
  }
  
  /// Start network discovery (iOS only)
  static Future<String> startNetworkDiscovery() async {
    try {
      final String result = await _staticChannel.invokeMethod('startNetworkDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start network discovery: ${e.message}');
    }
  }
  
  /// Stop network discovery (iOS only)
  static Future<String> stopNetworkDiscovery() async {
    try {
      final String result = await _staticChannel.invokeMethod('stopNetworkDiscovery');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop network discovery: ${e.message}');
    }
  }
  
  /// Set up method call handler for receiving callbacks
  static void setMethodCallHandler(Future<dynamic> Function(MethodCall call) handler) {
    _staticChannel.setMethodCallHandler(handler);
  }
  
  /// Set up event stream for receiving events
  static Stream<dynamic> get eventStream => _staticEventChannel.receiveBroadcastStream();

  /// Wi‑Fi Aware data stream (emits maps with {connectionToken, bytes})
  static Stream<Map<String, dynamic>> get wifiAwareDataStream =>
      _staticWifiAwareDataChannel.receiveBroadcastStream().map((event) {
        final map = Map<dynamic, dynamic>.from(event as Map);
        return map.map((k, v) => MapEntry(k.toString(), v));
      });

  // === CONNECTION MANAGEMENT ===
  
  /// Connect to a specific peer (Wi-Fi Aware)
  static Future<String> connectToPeer(String peerId) async {
    try {
      final String result = await _staticChannel.invokeMethod('connectToPeer', {'peerId': peerId});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to connect to peer: ${e.message}');
    }
  }
  
  /// Create datapath for connection (Wi-Fi Aware) by peerId
  static Future<Map<String, dynamic>> createDatapath(String peerId) async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('createDatapath', {'peerId': peerId});
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to create datapath: ${e.message}');
    }
  }
  
  /// Connect to device (native BLE)
  static Future<String> connectToDevice(String deviceAddress) async {
    try {
      final String result = await _staticChannel.invokeMethod('connectToDevice', {'deviceAddress': deviceAddress});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to connect to device: ${e.message}');
    }
  }
  
  /// Close connection
  static Future<bool> closeConnection(String connectionToken) async {
    try {
      final bool result = await _staticChannel.invokeMethod('closeConnection', {'connectionToken': connectionToken});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to close connection: ${e.message}');
    }
  }
  
  /// Get connection info
  static Future<Map<String, dynamic>> getConnectionInfo(String connectionToken) async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('getConnectionInfo', {'connectionToken': connectionToken});
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get connection info: ${e.message}');
    }
  }

  // === FILE TRANSFER ===
  
  /// Start file transfer
  static Future<bool> startTransfer(String transferId, String filePath, int fileSize, String targetDeviceId, String connectionMethod) async {
    try {
      final bool result = await _staticChannel.invokeMethod('startTransfer', {
        'transferId': transferId,
        'filePath': filePath,
        'fileSize': fileSize,
        'targetDeviceId': targetDeviceId,
        'connectionMethod': connectionMethod,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start transfer: ${e.message}');
    }
  }
  
  /// Pause transfer
  static Future<bool> pauseTransfer(String transferId) async {
    try {
      final bool result = await _staticChannel.invokeMethod('pauseTransfer', {'transferId': transferId});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to pause transfer: ${e.message}');
    }
  }
  
  /// Resume transfer
  static Future<bool> resumeTransfer(String transferId) async {
    try {
      final bool result = await _staticChannel.invokeMethod('resumeTransfer', {'transferId': transferId});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to resume transfer: ${e.message}');
    }
  }
  
  /// Cancel transfer
  static Future<bool> cancelTransfer(String transferId) async {
    try {
      final bool result = await _staticChannel.invokeMethod('cancelTransfer', {'transferId': transferId});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to cancel transfer: ${e.message}');
    }
  }
  
  /// Get transfer progress
  static Future<Map<String, dynamic>> getTransferProgress(String transferId) async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('getTransferProgress', {'transferId': transferId});
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get transfer progress: ${e.message}');
    }
  }

  // === CHUNK-LEVEL OPERATIONS ===
  
  /// Send chunk data
  static Future<bool> sendChunk(String connectionToken, List<int> chunkData, int chunkIndex, int totalChunks) async {
    try {
      final bool result = await _staticChannel.invokeMethod('sendChunk', {
        'connectionToken': connectionToken,
        'chunkData': chunkData,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to send chunk: ${e.message}');
    }
  }
  
  /// Receive chunk data
  static Future<List<int>?> receiveChunk(String connectionToken) async {
    try {
      final List<dynamic>? result = await _staticChannel.invokeMethod('receiveChunk', {'connectionToken': connectionToken});
      return result?.cast<int>();
    } on PlatformException catch (e) {
      throw Exception('Failed to receive chunk: ${e.message}');
    }
  }
  
  /// Start file transfer service
  static Future<bool> startTransferService(String transferId) async {
    try {
      final bool result = await _staticChannel.invokeMethod('startTransferService', {'transferId': transferId});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start transfer service: ${e.message}');
    }
  }

  // === BLE SPECIFIC ===
  
  /// Start BLE file transfer
  static Future<bool> startBleFileTransfer(String connectionToken, String filePath, String transferId) async {
    try {
      final bool result = await _staticChannel.invokeMethod('startBleFileTransfer', {
        'connectionToken': connectionToken,
        'filePath': filePath,
        'transferId': transferId,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start BLE file transfer: ${e.message}');
    }
  }
  
  /// Start receiving BLE file
  static Future<bool> startReceivingBleFile(String connectionToken, String transferId, String savePath) async {
    try {
      final bool result = await _staticChannel.invokeMethod('startReceivingBleFile', {
        'connectionToken': connectionToken,
        'transferId': transferId,
        'savePath': savePath,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to start receiving BLE file: ${e.message}');
    }
  }
  
  /// Get BLE transfer progress
  static Future<Map<String, dynamic>> getBleTransferProgress(String transferId) async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('getBleTransferProgress', {'transferId': transferId});
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get BLE transfer progress: ${e.message}');
    }
  }

  /// Get transfer progress event stream
  static Stream<Map<String, dynamic>> getTransferProgressStream(String transferId) {
    return _staticEventChannel.receiveBroadcastStream({
      'type': 'transfer_progress',
      'transferId': transferId,
    }).map((event) => Map<String, dynamic>.from(event));
  }
  
  /// Cancel BLE file transfer
  static Future<bool> cancelBleFileTransfer(String transferId) async {
    try {
      final bool result = await _staticChannel.invokeMethod('cancelBleFileTransfer', {'transferId': transferId});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to cancel BLE file transfer: ${e.message}');
    }
  }

  /// Set BLE encryption key (AES-GCM)
  static Future<bool> setBleEncryptionKey(List<int> key) async {
    try {
      if (_isWeakKey(key)) {
        throw Exception('Invalid BLE encryption key: weak or uniform bytes');
      }
      final bool result = await _staticChannel.invokeMethod('setBleEncryptionKey', {
        'key': key,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to set BLE encryption key: ${e.message}');
    }
  }

  // === WI-FI AWARE SPECIFIC ===
  
  /// Send data over Wi-Fi Aware
  static Future<bool> sendWifiAwareData(String connectionToken, List<int> data) async {
    try {
      final bool result = await _staticChannel.invokeMethod('sendWifiAwareData', {
        'connectionToken': connectionToken,
        'data': data,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to send Wi-Fi Aware data: ${e.message}');
    }
  }
  
  /// Start Wi‑Fi Aware native receive that writes files to savePath
  static Future<void> startWifiAwareReceive(String connectionToken, String transferId, String savePath) async {
    try {
      await _staticChannel.invokeMethod('startWifiAwareReceive', {
        'connectionToken': connectionToken,
        'transferId': transferId,
        'savePath': savePath,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to start Wi‑Fi Aware receive: ${e.message}');
    }
  }

  /// Set native encryption key for a connection (AES-GCM)
  static Future<bool> setEncryptionKey(String connectionToken, List<int> key) async {
    try {
      if (_isWeakKey(key)) {
        throw Exception('Invalid encryption key: weak or uniform bytes');
      }
      final bool result = await _staticChannel.invokeMethod('setEncryptionKey', {
        'connectionToken': connectionToken,
        'key': key,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to set encryption key: ${e.message}');
    }
  }

  /// Verify that native layer applied the encryption key by encrypting a test payload
  static Future<Map<String, dynamic>> verifyEncryptionKey(String connectionToken, List<int> testPayload) async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('verifyEncryptionKey', {
        'connectionToken': connectionToken,
        'testPayload': testPayload,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to verify encryption key: ${e.message}');
    }
  }

  // === AUDIT MODE CONTROL ===
  
  /// Enable audit logging in native layers
  static Future<bool> enableAuditMode() async {
    try {
      final bool result = await _staticChannel.invokeMethod('enableAuditMode');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to enable audit mode: ${e.message}');
    }
  }
  
  /// Disable audit logging in native layers
  static Future<bool> disableAuditMode() async {
    try {
      final bool result = await _staticChannel.invokeMethod('disableAuditMode');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to disable audit mode: ${e.message}');
    }
  }
  
  /// Get audit metrics for a transfer
  static Future<Map<String, dynamic>> getAuditMetrics(String transferId) async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod(
        'getAuditMetrics',
        {'transferId': transferId}
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get audit metrics: ${e.message}');
    }
  }
  
  /// Export all audit logs to file
  static Future<bool> exportAuditLogs(String outputPath) async {
    try {
      final bool result = await _staticChannel.invokeMethod(
        'exportAuditLogs',
        {'outputPath': outputPath}
      );
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to export audit logs: ${e.message}');
    }
  }

  static bool _isWeakKey(List<int> key) {
    if (key.isEmpty) return true;
    final int first = key.first;
    bool allSame = true;
    for (int i = 1; i < key.length; i++) {
      if (key[i] != first) { allSame = false; break; }
    }
    if (allSame) return true;
    bool allZero = true;
    for (final b in key) { if (b != 0) { allZero = false; break; } }
    return allZero;
  }

  // === AUDIT EVIDENCE COLLECTION ===

  /// Get storage status (available/total bytes)
  static Future<Map<String, dynamic>> getStorageStatus() async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('getStorageStatus');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get storage status: ${e.message}');
    }
  }

  /// Get device capabilities (Wi-Fi Aware, BLE support/enabled)
  static Future<Map<String, dynamic>> getCapabilities() async {
    try {
      final Map<dynamic, dynamic> result = await _staticChannel.invokeMethod('getCapabilities');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get capabilities: ${e.message}');
    }
  }

  /// Capture screenshot and save to path
  static Future<bool> captureScreenshot(String path) async {
    try {
      final bool result = await _staticChannel.invokeMethod('captureScreenshot', {'path': path});
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to capture screenshot: ${e.message}');
    }
  }

  /// Export device logs to destination directory
  static Future<List<String>> exportDeviceLogs(String destDir) async {
    try {
      final List<dynamic> result = await _staticChannel.invokeMethod('exportDeviceLogs', {'destDir': destDir});
      return result.cast<String>();
    } on PlatformException catch (e) {
      throw Exception('Failed to export device logs: ${e.message}');
    }
  }

  /// List transferred files with their paths
  static Future<List<Map<String, dynamic>>> listTransferredFiles() async {
    try {
      final List<dynamic> result = await _staticChannel.invokeMethod('listTransferredFiles');
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to list transferred files: ${e.message}');
    }
  }
}
