import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/crypto_service.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/core/errors/exceptions.dart';
import 'package:uuid/uuid.dart';
import 'package:injectable/injectable.dart';

enum TransferConnectionType {
  wifiAware,
  ble,
  webrtc,
  hotspot,
  cloudRelay,
}

enum TransferDirection {
  send,
  receive,
  bidirectional,
}

class TransferConnection {
  final String id;
  final String deviceId;
  final TransferConnectionType type;
  final bool isActive;
  final DateTime connectedAt;
  final Map<String, dynamic> metadata;
  
  const TransferConnection({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.isActive,
    required this.connectedAt,
    required this.metadata,
  });
  
  TransferConnection copyWith({
    String? id,
    String? deviceId,
    TransferConnectionType? type,
    bool? isActive,
    DateTime? connectedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TransferConnection(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      connectedAt: connectedAt ?? this.connectedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

@injectable
class TransferStrategyService {
  final LoggerService _loggerService;
  final CryptoService _cryptoService;
  final Uuid _uuid = const Uuid();
  
  final List<TransferConnection> _activeConnections = [];
  final List<unified.TransferSession> _activeSessions = [];
  final Map<String, StreamController<unified.TransferProgress>> _progressControllers = {};
  
  final StreamController<List<TransferConnection>> _connectionsController = StreamController<List<TransferConnection>>.broadcast();
  final StreamController<List<unified.TransferSession>> _sessionsController = StreamController<List<unified.TransferSession>>.broadcast();
  
  Stream<List<TransferConnection>> get connectionsStream => _connectionsController.stream;
  Stream<List<unified.TransferSession>> get sessionsStream => _sessionsController.stream;
  List<TransferConnection> get activeConnections => List.from(_activeConnections);
  List<unified.TransferSession> get activeSessions => List.from(_activeSessions);
  
  TransferStrategyService({
    required LoggerService loggerService,
    required CryptoService cryptoService,
  }) : _loggerService = loggerService,
       _cryptoService = cryptoService;
  
  Future<TransferConnection> establishConnection({
    required String deviceId,
    required TransferConnectionType preferredType,
    required TransferDirection direction,
  }) async {
    try {
      _loggerService.info('Establishing connection to device: $deviceId with type: $preferredType');
      
      // Try preferred connection type first
      TransferConnection? connection = await _tryConnectionType(deviceId, preferredType, direction);
      
      // If preferred type fails, try fallback types
      if (connection == null) {
        final fallbackTypes = _getFallbackConnectionTypes(preferredType);
        for (final type in fallbackTypes) {
          connection = await _tryConnectionType(deviceId, type, direction);
          if (connection != null) break;
        }
      }
      
      if (connection == null) {
        throw TransferException(
          message: 'Failed to establish connection to device: $deviceId',
        );
      }
      
      _activeConnections.add(connection);
      _connectionsController.add(_activeConnections);
      
      _loggerService.info('Successfully established connection: ${connection.id}');
      return connection;
    } catch (e) {
      _loggerService.error('Failed to establish connection: $e');
      throw TransferException(
        message: 'Failed to establish connection: $e',
      );
    }
  }
  
  Future<void> closeConnection(String connectionId) async {
    try {
      _loggerService.info('Closing connection: $connectionId');
      
      final connection = _activeConnections.firstWhere(
        (c) => c.id == connectionId,
        orElse: () => throw TransferException(
          message: 'Connection not found: $connectionId',
        ),
      );
      
      await _closeConnectionType(connection);
      
      _activeConnections.removeWhere((c) => c.id == connectionId);
      _connectionsController.add(_activeConnections);
      
      _loggerService.info('Connection closed: $connectionId');
    } catch (e) {
      _loggerService.error('Failed to close connection: $e');
      throw TransferException(
        message: 'Failed to close connection: $e',
      );
    }
  }
  
  Future<String> startTransferSession({
    required String connectionId,
    required List<unified.TransferFile> files,
    required TransferDirection direction,
  }) async {
    try {
      final sessionId = _uuid.v4();
      _loggerService.info('Starting transfer session: $sessionId');
      
      final connection = _activeConnections.firstWhere(
        (c) => c.id == connectionId,
        orElse: () => throw TransferException(
          message: 'Connection not found: $connectionId',
        ),
      );
      
      // Generate encryption key for this session
      // TODO: Exchange public keys with the other device and perform key exchange
      // For now, we'll use a placeholder shared secret
      final sharedSecret = Uint8List(32); // This should be the result of key exchange
      final encryptionKey = _cryptoService.deriveEncryptionKey(sharedSecret);
      
      final session = unified.TransferSession(
        id: sessionId,
        targetDeviceId: connection.deviceId,
        files: files,
        connectionMethod: connection.type.toString(),
        status: unified.TransferStatus.pending,
        createdAt: DateTime.now(),
        direction: _mapDirectionToUnified(direction),
      );
      
      _activeSessions.add(session);
      _sessionsController.add(_activeSessions);
      
      // Start transfer based on direction
      if (direction == TransferDirection.send || direction == TransferDirection.bidirectional) {
        _startSendingFiles(session, await encryptionKey);
      }
      
      if (direction == TransferDirection.receive || direction == TransferDirection.bidirectional) {
        _startReceivingFiles(session, await encryptionKey);
      }
      
      _loggerService.info('Transfer session started: $sessionId');
      return sessionId;
    } catch (e) {
      _loggerService.error('Failed to start transfer session: $e');
      throw TransferException(
        message: 'Failed to start transfer session: $e',
      );
    }
  }
  
  Future<void> pauseTransferSession(String sessionId) async {
    try {
      _loggerService.info('Pausing transfer session: $sessionId');
      
      final session = _activeSessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(
          message: 'Transfer session not found: $sessionId',
        ),
      );
      
      final updatedSession = session.copyWith(status: unified.TransferStatus.paused);
      _updateSession(updatedSession);
      
      _loggerService.info('Transfer session paused: $sessionId');
    } catch (e) {
      _loggerService.error('Failed to pause transfer session: $e');
      throw TransferException(
        message: 'Failed to pause transfer session: $e',
      );
    }
  }
  
  Future<void> resumeTransferSession(String sessionId) async {
    try {
      _loggerService.info('Resuming transfer session: $sessionId');
      
      final session = _activeSessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(
          message: 'Transfer session not found: $sessionId',
        ),
      );
      
      final updatedSession = session.copyWith(status: unified.TransferStatus.transferring);
      _updateSession(updatedSession);
      
      _loggerService.info('Transfer session resumed: $sessionId');
    } catch (e) {
      _loggerService.error('Failed to resume transfer session: $e');
      throw TransferException(
        message: 'Failed to resume transfer session: $e',
      );
    }
  }
  
  Future<void> cancelTransferSession(String sessionId) async {
    try {
      _loggerService.info('Cancelling transfer session: $sessionId');
      
      final session = _activeSessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw TransferException(
          message: 'Transfer session not found: $sessionId',
        ),
      );
      
      final updatedSession = session.copyWith(
        status: unified.TransferStatus.cancelled,
        completedAt: DateTime.now(),
      );
      _updateSession(updatedSession);
      
      _activeSessions.removeWhere((s) => s.id == sessionId);
      _sessionsController.add(_activeSessions);
      
      _loggerService.info('Transfer session cancelled: $sessionId');
    } catch (e) {
      _loggerService.error('Failed to cancel transfer session: $e');
      throw TransferException(
        message: 'Failed to cancel transfer session: $e',
      );
    }
  }
  
  Stream<unified.TransferProgress> getTransferProgress(String sessionId) {
    if (!_progressControllers.containsKey(sessionId)) {
      _progressControllers[sessionId] = StreamController<unified.TransferProgress>.broadcast();
    }
    return _progressControllers[sessionId]!.stream;
  }
  
  Future<TransferConnection?> _tryConnectionType(
    String deviceId,
    TransferConnectionType type,
    TransferDirection direction,
  ) async {
    try {
      switch (type) {
        case TransferConnectionType.wifiAware:
          return await _establishWifiAwareConnection(deviceId, direction);
        case TransferConnectionType.ble:
          return await _establishBLEConnection(deviceId, direction);
        case TransferConnectionType.webrtc:
          return await _establishWebRTCConnection(deviceId, direction);
        case TransferConnectionType.hotspot:
          return await _establishHotspotConnection(deviceId, direction);
        case TransferConnectionType.cloudRelay:
          return await _establishCloudRelayConnection(deviceId, direction);
      }
    } catch (e) {
      _loggerService.warning('Failed to establish $type connection: $e');
      return null;
    }
  }
  
  Future<TransferConnection> _establishWifiAwareConnection(String deviceId, TransferDirection direction) async {
    // TODO: Implement Wi-Fi Aware connection
    _loggerService.info('Establishing Wi-Fi Aware connection to: $deviceId');
    
    return TransferConnection(
      id: _uuid.v4(),
      deviceId: deviceId,
      type: TransferConnectionType.wifiAware,
      isActive: true,
      connectedAt: DateTime.now(),
      metadata: {
        'direction': direction.toString(),
        'bandwidth': 'high',
        'latency': 'low',
      },
    );
  }
  
  Future<TransferConnection> _establishBLEConnection(String deviceId, TransferDirection direction) async {
    // TODO: Implement BLE connection
    _loggerService.info('Establishing BLE connection to: $deviceId');
    
    return TransferConnection(
      id: _uuid.v4(),
      deviceId: deviceId,
      type: TransferConnectionType.ble,
      isActive: true,
      connectedAt: DateTime.now(),
      metadata: {
        'direction': direction.toString(),
        'bandwidth': 'low',
        'latency': 'medium',
      },
    );
  }
  
  Future<TransferConnection> _establishWebRTCConnection(String deviceId, TransferDirection direction) async {
    // TODO: Implement WebRTC connection
    _loggerService.info('Establishing WebRTC connection to: $deviceId');
    
    return TransferConnection(
      id: _uuid.v4(),
      deviceId: deviceId,
      type: TransferConnectionType.webrtc,
      isActive: true,
      connectedAt: DateTime.now(),
      metadata: {
        'direction': direction.toString(),
        'bandwidth': 'medium',
        'latency': 'low',
      },
    );
  }
  
  Future<TransferConnection> _establishHotspotConnection(String deviceId, TransferDirection direction) async {
    // TODO: Implement hotspot connection
    _loggerService.info('Establishing hotspot connection to: $deviceId');
    
    return TransferConnection(
      id: _uuid.v4(),
      deviceId: deviceId,
      type: TransferConnectionType.hotspot,
      isActive: true,
      connectedAt: DateTime.now(),
      metadata: {
        'direction': direction.toString(),
        'bandwidth': 'medium',
        'latency': 'medium',
      },
    );
  }
  
  Future<TransferConnection> _establishCloudRelayConnection(String deviceId, TransferDirection direction) async {
    // TODO: Implement cloud relay connection
    _loggerService.info('Establishing cloud relay connection to: $deviceId');
    
    return TransferConnection(
      id: _uuid.v4(),
      deviceId: deviceId,
      type: TransferConnectionType.cloudRelay,
      isActive: true,
      connectedAt: DateTime.now(),
      metadata: {
        'direction': direction.toString(),
        'bandwidth': 'variable',
        'latency': 'high',
      },
    );
  }
  
  Future<void> _closeConnectionType(TransferConnection connection) async {
    switch (connection.type) {
      case TransferConnectionType.wifiAware:
        await _closeWifiAwareConnection(connection);
        break;
      case TransferConnectionType.ble:
        await _closeBLEConnection(connection);
        break;
      case TransferConnectionType.webrtc:
        await _closeWebRTCConnection(connection);
        break;
      case TransferConnectionType.hotspot:
        await _closeHotspotConnection(connection);
        break;
      case TransferConnectionType.cloudRelay:
        await _closeCloudRelayConnection(connection);
        break;
    }
  }
  
  Future<void> _closeWifiAwareConnection(TransferConnection connection) async {
    // TODO: Implement Wi-Fi Aware connection close
    _loggerService.info('Closing Wi-Fi Aware connection: ${connection.id}');
  }
  
  Future<void> _closeBLEConnection(TransferConnection connection) async {
    // TODO: Implement BLE connection close
    _loggerService.info('Closing BLE connection: ${connection.id}');
  }
  
  Future<void> _closeWebRTCConnection(TransferConnection connection) async {
    // TODO: Implement WebRTC connection close
    _loggerService.info('Closing WebRTC connection: ${connection.id}');
  }
  
  Future<void> _closeHotspotConnection(TransferConnection connection) async {
    // TODO: Implement hotspot connection close
    _loggerService.info('Closing hotspot connection: ${connection.id}');
  }
  
  Future<void> _closeCloudRelayConnection(TransferConnection connection) async {
    // TODO: Implement cloud relay connection close
    _loggerService.info('Closing cloud relay connection: ${connection.id}');
  }
  
  List<TransferConnectionType> _getFallbackConnectionTypes(TransferConnectionType preferredType) {
    switch (preferredType) {
      case TransferConnectionType.wifiAware:
        return [
          TransferConnectionType.webrtc,
          TransferConnectionType.hotspot,
          TransferConnectionType.ble,
          TransferConnectionType.cloudRelay,
        ];
      case TransferConnectionType.ble:
        return [
          TransferConnectionType.webrtc,
          TransferConnectionType.hotspot,
          TransferConnectionType.cloudRelay,
        ];
      case TransferConnectionType.webrtc:
        return [
          TransferConnectionType.hotspot,
          TransferConnectionType.ble,
          TransferConnectionType.cloudRelay,
        ];
      case TransferConnectionType.hotspot:
        return [
          TransferConnectionType.ble,
          TransferConnectionType.cloudRelay,
        ];
      case TransferConnectionType.cloudRelay:
        return []; // No fallbacks for cloud relay
    }
  }
  
  void _startSendingFiles(unified.TransferSession session, Uint8List encryptionKey) async {
    try {
      _loggerService.info('Starting file sending for session: ${session.id}');
      
      for (final file in session.files) {
        await _sendFile(session, file, encryptionKey);
      }
      
      final completedSession = session.copyWith(
        status: unified.TransferStatus.completed,
        completedAt: DateTime.now(),
      );
      _updateSession(completedSession);
      
      _loggerService.info('File sending completed for session: ${session.id}');
    } catch (e) {
      _loggerService.error('Failed to send files for session ${session.id}: $e');
      
      final errorSession = session.copyWith(
        status: unified.TransferStatus.failed,
        completedAt: DateTime.now(),
      );
      _updateSession(errorSession);
    }
  }
  
  void _startReceivingFiles(unified.TransferSession session, Uint8List encryptionKey) async {
    try {
      _loggerService.info('Starting file receiving for session: ${session.id}');
      
      // TODO: Implement file receiving logic
      
      _loggerService.info('File receiving completed for session: ${session.id}');
    } catch (e) {
      _loggerService.error('Failed to receive files for session ${session.id}: $e');
    }
  }
  
  Future<void> _sendFile(unified.TransferSession session, unified.TransferFile file, Uint8List encryptionKey) async {
    try {
      _loggerService.info('Sending file: ${file.name}');
      
      final filePath = file.path;
      final fileSize = file.size;
      
      int bytesTransferred = 0;
      
      // Read and send file in chunks
      final fileStream = File(filePath).openRead();
      await for (final chunk in fileStream) {
        // Encrypt chunk
        final encryptedChunk = _cryptoService.encryptData(Uint8List.fromList(chunk), encryptionKey);
        
        // Send encrypted chunk
        await _sendChunk(session, encryptedChunk);
        
        bytesTransferred += chunk.length;
        
        // Update progress
        final progress = unified.TransferProgress(
          transferId: session.id,
          fileId: file.id,
          fileName: file.name,
          bytesTransferred: bytesTransferred,
          totalBytes: fileSize,
          progress: bytesTransferred / fileSize,
          speed: 0.0,
          status: unified.TransferStatus.transferring,
          startedAt: DateTime.now(),
        );
        
        _progressControllers[session.id]?.add(progress);
        
        // Simulate network delay
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      _loggerService.info('File sent successfully: ${file.name}');
    } catch (e) {
      _loggerService.error('Failed to send file ${file.name}: $e');
      throw TransferException(
        message: 'Failed to send file: ${file.name}',
      );
    }
  }
  
  Future<void> _sendChunk(unified.TransferSession session, EncryptedData encryptedChunk) async {
    // TODO: Implement actual network transmission based on connection type
    // This would involve sending the encrypted chunk over the established connection
    await Future.delayed(const Duration(milliseconds: 1));
  }
  
  void _updateSession(unified.TransferSession session) {
    final index = _activeSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _activeSessions[index] = session;
    } else {
      _activeSessions.add(session);
    }
    _sessionsController.add(_activeSessions);
  }
  
  /// Map TransferDirection to unified.TransferDirection
  unified.TransferDirection _mapDirectionToUnified(TransferDirection direction) {
    switch (direction) {
      case TransferDirection.send:
        return unified.TransferDirection.sent;
      case TransferDirection.receive:
        return unified.TransferDirection.received;
      case TransferDirection.bidirectional:
        return unified.TransferDirection.sent; // Default to sent for bidirectional
    }
  }

  void dispose() {
    _connectionsController.close();
    _sessionsController.close();
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
  }
}
