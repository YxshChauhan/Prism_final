import 'dart:typed_data';
import 'package:airlink/core/security/crypto.dart';
import 'package:airlink/core/constants/feature_flags.dart';

/// Secure Key Management System
/// 
/// Manages ephemeral keys with automatic secure erasure
/// Ensures keys are disposed of after session end
class SecureKeyManager {
  final Map<String, _KeyEntry> _activeKeys = {};
  final List<X25519KeyPair> _ephemeralKeyPairs = [];
  final List<Uint8List> _derivedKeys = [];
  
  // Key rotation tracking
  final Map<String, DateTime> _keyCreationTimes = {};
  final Map<String, int> _keyUsageCount = {};
  final Map<String, _KeyEntry> _keyRenegotiationInProgress = {};
  
  // Key rotation constants
  static const Duration KEY_ROTATION_INTERVAL = Duration(hours: 24);
  static const int KEY_ROTATION_USAGE_LIMIT = 100;

  /// Generate and store ephemeral key pair
  /// 
  /// [sessionId] - Unique session identifier
  /// Returns the generated key pair
  Future<X25519KeyPair> generateEphemeralKeyPair(String sessionId) async {
    final keyPair = await AirLinkCrypto.generateX25519KeyPair();
    final now = DateTime.now();
    
    _activeKeys[sessionId] = _KeyEntry(
      keyPair: keyPair,
      createdAt: now,
    );
    
    _keyCreationTimes[sessionId] = now;
    _keyUsageCount[sessionId] = 0;
    
    _ephemeralKeyPairs.add(keyPair);
    
    return keyPair;
  }

  /// Get stored key pair for session
  X25519KeyPair? getKeyPair(String sessionId) {
    return _activeKeys[sessionId]?.keyPair;
  }

  /// Derive and store symmetric key
  /// 
  /// [sessionId] - Session identifier
  /// [sharedSecret] - Shared secret from ECDH
  /// [info] - Application-specific info
  /// Returns derived symmetric key
  Future<Uint8List> deriveAndStoreSymmetricKey(
    String sessionId,
    Uint8List sharedSecret,
    Uint8List info, {
    Uint8List? salt,
  }) async {
    final symmetricKey = await AirLinkCrypto.hkdfDerive(sharedSecret, info, salt: salt);
    
    final entry = _activeKeys[sessionId];
    if (entry != null) {
      entry.symmetricKey = symmetricKey;
      _derivedKeys.add(symmetricKey);
    }
    
    return symmetricKey;
  }

  /// Directly set a provided symmetric key for a session (when derived externally)
  void setSymmetricKey(String sessionId, Uint8List symmetricKey) {
    final entry = _activeKeys[sessionId];
    if (entry != null) {
      entry.symmetricKey = symmetricKey;
      _derivedKeys.add(symmetricKey);
    }
  }

  /// Get stored symmetric key for session
  Uint8List? getSymmetricKey(String sessionId) {
    return _activeKeys[sessionId]?.symmetricKey;
  }

  /// Get stored symmetric key bytes for session
  ///
  /// Returns the symmetric key as a List<int> for platform channel
  /// compatibility with native code. Throws [CryptoException] if the
  /// key is not found for the provided [sessionId].
  List<int> getSymmetricKeyBytes(String sessionId) {
    final Uint8List? key = getSymmetricKey(sessionId);
    if (key == null) {
      throw CryptoException('No symmetric key found for session: $sessionId');
    }
    return key.toList();
  }

  /// Encrypt data using session key
  /// 
  /// [sessionId] - Session identifier
  /// [data] - Data to encrypt
  /// [aad] - Additional authenticated data
  /// Returns encrypted result
  Future<AesGcmResult> encryptWithSessionKey(
    String sessionId,
    Uint8List data,
    Uint8List aad,
  ) async {
    // Check if key rotation is needed (only if feature is enabled)
    if (FeatureFlags.KEY_ROTATION_ENABLED && shouldRotateKey(sessionId)) {
      await rotateSessionKey(sessionId);
    }
    
    final symmetricKey = getSymmetricKey(sessionId);
    if (symmetricKey == null) {
      throw CryptoException('No symmetric key found for session: $sessionId');
    }

    // Increment usage count
    _keyUsageCount[sessionId] = (_keyUsageCount[sessionId] ?? 0) + 1;

    final iv = await AirLinkCrypto.generateIV();
    return await AirLinkCrypto.aesGcmEncrypt(symmetricKey, iv, aad, data);
  }

