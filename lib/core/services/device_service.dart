import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airlink/core/services/logger_service.dart';

/// Service for managing device identification and metadata
@injectable
class DeviceService {
  final LoggerService _loggerService;
  final Uuid _uuid = const Uuid();

  static const String _deviceIdKey = 'airlink_device_id';
  static const String _deviceNameKey = 'airlink_device_name';

  DeviceService({required LoggerService loggerService})
    : _loggerService = loggerService;

  /// Get the current device ID, creating one if it doesn't exist
  Future<String> getCurrentDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _uuid.v4();
        await prefs.setString(_deviceIdKey, deviceId);
        _loggerService.info('Generated new device ID: $deviceId');
      } else {
        _loggerService.info('Retrieved existing device ID: $deviceId');
      }

      return deviceId;
    } catch (e) {
      _loggerService.error('Failed to get device ID', e);
      // Fallback to generating a new UUID
      final fallbackId = _uuid.v4();
      _loggerService.warning('Using fallback device ID: $fallbackId');
      return fallbackId;
    }
  }

  /// Get the current device name
  Future<String> getCurrentDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceName = prefs.getString(_deviceNameKey);

      if (deviceName == null || deviceName.isEmpty) {
        deviceName = 'AirLink Device';
        await prefs.setString(_deviceNameKey, deviceName);
        _loggerService.info('Set default device name: $deviceName');
      }

      return deviceName;
    } catch (e) {
      _loggerService.error('Failed to get device name', e);
      return 'AirLink Device';
    }
  }

  /// Set the device name
  Future<void> setDeviceName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceNameKey, name);
      _loggerService.info('Updated device name to: $name');
    } catch (e) {
      _loggerService.error('Failed to set device name', e);
    }
  }

  /// Get device metadata
  Future<Map<String, dynamic>> getDeviceMetadata() async {
    try {
      final deviceId = await getCurrentDeviceId();
      final deviceName = await getCurrentDeviceName();

      return {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': 'flutter',
        'version': '1.0.0', // TODO: Get from package info
        'capabilities': {
          'encryption': true,
          'wifi_direct': true,
          'bluetooth': true,
          'qr_connection': true,
        },
      };
    } catch (e) {
      _loggerService.error('Failed to get device metadata', e);
      return {
        'deviceId': _uuid.v4(),
        'deviceName': 'AirLink Device',
        'platform': 'flutter',
        'version': '1.0.0',
        'capabilities': {
          'encryption': true,
          'wifi_direct': true,
          'bluetooth': true,
          'qr_connection': true,
        },
      };
    }
  }
}
