import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';

/// Extraction History Item
class ExtractionHistoryItem {
  final String id;
  final String appName;
  final String packageName;
  final String apkPath;
  final DateTime extractedAt;
  final int fileSize;
  
  const ExtractionHistoryItem({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.apkPath,
    required this.extractedAt,
    required this.fileSize,
  });

  factory ExtractionHistoryItem.fromMap(Map<String, dynamic> map) {
    return ExtractionHistoryItem(
      id: map['id'] as String,
      appName: map['appName'] as String,
      packageName: map['packageName'] as String,
      apkPath: map['apkPath'] as String,
      extractedAt: DateTime.fromMillisecondsSinceEpoch(map['extractedAt'] as int),
      fileSize: map['fileSize'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appName': appName,
      'packageName': packageName,
      'apkPath': apkPath,
      'extractedAt': extractedAt.millisecondsSinceEpoch,
      'fileSize': fileSize,
    };
  }
}

/// APK Extractor Service
/// Provides app sharing functionality similar to SHAREit/Zapya
/// Allows users to extract, share, and install APK files
@injectable
class ApkExtractorService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<ApkEvent> _eventController = StreamController<ApkEvent>.broadcast();
  
  // Cache for installed apps
  final List<AppInfo> _installedApps = [];
  final Map<String, String> _extractedApks = {}; // packageName -> apkPath
  
