import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:airlink/core/protocol/frame.dart';
import 'package:airlink/core/protocol/handshake.dart';
import 'package:airlink/core/protocol/reliability.dart';
import 'package:airlink/core/protocol/protocol_constants.dart';
import 'package:airlink/core/security/crypto.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:airlink/core/services/rate_limiting_service.dart';
import 'package:airlink/core/services/logger_service.dart';

/// Socket Manager for AirLink Protocol
///
/// Manages CONTROL and DATA channels over a single socket (multiplexed)
class SocketManager {
  Socket? _socket;
  StreamSubscription<Uint8List>? _dataSubscription;
  final StreamController<ProtocolFrame> _frameController =
      StreamController<ProtocolFrame>.broadcast();
  final StreamController<AckFrame> _ackController =
      StreamController<AckFrame>.broadcast();
  final StreamController<ProtocolFrame> _controlController =
      StreamController<ProtocolFrame>.broadcast();

  // Protocol components
  late HandshakeProtocol _handshake;
  late ReliabilityProtocol _reliability;

  // Security components
  final RateLimitingService _rateLimitingService;
  final LoggerService _loggerService = LoggerService();
  // Removed unused _invalidFrameCounts; violations tracked via RateLimitingService

  // Connection state
  bool _isConnected = false;
  bool _isHandshakeComplete = false;
  Uint8List? _encryptionKey;
  Uint8List? _remotePublicKey;
  final Function(String)? _onSessionKey;
  String? _connectionId;
  Map<String, dynamic>? _remoteCapabilities;

  // Reconnection state
  String? _lastHost;
  int? _lastPort;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseReconnectDelay = Duration(seconds: 1);

  SocketManager({
    required String deviceId,
    required Map<String, dynamic> capabilities,
    required RateLimitingService rateLimitingService,
    Function(String)? onSessionKey,
  }) : _rateLimitingService = rateLimitingService,
       _onSessionKey = onSessionKey {
    _handshake = HandshakeProtocol(
      deviceId: deviceId,
      capabilities: capabilities,
    );
    
    _reliability = ReliabilityProtocol(
      windowSize: ProtocolConstants.defaultWindowSize,
      chunkSize: ProtocolConstants.defaultChunkSize,
      onFrameSend: _sendFrame,
      onAckReceived: _processAck,
      onChunkDelivered: _onChunkDelivered,
    );
  }

