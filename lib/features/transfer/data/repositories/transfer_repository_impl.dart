import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
// import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256;
import 'package:uuid/uuid.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/connection_service.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:airlink/core/services/error_handling_service.dart';
import 'package:airlink/core/services/performance_optimization_service.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';
import 'package:airlink/core/services/transfer_benchmark.dart';
import 'package:airlink/core/services/rate_limiting_service.dart';
import 'package:airlink/core/services/checksum_verification_service.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:airlink/core/security/secure_session.dart';
import 'package:airlink/core/security/key_manager.dart';
import 'package:airlink/core/protocol/airlink_protocol.dart';
import 'package:airlink/core/constants/app_constants.dart';
import 'package:injectable/injectable.dart';

// Event classes for protocol communication
class ChunkReceivedEvent {
  final String sessionId;
  final int chunkIndex;
  final List<int> data;
  final int totalChunks;
  final int totalBytes;
  
  ChunkReceivedEvent({
    required this.sessionId,
    required this.chunkIndex,
    required this.data,
    required this.totalChunks,
    required this.totalBytes,
  });
}

class TransferProgressEvent {
  final String sessionId;
  final int progress;
  final int bytesTransferred;
  final int totalBytes;
  
  TransferProgressEvent({
    required this.sessionId,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
  });
}

@Injectable(as: TransferRepository)
class TransferRepositoryImpl implements TransferRepository {
  
  
  final LoggerService _loggerService;
  final ConnectionService _connectionService;
  final ErrorHandlingService _errorHandlingService;
  final PerformanceOptimizationService _performanceService;
  final TransferBenchmarkingService _benchmarkingService;
  final ChecksumVerificationService _checksumService;
  final SecureSessionManager _secureSessionManager;
  final AirLinkProtocol _airLinkProtocol;
  final RateLimitingService _rateLimitingService;
  final Uuid _uuid = const Uuid();
  
  final List<unified.TransferSession> _activeTransfers = [];
  final List<unified.TransferSession> _transferHistory = [];
  final Map<String, StreamController<unified.TransferProgress>> _progressControllers = {};
  final Map<String, DateTime> _fileStartTimes = {}; // (sessionId,fileId) -> startedAt
  final Map<String, StreamController<TransferQueueProgress>> _queueControllers = {};
  final Map<String, String> _connectionTokens = {}; // sessionId -> connectionToken
  final Map<String, String> _connectionMethods = {}; // sessionId -> connectionMethod
  final Map<String, StreamSubscription> _wifiAwareSubscriptions = {}; // sessionId -> subscription
  final Map<String, unified.TransferStatus> _nextStatus = {}; // sessionId -> nextStatus for state machine
  final Map<String, Timer?> _statusDebounceTimers = {}; // sessionId -> debounce timer
  
  TransferRepositoryImpl({
    required LoggerService loggerService,
    required ConnectionService connectionService,
    required ErrorHandlingService errorHandlingService,
    required PerformanceOptimizationService performanceService,
    required TransferBenchmarkingService benchmarkingService,
    required ChecksumVerificationService checksumService,
    required AirLinkProtocol airLinkProtocol,
    required RateLimitingService rateLimitingService,
    SecureSessionManager? secureSessionManager,
  }) : _loggerService = loggerService,
       _connectionService = connectionService,
       _errorHandlingService = errorHandlingService,
       _performanceService = performanceService,
       _benchmarkingService = benchmarkingService,
       _checksumService = checksumService,
       _airLinkProtocol = airLinkProtocol,
       _rateLimitingService = rateLimitingService,
       _secureSessionManager = secureSessionManager ?? SecureSessionManager();
  
  // Transfer ID mapping from sessionId (UUID) to numeric transferId
  final Map<String, int> _sessionToTransferId = {};
  int _nextTransferId = 1;
  
  @override
  Future<String> startTransferSession({
    required String targetDeviceId,
    required String connectionMethod,
    required List<unified.TransferFile> files,
  }) async {
    try {
      // Check device-specific rate limit
      final deviceRateLimit = _rateLimitingService.checkTransferRateLimit(targetDeviceId);
      if (!deviceRateLimit.allowed) {
        _loggerService.warning('Rate limit exceeded for device $targetDeviceId');
        throw TransferException(
          message: 'Rate limit exceeded for device. Retry after ${deviceRateLimit.retryAfter?.inSeconds ?? 60} seconds.',
          code: 'RATE_LIMIT_DEVICE',
        );
      }
      
      // Check global rate limit
      final globalRateLimit = _rateLimitingService.checkGlobalRateLimit();
      if (!globalRateLimit.allowed) {
        _loggerService.warning('Global rate limit exceeded');
        throw TransferException(
          message: 'Global rate limit exceeded. Retry after ${globalRateLimit.retryAfter?.inSeconds ?? 60} seconds.',
          code: 'RATE_LIMIT_GLOBAL',
        );
      }
      
      // Check concurrent transfer limit
      if (_activeTransfers.length >= AppConstants.maxConcurrentTransfers) {
        throw TransferException(
          message: 'Maximum concurrent transfers reached (${AppConstants.maxConcurrentTransfers})',
          code: 'CONCURRENT_LIMIT',
        );
      }
      
      // Record transfer request for rate limiting
      _rateLimitingService.recordTransferRequest(targetDeviceId);
      
      final sessionId = _uuid.v4();
      final session = unified.TransferSession(
        id: sessionId,
        targetDeviceId: targetDeviceId,
        files: files,
        connectionMethod: connectionMethod,
        status: unified.TransferStatus.pending,
        direction: unified.TransferDirection.sent, // Default to sent for outgoing transfers
        createdAt: DateTime.now(),
      );
      
      _activeTransfers.add(session);
      
      // Assign numeric transfer ID for this session
      _sessionToTransferId[sessionId] = _nextTransferId++;
      
      _loggerService.info('Started transfer session: $sessionId with transferId: ${_sessionToTransferId[sessionId]}');
      
      return sessionId;
    } catch (e) {
      _loggerService.error('Failed to start transfer session: $e');
      throw TransferException(
        message: 'Failed to start transfer session: $e',
      );
    }
  }
  
