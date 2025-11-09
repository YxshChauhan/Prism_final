import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:airlink/core/protocol/reliability.dart';
import 'package:airlink/core/protocol/resume_database.dart';
import 'package:airlink/core/protocol/protocol_constants.dart';
import 'package:airlink/core/constants/app_constants.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/transport_adapter.dart';
import 'package:crypto/crypto.dart' show sha256, Digest;


class AirLinkProtocol {
  final String deviceId;
  final Map<String, dynamic> capabilities;
  
  // Session key for encryption (derived from handshake)
  String? _sessionKey;
  
  // Negotiated chunk size
  int? _negotiatedChunkSize;
  
  // Connection info
  String? _connectionToken;
  String? _connectionMethod;
  
  // Services
  final LoggerService _loggerService = LoggerService();
  final TransportAdapter _transportAdapter;
  
  // Stream controllers
  final StreamController<ProtocolTransferProgress> _progressController = 
      StreamController<ProtocolTransferProgress>.broadcast();
  final StreamController<TransferEvent> _eventController = 
      StreamController<TransferEvent>.broadcast();
  
  // Transfer state
  final Map<String, Map<String, dynamic>> _activeTransfers = {};
  final Map<String, StreamSubscription> _progressSubscriptions = {};
  
  // Connection management for simultaneous transfers
  final Map<String, String> _connectionTokens = {}; // transferId -> token
  final Map<String, String> _connectionMethods = {}; // transferId -> method
  final Map<String, int> _negotiatedChunkSizes = {}; // transferId -> chunkSize
  
  // Transfer limits - using shared constant from AppConstants

  AirLinkProtocol({
    required this.deviceId,
    required this.capabilities,
    String? sessionKey,
    String? connectionToken,
    String? connectionMethod,
    Function(String)? onSessionKey,
    TransportAdapter? transportAdapter,
  }) : _sessionKey = sessionKey,
       _connectionToken = connectionToken,
       _connectionMethod = connectionMethod,
       _transportAdapter = transportAdapter ?? DefaultTransportAdapter() {
    if (onSessionKey != null) {
      _onSessionKey = onSessionKey;
    }
  }
  
  Function(String)? _onSessionKey;

  /// Set session key for encryption
  void setSessionKey(String sessionKey) {
    _sessionKey = sessionKey;
    _onSessionKey?.call(sessionKey);
  }
  
  // Global setConnectionInfo method removed - use setConnectionInfoForTransfer instead
  
  /// Set connection info for a specific transfer
  void setConnectionInfoForTransfer(String transferId, String connectionToken, String connectionMethod) {
    _connectionTokens[transferId] = connectionToken;
    _connectionMethods[transferId] = connectionMethod;
    _activeTransfers[transferId] = {'startedAt': DateTime.now()};
    
    // Negotiate chunk size for this specific transfer
    _negotiateChunkSizeForTransfer(transferId, connectionMethod);
  }
  
  /// Check if protocol can handle simultaneous transfers
  bool canHandleSimultaneousTransfers() {
    return _activeTransfers.length < AppConstants.maxConcurrentTransfers;
  }
  
  /// Get current active transfer count
  int get activeTransferCount => _activeTransfers.length;
  
  /// Check if a specific transfer is active
  bool isTransferActive(String transferId) {
    return _activeTransfers.containsKey(transferId);
  }
  
  /// Clean up completed transfer
  void cleanupTransfer(String transferId) {
    _activeTransfers.remove(transferId);
    _connectionTokens.remove(transferId);
    _connectionMethods.remove(transferId);
    _negotiatedChunkSizes.remove(transferId);
    _progressSubscriptions[transferId]?.cancel();
    _progressSubscriptions.remove(transferId);
  }
  
  /// Get transfer isolation info
  Map<String, dynamic> getTransferIsolation(String transferId) {
    return {
      'transferId': transferId,
      'connectionToken': _connectionTokens[transferId],
      'connectionMethod': _connectionMethods[transferId],
      'isActive': isTransferActive(transferId),
    };
  }

  /// Get remote public key from handshake (not applicable for native transport)
  Uint8List? getRemotePublicKey() {
    // Native transport handles encryption internally
    return null;
  }
  
  /// Get session key (for testing)
  String? getSessionKey() => _sessionKey;
  
  /// Encrypt data (for testing)
  Future<Uint8List> encryptData(Uint8List data) async {
    return await _transportAdapter.encryptData(data);
  }
  
  /// Decrypt data (for testing)
  Future<Uint8List> decryptData(Uint8List data) async {
    return await _transportAdapter.decryptData(data);
  }
  