  /// Decrypt data using session key
  /// 
  /// [sessionId] - Session identifier
  /// [encryptedData] - Encrypted data
  /// [aad] - Additional authenticated data
  /// Returns decrypted data
  Future<Uint8List> decryptWithSessionKey(
    String sessionId,
    AesGcmResult encryptedData,
    Uint8List aad,
  ) async {
    final symmetricKey = getSymmetricKey(sessionId);
    if (symmetricKey == null) {
      throw CryptoException('No symmetric key found for session: $sessionId');
    }

    return await AirLinkCrypto.aesGcmDecrypt(
      symmetricKey,
      encryptedData.iv,
      aad,
      encryptedData.ciphertext,
      encryptedData.tag,
    );
  }

  /// End session and securely erase all keys
  /// 
  /// [sessionId] - Session to end
  void endSession(String sessionId) {
    final entry = _activeKeys.remove(sessionId);
    if (entry != null) {
      // Securely dispose of key pair
      entry.keyPair.dispose();
      
      // Securely erase symmetric key
      if (entry.symmetricKey != null) {
        AirLinkCrypto.secureErase(entry.symmetricKey!);
      }
    }
  }

  /// End all sessions and securely erase all keys
  void endAllSessions() {
    // Dispose of all ephemeral key pairs
    for (final keyPair in _ephemeralKeyPairs) {
      keyPair.dispose();
    }
    _ephemeralKeyPairs.clear();

    // Securely erase all derived keys
    for (final key in _derivedKeys) {
      AirLinkCrypto.secureErase(key);
    }
    _derivedKeys.clear();

    // Clear all active keys
    for (final entry in _activeKeys.values) {
      entry.keyPair.dispose();
      if (entry.symmetricKey != null) {
        AirLinkCrypto.secureErase(entry.symmetricKey!);
      }
    }
    _activeKeys.clear();
  }

  /// Get session statistics
  SessionStats getStats() {
    return SessionStats(
      activeSessions: _activeKeys.length,
      ephemeralKeyPairs: _ephemeralKeyPairs.length,
      derivedKeys: _derivedKeys.length,
    );
  }

  /// Check if session exists
  bool hasSession(String sessionId) {
    return _activeKeys.containsKey(sessionId);
  }

  /// Get all active session IDs
  List<String> getActiveSessions() {
    return _activeKeys.keys.toList();
  }

  /// Clean up expired sessions
  /// 
  /// [maxAge] - Maximum age for sessions
  void cleanupExpiredSessions({Duration maxAge = const Duration(hours: 24)}) {
    final now = DateTime.now();
    final expiredSessions = <String>[];

    for (final entry in _activeKeys.entries) {
      if (now.difference(entry.value.createdAt) > maxAge) {
        expiredSessions.add(entry.key);
      }
    }

    for (final sessionId in expiredSessions) {
      endSession(sessionId);
    }
  }

  /// Check if key rotation is needed for a session
  bool shouldRotateKey(String sessionId) {
    final creationTime = _keyCreationTimes[sessionId];
    final usageCount = _keyUsageCount[sessionId] ?? 0;
    
    if (creationTime == null) return false;
    
    final age = DateTime.now().difference(creationTime);
    return age > KEY_ROTATION_INTERVAL || usageCount > KEY_ROTATION_USAGE_LIMIT;
  }

  /// Rotate session key
  Future<void> rotateSessionKey(String sessionId) async {
    try {
      // Generate new ephemeral key pair
      final newKeyPair = await AirLinkCrypto.generateX25519KeyPair();
      
      // Store old key temporarily for in-flight messages
      final oldEntry = _activeKeys[sessionId];
      if (oldEntry != null) {
        // Create new entry with rotated key
        final newEntry = _KeyEntry(
          keyPair: newKeyPair,
          createdAt: DateTime.now(),
        );
        newEntry.symmetricKey = oldEntry.symmetricKey; // Keep existing symmetric key for now
        _activeKeys[sessionId] = newEntry;
        
        // Update tracking
        _keyCreationTimes[sessionId] = DateTime.now();
        _keyUsageCount[sessionId] = 0;
        
        // Dispose of old key pair
        oldEntry.keyPair.dispose();
        
        // Add new key pair to ephemeral list
        _ephemeralKeyPairs.add(newKeyPair);
        
        // Emit key rotation event for protocol handling
        _emitKeyRotationEvent(sessionId, newKeyPair);
      }
    } catch (e) {
      throw CryptoException('Failed to rotate key for session $sessionId: $e');
    }
  }

