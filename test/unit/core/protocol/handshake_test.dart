import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/protocol/handshake.dart';

void main() {
  group('HandshakeProtocol Tests', () {
    test('should create discovery payload', () {
      final handshake = HandshakeProtocol(
        deviceId: 'test-device-123',
        capabilities: {
          'encryption': true,
          'wifi_aware': true,
        },
      );
      final payload = handshake.createDiscoveryPayload();
      expect(payload.deviceId, equals('test-device-123'));
      expect(payload.capabilities['encryption'], isTrue);
      expect(payload.capabilities['wifi_aware'], isTrue);
      expect(payload.protocolVersion, greaterThan(0));
    });

    test('should validate discovery payload', () async {
      final handshake = HandshakeProtocol(
        deviceId: 'test-device-456',
        capabilities: {
          'encryption': true,
          'wifi_aware': true,
        },
      );
      final payload = handshake.createDiscoveryPayload();
      expect(await handshake.processDiscoveryPayload(payload), isTrue);
    });

    test('should handle invalid discovery payload (capabilities)', () async {
      final handshake = HandshakeProtocol(
        deviceId: 'abc',
        capabilities: {
          'encryption': false,
          'wifi_aware': false,
          'bluetooth': false,
        },
      );
      final payload = handshake.createDiscoveryPayload();
      expect(await handshake.processDiscoveryPayload(payload), isFalse);
    });

    test('should perform key exchange', () async {
      final handshake = HandshakeProtocol(
        deviceId: 'abc',
        capabilities: {
          'encryption': true,
          'wifi_aware': true,
        },
      );
      final keyExchange = await handshake.performKeyExchange();
      expect(keyExchange.isSuccess, isTrue);
      expect(keyExchange.localKeyPair, isNotNull);
    });

    test('should complete key exchange', () async {
      final handshake = HandshakeProtocol(
        deviceId: 'abc',
        capabilities: {
          'encryption': true,
          'wifi_aware': true,
        },
      );
      final exchange = await handshake.performKeyExchange();
      expect(exchange.isSuccess, isTrue);
      final result = await handshake.completeKeyExchange(
        sessionId: 'test-session',
        localPublicKey: exchange.localKeyPair!.publicKey,
        remotePublicKey: Uint8List(32),
        localKeyPair: exchange.localKeyPair!,
      );
      expect(result.isSuccess, isTrue);
      expect(result.derivedKey, isNotNull);
      expect(result.derivedKey!.length, equals(32));
    });
  });
}