  /// Derive key (for testing)
  Future<Uint8List> deriveKey(Uint8List inputKeyMaterial, Uint8List salt, Uint8List info) async {
    return await _transportAdapter.deriveKey(inputKeyMaterial, salt, info);
  }
  
  /// Send chunk (for testing)
  Future<void> sendChunk({
    required int transferId,
    required int chunkIndex,
    required Uint8List data,
    required bool isLastChunk,
  }) async {
    return await _transportAdapter.sendChunk(
      transferId: transferId,
      chunkIndex: chunkIndex,
      data: data,
      isLastChunk: isLastChunk,
    );
  }
  
  /// Receive chunk (for testing)
  Future<Uint8List> receiveChunk({
    required int transferId,
    required int chunkIndex,
    required int expectedSize,
  }) async {
    return await _transportAdapter.receiveChunk(
      transferId: transferId,
      chunkIndex: chunkIndex,
      expectedSize: expectedSize,
    );
  }
  
  /// Resume transfer (for testing)
  Future<void> resumeTransferTest({
    required int transferId,
    required int resumeOffset,
  }) async {
    return await _transportAdapter.resumeTransferTest(
      transferId: transferId,
      resumeOffset: resumeOffset,
    );
  }

  /// Initialize protocol
  Future<void> initialize() async {
    // Initialize resume database
    await ResumeDatabase.cleanupOldStates();
  }

  /// Start listening for incoming connections (handled by native transport)
  Future<void> startServer({int port = 0}) async {
    // Native transport handles server setup
    _eventController.add(TransferEvent.connected());
  }

  /// Connect to remote device (handled by native transport)
  Future<bool> connectToDevice(String host, int port) async {
    // Native transport handles connection
    if (_connectionToken != null) {
      _eventController.add(TransferEvent.connected());
      return true;
    }
    return false;
  }




