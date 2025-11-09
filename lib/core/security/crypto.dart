import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart' hide SecureRandom;
import 'package:cryptography/cryptography.dart';


class AirLinkCrypto {
  static final Random _secureRandom = Random.secure();
  
  /// Initialize secure random with system entropy
  static void _initializeSecureRandom() {
    // Random.secure() is already cryptographically secure
    // No manual seeding required
  }

  /// Generate X25519 key pair using audited cryptography library
  /// 
  /// Returns a key pair for ECDH key exchange
  /// Private key is 32 bytes, public key is 32 bytes
  static Future<X25519KeyPair> generateX25519KeyPair() async {
    try {
      // Use audited cryptography library for secure key generation
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final privateKey = await keyPair.extractPrivateKeyBytes();
      
      return X25519KeyPair(
        privateKey: Uint8List.fromList(privateKey),
        publicKey: Uint8List.fromList(publicKey.bytes),
      );
    } catch (e) {
      throw CryptoException('Failed to generate X25519 key pair: $e');
    }
  }

  /// Compute shared secret using audited x25519 library
  /// 
  /// Performs ECDH key exchange to derive shared secret
  /// [localPrivateKey] - Our private key (32 bytes)
  /// [peerPublicKey] - Remote device's public key (32 bytes)
  /// Returns shared secret (32 bytes)
  static Future<Uint8List> computeSharedSecret(
    Uint8List localPrivateKey,
    Uint8List peerPublicKey,
  ) async {
    try {
      // Validate key lengths
      if (localPrivateKey.length != 32) {
        throw CryptoException('Local private key must be 32 bytes');
      }
      if (peerPublicKey.length != 32) {
        throw CryptoException('Peer public key must be 32 bytes');
      }
      
      // Use audited cryptography library for secure ECDH operations
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPairFromSeed(localPrivateKey);
      final peerPublicKeyObj = SimplePublicKey(peerPublicKey, type: KeyPairType.x25519);
      final sharedSecretKey = await algorithm.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: peerPublicKeyObj,
      );
      final sharedSecret = await sharedSecretKey.extractBytes();
      
      // Verify shared secret is valid
      if (sharedSecret.length != 32) {
        throw CryptoException('Shared secret must be 32 bytes');
      }
      
      // Verify shared secret is not all zeros
      bool isAllZeros = true;
      for (int i = 0; i < sharedSecret.length; i++) {
        if (sharedSecret[i] != 0) {
          isAllZeros = false;
          break;
        }
      }
      
      if (isAllZeros) {
        throw CryptoException('Shared secret is all zeros - key exchange failed');
      }
      
      return Uint8List.fromList(sharedSecret);
    } catch (e) {
      throw CryptoException('Failed to compute shared secret: $e');
    }
  }

  /// Derive symmetric key using HKDF
  /// 
  /// [sharedSecret] - Shared secret from ECDH (32 bytes)
  /// [info] - Application-specific info (can be empty)
  /// [salt] - Optional salt (32 bytes, defaults to zeros)
  /// Returns derived symmetric key (32 bytes)
  static Future<Uint8List> hkdfDerive(
    Uint8List sharedSecret,
    Uint8List info, {
    Uint8List? salt,
  }) async {
    try {
      // Validate input parameters
      if (sharedSecret.length != 32) {
        throw CryptoException('Shared secret must be 32 bytes');
      }
      
      // Use zero salt if not provided (RFC 5869 compliant)
      final hkdfSalt = salt ?? Uint8List(32);
      
      // Use PointyCastle's HKDF implementation with SHA-256
      final hkdf = HKDFKeyDerivator(SHA256Digest());
      final params = HkdfParameters(sharedSecret, 32, hkdfSalt, info);
      hkdf.init(params);
      
      // Derive key with proper error handling
      final derivedKey = Uint8List(32);
      final derivedLength = hkdf.deriveKey(null, 0, derivedKey, 0);
      
      // Validate derived key length
      if (derivedLength != 32) {
        throw CryptoException('HKDF derived key length mismatch: expected 32, got $derivedLength');
      }
      
      // Verify derived key is not all zeros (security check)
      bool isAllZeros = true;
      for (int i = 0; i < derivedKey.length; i++) {
        if (derivedKey[i] != 0) {
          isAllZeros = false;
          break;
        }
      }
      
      if (isAllZeros) {
        throw CryptoException('HKDF derived key is all zeros - security violation');
      }
      
      return derivedKey;
    } catch (e) {
      throw CryptoException('Failed to derive key with HKDF: $e');
    }
  }

  /// Derive a 32-byte session key using symmetric HKDF salt construction.
  ///
  /// Both peers must call this with the same inputs to obtain identical keys.
  /// Salt is computed as sha256(concat(sorted([localPubKey, remotePubKey])) + utf8(sessionId)).
  /// Info is standardized as 'airlink/v1/session:<sessionId>'.
  static Future<Uint8List> deriveSessionKey(
    Uint8List sharedSecret,
    String sessionId,
    Uint8List localPublicKey,
    Uint8List remotePublicKey,
  ) async {
    if (sharedSecret.length != 32) {
      throw CryptoException('Shared secret must be 32 bytes');
    }
    if (localPublicKey.length != 32 || remotePublicKey.length != 32) {
      throw CryptoException('Public keys must be 32 bytes');
    }
    // Deterministic ordering of public keys
    final bool localFirst = _lexicographicallyLessOrEqual(localPublicKey, remotePublicKey);
    final Uint8List first = localFirst ? localPublicKey : remotePublicKey;
    final Uint8List second = localFirst ? remotePublicKey : localPublicKey;
    // Build salt input: concat(sorted pubkeys) + utf8(sessionId)
    final List<int> saltInput = <int>[...first, ...second, ...sessionId.codeUnits];
    final SHA256Digest digest = SHA256Digest();
    digest.update(Uint8List.fromList(saltInput), 0, saltInput.length);
    final Uint8List salt = Uint8List(digest.digestSize);
    digest.doFinal(salt, 0);
    // Standardized HKDF info
    final Uint8List info = Uint8List.fromList('airlink/v1/session:$sessionId'.codeUnits);
    return await hkdfDerive(sharedSecret, info, salt: salt);
  }

  static bool _lexicographicallyLessOrEqual(Uint8List a, Uint8List b) {
    final int len = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      if (a[i] != b[i]) {
        return a[i] < b[i];
      }
    }
    return a.length <= b.length;
  }

  /// Encrypt data using AES-GCM
  /// 
  /// [key] - Symmetric key (32 bytes)
  /// [iv] - Initialization vector (12 bytes)
  /// [aad] - Additional authenticated data
  /// [plaintext] - Data to encrypt
  /// Returns encrypted data with authentication tag
  static Future<AesGcmResult> aesGcmEncrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List aad,
    Uint8List plaintext,
  ) async {
    try {
      // Validate parameters
      if (key.length != 32) {
        throw CryptoException('Key must be 32 bytes (256 bits)');
      }
      if (iv.length != 12) {
        throw CryptoException('IV must be 12 bytes (96 bits)');
      }
      if (plaintext.isEmpty) {
        throw CryptoException('Plaintext cannot be empty');
      }
      
      // Security check: ensure key is not all zeros
      bool isKeyAllZeros = true;
      for (int i = 0; i < key.length; i++) {
        if (key[i] != 0) {
          isKeyAllZeros = false;
          break;
        }
      }
      if (isKeyAllZeros) {
        throw CryptoException('Encryption key cannot be all zeros');
      }
      
      // Security check: ensure IV is not all zeros (weak IV)
      bool isIvAllZeros = true;
      for (int i = 0; i < iv.length; i++) {
        if (iv[i] != 0) {
          isIvAllZeros = false;
          break;
        }
      }
      if (isIvAllZeros) {
        throw CryptoException('IV cannot be all zeros - use random IV');
      }
      
      // Create GCM cipher with AES-256
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        128, // 128-bit authentication tag
        iv,
        aad,
      );
      
      // Initialize for encryption
      cipher.init(true, params);
      
      // Encrypt plaintext and compute tag
      final ciphertextWithTag = Uint8List(plaintext.length + 16);
      final length = cipher.processBytes(
        plaintext,
        0,
        plaintext.length,
        ciphertextWithTag,
        0,
      );
      cipher.doFinal(ciphertextWithTag, length);
      
      // Split ciphertext and tag
      final ciphertext = ciphertextWithTag.sublist(0, plaintext.length);
      final tag = ciphertextWithTag.sublist(plaintext.length);
      
      // Verify tag is not all zeros (security check)
      bool isTagAllZeros = true;
      for (int i = 0; i < tag.length; i++) {
        if (tag[i] != 0) {
          isTagAllZeros = false;
          break;
        }
      }
      if (isTagAllZeros) {
        throw CryptoException('Authentication tag is all zeros - encryption failed');
      }
      
      return AesGcmResult(
        ciphertext: ciphertext,
        tag: tag,
        iv: iv,
      );
    } catch (e) {
      throw CryptoException('Failed to encrypt with AES-GCM: $e');
    }
  }

  /// Decrypt data using AES-GCM
  /// 
  /// [key] - Symmetric key (32 bytes)
  /// [iv] - Initialization vector (12 bytes)
  /// [aad] - Additional authenticated data
  /// [ciphertext] - Encrypted data
  /// [tag] - Authentication tag (16 bytes)
  /// Returns decrypted plaintext
  static Future<Uint8List> aesGcmDecrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List aad,
    Uint8List ciphertext,
    Uint8List tag,
  ) async {
    try {
      // Validate parameters
      if (key.length != 32) {
        throw CryptoException('Key must be 32 bytes (256 bits)');
      }
      if (iv.length != 12) {
        throw CryptoException('IV must be 12 bytes (96 bits)');
      }
      if (tag.length != 16) {
        throw CryptoException('Tag must be 16 bytes (128 bits)');
      }
      if (ciphertext.isEmpty) {
        throw CryptoException('Ciphertext cannot be empty');
      }
      
      // Security check: ensure key is not all zeros
      bool isKeyAllZeros = true;
      for (int i = 0; i < key.length; i++) {
        if (key[i] != 0) {
          isKeyAllZeros = false;
          break;
        }
      }
      if (isKeyAllZeros) {
        throw CryptoException('Decryption key cannot be all zeros');
      }
      
      // Security check: ensure tag is not all zeros
      bool isTagAllZeros = true;
      for (int i = 0; i < tag.length; i++) {
        if (tag[i] != 0) {
          isTagAllZeros = false;
          break;
        }
      }
      if (isTagAllZeros) {
        throw CryptoException('Authentication tag cannot be all zeros');
      }
      
      // Create GCM cipher with AES-256
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        128, // 128-bit authentication tag
        iv,
        aad,
      );
      
      // Initialize for decryption
      cipher.init(false, params);
      
      // Combine ciphertext and tag for decryption
      final ciphertextWithTag = Uint8List.fromList([...ciphertext, ...tag]);
      
      // Decrypt and verify tag
      final plaintext = Uint8List(ciphertext.length);
      final length = cipher.processBytes(
        ciphertextWithTag,
        0,
        ciphertextWithTag.length,
        plaintext,
        0,
      );
      cipher.doFinal(plaintext, length);
      
      return plaintext;
    } catch (e) {
      throw CryptoException('Failed to decrypt with AES-GCM: $e');
    }
  }

  /// Generate SHA-256 hash of chunk payload
  /// 
  /// [payload] - Data to hash
  /// Returns 32-byte SHA-256 hash
  static Future<Uint8List> chunkSHA256(Uint8List payload) async {
    try {
      final digest = SHA256Digest();
      
      // Update digest with payload
      digest.update(payload, 0, payload.length);
      
      // Finalize and get hash
      final hash = Uint8List(digest.digestSize);
      digest.doFinal(hash, 0);
      
      return hash;
    } catch (e) {
      throw CryptoException('Failed to generate SHA-256 hash: $e');
    }
  }

  /// Generate secure random bytes
  /// 
  /// [length] - Number of bytes to generate
  /// Returns cryptographically secure random bytes
  static Future<Uint8List> generateSecureRandom(int length) async {
    _initializeSecureRandom();
    
    // Use Dart's cryptographically secure random
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add(_secureRandom.nextInt(256));
    }
    return Uint8List.fromList(bytes);
  }

  /// Generate random IV for AES-GCM
  /// 
  /// Returns 12-byte random IV
  static Future<Uint8List> generateIV() async {
    return await generateSecureRandom(12);
  }

  /// Securely erase sensitive data from memory
  /// 
  /// [data] - Data to erase
  static void secureErase(Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }

  // REMOVED: _performX25519ECDH function
  // X25519 operations now handled directly in computeSharedSecret() using audited library
  

  // REMOVED: _computeX25519PublicKey function
  // Public key computation now handled directly in generateX25519KeyPair() using audited library
  

  /// Constant-time comparison to prevent timing attacks
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    
    return result == 0;
  }

  /// Constant-time conditional swap to prevent timing attacks
  /// 
  /// [a] - First value to potentially swap
  /// [b] - Second value to potentially swap  
  /// [swap] - If true, swap the values
  /// Returns tuple of (a, b) with potential swap applied
  static (Uint8List, Uint8List) constantTimeSwap(
    Uint8List a, 
    Uint8List b, 
    bool swap
  ) {
    if (a.length != b.length) {
      throw CryptoException('Values must have same length for constant-time swap');
    }
    
    // Convert boolean to integer mask (0 or -1)
    final mask = swap ? -1 : 0;
    
    final resultA = Uint8List(a.length);
    final resultB = Uint8List(b.length);
    
    for (int i = 0; i < a.length; i++) {
      // Constant-time conditional swap using XOR
      final aByte = a[i];
      final bByte = b[i];
      
      // If swap is true, mask is -1 (all 1s), otherwise 0 (all 0s)
      resultA[i] = (aByte & ~mask) | (bByte & mask);
      resultB[i] = (bByte & ~mask) | (aByte & mask);
    }
    
    return (resultA, resultB);
  }

  /// Constant-time conditional assignment
  /// 
  /// [condition] - If true, assign value, otherwise keep original
  /// [original] - Original value to potentially keep
  /// [value] - New value to potentially assign
  /// Returns original or value based on condition
  static Uint8List constantTimeSelect(
    bool condition,
    Uint8List original,
    Uint8List value,
  ) {
    if (original.length != value.length) {
      throw CryptoException('Values must have same length for constant-time select');
    }
    
    final mask = condition ? -1 : 0;
    final result = Uint8List(original.length);
    
    for (int i = 0; i < original.length; i++) {
      result[i] = (original[i] & ~mask) | (value[i] & mask);
    }
    
    return result;
  }

  /// Constant-time array copy with potential conditional selection
  /// 
  /// [source] - Source array
  /// [dest] - Destination array  
  /// [condition] - If true, copy source to dest, otherwise leave dest unchanged
  static void constantTimeCopy(
    Uint8List source,
    Uint8List dest,
    bool condition,
  ) {
    if (source.length != dest.length) {
      throw CryptoException('Source and destination must have same length');
    }
    
    final mask = condition ? -1 : 0;
    
    for (int i = 0; i < source.length; i++) {
      dest[i] = (dest[i] & ~mask) | (source[i] & mask);
    }
  }

  /// Secure memory comparison that doesn't leak timing information
  /// 
  /// [a] - First array
  /// [b] - Second array
  /// Returns true if arrays are equal, false otherwise
  static bool secureMemoryEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      // Still perform comparison to avoid timing leak about length difference
      final maxLen = a.length > b.length ? a.length : b.length;
      for (int i = 0; i < maxLen; i++) {
        final aByte = i < a.length ? a[i] : 0;
        final bByte = i < b.length ? b[i] : 0;
        // Perform comparison but don't use result to avoid timing leak
        aByte ^ bByte; // This operation takes constant time
      }
      return false;
    }
    
    return constantTimeEquals(a, b);
  }
}

/// X25519 Key Pair
class X25519KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  const X25519KeyPair({
    required this.privateKey,
    required this.publicKey,
  });

  /// Securely dispose of private key
  void dispose() {
    AirLinkCrypto.secureErase(privateKey);
  }
}

/// AES-GCM Encryption Result
class AesGcmResult {
  final Uint8List ciphertext;
  final Uint8List tag;
  final Uint8List iv;

  const AesGcmResult({
    required this.ciphertext,
    required this.tag,
    required this.iv,
  });

  /// Get combined ciphertext + tag
  Uint8List get combined => Uint8List.fromList([...ciphertext, ...tag]);
}

/// Cryptographic Exception
class CryptoException implements Exception {
  final String message;
  
  const CryptoException(this.message);
  
  @override
  String toString() => 'CryptoException: $message';
}