  ApkExtractorService({
    required LoggerService logger,
    @Named('apkExtractor') required MethodChannel methodChannel,
    @Named('apkExtractorEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize APK extractor service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing APK extractor service...');
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('APK extractor event error: $error'),
      );
      
      // Load installed apps
      await _loadInstalledApps();
      
      _logger.info('APK extractor service initialized');
    } catch (e) {
      _logger.error('Failed to initialize APK extractor: $e');
      throw ApkExtractorException('Failed to initialize: $e');
    }
  }
  
  /// Get list of installed apps
  Future<List<AppInfo>> getInstalledApps({
    bool includeSystemApps = false,
    bool includeUserApps = true,
    String? searchQuery,
  }) async {
    try {
      _logger.info('Getting installed apps...');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getInstalledApps', {
        'includeSystemApps': includeSystemApps,
        'includeUserApps': includeUserApps,
        'searchQuery': searchQuery,
      });
      
      final List<dynamic> appsData = result['apps'] as List<dynamic>;
      final List<AppInfo> apps = appsData.map((data) => AppInfo.fromMap(Map<String, dynamic>.from(data))).toList();
      
      _installedApps.clear();
      _installedApps.addAll(apps);
      
      _logger.info('Found ${apps.length} installed apps');
      return apps;
    } catch (e) {
      _logger.error('Failed to get installed apps: $e');
      throw ApkExtractorException('Failed to get installed apps: $e');
    }
  }
  
  /// Get app info by package name
  Future<AppInfo?> getAppInfo(String packageName) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getAppInfo', {
        'packageName': packageName,
      });
      
      if (result['app'] != null) {
        return AppInfo.fromMap(Map<String, dynamic>.from(result['app']));
      }
      return null;
    } catch (e) {
      _logger.error('Failed to get app info: $e');
      return null;
    }
  }
  
  /// Extract APK for an app
  Future<String> extractApk(String packageName) async {
    try {
      _logger.info('Extracting APK for package: $packageName');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('extractApk', {
        'packageName': packageName,
      });
      
      final String apkPath = result['apkPath'] as String;
      _extractedApks[packageName] = apkPath;
      
      _logger.info('APK extracted to: $apkPath');
      return apkPath;
    } catch (e) {
      _logger.error('Failed to extract APK: $e');
      throw ApkExtractorException('Failed to extract APK: $e');
    }
  }
  
  /// Extract multiple APKs in batch
  Future<List<String>> extractMultipleApks(List<String> packageNames) async {
    try {
      _logger.info('Extracting ${packageNames.length} APKs...');
      
      final List<String> extractedPaths = [];
      
      for (final packageName in packageNames) {
        try {
          final apkPath = await extractApk(packageName);
          extractedPaths.add(apkPath);
        } catch (e) {
          _logger.warning('Failed to extract APK for $packageName: $e');
        }
      }
      
      _logger.info('Extracted ${extractedPaths.length} APKs');
      return extractedPaths;
    } catch (e) {
      _logger.error('Failed to extract multiple APKs: $e');
      throw ApkExtractorException('Failed to extract multiple APKs: $e');
    }
  }
  
  /// Get APK file info
  Future<ApkFileInfo> getApkFileInfo(String apkPath) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getApkFileInfo', {
        'apkPath': apkPath,
      });
      
      return ApkFileInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logger.error('Failed to get APK file info: $e');
      throw ApkExtractorException('Failed to get APK file info: $e');
    }
  }
  
  /// Share APK file
  Future<void> shareApk(String apkPath, {String? message}) async {
    try {
      _logger.info('Sharing APK: $apkPath');
      
      await _methodChannel.invokeMethod('shareApk', {
        'apkPath': apkPath,
        'message': message,
      });
      
      _logger.info('APK shared successfully');
    } catch (e) {
      _logger.error('Failed to share APK: $e');
      throw ApkExtractorException('Failed to share APK: $e');
    }
  }
  
  /// Install APK file
  Future<bool> installApk(String apkPath) async {
    try {
      _logger.info('Installing APK: $apkPath');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('installApk', {
        'apkPath': apkPath,
      });
      
      final bool success = result['success'] as bool;
      _logger.info('APK installation ${success ? 'successful' : 'failed'}');
      return success;
    } catch (e) {
      _logger.error('Failed to install APK: $e');
      return false;
    }
  }
  
  /// Uninstall app
  Future<bool> uninstallApp(String packageName) async {
    try {
      _logger.info('Uninstalling app: $packageName');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('uninstallApp', {
        'packageName': packageName,
      });
      
      final bool success = result['success'] as bool;
      _logger.info('App uninstallation ${success ? 'successful' : 'failed'}');
      return success;
    } catch (e) {
      _logger.error('Failed to uninstall app: $e');
      return false;
    }
  }
  
  /// Get app permissions
  Future<List<String>> getAppPermissions(String packageName) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getAppPermissions', {
        'packageName': packageName,
      });
      
      final List<dynamic> permissions = result['permissions'] as List<dynamic>;
      return permissions.map((p) => p as String).toList();
    } catch (e) {
      _logger.error('Failed to get app permissions: $e');
      return [];
    }
  }
  
  /// Check if app is installed
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('isAppInstalled', {
        'packageName': packageName,
      });
      
      return result['installed'] as bool;
    } catch (e) {
      _logger.error('Failed to check if app is installed: $e');
      return false;
    }
  }
  
  /// Get app version info
  Future<AppVersionInfo> getAppVersionInfo(String packageName) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getAppVersionInfo', {
        'packageName': packageName,
      });
      
      return AppVersionInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logger.error('Failed to get app version info: $e');
      throw ApkExtractorException('Failed to get app version info: $e');
    }
  }
  
  /// Create app backup (APK + data)
  Future<String> createAppBackup(String packageName) async {
    try {
      _logger.info('Creating app backup: $packageName');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('createAppBackup', {
        'packageName': packageName,
      });
      
      final String backupPath = result['backupPath'] as String;
      _logger.info('App backup created: $backupPath');
      return backupPath;
    } catch (e) {
      _logger.error('Failed to create app backup: $e');
      throw ApkExtractorException('Failed to create app backup: $e');
    }
  }
  
  /// Restore app from backup
  Future<bool> restoreAppFromBackup(String backupPath) async {
    try {
      _logger.info('Restoring app from backup: $backupPath');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('restoreAppFromBackup', {
        'backupPath': backupPath,
      });
      
      final bool success = result['success'] as bool;
      _logger.info('App restoration ${success ? 'successful' : 'failed'}');
      return success;
    } catch (e) {
      _logger.error('Failed to restore app from backup: $e');
      return false;
    }
  }
  
  /// Get extracted APK path
  String? getExtractedApkPath(String packageName) {
    return _extractedApks[packageName];
  }
  
  /// Clear extracted APKs cache
  Future<void> clearExtractedApks() async {
    try {
      for (final apkPath in _extractedApks.values) {
        try {
          final file = File(apkPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          _logger.warning('Failed to delete APK file: $apkPath');
        }
      }
      
      _extractedApks.clear();
      _logger.info('Extracted APKs cache cleared');
    } catch (e) {
      _logger.error('Failed to clear extracted APKs: $e');
    }
  }
  
  /// Stream of APK events
  Stream<ApkEvent> get eventStream => _eventController.stream;
  
  Future<void> _loadInstalledApps() async {
    try {
      await getInstalledApps();
    } catch (e) {
      _logger.warning('Failed to load installed apps: $e');
    }
  }
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'apkExtracted':
          final String packageName = eventData['packageName'] as String;
          final String apkPath = eventData['apkPath'] as String;
          _extractedApks[packageName] = apkPath;
          _eventController.add(ApkExtractedEvent(
            packageName: packageName,
            apkPath: apkPath,
            timestamp: DateTime.now(),
          ));
          break;
        case 'apkInstalled':
          final String packageName = eventData['packageName'] as String;
          _eventController.add(ApkInstalledEvent(
            packageName: packageName,
            timestamp: DateTime.now(),
          ));
          break;
        case 'appUninstalled':
          final String packageName = eventData['packageName'] as String;
          _eventController.add(AppUninstalledEvent(
            packageName: packageName,
            timestamp: DateTime.now(),
          ));
          break;
        case 'error':
          final String error = eventData['error'] as String;
          _eventController.add(ApkErrorEvent(
            error: error,
            timestamp: DateTime.now(),
          ));
          break;
      }
    } catch (e) {
      _logger.error('Failed to handle APK event: $e');
    }
  }
  
  /// Get extraction history
  Future<List<ExtractionHistoryItem>> getExtractionHistory() async {
    try {
      _logger.info('Getting extraction history...');
      
      final result = await _methodChannel.invokeMethod('getExtractionHistory');
      
      if (result is List) {
        return result.map((item) => ExtractionHistoryItem.fromMap(item)).toList();
      }
      
      return [];
    } catch (e) {
      _logger.error('Failed to get extraction history: $e');
      throw ApkExtractorException('Failed to get extraction history: $e');
    }
  }

  /// Delete from history
  Future<void> deleteFromHistory(String historyId) async {
    try {
      _logger.info('Deleting from history: $historyId');
      
      await _methodChannel.invokeMethod('deleteFromHistory', {'historyId': historyId});
      
      _logger.info('Deleted from history successfully');
    } catch (e) {
      _logger.error('Failed to delete from history: $e');
      throw ApkExtractorException('Failed to delete from history: $e');
    }
  }

  /// Get extracted APKs
  Future<List<ExtractedApk>> getExtractedApks() async {
    // TODO(apk-sharing): Implement extracted APKs retrieval via native method channel
    // Expected method: 'getExtractedApks' returning a list of maps
    try {
      final dynamic result = await _methodChannel.invokeMethod('getExtractedApks');
      if (result is List) {
        return result.map((e) => ExtractedApk.fromMap(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    } catch (e) {
      _logger.error('Failed to get extracted APKs: $e');
      return [];
    }
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// App info model
class AppInfo {
  final String packageName;
  final String appName;
  final String versionName;
  final int versionCode;
  final String? iconPath;
  final int size;
  final DateTime installDate;
  final DateTime updateDate;
  final bool isSystemApp;
  final bool isUserApp;
  final List<String> permissions;
  final String? sourceDir;
  final String? dataDir;
  
  const AppInfo({
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.versionCode,
    this.iconPath,
    required this.size,
    required this.installDate,
    required this.updateDate,
    required this.isSystemApp,
    required this.isUserApp,
    required this.permissions,
    this.sourceDir,
    this.dataDir,
  });
  
  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      versionName: map['versionName'] as String,
      versionCode: map['versionCode'] as int,
      iconPath: map['iconPath'] as String?,
      size: map['size'] as int,
      installDate: DateTime.fromMillisecondsSinceEpoch(map['installDate'] as int),
      updateDate: DateTime.fromMillisecondsSinceEpoch(map['updateDate'] as int),
      isSystemApp: map['isSystemApp'] as bool,
      isUserApp: map['isUserApp'] as bool,
      permissions: List<String>.from(map['permissions'] as List<dynamic>),
      sourceDir: map['sourceDir'] as String?,
      dataDir: map['dataDir'] as String?,
    );
  }
  
  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// APK file info model
class ApkFileInfo {
  final String apkPath;
  final String packageName;
  final String appName;
  final String versionName;
  final int versionCode;
  final int fileSize;
  final String? iconPath;
  final List<String> permissions;
  final String? signature;
  final DateTime createdDate;
  
  const ApkFileInfo({
    required this.apkPath,
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.versionCode,
    required this.fileSize,
    this.iconPath,
    required this.permissions,
    this.signature,
    required this.createdDate,
  });
  
  factory ApkFileInfo.fromMap(Map<String, dynamic> map) {
    return ApkFileInfo(
      apkPath: map['apkPath'] as String,
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      versionName: map['versionName'] as String,
      versionCode: map['versionCode'] as int,
      fileSize: map['fileSize'] as int,
      iconPath: map['iconPath'] as String?,
      permissions: List<String>.from(map['permissions'] as List<dynamic>),
      signature: map['signature'] as String?,
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate'] as int),
    );
  }
  
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// App version info model
class AppVersionInfo {
  final String packageName;
  final String versionName;
  final int versionCode;
  final String? minSdkVersion;
  final String? targetSdkVersion;
  final String? compileSdkVersion;
  final DateTime installDate;
  final DateTime updateDate;
  
  const AppVersionInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    this.minSdkVersion,
    this.targetSdkVersion,
    this.compileSdkVersion,
    required this.installDate,
    required this.updateDate,
  });
  
  factory AppVersionInfo.fromMap(Map<String, dynamic> map) {
    return AppVersionInfo(
      packageName: map['packageName'] as String,
      versionName: map['versionName'] as String,
      versionCode: map['versionCode'] as int,
      minSdkVersion: map['minSdkVersion'] as String?,
      targetSdkVersion: map['targetSdkVersion'] as String?,
      compileSdkVersion: map['compileSdkVersion'] as String?,
      installDate: DateTime.fromMillisecondsSinceEpoch(map['installDate'] as int),
      updateDate: DateTime.fromMillisecondsSinceEpoch(map['updateDate'] as int),
    );
  }
}

/// APK event base class
abstract class ApkEvent {
  final String type;
  final DateTime timestamp;
  
  const ApkEvent({
    required this.type,
    required this.timestamp,
  });
}

class ApkExtractedEvent extends ApkEvent {
  final String packageName;
  final String apkPath;
  
  const ApkExtractedEvent({
    required this.packageName,
    required this.apkPath,
    required super.timestamp,
  }) : super(type: 'apkExtracted');
}

class ApkInstalledEvent extends ApkEvent {
  final String packageName;
  
  const ApkInstalledEvent({
    required this.packageName,
    required super.timestamp,
  }) : super(type: 'apkInstalled');
}

class AppUninstalledEvent extends ApkEvent {
  final String packageName;
  
  const AppUninstalledEvent({
    required this.packageName,
    required super.timestamp,
  }) : super(type: 'appUninstalled');
}

class ApkErrorEvent extends ApkEvent {
  final String error;
  
  const ApkErrorEvent({
    required this.error,
    required super.timestamp,
  }) : super(type: 'error');
}

/// APK extractor exception
class ApkExtractorException implements Exception {
  final String message;
  const ApkExtractorException(this.message);
  
  @override
  String toString() => 'ApkExtractorException: $message';
}