  /// Send file to remote device using native transport
  Future<void> sendFile({
    required String filePath,
    required String remoteDeviceId,
    required int transferId,
  }) async {
    final transferIdStr = transferId.toString();
    
    // Check if we can handle another transfer
    if (!canHandleSimultaneousTransfers()) {
      throw Exception('Maximum concurrent transfers reached (${AppConstants.maxConcurrentTransfers})');
    }
    
    // Register transfer in _activeTransfers at start
    _activeTransfers[transferIdStr] = {'startedAt': DateTime.now()};
    
    try {
      // Get connection info for this transfer
      final connectionToken = _connectionTokens[transferIdStr] ?? _connectionToken;
      
      if (connectionToken == null) {
        throw Exception('Not connected to remote device');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileSize = await file.length();
      final chunkSize = getNegotiatedChunkSizeForTransfer(transferIdStr);

      // Initialize resume state (use local deviceId for resume keys)
      final resumeState = ResumeState.initial(
        transferId: transferIdStr,
        deviceId: deviceId,
        filePath: filePath,
        fileSize: fileSize,
        chunkSize: chunkSize,
      );

      await ResumeDatabase.saveResumeState(resumeState);

      // Start transfer
      _eventController.add(TransferEvent.transferStarted(
        transferId: transferId,
        fileName: filePath.split('/').last,
        fileSize: fileSize,
      ));

      // Use native transport to send file
      final method = _connectionMethods[transferIdStr] ?? _connectionMethod ?? 'wifi_aware';
      await _sendFileWithNativeTransport(file, transferId, chunkSize, remoteDeviceId, method);
      
      // Transfer completed successfully
      _eventController.add(TransferEvent.transferCompleted(transferId: transferId));
    } catch (e) {
      // Transfer failed
      _eventController.add(TransferEvent.chunkError(
        transferId: transferId,
        offset: 0,
        error: e.toString(),
      ));
      rethrow;
    } finally {
      // Always cleanup transfer on success or failure
      cleanupTransfer(transferIdStr);
    }
  }

  /// Send file using native transport
  Future<void> _sendFileWithNativeTransport(File file, int transferId, int chunkSize, String remoteDeviceId, String method) async {
    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();

    // Calculate and store expected file hash for integrity verification
    final expectedHash = await _calculateFileHash(file);
    
    // Store transfer metadata in resume database
    await ResumeDatabase.saveResumeState(ResumeState(
      transferId: transferId.toString(),
      deviceId: deviceId,
      filePath: file.path,
      fileSize: fileSize,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      receivedChunks: Uint8List((totalChunks + 7) ~/ 8),
      lastConfirmedOffset: 0,
      createdAt: DateTime.now(),
      expectedHash: expectedHash,
    ));
    
    // Start native transfer based on connection method
    bool success = false;
    if (method == 'ble') {
      success = await _transportAdapter.startBleFileTransfer(
        _connectionTokens[transferId.toString()] ?? _connectionToken!,
        file.path,
        transferId.toString(),
      );
    } else {
      // Use Wi-Fi Aware or MultipeerConnectivity
      success = await _transportAdapter.startTransfer(
        transferId.toString(),
        file.path,
        fileSize,
        remoteDeviceId,
        method,
      );
    }
    
    if (!success) {
      throw Exception('Failed to start native file transfer');
    }
    
    // Progress monitoring is handled at repository level to avoid duplication
    // (no-op here)
  }
  

  /// Resume interrupted transfer
  /// Supports both simplified (transferId/resumeOffset) and full resume flows.
  Future<void> resumeTransfer({
    Object? transferId,
    int? resumeOffset,
    String? deviceId,
    File? file,
    int? chunkSize,
  }) async {
    // Simplified native resume path used in tests
    if (transferId is int && resumeOffset != null) {
      await _transportAdapter.resumeTransfer(transferId.toString());
      _eventController.add(TransferEvent.transferResumed(
        transferId: transferId,
        missingChunks: 0,
      ));
      return;
    }

    // Full resume path using resume database
    if (transferId is String && deviceId != null && file != null && chunkSize != null) {
      final resumeState = await ResumeDatabase.loadResumeState(transferId, deviceId);
      if (resumeState == null) {
        throw Exception('No resume state found for transfer');
      }

      if (resumeState.isComplete) {
        _eventController.add(TransferEvent.transferCompleted(transferId: int.parse(transferId)));
        return;
      }

      final missingChunks = await ResumeDatabase.getMissingChunks(transferId, deviceId);
      if (missingChunks.isEmpty) {
        _eventController.add(TransferEvent.transferCompleted(transferId: int.parse(transferId)));
        return;
      }

      _eventController.add(TransferEvent.transferResumed(
        transferId: int.parse(transferId),
        missingChunks: missingChunks.length,
      ));

      for (final chunkIndex in missingChunks) {
        try {
          final int startOffset = chunkIndex * chunkSize;
          final int endOffsetExclusive = math.min(startOffset + chunkSize, await file.length());
          if (endOffsetExclusive <= startOffset) {
            continue;
          }
          final chunkData = await _readFileChunk(file, startOffset, endOffsetExclusive);
          if (chunkData.isNotEmpty) {
            if (_connectionToken != null) {
              await _transportAdapter.sendWifiAwareData(_connectionToken!, chunkData);
            }
            await ResumeDatabase.markChunkReceived(transferId, deviceId, chunkIndex);
          }
        } catch (e) {
          _loggerService.error('Failed to resend chunk $chunkIndex: $e');
        }
      }
      return;
    }

    throw Exception('Invalid resumeTransfer parameters');
  }

  /// Receive file (compatibility stub for tests)
  Future<void> receiveFile({
    required String filePath,
    required int transferId,
  }) async {
    // In native paths, receiving is initiated via platform; here we just acknowledge.
    _eventController.add(TransferEvent.transferStarted(
      transferId: transferId,
      fileName: filePath.split('/').last,
      fileSize: 0,
    ));
  }










  
  

  /// Get transfer progress stream
  Stream<ProtocolTransferProgress> get progressStream => _progressController.stream;

  /// Get transfer events stream
  Stream<TransferEvent> get eventStream => _eventController.stream;

  /// Check if connected
  bool get isConnected => _connectionToken != null;

  /// Get connection statistics (not applicable for native transport)
  TransferStats? get stats => null;
  
  
  /// Negotiate chunk size for a specific transfer
  void _negotiateChunkSizeForTransfer(String transferId, String connectionMethod) {
    // Get local preferred chunk size from capabilities
    final localChunkSize = capabilities['maxChunkSize'] ?? ProtocolConstants.defaultChunkSize;
    
    // For native transport, use local chunk size or default based on connection method
    int negotiatedSize = localChunkSize;
    
    if (connectionMethod == 'ble') {
      // BLE has smaller MTU, use smaller chunks
      negotiatedSize = math.min(localChunkSize, 244); // BLE characteristic limit
    } else if (connectionMethod == 'wifi_aware') {
      // Wi-Fi Aware can handle larger chunks
      negotiatedSize = math.max(localChunkSize, 1024 * 1024); // 1MB chunks
    }
    
    // Ensure chunk size is within valid bounds
    _negotiatedChunkSizes[transferId] = negotiatedSize.clamp(
      ProtocolConstants.minChunkSize,
      ProtocolConstants.maxChunkSize,
    );
    
    _loggerService.info('Negotiated chunk size for transfer $transferId: ${_negotiatedChunkSizes[transferId]} bytes for $connectionMethod');
  }
  
  /// Get negotiated chunk size
  int get negotiatedChunkSize => _negotiatedChunkSize ?? ProtocolConstants.defaultChunkSize;
  
  /// Get negotiated chunk size for a specific transfer
  int getNegotiatedChunkSizeForTransfer(String transferId) {
    return _negotiatedChunkSizes[transferId] ?? negotiatedChunkSize;
  }
  

  /// Close protocol
  /// Pause transfer using native transport
  Future<void> pauseTransfer(int transferId) async {
    try {
      _loggerService.info('Pausing transfer $transferId');
      
      final success = await _transportAdapter.pauseTransfer(transferId.toString());
      if (success) {
        _eventController.add(TransferEvent.transferPaused(transferId: transferId));
        _loggerService.info('Transfer $transferId paused');
      } else {
        throw Exception('Failed to pause transfer in native layer');
      }
    } catch (e) {
      _loggerService.error('Failed to pause transfer $transferId: $e');
      rethrow;
    }
  }
  
  /// Cancel transfer using native transport
  Future<void> cancelTransfer(int transferId) async {
    try {
      _loggerService.info('Cancelling transfer $transferId');
      
      final success = await _transportAdapter.cancelTransfer(transferId.toString());
      if (success) {
        // Clean up transfer data
        await ResumeDatabase.deleteTransferState(transferId.toString(), deviceId);
        
        _eventController.add(TransferEvent.transferCancelled(transferId: transferId));
        _loggerService.info('Transfer $transferId cancelled');
      } else {
        throw Exception('Failed to cancel transfer in native layer');
      }
    } catch (e) {
      _loggerService.error('Failed to cancel transfer $transferId: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    // Close native connection if we have one
    if (_connectionToken != null) {
      try {
        await _transportAdapter.closeConnection(_connectionToken!);
      } catch (e) {
        _loggerService.warning('Failed to close native connection: $e');
      }
    }
    
    // Close progress subscriptions
    for (final subscription in _progressSubscriptions.values) {
      await subscription.cancel();
    }
    _progressSubscriptions.clear();
    
    // Close stream controllers
    await _progressController.close();
    await _eventController.close();
  }
  
  /// Read a chunk from file at specified offset
  Future<Uint8List> _readFileChunk(File file, int start, int end) async {
    final randomAccessFile = await file.open();
    try {
      await randomAccessFile.setPosition(start);
      final chunk = await randomAccessFile.read(end - start);
      return chunk;
    } finally {
      await randomAccessFile.close();
    }
  }
  
  /// Calculate file hash for integrity verification (streaming, low memory)
  Future<String> _calculateFileHash(File file) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
  
  
  
  
}

/// Transfer progress model
class ProtocolTransferProgress {
  final int transferId;
  final double progress; // 0.0 to 1.0
  final int bytesTransferred;
  final int totalBytes;

  const ProtocolTransferProgress({
    required this.transferId,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
  });
}

/// Transfer event model
class TransferEvent {
  final String type;
  final Map<String, dynamic> data;

  const TransferEvent._(this.type, this.data);

  factory TransferEvent.connected() => const TransferEvent._('connected', {});
  
  factory TransferEvent.transferStarted({
    required int transferId,
    required String fileName,
    required int fileSize,
  }) => TransferEvent._('transfer_started', {
    'transferId': transferId,
    'fileName': fileName,
    'fileSize': fileSize,
  });

  factory TransferEvent.transferCompleted({required int transferId}) => 
      TransferEvent._('transfer_completed', {'transferId': transferId});

  factory TransferEvent.transferResumed({
    required int transferId,
    required int missingChunks,
  }) => TransferEvent._('transfer_resumed', {
    'transferId': transferId,
    'missingChunks': missingChunks,
  });

  factory TransferEvent.transferPaused({required int transferId}) => 
      TransferEvent._('transfer_paused', {'transferId': transferId});

  factory TransferEvent.transferCancelled({required int transferId}) => 
      TransferEvent._('transfer_cancelled', {'transferId': transferId});

  factory TransferEvent.chunkError({
    required int transferId,
    required int offset,
    required String error,
  }) => TransferEvent._('chunk_error', {
    'transferId': transferId,
    'offset': offset,
    'error': error,
  });
}