  @override
  Future<void> sendFiles({
    required String sessionId,
    required List<unified.TransferFile> files,
  }) async {
    try {
      final session = _activeTransfers.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(
          message: 'Transfer session not found: $sessionId',
        ),
      );
      
      _loggerService.info('Starting file transfer for session: $sessionId');
      
      // Get connection info from discovery service
      final connectionInfo = await _connectionService.getConnectionInfo(session.targetDeviceId);
      if (connectionInfo == null) {
        throw TransferException(
          message: 'Connection info not found for device ${session.targetDeviceId}. Device may not be discovered yet.',
          code: 'CONNECTION_INFO_NOT_FOUND',
        );
      }
      
      final connectionToken = connectionInfo.connectionToken;
      final connectionMethod = connectionInfo.connectionMethod;

      // Validate connection token for token-based transports
      if ((connectionMethod == 'ble' || connectionMethod == 'wifi_aware') &&
          (connectionToken == null || connectionToken.isEmpty)) {
        throw TransferException(
          message: 'Missing connection token for method: $connectionMethod',
          code: 'MISSING_CONNECTION_TOKEN',
        );
      }
      
      // Store connection info for this session
      if (connectionToken != null) {
        _connectionTokens[sessionId] = connectionToken;
        // Set connecting status once connection tokens are available
        _updateSessionStatus(sessionId, unified.TransferStatus.connecting);
      }
      _connectionMethods[sessionId] = connectionMethod;
      
      // Set connection info for this specific transfer in AirLinkProtocol
      if (connectionToken != null) {
        _airLinkProtocol.setConnectionInfoForTransfer(sessionId, connectionToken, connectionMethod);
      }
      
      // Calculate and store checksums for each file before sending
      // Use chunked hashing for files larger than 10MB to avoid memory issues
      const int largeFileThreshold = 10 * 1024 * 1024; // 10MB
      for (final file in files) {
        try {
          final checksum = file.size > largeFileThreshold
              ? await _checksumService.calculateChecksumChunked(file.path)
              : await _checksumService.calculateChecksum(file.path);
          await _checksumService.storeChecksum(sessionId, file.path, checksum);
          _loggerService.info('File checksum calculated and stored: ${file.name} - $checksum (${file.size > largeFileThreshold ? "chunked" : "standard"})');
        } catch (e) {
          _loggerService.error('Failed to calculate checksum for ${file.name}: $e');
          // Continue with transfer but log the error
        }
        
        await _benchmarkingService.startBenchmark(
          transferId: '${sessionId}_${file.id}',
          fileName: file.name,
          fileSize: file.size,
          transferMethod: connectionMethod,
          deviceType: Platform.isAndroid ? 'Android' : 'iOS',
        );
      }
      
      // Start transfer service for background processing
      final transferId = _sessionToTransferId[sessionId] ?? 0;
      await AirLinkPlugin.startTransferService(transferId.toString());
      
      // Set native connection info and initiate secure session + handshake scaffold
      try {
        _secureSessionManager.setNativeConnectionInfo(
          sessionId,
          connectionToken ?? '',
          connectionMethod,
        );
        await _secureSessionManager.createSession(
          sessionId,
          session.targetDeviceId,
          connectionToken: connectionToken,
          connectionMethod: connectionMethod,
        );
        // Obtain local public key (to be shared via native/protocol by higher layer)
        final localPublicKey = _secureSessionManager.getLocalPublicKey(sessionId);
        _loggerService.info('Local public key generated for session $sessionId (${localPublicKey.length} bytes)');
        
        // Set handshaking status before performing handshake
        _updateSessionStatus(sessionId, unified.TransferStatus.handshaking);
        
        // Perform handshake per transport
        if (connectionMethod == 'wifi_aware' && (connectionToken != null && connectionToken.isNotEmpty)) {
          await _performWifiAwareHandshake(sessionId, connectionToken, localPublicKey);
        } else if (connectionMethod == 'ble' && (connectionToken != null && connectionToken.isNotEmpty)) {
          // Wait for remote BLE public key via discovery events or a metadata read
          try {
            final Uint8List remoteKey = await _awaitBleRemotePublicKey(connectionToken).timeout(
              const Duration(seconds: 10),
              onTimeout: () => Uint8List(0),
            );
            if (remoteKey.isNotEmpty) {
              // Validate BLE remote key (length, not all zeros)
              if (remoteKey.length != 32 || remoteKey.every((b) => b == 0)) {
                throw TransferException(message: 'Invalid BLE public key received', code: 'BLE_KEY_INVALID');
              }
              // Complete handshake with standardized info
              final info = Uint8List.fromList('airlink/v1/session:$sessionId'.codeUnits);
              await _secureSessionManager.completeHandshake(sessionId, remoteKey, info);
              final List<int> keyBytes = globalKeyManager.getSymmetricKeyBytes(sessionId);
              final bool setOk = await AirLinkPlugin.setBleEncryptionKey(keyBytes);
              if (setOk) {
                _loggerService.info('BLE encryption key set (len=${keyBytes.length}) for session $sessionId');
              } else {
                _loggerService.warning('Native BLE encryption key set returned false');
              }
            } else {
              _loggerService.warning('Remote BLE public key not received; disabling native BLE encryption for session $sessionId');
              _secureSessionManager.encryptionMode = EncryptionMode.dart;
            }
          } catch (e) {
            _loggerService.warning('BLE handshake failed, falling back to Dart encryption: $e');
            _secureSessionManager.encryptionMode = EncryptionMode.dart;
          }
        }
      } catch (e) {
        _loggerService.warning('Handshake initialization failed for session $sessionId: $e');
        throw TransferException(message: 'Handshake initialization failed', code: 'HANDSHAKE_FAILED');
      }

      // Set transferring status before starting file transfers
      _updateSessionStatus(sessionId, unified.TransferStatus.transferring);

      // Transfer files sequentially with per-file error isolation
      await _transferFilesSequentially(
        sessionId,
        files,
        connectionToken ?? '',
        connectionMethod,
      );
      
      // Mark session as completed
      final currentSession = _activeTransfers.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(message: 'Session not found: $sessionId'),
      );
      final completedSession = currentSession.copyWith(
        status: unified.TransferStatus.completed,
        completedAt: DateTime.now(),
      );
      _updateSession(completedSession);
      _transferHistory.add(completedSession);
      _activeTransfers.removeWhere((s) => s.id == sessionId);
      
      // Complete benchmarking for all files
      for (final file in files) {
        await _benchmarkingService.completeBenchmark(
          transferId: '${sessionId}_${file.id}',
          status: unified.TransferStatus.completed,
        );
      }
      // Cancel Wi‑Fi Aware subscription if present
      try {
        await _wifiAwareSubscriptions.remove(sessionId)?.cancel();
      } catch (_) {}
      // Clean up controllers on success
      try { await _progressControllers[sessionId]?.close(); } catch (_) {}
      _progressControllers.remove(sessionId);
      try { await _queueControllers[sessionId]?.close(); } catch (_) {}
      _queueControllers.remove(sessionId);
      
      // Clean up transfer in AirLinkProtocol
      _airLinkProtocol.cleanupTransfer(sessionId);
      
