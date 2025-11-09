import 'dart:async';
import 'package:airlink/core/services/platform_detection_service.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:airlink/core/services/connection_service.dart';
import 'package:airlink/core/services/channel_factory.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:injectable/injectable.dart';

enum DiscoveryState {
  idle,
  initializing,
  discovering,
  advertising,
  connecting,
  connected,
  error,
}

@injectable
class DiscoveryStrategyService {
  final LoggerService _loggerService;
  final PlatformDetectionService _platformDetectionService;
  final ConnectionService _connectionService;
  
  PlatformCapabilities? _capabilities;
  DiscoveryState _currentState = DiscoveryState.idle;
  DiscoveryMethod? _activeDiscoveryMethod;
  final List<Device> _discoveredDevices = [];
  final List<Device> _connectedDevices = [];
  
  final StreamController<List<Device>> _devicesController = StreamController<List<Device>>.broadcast();
  final StreamController<DiscoveryState> _stateController = StreamController<DiscoveryState>.broadcast();
  
  StreamSubscription<dynamic>? _eventSubscription;
  
  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<DiscoveryState> get stateStream => _stateController.stream;
  List<Device> get discoveredDevices => List.from(_discoveredDevices);
  List<Device> get connectedDevices => List.from(_connectedDevices);
  DiscoveryState get currentState => _currentState;
  DiscoveryMethod? get activeDiscoveryMethod => _activeDiscoveryMethod;
  
  DiscoveryStrategyService({
    required LoggerService loggerService,
    required PlatformDetectionService platformDetectionService,
    required ConnectionService connectionService,
  }) : _loggerService = loggerService,
       _platformDetectionService = platformDetectionService,
       _connectionService = connectionService;
  
  Future<void> initialize() async {
    try {
      _loggerService.info('Initializing discovery strategy service...');
      _updateState(DiscoveryState.initializing);
      
      _capabilities = await _platformDetectionService.detectPlatformCapabilities();
      
      // Subscribe to discovery events
      _eventSubscription = ChannelFactory.createMultiplexedEventChannel('discovery').listen((event) {
        _handleDiscoveryEvent(event);
      });
      
      _loggerService.info('Discovery strategy initialized with capabilities: ${_capabilities!.supportedCapabilities}');
      _updateState(DiscoveryState.idle);
    } catch (e) {
      _loggerService.error('Failed to initialize discovery strategy: $e');
      _updateState(DiscoveryState.error);
      throw DiscoveryException(
        message: 'Failed to initialize discovery strategy: $e',
      );
    }
  }
  
  Future<void> startDiscovery() async {
    if (_currentState != DiscoveryState.idle) {
      _loggerService.warning('Discovery already active, stopping current discovery first');
      await stopDiscovery();
    }
    
    try {
      _loggerService.info('Starting discovery with fallback strategy...');
      _updateState(DiscoveryState.discovering);
      
      final availableMethods = _capabilities!.getAvailableDiscoveryMethods();
      _loggerService.info('Available discovery methods: $availableMethods');
      
      // Try each discovery method in priority order
      for (final method in availableMethods) {
        if (method == DiscoveryMethod.cloudRelay) continue; // Skip cloud relay for now
        
        try {
          _loggerService.info('Attempting discovery with method: $method');
          _activeDiscoveryMethod = method;
          
          final success = await _startDiscoveryMethod(method);
          if (success) {
            _loggerService.info('Successfully started discovery with method: $method');
            _updateState(DiscoveryState.discovering);
            return;
          }
        } catch (e) {
          _loggerService.warning('Failed to start discovery with method $method: $e');
          continue;
        }
      }
      
      // If all methods failed, try cloud relay as last resort
      _loggerService.warning('All discovery methods failed, trying cloud relay as last resort');
      try {
        _activeDiscoveryMethod = DiscoveryMethod.cloudRelay;
        await _startCloudRelayDiscovery();
        _updateState(DiscoveryState.discovering);
      } catch (e) {
        _loggerService.error('All discovery methods failed: $e');
        _updateState(DiscoveryState.error);
        throw DiscoveryException(
          message: 'All discovery methods failed: $e',
        );
      }
    } catch (e) {
      _loggerService.error('Failed to start discovery: $e');
      _updateState(DiscoveryState.error);
      throw DiscoveryException(
        message: 'Failed to start discovery: $e',
      );
    }
  }
  
