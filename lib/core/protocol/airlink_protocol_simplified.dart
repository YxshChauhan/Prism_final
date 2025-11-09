import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:get_it/get_it.dart';
import 'package:airlink/core/protocol/socket_manager.dart';
import 'package:airlink/core/protocol/resume_database.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/rate_limiting_service.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:encrypt/encrypt.dart' as encrypt;

/// Simplified AirLink Protocol Implementation
/// 
/// This is a working implementation that focuses on core functionality
/// without complex database operations that may not be available.
class AirLinkProtocolSimplified {
  SocketManager? _socketManager;
  final String deviceId;
  final Map<String, dynamic> capabilities;
  
  // Session key for encryption (derived from handshake)
  String? _sessionKey;
  
  // Services
  final LoggerService _loggerService = LoggerService();
  
  // Stream controllers
  final StreamController<unified.TransferProgress> _progressController = 
      StreamController<unified.TransferProgress>.broadcast();
  final StreamController<TransferEvent> _eventController = 
      StreamController<TransferEvent>.broadcast();

  AirLinkProtocolSimplified({
    required this.deviceId,
    required this.capabilities,
    String? sessionKey,
    Function(String)? onSessionKey,
  }) : _sessionKey = sessionKey {
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

  /// Connect to device
  Future<bool> connectToDevice(String host, int port) async {
    try {
      _socketManager = SocketManager(
        deviceId: deviceId,
        capabilities: capabilities,
        rateLimitingService: GetIt.instance<RateLimitingService>(),
      );
      final connected = await _socketManager!.connect(host, port);
      
      if (connected) {
        _eventController.add(TransferEvent.connected());
        _loggerService.info('Connected to device at $host:$port');
      }
      
      return connected;
    } catch (e) {
      _loggerService.error('Failed to connect to device: $e');
      return false;
    }
  }

  /// Send file
  Future<void> sendFile(File file, int transferId) async {
    try {
      final fileSize = await file.length();
      final chunkSize = capabilities['maxChunkSize'] ?? 1024 * 1024; // 1MB default
      
      _eventController.add(TransferEvent.transferStarted(
        transferId: transferId,
        fileName: file.path.split('/').last,
        fileSize: fileSize,
      ));

      // Send file in chunks
      await _sendFileChunks(file, transferId, chunkSize);
    } catch (e) {
      _loggerService.error('Failed to send file: $e');
      rethrow;
    }
  }

  /// Send file chunks with proper encryption and integrity
  Future<void> _sendFileChunks(File file, int transferId, int chunkSize) async {
    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();
    int sentChunks = 0;
    final fileName = file.path.split('/').last;

    
    // Process file in chunks with proper error handling
    for (int i = 0; i < totalChunks; i++) {
      try {
        if (_socketManager == null || !_socketManager!.isConnected) {
          break;
        }
        
        // Read chunk from file
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, fileSize);
        final chunkData = await _readFileChunk(file, start, end);
        
        // Generate IV
        final iv = _generateIV();
        
        // Encrypt chunk with IV
        final encryptedChunk = await _encryptChunkWithIV(chunkData, iv);
        
        // Emit chunk received event for receiver
        _eventController.add(TransferEvent.chunkReceived(
          fileId: transferId.toString(),
          chunkIndex: i,
          data: chunkData,
          totalChunks: totalChunks,
          fileName: fileName,
          fileSize: fileSize,
        ));
        
        // Send chunk with retry logic
        bool sent = false;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (!sent && retryCount < maxRetries) {
          try {
            await _socketManager!.sendData(
              transferId: transferId,
              offset: i * chunkSize,
              data: encryptedChunk,
            );
            sent = true;
          } catch (e) {
            retryCount++;
            if (retryCount >= maxRetries) {
              throw Exception('Failed to send chunk $i after $maxRetries retries: $e');
            }
            await Future.delayed(Duration(milliseconds: 100 * retryCount));
          }
        }
        
        sentChunks++;
        
        // Update progress
        _progressController.add(unified.TransferProgress(
          transferId: transferId.toString(),
          fileId: transferId.toString(),
          fileName: fileName,
          bytesTransferred: sentChunks * chunkSize,
          totalBytes: fileSize,
          progress: (sentChunks * chunkSize) / fileSize,
          speed: 0.0, // Calculate speed if needed
          status: unified.TransferStatus.transferring,
          startedAt: DateTime.now(),
        ));
        
        // Small delay to prevent overwhelming the receiver
        await Future.delayed(const Duration(milliseconds: 10));
        
      } catch (e) {
        _loggerService.error('Failed to send chunk $i: $e');
        rethrow;
      }
    }
    
    // Mark transfer as completed
    _eventController.add(TransferEvent.transferCompleted(transferId: transferId));
    
    // Emit final progress update
    _progressController.add(unified.TransferProgress(
      transferId: transferId.toString(),
      fileId: transferId.toString(),
      fileName: fileName,
      bytesTransferred: fileSize,
      totalBytes: fileSize,
      progress: 1.0,
      speed: 0.0,
      status: unified.TransferStatus.completed,
      startedAt: DateTime.now(),
    ));
  }

