import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:airlink/core/security/crypto.dart';
import 'package:airlink/core/security/key_manager.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:airlink/core/services/logger_service.dart';

/// Secure Session Manager
/// 
/// Manages secure sessions with automatic key lifecycle management
/// Ensures ephemeral keys are properly disposed of after session end
/// Integrates with native transport encryption when available
class SecureSessionManager {
  final SecureKeyManager _keyManager = SecureKeyManager();
  final Map<String, SecureSession> _activeSessions = {};
  final StreamController<SessionEvent> _eventController = 
      StreamController<SessionEvent>.broadcast();
  final LoggerService _loggerService = LoggerService();
  
  // Encryption policy
  bool requireEncryption = true; // gate to disable all encryption if false
  EncryptionMode encryptionMode = EncryptionMode.auto; // select native vs dart
  
  // Native encryption integration
  final Map<String, String> _sessionToConnectionToken = {}; // sessionId -> connectionToken
  final Map<String, String> _sessionToConnectionMethod = {}; // sessionId -> connectionMethod
  final Map<String, bool> _sessionVerificationStatus = {}; // sessionId -> verified

  /// Create new secure session
  /// 
  /// [sessionId] - Unique session identifier
  /// [deviceId] - Remote device identifier
  /// [connectionToken] - Native connection token (optional)
  /// [connectionMethod] - Native connection method (optional)
  /// Returns new secure session
  Future<SecureSession> createSession(
    String sessionId, 
    String deviceId, {
    String? connectionToken,
    String? connectionMethod,
  }) async {
    // Generate ephemeral key pair
    final keyPair = await _keyManager.generateEphemeralKeyPair(sessionId);
    
    // Create session
    final session = SecureSession(
      sessionId: sessionId,
      deviceId: deviceId,
      localKeyPair: keyPair,
      keyManager: _keyManager,
    );
    
    _activeSessions[sessionId] = session;
    
    // Store native connection info if provided
    if (connectionToken != null) {
      _sessionToConnectionToken[sessionId] = connectionToken;
    }
    if (connectionMethod != null) {
      _sessionToConnectionMethod[sessionId] = connectionMethod;
    }
    
    // Emit session created event
    _eventController.add(SessionEvent.sessionCreated(sessionId, deviceId));
    
    return session;
  }

  /// Get local public key for a session
  Uint8List getLocalPublicKey(String sessionId) {
    final SecureSession? session = _activeSessions[sessionId];
    if (session == null) {
      throw CryptoException('Session not found: $sessionId');
    }
    return session.localPublicKey;
  }

  /// Complete handshake with default info derived from session id
  Future<void> completeHandshakeSimple(
    String sessionId,
    Uint8List remotePublicKey,
  ) async {
    final Uint8List info = Uint8List.fromList('airlink/v1/session:$sessionId'.codeUnits);
    await completeHandshakeWithInfo(sessionId, remotePublicKey, info);
  }

  /// Complete handshake with explicit info
  Future<void> completeHandshakeWithInfo(
    String sessionId,
    Uint8List remotePublicKey,
    Uint8List info,
  ) async {
    await completeHandshake(
      sessionId,
      remotePublicKey,
      info,
    );
  }

