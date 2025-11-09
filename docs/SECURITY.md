# Security Guide

## Security Architecture Overview
- End-to-end encryption with AES-256-GCM
- X25519 (Curve25519) key exchange for session keys
- HKDF-SHA256 key derivation with per-session salt and info
- Zero-knowledge architecture (no server storage)

## Key Exchange Protocol
1. Generate ephemeral X25519 key pair per session
2. Exchange public keys over the chosen transport (QR, Wi‑Fi Aware, BLE, Multipeer)
3. Compute shared secret via X25519
4. Derive symmetric key with HKDF-SHA256 (salt = random 16 bytes, info = "airlink/v1/session")
5. Verify handshake by exchanging an authenticated test message

## Encryption Implementation
- Cipher: AES-256-GCM
- Key size: 256-bit (32 bytes)
- Nonce: Random 12 bytes per chunk/message
- AAD: Chunk metadata (transferId, fileId, sequence)
- Authentication tag verified on decryption; failures abort transfer

## Best Practices
- Never hardcode passwords or keys
- Validate encryption keys (length == 32, non-trivial)
- Use secure random for all secrets and nonces
- Zeroize sensitive buffers when possible
- Validate and sanitize all external inputs
- Prevent path traversal for file operations
- Enforce resource limits to mitigate DoS

## Threat Model
- Passive eavesdropping → Encrypted channel
- Active MITM → Handshake verification with key confirmation
- Replay attacks → Nonces and sequence numbers
- DoS → Resource limits and timeouts
- Malicious files → User awareness; consider antivirus scanning externally

## Security Audit Checklist
- [ ] No hardcoded credentials
- [ ] All network data encrypted post-handshake
- [ ] Input validation on native/plugin methods
- [ ] Path traversal prevention implemented
- [ ] Resource limits enforced
- [ ] Secure key storage (Keychain/Keystore)
- [ ] Proper error handling without sensitive leakage
- [ ] Secure random usage verified

## Known Limitations
- Device identity based on user verification (QR/device name)
- No CA/PKI for device identities
- Local-network operation only; no relay servers
- Integrity checks depend on file checksums

## Reporting Security Issues
Please open a private issue or contact the maintainers per the repository policy. Follow responsible disclosure. We aim to acknowledge within 72 hours.