  /// Connect to remote device
  Future<bool> connect(String host, int port) async {
    try {
      _lastHost = host;
      _lastPort = port;
      _reconnectAttempts = 0;

      // Generate connection ID for rate limiting
      _connectionId = 'conn_${DateTime.now().millisecondsSinceEpoch}_${host.hashCode}';

      // Check rate limiting for connection attempts
      final deviceId = 'device_${host.hashCode}';
      final canConnect = _rateLimitingService.isConnectionAllowed(deviceId);
      if (!canConnect) {
        _loggerService.warning('Connection attempt blocked by rate limiting for device: $deviceId');
        return false;
      }

      _socket = await Socket.connect(host, port,
          timeout: ProtocolConstants.connectionTimeout);

      _isConnected = true;
      _setupDataHandler();

      // Start handshake process
      return await _performHandshake();
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Accept incoming connection
  Future<bool> accept(Socket socket) async {
    try {
      _socket = socket;
      _isConnected = true;
      _setupDataHandler();
      
      // Start handshake process
      return await _performHandshake();
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Setup data handler for incoming frames
  void _setupDataHandler() {
    _dataSubscription = _socket!.listen(
      _processIncomingData,
      onError: _onSocketError,
      onDone: _onSocketClosed,
    );
  }

  /// Process incoming data and parse frames with length-prefixed framing
  final List<int> _frameBuffer = [];
  int? _expectedFrameLength;

  void _processIncomingData(Uint8List data) async {
    try {
      // Add data to frame buffer
      _frameBuffer.addAll(data);
      
      // Process complete frames from buffer
      while (true) {
        // Read frame length if we don't have it yet
        if (_expectedFrameLength == null) {
          if (_frameBuffer.length < 4) {
            // Not enough data for length prefix
            break;
          }
          
          // Read 4-byte length prefix (big-endian)
          _expectedFrameLength = 
              (_frameBuffer[0] << 24) |
              (_frameBuffer[1] << 16) |
              (_frameBuffer[2] << 8) |
              _frameBuffer[3];
          
          // Validate frame length to prevent buffer exhaustion attacks
          if (_expectedFrameLength! <= 0 || _expectedFrameLength! > ProtocolConstants.maxFrameSize) {
            // Track invalid frame violations for rate limiting
            final connectionId = _connectionId ?? 'unknown';
            _rateLimitingService.recordInvalidFrame(connectionId);

            // Check if we've exceeded the threshold for invalid frames
            if (!_rateLimitingService.isInvalidFrameAllowed(connectionId)) {
              _loggerService.warning('Connection blocked due to excessive invalid frames: $connectionId');
              _closeConnection();
              return;
            }

            // Log error and clear buffer to prevent unbounded growth
            _loggerService.error('Invalid frame length: $_expectedFrameLength (max: ${ProtocolConstants.maxFrameSize}) for connection: $connectionId');
            _frameBuffer.clear();
            _expectedFrameLength = null;
            throw ProtocolException(
              message: 'Invalid frame length: $_expectedFrameLength',
              code: 'INVALID_FRAME_LENGTH'
            );
          }
          
          // Remove length prefix from buffer
          _frameBuffer.removeRange(0, 4);
        }
        
        // Check if we have complete frame
        if (_frameBuffer.length < _expectedFrameLength!) {
          // Not enough data for complete frame
          break;
        }
        
        // Extract frame data
        final frameData = Uint8List.fromList(
          _frameBuffer.sublist(0, _expectedFrameLength!)
        );
        _frameBuffer.removeRange(0, _expectedFrameLength!);
        _expectedFrameLength = null;
        
        // Parse and handle frame
        final frame = ProtocolFrame.fromBytes(frameData);
        
        if (frame.frameType == ProtocolConstants.frameTypeControl) {
          _handleControlFrame(frame);
        } else if (frame.frameType == ProtocolConstants.frameTypeData) {
          _handleDataFrame(frame);
        }
      }
    } catch (e) {
      // Handle frame parsing errors
      if (e is ProtocolException) {
        // Log protocol-specific errors
        _loggerService.error('Protocol error: ${e.message}');
        // For protocol violations, we should close the connection
        _closeConnection();
      } else {
        // Handle other frame parsing errors
        _loggerService.error('Error parsing frame: $e');
      }
      // Reset frame buffer on error to prevent unbounded growth
      _frameBuffer.clear();
      _expectedFrameLength = null;
    }
  }

  /// Handle control frames
  void _handleControlFrame(ProtocolFrame frame) {
    // Emit all control frames to the control stream for handshake listeners
    _controlController.add(frame);
    
    // Process control messages based on explicit subtype
    if (frame.controlSubtype == ProtocolConstants.controlSubtypeAck) {
      final ack = AckFrame.fromBytes(frame.encryptedPayload);
      _ackController.add(ack);
    }
  }

  /// Handle data frames
  void _handleDataFrame(ProtocolFrame frame) async {
    if (!_isHandshakeComplete || _encryptionKey == null) {
      // Frame received before handshake complete, ignore
      return;
    }

    try {
      // Create AAD (Additional Authenticated Data) with transfer metadata
      // Use consistent 32-bit types for both transferId and offset
      final aad = Uint8List.fromList([
        ...Int32List.fromList([frame.transferId]).buffer.asUint8List(),
        ...Int32List.fromList([frame.offset.toInt()]).buffer.asUint8List(),
      ]);
      
      // Split encrypted payload into ciphertext and tag
      final ciphertextLength = frame.encryptedPayload.length - 16; // 16 bytes for tag
      final ciphertext = frame.encryptedPayload.sublist(0, ciphertextLength);
      final tag = frame.encryptedPayload.sublist(ciphertextLength);
      
      // Decrypt the frame payload using AES-GCM
      final plaintext = await AirLinkCrypto.aesGcmDecrypt(
        _encryptionKey!,
        frame.iv,
        aad,
        ciphertext,
        tag,
      );
      
      // Create decrypted frame
      final decryptedFrame = ProtocolFrame(
        frameType: frame.frameType,
        transferId: frame.transferId,
        offset: frame.offset,
        payloadLength: plaintext.length,
        iv: frame.iv,
        encryptedPayload: plaintext,
        chunkHash: frame.chunkHash,
      );
      
      _frameController.add(decryptedFrame);
    } catch (e) {
      _loggerService.error('Error decrypting data frame: $e');
    }
  }

  /// Perform handshake protocol
  Future<bool> _performHandshake() async {
    try {
      // Step 1: Exchange discovery payloads
      final discoveryPayload = _handshake.createDiscoveryPayload();
      await _sendDiscoveryPayload(discoveryPayload);
      
      // Wait for remote discovery payload
      final remotePayload = await _waitForDiscoveryPayload();
      if (!await _handshake.processDiscoveryPayload(remotePayload)) {
        return false;
      }

      // Step 2: Perform key exchange
      final keyExchangeResult = await _handshake.performKeyExchange();
      if (!keyExchangeResult.isSuccess) {
        return false;
      }

      // Step 3: Send local public key and receive remote public key
      final localPublicKey = keyExchangeResult.localKeyPair!.publicKey;
      await _sendPublicKey(localPublicKey);
      final remotePublicKey = await _waitForPublicKey();

      // Step 4: Complete key derivation with real remote public key
      final keyDerivationResult = await _handshake.completeKeyExchange(
        sessionId: _connectionId ?? 'unknown_session',
        localPublicKey: keyExchangeResult.localKeyPair!.publicKey,
        remotePublicKey: remotePublicKey,
        localKeyPair: keyExchangeResult.localKeyPair!,
      );

      if (!keyDerivationResult.isSuccess) {
        return false;
      }

      _encryptionKey = keyDerivationResult.derivedKey;
      _remotePublicKey = remotePublicKey;
      _isHandshakeComplete = true;
      
      // Verify encryption key is not all zeros
      bool isKeyAllZeros = true;
      for (int i = 0; i < _encryptionKey!.length; i++) {
        if (_encryptionKey![i] != 0) {
          isKeyAllZeros = false;
          break;
        }
      }
      
      if (isKeyAllZeros) {
        return false;
      }
      
      // Notify protocol layer of session key (base64 encoded)
      if (_onSessionKey != null && _encryptionKey != null) {
        final sessionKeyBase64 = base64.encode(_encryptionKey!);
        _onSessionKey(sessionKeyBase64);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send discovery payload using framed protocol
  Future<void> _sendDiscoveryPayload(DiscoveryPayload payload) async {
    final data = payload.toBytes();
    
    // Create control frame for discovery payload
    final frame = ProtocolFrame.control(
      transferId: 0, // Discovery uses transferId 0
      offset: 0,
      payload: data,
      iv: Uint8List(ProtocolConstants.ivLength), // Zero IV for discovery
      hash: Uint8List(ProtocolConstants.hashLength), // Zero hash for discovery
      controlSubtype: ProtocolConstants.controlSubtypeDiscovery,
    );
    
    _sendFrame(frame);
  }

  /// Wait for remote discovery payload using framed protocol
  Future<DiscoveryPayload> _waitForDiscoveryPayload() async {
    final completer = Completer<DiscoveryPayload>();
    
    // Use the dedicated control stream to wait for discovery payload
    late StreamSubscription<ProtocolFrame> controlSubscription;
    
    controlSubscription = _controlController.stream.listen((frame) {
      try {
        // Parse discovery payload from control frame
        final payload = DiscoveryPayload.fromBytes(frame.encryptedPayload);
        if (!completer.isCompleted) {
          // Store remote capabilities for chunk size negotiation
          _remoteCapabilities = payload.capabilities;
          completer.complete(payload);
          controlSubscription.cancel();
        }
      } catch (e) {
        // Continue waiting for valid discovery payload
      }
    });

    // Timeout after discovery timeout
    Timer(ProtocolConstants.discoveryTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError('Discovery timeout');
        controlSubscription.cancel();
      }
    });

    final payload = await completer.future;
    return payload;
  }

  /// Send public key using framed protocol
  Future<void> _sendPublicKey(Uint8List publicKey) async {
    // Create control frame for public key exchange
    final frame = ProtocolFrame.control(
      transferId: 0, // Key exchange uses transferId 0
      offset: 0,
      payload: publicKey,
      iv: Uint8List(ProtocolConstants.ivLength), // Zero IV for key exchange
      hash: Uint8List(ProtocolConstants.hashLength), // Zero hash for key exchange
      controlSubtype: ProtocolConstants.controlSubtypeKeyExchange,
    );
    
    _sendFrame(frame);
  }

  /// Wait for remote public key using framed protocol
  Future<Uint8List> _waitForPublicKey() async {
    final completer = Completer<Uint8List>();
    
    // Use the dedicated control stream to wait for public key
    late StreamSubscription<ProtocolFrame> controlSubscription;
    
    controlSubscription = _controlController.stream.listen((frame) {
      try {
        // Parse public key from control frame
        final publicKey = frame.encryptedPayload;
        if (publicKey.length == 32) { // X25519 public key is 32 bytes
          if (!completer.isCompleted) {
            completer.complete(publicKey);
            controlSubscription.cancel();
          }
        }
      } catch (e) {
        // Continue waiting for valid public key
      }
    });

    // Timeout after key exchange timeout
    Timer(ProtocolConstants.discoveryTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError('Key exchange timeout');
        controlSubscription.cancel();
      }
    });

    final publicKey = await completer.future;
    return publicKey;
  }

  /// Send frame over socket with length-prefixed framing
  void _sendFrame(ProtocolFrame frame) {
    if (_socket != null && _isConnected) {
      final frameData = frame.toBytes();
      
      // Create length prefix (4 bytes, big-endian)
      final lengthPrefix = Uint8List(4);
      lengthPrefix[0] = (frameData.length >> 24) & 0xFF;
      lengthPrefix[1] = (frameData.length >> 16) & 0xFF;
      lengthPrefix[2] = (frameData.length >> 8) & 0xFF;
      lengthPrefix[3] = frameData.length & 0xFF;
      
      // Send length prefix followed by frame data
      _socket!.add(lengthPrefix);
      _socket!.add(frameData);
    }
  }

  /// Process ACK frame
  void _processAck(AckFrame ack) {
    _reliability.processAck(ack);
  }

  /// Handle chunk delivery
  void _onChunkDelivered(int transferId, int offset) {
    // Notify upper layers of chunk delivery
    _loggerService.debug('Chunk delivered: transferId=$transferId, offset=$offset');
  }

  /// Send data with reliability and proper encryption
  Future<void> sendData({
    required int transferId,
    required int offset,
    required Uint8List data,
  }) async {
    if (!_isHandshakeComplete || _encryptionKey == null) {
      throw Exception('Handshake not complete');
    }

    try {
      // Generate random IV for AES-GCM (12 bytes)
      final iv = await AirLinkCrypto.generateIV();
      
      // Verify IV is not all zeros (security check)
      bool isIvAllZeros = true;
      for (int i = 0; i < iv.length; i++) {
        if (iv[i] != 0) {
          isIvAllZeros = false;
          break;
        }
      }
      
      if (isIvAllZeros) {
        throw Exception('Generated IV is all zeros - security violation');
      }
      
      // Create AAD (Additional Authenticated Data) with transfer metadata
      // Use consistent 32-bit types for both transferId and offset
      final aad = Uint8List.fromList([
        ...Int32List.fromList([transferId]).buffer.asUint8List(),
        ...Int32List.fromList([offset.toInt()]).buffer.asUint8List(),
      ]);
      
      // Encrypt data using AES-GCM
      final encryptionResult = await AirLinkCrypto.aesGcmEncrypt(
        _encryptionKey!,
        iv,
        aad,
        data,
      );
      
      // Calculate SHA-256 hash of the plaintext chunk
      final hash = await AirLinkCrypto.chunkSHA256(data);
      
      // Combine ciphertext and authentication tag
      final encryptedData = encryptionResult.combined;

      // Send with reliability
      await _reliability.sendChunk(
        transferId: transferId,
        offset: offset,
        data: encryptedData,
        iv: iv,
        hash: hash,
      );
    } catch (e) {
      _loggerService.error('Error sending encrypted data: $e');
      rethrow;
    }
  }

  /// Send ACK frame (ACKs are not encrypted for performance)
  Future<void> sendAck(AckFrame ack) async {
    if (_socket != null && _isConnected) {
      final ackBytes = ack.toBytes();
      
      // ACKs use zero IV and hash since they're control frames
      // and don't contain sensitive data
      final iv = Uint8List(ProtocolConstants.ivLength);
      final hash = Uint8List(ProtocolConstants.hashLength);
      
      final frame = ProtocolFrame.control(
        transferId: ack.transferId,
        offset: ack.offset,
        payload: ackBytes,
        iv: iv,
        hash: hash,
        controlSubtype: ProtocolConstants.controlSubtypeAck,
      );
      
      // Send with length prefix
      _sendFrame(frame);
    }
  }

  /// Get connection statistics
  TransferStats getStats() {
    final baseStats = _reliability.getStats();
    
    // Enhance with additional connection stats
    return TransferStats(
      totalChunks: baseStats.totalChunks,
      ackedChunks: baseStats.ackedChunks,
      inFlightChunks: baseStats.inFlightChunks,
      failedChunks: baseStats.failedChunks,
      windowSize: baseStats.windowSize,
      windowStart: baseStats.windowStart,
      bytesTransferred: baseStats.bytesTransferred,
      bytesReceived: baseStats.bytesReceived,
      transferRate: baseStats.transferRate,
      averageRTT: _calculateAverageRTT(),
      packetLoss: _calculatePacketLoss(),
      reconnectionAttempts: _reconnectAttempts,
      isConnected: _isConnected,
      isHandshakeComplete: _isHandshakeComplete,
    );
  }

  /// Calculate average RTT from reliability protocol
  double _calculateAverageRTT() {
    // This would be implemented in ReliabilityProtocol
    // For now, return a placeholder
    return 0.0;
  }

  /// Calculate packet loss percentage
  double _calculatePacketLoss() {
    // This would be implemented in ReliabilityProtocol
    // For now, return a placeholder
    return 0.0;
  }

  /// Check if connected
  bool get isConnected => _isConnected && _isHandshakeComplete;

  /// Get frame stream
  Stream<ProtocolFrame> get frameStream => _frameController.stream;

  /// Get ACK stream
  Stream<AckFrame> get ackStream => _ackController.stream;

  /// Get control frame stream
  Stream<ProtocolFrame> get controlStream => _controlController.stream;

  /// Get remote public key
  Uint8List? get remotePublicKey => _remotePublicKey;
  
  /// Get remote capabilities
  Map<String, dynamic>? get remoteCapabilities => _remoteCapabilities;

  /// Attempt reconnection with exponential backoff
  void _attemptReconnection() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _loggerService.warning('Max reconnection attempts reached');
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: _baseReconnectDelay.inMilliseconds * 
      (1 << (_reconnectAttempts - 1)), // Exponential backoff
    );
    
    _loggerService.info('Attempting reconnection $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () async {
      try {
        if (_lastHost != null && _lastPort != null) {
          final success = await connect(_lastHost!, _lastPort!);
          if (success) {
            _loggerService.info('Reconnection successful');
            _reconnectAttempts = 0; // Reset on successful reconnection
          } else {
            _attemptReconnection(); // Try again
          }
        }
      } catch (e) {
        _loggerService.error('Reconnection failed: $e');
        _attemptReconnection(); // Try again
      }
    });
  }

