/// Feature flags for controlling app functionality
/// 
/// This file centralizes all feature availability flags to enable/disable
/// features during development and production releases.
class FeatureFlags {
  // Core Features
  static const bool DISCOVERY_ENABLED = true;
  static const bool TRANSFER_ENABLED = true;
  static const bool RESUME_ENABLED = true;
  static const bool ENCRYPTION_ENABLED = true;
  
  // Advanced Features - ALL NOW ENABLED WITH COMPLETE BACKENDS
  static const bool MEDIA_PLAYER_ENABLED = true;
  static const bool FILE_MANAGER_ENABLED = true;
  static const bool APK_SHARING_ENABLED = true;
  static const bool CLOUD_SYNC_ENABLED = true;
  static const bool VIDEO_COMPRESSION_ENABLED = true;
  static const bool PHONE_REPLICATION_ENABLED = true;
  static const bool GROUP_SHARING_ENABLED = true;

  // Connectivity Features
  static const bool QR_CONNECTION_ENABLED = true; // QR pairing flow
  static const bool BENCHMARKING_ENABLED = true; // Benchmarking service UI hooks
  
  // Platform Features
  static const bool ANDROID_WIFI_AWARE_ENABLED = true;
  static const bool ANDROID_BLE_ENABLED = true;
  static const bool IOS_MULTIPEER_ENABLED = true;
  static const bool IOS_BLE_ENABLED = true;
  
  // UI Features
  static const bool DARK_MODE_ENABLED = true;
  static const bool ANIMATIONS_ENABLED = true;
  static const bool HAPTIC_FEEDBACK_ENABLED = true;
  static const bool ACCESSIBILITY_ENABLED = true;
  
  // Development Features
  static const bool DEBUG_LOGGING_ENABLED = true;
  static const bool MOCK_DATA_ENABLED = false;
  static const bool PERFORMANCE_MONITORING_ENABLED = true;
  static const bool ERROR_REPORTING_ENABLED = true;
  
  // Security Features
  static const bool CERTIFICATE_PINNING_ENABLED = false; // TODO: Implement certificate pinning
  static const bool BIOMETRIC_AUTH_ENABLED = false; // TODO: Implement biometric authentication
  static const bool KEY_ROTATION_ENABLED = false; // Symmetric key renegotiation implemented but disabled until end-to-end tested
  
  // Network Features
  static const bool AUTO_DISCOVERY_ENABLED = true;
  static const bool BACKGROUND_TRANSFER_ENABLED = true;
  static const bool MULTIPLE_CONNECTIONS_ENABLED = true;
  static const bool CONNECTION_POOLING_ENABLED = false; // Disabled - not implemented yet
  
  /// Get feature status with fallback
  static bool isEnabled(String featureName, {bool fallback = false}) {
    switch (featureName.toLowerCase()) {
      case 'discovery':
        return DISCOVERY_ENABLED;
      case 'transfer':
        return TRANSFER_ENABLED;
      case 'resume':
        return RESUME_ENABLED;
      case 'encryption':
        return ENCRYPTION_ENABLED;
      case 'media_player':
        return MEDIA_PLAYER_ENABLED;
      case 'file_manager':
        return FILE_MANAGER_ENABLED;
      case 'apk_sharing':
        return APK_SHARING_ENABLED;
      case 'cloud_sync':
        return CLOUD_SYNC_ENABLED;
      case 'video_compression':
        return VIDEO_COMPRESSION_ENABLED;
      case 'phone_replication':
        return PHONE_REPLICATION_ENABLED;
      case 'group_sharing':
        return GROUP_SHARING_ENABLED;
      case 'android_wifi_aware':
        return ANDROID_WIFI_AWARE_ENABLED;
      case 'android_ble':
        return ANDROID_BLE_ENABLED;
      case 'ios_multipeer':
        return IOS_MULTIPEER_ENABLED;
      case 'ios_ble':
        return IOS_BLE_ENABLED;
      case 'dark_mode':
        return DARK_MODE_ENABLED;
      case 'animations':
        return ANIMATIONS_ENABLED;
      case 'haptic_feedback':
        return HAPTIC_FEEDBACK_ENABLED;
      case 'accessibility':
        return ACCESSIBILITY_ENABLED;
      case 'debug_logging':
        return DEBUG_LOGGING_ENABLED;
      case 'mock_data':
        return MOCK_DATA_ENABLED;
      case 'performance_monitoring':
        return PERFORMANCE_MONITORING_ENABLED;
      case 'error_reporting':
        return ERROR_REPORTING_ENABLED;
      case 'certificate_pinning':
        return CERTIFICATE_PINNING_ENABLED;
      case 'biometric_auth':
        return BIOMETRIC_AUTH_ENABLED;
      case 'key_rotation':
        return KEY_ROTATION_ENABLED;
      case 'auto_discovery':
        return AUTO_DISCOVERY_ENABLED;
      case 'background_transfer':
        return BACKGROUND_TRANSFER_ENABLED;
      case 'multiple_connections':
        return MULTIPLE_CONNECTIONS_ENABLED;
      case 'connection_pooling':
        return CONNECTION_POOLING_ENABLED;
      default:
        return fallback;
    }
  }
  
