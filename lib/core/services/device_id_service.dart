import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:injectable/injectable.dart';

/// Service for managing device identification and unique device IDs
@injectable
class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get the unique device ID for this device
  /// Generates a new UUID if none exists and stores it securely
  Future<String> getDeviceId() async {
    try {
      String? deviceId = await _secureStorage.read(key: _deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        // Generate new device ID
        deviceId = _generateDeviceId();
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
      }

      return deviceId;
    } catch (e) {
      // Fallback to a random ID if secure storage fails
      return _generateDeviceId();
    }
  }

  /// Get a human-readable device name
  /// Combines device model with a short ID for uniqueness
  Future<String> getDeviceName() async {
    try {
      String? deviceName = await _secureStorage.read(key: _deviceNameKey);

      if (deviceName == null || deviceName.isEmpty) {
        // Generate device name based on platform
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceName = '${androidInfo.model} (${_getShortId()})';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceName = '${iosInfo.model} (${_getShortId()})';
        } else {
          deviceName = 'AirLink Device (${_getShortId()})';
        }

        await _secureStorage.write(key: _deviceNameKey, value: deviceName);
      }

      return deviceName;
    } catch (e) {
      // Fallback name
      return 'AirLink Device (${_getShortId()})';
    }
  }

  /// Get device capabilities for connection negotiation
  Future<Map<String, dynamic>> getDeviceCapabilities() async {
    try {
      final capabilities = <String, dynamic>{
        'maxChunkSize': 64 * 1024, // 64KB default
        'supportsResume': true,
        'encryption': 'AES-GCM',
        'compression': false,
        'platform': Platform.operatingSystem,
      };

      // Add platform-specific capabilities
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        capabilities.addAll({
          'androidVersion': androidInfo.version.release,
          'wifiAware': androidInfo.version.sdkInt >= 26,
          'ble': true,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        capabilities.addAll({
          'iosVersion': iosInfo.systemVersion,
          'multipeerConnectivity': true,
          'ble': true,
        });
      }

      return capabilities;
    } catch (e) {
      // Return basic capabilities if device info fails
      return {
        'maxChunkSize': 64 * 1024,
        'supportsResume': true,
        'encryption': 'AES-GCM',
        'platform': Platform.operatingSystem,
      };
    }
  }

  /// Generate a unique device ID
  String _generateDeviceId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List.generate(8, (_) => random.nextInt(256));

    // Create a UUID-like string
    final hex = randomBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${timestamp.toRadixString(16)}-${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16)}';
  }

  /// Get a short ID for display purposes
  String _getShortId() {
    final random = Random.secure();
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Clear stored device information (for testing or reset)
  Future<void> clearDeviceInfo() async {
    await _secureStorage.delete(key: _deviceIdKey);
    await _secureStorage.delete(key: _deviceNameKey);
  }

  /// Check if device ID exists
  Future<bool> hasDeviceId() async {
    final deviceId = await _secureStorage.read(key: _deviceIdKey);
    return deviceId != null && deviceId.isNotEmpty;
  }
}
