import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';

/// Comprehensive Settings Service
/// Manages app settings, preferences, and configuration
/// Provides secure storage for sensitive settings
@injectable
class SettingsService extends ChangeNotifier {
  final LoggerService _logger;
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  
  // Settings cache
  final Map<String, dynamic> _settingsCache = {};
  
  // Settings keys
  static const String _themeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _autoAcceptTransfersKey = 'auto_accept_transfers';
  static const String _compressionQualityKey = 'compression_quality';
  static const String _maxConcurrentTransfersKey = 'max_concurrent_transfers';
  static const String _deviceNameKey = 'device_name';
  static const String _discoveryEnabledKey = 'discovery_enabled';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _wifiOnlyKey = 'wifi_only';
  static const String _backgroundTransfersKey = 'background_transfers';
  static const String _encryptionEnabledKey = 'encryption_enabled';
  static const String _certificatePinningKey = 'certificate_pinning';
  static const String _debugModeKey = 'debug_mode';
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const String _crashReportingKey = 'crash_reporting';
  static const String _storageLocationKey = 'storage_location';
  static const String _fileTypesKey = 'allowed_file_types';
  static const String _transferHistoryRetentionKey = 'transfer_history_retention';
  
  // Secure settings keys
  static const String _deviceIdKey = 'device_id';
  
  SettingsService({
    required LoggerService logger,
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
  }) : _logger = logger,
       _prefs = prefs,
       _secureStorage = secureStorage;
  
