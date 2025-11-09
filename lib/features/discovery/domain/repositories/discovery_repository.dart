import 'package:airlink/shared/models/app_state.dart';

abstract class DiscoveryRepository {
  /// Start discovering nearby devices
  Stream<List<Device>> startDiscovery();
  
  /// Stop device discovery
  Future<void> stopDiscovery();
  
  /// Start advertising this device for discovery
  Future<void> startAdvertising();
  
  /// Stop advertising this device
  Future<void> stopAdvertising();
  
  /// Connect to a specific device
  Future<bool> connectToDevice(Device device);
  
  /// Disconnect from a device
  Future<void> disconnectFromDevice(Device device);
  
  /// Get currently connected devices
  List<Device> getConnectedDevices();
  
  /// Check if discovery is currently active
  bool isDiscoveryActive();
  
  /// Check if advertising is currently active
  bool isAdvertisingActive();
}