  /// Get existing session
  SecureSession? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  /// Complete session handshake
  /// 
  /// [sessionId] - Session identifier
  /// [remotePublicKey] - Remote device's public key
  /// [info] - Application-specific info for key derivation
  Future<void> completeHandshake(
    String sessionId,
    Uint8List remotePublicKey,
    Uint8List info,
  ) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw CryptoException('Session not found: $sessionId');
    }

    // Compute shared secret
    final sharedSecret = await AirLinkCrypto.computeSharedSecret(
      session.localKeyPair.privateKey,
      remotePublicKey,
    );

    // Derive symmetric key using unified derivation (symmetric salt)
    final Uint8List derivedKey = await AirLinkCrypto.deriveSessionKey(
      sharedSecret,
      sessionId,
      session.localPublicKey,
      remotePublicKey,
    );
    _keyManager.setSymmetricKey(sessionId, derivedKey);

    // Store remote public key
    session.remotePublicKey = remotePublicKey;
    session.isHandshakeComplete = true;

    // If native connection is present and policy allows, set key in native layer
    final connectionToken = _sessionToConnectionToken[sessionId];
    final connectionMethod = _sessionToConnectionMethod[sessionId];
    if (requireEncryption &&
        (encryptionMode == EncryptionMode.native || encryptionMode == EncryptionMode.auto)) {
      final List<int>? keyBytes = _keyManager.getSymmetricKey(sessionId)?.toList();
      if (keyBytes == null) {
        _loggerService.warning('No symmetric key available to push for session $sessionId');
      } else {
        try {
          if (connectionMethod == 'ble') {
            final bool ok = await AirLinkPlugin.setBleEncryptionKey(keyBytes);
            if (ok) {
              _loggerService.info('Pushed BLE encryption key for session $sessionId');
            } else {
              _loggerService.warning('Native returned false for BLE key push, session $sessionId');
            }
          } else {
            if (connectionToken == null) {
              _loggerService.warning('Missing connection token for session $sessionId; cannot push key');
            } else {
              final bool ok = await AirLinkPlugin.setEncryptionKey(connectionToken, keyBytes);
              if (ok) {
                _loggerService.info('Pushed session key to native transport for session $sessionId via ${connectionMethod ?? 'unknown'}');
              } else {
                _loggerService.warning('Native returned false for key push (method ${connectionMethod ?? 'unknown'}), session $sessionId');
              }
            }
          }
        } catch (e) {
          _loggerService.warning('Failed to set native encryption key for session $sessionId: $e');
        }
      }
    }

    // Emit handshake completed event
    _eventController.add(SessionEvent.handshakeCompleted(sessionId));

    // Verify that native layer applied the encryption key (with timeout and retry)
    if (connectionToken != null && connectionMethod != null && connectionMethod != 'ble') {
      try {
        final bool verified = await _verifyNativeEncryptionKey(sessionId)
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        _sessionVerificationStatus[sessionId] = verified;
        if (!verified) {
          _loggerService.warning('Native encryption key verification failed for session $sessionId');
        } else {
          _loggerService.info('Native encryption key verified for session $sessionId');
        }
      } catch (e) {
        _sessionVerificationStatus[sessionId] = false;
        _loggerService.error('Encryption key verification error for session $sessionId: $e');
      }
    } else {
      // BLE or no connection token - mark as verified by default
      _sessionVerificationStatus[sessionId] = true;
    }
  }

  /// Create a small encrypted verification payload to prove both sides derive the same key
  Future<Map<String, dynamic>> generateVerificationPayload(String sessionId) async {
    final aad = Uint8List.fromList('airlink/verify:$sessionId'.codeUnits);
    final plaintext = Uint8List.fromList('ok'.codeUnits);
    final result = await encryptData(sessionId, plaintext, aad);
    return {
      'aad': aad.toList(),
      'iv': result.iv.toList(),
      'tag': result.tag.toList(),
      'ciphertext': result.ciphertext.toList(),
    };
  }

  /// Verify an incoming encrypted verification payload; returns true if valid
  Future<bool> verifyIncomingPayload(String sessionId, Map<String, dynamic> payload) async {
    try {
      final aad = Uint8List.fromList((payload['aad'] as List).cast<int>());
      final iv = Uint8List.fromList((payload['iv'] as List).cast<int>());
      final tag = Uint8List.fromList((payload['tag'] as List).cast<int>());
      final ciphertext = Uint8List.fromList((payload['ciphertext'] as List).cast<int>());
      final decrypted = await _keyManager.decryptWithSessionKey(
        sessionId,
        AesGcmResult(ciphertext: ciphertext, iv: iv, tag: tag),
        aad,
      );
      return utf8.decode(decrypted) == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Encrypt data for session
  /// 
  /// [sessionId] - Session identifier
  /// [data] - Data to encrypt
  /// [aad] - Additional authenticated data
  /// Returns encrypted result
  Future<AesGcmResult> encryptData(
    String sessionId,
    Uint8List data,
    Uint8List aad,
  ) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw CryptoException('Session not found: $sessionId');
    }

    if (!session.isHandshakeComplete) {
      throw CryptoException('Handshake not complete for session: $sessionId');
    }

    if (!requireEncryption) {
      // passthrough
      return AesGcmResult(ciphertext: data, iv: Uint8List(12), tag: Uint8List(16));
    }
    if (encryptionMode == EncryptionMode.native) {
      // rely on native transport; return passthrough wrapper
      return await _encryptWithNativeTransport(
        sessionId, data, aad,
        _sessionToConnectionToken[sessionId] ?? '',
        _sessionToConnectionMethod[sessionId] ?? 'unknown',
      );
    }
    // Default to Dart crypto
    return await _keyManager.encryptWithSessionKey(sessionId, data, aad);
  }

  /// Decrypt data for session
  /// 
  /// [sessionId] - Session identifier
  /// [encryptedData] - Encrypted data
  /// [aad] - Additional authenticated data
  /// Returns decrypted data
  Future<Uint8List> decryptData(
    String sessionId,
    AesGcmResult encryptedData,
    Uint8List aad,
  ) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw CryptoException('Session not found: $sessionId');
    }

    if (!session.isHandshakeComplete) {
      throw CryptoException('Handshake not complete for session: $sessionId');
    }

    if (!requireEncryption) {
      return encryptedData.ciphertext;
    }
    if (encryptionMode == EncryptionMode.native) {
      return await _decryptWithNativeTransport(
        sessionId, encryptedData, aad,
        _sessionToConnectionToken[sessionId] ?? '',
        _sessionToConnectionMethod[sessionId] ?? 'unknown',
      );
    }
    return await _keyManager.decryptWithSessionKey(sessionId, encryptedData, aad);
  }

  /// Generate hash for data integrity
  /// 
  /// [data] - Data to hash
  /// Returns SHA-256 hash
  Future<Uint8List> generateHash(Uint8List data) async {
    return await AirLinkCrypto.chunkSHA256(data);
  }

  /// End session and securely erase all keys
  /// 
  /// [sessionId] - Session to end
  void endSession(String sessionId) {
    final session = _activeSessions.remove(sessionId);
    if (session != null) {
      // End session in key manager
      _keyManager.endSession(sessionId);
      
      // Clean up native connection info
      _sessionToConnectionToken.remove(sessionId);
      _sessionToConnectionMethod.remove(sessionId);
      _sessionVerificationStatus.remove(sessionId);
      
      // Emit session ended event
      _eventController.add(SessionEvent.sessionEnded(sessionId));
    }
  }
  
  /// Get the count of active sessions
  /// 
  /// Returns the number of currently active sessions
  int getActiveSessionCount() {
    return _activeSessions.length;
  }

  /// End all sessions
  void endAllSessions() {
    final sessionIds = _activeSessions.keys.toList();
    
    for (final sessionId in sessionIds) {
      endSession(sessionId);
    }
    
    _keyManager.endAllSessions();
  }

  /// Get session statistics
  SessionStats getStats() {
    return _keyManager.getStats();
  }

  /// Get all active session IDs
  List<String> getActiveSessions() {
    return _activeSessions.keys.toList();
  }

  /// Get session events stream
  Stream<SessionEvent> get eventStream => _eventController.stream;

  /// Clean up expired sessions
  void cleanupExpiredSessions({Duration maxAge = const Duration(hours: 24)}) {
    _keyManager.cleanupExpiredSessions(maxAge: maxAge);
    
    // Remove expired sessions from active sessions
    final expiredSessions = <String>[];
    for (final entry in _activeSessions.entries) {
      if (!_keyManager.hasSession(entry.key)) {
        expiredSessions.add(entry.key);
      }
    }
    
    for (final sessionId in expiredSessions) {
      _activeSessions.remove(sessionId);
    }
  }

  /// Encrypt data using native transport
  Future<AesGcmResult> _encryptWithNativeTransport(
    String sessionId,
    Uint8List data,
    Uint8List aad,
    String connectionToken,
    String connectionMethod,
  ) async {
    try {
      if (_sessionVerificationStatus[sessionId] != true) {
        _loggerService.warning('Native encryption not verified for session $sessionId, falling back to Dart');
        return await _keyManager.encryptWithSessionKey(sessionId, data, aad);
      }
      // For native transport, we rely on the native layer's encryption
      // The native layer handles encryption internally, so we just pass the data
      // and return a mock AesGcmResult for compatibility
      
      _loggerService.debug('Using native encryption for session $sessionId via $connectionMethod');
      
      // Native transport handles encryption, so we return the data as-is
      // with a mock IV and tag for compatibility
      final mockIv = Uint8List(12); // 12 bytes for GCM IV
      final mockTag = Uint8List(16); // 16 bytes for GCM tag
      
      return AesGcmResult(
        ciphertext: data,
        iv: mockIv,
        tag: mockTag,
      );
    } catch (e) {
      _loggerService.error('Native encryption failed for session $sessionId: $e');
      // Fallback to Dart-based encryption
      return await _keyManager.encryptWithSessionKey(sessionId, data, aad);
    }
  }
  
  /// Decrypt data using native transport
  Future<Uint8List> _decryptWithNativeTransport(
    String sessionId,
    AesGcmResult encryptedData,
    Uint8List aad,
    String connectionToken,
    String connectionMethod,
  ) async {
    try {
      if (_sessionVerificationStatus[sessionId] != true) {
        _loggerService.warning('Native encryption not verified for session $sessionId, falling back to Dart');
        return await _keyManager.decryptWithSessionKey(sessionId, encryptedData, aad);
      }
      // For native transport, we rely on the native layer's decryption
      // The native layer handles decryption internally, so we just return the data
      
      _loggerService.debug('Using native decryption for session $sessionId via $connectionMethod');
      
      // Native transport handles decryption, so we return the ciphertext as-is
      return encryptedData.ciphertext;
    } catch (e) {
      _loggerService.error('Native decryption failed for session $sessionId: $e');
      // Fallback to Dart-based decryption
      return await _keyManager.decryptWithSessionKey(sessionId, encryptedData, aad);
    }
  }
  
  /// Set native connection info for a session
  void setNativeConnectionInfo(String sessionId, String connectionToken, String connectionMethod) {
    _sessionToConnectionToken[sessionId] = connectionToken;
    _sessionToConnectionMethod[sessionId] = connectionMethod;
    _loggerService.info('Set native connection info for session $sessionId: $connectionMethod');
  }
  
  /// Check if session uses native encryption
  bool usesNativeEncryption(String sessionId) {
    return _sessionToConnectionToken.containsKey(sessionId) && 
           _sessionToConnectionMethod.containsKey(sessionId);
  }

  /// Verify native encryption key by round-tripping a small payload
  Future<bool> _verifyNativeEncryptionKey(String sessionId) async {
    final String? connectionToken = _sessionToConnectionToken[sessionId];
    final String? connectionMethod = _sessionToConnectionMethod[sessionId];
    if (connectionMethod == 'ble') {
      // BLE verification handled separately; consider verified if key was set
      return true;
    }
    if (connectionToken == null || connectionToken.isEmpty) {
      return false;
    }
    final Uint8List testPayload = Uint8List.fromList(List<int>.generate(32, (i) => (i * 7 + 13) & 0xFF));
    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final Map<String, dynamic> response = await AirLinkPlugin.verifyEncryptionKey(connectionToken, testPayload);
        final AesGcmResult result = AesGcmResult(
          ciphertext: Uint8List.fromList((response['ciphertext'] as List).cast<int>()),
          iv: Uint8List.fromList((response['iv'] as List).cast<int>()),
          tag: Uint8List.fromList((response['tag'] as List).cast<int>()),
        );
        final Uint8List decrypted = await _keyManager.decryptWithSessionKey(sessionId, result, Uint8List(0));
        if (decrypted.length == testPayload.length) {
          return true;
        }
      } catch (e) {
        _loggerService.warning('Key verification attempt $attempts failed: $e');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return false;
  }

  /// Dispose of all resources
  void dispose() {
    endAllSessions();
    _eventController.close();
  }
}
/// Encryption mode policy
enum EncryptionMode {
  auto, // prefer native if available; fallback to dart
  native, // force native transport encryption framing
  dart, // force Dart encryption only
}