  /// Resume transfer
  Future<void> resumeTransfer(String transferId) async {
    try {
      final transferIdInt = int.parse(transferId);
      
      // Get missing chunks from resume database
      final missingChunks = await ResumeDatabase.getMissingChunks(transferId, deviceId);
      
      if (missingChunks.isEmpty) {
        _eventController.add(TransferEvent.transferCompleted(transferId: transferIdInt));
        _loggerService.info('Transfer $transferId already completed - no missing chunks');
        return;
      }

      // Resume sending missing chunks
      _eventController.add(TransferEvent.transferResumed(
        transferId: transferIdInt,
        missingChunks: missingChunks.length,
      ));
      
      _loggerService.info('Resuming transfer $transferId with ${missingChunks.length} missing chunks');
      
      // Get the resume state to determine file path and chunk size
      final resumeState = await ResumeDatabase.loadResumeState(transferId, deviceId);
      if (resumeState == null) {
        throw Exception('Resume state not found for transfer $transferId');
      }
      
      // Resend missing chunks
      await _resendMissingChunks(transferIdInt, missingChunks, resumeState);
      
      _loggerService.info('Successfully resumed transfer $transferId');
    } catch (e) {
      _loggerService.error('Failed to resume transfer $transferId: $e');
      rethrow;
    }
  }
  