      _loggerService.info('Transfer session completed: $sessionId');
    } catch (e) {
      _loggerService.error('Failed to send files: $e');
      
      // Complete benchmarking for all files with error status
      for (final file in files) {
        await _benchmarkingService.completeBenchmark(
          transferId: '${sessionId}_${file.id}',
          status: unified.TransferStatus.failed,
          errorMessage: e.toString(),
        );
      }
      
      // Clean up transfer in AirLinkProtocol on error
      _airLinkProtocol.cleanupTransfer(sessionId);
      
      throw TransferException(
        message: 'Failed to send files: $e',
      );
    }
  }
  
  @override
  Future<void> startReceivingFiles({
    required String sessionId,
    required String connectionToken,
    required String connectionMethod,
    required String savePath,
  }) async {
    try {
      _loggerService.info('Starting to receive files for session: $sessionId');
      
      // Store connection info for this session
      _connectionTokens[sessionId] = connectionToken;
      _connectionMethods[sessionId] = connectionMethod;
      
      // Set connection info for this specific transfer in AirLinkProtocol
      _airLinkProtocol.setConnectionInfoForTransfer(sessionId, connectionToken, connectionMethod);
      
      // Create a session for receiving
      final session = unified.TransferSession(
        id: sessionId,
        targetDeviceId: 'unknown', // Will be updated when connection is established
        files: [], // Will be populated as files are received
        connectionMethod: connectionMethod,
        status: unified.TransferStatus.pending,
        direction: unified.TransferDirection.received,
        createdAt: DateTime.now(),
      );
      
      _activeTransfers.add(session);
      
      // Delegate to the main receiveFiles method
      await receiveFiles(sessionId: sessionId, savePath: savePath);
      
    } catch (e) {
      _loggerService.error('Failed to start receiving files: $e');
      throw TransferException(
        message: 'Failed to start receiving files: $e',
      );
    }
  }

  @override
  Future<void> receiveFiles({
    required String sessionId,
    required String savePath,
  }) async {
    try {
      _loggerService.info('Starting file reception for session: $sessionId');
      
      // Get connection info for this session
      final connectionToken = _connectionTokens[sessionId];
      final connectionMethod = _connectionMethods[sessionId];
      
      if (connectionToken == null || connectionMethod == null) {
        throw TransferException(
          message: 'Connection info not found for session: $sessionId',
          code: 'CONNECTION_INFO_NOT_FOUND',
        );
      }
      
      // Create progress controller
      if (!_progressControllers.containsKey(sessionId)) {
        _progressControllers[sessionId] = StreamController<unified.TransferProgress>.broadcast();
      }
      
      // Create directory for received files
      final saveDirectory = Directory(savePath);
      if (!await saveDirectory.exists()) {
        await saveDirectory.create(recursive: true);
      }
      
      // Start receiving files based on connection method
      final transferId = _sessionToTransferId[sessionId] ?? 0;
      
      if (connectionMethod == 'wifi_aware') {
        // Use Wi-Fi Aware receive with progress monitoring
        final subscription = await _receiveWifiAwareFiles(sessionId, connectionToken, savePath);
        _wifiAwareSubscriptions[sessionId] = subscription;
      } else if (connectionMethod == 'ble') {
        // Use BLE file transfer with benchmarking
        await AirLinkPlugin.startReceivingBleFile(connectionToken, transferId.toString(), savePath);
        
        // Start benchmarking for BLE receive (we'll need to get file info from native layer)
        // For now, create a placeholder benchmark that will be updated when file info is available
        await _benchmarkingService.startBenchmark(
          transferId: '${sessionId}_ble_receive',
          fileName: 'BLE_Receive',
          fileSize: 0, // Will be updated when file info is available
          transferMethod: 'ble',
          deviceType: Platform.isAndroid ? 'Android' : 'iOS',
        );
        
        // Subscribe to BLE progress stream and update benchmarking service
        try {
          final progressStream = AirLinkPlugin.getTransferProgressStream(transferId.toString());
          progressStream.listen((progressData) async {
            final bytesTransferred = progressData['bytesTransferred'] as int? ?? 0;
            final speed = progressData['speed'] as double? ?? 0.0;
            
            await _benchmarkingService.updateProgress(
              transferId: '${sessionId}_ble_receive',
              bytesTransferred: bytesTransferred,
              currentSpeed: speed,
            );
          });
        } catch (e) {
          _loggerService.warning('Failed to subscribe to BLE progress stream: $e');
        }
      } else {
        // Use Wi-Fi Aware native receive Option B: write natively and monitor progress
        await AirLinkPlugin.startWifiAwareReceive(connectionToken, transferId.toString(), savePath);
      }
      
      // Update session status to received
      final session = _activeTransfers.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(message: 'Session not found: $sessionId'),
      );
      
      final receivedSession = session.copyWith(
        status: unified.TransferStatus.completed,
        direction: unified.TransferDirection.received,
        completedAt: DateTime.now(),
      );
      _updateSession(receivedSession);
      _transferHistory.add(receivedSession);
      _activeTransfers.removeWhere((s) => s.id == sessionId);
      
      // Complete benchmarking for BLE receive if applicable
      if (connectionMethod == 'ble') {
        await _benchmarkingService.completeBenchmark(
          transferId: '${sessionId}_ble_receive',
          status: unified.TransferStatus.completed,
        );
      }
      
      // Clean up transfer in AirLinkProtocol
      _airLinkProtocol.cleanupTransfer(sessionId);
      
      _loggerService.info('File reception completed for session: $sessionId');
      
    } catch (e) {
      // Complete benchmarking for BLE receive with error status if applicable
      final storedConnectionMethod = _connectionMethods[sessionId];
      if (storedConnectionMethod == 'ble') {
        await _benchmarkingService.completeBenchmark(
          transferId: '${sessionId}_ble_receive',
          status: unified.TransferStatus.failed,
          errorMessage: e.toString(),
        );
      }
      
      // Use enhanced error handling
      await _errorHandlingService.handleError(
        e,
        'file_reception',
        shouldRetry: true,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 2),
      );
      
      // Clean up transfer in AirLinkProtocol on error
      _airLinkProtocol.cleanupTransfer(sessionId);
      
      _loggerService.error('Failed to receive files: $e');
      throw TransferException(
        message: 'Failed to receive files: $e',
      );
    }
  }
  
  @override
  Future<void> pauseTransfer(String sessionId) async {
    try {
      _loggerService.info('Pausing transfer session: $sessionId');
      
      final numericTransferId = _sessionToTransferId[sessionId] ?? 0;
      final success = await AirLinkPlugin.pauseTransfer(numericTransferId.toString());
      
      if (success) {
        // Update session status
        final session = _activeTransfers.firstWhere(
          (s) => s.id == sessionId,
          orElse: () => throw TransferException(message: 'Session not found: $sessionId'),
        );
        
        final pausedSession = session.copyWith(status: unified.TransferStatus.paused);
        _updateSession(pausedSession);
      } else {
        throw TransferException(message: 'Failed to pause transfer in native layer');
      }
      
    } catch (e) {
      // Use enhanced error handling
      await _errorHandlingService.handleError(
        e,
        'pause_transfer',
        shouldRetry: false,
      );
      
      _loggerService.error('Failed to pause transfer session: $e');
      throw TransferException(
        message: 'Failed to pause transfer session: $e',
      );
    }
  }
  
  @override
  Future<void> resumeTransfer(String sessionId) async {
    try {
      _loggerService.info('Resuming transfer session: $sessionId');
      
      final numericTransferId = _sessionToTransferId[sessionId] ?? 0;
      final success = await AirLinkPlugin.resumeTransfer(numericTransferId.toString());
      
      if (success) {
        // Update session status
        final session = _activeTransfers.firstWhere(
          (s) => s.id == sessionId,
          orElse: () => throw TransferException(message: 'Session not found: $sessionId'),
        );
        
        // Set resuming status first
        final resumingSession = session.copyWith(status: unified.TransferStatus.resuming);
        _updateSession(resumingSession);
        
        // Then set to transferring
        final resumedSession = session.copyWith(status: unified.TransferStatus.transferring);
        _updateSession(resumedSession);
      } else {
        throw TransferException(message: 'Failed to resume transfer in native layer');
      }
      
    } catch (e) {
      // Use enhanced error handling
      await _errorHandlingService.handleError(
        e,
        'resume_transfer',
        shouldRetry: true,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 2),
      );
      
      _loggerService.error('Failed to resume transfer session: $e');
      throw TransferException(
        message: 'Failed to resume transfer session: $e',
      );
    }
  }
  
  @override
  Future<void> cancelTransfer(String sessionId) async {
    try {
      _loggerService.info('Cancelling transfer session: $sessionId');
      
      final session = _activeTransfers.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(
          message: 'Transfer session not found: $sessionId',
        ),
      );
      
      // Get the numeric transfer ID for native operations
      final numericTransferId = _sessionToTransferId[sessionId] ?? 0;
      
      // Cancel the transfer in the native layer
      final success = await AirLinkPlugin.cancelTransfer(numericTransferId.toString());
      if (!success) {
        _loggerService.warning('Failed to cancel transfer in native layer');
      }
      
      // Close connection if we have one
      final connectionToken = _connectionTokens[sessionId];
      if (connectionToken != null) {
        try {
          await AirLinkPlugin.closeConnection(connectionToken);
          _loggerService.info('Connection closed');
        } catch (e) {
          _loggerService.warning('Failed to close connection: $e');
        }
      }
      
      // Update session status
      final cancelledSession = session.copyWith(
        status: unified.TransferStatus.cancelled,
        completedAt: DateTime.now(),
      );
      
      _updateSession(cancelledSession);
      _transferHistory.add(cancelledSession);
      _activeTransfers.removeWhere((s) => s.id == sessionId);
      
      // Clean up progress controller
      _progressControllers[sessionId]?.close();
      _progressControllers.remove(sessionId);
      _queueControllers[sessionId]?.close();
      _queueControllers.remove(sessionId);
      // Cancel Wi‑Fi Aware subscription if present
      try {
        await _wifiAwareSubscriptions.remove(sessionId)?.cancel();
      } catch (_) {}
      
      // Remove from session to transfer ID mapping
      _sessionToTransferId.remove(sessionId);
      
      // Clean up connection info
      _connectionTokens.remove(sessionId);
      _connectionMethods.remove(sessionId);
      
      // Clean up status state machine
      _statusDebounceTimers[sessionId]?.cancel();
      _statusDebounceTimers.remove(sessionId);
      _nextStatus.remove(sessionId);
      
      // Clean up transfer in AirLinkProtocol
      _airLinkProtocol.cleanupTransfer(sessionId);
      
      _loggerService.info('Transfer cancelled successfully: $sessionId');
      
    } catch (e) {
      // Use enhanced error handling
      await _errorHandlingService.handleError(
        e,
        'cancel_transfer',
        shouldRetry: false,
      );
      
      // Clean up transfer in AirLinkProtocol on error
      _airLinkProtocol.cleanupTransfer(sessionId);
      
      _loggerService.error('Failed to cancel transfer session: $e');
      throw TransferException(
        message: 'Failed to cancel transfer session: $e',
      );
    }
  }
  
  @override
  Stream<unified.TransferProgress> getTransferProgress(String sessionId) {
    if (!_progressControllers.containsKey(sessionId)) {
      _progressControllers[sessionId] = StreamController<unified.TransferProgress>.broadcast();
    }
    return _progressControllers[sessionId]!.stream;
  }

  @override
  Stream<TransferQueueProgress> getQueueProgress(String sessionId) {
    if (!_queueControllers.containsKey(sessionId)) {
      _queueControllers[sessionId] = StreamController<TransferQueueProgress>.broadcast();
    }
    return _queueControllers[sessionId]!.stream;
  }
  
  @override
  List<unified.TransferSession> getActiveTransfers() {
    return List.from(_activeTransfers);
  }
  
  @override
  List<unified.TransferSession> getTransferHistory() {
    return List.from(_transferHistory);
  }
  
  @override
  Future<void> cleanupCompletedTransfers() async {
    try {
      _loggerService.info('Cleaning up completed transfers');
      
      // Remove completed transfers older than 24 hours
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      _transferHistory.removeWhere(
        (session) => session.completedAt != null && 
        session.completedAt!.isBefore(cutoffTime),
      );
      
    } catch (e) {
      _loggerService.error('Failed to cleanup transfers: $e');
      throw TransferException(
        message: 'Failed to cleanup transfers: $e',
      );
    }
  }
  
  Future<void> _transferFileWithNativeTransport(String sessionId, unified.TransferFile transferFile, String connectionToken, String connectionMethod) async {
    try {
      final filePath = transferFile.path;
      final fileSize = transferFile.size;
      
      // Create progress controller if it doesn't exist
      if (!_progressControllers.containsKey(sessionId)) {
        _progressControllers[sessionId] = StreamController<unified.TransferProgress>.broadcast();
      }
      
      // Record performance metrics
      final stopwatch = Stopwatch()..start();
      
      // Get the session for this transfer
      final session = _activeTransfers.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(
          message: 'Transfer session not found: $sessionId',
        ),
      );
      
      final transferId = _sessionToTransferId[sessionId] ?? 0;
      
      // Set file start time before native start
      _fileStartTimes['$sessionId:${transferFile.id}'] = DateTime.now();

      // Send file metadata with checksum before starting transfer (for Wi-Fi Aware)
      if (connectionMethod == 'wifi_aware') {
        await _sendFileMetadata(sessionId, transferFile, connectionToken);
      }

      // Start transfer based on connection method
      bool success = false;
      if (connectionMethod == 'ble') {
        success = await AirLinkPlugin.startBleFileTransfer(connectionToken, filePath, transferId.toString());
      } else {
        // Use Wi-Fi Aware or MultipeerConnectivity
        success = await AirLinkPlugin.startTransfer(
          transferId.toString(),
          filePath,
          fileSize,
          session.targetDeviceId,
          connectionMethod,
        );
      }
      
      if (!success) {
        throw TransferException(message: 'Failed to start file transfer in native layer');
      }
      
      // Monitor progress
      await _monitorTransferProgress(sessionId, transferFile, transferId.toString());
      
      stopwatch.stop();
      
      // Record performance data
      _performanceService.recordOperation(
        'file_transfer',
        stopwatch.elapsed,
        fileSize,
      );
      
      _loggerService.info('File transfer completed: ${transferFile.name}');
    } catch (e) {
      // Complete benchmarking for failed file
      await _benchmarkingService.completeBenchmark(
        transferId: '${sessionId}_${transferFile.id}',
        status: unified.TransferStatus.failed,
        errorMessage: e.toString(),
      );
      
      // Use enhanced error handling
      await _errorHandlingService.handleError(
        e,
        'file_transfer',
        shouldRetry: true,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 2),
      );
      
      _loggerService.error('Failed to transfer file: ${transferFile.name}, error: $e');
      throw TransferException(
        message: 'Failed to transfer file: ${transferFile.name}',
      );
    }
  }

  /// Transfer multiple files sequentially with progress aggregation
  Future<void> _transferFilesSequentially(
    String sessionId,
    List<unified.TransferFile> files,
    String connectionToken,
    String connectionMethod,
  ) async {
    final List<unified.TransferFile> failedFiles = <unified.TransferFile>[];
    final int totalFiles = files.length;
    int completedFiles = 0;
    for (int i = 0; i < files.length; i++) {
      final unified.TransferFile file = files[i];
      try {
        await _transferFileWithNativeTransport(sessionId, file, connectionToken, connectionMethod);
        completedFiles++;
      } catch (e) {
        failedFiles.add(file);
        _loggerService.warning('File failed (${file.name}), continuing with next: $e');
        
        // Complete benchmarking for failed file
        await _benchmarkingService.completeBenchmark(
          transferId: '${sessionId}_${file.id}',
          status: unified.TransferStatus.failed,
          errorMessage: e.toString(),
        );
      }
      await Future.delayed(const Duration(milliseconds: 100));
      // Emit overall queue progress event
      final qc = _queueControllers[sessionId];
      qc?.add(TransferQueueProgress(
        sessionId: sessionId,
        completedFiles: completedFiles,
        totalFiles: totalFiles,
      ));
    }
    if (failedFiles.isNotEmpty) {
      final String failedNames = failedFiles.map((f) => f.name).join(', ');
      throw TransferException(message: 'Some files failed: $failedNames');
    }
  }
  
  void _updateSession(unified.TransferSession session) {
    final index = _activeTransfers.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _activeTransfers[index] = session;
    }
  }

  /// Update session status with state machine and debouncing
  void _updateSessionStatus(String sessionId, unified.TransferStatus newStatus) {
    // Cancel existing debounce timer
    _statusDebounceTimers[sessionId]?.cancel();
    
    // Store the next status
    _nextStatus[sessionId] = newStatus;
    
    // Debounce status updates by 100ms to prevent flicker
    _statusDebounceTimers[sessionId] = Timer(const Duration(milliseconds: 100), () {
      final session = _activeTransfers.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(message: 'Session not found: $sessionId'),
      );
      
      final updatedSession = session.copyWith(status: newStatus);
      _updateSession(updatedSession);
      
      // Clean up
      _nextStatus.remove(sessionId);
      _statusDebounceTimers.remove(sessionId);
    });
  }
  
  /// Monitor transfer progress using native transport
  Future<void> _monitorTransferProgress(String sessionId, unified.TransferFile transferFile, String transferId) async {
    try {
      final fileSize = transferFile.size;
      int lastBytesTransferred = 0;
      DateTime lastProgressTime = DateTime.now();
      const Duration timeoutThreshold = Duration(seconds: 60); // 60 seconds timeout
      
      // Use event-driven progress updates instead of polling
      // This provides real-time updates from native layer without constant polling
      try {
        final progressStream = AirLinkPlugin.getTransferProgressStream(transferId);
        await for (final progressData in progressStream) {
          final bytesTransferred = progressData['bytesTransferred'] as int? ?? 0;
          final status = progressData['status'] as String? ?? 'unknown';
          
          // Check for timeout - if no progress for too long, abort
          final now = DateTime.now();
          if (bytesTransferred == lastBytesTransferred && 
              now.difference(lastProgressTime) > timeoutThreshold &&
              status != 'completed' && status != 'failed' && status != 'cancelled') {
            _loggerService.warning('Transfer progress stalled for ${timeoutThreshold.inSeconds}s, attempting to abort');
            
            // Emit error progress
            final transferProgress = unified.TransferProgress(
              transferId: sessionId,
              fileId: transferFile.id,
              fileName: transferFile.name,
              bytesTransferred: bytesTransferred,
              totalBytes: fileSize,
              progress: bytesTransferred / fileSize,
              speed: 0.0,
              status: unified.TransferStatus.failed,
              startedAt: _fileStartTimes['$sessionId:${transferFile.id}'] ?? DateTime.now(),
              errorMessage: 'Transfer stalled - no progress for ${timeoutThreshold.inSeconds} seconds',
            );
            _progressControllers[sessionId]?.add(transferProgress);
            
            // Complete benchmarking with error
            await _benchmarkingService.completeBenchmark(
              transferId: '${sessionId}_${transferFile.id}',
              status: unified.TransferStatus.failed,
              errorMessage: 'Transfer stalled - timeout',
            );
            
            _fileStartTimes.remove('$sessionId:${transferFile.id}');
            break;
          }
          
          // Update progress (preserve startedAt)
          if (bytesTransferred != lastBytesTransferred) {
            lastProgressTime = now; // Reset timeout timer
            final DateTime startedAt = _fileStartTimes['$sessionId:${transferFile.id}'] ?? DateTime.now();
            final double elapsedSecs = now.difference(startedAt).inMilliseconds / 1000.0;
            final double calcSpeed = elapsedSecs > 0 ? bytesTransferred / elapsedSecs : 0.0;
            final transferProgress = unified.TransferProgress(
              transferId: sessionId,
              fileId: transferFile.id,
              fileName: transferFile.name,
              bytesTransferred: bytesTransferred,
              totalBytes: fileSize,
              progress: bytesTransferred / fileSize,
              speed: calcSpeed,
              status: _mapNativeStatusToTransferStatus(status),
              startedAt: startedAt,
            );
            _progressControllers[sessionId]?.add(transferProgress);
            
            // Update benchmarking progress
            await _benchmarkingService.updateProgress(
              transferId: '${sessionId}_${transferFile.id}',
              bytesTransferred: bytesTransferred,
              currentSpeed: calcSpeed,
            );
            
            lastBytesTransferred = bytesTransferred;
          }
          
          // Check if transfer is complete
          if (status == 'completed' || status == 'failed' || status == 'cancelled') {
            _fileStartTimes.remove('$sessionId:${transferFile.id}');
            
            // Complete benchmarking for this file
            final transferStatus = _mapNativeStatusToTransferStatus(status);
            await _benchmarkingService.completeBenchmark(
              transferId: '${sessionId}_${transferFile.id}',
              status: transferStatus,
              errorMessage: status == 'failed' ? 'Transfer failed' : null,
            );
            
            break;
          }
        }
      } catch (e) {
        _loggerService.warning('Error monitoring progress: $e');
        // Emit error progress
        final transferProgress = unified.TransferProgress(
          transferId: sessionId,
          fileId: transferFile.id,
          fileName: transferFile.name,
          bytesTransferred: lastBytesTransferred,
          totalBytes: fileSize,
          progress: lastBytesTransferred / fileSize,
          speed: 0.0,
          status: unified.TransferStatus.failed,
          startedAt: _fileStartTimes['$sessionId:${transferFile.id}'] ?? DateTime.now(),
          errorMessage: 'Progress monitoring error: $e',
        );
        _progressControllers[sessionId]?.add(transferProgress);
      }
    } catch (e) {
      _loggerService.error('Failed to monitor transfer progress: $e');
    }
  }
  
  
  /// Receive files over Wi‑Fi Aware using event stream
  Future<StreamSubscription> _receiveWifiAwareFiles(String sessionId, String connectionToken, String savePath) async {
    try {
      // Create directory for received files
      final saveDirectory = Directory(savePath);
      if (!await saveDirectory.exists()) {
        await saveDirectory.create(recursive: true);
      }
      
      // Start native receive loop and subscribe to data stream
      final int transferId = _sessionToTransferId[sessionId] ?? 0;
      await AirLinkPlugin.startWifiAwareReceive(connectionToken, transferId.toString(), savePath);
      // Receiver state
      final Map<String, _FileReceiveState> receiveStates = {};
      StreamSubscription? sub;
      sub = AirLinkPlugin.wifiAwareDataStream.listen((event) async {
        try {
          if (event['connectionToken'] != connectionToken) return;
          final List<int> bytes = (event['bytes'] as List).cast<int>();
          if (bytes.isEmpty) return;
          
          // Expect messages as framed by native: payload only (plaintext) or decrypted plaintext
          // Define simple JSON control protocol for metadata and chunking
          if (bytes.isNotEmpty && bytes[0] == 0x7B /* '{' */) {
            final String jsonText = String.fromCharCodes(bytes);
            final Map<String, dynamic> msg = _safeParseJson(jsonText);
            if (msg.isEmpty) return;
            final String type = (msg['type'] as String?) ?? '';
            if (type == 'handshake') {
              // Peer is initiating handshake: complete with its public key and reply with ours
              try {
                final List<dynamic>? remoteKeyList = msg['publicKey'] as List<dynamic>?;
                if (remoteKeyList != null) {
                  final Uint8List remoteKey = Uint8List.fromList(remoteKeyList.cast<int>());
                  // Ensure session exists and connection info is set
                  _secureSessionManager.setNativeConnectionInfo(sessionId, connectionToken, 'wifi_aware');
                  _secureSessionManager.getSession(sessionId) ?? await _secureSessionManager.createSession(sessionId, 'wifi_aware_peer', connectionToken: connectionToken, connectionMethod: 'wifi_aware');
                  await _secureSessionManager.completeHandshakeSimple(sessionId, remoteKey);
                  final Uint8List localKey = _secureSessionManager.getLocalPublicKey(sessionId);
                  final Map<String, dynamic> response = {
                    'type': 'handshake_response',
                    'sessionId': sessionId,
                    'publicKey': localKey.toList(),
                  };
                  await AirLinkPlugin.sendWifiAwareData(connectionToken, utf8.encode(jsonEncode(response)));
                  _loggerService.info('Handshake completed and response sent for session $sessionId');
                }
              } catch (e) {
                _loggerService.warning('Failed to process handshake request: $e');
              }
              return;
            } else if (type == 'handshake_response') {
              // Initiator will handle this via the awaiting future; ignore here on receiver side
              return;
            } else if (type == 'verify') {
              // Perform verification of incoming encrypted payload and respond
              try {
                final Map<String, dynamic>? payload = msg['payload'] as Map<String, dynamic>?;
                if (payload != null) {
                  final ok = await _secureSessionManager.verifyIncomingPayload(sessionId, payload);
                  final Map<String, dynamic> ack = {
                    'type': ok ? 'verify_ack' : 'verify_fail',
                    'sessionId': sessionId,
                  };
                  await AirLinkPlugin.sendWifiAwareData(connectionToken, utf8.encode(jsonEncode(ack)));
                }
              } catch (e) {
                _loggerService.warning('Verification handling failed: $e');
              }
              return;
            }
            if (type == 'file_meta') {
              final String fileId = msg['fileId'] as String? ?? _uuid.v4();
              final String fileName = msg['name'] as String? ?? 'file.bin';
              final int totalBytes = (msg['size'] as num?)?.toInt() ?? 0;
              final String? checksum = msg['checksum'] as String?;
              final filePath = _joinPath(savePath, fileName);
              final state = _FileReceiveState(
                fileId: fileId,
                path: filePath,
                expectedBytes: totalBytes,
                checksum: checksum,
              );
              await state.open();
              receiveStates[fileId] = state;
              
              // Start benchmarking for received file
              await _benchmarkingService.startBenchmark(
                transferId: '${sessionId}_${fileId}',
                fileName: fileName,
                fileSize: totalBytes,
                transferMethod: 'wifi_aware',
                deviceType: Platform.isAndroid ? 'Android' : 'iOS',
              );
              
              _loggerService.info('Receiving file meta: $fileName ($totalBytes bytes)');
            } else if (type == 'file_chunk') {
              final String fileId = msg['fileId'] as String? ?? '';
              final List<int> data = (msg['data'] as List).cast<int>();
              final int offset = (msg['offset'] as num?)?.toInt() ?? -1;
              final int totalBytes = (msg['size'] as num?)?.toInt() ?? 0;
              final state = receiveStates[fileId];
              if (state != null) {
                await state.writeChunk(data, offset: offset);
                _emitProgress(sessionId, fileId, state.writtenBytes, totalBytes, fileName: state.path.split('/').last);
              }
            } else if (type == 'file_end') {
              final String fileId = msg['fileId'] as String? ?? '';
              final state = receiveStates.remove(fileId);
              if (state != null) {
                await state.close();
                
                // Verify checksum using ChecksumVerificationService
                bool checksumValid = false;
                if (state.checksum != null && state.checksum!.isNotEmpty) {
                  try {
                    checksumValid = await _checksumService.verifyChecksum(state.path, state.checksum!);
                    if (checksumValid) {
                      // Store the verified checksum
                      await _checksumService.storeChecksum(sessionId, state.path, state.checksum!);
                    }
                  } catch (e) {
                    _loggerService.error('Checksum verification failed for ${state.path}: $e');
                    checksumValid = false;
                  }
                } else {
                  // No checksum provided, use legacy verification
                  checksumValid = await state.verifyChecksum();
                }
                
                if (checksumValid) {
                  _loggerService.info('File received and verified: ${state.path}');
                  
                  // Complete benchmarking for received file
                  await _benchmarkingService.completeBenchmark(
                    transferId: '${sessionId}_${fileId}',
                    status: unified.TransferStatus.completed,
                  );
                } else {
                  _loggerService.warning('Checksum mismatch for ${state.path}');
                  
                  // Complete benchmarking with error status
                  await _benchmarkingService.completeBenchmark(
                    transferId: '${sessionId}_${fileId}',
                    status: unified.TransferStatus.failed,
                    errorMessage: 'Checksum verification failed',
                  );
                }
                // If no more files expected, cancel subscription and cleanup
                if (receiveStates.isEmpty) {
                  try { await sub?.cancel(); } catch (_) {}
                  _wifiAwareSubscriptions.remove(sessionId);
                }
              }
            }
          } else {
            // Binary frame: [type:1][fileIdLen:1][fileId][offset:8][dataLen:4][data]
            if (bytes.length >= 1 + 1 + 8 + 4) {
              int index = 0;
              final int type = bytes[index++];
              if (type == 1) { // file_chunk
                final int fileIdLen = bytes[index++];
                if (bytes.length < 1 + 1 + fileIdLen + 8 + 4) return;
                final String fileId = String.fromCharCodes(bytes.sublist(index, index + fileIdLen));
                index += fileIdLen;
                final ByteData bd = ByteData.sublistView(Uint8List.fromList(bytes.sublist(index, index + 8)));
                final int offset = bd.getInt64(0, Endian.big);
                index += 8;
                final ByteData lenBd = ByteData.sublistView(Uint8List.fromList(bytes.sublist(index, index + 4)));
                final int dataLen = lenBd.getInt32(0, Endian.big);
                index += 4;
                if (bytes.length < index + dataLen) return;
                final List<int> data = bytes.sublist(index, index + dataLen);
                final state = receiveStates[fileId];
                if (state != null) {
                  await state.writeChunk(data, offset: offset);
                  _emitProgress(sessionId, fileId, state.writtenBytes, state.expectedBytes, fileName: state.path.split('/').last);
                }
              }
            }
          }
        } catch (e) {
          _loggerService.warning('Failed processing Wi‑Fi Aware data: $e');
        }
      });
      return sub;
    } catch (e) {
      _loggerService.error('Failed to receive Wi-Fi Aware files: $e');
      throw TransferException(
        message: 'Failed to receive Wi-Fi Aware files: $e',
      );
    }
  }

  /// Perform Wi‑Fi Aware handshake: send local public key and await peer response
  Future<void> _performWifiAwareHandshake(String sessionId, String connectionToken, Uint8List localPublicKey) async {
    try {
      final Map<String, dynamic> request = {
        'type': 'handshake',
        'sessionId': sessionId,
        'publicKey': localPublicKey.toList(),
      };
      await AirLinkPlugin.sendWifiAwareData(connectionToken, utf8.encode(jsonEncode(request)));
      _loggerService.info('Handshake request sent for session $sessionId');

      // Await response with timeout
      final Completer<Uint8List> completer = Completer<Uint8List>();
      late final StreamSubscription sub;
      sub = AirLinkPlugin.wifiAwareDataStream.listen((event) {
        try {
          if (event['connectionToken'] != connectionToken) return;
          final List<int> bytes = (event['bytes'] as List).cast<int>();
          if (bytes.isEmpty) return;
          if (bytes[0] != 0x7B) return; // '{'
          final Map<String, dynamic> msg = _safeParseJson(String.fromCharCodes(bytes));
          if (msg.isEmpty) return;
          if ((msg['type'] as String?) == 'handshake_response' && (msg['sessionId'] as String?) == sessionId) {
            final List<dynamic>? keyList = msg['publicKey'] as List<dynamic>?;
            if (keyList != null && !completer.isCompleted) {
              completer.complete(Uint8List.fromList(keyList.cast<int>()));
            }
          }
        } catch (_) {}
      });

      Uint8List remoteKey;
      try {
        remoteKey = await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TransferException(message: 'Handshake response timeout', code: 'HANDSHAKE_TIMEOUT'),
        );
      } finally {
        await sub.cancel();
      }

      // Complete handshake with standardized info
      final info = Uint8List.fromList('airlink/v1/session:$sessionId'.codeUnits);
      await _secureSessionManager.completeHandshake(sessionId, remoteKey, info);

      // Verification: exchange encrypted ping/ack to ensure both peers can encrypt/decrypt
      final verifyPayload = await _secureSessionManager.generateVerificationPayload(sessionId);
      final Map<String, dynamic> verifyMsg = {
        'type': 'verify',
        'sessionId': sessionId,
        'payload': verifyPayload,
      };
      await AirLinkPlugin.sendWifiAwareData(connectionToken, utf8.encode(jsonEncode(verifyMsg)));

      // Await verification ack
      final Completer<bool> verifyCompleter = Completer<bool>();
      late final StreamSubscription vsub;
      vsub = AirLinkPlugin.wifiAwareDataStream.listen((event) async {
        try {
          if (event['connectionToken'] != connectionToken) return;
          final List<int> bytes = (event['bytes'] as List).cast<int>();
          if (bytes.isEmpty) return;
          if (bytes[0] != 0x7B) return; // '{'
          final Map<String, dynamic> msg = _safeParseJson(String.fromCharCodes(bytes));
          if (msg.isEmpty) return;
          if ((msg['type'] as String?) == 'verify_ack' && (msg['sessionId'] as String?) == sessionId) {
            if (!verifyCompleter.isCompleted) verifyCompleter.complete(true);
          }
        } catch (_) {}
      });
      bool verified = false;
      try {
        verified = await verifyCompleter.future.timeout(const Duration(seconds: 30), onTimeout: () => false);
      } finally {
        await vsub.cancel();
      }
      if (!verified) {
        throw TransferException(message: 'Handshake verification failed', code: 'VERIFY_FAILED');
      }
      // Propagate derived symmetric key to native layer (log key length only)
      try {
        final List<int> keyBytes = globalKeyManager.getSymmetricKeyBytes(sessionId);
        await AirLinkPlugin.setEncryptionKey(connectionToken, keyBytes);
        _loggerService.info('Native encryption key set (len=${keyBytes.length}) for session $sessionId');
      } catch (e) {
        _loggerService.warning('Failed to set native encryption key: $e');
      }
      _loggerService.info('Handshake completed for session $sessionId');
    } catch (e) {
      _loggerService.error('Wi‑Fi Aware handshake failed for session $sessionId: $e');
      throw TransferException(message: 'Wi‑Fi Aware handshake failed: $e', code: 'HANDSHAKE_FAILED');
    }
  }

  void _emitProgress(String sessionId, String fileId, int bytesTransferred, int totalBytes, {String? fileName}) {
    if (!_progressControllers.containsKey(sessionId)) {
      _progressControllers[sessionId] = StreamController<unified.TransferProgress>.broadcast();
    }
    
    // Calculate speed based on time elapsed
    final now = DateTime.now();
    final startTime = _fileStartTimes['$sessionId:$fileId'] ?? now;
    final elapsedSeconds = now.difference(startTime).inMilliseconds / 1000.0;
    final speed = elapsedSeconds > 0 ? bytesTransferred / elapsedSeconds : 0.0;
    
    _progressControllers[sessionId]?.add(unified.TransferProgress(
      transferId: sessionId,
      fileId: fileId,
      fileName: fileName ?? 'Unknown',
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      progress: totalBytes > 0 ? bytesTransferred / totalBytes : 0.0,
      speed: speed,
      status: _mapNativeStatusToTransferStatus(bytesTransferred >= totalBytes && totalBytes > 0 ? 'completed' : 'in_progress'),
      startedAt: startTime,
    ));
    
    // Update benchmarking progress
    _benchmarkingService.updateProgress(
      transferId: '${sessionId}_${fileId}',
      bytesTransferred: bytesTransferred,
      currentSpeed: speed,
    );
  }

  Map<String, dynamic> _safeParseJson(String input) {
    try {
      return input.isNotEmpty ? (jsonDecode(input) as Map<String, dynamic>) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Await BLE remote public key from discovery/events channel
  Future<Uint8List> _awaitBleRemotePublicKey(String connectionToken) async {
    final Completer<Uint8List> completer = Completer<Uint8List>();
    late final StreamSubscription sub;
    sub = AirLinkPlugin.eventStream.listen((dynamic event) {
      try {
        final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
        final Map<dynamic, dynamic>? data = map['data'] as Map<dynamic, dynamic>?;
        if (data == null) return;
        if (data['connectionMethod'] == 'ble' && data['connectionToken'] == connectionToken && data.containsKey('publicKey')) {
          final List<dynamic> list = data['publicKey'] as List<dynamic>;
          final Uint8List key = Uint8List.fromList(list.cast<int>());
          if (!completer.isCompleted) {
            completer.complete(key);
          }
        }
      } catch (_) {}
    });
    try {
      return await completer.future.whenComplete(() async { await sub.cancel(); });
    } catch (e) {
      await sub.cancel();
      rethrow;
    }
  }

  String _joinPath(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return a + b;
    return a + Platform.pathSeparator + b;
  }

  unified.TransferStatus _mapNativeStatusToTransferStatus(String nativeStatus) {
    switch (nativeStatus.toLowerCase()) {
      case 'pending':
        return unified.TransferStatus.pending;
      case 'in_progress':
      case 'progress':
        return unified.TransferStatus.transferring;
      case 'paused':
        return unified.TransferStatus.paused;
      case 'completed':
        return unified.TransferStatus.completed;
      case 'failed':
      case 'error':
        return unified.TransferStatus.failed;
      case 'cancelled':
        return unified.TransferStatus.cancelled;
      default:
        return unified.TransferStatus.pending;
    }
  }


  /// Get benchmark for a specific transfer
  Future<TransferBenchmark?> getTransferBenchmark(String transferId) async {
    try {
      return await _benchmarkingService.getBenchmark(transferId);
    } catch (e) {
      _loggerService.error('Failed to get transfer benchmark: $e');
      return null;
    }
  }

  /// Get all transfer benchmarks
  Future<List<TransferBenchmark>> getTransferBenchmarks() async {
    try {
      return await _benchmarkingService.getAllBenchmarks();
    } catch (e) {
      _loggerService.error('Failed to get transfer benchmarks: $e');
      return [];
    }
  }

  /// Get benchmark statistics
  Future<Map<String, dynamic>> getBenchmarkStatistics() async {
    try {
      return await _benchmarkingService.generateReport();
    } catch (e) {
      _loggerService.error('Failed to get benchmark statistics: $e');
      return {};
    }
  }

  /// Send file metadata with checksum before file transfer
  Future<void> _sendFileMetadata(String sessionId, unified.TransferFile file, String connectionToken) async {
    try {
      // Retrieve stored checksum for this file
      final checksumRecord = await _checksumService.getStoredChecksum(sessionId, file.path);
      final checksum = checksumRecord?.checksum ?? '';
      
      // Prepare file metadata message
      final Map<String, dynamic> metadataMessage = {
        'type': 'file_meta',
        'fileId': file.id,
        'name': file.name,
        'size': file.size,
        'checksum': checksum,
      };
      
      // Send metadata via Wi-Fi Aware data channel
      final jsonString = jsonEncode(metadataMessage);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      final success = await AirLinkPlugin.sendWifiAwareData(connectionToken, bytes);
      if (success) {
        _loggerService.info('File metadata sent for ${file.name} with checksum: $checksum');
      } else {
        _loggerService.warning('Failed to send file metadata for ${file.name}');
      }
    } catch (e) {
      _loggerService.error('Error sending file metadata for ${file.name}: $e');
      // Don't throw - allow transfer to continue without metadata
    }
  }
}

class _FileReceiveState {
  final String fileId;
  final String path;
  final int expectedBytes;
  final String? checksum;
  late final RandomAccessFile _raf;
  int writtenBytes = 0;
  _FileReceiveState({
    required this.fileId,
    required this.path,
    required this.expectedBytes,
    required this.checksum,
  });
  Future<void> open() async {
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    _raf = await file.open(mode: FileMode.write);
  }
  Future<void> writeChunk(List<int> data, {int offset = -1}) async {
    if (offset >= 0) {
      await _raf.setPosition(offset);
    }
    await _raf.writeFrom(data);
    writtenBytes += data.length;
  }
  Future<void> close() async {
    await _raf.close();
  }
  Future<bool> verifyChecksum() async {
    if (checksum == null || checksum!.isEmpty) return true;
    final file = File(path);
    if (!await file.exists()) return false;
    // Stream hashing to avoid high memory usage
    final Stream<List<int>> stream = file.openRead();
    final String actual = await sha256.bind(stream).first.then((d) => d.toString());
    return actual.toLowerCase() == checksum!.toLowerCase();
  }
}

/// Extension to add missing methods to TransferRepositoryImpl
extension TransferRepositoryImplExtensions on TransferRepositoryImpl {
  /// Get active transfer count
  int getActiveTransferCount() {
    return _activeTransfers.length;
  }
}