  /// Get all enabled features
  static List<String> getEnabledFeatures() {
    final features = <String>[];
    
    if (DISCOVERY_ENABLED) features.add('Discovery');
    if (TRANSFER_ENABLED) features.add('Transfer');
    if (RESUME_ENABLED) features.add('Resume');
    if (ENCRYPTION_ENABLED) features.add('Encryption');
    if (MEDIA_PLAYER_ENABLED) features.add('Media Player');
    if (FILE_MANAGER_ENABLED) features.add('File Manager');
    if (APK_SHARING_ENABLED) features.add('APK Sharing');
    if (CLOUD_SYNC_ENABLED) features.add('Cloud Sync');
    if (VIDEO_COMPRESSION_ENABLED) features.add('Video Compression');
    if (PHONE_REPLICATION_ENABLED) features.add('Phone Replication');
    if (GROUP_SHARING_ENABLED) features.add('Group Sharing');
    
    return features;
  }
  
  /// Get all disabled features
  static List<String> getDisabledFeatures() {
    final features = <String>[];
    
    if (!MEDIA_PLAYER_ENABLED) features.add('Media Player');
    if (!FILE_MANAGER_ENABLED) features.add('File Manager');
    if (!APK_SHARING_ENABLED) features.add('APK Sharing');
    if (!CLOUD_SYNC_ENABLED) features.add('Cloud Sync');
    if (!VIDEO_COMPRESSION_ENABLED) features.add('Video Compression');
    if (!PHONE_REPLICATION_ENABLED) features.add('Phone Replication');
    if (!GROUP_SHARING_ENABLED) features.add('Group Sharing');
    
    return features;
  }
  
  /// Check if feature is in development
  static bool isInDevelopment(String featureName) {
    return getDisabledFeatures().contains(featureName);
  }
  
  /// Get feature completion percentage
  static int getFeatureCompletion(String featureName) {
    switch (featureName.toLowerCase()) {
      case 'discovery':
        return 100;
      case 'transfer':
        return 100;
      case 'resume':
        return 100;
      case 'encryption':
        return 100;
      case 'media_player':
        return 100; // Full backend + UI implementation
      case 'file_manager':
        return 100; // Full backend + UI implementation
      case 'apk_sharing':
        return 100; // Full backend + UI implementation
      case 'cloud_sync':
        return 100; // Full backend + UI implementation
      case 'video_compression':
        return 100; // Full backend + UI implementation
      case 'phone_replication':
        return 100; // Full backend + UI implementation
      case 'group_sharing':
        return 100; // Full backend + UI implementation
      case 'qr_connection':
        return 100;
      case 'benchmarking':
        return 100;
      default:
        return 0;
    }
  }
}
