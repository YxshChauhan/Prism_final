import 'dart:async';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/permission_service.dart';
import 'package:airlink/core/services/discovery_strategy_service.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: DiscoveryRepository)
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final LoggerService _loggerService;
  final PermissionService _permissionService;
  final DiscoveryStrategyService _discoveryStrategyService;
  
  bool _isInitialized = false;
  
  DiscoveryRepositoryImpl({
    required LoggerService loggerService,
    required PermissionService permissionService,
    required DiscoveryStrategyService discoveryStrategyService,
  }) : _loggerService = loggerService,
       _permissionService = permissionService,
       _discoveryStrategyService = discoveryStrategyService;
  
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _discoveryStrategyService.initialize();
      _isInitialized = true;
    }
  }
  
  @override
  Stream<List<Device>> startDiscovery() async* {
    try {
      await _ensureInitialized();
      _loggerService.info('Starting device discovery with strategy service');
      
      // Check permissions
      final hasLocation = await _permissionService.hasLocationPermission();
      final hasBluetooth = await _permissionService.hasBluetoothPermission();
      
      if (!hasLocation || !hasBluetooth) {
        throw DiscoveryException(
          message: 'Required permissions not granted',
        );
      }
      
      // Start discovery using strategy service
      await _discoveryStrategyService.startDiscovery();
      
      // Yield discovered devices from strategy service
      await for (final devices in _discoveryStrategyService.devicesStream) {
        yield devices;
      }
    } catch (e) {
      _loggerService.error('Failed to start discovery: $e');
      throw DiscoveryException(
        message: 'Failed to start discovery: $e',
      );
    }
  }
  
  @override
  Future<void> stopDiscovery() async {
    try {
      await _ensureInitialized();
      _loggerService.info('Stopping device discovery');
      await _discoveryStrategyService.stopDiscovery();
    } catch (e) {
      _loggerService.error('Failed to stop discovery: $e');
      throw DiscoveryException(
        message: 'Failed to stop discovery: $e',
      );
    }
  }
  
  @override
  Future<void> startAdvertising() async {
    try {
      await _ensureInitialized();
      _loggerService.info('Starting device advertising');
      await _discoveryStrategyService.startAdvertising();
    } catch (e) {
      _loggerService.error('Failed to start advertising: $e');
      throw DiscoveryException(
        message: 'Failed to start advertising: $e',
      );
    }
  }
  
  @override
  Future<void> stopAdvertising() async {
    try {
      await _ensureInitialized();
      _loggerService.info('Stopping device advertising');
      await _discoveryStrategyService.stopAdvertising();
    } catch (e) {
      _loggerService.error('Failed to stop advertising: $e');
      throw DiscoveryException(
        message: 'Failed to stop advertising: $e',
      );
    }
  }
  
  @override
  Future<bool> connectToDevice(Device device) async {
    try {
      await _ensureInitialized();
      _loggerService.info('Connecting to device: ${device.name}');
      return await _discoveryStrategyService.connectToDevice(device);
    } catch (e) {
      _loggerService.error('Connection error: $e');
      return false;
    }
  }
  
  @override
  Future<void> disconnectFromDevice(Device device) async {
    try {
      await _ensureInitialized();
      _loggerService.info('Disconnecting from device: ${device.name}');
      await _discoveryStrategyService.disconnectFromDevice(device);
    } catch (e) {
      _loggerService.error('Failed to disconnect from device: $e');
      throw DiscoveryException(
        message: 'Failed to disconnect from device: $e',
      );
    }
  }
  
  @override
  List<Device> getConnectedDevices() {
    return _discoveryStrategyService.connectedDevices;
  }
  
  @override
  bool isDiscoveryActive() {
    return _discoveryStrategyService.currentState == DiscoveryState.discovering;
  }
  
  @override
  bool isAdvertisingActive() {
    return _discoveryStrategyService.currentState == DiscoveryState.advertising;
  }
  
  void dispose() {
    _discoveryStrategyService.dispose();
  }
}
