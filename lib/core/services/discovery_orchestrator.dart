import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/protocol/airlink_protocol_simplified.dart';

class DiscoveryOrchestrator {
  final MethodChannel methodChannel;
  final Stream<Map<String, dynamic>> eventStream;
  final LoggerService _logger = LoggerService();

  DiscoveryOrchestrator({
    required this.methodChannel,
    required this.eventStream,
    required AirLinkProtocolSimplified protocol,
  }) : _protocol = protocol;

  bool _isRunning = false;
  StreamSubscription<Map<String, dynamic>>? _eventSub;

  // TTL cache for discovered devices
  final Map<String, _CachedDevice> _deviceCache = <String, _CachedDevice>{};
  Timer? _ttlTimer;
  final AirLinkProtocolSimplified _protocol;

  // Backoff state
  int _attempt = 0;
  static const int _maxBackoffSeconds = 30;
  static const Duration _ttl = Duration(seconds: 30);

  Future<void> start({required Map<String, dynamic> metadata}) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final bool wifiAware = await _isWifiAwareSupported();
      final bool ble = await _isBleSupported();

      // Publish first (best effort)
      await _publish(metadata);

      // Choose preferred method: Wi‑Fi Aware > BLE
      if (wifiAware) {
        await _startUnifiedDiscovery();
      } else if (ble) {
        await _startUnifiedDiscovery();
      } else {
        _logger.warning('No discovery methods available');
      }

      // Listen to native events and maintain TTL cache
      _attachEventListener();

      // TTL sweeper using protocol events
      _protocol.eventStream.listen((event) {
        if (event.type == 'device_discovered' || event.type == 'device_updated') {
          _sweepTtl();
        }
      });
    } catch (e) {
      _logger.error('Discovery orchestrator failed to start', e);
      _scheduleRetry(metadata);
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    await _eventSub?.cancel();
    _ttlTimer?.cancel();
    _ttlTimer = null;
    _deviceCache.clear();
    try {
      await methodChannel.invokeMethod('stopDiscovery');
    } catch (_) {}
  }

  // Expose snapshot for consumers that want it (optional)
  List<Device> getCurrentDevices() {
    return _deviceCache.values
        .map((c) => c.device)
        .toList(growable: false);
  }

  void _attachEventListener() {
    _eventSub?.cancel();
    _eventSub = eventStream.listen((Map<String, dynamic> event) {
      final String? type = event['type'] as String?;
      if (type == 'discoveryUpdate') {
        final Map<String, dynamic> data = (event['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final String id = (data['deviceId'] as String?) ?? (data['peerId'] as String? ?? 'unknown');
        final String name = (data['deviceName'] as String?) ?? 'Unknown Device';
        final String? ipAddress = data['ipAddress'] as String?;
        final int? rssi = (data['rssi'] is int) ? data['rssi'] as int : null;
        final Map<String, dynamic> metadata = (data['metadata'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final String? deviceTypeStr = (data['deviceType'] as String?) ?? metadata['deviceType'] as String?;

        final Device device = Device(
          id: id,
          name: name,
          type: _parseDeviceType(deviceTypeStr),
          ipAddress: ipAddress,
          rssi: rssi,
          metadata: metadata,
          discoveredAt: DateTime.now(),
        );

        _deviceCache[id] = _CachedDevice(
          device: _mergeDevice(_deviceCache[id]?.device, device),
          expiresAt: DateTime.now().add(_ttl),
        );
      }
    });
  }

  Future<void> _publish(Map<String, dynamic> metadata) async {
    try {
      await methodChannel.invokeMethod('publishService', <String, dynamic>{'metadata': metadata});
    } catch (e) {
      _logger.warning('Publish failed: $e');
    }
  }

  Future<void> _startUnifiedDiscovery() async {
    try {
      await methodChannel.invokeMethod('startDiscovery');
      _attempt = 0; // reset backoff on success start
    } catch (e) {
      _logger.warning('startDiscovery failed: $e');
      rethrow;
    }
  }

  void _scheduleRetry(Map<String, dynamic> metadata) {
    if (!_isRunning) return;
    _attempt += 1;
    final int delay = min(_maxBackoffSeconds, 1 << (_attempt - 1));
    Timer(Duration(seconds: delay), () {
      if (_isRunning) {
        // ignore: unused_result
        start(metadata: metadata);
      }
    });
  }

  void _sweepTtl() {
    final DateTime now = DateTime.now();
    final List<String> toRemove = <String>[];
    _deviceCache.forEach((String id, _CachedDevice cached) {
      if (cached.expiresAt.isBefore(now)) {
        toRemove.add(id);
      }
    });
    for (final String id in toRemove) {
      _deviceCache.remove(id);
    }
  }

  Future<bool> _isWifiAwareSupported() async {
    try {
      final bool? result = await methodChannel.invokeMethod<bool>('isWifiAwareSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isBleSupported() async {
    try {
      final bool? result = await methodChannel.invokeMethod<bool>('isBleSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // Merge metrics (e.g., keep best RSSI)
  Device _mergeDevice(Device? oldDevice, Device newDevice) {
    if (oldDevice == null) return newDevice;
    final int? bestRssi = _maxInt(oldDevice.rssi, newDevice.rssi);
    return Device(
      id: newDevice.id,
      name: newDevice.name.isNotEmpty ? newDevice.name : oldDevice.name,
      type: newDevice.type != DeviceType.unknown ? newDevice.type : oldDevice.type,
      ipAddress: newDevice.ipAddress ?? oldDevice.ipAddress,
      rssi: bestRssi,
      metadata: <String, dynamic>{...oldDevice.metadata, ...newDevice.metadata},
      discoveredAt: newDevice.discoveredAt,
    );
  }

  int? _maxInt(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return max(a, b);
  }

  DeviceType _parseDeviceType(String? deviceType) {
    switch (deviceType?.toLowerCase()) {
      case 'android':
        return DeviceType.android;
      case 'ios':
        return DeviceType.ios;
      case 'desktop':
        return DeviceType.desktop;
      default:
        return DeviceType.unknown;
    }
  }
}

class _CachedDevice {
  final Device device;
  final DateTime expiresAt;
  const _CachedDevice({required this.device, required this.expiresAt});
}


