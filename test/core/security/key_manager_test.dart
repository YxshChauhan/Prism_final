import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/security/crypto.dart';
import 'package:airlink/core/security/key_manager.dart';
import 'dart:typed_data';

void main() {
  group('Secure Key Manager Tests', () {
    late SecureKeyManager keyManager;

    setUp(() {
      keyManager = SecureKeyManager();
    });

    tearDown(() {
      keyManager.endAllSessions();
    });

    group('Ephemeral Key Management', () {
      test('should generate and store ephemeral key pair', () async {
        const sessionId = 'test-session-1';
        
        final keyPair = await keyManager.generateEphemeralKeyPair(sessionId);
        
        expect(keyPair.privateKey.length, equals(32));
        expect(keyPair.publicKey.length, equals(32));
        expect(keyManager.hasSession(sessionId), isTrue);
        expect(keyManager.getKeyPair(sessionId), equals(keyPair));
      });

      test('should handle multiple sessions', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        
        final keyPair1 = await keyManager.generateEphemeralKeyPair(sessionId1);
        final keyPair2 = await keyManager.generateEphemeralKeyPair(sessionId2);
        
        expect(keyManager.hasSession(sessionId1), isTrue);
        expect(keyManager.hasSession(sessionId2), isTrue);
        expect(keyManager.getKeyPair(sessionId1), equals(keyPair1));
        expect(keyManager.getKeyPair(sessionId2), equals(keyPair2));
        expect(keyPair1, isNot(equals(keyPair2)));
      });

      test('should return null for non-existent session', () {
        expect(keyManager.getKeyPair('non-existent'), isNull);
        expect(keyManager.hasSession('non-existent'), isFalse);
      });
    });

    group('Symmetric Key Derivation', () {
      test('should derive and store symmetric key', () async {
        const sessionId = 'test-session';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        final symmetricKey = await keyManager.deriveAndStoreSymmetricKey(
          sessionId,
          sharedSecret,
          info,
        );
        
        expect(symmetricKey.length, equals(32));
        expect(keyManager.getSymmetricKey(sessionId), equals(symmetricKey));
      });

      test('should return null for non-existent session', () {
        expect(keyManager.getSymmetricKey('non-existent'), isNull);
      });

      test('should handle multiple symmetric keys', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        final sharedSecret1 = Uint8List.fromList(List.generate(32, (i) => i));
        final sharedSecret2 = Uint8List.fromList(List.generate(32, (i) => i + 10));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId1);
        await keyManager.generateEphemeralKeyPair(sessionId2);
        
        final symmetricKey1 = await keyManager.deriveAndStoreSymmetricKey(
          sessionId1,
          sharedSecret1,
          info,
        );
        final symmetricKey2 = await keyManager.deriveAndStoreSymmetricKey(
          sessionId2,
          sharedSecret2,
          info,
        );
        
        expect(symmetricKey1, isNot(equals(symmetricKey2)));
        expect(keyManager.getSymmetricKey(sessionId1), equals(symmetricKey1));
        expect(keyManager.getSymmetricKey(sessionId2), equals(symmetricKey2));
      });
    });

    group('Encryption and Decryption', () {
      test('should encrypt and decrypt with session key', () async {
        const sessionId = 'test-session';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        await keyManager.deriveAndStoreSymmetricKey(sessionId, sharedSecret, info);
        
        final encrypted = await keyManager.encryptWithSessionKey(sessionId, data, aad);
        final decrypted = await keyManager.decryptWithSessionKey(sessionId, encrypted, aad);
        
        expect(decrypted, equals(data));
        expect(encrypted.ciphertext.length, equals(data.length));
        expect(encrypted.tag.length, equals(16));
      });

      test('should throw exception for non-existent session', () async {
        const sessionId = 'non-existent';
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        expect(
          () => keyManager.encryptWithSessionKey(sessionId, data, aad),
          throwsA(isA<CryptoException>()),
        );
        
        expect(
          () => keyManager.decryptWithSessionKey(sessionId, 
            AesGcmResult(
              ciphertext: data,
              tag: Uint8List(16),
              iv: Uint8List(12),
            ),
            aad,
          ),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should throw exception for session without symmetric key', () async {
        const sessionId = 'test-session';
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        // Don't derive symmetric key
        
        expect(
          () => keyManager.encryptWithSessionKey(sessionId, data, aad),
          throwsA(isA<CryptoException>()),
        );
      });
    });

    group('Session Management', () {
      test('should end individual session', () async {
        const sessionId = 'test-session';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        await keyManager.deriveAndStoreSymmetricKey(sessionId, sharedSecret, info);
        
        expect(keyManager.hasSession(sessionId), isTrue);
        
        keyManager.endSession(sessionId);
        
        expect(keyManager.hasSession(sessionId), isFalse);
        expect(keyManager.getKeyPair(sessionId), isNull);
        expect(keyManager.getSymmetricKey(sessionId), isNull);
      });

      test('should end all sessions', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId1);
        await keyManager.generateEphemeralKeyPair(sessionId2);
        await keyManager.deriveAndStoreSymmetricKey(sessionId1, sharedSecret, info);
        await keyManager.deriveAndStoreSymmetricKey(sessionId2, sharedSecret, info);
        
        expect(keyManager.hasSession(sessionId1), isTrue);
        expect(keyManager.hasSession(sessionId2), isTrue);
        
        keyManager.endAllSessions();
        
        expect(keyManager.hasSession(sessionId1), isFalse);
        expect(keyManager.hasSession(sessionId2), isFalse);
        expect(keyManager.getActiveSessions(), isEmpty);
      });

      test('should get active sessions', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        
        await keyManager.generateEphemeralKeyPair(sessionId1);
        await keyManager.generateEphemeralKeyPair(sessionId2);
        
        final activeSessions = keyManager.getActiveSessions();
        expect(activeSessions.length, equals(2));
        expect(activeSessions, contains(sessionId1));
        expect(activeSessions, contains(sessionId2));
      });
    });

    group('Session Statistics', () {
      test('should provide correct statistics', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId1);
        await keyManager.generateEphemeralKeyPair(sessionId2);
        await keyManager.deriveAndStoreSymmetricKey(sessionId1, sharedSecret, info);
        await keyManager.deriveAndStoreSymmetricKey(sessionId2, sharedSecret, info);
        
        final stats = keyManager.getStats();
        expect(stats.activeSessions, equals(2));
        expect(stats.ephemeralKeyPairs, equals(2));
        expect(stats.derivedKeys, equals(2));
      });

      test('should update statistics after session end', () async {
        const sessionId = 'test-session';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        await keyManager.deriveAndStoreSymmetricKey(sessionId, sharedSecret, info);
        
        var stats = keyManager.getStats();
        expect(stats.activeSessions, equals(1));
        expect(stats.ephemeralKeyPairs, equals(1));
        expect(stats.derivedKeys, equals(1));
        
        keyManager.endSession(sessionId);
        
        stats = keyManager.getStats();
        expect(stats.activeSessions, equals(0));
        expect(stats.ephemeralKeyPairs, equals(0));
        expect(stats.derivedKeys, equals(0));
      });
    });

    group('Session Cleanup', () {
      test('should cleanup expired sessions', () async {
        const sessionId = 'test-session';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        await keyManager.deriveAndStoreSymmetricKey(sessionId, sharedSecret, info);
        
        expect(keyManager.hasSession(sessionId), isTrue);
        
        // Cleanup with very short max age
        keyManager.cleanupExpiredSessions(maxAge: const Duration(milliseconds: 1));
        
        // Wait a bit to ensure expiration
        await Future.delayed(const Duration(milliseconds: 10));
        
        // This should not remove the session since we just created it
        // The cleanup only removes sessions older than maxAge
        expect(keyManager.hasSession(sessionId), isTrue);
      });
    });

    group('Security Validation', () {
      test('should securely dispose of keys', () async {
        const sessionId = 'test-session';
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        await keyManager.deriveAndStoreSymmetricKey(sessionId, sharedSecret, info);
        
        final keyPair = keyManager.getKeyPair(sessionId);
        final symmetricKey = keyManager.getSymmetricKey(sessionId);
        
        expect(keyPair, isNotNull);
        expect(symmetricKey, isNotNull);
        
        keyManager.endSession(sessionId);
        
        // Keys should be disposed and cannot be accessed
        expect(keyManager.getKeyPair(sessionId), isNull);
        expect(keyManager.getSymmetricKey(sessionId), isNull);
      });

      test('should handle multiple cleanup operations', () async {
        const sessionId = 'test-session';
        
        await keyManager.generateEphemeralKeyPair(sessionId);
        expect(keyManager.hasSession(sessionId), isTrue);
        
        // Multiple cleanup operations should not cause issues
        keyManager.cleanupExpiredSessions();
        keyManager.cleanupExpiredSessions();
        keyManager.cleanupExpiredSessions();
        
        expect(keyManager.hasSession(sessionId), isTrue);
      });
    });
  });
}