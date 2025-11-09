import 'package:permission_handler/permission_handler.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

@injectable
class PermissionService {
  final LoggerService _loggerService = LoggerService();
  
  // Permission status cache
  final Map<Permission, PermissionStatus> _permissionCache = {};
  final Map<Permission, DateTime> _lastChecked = {};
  
  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 5);
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to request location permission: $e',
      );
    }
  }
  
  Future<bool> requestBluetoothPermission() async {
    try {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to request bluetooth permission: $e',
      );
    }
  }
  
  Future<bool> requestStoragePermission() async {
    try {
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to request storage permission: $e',
      );
    }
  }
  
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to request camera permission: $e',
      );
    }
  }
  
  Future<bool> hasLocationPermission() async {
    try {
      final status = await Permission.location.status;
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to check location permission: $e',
      );
    }
  }
  
  Future<bool> hasBluetoothPermission() async {
    try {
      final status = await Permission.bluetooth.status;
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to check bluetooth permission: $e',
      );
    }
  }
  
  Future<bool> hasStoragePermission() async {
    try {
      final status = await Permission.storage.status;
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to check storage permission: $e',
      );
    }
  }
  
  Future<bool> hasCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      throw PermissionException(
        message: 'Failed to check camera permission: $e',
      );
    }
  }
  
  Future<bool> requestAllRequiredPermissions() async {
    try {
      final permissions = _getRequiredPermissions();
      // Refine Android 13+ media permissions
      if (Platform.isAndroid) {
        try {
          final int sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
          if (sdkInt >= 33) {
            permissions.remove(Permission.storage);
            permissions.addAll([Permission.photos, Permission.videos, Permission.audio]);
          }
        } catch (_) {}
      }
      
      final statuses = await permissions.request();
      
      // Update cache
      for (final entry in statuses.entries) {
        _permissionCache[entry.key] = entry.value;
        _lastChecked[entry.key] = DateTime.now();
      }
      
      final allGranted = statuses.values.every((status) => status.isGranted);
      
      if (allGranted) {
        _loggerService.info('All required permissions granted');
      } else {
        _loggerService.warning('Some permissions were denied');
        _logPermissionStatuses(statuses);
      }
      
      return allGranted;
    } catch (e) {
      _loggerService.error('Failed to request required permissions: $e');
      throw PermissionException(
        message: 'Failed to request required permissions: $e',
      );
    }
  }
  
  /// Get all required permissions for the app
  List<Permission> _getRequiredPermissions() {
    final permissions = <Permission>[
      Permission.location,
      Permission.bluetooth,
    ];
    
    // Add platform-specific permissions
    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
        Permission.notification,
      ]);
      // Android 13+ scoped media vs legacy storage
      // Checked at call time to avoid async in this getter; default to legacy storage, caller may refine
      // Will be refined in requestAllRequiredPermissions via SDK check
      permissions.add(Permission.storage);
    } else if (Platform.isIOS) {
      permissions.addAll([
        Permission.bluetooth,
        Permission.photos,
        Permission.camera,
        Permission.microphone,
      ]);
    }
    
    return permissions;
  }
  
  /// Check if all required permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    try {
      final permissions = _getRequiredPermissions();
      // Refine Android 13+ media permissions on check path too
      if (Platform.isAndroid) {
        try {
          final int sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
          if (sdkInt >= 33) {
            permissions.remove(Permission.storage);
            if (!permissions.contains(Permission.photos)) permissions.add(Permission.photos);
            if (!permissions.contains(Permission.videos)) permissions.add(Permission.videos);
            if (!permissions.contains(Permission.audio)) permissions.add(Permission.audio);
          }
        } catch (_) {}
      }
      
      for (final permission in permissions) {
        if (!await _hasPermission(permission)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      _loggerService.error('Failed to check required permissions: $e');
      return false;
    }
  }
  
  /// Check permission status with caching
  Future<bool> _hasPermission(Permission permission) async {
    try {
      // Check cache first
      final lastChecked = _lastChecked[permission];
      if (lastChecked != null && 
          DateTime.now().difference(lastChecked) < _cacheDuration) {
        final cachedStatus = _permissionCache[permission];
        if (cachedStatus != null) {
          return cachedStatus.isGranted;
        }
      }
      
      // Check actual permission status
      final status = await permission.status;
      
      // Update cache
      _permissionCache[permission] = status;
      _lastChecked[permission] = DateTime.now();
      
      return status.isGranted;
    } catch (e) {
      _loggerService.error('Failed to check permission $permission: $e');
      return false;
    }
  }
  
  /// Request permission with retry logic
  Future<bool> requestPermissionWithRetry(
    Permission permission, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final status = await permission.request();
        
        // Update cache
        _permissionCache[permission] = status;
        _lastChecked[permission] = DateTime.now();
        
        if (status.isGranted) {
          _loggerService.info('Permission $permission granted on attempt $attempt');
          return true;
        } else if (status.isPermanentlyDenied) {
          _loggerService.warning('Permission $permission permanently denied');
          return false;
        } else if (status.isDenied && attempt < maxRetries) {
          _loggerService.info('Permission $permission denied, retrying in ${retryDelay.inSeconds}s (attempt $attempt/$maxRetries)');
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        _loggerService.error('Failed to request permission $permission on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }
    
    return false;
  }
  
  /// Get permission status with detailed information
  Future<PermissionStatusInfo> getPermissionStatusInfo(Permission permission) async {
    try {
      final status = await permission.status;
      final isGranted = status.isGranted;
      final isDenied = status.isDenied;
      final isPermanentlyDenied = status.isPermanentlyDenied;
      final isRestricted = status.isRestricted;
      
      return PermissionStatusInfo(
        permission: permission,
        status: status,
        isGranted: isGranted,
        isDenied: isDenied,
        isPermanentlyDenied: isPermanentlyDenied,
        isRestricted: isRestricted,
        canRequest: !isPermanentlyDenied && !isRestricted,
      );
    } catch (e) {
      _loggerService.error('Failed to get permission status info for $permission: $e');
      return PermissionStatusInfo(
        permission: permission,
        status: PermissionStatus.denied,
        isGranted: false,
        isDenied: true,
        isPermanentlyDenied: false,
        isRestricted: false,
        canRequest: false,
      );
    }
  }
  
  /// Open app settings for permission management
  Future<bool> openSystemAppSettings() async {
    try {
      // Calls the permission_handler global function to open system app settings
      final opened = await openAppSettings();
      if (opened) {
        _loggerService.info('Opened app settings for permission management');
      } else {
        _loggerService.warning('Failed to open app settings');
      }
      return opened;
    } catch (e) {
      _loggerService.error('Failed to open app settings: $e');
      return false;
    }
  }
  
  /// Clear permission cache
  void clearCache() {
    _permissionCache.clear();
    _lastChecked.clear();
    _loggerService.info('Permission cache cleared');
  }
  
  /// Log permission statuses for debugging
  void _logPermissionStatuses(Map<Permission, PermissionStatus> statuses) {
    for (final entry in statuses.entries) {
      final permission = entry.key;
      final status = entry.value;
      _loggerService.info('Permission $permission: ${status.toString()}');
    }
  }
}

/// Permission status information
class PermissionStatusInfo {
  final Permission permission;
  final PermissionStatus status;
  final bool isGranted;
  final bool isDenied;
  final bool isPermanentlyDenied;
  final bool isRestricted;
  final bool canRequest;
  
  const PermissionStatusInfo({
    required this.permission,
    required this.status,
    required this.isGranted,
    required this.isDenied,
    required this.isPermanentlyDenied,
    required this.isRestricted,
    required this.canRequest,
  });
}
