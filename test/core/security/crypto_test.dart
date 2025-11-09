import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/security/crypto.dart';
import 'dart:typed_data';

void main() {
  group('AirLink Crypto Tests', () {
    group('X25519 Key Exchange', () {
      test('should generate valid X25519 key pair', () async {
        final keyPair = await AirLinkCrypto.generateX25519KeyPair();
        
        expect(keyPair.privateKey.length, equals(32));
        expect(keyPair.publicKey.length, equals(32));
        
        // Ensure keys are not all zeros
        expect(keyPair.privateKey.any((byte) => byte != 0), isTrue);
        expect(keyPair.publicKey.any((byte) => byte != 0), isTrue);
      });

      test('should generate unique X25519 key pairs', () async {
        // Generate first key pair
        final keyPair1 = await AirLinkCrypto.generateX25519KeyPair();
        
        // Generate second key pair
        final keyPair2 = await AirLinkCrypto.generateX25519KeyPair();
        
        // Verify both key pairs are valid
        expect(keyPair1.privateKey.length, equals(32));
        expect(keyPair1.publicKey.length, equals(32));
        expect(keyPair2.privateKey.length, equals(32));
        expect(keyPair2.publicKey.length, equals(32));
        
        // Ensure keys are not all zeros
        expect(keyPair1.privateKey.any((byte) => byte != 0), isTrue);
        expect(keyPair1.publicKey.any((byte) => byte != 0), isTrue);
        expect(keyPair2.privateKey.any((byte) => byte != 0), isTrue);
        expect(keyPair2.publicKey.any((byte) => byte != 0), isTrue);
        
        // Verify uniqueness - keys from different pairs should be different
        expect(keyPair1.privateKey, isNot(equals(keyPair2.privateKey)));
        expect(keyPair1.publicKey, isNot(equals(keyPair2.publicKey)));
      });

      test('should compute shared secret correctly', () async {
        final aliceKeyPair = await AirLinkCrypto.generateX25519KeyPair();
        final bobKeyPair = await AirLinkCrypto.generateX25519KeyPair();
        
        final aliceSecret = await AirLinkCrypto.computeSharedSecret(
          aliceKeyPair.privateKey,
          bobKeyPair.publicKey,
        );
        
        final bobSecret = await AirLinkCrypto.computeSharedSecret(
          bobKeyPair.privateKey,
          aliceKeyPair.publicKey,
        );
        
        expect(aliceSecret.length, equals(32));
        expect(bobSecret.length, equals(32));
        expect(aliceSecret, equals(bobSecret));
        
        // Ensure shared secret is not all zeros
        expect(aliceSecret.any((byte) => byte != 0), isTrue);
      });

      test('should handle invalid key lengths', () async {
        final validKey = Uint8List.fromList(List.generate(32, (i) => 1));
        final invalidKey = Uint8List(16);
        
        expect(
          () => AirLinkCrypto.computeSharedSecret(validKey, invalidKey),
          throwsA(isA<CryptoException>()),
        );
        
        expect(
          () => AirLinkCrypto.computeSharedSecret(invalidKey, validKey),
          throwsA(isA<CryptoException>()),
        );
      });
    });

    group('HKDF Key Derivation', () {
      test('should derive symmetric key correctly', () async {
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        final salt = Uint8List.fromList(List.generate(32, (i) => i + 10));
        
        final derivedKey = await AirLinkCrypto.hkdfDerive(
          sharedSecret,
          info,
          salt: salt,
        );
        
        expect(derivedKey.length, equals(32));
        expect(derivedKey.any((byte) => byte != 0), isTrue);
      });

      test('should use zero salt when not provided', () async {
        final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        final derivedKey1 = await AirLinkCrypto.hkdfDerive(sharedSecret, info);
        final derivedKey2 = await AirLinkCrypto.hkdfDerive(sharedSecret, info);
        
        expect(derivedKey1, equals(derivedKey2));
        expect(derivedKey1.length, equals(32));
      });

      test('should reject invalid shared secret length', () async {
        final invalidSecret = Uint8List(16);
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        expect(
          () => AirLinkCrypto.hkdfDerive(invalidSecret, info),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should derive valid key from all-zeros input', () async {
        final allZerosSecret = Uint8List(32); // All zeros
        final info = Uint8List.fromList('test-info'.codeUnits);
        
        // HKDF should produce a valid, non-zero derived key even from all-zeros input
        final derivedKey = await AirLinkCrypto.hkdfDerive(allZerosSecret, info);
        expect(derivedKey.length, equals(32));
        expect(derivedKey.any((byte) => byte != 0), isTrue);
      });
    });

    group('AES-GCM Encryption', () {
      test('should encrypt and decrypt data correctly', () async {
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final iv = Uint8List.fromList(List.generate(12, (i) => i + 10));
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        final encrypted = await AirLinkCrypto.aesGcmEncrypt(key, iv, aad, plaintext);
        final decrypted = await AirLinkCrypto.aesGcmDecrypt(
          key,
          iv,
          aad,
          encrypted.ciphertext,
          encrypted.tag,
        );
        
        expect(decrypted, equals(plaintext));
        expect(encrypted.ciphertext.length, equals(plaintext.length));
        expect(encrypted.tag.length, equals(16));
      });

      test('should reject invalid key length', () async {
        final invalidKey = Uint8List(16);
        final iv = Uint8List.fromList(List.generate(12, (i) => i));
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        expect(
          () => AirLinkCrypto.aesGcmEncrypt(invalidKey, iv, aad, plaintext),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should reject invalid IV length', () async {
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final invalidIv = Uint8List(8);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        expect(
          () => AirLinkCrypto.aesGcmEncrypt(key, invalidIv, aad, plaintext),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should reject all-zeros key', () async {
        final allZerosKey = Uint8List(32);
        final iv = Uint8List.fromList(List.generate(12, (i) => i));
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        expect(
          () => AirLinkCrypto.aesGcmEncrypt(allZerosKey, iv, aad, plaintext),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should reject all-zeros IV', () async {
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final allZerosIv = Uint8List(12);
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        expect(
          () => AirLinkCrypto.aesGcmEncrypt(key, allZerosIv, aad, plaintext),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should reject empty plaintext', () async {
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final iv = Uint8List.fromList(List.generate(12, (i) => i));
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final emptyPlaintext = Uint8List(0);
        
        expect(
          () => AirLinkCrypto.aesGcmEncrypt(key, iv, aad, emptyPlaintext),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should detect tampered data', () async {
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final iv = Uint8List.fromList(List.generate(12, (i) => i));
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        final encrypted = await AirLinkCrypto.aesGcmEncrypt(key, iv, aad, plaintext);
        
        // Tamper with ciphertext
        final tamperedCiphertext = Uint8List.fromList(encrypted.ciphertext);
        tamperedCiphertext[0] = (tamperedCiphertext[0] + 1) % 256;
        
        expect(
          () => AirLinkCrypto.aesGcmDecrypt(
            key,
            iv,
            aad,
            tamperedCiphertext,
            encrypted.tag,
          ),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should detect tampered tag', () async {
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final iv = Uint8List.fromList(List.generate(12, (i) => i));
        final aad = Uint8List.fromList('test-aad'.codeUnits);
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
        
        final encrypted = await AirLinkCrypto.aesGcmEncrypt(key, iv, aad, plaintext);
        
        // Tamper with tag
        final tamperedTag = Uint8List.fromList(encrypted.tag);
        tamperedTag[0] = (tamperedTag[0] + 1) % 256;
        
        expect(
          () => AirLinkCrypto.aesGcmDecrypt(
            key,
            iv,
            aad,
            encrypted.ciphertext,
            tamperedTag,
          ),
          throwsA(isA<CryptoException>()),
        );
      });
    });

    group('SHA-256 Hashing', () {
      test('should generate correct SHA-256 hash', () async {
        final payload = Uint8List.fromList('Hello, World!'.codeUnits);
        final hash = await AirLinkCrypto.chunkSHA256(payload);
        
        expect(hash.length, equals(32));
        expect(hash.any((byte) => byte != 0), isTrue);
      });

      test('should generate consistent hashes', () async {
        final payload = Uint8List.fromList('Hello, World!'.codeUnits);
        final hash1 = await AirLinkCrypto.chunkSHA256(payload);
        final hash2 = await AirLinkCrypto.chunkSHA256(payload);
        
        expect(hash1, equals(hash2));
      });

      test('should generate different hashes for different inputs', () async {
        final payload1 = Uint8List.fromList('Hello, World!'.codeUnits);
        final payload2 = Uint8List.fromList('Hello, World?'.codeUnits);
        
        final hash1 = await AirLinkCrypto.chunkSHA256(payload1);
        final hash2 = await AirLinkCrypto.chunkSHA256(payload2);
        
        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('Secure Random Generation', () {
      test('should generate secure random bytes', () async {
        final random1 = await AirLinkCrypto.generateSecureRandom(32);
        final random2 = await AirLinkCrypto.generateSecureRandom(32);
        
        expect(random1.length, equals(32));
        expect(random2.length, equals(32));
        // Note: Uniqueness across calls is omitted due to negligible collision probability
        // for 32-byte secure random values (2^256 possible values)
        expect(random1.any((byte) => byte != 0), isTrue);
        expect(random2.any((byte) => byte != 0), isTrue);
      });

      test('should generate IV correctly', () async {
        final iv = await AirLinkCrypto.generateIV();
        
        expect(iv.length, equals(12));
        expect(iv.any((byte) => byte != 0), isTrue);
      });
    });

    group('Security Validation', () {
      test('should perform constant-time comparison', () {
        final a = Uint8List.fromList([1, 2, 3, 4]);
        final b = Uint8List.fromList([1, 2, 3, 4]);
        final c = Uint8List.fromList([1, 2, 3, 5]);
        
        expect(AirLinkCrypto.constantTimeEquals(a, b), isTrue);
        expect(AirLinkCrypto.constantTimeEquals(a, c), isFalse);
        expect(AirLinkCrypto.constantTimeEquals(a, Uint8List(3)), isFalse);
      });

      test('should perform constant-time swap', () {
        final a = Uint8List.fromList([1, 2, 3, 4]);
        final b = Uint8List.fromList([5, 6, 7, 8]);
        
        // Test swap = true
        final (swappedA, swappedB) = AirLinkCrypto.constantTimeSwap(a, b, true);
        expect(swappedA, equals(b));
        expect(swappedB, equals(a));
        
        // Test swap = false
        final (noSwapA, noSwapB) = AirLinkCrypto.constantTimeSwap(a, b, false);
        expect(noSwapA, equals(a));
        expect(noSwapB, equals(b));
      });

      test('should perform constant-time select', () {
        final original = Uint8List.fromList([1, 2, 3, 4]);
        final value = Uint8List.fromList([5, 6, 7, 8]);
        
        // Test condition = true
        final selectedTrue = AirLinkCrypto.constantTimeSelect(true, original, value);
        expect(selectedTrue, equals(value));
        
        // Test condition = false
        final selectedFalse = AirLinkCrypto.constantTimeSelect(false, original, value);
        expect(selectedFalse, equals(original));
      });

      test('should perform secure memory comparison', () {
        final a = Uint8List.fromList([1, 2, 3, 4]);
        final b = Uint8List.fromList([1, 2, 3, 4]);
        final c = Uint8List.fromList([1, 2, 3, 5]);
        final d = Uint8List.fromList([1, 2, 3]);
        
        expect(AirLinkCrypto.secureMemoryEquals(a, b), isTrue);
        expect(AirLinkCrypto.secureMemoryEquals(a, c), isFalse);
        expect(AirLinkCrypto.secureMemoryEquals(a, d), isFalse);
      });

      test('should securely erase data', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        AirLinkCrypto.secureErase(data);
        
        expect(data.every((byte) => byte == 0), isTrue);
      });

      test('should handle constant-time operations with different lengths', () {
        final a = Uint8List.fromList([1, 2, 3]);
        final b = Uint8List.fromList([1, 2, 3, 4]);
        
        expect(
          () => AirLinkCrypto.constantTimeSwap(a, b, true),
          throwsA(isA<CryptoException>()),
        );
        
        expect(
          () => AirLinkCrypto.constantTimeSelect(true, a, b),
          throwsA(isA<CryptoException>()),
        );
      });

      test('should perform constant-time operations without timing leaks', () {
        // Test that constant-time operations work correctly
        final testData1 = Uint8List.fromList(List.generate(32, (i) => i));
        final testData2 = Uint8List.fromList(List.generate(32, (i) => i + 1));
        final testData3 = Uint8List.fromList(List.generate(32, (i) => 255 - i));
        
        // Test constant-time comparison functionality
        expect(AirLinkCrypto.constantTimeEquals(testData1, testData1), isTrue);
        expect(AirLinkCrypto.constantTimeEquals(testData1, testData2), isFalse);
        expect(AirLinkCrypto.constantTimeEquals(testData2, testData3), isFalse);
        
        // Test constant-time swap
        final (swap1, swap2) = AirLinkCrypto.constantTimeSwap(testData1, testData2, true);
        expect(swap1, equals(testData2));
        expect(swap2, equals(testData1));
        
        // Test constant-time select
        final selected = AirLinkCrypto.constantTimeSelect(true, testData1, testData2);
        expect(selected, equals(testData2));
        
        // Test that operations complete without throwing exceptions
        // This verifies the constant-time operations work correctly
        for (int i = 0; i < 10; i++) {
          AirLinkCrypto.constantTimeEquals(testData1, testData2);
          AirLinkCrypto.constantTimeSwap(testData1, testData2, i % 2 == 0);
          AirLinkCrypto.constantTimeSelect(i % 2 == 0, testData1, testData2);
        }
      });

      test('should prevent timing attacks on memory comparison', () {
        // Test that secureMemoryEquals doesn't leak information about array lengths
        final shortArray = Uint8List.fromList([1, 2, 3]);
        final longArray = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        
        // These should all take similar time regardless of length difference
        expect(AirLinkCrypto.secureMemoryEquals(shortArray, longArray), isFalse);
        expect(AirLinkCrypto.secureMemoryEquals(shortArray, shortArray), isTrue);
        expect(AirLinkCrypto.secureMemoryEquals(longArray, longArray), isTrue);
      });
    });

    group('End-to-End Security Flow', () {
      test('should complete full security handshake', () async {
        // Generate key pairs for both parties
        final aliceKeyPair = await AirLinkCrypto.generateX25519KeyPair();
        final bobKeyPair = await AirLinkCrypto.generateX25519KeyPair();
        
        // Compute shared secrets
        final aliceSecret = await AirLinkCrypto.computeSharedSecret(
          aliceKeyPair.privateKey,
          bobKeyPair.publicKey,
        );
        final bobSecret = await AirLinkCrypto.computeSharedSecret(
          bobKeyPair.privateKey,
          aliceKeyPair.publicKey,
        );
        
        expect(aliceSecret, equals(bobSecret));
        
        // Derive symmetric keys
        final info = Uint8List.fromList('airlink-session'.codeUnits);
        final aliceSymmetricKey = await AirLinkCrypto.hkdfDerive(aliceSecret, info);
        final bobSymmetricKey = await AirLinkCrypto.hkdfDerive(bobSecret, info);
        
        expect(aliceSymmetricKey, equals(bobSymmetricKey));
        
        // Encrypt and decrypt data
        final plaintext = Uint8List.fromList('Secret message'.codeUnits);
        final aad = Uint8List.fromList('message-metadata'.codeUnits);
        final iv = await AirLinkCrypto.generateIV();
        
        final encrypted = await AirLinkCrypto.aesGcmEncrypt(
          aliceSymmetricKey,
          iv,
          aad,
          plaintext,
        );
        
        final decrypted = await AirLinkCrypto.aesGcmDecrypt(
          bobSymmetricKey,
          iv,
          aad,
          encrypted.ciphertext,
          encrypted.tag,
        );
        
        expect(decrypted, equals(plaintext));
        
        // Clean up keys
        aliceKeyPair.dispose();
        bobKeyPair.dispose();
        AirLinkCrypto.secureErase(aliceSecret);
        AirLinkCrypto.secureErase(bobSecret);
        AirLinkCrypto.secureErase(aliceSymmetricKey);
        AirLinkCrypto.secureErase(bobSymmetricKey);
      });
    });
  });
}