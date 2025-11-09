import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../transfer_engine/crypto.dart';

void main() {
  group('CryptoUtils Tests', () {
    test('should throw UnimplementedError for generateKeyPair', () async {
      expect(
        () async => await CryptoUtils.generateKeyPair(),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('should throw UnimplementedError for performKeyExchange', () async {
      final keyPair = KeyPair(
        privateKey: Uint8List.fromList(List.generate(32, (i) => i)),
        publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
      final remotePublicKey = Uint8List.fromList(List.generate(32, (i) => i + 2));
      
      expect(
        () async => await CryptoUtils.performKeyExchange(keyPair, remotePublicKey),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('should throw UnimplementedError for encryptData', () async {
      final data = Uint8List.fromList('Hello World'.codeUnits);
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      
      expect(
        () async => await CryptoUtils.encryptData(data, key, nonce),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('should throw UnimplementedError for decryptData', () async {
      final encryptedData = EncryptedData(
        ciphertext: Uint8List.fromList('encrypted'.codeUnits),
        nonce: Uint8List.fromList(List.generate(12, (i) => i)),
        tag: Uint8List.fromList(List.generate(16, (i) => i)),
      );
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      
      expect(
        () async => await CryptoUtils.decryptData(encryptedData, key),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('should generate random bytes', () async {
      final bytes = await CryptoUtils.generateRandomBytes(32);
      expect(bytes.length, equals(32));
    });
  });
}
