import 'dart:async';
import 'package:flutter/services.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/shared/utils/format_utils.dart';
import 'package:injectable/injectable.dart';

/// Wi-Fi Direct service for high-speed peer-to-peer file transfers
/// Implements SHAREit/Zapya style Wi-Fi Direct functionality
@injectable
class WifiDirectService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<WifiDirectEvent> _eventController = StreamController<WifiDirectEvent>.broadcast();
  
  bool _isInitialized = false;
  bool _isDiscovering = false;
  bool _isConnected = false;
  String? _currentGroupOwner;
  String? _currentClient;
  
  WifiDirectService({
    required LoggerService logger,
    @Named('wifiDirect') required MethodChannel methodChannel,
    @Named('wifiDirectEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize Wi-Fi Direct service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.info('Initializing Wi-Fi Direct service...');
      
      // Check if Wi-Fi Direct is supported
      final bool isSupported = await _methodChannel.invokeMethod('isWifiDirectSupported');
      if (!isSupported) {
        throw WifiDirectException('Wi-Fi Direct is not supported on this device');
      }
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Wi-Fi Direct event error: $error'),
      );
      
      _isInitialized = true;
      _logger.info('Wi-Fi Direct service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize Wi-Fi Direct service: $e');
      throw WifiDirectException('Failed to initialize Wi-Fi Direct: $e');
    }
  }
  
  /// Start Wi-Fi Direct discovery
  Future<void> startDiscovery() async {
    if (!_isInitialized) await initialize();
    if (_isDiscovering) return;
    
    try {
      _logger.info('Starting Wi-Fi Direct discovery...');
      await _methodChannel.invokeMethod('startDiscovery');
      _isDiscovering = true;
      _logger.info('Wi-Fi Direct discovery started');
    } catch (e) {
      _logger.error('Failed to start Wi-Fi Direct discovery: $e');
      throw WifiDirectException('Failed to start discovery: $e');
    }
  }
  
  /// Stop Wi-Fi Direct discovery
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    try {
      _logger.info('Stopping Wi-Fi Direct discovery...');
      await _methodChannel.invokeMethod('stopDiscovery');
      _isDiscovering = false;
      _logger.info('Wi-Fi Direct discovery stopped');
    } catch (e) {
      _logger.error('Failed to stop Wi-Fi Direct discovery: $e');
    }
  }
  
  /// Create Wi-Fi Direct group (become group owner)
  Future<String> createGroup({String? groupName}) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Creating Wi-Fi Direct group...');
      final String groupId = await _methodChannel.invokeMethod('createGroup', {
        'groupName': groupName ?? 'AirLink_${DateTime.now().millisecondsSinceEpoch}',
      });
      
      _currentGroupOwner = groupId;
      _logger.info('Wi-Fi Direct group created: $groupId');
      return groupId;
    } catch (e) {
      _logger.error('Failed to create Wi-Fi Direct group: $e');
      throw WifiDirectException('Failed to create group: $e');
    }
  }
  
  /// Connect to Wi-Fi Direct group
  Future<void> connectToGroup(String groupId) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Connecting to Wi-Fi Direct group: $groupId');
      await _methodChannel.invokeMethod('connectToGroup', {'groupId': groupId});
      _currentClient = groupId;
      _isConnected = true;
      _logger.info('Connected to Wi-Fi Direct group: $groupId');
    } catch (e) {
      _logger.error('Failed to connect to Wi-Fi Direct group: $e');
      throw WifiDirectException('Failed to connect to group: $e');
    }
  }
  
  /// Disconnect from current group
  Future<void> disconnect() async {
    try {
      _logger.info('Disconnecting from Wi-Fi Direct group...');
      await _methodChannel.invokeMethod('disconnect');
      _isConnected = false;
      _currentGroupOwner = null;
      _currentClient = null;
      _logger.info('Disconnected from Wi-Fi Direct group');
    } catch (e) {
      _logger.error('Failed to disconnect from Wi-Fi Direct group: $e');
    }
  }
  
  /// Send file over Wi-Fi Direct connection
  Future<void> sendFile({
    required String filePath,
    required String fileName,
    required int fileSize,
    required String targetDeviceId,
    Function(double progress)? onProgress,
  }) async {
    if (!_isConnected) {
      throw WifiDirectException('Not connected to Wi-Fi Direct group');
    }
    
    try {
      _logger.info('Sending file: $fileName (${FormatUtils.formatBytes(fileSize)})');
      
      final String transferId = await _methodChannel.invokeMethod('sendFile', {
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'targetDeviceId': targetDeviceId,
      });
      
      // Monitor transfer progress
      _monitorTransferProgress(transferId, onProgress);
      
      _logger.info('File transfer initiated: $transferId');
    } catch (e) {
      _logger.error('Failed to send file: $e');
      throw WifiDirectException('Failed to send file: $e');
    }
  }
  
  /// Receive file from Wi-Fi Direct connection
  Future<String> receiveFile({
    required String savePath,
    required String fileName,
  }) async {
    if (!_isConnected) {
      throw WifiDirectException('Not connected to Wi-Fi Direct group');
    }
    
    try {
      _logger.info('Receiving file: $fileName');
      
      final String receivedPath = await _methodChannel.invokeMethod('receiveFile', {
        'savePath': savePath,
        'fileName': fileName,
      });
      
      _logger.info('File received: $receivedPath');
      return receivedPath;
    } catch (e) {
      _logger.error('Failed to receive file: $e');
      throw WifiDirectException('Failed to receive file: $e');
    }
  }
  
  /// Get discovered devices
  Future<List<WifiDirectDevice>> getDiscoveredDevices() async {
    try {
      final List<dynamic> devices = await _methodChannel.invokeMethod('getDiscoveredDevices');
      return devices.map((device) => WifiDirectDevice.fromMap(device)).toList();
    } catch (e) {
      _logger.error('Failed to get discovered devices: $e');
      return [];
    }
  }
  
  /// Get current connection status
  WifiDirectStatus getStatus() {
    return WifiDirectStatus(
      isInitialized: _isInitialized,
      isDiscovering: _isDiscovering,
      isConnected: _isConnected,
      groupOwner: _currentGroupOwner,
      client: _currentClient,
    );
  }
  
  /// Stream of Wi-Fi Direct events
  Stream<WifiDirectEvent> get eventStream => _eventController.stream;
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'deviceFound':
          _eventController.add(DeviceFoundEvent.fromMap(eventData));
          break;
        case 'deviceLost':
          _eventController.add(DeviceLostEvent.fromMap(eventData));
          break;
        case 'groupCreated':
          _eventController.add(GroupCreatedEvent.fromMap(eventData));
          break;
        case 'groupJoined':
          _eventController.add(GroupJoinedEvent.fromMap(eventData));
          break;
        case 'groupLeft':
          _eventController.add(GroupLeftEvent.fromMap(eventData));
          break;
        case 'transferProgress':
          _eventController.add(TransferProgressEvent.fromMap(eventData));
          break;
        case 'transferComplete':
          _eventController.add(TransferCompleteEvent.fromMap(eventData));
          break;
        case 'transferFailed':
          _eventController.add(TransferFailedEvent.fromMap(eventData));
          break;
        default:
          _logger.warning('Unknown Wi-Fi Direct event type: $eventType');
      }
    } catch (e) {
      _logger.error('Failed to handle Wi-Fi Direct event: $e');
    }
  }
  
  void _monitorTransferProgress(String transferId, Function(double progress)? onProgress) {
    // This would typically be handled by the native implementation
    // For now, we'll simulate progress updates
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Simulate progress - in real implementation, this would come from native
      if (onProgress != null) {
        onProgress(0.5); // 50% progress
      }
      
      // Stop after some time (simulation)
      if (timer.tick > 50) {
        timer.cancel();
      }
    });
  }
  
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Wi-Fi Direct device model
class WifiDirectDevice {
  final String deviceId;
  final String deviceName;
  final String deviceAddress;
  final int signalStrength;
  final bool isGroupOwner;
  final Map<String, dynamic> capabilities;
  