/// Secure Session
class SecureSession {
  final String sessionId;
  final String deviceId;
  final X25519KeyPair localKeyPair;
  final SecureKeyManager keyManager;
  
  Uint8List? remotePublicKey;
  bool isHandshakeComplete = false;
  final DateTime createdAt = DateTime.now();

  SecureSession({
    required this.sessionId,
    required this.deviceId,
    required this.localKeyPair,
    required this.keyManager,
  });

  /// Get local public key
  Uint8List get localPublicKey => localKeyPair.publicKey;

  /// Check if handshake is complete
  bool get isReady => isHandshakeComplete && remotePublicKey != null;

  /// Get session age
  Duration get age => DateTime.now().difference(createdAt);

  /// Encrypt data using session key
  Future<AesGcmResult> encrypt(Uint8List data, Uint8List aad) async {
    return await keyManager.encryptWithSessionKey(sessionId, data, aad);
  }

  /// Decrypt data using session key
  Future<Uint8List> decrypt(AesGcmResult encryptedData, Uint8List aad) async {
    return await keyManager.decryptWithSessionKey(sessionId, encryptedData, aad);
  }

  /// Generate hash for data
  Future<Uint8List> hash(Uint8List data) async {
    return await AirLinkCrypto.chunkSHA256(data);
  }
}

/// Session Event Types
enum SessionEventType {
  sessionCreated,
  handshakeCompleted,
  sessionEnded,
}

/// Session Events
class SessionEvent {
  final String type;
  final String sessionId;
  final String? deviceId;
  final DateTime timestamp;

  const SessionEvent._(this.type, this.sessionId, this.deviceId, this.timestamp);

  factory SessionEvent.sessionCreated(String sessionId, String deviceId) {
    return SessionEvent._('session_created', sessionId, deviceId, DateTime.now());
  }

  factory SessionEvent.handshakeCompleted(String sessionId) {
    return SessionEvent._('handshake_completed', sessionId, null, DateTime.now());
  }

  factory SessionEvent.sessionEnded(String sessionId) {
    return SessionEvent._('session_ended', sessionId, null, DateTime.now());
  }
  
  SessionEventType get eventType {
    switch (type) {
      case 'session_created':
        return SessionEventType.sessionCreated;
      case 'handshake_completed':
        return SessionEventType.handshakeCompleted;
      case 'session_ended':
        return SessionEventType.sessionEnded;
      default:
        throw ArgumentError('Unknown session event type: "$type"');
    }
  }
}

/// Global session manager instance
final SecureSessionManager globalSessionManager = SecureSessionManager();
