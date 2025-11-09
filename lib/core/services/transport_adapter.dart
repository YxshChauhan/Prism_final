import 'dart:typed_data';

/// Interface for transport operations used by AirLinkProtocol
/// This allows for dependency injection and easier testing
abstract class TransportAdapter {
  /// Start BLE file transfer
  Future<bool> startBleFileTransfer(String connectionToken, String filePath, String transferId);
  
  /// Start transfer using Wi-Fi Aware or MultipeerConnectivity
  Future<bool> startTransfer(String transferId, String filePath, int fileSize, String remoteDeviceId, String method);
  
  /// Get transfer progress
  Future<Map<String, dynamic>> getTransferProgress(String transferId);
  
  /// Pause transfer
  Future<bool> pauseTransfer(String transferId);
  
  /// Cancel transfer
  Future<bool> cancelTransfer(String transferId);
  
  /// Resume transfer
  Future<bool> resumeTransfer(String transferId);
  
  /// Close connection
  Future<void> closeConnection(String connectionToken);
  
  /// Send Wi-Fi Aware data
  Future<void> sendWifiAwareData(String connectionToken, Uint8List data);
  
  /// Get session key (for testing)
  String? getSessionKey();
  
  /// Encrypt data (for testing)
  Future<Uint8List> encryptData(Uint8List data);
  
  /// Decrypt data (for testing)
  Future<Uint8List> decryptData(Uint8List data);
  
  /// Derive key (for testing)
  Future<Uint8List> deriveKey(Uint8List inputKeyMaterial, Uint8List salt, Uint8List info);
  
  /// Send chunk (for testing)
  Future<void> sendChunk({
    required int transferId,
    required int chunkIndex,
    required Uint8List data,
    required bool isLastChunk,
  });
  
  /// Receive chunk (for testing)
  Future<Uint8List> receiveChunk({
    required int transferId,
    required int chunkIndex,
    required int expectedSize,
  });
  
  /// Resume transfer (for testing)
  Future<void> resumeTransferTest({
    required int transferId,
    required int resumeOffset,
  });
}

/// Default implementation using AirLinkPlugin
class DefaultTransportAdapter implements TransportAdapter {
  @override
  Future<bool> startBleFileTransfer(String connectionToken, String filePath, String transferId) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
    return true;
  }
  
  @override
  Future<bool> startTransfer(String transferId, String filePath, int fileSize, String remoteDeviceId, String method) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
    return true;
  }
  
  @override
  Future<Map<String, dynamic>> getTransferProgress(String transferId) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
    return {
      'bytesTransferred': 0,
      'status': 'unknown',
    };
  }
  
  @override
  Future<bool> pauseTransfer(String transferId) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
    return true;
  }
  
  @override
  Future<bool> cancelTransfer(String transferId) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
    return true;
  }
  
  @override
  Future<bool> resumeTransfer(String transferId) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
    return true;
  }
  
  @override
  Future<void> closeConnection(String connectionToken) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
  }
  
  @override
  Future<void> sendWifiAwareData(String connectionToken, Uint8List data) async {
    // This would call the actual AirLinkPlugin method
    // For now, return a mock implementation
  }
  
  @override
  String? getSessionKey() => null;
  
  @override
  Future<Uint8List> encryptData(Uint8List data) async {
    // Mock encryption
    return Uint8List.fromList('encrypted_${data.length}'.codeUnits);
  }
  
  @override
  Future<Uint8List> decryptData(Uint8List data) async {
    // Mock decryption
    return Uint8List.fromList('Hello World'.codeUnits);
  }
  
  @override
  Future<Uint8List> deriveKey(Uint8List inputKeyMaterial, Uint8List salt, Uint8List info) async {
    // Mock key derivation
    return Uint8List(32);
  }
  
  @override
  Future<void> sendChunk({
    required int transferId,
    required int chunkIndex,
    required Uint8List data,
    required bool isLastChunk,
  }) async {
    // Mock chunk sending
  }
  
  @override
  Future<Uint8List> receiveChunk({
    required int transferId,
    required int chunkIndex,
    required int expectedSize,
  }) async {
    // Mock chunk receiving
    return Uint8List(expectedSize);
  }
  
  @override
  Future<void> resumeTransferTest({
    required int transferId,
    required int resumeOffset,
  }) async {
    // Mock transfer resume
  }
}