  /// Emit key rotation event for protocol handling
  void _emitKeyRotationEvent(String sessionId, X25519KeyPair newKeyPair) {
    // This would be handled by the protocol layer to coordinate with peer
    // For now, we'll just log the event
    print('Key rotation event for session $sessionId: new public key available');
  }

  /// Start symmetric key renegotiation process
  Future<void> startSymmetricKeyRenegotiation(String sessionId) async {
    try {
      // Generate new ephemeral key pair for renegotiation
      final newKeyPair = await AirLinkCrypto.generateX25519KeyPair();
      
      // Store the new key pair for renegotiation
      final renegotiationEntry = _KeyEntry(
        keyPair: newKeyPair,
        createdAt: DateTime.now(),
      );
      
      // Mark session as undergoing key renegotiation
      _keyRenegotiationInProgress[sessionId] = renegotiationEntry;
      
      // Emit renegotiation start event
      _emitKeyRenegotiationStartEvent(sessionId, newKeyPair);
      
    } catch (e) {
      throw CryptoException('Failed to start key renegotiation for session $sessionId: $e');
    }
  }

  /// Complete symmetric key renegotiation
  Future<void> completeSymmetricKeyRenegotiation(
    String sessionId,
    Uint8List newSharedSecret,
    Uint8List info,
  ) async {
    try {
      // Derive new symmetric key from shared secret
      final newSymmetricKey = await AirLinkCrypto.hkdfDerive(newSharedSecret, info);
      
      // Update the active session with new symmetric key
      final activeEntry = _activeKeys[sessionId];
      if (activeEntry != null) {
        // Securely erase old symmetric key
        if (activeEntry.symmetricKey != null) {
          AirLinkCrypto.secureErase(activeEntry.symmetricKey!);
        }
        
        // Set new symmetric key
        activeEntry.symmetricKey = newSymmetricKey;
        _derivedKeys.add(newSymmetricKey);
        
        // Update tracking
        _keyCreationTimes[sessionId] = DateTime.now();
        _keyUsageCount[sessionId] = 0;
      }
      
      // Clean up renegotiation state
      _keyRenegotiationInProgress.remove(sessionId);
      
      // Emit renegotiation completion event
      _emitKeyRenegotiationCompleteEvent(sessionId);
      
    } catch (e) {
      throw CryptoException('Failed to complete key renegotiation for session $sessionId: $e');
    }
  }

  /// Emit key renegotiation start event
  void _emitKeyRenegotiationStartEvent(String sessionId, X25519KeyPair newKeyPair) {
    // This would be handled by the protocol layer
    print('Key renegotiation started for session $sessionId');
  }

  /// Emit key renegotiation completion event
  void _emitKeyRenegotiationCompleteEvent(String sessionId) {
    // This would be handled by the protocol layer
    print('Key renegotiation completed for session $sessionId');
  }

  /// Get key rotation status for a session
  Map<String, dynamic> getKeyRotationStatus(String sessionId) {
    final creationTime = _keyCreationTimes[sessionId];
    final usageCount = _keyUsageCount[sessionId] ?? 0;
    
    if (creationTime == null) {
      return {
        'sessionId': sessionId,
        'hasKey': false,
        'age': null,
        'usageCount': 0,
        'needsRotation': false,
      };
    }
    
    final age = DateTime.now().difference(creationTime);
    final needsRotation = shouldRotateKey(sessionId);
    
    return {
      'sessionId': sessionId,
      'hasKey': true,
      'age': age.inHours,
      'usageCount': usageCount,
      'needsRotation': needsRotation,
      'maxAge': KEY_ROTATION_INTERVAL.inHours,
      'maxUsage': KEY_ROTATION_USAGE_LIMIT,
    };
  }
}

/// Internal key entry
class _KeyEntry {
  final X25519KeyPair keyPair;
  final DateTime createdAt;
  Uint8List? symmetricKey;

  _KeyEntry({
    required this.keyPair,
    required this.createdAt,
  });
}

/// Session statistics
class SessionStats {
  final int activeSessions;
  final int ephemeralKeyPairs;
  final int derivedKeys;

  const SessionStats({
    required this.activeSessions,
    required this.ephemeralKeyPairs,
    required this.derivedKeys,
  });

  @override
  String toString() {
    return 'SessionStats(active: $activeSessions, ephemeral: $ephemeralKeyPairs, derived: $derivedKeys)';
  }
}

/// Global key manager instance
final SecureKeyManager globalKeyManager = SecureKeyManager();