  Future<void> stopDiscovery() async {
    try {
      _loggerService.info('Stopping discovery...');
      
      if (_activeDiscoveryMethod != null) {
        await _stopDiscoveryMethod(_activeDiscoveryMethod!);
        _activeDiscoveryMethod = null;
      }
      
      _discoveredDevices.clear();
      _devicesController.add(_discoveredDevices);
      _updateState(DiscoveryState.idle);
      
      _loggerService.info('Discovery stopped');
    } catch (e) {
      _loggerService.error('Failed to stop discovery: $e');
      _updateState(DiscoveryState.error);
      throw DiscoveryException(
        message: 'Failed to stop discovery: $e',
      );
    }
  }
  
  Future<void> startAdvertising() async {
    if (_currentState != DiscoveryState.idle) {
      _loggerService.warning('Advertising already active, stopping current advertising first');
      await stopAdvertising();
    }
    
    try {
      _loggerService.info('Starting advertising with fallback strategy...');
      _updateState(DiscoveryState.advertising);
      
      final availableMethods = _capabilities!.getAvailableDiscoveryMethods();
      
      // Try each advertising method in priority order
      for (final method in availableMethods) {
        if (method == DiscoveryMethod.cloudRelay) continue; // Skip cloud relay for now
        
        try {
          _loggerService.info('Attempting advertising with method: $method');
          _activeDiscoveryMethod = method;
          
          final success = await _startAdvertisingMethod(method);
          if (success) {
            _loggerService.info('Successfully started advertising with method: $method');
            _updateState(DiscoveryState.advertising);
            return;
          }
        } catch (e) {
          _loggerService.warning('Failed to start advertising with method $method: $e');
          continue;
        }
      }
      
      // If all methods failed, try cloud relay as last resort
      _loggerService.warning('All advertising methods failed, trying cloud relay as last resort');
      try {
        _activeDiscoveryMethod = DiscoveryMethod.cloudRelay;
        await _startCloudRelayAdvertising();
        _updateState(DiscoveryState.advertising);
      } catch (e) {
        _loggerService.error('All advertising methods failed: $e');
        _updateState(DiscoveryState.error);
        throw DiscoveryException(
          message: 'All advertising methods failed: $e',
        );
      }
    } catch (e) {
      _loggerService.error('Failed to start advertising: $e');
      _updateState(DiscoveryState.error);
      throw DiscoveryException(
        message: 'Failed to start advertising: $e',
      );
    }
  }
  
  Future<void> stopAdvertising() async {
    try {
      _loggerService.info('Stopping advertising...');
      
      if (_activeDiscoveryMethod != null) {
        await _stopAdvertisingMethod(_activeDiscoveryMethod!);
        _activeDiscoveryMethod = null;
      }
      
      _updateState(DiscoveryState.idle);
      _loggerService.info('Advertising stopped');
    } catch (e) {
      _loggerService.error('Failed to stop advertising: $e');
      _updateState(DiscoveryState.error);
      throw DiscoveryException(
        message: 'Failed to stop advertising: $e',
      );
    }
  }
  
  Future<bool> connectToDevice(Device device) async {
    try {
      _loggerService.info('Connecting to device: ${device.name}');
      _updateState(DiscoveryState.connecting);
      
      // Update device status
      final updatedDevice = device.copyWith(isConnected: false);
      _updateDevice(updatedDevice);
      
      // Attempt connection based on discovery method
      final success = await _attemptConnection(device);
      
      if (success) {
        final connectedDevice = device.copyWith(isConnected: true);
        _updateDevice(connectedDevice);
        _connectedDevices.add(connectedDevice);
        _updateState(DiscoveryState.connected);
        _loggerService.info('Successfully connected to device: ${device.name}');
        return true;
      } else {
        final errorDevice = device.copyWith(isConnected: false);
        _updateDevice(errorDevice);
        _updateState(DiscoveryState.error);
        _loggerService.warning('Failed to connect to device: ${device.name}');
        return false;
      }
    } catch (e) {
      _loggerService.error('Connection error: $e');
      final errorDevice = device.copyWith(isConnected: false);
      _updateDevice(errorDevice);
      _updateState(DiscoveryState.error);
      return false;
    }
  }
  
