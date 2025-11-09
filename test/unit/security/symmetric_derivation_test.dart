import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/security/crypto.dart';
import 'package:airlink/core/protocol/handshake.dart';
import 'package:airlink/core/security/secure_session.dart';

void main() {
  group('Symmetric key derivation parity', () {
    test('AirLinkCrypto.deriveSessionKey produces same key regardless of pubkey order', () async {
      // Arrange
      final X25519KeyPair keyPairA = await AirLinkCrypto.generateX25519KeyPair();
      final X25519KeyPair keyPairB = await AirLinkCrypto.generateX25519KeyPair();
      final Uint8List sharedAB = await AirLinkCrypto.computeSharedSecret(keyPairA.privateKey, keyPairB.publicKey);
      final Uint8List sharedBA = await AirLinkCrypto.computeSharedSecret(keyPairB.privateKey, keyPairA.publicKey);
      const String sessionId = 'session-order-test';

      // Act
      final Uint8List key1 = await AirLinkCrypto.deriveSessionKey(sharedAB, sessionId, keyPairA.publicKey, keyPairB.publicKey);
      final Uint8List key2 = await AirLinkCrypto.deriveSessionKey(sharedBA, sessionId, keyPairB.publicKey, keyPairA.publicKey);

      // Assert
      expect(AirLinkCrypto.secureMemoryEquals(key1, key2), isTrue);
      expect(key1.length, 32);
      expect(key2.length, 32);
    });

    test('HandshakeProtocol.completeKeyExchange derives identical keys on both peers', () async {
      // Arrange
      final HandshakeProtocol hsA = HandshakeProtocol(deviceId: 'A', capabilities: {'encryption': true, 'wifi_aware': true});
      final HandshakeProtocol hsB = HandshakeProtocol(deviceId: 'B', capabilities: {'encryption': true, 'wifi_aware': true});
      final keyExA = await hsA.performKeyExchange();
      final keyExB = await hsB.performKeyExchange();
      expect(keyExA.isSuccess, isTrue);
      expect(keyExB.isSuccess, isTrue);
      const String sessionId = 'session-handshake-test';

      // Act
      final KeyDerivationResult resA = await hsA.completeKeyExchange(
        sessionId: sessionId,
        localPublicKey: keyExA.localKeyPair!.publicKey,
        remotePublicKey: keyExB.localKeyPair!.publicKey,
        localKeyPair: keyExA.localKeyPair!,
      );
      final KeyDerivationResult resB = await hsB.completeKeyExchange(
        sessionId: sessionId,
        localPublicKey: keyExB.localKeyPair!.publicKey,
        remotePublicKey: keyExA.localKeyPair!.publicKey,
        localKeyPair: keyExB.localKeyPair!,
      );

      // Assert
      expect(resA.isSuccess, isTrue);
      expect(resB.isSuccess, isTrue);
      expect(resA.derivedKey, isNotNull);
      expect(resB.derivedKey, isNotNull);
      expect(AirLinkCrypto.secureMemoryEquals(resA.derivedKey!, resB.derivedKey!), isTrue);
    });

    test('SecureSessionManager two peers verify each other after handshake', () async {
      // Arrange
      const String sessionId = 'session-secure-manager-test';
      final SecureSessionManager mgrA = SecureSessionManager();
      final SecureSessionManager mgrB = SecureSessionManager();
      final SecureSession sessA = await mgrA.createSession(sessionId, 'deviceA');
      final SecureSession sessB = await mgrB.createSession(sessionId, 'deviceB');

      // Act: complete handshakes using each other's public keys
      await mgrA.completeHandshakeSimple(sessionId, sessB.localPublicKey);
      await mgrB.completeHandshakeSimple(sessionId, sessA.localPublicKey);

      // Cross-verify payloads
      final Map<String, dynamic> payloadA = await mgrA.generateVerificationPayload(sessionId);
      final Map<String, dynamic> payloadB = await mgrB.generateVerificationPayload(sessionId);
      final bool verifiedByB = await mgrB.verifyIncomingPayload(sessionId, payloadA);
      final bool verifiedByA = await mgrA.verifyIncomingPayload(sessionId, payloadB);

      // Assert
      expect(verifiedByA, isTrue);
      expect(verifiedByB, isTrue);
    });
  });
}