  /// Handle socket errors
  void _onSocketError(dynamic error) {
    _loggerService.error('Socket error: $error');
    _isConnected = false;
    _isHandshakeComplete = false;
    
    // Attempt reconnection if we have connection details
    if (_lastHost != null && _lastPort != null) {
      _attemptReconnection();
    }
  }

  /// Handle socket closure
  void _onSocketClosed() {
    _loggerService.info('Socket closed');
    _isConnected = false;
    _isHandshakeComplete = false;
    
    // Attempt reconnection if we have connection details
    if (_lastHost != null && _lastPort != null) {
      _attemptReconnection();
    }
  }

  /// Close connection
  /// Internal method to close connection due to protocol violations
  void _closeConnection() {
    _isConnected = false;
    _isHandshakeComplete = false;
    
    _dataSubscription?.cancel();
    _socket?.close();
    
    // Clear frame buffer to prevent further processing
    _frameBuffer.clear();
    _expectedFrameLength = null;
  }

  /// Cancel transfer
  Future<void> cancelTransfer(int transferId) async {
    try {
      if (_socket != null && _isConnected) {
        // Create empty payload for cancel frame
        final payload = Uint8List(0);
        final iv = Uint8List(ProtocolConstants.ivLength);
        final hash = Uint8List(ProtocolConstants.hashLength);
        
        // Send cancel frame to remote peer
        final cancelFrame = ProtocolFrame.control(
          transferId: transferId,
          offset: 0,
          payload: payload,
          iv: iv,
          hash: hash,
          controlSubtype: ProtocolConstants.controlSubtypeCancel,
        );
        
        final frameBytes = cancelFrame.toBytes();
        _socket!.add(frameBytes);
        
        _loggerService.info('Cancel frame sent for transfer $transferId');
      }
    } catch (e) {
      _loggerService.error('Failed to cancel transfer $transferId: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    _isConnected = false;
    _isHandshakeComplete = false;
    
    // Cancel reconnection timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    await _dataSubscription?.cancel();
    await _socket?.close();
    
    _frameController.close();
    _ackController.close();
    _controlController.close();
    _reliability.dispose();
  }
}
