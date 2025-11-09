import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/security/crypto.dart';

void main() {
  group('AAD Consistency Tests', () {
    test('AAD creation should be consistent between encryption and decryption', () async {
      // Test data
      final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final transferId = 12345;
      final offset = 67890;
      final key = Uint8List(32); // 256-bit key
      key.fillRange(0, 32, 42); // Fill with test data
      
      // Create AAD using consistent 32-bit types
      final aad = Uint8List.fromList([
        ...Int32List.fromList([transferId]).buffer.asUint8List(),
        ...Int32List.fromList([offset.toInt()]).buffer.asUint8List(),
      ]);
      
      // Generate IV
      final iv = await AirLinkCrypto.generateIV();
      
      // Encrypt data
      final encryptionResult = await AirLinkCrypto.aesGcmEncrypt(
        key,
        iv,
        aad,
        testData,
      );
      
      // Decrypt data using same AAD
      final decryptedData = await AirLinkCrypto.aesGcmDecrypt(
        key,
        iv,
        aad,
        encryptionResult.ciphertext,
        encryptionResult.tag,
      );
      
      // Verify decryption succeeds
      expect(decryptedData, equals(testData));
    });
    
    test('AAD mismatch should cause decryption failure', () async {
      // Test data
      final testData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final transferId = 12345;
      final offset = 67890;
      final key = Uint8List(32); // 256-bit key
      key.fillRange(0, 32, 42); // Fill with test data
      
      // Create AAD for encryption
      final encryptionAad = Uint8List.fromList([
        ...Int32List.fromList([transferId]).buffer.asUint8List(),
        ...Int32List.fromList([offset.toInt()]).buffer.asUint8List(),
      ]);
      
      // Create different AAD for decryption (mismatch)
      final decryptionAad = Uint8List.fromList([
        ...Int32List.fromList([transferId + 1]).buffer.asUint8List(), // Different transferId
        ...Int32List.fromList([offset.toInt()]).buffer.asUint8List(),
      ]);
      
      // Generate IV
      final iv = await AirLinkCrypto.generateIV();
      
      // Encrypt data
      final encryptionResult = await AirLinkCrypto.aesGcmEncrypt(
        key,
        iv,
        encryptionAad,
        testData,
      );
      
      // Attempt to decrypt with mismatched AAD should fail
      expect(
        () async => await AirLinkCrypto.aesGcmDecrypt(
          key,
          iv,
          decryptionAad,
          encryptionResult.ciphertext,
          encryptionResult.tag,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