  /// Initialize settings service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing settings service...');
      await _loadSettings();
      _logger.info('Settings service initialized');
    } catch (e) {
      _logger.error('Failed to initialize settings: $e');
      throw Exception('Failed to initialize settings: $e');
    }
  }
  
  /// Load all settings from storage
  Future<void> _loadSettings() async {
    // Load regular settings
    _settingsCache[_themeKey] = _prefs.getString(_themeKey) ?? 'system';
    _settingsCache[_languageKey] = _prefs.getString(_languageKey) ?? 'en';
    _settingsCache[_autoAcceptTransfersKey] = _prefs.getBool(_autoAcceptTransfersKey) ?? false;
    _settingsCache[_compressionQualityKey] = _prefs.getDouble(_compressionQualityKey) ?? 0.8;
    _settingsCache[_maxConcurrentTransfersKey] = _prefs.getInt(_maxConcurrentTransfersKey) ?? 5;
    _settingsCache[_deviceNameKey] = _prefs.getString(_deviceNameKey) ?? 'AirLink Device';
    _settingsCache[_discoveryEnabledKey] = _prefs.getBool(_discoveryEnabledKey) ?? true;
    _settingsCache[_notificationsEnabledKey] = _prefs.getBool(_notificationsEnabledKey) ?? true;
    _settingsCache[_soundEnabledKey] = _prefs.getBool(_soundEnabledKey) ?? true;
    _settingsCache[_vibrationEnabledKey] = _prefs.getBool(_vibrationEnabledKey) ?? true;
    _settingsCache[_wifiOnlyKey] = _prefs.getBool(_wifiOnlyKey) ?? false;
    _settingsCache[_backgroundTransfersKey] = _prefs.getBool(_backgroundTransfersKey) ?? true;
    _settingsCache[_encryptionEnabledKey] = _prefs.getBool(_encryptionEnabledKey) ?? true;
    _settingsCache[_certificatePinningKey] = _prefs.getBool(_certificatePinningKey) ?? false;
    _settingsCache[_debugModeKey] = _prefs.getBool(_debugModeKey) ?? kDebugMode;
    _settingsCache[_analyticsEnabledKey] = _prefs.getBool(_analyticsEnabledKey) ?? true;
    _settingsCache[_crashReportingKey] = _prefs.getBool(_crashReportingKey) ?? true;
    _settingsCache[_storageLocationKey] = _prefs.getString(_storageLocationKey) ?? '';
    _settingsCache[_transferHistoryRetentionKey] = _prefs.getInt(_transferHistoryRetentionKey) ?? 30;
    
    // Load file types
    final fileTypesJson = _prefs.getString(_fileTypesKey);
    if (fileTypesJson != null) {
      try {
        _settingsCache[_fileTypesKey] = jsonDecode(fileTypesJson);
      } catch (e) {
        _logger.warning('Failed to parse file types setting: $e');
        _settingsCache[_fileTypesKey] = _getDefaultFileTypes();
      }
    } else {
      _settingsCache[_fileTypesKey] = _getDefaultFileTypes();
    }
  }
  
  /// Get default allowed file types
  List<String> _getDefaultFileTypes() {
    return [
      // Images
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'ico', 'heic', 'heif',
      // Videos
      'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp',
      // Audio
      'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma',
      // Documents
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf',
      // Archives
      'zip', 'rar', '7z', 'tar', 'gz',
      // Other
      'apk', 'ipa', 'json', 'xml', 'csv',
    ];
  }
  
  // Getters for settings
  String get themeMode => _settingsCache[_themeKey] ?? 'system';
  String get language => _settingsCache[_languageKey] ?? 'en';
  bool get autoAcceptTransfers => _settingsCache[_autoAcceptTransfersKey] ?? false;
  double get compressionQuality => _settingsCache[_compressionQualityKey] ?? 0.8;
  int get maxConcurrentTransfers => _settingsCache[_maxConcurrentTransfersKey] ?? 5;
  String get deviceName => _settingsCache[_deviceNameKey] ?? 'AirLink Device';
  bool get discoveryEnabled => _settingsCache[_discoveryEnabledKey] ?? true;
  bool get notificationsEnabled => _settingsCache[_notificationsEnabledKey] ?? true;
  bool get soundEnabled => _settingsCache[_soundEnabledKey] ?? true;
  bool get vibrationEnabled => _settingsCache[_vibrationEnabledKey] ?? true;
  bool get wifiOnly => _settingsCache[_wifiOnlyKey] ?? false;
  bool get backgroundTransfers => _settingsCache[_backgroundTransfersKey] ?? true;
  bool get encryptionEnabled => _settingsCache[_encryptionEnabledKey] ?? true;
  bool get certificatePinning => _settingsCache[_certificatePinningKey] ?? false;
  bool get debugMode => _settingsCache[_debugModeKey] ?? kDebugMode;
  bool get analyticsEnabled => _settingsCache[_analyticsEnabledKey] ?? true;
  bool get crashReporting => _settingsCache[_crashReportingKey] ?? true;
  String get storageLocation => _settingsCache[_storageLocationKey] ?? '';
  List<String> get allowedFileTypes => List<String>.from(_settingsCache[_fileTypesKey] ?? _getDefaultFileTypes());
  int get transferHistoryRetention => _settingsCache[_transferHistoryRetentionKey] ?? 30;
  
  // Setters for settings
  Future<void> setThemeMode(String value) async {
    await _setSetting(_themeKey, value);
  }
  
  Future<void> setLanguage(String value) async {
    await _setSetting(_languageKey, value);
  }
  
  Future<void> setAutoAcceptTransfers(bool value) async {
    await _setSetting(_autoAcceptTransfersKey, value);
  }
  
  Future<void> setCompressionQuality(double value) async {
    await _setSetting(_compressionQualityKey, value);
  }
  
  Future<void> setMaxConcurrentTransfers(int value) async {
    await _setSetting(_maxConcurrentTransfersKey, value);
  }
  
  Future<void> setDeviceName(String value) async {
    await _setSetting(_deviceNameKey, value);
  }
  
  Future<void> setDiscoveryEnabled(bool value) async {
    await _setSetting(_discoveryEnabledKey, value);
  }
  
  Future<void> setNotificationsEnabled(bool value) async {
    await _setSetting(_notificationsEnabledKey, value);
  }
  
  Future<void> setSoundEnabled(bool value) async {
    await _setSetting(_soundEnabledKey, value);
  }
  
  Future<void> setVibrationEnabled(bool value) async {
    await _setSetting(_vibrationEnabledKey, value);
  }
  
  Future<void> setWifiOnly(bool value) async {
    await _setSetting(_wifiOnlyKey, value);
  }
  
  Future<void> setBackgroundTransfers(bool value) async {
    await _setSetting(_backgroundTransfersKey, value);
  }
  
  Future<void> setEncryptionEnabled(bool value) async {
    await _setSetting(_encryptionEnabledKey, value);
  }
  
  Future<void> setCertificatePinning(bool value) async {
    await _setSetting(_certificatePinningKey, value);
  }
  
  Future<void> setDebugMode(bool value) async {
    await _setSetting(_debugModeKey, value);
  }
  
  Future<void> setAnalyticsEnabled(bool value) async {
    await _setSetting(_analyticsEnabledKey, value);
  }
  
  Future<void> setCrashReporting(bool value) async {
    await _setSetting(_crashReportingKey, value);
  }
  
  Future<void> setStorageLocation(String value) async {
    await _setSetting(_storageLocationKey, value);
  }
  
  Future<void> setAllowedFileTypes(List<String> value) async {
    await _setSetting(_fileTypesKey, jsonEncode(value));
  }
  
  Future<void> setTransferHistoryRetention(int value) async {
    await _setSetting(_transferHistoryRetentionKey, value);
  }
  
  /// Generic setting setter
  Future<void> _setSetting(String key, dynamic value) async {
    try {
      _settingsCache[key] = value;
      
      if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      }
      
      notifyListeners();
      _logger.debug('Setting updated: $key = $value');
    } catch (e) {
      _logger.error('Failed to set setting $key: $e');
      throw Exception('Failed to update setting: $e');
    }
  }
  
  // Secure settings methods
  Future<String?> getSecureSetting(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      _logger.error('Failed to read secure setting $key: $e');
      return null;
    }
  }
  
  Future<void> setSecureSetting(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      _logger.debug('Secure setting updated: $key');
    } catch (e) {
      _logger.error('Failed to set secure setting $key: $e');
      throw Exception('Failed to update secure setting: $e');
    }
  }
  
  Future<void> deleteSecureSetting(String key) async {
    try {
      await _secureStorage.delete(key: key);
      _logger.debug('Secure setting deleted: $key');
    } catch (e) {
      _logger.error('Failed to delete secure setting $key: $e');
    }
  }
  
  // Device ID management
  Future<String> getDeviceId() async {
    String? deviceId = await getSecureSetting(_deviceIdKey);
    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await setSecureSetting(_deviceIdKey, deviceId);
    }
    return deviceId;
  }
  
  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return 'airlink_${random.substring(random.length - 12)}';
  }
  
  // Export/Import settings
  Future<Map<String, dynamic>> exportSettings() async {
    final settings = Map<String, dynamic>.from(_settingsCache);
    settings['exported_at'] = DateTime.now().toIso8601String();
    settings['version'] = '1.0';
    return settings;
  }
  
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      for (final entry in settings.entries) {
        if (entry.key.startsWith('_') || entry.key == 'exported_at' || entry.key == 'version') {
          continue; // Skip internal keys
        }
        await _setSetting(entry.key, entry.value);
      }
      _logger.info('Settings imported successfully');
    } catch (e) {
      _logger.error('Failed to import settings: $e');
      throw Exception('Failed to import settings: $e');
    }
  }
  
  // Reset settings
  Future<void> resetToDefaults() async {
    try {
      await _prefs.clear();
      await _secureStorage.deleteAll();
      await _loadSettings();
      notifyListeners();
      _logger.info('Settings reset to defaults');
    } catch (e) {
      _logger.error('Failed to reset settings: $e');
      throw Exception('Failed to reset settings: $e');
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}