  Future<void> disconnectFromDevice(Device device) async {
    try {
      _loggerService.info('Disconnecting from device: ${device.name}');
      
      final disconnectedDevice = device.copyWith(isConnected: false);
      _updateDevice(disconnectedDevice);
      _connectedDevices.removeWhere((d) => d.id == device.id);
      
      if (_connectedDevices.isEmpty) {
        _updateState(DiscoveryState.discovering);
      }
    } catch (e) {
      _loggerService.error('Failed to disconnect from device: $e');
      throw DiscoveryException(
        message: 'Failed to disconnect from device: $e',
      );
    }
  }
  
  Future<bool> _startDiscoveryMethod(DiscoveryMethod method) async {
    switch (method) {
      case DiscoveryMethod.wifiAware:
        return await _startWifiAwareDiscovery();
      case DiscoveryMethod.ble:
        return await _startBLEDiscovery();
      case DiscoveryMethod.webrtc:
        return await _startWebRTCDiscovery();
      case DiscoveryMethod.hotspot:
        return await _startHotspotDiscovery();
      case DiscoveryMethod.cloudRelay:
        return await _startCloudRelayDiscovery();
    }
  }
  
  Future<bool> _stopDiscoveryMethod(DiscoveryMethod method) async {
    switch (method) {
      case DiscoveryMethod.wifiAware:
        return await _stopWifiAwareDiscovery();
      case DiscoveryMethod.ble:
        return await _stopBLEDiscovery();
      case DiscoveryMethod.webrtc:
        return await _stopWebRTCDiscovery();
      case DiscoveryMethod.hotspot:
        return await _stopHotspotDiscovery();
      case DiscoveryMethod.cloudRelay:
        return await _stopCloudRelayDiscovery();
    }
  }
  
  Future<bool> _startAdvertisingMethod(DiscoveryMethod method) async {
    switch (method) {
      case DiscoveryMethod.wifiAware:
        return await _startWifiAwareAdvertising();
      case DiscoveryMethod.ble:
        return await _startBLEAdvertising();
      case DiscoveryMethod.webrtc:
        return await _startWebRTCAdvertising();
      case DiscoveryMethod.hotspot:
        return await _startHotspotAdvertising();
      case DiscoveryMethod.cloudRelay:
        return await _startCloudRelayAdvertising();
    }
  }
  
  Future<bool> _stopAdvertisingMethod(DiscoveryMethod method) async {
    switch (method) {
      case DiscoveryMethod.wifiAware:
        return await _stopWifiAwareAdvertising();
      case DiscoveryMethod.ble:
        return await _stopBLEAdvertising();
      case DiscoveryMethod.webrtc:
        return await _stopWebRTCAdvertising();
      case DiscoveryMethod.hotspot:
        return await _stopHotspotAdvertising();
      case DiscoveryMethod.cloudRelay:
        return await _stopCloudRelayAdvertising();
    }
  }
  