  const WifiDirectDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceAddress,
    required this.signalStrength,
    required this.isGroupOwner,
    required this.capabilities,
  });
  
  factory WifiDirectDevice.fromMap(Map<String, dynamic> map) {
    return WifiDirectDevice(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      deviceAddress: map['deviceAddress'] as String,
      signalStrength: map['signalStrength'] as int,
      isGroupOwner: map['isGroupOwner'] as bool,
      capabilities: Map<String, dynamic>.from(map['capabilities'] as Map),
    );
  }
}

/// Wi-Fi Direct status model
class WifiDirectStatus {
  final bool isInitialized;
  final bool isDiscovering;
  final bool isConnected;
  final String? groupOwner;
  final String? client;
  
  const WifiDirectStatus({
    required this.isInitialized,
    required this.isDiscovering,
    required this.isConnected,
    this.groupOwner,
    this.client,
  });
}

/// Wi-Fi Direct event base class
abstract class WifiDirectEvent {
  final String type;
  final DateTime timestamp;
  
  const WifiDirectEvent({
    required this.type,
    required this.timestamp,
  });
}

class DeviceFoundEvent extends WifiDirectEvent {
  final WifiDirectDevice device;
  
  const DeviceFoundEvent({
    required this.device,
    required super.timestamp,
  }) : super(type: 'deviceFound');
  
