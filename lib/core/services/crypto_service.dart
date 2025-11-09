import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:airlink/core/constants/app_constants.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:airlink/core/security/crypto.dart';
import 'package:injectable/injectable.dart';

@injectable
class CryptoService {
  late final SecureRandom _secureRandom;
  
  CryptoService() {
    _secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = DateTime.now().millisecondsSinceEpoch & 0xFF;
    }
    _secureRandom.seed(KeyParameter(seed));
  }
  
  /// Generate a new X25519 key pair
  Future<X25519KeyPair> generateKeyPair() async {
    try {
      return await AirLinkCrypto.generateX25519KeyPair();
    } catch (e) {
      throw CryptoException(
        message: 'Failed to generate X25519 key pair: $e',
      );
    }
  }
  
  /// Perform X25519 key exchange using constant-time operations
  Future<Uint8List> performKeyExchange(Uint8List privateKey, Uint8List publicKey) async {
    try {
      return await AirLinkCrypto.computeSharedSecret(privateKey, publicKey);
    } catch (e) {
      throw CryptoException(
        message: 'Failed to perform X25519 key exchange: $e',
      );
    }
  }

  // Removed _bigIntToSecureBytes - no longer needed with X25519
  
  /// Derive encryption key from shared secret using HKDF with constant-time operations
  Future<Uint8List> deriveEncryptionKey(Uint8List sharedSecret, {Uint8List? salt}) async {
    try {
      // Use AirLinkCrypto's HKDF implementation
      return await AirLinkCrypto.hkdfDerive(
        sharedSecret,
        Uint8List(0), // No additional info
        salt: salt,
      );
    } catch (e) {
      throw CryptoException(
        message: 'Failed to derive encryption key: $e',
      );
    }
  }


  /// Constant-time comparison to prevent timing attacks
  bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    
    return result == 0;
  }

  /// Securely erase sensitive data from memory
  void secureErase(Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }
  
  /// Encrypt data using AES-GCM
  EncryptedData encryptData(Uint8List data, Uint8List key) {
    try {
      final iv = _generateIV();
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        AppConstants.tagSize * 8,
        iv,
        Uint8List(0), // No additional authenticated data
      );
      
      cipher.init(true, params);
      final encrypted = cipher.process(data);
      // Finalize the cipher to complete MAC/tag generation
      cipher.doFinal(Uint8List(0), 0);
      
      return EncryptedData(
        data: encrypted,
        iv: iv,
        tag: cipher.mac,
      );
    } catch (e) {
      throw CryptoException(
        message: 'Failed to encrypt data: $e',
      );
    }
  }
  
  /// Decrypt data using AES-GCM
  Uint8List decryptData(EncryptedData encryptedData, Uint8List key) {
    try {
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        AppConstants.tagSize * 8,
        encryptedData.iv,
        Uint8List(0), // No additional authenticated data
      );
      
      cipher.init(false, params);
      // Concatenate ciphertext and authentication tag for proper GCM decryption
      final ciphertextWithTag = Uint8List.fromList([
        ...encryptedData.data,
        ...encryptedData.tag,
      ]);
      final decrypted = cipher.process(ciphertextWithTag);
      // Finalize the cipher to validate the authentication tag
      cipher.doFinal(Uint8List(0), 0);
      
      return decrypted;
    } catch (e) {
      throw CryptoException(
        message: 'Failed to decrypt data: $e',
      );
    }
  }
  
  /// Generate a random IV
  Uint8List _generateIV() {
    final iv = Uint8List(AppConstants.ivSize);
    for (int i = 0; i < AppConstants.ivSize; i++) {
      iv[i] = _secureRandom.nextUint8();
    }
    return iv;
  }
  
  /// Hash data using SHA-256
  Uint8List hashData(Uint8List data) {
    try {
      final digest = sha256.convert(data);
      return Uint8List.fromList(digest.bytes);
    } catch (e) {
      throw CryptoException(
        message: 'Failed to hash data: $e',
      );
    }
  }
  
  /// Generate a random nonce
  Uint8List generateNonce() {
    final nonce = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      nonce[i] = _secureRandom.nextUint8();
    }
    return nonce;
  }
  
  /// Generate a UUID
  String generateUuid() {
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
  
  /// Convert key to base64 string
  String keyToBase64(Uint8List key) {
    return base64Encode(key);
  }
  
  /// Convert base64 string to key
  Uint8List base64ToKey(String base64Key) {
    return base64Decode(base64Key);
  }
}

class EncryptedData {
  const EncryptedData({
    required this.data,
    required this.iv,
    required this.tag,
  });
  
  final Uint8List data;
  final Uint8List iv;
  final Uint8List tag;
}

class CryptoException extends AppException {
  const CryptoException({required super.message});
}