  // Wi-Fi Aware methods
  Future<bool> _startWifiAwareDiscovery() async {
    if (!_capabilities!.hasCapability(PlatformCapability.wifiAware)) {
      return false;
    }
    
    try {
      await AirLinkPlugin.startWifiAwareDiscovery();
      _loggerService.info('Wi-Fi Aware discovery started');
      return true;
    } catch (e) {
      _loggerService.warning('Wi-Fi Aware discovery failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopWifiAwareDiscovery() async {
    try {
      await AirLinkPlugin.stopWifiAwareDiscovery();
      _loggerService.info('Wi-Fi Aware discovery stopped');
      return true;
    } catch (e) {
      _loggerService.warning('Wi-Fi Aware discovery stop failed: $e');
      return false;
    }
  }
  
  Future<bool> _startWifiAwareAdvertising() async {
    if (!_capabilities!.hasCapability(PlatformCapability.wifiAware)) {
      return false;
    }
    
    try {
      await AirLinkPlugin.startAdvertising();
      _loggerService.info('Wi-Fi Aware advertising started');
      return true;
    } catch (e) {
      _loggerService.warning('Wi-Fi Aware advertising failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopWifiAwareAdvertising() async {
    try {
      await AirLinkPlugin.stopAdvertising();
      _loggerService.info('Wi-Fi Aware advertising stopped');
      return true;
    } catch (e) {
      _loggerService.warning('Wi-Fi Aware advertising stop failed: $e');
      return false;
    }
  }
  
  // BLE methods
  Future<bool> _startBLEDiscovery() async {
    if (!_capabilities!.hasCapability(PlatformCapability.ble)) {
      return false;
    }
    
    try {
      await AirLinkPlugin.startBleDiscovery();
      _loggerService.info('BLE discovery started');
      return true;
    } catch (e) {
      _loggerService.warning('BLE discovery failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopBLEDiscovery() async {
    try {
      await AirLinkPlugin.stopBleDiscovery();
      _loggerService.info('BLE discovery stopped');
      return true;
    } catch (e) {
      _loggerService.warning('BLE discovery stop failed: $e');
      return false;
    }
  }
  
  Future<bool> _startBLEAdvertising() async {
    if (!_capabilities!.hasCapability(PlatformCapability.ble)) {
      return false;
    }
    
    try {
      await AirLinkPlugin.startAdvertising();
      _loggerService.info('BLE advertising started');
      return true;
    } catch (e) {
      _loggerService.warning('BLE advertising failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopBLEAdvertising() async {
    try {
      await AirLinkPlugin.stopAdvertising();
      _loggerService.info('BLE advertising stopped');
      return true;
    } catch (e) {
      _loggerService.warning('BLE advertising stop failed: $e');
      return false;
    }
  }
  
  // WebRTC methods
  Future<bool> _startWebRTCDiscovery() async {
    if (!_capabilities!.hasCapability(PlatformCapability.webrtc)) {
      return false;
    }
    
    try {
      // TODO: Implement WebRTC discovery
      _loggerService.info('WebRTC discovery started');
      return true;
    } catch (e) {
      _loggerService.warning('WebRTC discovery failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopWebRTCDiscovery() async {
    try {
      // TODO: Implement WebRTC discovery stop
      _loggerService.info('WebRTC discovery stopped');
      return true;
    } catch (e) {
      _loggerService.warning('WebRTC discovery stop failed: $e');
      return false;
    }
  }
  
  Future<bool> _startWebRTCAdvertising() async {
    if (!_capabilities!.hasCapability(PlatformCapability.webrtc)) {
      return false;
    }
    
    try {
      // TODO: Implement WebRTC advertising
      _loggerService.info('WebRTC advertising started');
      return true;
    } catch (e) {
      _loggerService.warning('WebRTC advertising failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopWebRTCAdvertising() async {
    try {
      // TODO: Implement WebRTC advertising stop
      _loggerService.info('WebRTC advertising stopped');
      return true;
    } catch (e) {
      _loggerService.warning('WebRTC advertising stop failed: $e');
      return false;
    }
  }
  
  // Hotspot methods
  Future<bool> _startHotspotDiscovery() async {
    if (!_capabilities!.hasCapability(PlatformCapability.hotspot)) {
      return false;
    }
    
    try {
      // TODO: Implement hotspot discovery
      _loggerService.info('Hotspot discovery started');
      return true;
    } catch (e) {
      _loggerService.warning('Hotspot discovery failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopHotspotDiscovery() async {
    try {
      // TODO: Implement hotspot discovery stop
      _loggerService.info('Hotspot discovery stopped');
      return true;
    } catch (e) {
      _loggerService.warning('Hotspot discovery stop failed: $e');
      return false;
    }
  }
  
  Future<bool> _startHotspotAdvertising() async {
    if (!_capabilities!.hasCapability(PlatformCapability.hotspot)) {
      return false;
    }
    
    try {
      // TODO: Implement hotspot advertising
      _loggerService.info('Hotspot advertising started');
      return true;
    } catch (e) {
      _loggerService.warning('Hotspot advertising failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopHotspotAdvertising() async {
    try {
      // TODO: Implement hotspot advertising stop
      _loggerService.info('Hotspot advertising stopped');
      return true;
    } catch (e) {
      _loggerService.warning('Hotspot advertising stop failed: $e');
      return false;
    }
  }
  
  // Cloud relay methods
  Future<bool> _startCloudRelayDiscovery() async {
    try {
      // TODO: Implement cloud relay discovery
      _loggerService.info('Cloud relay discovery started');
      return true;
    } catch (e) {
      _loggerService.warning('Cloud relay discovery failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopCloudRelayDiscovery() async {
    try {
      // TODO: Implement cloud relay discovery stop
      _loggerService.info('Cloud relay discovery stopped');
      return true;
    } catch (e) {
      _loggerService.warning('Cloud relay discovery stop failed: $e');
      return false;
    }
  }
  
  Future<bool> _startCloudRelayAdvertising() async {
    try {
      // TODO: Implement cloud relay advertising
      _loggerService.info('Cloud relay advertising started');
      return true;
    } catch (e) {
      _loggerService.warning('Cloud relay advertising failed: $e');
      return false;
    }
  }
  
  Future<bool> _stopCloudRelayAdvertising() async {
    try {
      // TODO: Implement cloud relay advertising stop
      _loggerService.info('Cloud relay advertising stopped');
      return true;
    } catch (e) {
      _loggerService.warning('Cloud relay advertising stop failed: $e');
      return false;
    }
  }
  
  Future<bool> _attemptConnection(Device device) async {
    try {
      _loggerService.info('Attempting connection to device: ${device.name}');
      
      // Get connection method from device metadata
      final connectionMethod = device.metadata['connectionMethod'] as String? ?? 'unknown';
      if ((device.metadata['invalid'] as bool?) == true) {
        _loggerService.warning('Aborting connection due to invalid discovery payload for device: ${device.name}');
        // Emit UI event via devices stream by updating device state
        final invalidDevice = device.copyWith(metadata: {
          ...device.metadata,
          'invalid': true,
          'invalidReason': 'Invalid discovery payload',
        });
        _updateDevice(invalidDevice);
        return false;
      }
      final peerId = device.metadata['peerId'] as String?;
      final deviceAddress = device.metadata['deviceAddress'] as String?;
      
      switch (connectionMethod) {
        case 'wifi_aware':
          return await _connectViaWifiAware(device, peerId);
        case 'ble':
          return await _connectViaBLE(device, deviceAddress);
        case 'multipeer':
          return await _connectViaMultipeer(device, peerId);
        default:
          _loggerService.warning('Unknown connection method: $connectionMethod');
          return false;
      }
    } catch (e) {
      _loggerService.error('Connection attempt failed: $e');
      return false;
    }
  }
  
  Future<bool> _connectViaWifiAware(Device device, String? peerId) async {
    try {
      if (peerId == null) {
        _loggerService.error('No peerId provided for Wi-Fi Aware connection');
        return false;
      }
      
      // Create datapath using peerId
      await AirLinkPlugin.createDatapath(peerId);
      
      // Wait for connection ready event with timeout
      final connectionReady = await _waitForConnectionReady(device.id, const Duration(seconds: 30));
      if (!connectionReady) {
        _loggerService.error('Connection ready timeout for Wi-Fi Aware');
        return false;
      }
      
      _loggerService.info('Wi-Fi Aware connection established');
      return true;
    } catch (e) {
      _loggerService.error('Wi-Fi Aware connection failed: $e');
      return false;
    }
  }
  
  Future<bool> _connectViaBLE(Device device, String? deviceAddress) async {
    try {
      if (deviceAddress == null) {
        _loggerService.error('No device address provided for BLE connection');
        return false;
      }
      
      // Connect to BLE device using address
      final connectionToken = await AirLinkPlugin.connectToDevice(deviceAddress);
      // Persist token early to avoid loss if event is missed
      await _connectionService.storeConnectionInfo(
        device.id,
        DeviceConnectionInfo(
          host: '',
          port: 0,
          connectionMethod: 'ble',
          isConnected: true,
          lastConnected: DateTime.now(),
          metadata: {'deviceAddress': deviceAddress},
          connectionToken: connectionToken,
          peerId: null,
        ),
      );
      
      // Wait for connection ready event with timeout
      final connectionReady = await _waitForConnectionReady(device.id, const Duration(seconds: 30));
      if (!connectionReady) {
        _loggerService.error('Connection ready timeout for BLE');
        return false;
      }
      
      _loggerService.info('BLE connection established');
      return true;
    } catch (e) {
      _loggerService.error('BLE connection failed: $e');
      return false;
    }
  }
  
  Future<bool> _connectViaMultipeer(Device device, String? peerId) async {
    try {
      if (peerId == null) {
        _loggerService.error('No peerId provided for Multipeer connection');
        return false;
      }
      
      // Connect to peer via MultipeerConnectivity
      await AirLinkPlugin.connectToPeer(peerId);
      
      // Wait for connection ready event with timeout
      final connectionReady = await _waitForConnectionReady(device.id, const Duration(seconds: 30));
      if (!connectionReady) {
        _loggerService.error('Connection ready timeout for Multipeer');
        return false;
      }
      
      _loggerService.info('Multipeer connection established');
      return true;
    } catch (e) {
      _loggerService.error('Multipeer connection failed: $e');
      return false;
    }
  }
  
  Future<bool> _waitForConnectionReady(String deviceId, Duration timeout) async {
    try {
      final completer = Completer<bool>();
      Timer? timeoutTimer;
      
      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      // Listen for connection ready events
      late StreamSubscription subscription;
      subscription = ChannelFactory.createMultiplexedEventChannel('discovery').listen((event) {
        if (event is Map<String, dynamic>) {
          final eventType = event['type'] as String?;
          final eventData = event['data'] as Map<String, dynamic>?;
          
          if (eventType == 'connectionReady' && eventData != null) {
            final eventDeviceId = eventData['deviceId'] as String?;
            
            if (eventDeviceId == deviceId) {
              if (!completer.isCompleted) {
                timeoutTimer?.cancel();
                subscription.cancel();
                completer.complete(true);
              }
            }
          } else if (eventType == 'discoveryUpdate' && eventData != null) {
            final eventDeviceId = eventData['deviceId'] as String?;
            final status = eventData['status'] as String?;
            
            if (eventDeviceId == deviceId && status == 'ready') {
              if (!completer.isCompleted) {
                timeoutTimer?.cancel();
                subscription.cancel();
                completer.complete(true);
              }
            }
          }
        }
      });
      
      return await completer.future;
    } catch (e) {
      _loggerService.error('Error waiting for connection ready: $e');
      return false;
    }
  }
  
  void _updateDevice(Device device) {
    final index = _discoveredDevices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      _discoveredDevices[index] = device;
    } else {
      _discoveredDevices.add(device);
      // Store connection info for newly discovered device
      _storeConnectionInfo(device);
    }
    _devicesController.add(_discoveredDevices);
  }
  
  /// Store connection information for a discovered device
  Future<void> _storeConnectionInfo(Device device) async {
    try {
      // Determine connection method based on active discovery method
      String connectionMethod = 'unknown';
      if (_activeDiscoveryMethod == DiscoveryMethod.wifiAware) {
        connectionMethod = 'wifi_aware';
      } else if (_activeDiscoveryMethod == DiscoveryMethod.ble) {
        connectionMethod = 'ble';
      } else if (_activeDiscoveryMethod == DiscoveryMethod.webrtc) {
        connectionMethod = 'webrtc';
      } else if (_activeDiscoveryMethod == DiscoveryMethod.hotspot) {
        connectionMethod = 'hotspot';
      } else if (_activeDiscoveryMethod == DiscoveryMethod.cloudRelay) {
        connectionMethod = 'cloud_relay';
      }
      
      // Extract host and port from metadata only if present (no defaults)
      String? host = device.metadata['host'] as String?;
      int? port = device.metadata['port'] as int?;
      
      // For BLE/Multipeer, store connection token or peer ID
      String? connectionToken;
      if (device.metadata.containsKey('connectionToken')) {
        connectionToken = device.metadata['connectionToken'] as String?;
      } else if (device.metadata.containsKey('peerId')) {
        connectionToken = device.metadata['peerId'] as String?;
      }
      
      // Validate minimal payload based on method
      bool isInvalid = false;
      if (connectionMethod == 'wifi_aware') {
        final bool hostValid = (host != null && host.isNotEmpty) || (device.metadata['connectionToken'] != null);
        final bool portValid = (port != null && port > 0) || (device.metadata['connectionToken'] != null);
        if (!hostValid || !portValid) {
          _loggerService.warning('Invalid Wi‑Fi Aware connection payload for device ${device.name}');
          isInvalid = true;
        }
      } else if (connectionMethod == 'ble') {
        final bool tokenValid = device.metadata['connectionToken'] is String && (device.metadata['connectionToken'] as String).isNotEmpty;
        final bool addrValid = device.metadata['deviceAddress'] is String && (device.metadata['deviceAddress'] as String).isNotEmpty;
        if (!tokenValid && !addrValid) {
          _loggerService.warning('Invalid BLE connection payload for device ${device.name}');
          isInvalid = true;
        }
      }

      // Create connection info with transport-specific endpoints
      final connectionInfo = DeviceConnectionInfo(
        host: host ?? '',
        port: port ?? 0,
        connectionMethod: connectionMethod,
        isConnected: device.isConnected,
        lastConnected: device.isConnected ? DateTime.now() : null,
        metadata: {
          ...device.metadata,
          if (isInvalid) 'invalid': true,
        },
        connectionToken: connectionToken,
        peerId: device.metadata['peerId'] as String?,
      );
      
      // Store in ConnectionService
      await _connectionService.storeConnectionInfo(device.id, connectionInfo);
      
      if (isInvalid) {
        _loggerService.warning('Stored INVALID connection info for device ${device.name}: $host:$port ($connectionMethod)');
      } else {
        _loggerService.info('Stored connection info for device ${device.name}: $host:$port ($connectionMethod)');
      }
    } catch (e) {
      _loggerService.error('Failed to store connection info for device ${device.name}: $e');
    }
  }
  
  /// Handle discovery events from platform channels
  void _handleDiscoveryEvent(dynamic event) {
    try {
      if (event is Map<String, dynamic>) {
        final eventType = event['type'] as String?;
        final eventData = event['data'] as Map<String, dynamic>?;
        
        if (eventType == 'discoveryUpdate' && eventData != null) {
          _handleDiscoveryUpdate(eventData);
        } else if (eventType == 'connectionReady' && eventData != null) {
          handleConnectionReadyEvent(eventData);
        } else if (eventType == 'connectionEstablished' && eventData != null) {
          final String? deviceId = eventData['deviceId'] as String?;
          final String? connectionToken = eventData['connectionToken'] as String?;
          final String? method = (eventData['connectionMethod'] as String?) ?? (eventData['method'] as String?);
          if (deviceId != null && connectionToken != null) {
            final connectionInfo = DeviceConnectionInfo(
              host: '',
              port: 0,
              connectionMethod: method ?? 'unknown',
              isConnected: true,
              lastConnected: DateTime.now(),
              metadata: eventData,
              connectionToken: connectionToken,
              peerId: eventData['peerId'] as String?,
            );
            _connectionService.storeConnectionInfo(deviceId, connectionInfo);
          }
        } else if (eventType == 'connectionLost' && eventData != null) {
          final String? deviceId = eventData['deviceId'] as String?;
          if (deviceId != null) {
            final matches = _connectedDevices.where((d) => d.id == deviceId).toList();
            if (matches.isNotEmpty) {
              final updatedDevice = matches.first.copyWith(isConnected: false);
              _updateDevice(updatedDevice);
            }
          }
        }
      }
    } catch (e) {
      _loggerService.error('Failed to handle discovery event: $e');
    }
  }
  
  /// Handle discovery update events
  void _handleDiscoveryUpdate(Map<String, dynamic> eventData) {
    try {
      if (!_validateEventPayload(eventData, const ['deviceId', 'deviceName'])) {
        _loggerService.warning('Received discovery event with missing deviceId or deviceName');
        return;
      }
      final String deviceId = (eventData['deviceId'] as String).trim();
      final String deviceName = (eventData['deviceName'] as String).trim();
      final String? connectionMethod = eventData['connectionMethod'] as String?;
      final String? peerId = eventData['peerId'] as String?;
      final String? deviceAddress = eventData['deviceAddress'] as String?;
      final int? rssi = eventData['rssi'] as int?;
      final String? host = eventData['host'] as String?;
      final int? port = eventData['port'] as int?;
      final String? connectionToken = eventData['connectionToken'] as String?;
      
      if (deviceId.isNotEmpty && deviceName.isNotEmpty) {
        // Handle device discovery
        final device = Device(
          id: deviceId,
          name: deviceName,
          type: DeviceType.unknown,
          discoveredAt: DateTime.now(),
          isConnected: false,
          metadata: {
            'connectionMethod': connectionMethod ?? 'unknown',
            'lastSeen': DateTime.now().toIso8601String(),
            'peerId': peerId,
            'deviceAddress': deviceAddress,
            'rssi': rssi,
            'host': host,
            'port': port,
            'connectionToken': connectionToken,
            'capabilities': eventData['capabilities'] ?? [],
          },
        );
        
        // Add or update device in discovered devices
        final existingIndex = _discoveredDevices.indexWhere((d) => d.id == deviceId);
        if (existingIndex >= 0) {
          _discoveredDevices[existingIndex] = device;
        } else {
          _discoveredDevices.add(device);
        }
        
        _devicesController.add(List.from(_discoveredDevices));
        _loggerService.info('Device discovered: $deviceName ($deviceId) via $connectionMethod');
      }
    } catch (e) {
      _loggerService.error('Failed to handle discovery update: $e');
    }
  }
  
  /// Handle connection-ready events from platform channels
  Future<void> handleConnectionReadyEvent(Map<String, dynamic> eventData) async {
    try {
      if (!_validateEventPayload(eventData, const ['deviceId'])) {
        _loggerService.warning('Connection ready event missing deviceId');
        return;
      }
      final String deviceId = (eventData['deviceId'] as String).trim();
      final String? connectionToken = eventData['connectionToken'] as String?;
      final String? host = eventData['host'] as String?;
      final int? port = eventData['port'] as int?;
      final String? connectionMethod = eventData['connectionMethod'] as String?;
      
      if ((connectionMethod == 'ble' || connectionMethod == 'wifi_aware') && (connectionToken == null || connectionToken.isEmpty)) {
        _loggerService.warning('Connection ready event missing required fields for method: $connectionMethod');
      }
      // Merge with existing device entry metadata if present
      Map<String, dynamic> mergedMeta = Map<String, dynamic>.from(eventData);
      final existingIndex = _discoveredDevices.indexWhere((d) => d.id == deviceId);
      if (existingIndex >= 0) {
        final existing = _discoveredDevices[existingIndex];
        mergedMeta = {
          ...existing.metadata,
          ...mergedMeta,
        };
        // Update device entry and re-emit
        final updatedDevice = existing.copyWith(
          isConnected: true,
          metadata: mergedMeta,
        );
        _discoveredDevices[existingIndex] = updatedDevice;
        _devicesController.add(List.from(_discoveredDevices));
      }

      // Update connection info with real host/port or connectionToken
      final connectionInfo = DeviceConnectionInfo(
        host: host ?? (mergedMeta['host'] as String? ?? ''),
        port: port ?? (mergedMeta['port'] as int? ?? 0),
        connectionMethod: connectionMethod ?? (mergedMeta['connectionMethod'] as String? ?? 'unknown'),
        isConnected: true,
        lastConnected: DateTime.now(),
        metadata: mergedMeta,
        connectionToken: connectionToken ?? mergedMeta['connectionToken'] as String?,
        peerId: mergedMeta['peerId'] as String?,
      );
      
      await _connectionService.storeConnectionInfo(deviceId, connectionInfo);
      
      _loggerService.info('Updated connection info for device $deviceId: ${host ?? 'localhost'}:${port ?? 8080} ($connectionMethod)');
    } catch (e) {
      _loggerService.error('Failed to handle connection ready event: $e');
    }
  }

  /// Validate event payload for required non-empty fields
  bool _validateEventPayload(Map<String, dynamic> eventData, List<String> requiredFields) {
    for (final String field in requiredFields) {
      final dynamic value = eventData[field];
      if (value == null) return false;
      if (value is String && value.trim().isEmpty) return false;
    }
    return true;
  }
  
  void _updateState(DiscoveryState state) {
    _currentState = state;
    _stateController.add(state);
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _devicesController.close();
    _stateController.close();
  }
}
