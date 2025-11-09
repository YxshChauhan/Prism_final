class AppConstants {
  // App Information
  static const String appName = 'AirLink';
  static const String appVersion = '1.0.0';
  
  // Network Configuration
  static const int defaultPort = 8080;
  static const int maxConcurrentTransfers = 5;
  static const int chunkSize = 64 * 1024; // 64KB chunks
  static const int maxFileSize = 2 * 1024 * 1024 * 1024; // 2GB max file size
  
  // Discovery Configuration
  static const String serviceName = 'AirLink';
  static const String serviceType = '_airlink._tcp';
  static const Duration discoveryTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  // BLE Configuration
  static const String bleServiceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String bleCharacteristicUuid = '87654321-4321-4321-4321-cba987654321';
  static const Duration bleScanTimeout = Duration(seconds: 15);
  
  // Security Configuration
  static const int keySize = 256; // AES-256
  static const int ivSize = 12; // GCM IV size
  static const int tagSize = 16; // GCM tag size
  
  // File Types
  static const List<String> supportedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif'
  ];
  
  static const List<String> supportedVideoTypes = [
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'
  ];
  
  static const List<String> supportedDocumentTypes = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'
  ];
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double borderRadius = 12.0;
  static const double cardElevation = 4.0;
}