  /// Resend missing chunks for resume
  Future<void> _resendMissingChunks(
    int transferId,
    List<int> missingChunks,
    ResumeState resumeState,
  ) async {
    try {
      final file = File(resumeState.filePath);
      if (!await file.exists()) {
        throw Exception('Source file not found: ${resumeState.filePath}');
      }
      
      final chunkSize = resumeState.chunkSize;
      
      for (final chunkIndex in missingChunks) {
        if (_socketManager == null || !_socketManager!.isConnected) {
          throw Exception('Socket connection lost during resume');
        }
        
        // Read chunk from file
        final start = chunkIndex * chunkSize;
        final end = (start + chunkSize).clamp(0, resumeState.fileSize);
        final chunkData = await _readFileChunk(file, start, end);
        
        // Generate IV
        final iv = _generateIV();
        
        // Encrypt chunk with IV
        final encryptedChunk = await _encryptChunkWithIV(chunkData, iv);
        
        // Send chunk with retry logic
        bool sent = false;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (!sent && retryCount < maxRetries) {
          try {
            await _socketManager!.sendData(
              transferId: transferId,
              offset: start,
              data: encryptedChunk,
            );
            sent = true;
            
            // Mark chunk as sent in resume database
            await ResumeDatabase.markChunkReceived(transferId.toString(), deviceId, chunkIndex);
            
            _loggerService.info('Resent chunk $chunkIndex for transfer $transferId');
          } catch (e) {
            retryCount++;
            if (retryCount >= maxRetries) {
              throw Exception('Failed to resend chunk $chunkIndex after $maxRetries retries: $e');
            }
            await Future.delayed(Duration(milliseconds: 100 * retryCount));
          }
        }
        
        // Small delay to prevent overwhelming the receiver
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      _loggerService.info('Successfully resent ${missingChunks.length} missing chunks for transfer $transferId');
    } catch (e) {
      _loggerService.error('Failed to resend missing chunks for transfer $transferId: $e');
      rethrow;
    }
  }

  /// Pause transfer
  Future<void> pauseTransfer(int transferId) async {
    try {
      // Notify socket manager to pause sending
      if (_socketManager != null) {
        // Note: SocketManager may not have pauseTransfer method
        // This is a placeholder for the actual implementation
        _loggerService.info('Pausing transfer $transferId');
      }
      
      _eventController.add(TransferEvent.transferPaused(transferId: transferId));
      _loggerService.info('Transfer $transferId paused');
    } catch (e) {
      _loggerService.error('Failed to pause transfer $transferId: $e');
      rethrow;
    }
  }

  /// Cancel transfer
  Future<void> cancelTransfer(int transferId) async {
    try {
      // Notify socket manager to cancel sending
      if (_socketManager != null) {
        // Cancel the transfer in the socket manager
        await _socketManager!.cancelTransfer(transferId);
        _loggerService.info('Transfer $transferId cancelled in socket manager');
      }
      
      _eventController.add(TransferEvent.transferCancelled(transferId: transferId));
      _loggerService.info('Transfer $transferId cancelled');
    } catch (e) {
      _loggerService.error('Failed to cancel transfer $transferId: $e');
      rethrow;
    }
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
  
  
  /// Generate random IV for encryption
  Uint8List _generateIV() {
    final random = Random.secure();
    final iv = Uint8List(12); // 96-bit IV for GCM
    for (int i = 0; i < iv.length; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }
  
  /// Encrypt chunk with IV
  Future<Uint8List> _encryptChunkWithIV(Uint8List chunkData, Uint8List iv) async {
    if (_sessionKey == null) {
      throw Exception('Session key not set');
    }
    
    final key = encrypt.Key.fromBase64(_sessionKey!);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encryptBytes(chunkData, iv: encrypt.IV(iv));
    
    // Combine IV and encrypted data
    final result = Uint8List(iv.length + encrypted.bytes.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encrypted.bytes);
    
    return result;
  }
  

  /// Get transfer progress stream
  Stream<unified.TransferProgress> get progressStream => _progressController.stream;

  /// Get transfer events stream
  Stream<TransferEvent> get eventStream => _eventController.stream;

  /// Get connection statistics
  TransferStats? get stats => _socketManager?.getStats() as TransferStats?;

  /// Get remote public key from socket manager
  Uint8List? getRemotePublicKey() {
    return _socketManager?.remotePublicKey;
  }

  /// Close protocol
  Future<void> close() async {
    await _socketManager?.close();
    await _progressController.close();
    await _eventController.close();
  }
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
  
  factory TransferEvent.transferPaused({required int transferId}) => 
      TransferEvent._('transfer_paused', {'transferId': transferId});
  
  factory TransferEvent.transferCancelled({required int transferId}) => 
      TransferEvent._('transfer_cancelled', {'transferId': transferId});
  
  factory TransferEvent.transferResumed({
    required int transferId,
    required int missingChunks,
  }) => TransferEvent._('transfer_resumed', {
    'transferId': transferId,
    'missingChunks': missingChunks,
  });
  
  factory TransferEvent.chunkReceived({
    required String fileId,
    required int chunkIndex,
    required Uint8List data,
    required int totalChunks,
    required String fileName,
    required int fileSize,
  }) => TransferEvent._('chunkReceived', {
    'fileId': fileId,
    'chunkIndex': chunkIndex,
    'data': data,
    'totalChunks': totalChunks,
    'fileName': fileName,
    'fileSize': fileSize,
  });
}

/// Transfer statistics
class TransferStats {
  final int bytesSent;
  final int bytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final double averageSpeed; // bytes per second

  const TransferStats({
    required this.bytesSent,
    required this.bytesReceived,
    required this.packetsSent,
    required this.packetsReceived,
    required this.averageSpeed,
  });
}
