import 'dart:typed_data';
import 'dart:convert';
import 'package:airlink/core/protocol/protocol_constants.dart';
import 'package:airlink/core/security/crypto.dart';

/// Handshake Protocol Implementation
/// 
/// 1. Discovery payload exchange (device id, capabilities)
/// 2. User confirm -> ECDH ephemeral (X25519) key exchange
/// 3. Derive AES-GCM key via HKDF
class HandshakeProtocol {
  final String deviceId;
  final Map<String, dynamic> capabilities;

  HandshakeProtocol({
    required this.deviceId,
    required this.capabilities,
  });

  /// Discovery payload for initial exchange
  DiscoveryPayload createDiscoveryPayload() {
    return DiscoveryPayload(
      deviceId: deviceId,
      capabilities: capabilities,
      protocolVersion: ProtocolConstants.protocolVersion,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Process received discovery payload
  Future<bool> processDiscoveryPayload(DiscoveryPayload payload) async {
    // Validate protocol version compatibility
    if (payload.protocolVersion != ProtocolConstants.protocolVersion) {
      return false;
    }

    // Validate device capabilities
    if (!_validateCapabilities(payload.capabilities)) {
      return false;
    }

    return true;
  }

  /// Perform ECDH key exchange using X25519 (secure)
  Future<KeyExchangeResult> performKeyExchange() async {
    try {
      final keyPair = await AirLinkCrypto.generateX25519KeyPair();
      return KeyExchangeResult(
        localKeyPair: keyPair,
        isSuccess: true,
        error: null,
      );
    } catch (e) {
      return KeyExchangeResult(
        localKeyPair: null,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Complete key exchange with remote public key (secure)
  /// Uses symmetric HKDF salt so both peers derive identical keys.
  ///
  /// Both peers MUST pass their own local public key and the peer's public key.
  /// Public keys are ordered deterministically before salt computation.
  Future<KeyDerivationResult> completeKeyExchange({
    required String sessionId,
    required Uint8List localPublicKey,
    required Uint8List remotePublicKey,
    required X25519KeyPair localKeyPair,
  }) async {
    try {
      // Validate remote public key
      if (remotePublicKey.length != 32) {
        throw const CryptoException('Remote public key must be 32 bytes');
      }
      bool isAllZeros = true;
      for (int i = 0; i < remotePublicKey.length; i++) {
        if (remotePublicKey[i] != 0) {
          isAllZeros = false;
          break;
        }
      }
      if (isAllZeros) {
        throw const CryptoException('Remote public key is all zeros');
      }

      // Validate local public key
      if (localPublicKey.length != 32) {
        throw const CryptoException('Local public key must be 32 bytes');
      }

      // Compute shared secret using X25519
      final sharedSecret = await AirLinkCrypto.computeSharedSecret(
        localKeyPair.privateKey,
        remotePublicKey,
      );

      // Derive AES-GCM key using unified derivation (symmetric salt)
      final derivedKey = await AirLinkCrypto.deriveSessionKey(
        sharedSecret,
        sessionId,
        localPublicKey,
        remotePublicKey,
      );

      return KeyDerivationResult(
        derivedKey: derivedKey,
        isSuccess: true,
        error: null,
      );
    } catch (e) {
      return KeyDerivationResult(
        derivedKey: null,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }
  

  bool _validateCapabilities(Map<String, dynamic> capabilities) {
    // Encryption is required
    if (!capabilities.containsKey('encryption') || 
        capabilities['encryption'] != true) {
      return false;
    }
    
    // At least one transport (wifi_aware OR bluetooth) must be available
    final hasWifiAware = capabilities['wifi_aware'] == true;
    final hasBluetooth = capabilities['bluetooth'] == true;
    
    if (!hasWifiAware && !hasBluetooth) {
      return false;
    }

    return true;
  }
}

/// Discovery payload structure
class DiscoveryPayload {
  final String deviceId;
  final Map<String, dynamic> capabilities;
  final int protocolVersion;
  final int timestamp;

  const DiscoveryPayload({
    required this.deviceId,
    required this.capabilities,
    required this.protocolVersion,
    required this.timestamp,
  });

  /// Serialize to JSON bytes
  Uint8List toBytes() {
    final json = {
      'deviceId': deviceId,
      'capabilities': capabilities,
      'protocolVersion': protocolVersion,
      'timestamp': timestamp,
    };
    
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Deserialize from JSON bytes
  factory DiscoveryPayload.fromBytes(Uint8List data) {
    final json = jsonDecode(utf8.decode(data));
    
    return DiscoveryPayload(
      deviceId: json['deviceId'] as String,
      capabilities: Map<String, dynamic>.from(json['capabilities'] as Map),
      protocolVersion: json['protocolVersion'] as int,
      timestamp: json['timestamp'] as int,
    );
  }

  /// Check if payload is recent (within 30 seconds)
  bool get isRecent {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) < 30000; // 30 seconds
  }
}

/// Key exchange result
class KeyExchangeResult {
  final X25519KeyPair? localKeyPair;
  final bool isSuccess;
  final String? error;

  const KeyExchangeResult({
    this.localKeyPair,
    required this.isSuccess,
    this.error,
  });
}

/// Key derivation result
class KeyDerivationResult {
  final Uint8List? derivedKey;
  final bool isSuccess;
  final String? error;

  const KeyDerivationResult({
    this.derivedKey,
    required this.isSuccess,
    this.error,
  });
}

// Removed insecure simulated key pair implementation