  factory DeviceFoundEvent.fromMap(Map<String, dynamic> map) {
    return DeviceFoundEvent(
      device: WifiDirectDevice.fromMap(map['device'] as Map<String, dynamic>),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class DeviceLostEvent extends WifiDirectEvent {
  final String deviceId;
  
  const DeviceLostEvent({
    required this.deviceId,
    required super.timestamp,
  }) : super(type: 'deviceLost');
  
  factory DeviceLostEvent.fromMap(Map<String, dynamic> map) {
    return DeviceLostEvent(
      deviceId: map['deviceId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class GroupCreatedEvent extends WifiDirectEvent {
  final String groupId;
  final String groupName;
  
  const GroupCreatedEvent({
    required this.groupId,
    required this.groupName,
    required super.timestamp,
  }) : super(type: 'groupCreated');
  
  factory GroupCreatedEvent.fromMap(Map<String, dynamic> map) {
    return GroupCreatedEvent(
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class GroupJoinedEvent extends WifiDirectEvent {
  final String groupId;
  final String deviceId;
  
  const GroupJoinedEvent({
    required this.groupId,
    required this.deviceId,
    required super.timestamp,
  }) : super(type: 'groupJoined');
  
  factory GroupJoinedEvent.fromMap(Map<String, dynamic> map) {
    return GroupJoinedEvent(
      groupId: map['groupId'] as String,
      deviceId: map['deviceId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class GroupLeftEvent extends WifiDirectEvent {
  final String groupId;
  final String deviceId;
  
  const GroupLeftEvent({
    required this.groupId,
    required this.deviceId,
    required super.timestamp,
  }) : super(type: 'groupLeft');
  
  factory GroupLeftEvent.fromMap(Map<String, dynamic> map) {
    return GroupLeftEvent(
      groupId: map['groupId'] as String,
      deviceId: map['deviceId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class TransferProgressEvent extends WifiDirectEvent {
  final String transferId;
  final String fileName;
  final int bytesTransferred;
  final int totalBytes;
  final double speed;
  
  const TransferProgressEvent({
    required this.transferId,
    required this.fileName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speed,
    required super.timestamp,
  }) : super(type: 'transferProgress');
  
  factory TransferProgressEvent.fromMap(Map<String, dynamic> map) {
    return TransferProgressEvent(
      transferId: map['transferId'] as String,
      fileName: map['fileName'] as String,
      bytesTransferred: map['bytesTransferred'] as int,
      totalBytes: map['totalBytes'] as int,
      speed: (map['speed'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class TransferCompleteEvent extends WifiDirectEvent {
  final String transferId;
  final String fileName;
  final String filePath;
  
  const TransferCompleteEvent({
    required this.transferId,
    required this.fileName,
    required this.filePath,
    required super.timestamp,
  }) : super(type: 'transferComplete');
  
  factory TransferCompleteEvent.fromMap(Map<String, dynamic> map) {
    return TransferCompleteEvent(
      transferId: map['transferId'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class TransferFailedEvent extends WifiDirectEvent {
  final String transferId;
  final String fileName;
  final String error;
  
  const TransferFailedEvent({
    required this.transferId,
    required this.fileName,
    required this.error,
    required super.timestamp,
  }) : super(type: 'transferFailed');
  
  factory TransferFailedEvent.fromMap(Map<String, dynamic> map) {
    return TransferFailedEvent(
      transferId: map['transferId'] as String,
      fileName: map['fileName'] as String,
      error: map['error'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

/// Wi-Fi Direct specific exception
class WifiDirectException implements Exception {
  final String message;
  const WifiDirectException(this.message);
  
  @override
  String toString() => 'WifiDirectException: $message';
}
