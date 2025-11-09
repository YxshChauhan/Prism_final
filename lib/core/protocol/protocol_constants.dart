/// AirLink Protocol Constants
class ProtocolConstants {
  // Frame Types
  static const int frameTypeControl = 0;
  static const int frameTypeData = 1;
  
  // Control Frame Subtypes
  static const int controlSubtypeDiscovery = 0;
  static const int controlSubtypeKeyExchange = 1;
  static const int controlSubtypeAck = 2;
  static const int controlSubtypeHandshake = 3;
  static const int controlSubtypeCancel = 4;
  
  // Default Configuration
  static const int defaultChunkSize = 256 * 1024; // 256KB
  static const int defaultWindowSize = 4;
  static const int maxWindowSize = 16;
  static const int minChunkSize = 64 * 1024; // 64KB
  static const int maxChunkSize = 1024 * 1024; // 1MB
  
  // Protocol Version
  static const int protocolVersion = 1;
  
  // Handshake Timeouts
  static const Duration handshakeTimeout = Duration(seconds: 30);
  static const Duration discoveryTimeout = Duration(seconds: 10);
  static const Duration keyExchangeTimeout = Duration(seconds: 15);
  
  // Transfer Timeouts
  static const Duration chunkTimeout = Duration(seconds: 30);
  static const Duration ackTimeout = Duration(seconds: 5);
  static const Duration connectionTimeout = Duration(seconds: 60);
  
  // Retry Configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 1000);
  
  // Encryption
  static const int ivLength = 12; // AES-GCM IV length
  static const int keyLength = 32; // AES-256 key length
  static const int tagLength = 16; // AES-GCM tag length
  static const int hashLength = 32; // SHA-256 hash length
  
  // Discovery
  static const String serviceName = 'AirLink';
  static const String serviceType = '_airlink._tcp';
  static const int discoveryPort = 0; // Auto-assign
  
  // Socket Configuration
  static const int socketBufferSize = 64 * 1024; // 64KB
  static const Duration socketTimeout = Duration(seconds: 30);
  
  // Frame Size Limits
  static const int maxFrameSize = 10 * 1024 * 1024; // 10MB maximum frame size
  
  // Resume Database
  static const String resumeDbName = 'airlink_resume.db';
  static const int resumeDbVersion = 1;
}
