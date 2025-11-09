import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/security/crypto.dart';
import 'package:airlink/core/security/secure_session.dart';
import 'dart:typed_data';

void main() {
  group('Secure Session Manager Tests', () {
    late SecureSessionManager sessionManager;

    setUp(() {
      sessionManager = SecureSessionManager();
    });

    tearDown(() {
      sessionManager.endAllSessions();
    });

    group('Session Creation', () {
      test('should create new secure session', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        
        final session = await sessionManager.createSession(sessionId, deviceId);
        
        expect(session.sessionId, equals(sessionId));
        expect(session.deviceId, equals(deviceId));
        expect(session.isHandshakeComplete, isFalse);
        expect(session.localKeyPair, isNotNull);
        expect(session.remotePublicKey, isNull);
      });

      test('should handle multiple sessions', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        const deviceId1 = 'device-1';
        const deviceId2 = 'device-2';
        
        final session1 = await sessionManager.createSession(sessionId1, deviceId1);
        final session2 = await sessionManager.createSession(sessionId2, deviceId2);
        
        expect(session1.sessionId, equals(sessionId1));
        expect(session2.sessionId, equals(sessionId2));
        expect(session1.deviceId, equals(deviceId1));
        expect(session2.deviceId, equals(deviceId2));
        
        expect(sessionManager.getSession(sessionId1), equals(session1));
        expect(sessionManager.getSession(sessionId2), equals(session2));
      });

      test('should return null for non-existent session', () {
        expect(sessionManager.getSession('non-existent'), isNull);
      });
    });

    group('Handshake Process', () {
      test('should complete handshake successfully', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        final session = await sessionManager.createSession(sessionId, deviceId);
        expect(session.isHandshakeComplete, isFalse);
        
        await sessionManager.completeHandshake(sessionId, remotePublicKey, info);
        
        final updatedSession = sessionManager.getSession(sessionId);
        expect(updatedSession, isNotNull);
        expect(updatedSession!.isHandshakeComplete, isTrue);
        expect(updatedSession.remotePublicKey, equals(remotePublicKey));
      });

      test('should throw exception for non-existent session during handshake', () async {
        const sessionId = 'non-existent';
        final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        expect(
          () => sessionManager.completeHandshake(sessionId, remotePublicKey, info),
          throwsA(isA<CryptoException>()),
        );
      });
    });

    group('Data Encryption and Decryption', () {
      test('should encrypt and decrypt data after handshake', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        await sessionManager.createSession(sessionId, deviceId);
        await sessionManager.completeHandshake(sessionId, remotePublicKey, info);
        
        final encrypted = await sessionManager.encryptData(sessionId, data, aad);
        final decrypted = await sessionManager.decryptData(sessionId, encrypted, aad);
        
        expect(decrypted, equals(data));
        expect(encrypted.ciphertext.length, equals(data.length));
        expect(encrypted.tag.length, equals(16));
      });

      test('should throw exception for non-existent session during encryption', () async {
        const sessionId = 'non-existent';
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        expect(
          () => sessionManager.encryptData(sessionId, data, aad),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should throw exception for incomplete handshake during encryption', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        await sessionManager.createSession(sessionId, deviceId);
        // Don't complete handshake
        
        expect(
          () => sessionManager.encryptData(sessionId, data, aad),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should throw exception for non-existent session during decryption', () async {
        const sessionId = 'non-existent';
        final encryptedData = AesGcmResult(
          ciphertext: Uint8List.fromList('Hello'.codeUnits),
          tag: Uint8List(16),
          iv: Uint8List(12),
        );
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        expect(
          () => sessionManager.decryptData(sessionId, encryptedData, aad),
          throwsA(isA<CryptoException>()),
        );
      });
    });

    group('Session Events', () {
      test('should emit session created event', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        
        SessionEvent? capturedEvent;
        final subscription = sessionManager.eventStream.listen((event) {
          capturedEvent = event;
        });
        
        await sessionManager.createSession(sessionId, deviceId);
        
        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.type, equals(SessionEventType.sessionCreated));
        expect(capturedEvent!.sessionId, equals(sessionId));
        expect(capturedEvent!.deviceId, equals(deviceId));
        
        await subscription.cancel();
      });

      test('should emit handshake completed event', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        SessionEvent? capturedEvent;
        final subscription = sessionManager.eventStream.listen((event) {
          if (event.type == SessionEventType.handshakeCompleted) {
            capturedEvent = event;
          }
        });
        
        await sessionManager.createSession(sessionId, deviceId);
        await sessionManager.completeHandshake(sessionId, remotePublicKey, info);
        
        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.type, equals(SessionEventType.handshakeCompleted));
        expect(capturedEvent!.sessionId, equals(sessionId));
        
        await subscription.cancel();
      });

      test('should emit session ended event', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        
        SessionEvent? capturedEvent;
        final subscription = sessionManager.eventStream.listen((event) {
          if (event.type == SessionEventType.sessionEnded) {
            capturedEvent = event;
          }
        });
        
        await sessionManager.createSession(sessionId, deviceId);
        sessionManager.endSession(sessionId);
        
        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 10));
        
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.type, equals(SessionEventType.sessionEnded));
        expect(capturedEvent!.sessionId, equals(sessionId));
        
        await subscription.cancel();
      });
    });

    group('Session Management', () {
      test('should end individual session', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        
        await sessionManager.createSession(sessionId, deviceId);
        expect(sessionManager.getSession(sessionId), isNotNull);
        
        sessionManager.endSession(sessionId);
        expect(sessionManager.getSession(sessionId), isNull);
      });

      test('should end all sessions', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        const deviceId1 = 'device-1';
        const deviceId2 = 'device-2';
        
        await sessionManager.createSession(sessionId1, deviceId1);
        await sessionManager.createSession(sessionId2, deviceId2);
        
        expect(sessionManager.getSession(sessionId1), isNotNull);
        expect(sessionManager.getSession(sessionId2), isNotNull);
        
        sessionManager.endAllSessions();
        
        expect(sessionManager.getSession(sessionId1), isNull);
        expect(sessionManager.getSession(sessionId2), isNull);
      });

      test('should handle ending non-existent session', () {
        // Should not throw exception
        sessionManager.endSession('non-existent');
      });
    });

    group('Session Statistics', () {
      test('should provide correct session count', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        const deviceId1 = 'device-1';
        const deviceId2 = 'device-2';
        
        expect(sessionManager.getActiveSessionCount(), equals(0));
        
        await sessionManager.createSession(sessionId1, deviceId1);
        expect(sessionManager.getActiveSessionCount(), equals(1));
        
        await sessionManager.createSession(sessionId2, deviceId2);
        expect(sessionManager.getActiveSessionCount(), equals(2));
        
        sessionManager.endSession(sessionId1);
        expect(sessionManager.getActiveSessionCount(), equals(1));
        
        sessionManager.endAllSessions();
        expect(sessionManager.getActiveSessionCount(), equals(0));
      });

      test('should provide session list', () async {
        const sessionId1 = 'session-1';
        const sessionId2 = 'session-2';
        const deviceId1 = 'device-1';
        const deviceId2 = 'device-2';
        
        expect(sessionManager.getActiveSessions(), isEmpty);
        
        await sessionManager.createSession(sessionId1, deviceId1);
        await sessionManager.createSession(sessionId2, deviceId2);
        
        final sessions = sessionManager.getActiveSessions();
        expect(sessions.length, equals(2));
        expect(sessions, contains(sessionId1));
        expect(sessions, contains(sessionId2));
      });
    });

    group('Security Validation', () {
      test('should securely dispose of session data', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        await sessionManager.createSession(sessionId, deviceId);
        await sessionManager.completeHandshake(sessionId, remotePublicKey, info);
        
        final session = sessionManager.getSession(sessionId);
        expect(session, isNotNull);
        expect(session!.isHandshakeComplete, isTrue);
        
        sessionManager.endSession(sessionId);
        
        // Session should be disposed and cannot be accessed
        expect(sessionManager.getSession(sessionId), isNull);
      });

      test('should handle multiple operations on same session', () async {
        const sessionId = 'test-session';
        const deviceId = 'device-123';
        final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        final data = Uint8List.fromList('Hello, World!'.codeUnits);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        
        await sessionManager.createSession(sessionId, deviceId);
        await sessionManager.completeHandshake(sessionId, remotePublicKey, info);
        
        // Multiple encryption/decryption operations should work
        for (int i = 0; i < 5; i++) {
          final encrypted = await sessionManager.encryptData(sessionId, data, aad);
          final decrypted = await sessionManager.decryptData(sessionId, encrypted, aad);
          expect(decrypted, equals(data));
        }
      });
    });
  });
}