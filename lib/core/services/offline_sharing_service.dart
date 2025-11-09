import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';

/// Offline sharing service for creating local hotspots and Bluetooth sharing
/// Implements SHAREit/Zapya style offline file sharing
@injectable
class OfflineSharingService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<OfflineSharingEvent> _eventController = StreamController<OfflineSharingEvent>.broadcast();
  
  bool _isInitialized = false;
  bool _isHotspotActive = false;
  bool _isBluetoothActive = false;
  String? _currentHotspotName;
  String? _currentBluetoothName;
  
  OfflineSharingService({
    required LoggerService logger,
    @Named('offlineSharing') required MethodChannel methodChannel,
    @Named('offlineSharingEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize offline sharing service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.info('Initializing offline sharing service...');
      
      // Check platform capabilities
      final bool hotspotSupported = await _methodChannel.invokeMethod('isHotspotSupported');
      final bool bluetoothSupported = await _methodChannel.invokeMethod('isBluetoothSupported');
      
      if (!hotspotSupported && !bluetoothSupported) {
        throw OfflineSharingException('Neither hotspot nor Bluetooth is supported on this device');
      }
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Offline sharing event error: $error'),
      );
      
      _isInitialized = true;
      _logger.info('Offline sharing service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize offline sharing service: $e');
      throw OfflineSharingException('Failed to initialize offline sharing: $e');
    }
  }
  
  /// Create Wi-Fi hotspot for offline sharing
  Future<String> createHotspot({
    String? hotspotName,
    String? password,
    int maxConnections = 8,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isHotspotActive) {
      throw OfflineSharingException('Hotspot is already active');
    }
    
    try {
      _logger.info('Creating Wi-Fi hotspot for offline sharing...');
      
      final String name = hotspotName ?? 'AirLink_${DateTime.now().millisecondsSinceEpoch}';
      final String pass = password ?? _generateRandomPassword();
      
      final String hotspotId = await _methodChannel.invokeMethod('createHotspot', {
        'hotspotName': name,
        'password': pass,
        'maxConnections': maxConnections,
        'securityType': 'WPA2_PSK',
      });
      
      _currentHotspotName = name;
      _isHotspotActive = true;
      
      _logger.info('Wi-Fi hotspot created: $name');
      return hotspotId;
    } catch (e) {
      _logger.error('Failed to create Wi-Fi hotspot: $e');
      throw OfflineSharingException('Failed to create hotspot: $e');
    }
  }
  
  /// Stop Wi-Fi hotspot
  Future<void> stopHotspot() async {
    if (!_isHotspotActive) return;
    
    try {
      _logger.info('Stopping Wi-Fi hotspot...');
      await _methodChannel.invokeMethod('stopHotspot');
      _isHotspotActive = false;
      _currentHotspotName = null;
      _logger.info('Wi-Fi hotspot stopped');
    } catch (e) {
      _logger.error('Failed to stop Wi-Fi hotspot: $e');
    }
  }
  
  /// Connect to Wi-Fi hotspot
  Future<void> connectToHotspot({
    required String hotspotName,
    required String password,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Connecting to Wi-Fi hotspot: $hotspotName');
      await _methodChannel.invokeMethod('connectToHotspot', {
        'hotspotName': hotspotName,
        'password': password,
      });
      _logger.info('Connected to Wi-Fi hotspot: $hotspotName');
    } catch (e) {
      _logger.error('Failed to connect to Wi-Fi hotspot: $e');
      throw OfflineSharingException('Failed to connect to hotspot: $e');
    }
  }
  
  /// Start Bluetooth sharing
  Future<void> startBluetoothSharing({
    String? deviceName,
    bool discoverable = true,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isBluetoothActive) {
      throw OfflineSharingException('Bluetooth sharing is already active');
    }
    
    try {
      _logger.info('Starting Bluetooth sharing...');
      
      final String name = deviceName ?? 'AirLink_${DateTime.now().millisecondsSinceEpoch}';
      
      await _methodChannel.invokeMethod('startBluetoothSharing', {
        'deviceName': name,
        'discoverable': discoverable,
        'uuid': '00001101-0000-1000-8000-00805F9B34FB', // SPP UUID
      });
      
      _currentBluetoothName = name;
      _isBluetoothActive = true;
      
      _logger.info('Bluetooth sharing started: $name');
    } catch (e) {
      _logger.error('Failed to start Bluetooth sharing: $e');
      throw OfflineSharingException('Failed to start Bluetooth sharing: $e');
    }
  }
  
  /// Stop Bluetooth sharing
  Future<void> stopBluetoothSharing() async {
    if (!_isBluetoothActive) return;
    
    try {
      _logger.info('Stopping Bluetooth sharing...');
      await _methodChannel.invokeMethod('stopBluetoothSharing');
      _isBluetoothActive = false;
      _currentBluetoothName = null;
      _logger.info('Bluetooth sharing stopped');
    } catch (e) {
      _logger.error('Failed to stop Bluetooth sharing: $e');
    }
  }
  
  /// Scan for nearby hotspots
  Future<List<HotspotInfo>> scanHotspots() async {
    try {
      _logger.info('Scanning for nearby hotspots...');
      final List<dynamic> hotspots = await _methodChannel.invokeMethod('scanHotspots');
      return hotspots.map((hotspot) => HotspotInfo.fromMap(hotspot)).toList();
    } catch (e) {
      _logger.error('Failed to scan hotspots: $e');
      return [];
    }
  }
  
  /// Scan for Bluetooth devices
  Future<List<BluetoothDevice>> scanBluetoothDevices() async {
    try {
      _logger.info('Scanning for Bluetooth devices...');
      final List<dynamic> devices = await _methodChannel.invokeMethod('scanBluetoothDevices');
      return devices.map((device) => BluetoothDevice.fromMap(device)).toList();
    } catch (e) {
      _logger.error('Failed to scan Bluetooth devices: $e');
      return [];
    }
  }
  
  /// Send file via offline sharing
  Future<void> sendFileOffline({
    required String filePath,
    required String fileName,
    required int fileSize,
    required String targetDeviceId,
    required OfflineSharingMethod method,
    Function(double progress)? onProgress,
  }) async {
    try {
      _logger.info('Sending file via offline sharing: $fileName');
      
      final String transferId = await _methodChannel.invokeMethod('sendFileOffline', {
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'targetDeviceId': targetDeviceId,
        'method': method.toString().split('.').last,
      });
      
      // Monitor transfer progress
      _monitorOfflineTransferProgress(transferId, onProgress);
      
      _logger.info('Offline file transfer initiated: $transferId');
    } catch (e) {
      _logger.error('Failed to send file via offline sharing: $e');
      throw OfflineSharingException('Failed to send file: $e');
    }
  }
  
  /// Receive file via offline sharing
  Future<String> receiveFileOffline({
    required String savePath,
    required String fileName,
    required OfflineSharingMethod method,
  }) async {
    try {
      _logger.info('Receiving file via offline sharing: $fileName');
      
      final String receivedPath = await _methodChannel.invokeMethod('receiveFileOffline', {
        'savePath': savePath,
        'fileName': fileName,
        'method': method.toString().split('.').last,
      });
      
      _logger.info('File received via offline sharing: $receivedPath');
      return receivedPath;
    } catch (e) {
      _logger.error('Failed to receive file via offline sharing: $e');
      throw OfflineSharingException('Failed to receive file: $e');
    }
  }
  
  /// Get current sharing status
  OfflineSharingStatus getStatus() {
    return OfflineSharingStatus(
      isInitialized: _isInitialized,
      isHotspotActive: _isHotspotActive,
      isBluetoothActive: _isBluetoothActive,
      hotspotName: _currentHotspotName,
      bluetoothName: _currentBluetoothName,
    );
  }
  
  /// Stream of offline sharing events
  Stream<OfflineSharingEvent> get eventStream => _eventController.stream;
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'hotspotCreated':
          _eventController.add(HotspotCreatedEvent.fromMap(eventData));
          break;
        case 'hotspotStopped':
          _eventController.add(HotspotStoppedEvent.fromMap(eventData));
          break;
        case 'hotspotConnected':
          _eventController.add(HotspotConnectedEvent.fromMap(eventData));
          break;
        case 'hotspotDisconnected':
          _eventController.add(HotspotDisconnectedEvent.fromMap(eventData));
          break;
        case 'bluetoothStarted':
          _eventController.add(BluetoothStartedEvent.fromMap(eventData));
          break;
        case 'bluetoothStopped':
          _eventController.add(BluetoothStoppedEvent.fromMap(eventData));
          break;
        case 'bluetoothConnected':
          _eventController.add(BluetoothConnectedEvent.fromMap(eventData));
          break;
        case 'bluetoothDisconnected':
          _eventController.add(BluetoothDisconnectedEvent.fromMap(eventData));
          break;
        case 'offlineTransferProgress':
          _eventController.add(OfflineTransferProgressEvent.fromMap(eventData));
          break;
        case 'offlineTransferComplete':
          _eventController.add(OfflineTransferCompleteEvent.fromMap(eventData));
          break;
        case 'offlineTransferFailed':
          _eventController.add(OfflineTransferFailedEvent.fromMap(eventData));
          break;
        default:
          _logger.warning('Unknown offline sharing event type: $eventType');
      }
    } catch (e) {
      _logger.error('Failed to handle offline sharing event: $e');
    }
  }
  
  void _monitorOfflineTransferProgress(String transferId, Function(double progress)? onProgress) {
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
  
  String _generateRandomPassword() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Offline sharing methods
enum OfflineSharingMethod {
  hotspot,
  bluetooth,
  wifiDirect,
}

/// Hotspot information model
class HotspotInfo {
  final String ssid;
  final String bssid;
  final int signalStrength;
  final String securityType;
  final int frequency;
  final bool isConnected;
  
  const HotspotInfo({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
    required this.securityType,
    required this.frequency,
    required this.isConnected,
  });
  
  factory HotspotInfo.fromMap(Map<String, dynamic> map) {
    return HotspotInfo(
      ssid: map['ssid'] as String,
      bssid: map['bssid'] as String,
      signalStrength: map['signalStrength'] as int,
      securityType: map['securityType'] as String,
      frequency: map['frequency'] as int,
      isConnected: map['isConnected'] as bool,
    );
  }
}

/// Bluetooth device model
class BluetoothDevice {
  final String deviceId;
  final String deviceName;
  final String deviceAddress;
  final int signalStrength;
  final bool isConnected;
  final bool isPaired;
  
  const BluetoothDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceAddress,
    required this.signalStrength,
    required this.isConnected,
    required this.isPaired,
  });
  
  factory BluetoothDevice.fromMap(Map<String, dynamic> map) {
    return BluetoothDevice(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      deviceAddress: map['deviceAddress'] as String,
      signalStrength: map['signalStrength'] as int,
      isConnected: map['isConnected'] as bool,
      isPaired: map['isPaired'] as bool,
    );
  }
}

/// Offline sharing status model
class OfflineSharingStatus {
  final bool isInitialized;
  final bool isHotspotActive;
  final bool isBluetoothActive;
  final String? hotspotName;
  final String? bluetoothName;
  
  const OfflineSharingStatus({
    required this.isInitialized,
    required this.isHotspotActive,
    required this.isBluetoothActive,
    this.hotspotName,
    this.bluetoothName,
  });
}

/// Offline sharing event base class
abstract class OfflineSharingEvent {
  final String type;
  final DateTime timestamp;
  
  const OfflineSharingEvent({
    required this.type,
    required this.timestamp,
  });
}

class HotspotCreatedEvent extends OfflineSharingEvent {
  final String hotspotName;
  final String password;
  
  const HotspotCreatedEvent({
    required this.hotspotName,
    required this.password,
    required super.timestamp,
  }) : super(type: 'hotspotCreated');
  
  factory HotspotCreatedEvent.fromMap(Map<String, dynamic> map) {
    return HotspotCreatedEvent(
      hotspotName: map['hotspotName'] as String,
      password: map['password'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class HotspotStoppedEvent extends OfflineSharingEvent {
  const HotspotStoppedEvent({required super.timestamp}) : super(type: 'hotspotStopped');
  
  factory HotspotStoppedEvent.fromMap(Map<String, dynamic> map) {
    return HotspotStoppedEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class HotspotConnectedEvent extends OfflineSharingEvent {
  final String deviceId;
  final String deviceName;
  
  const HotspotConnectedEvent({
    required this.deviceId,
    required this.deviceName,
    required super.timestamp,
  }) : super(type: 'hotspotConnected');
  
  factory HotspotConnectedEvent.fromMap(Map<String, dynamic> map) {
    return HotspotConnectedEvent(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class HotspotDisconnectedEvent extends OfflineSharingEvent {
  final String deviceId;
  
  const HotspotDisconnectedEvent({
    required this.deviceId,
    required super.timestamp,
  }) : super(type: 'hotspotDisconnected');
  
  factory HotspotDisconnectedEvent.fromMap(Map<String, dynamic> map) {
    return HotspotDisconnectedEvent(
      deviceId: map['deviceId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class BluetoothStartedEvent extends OfflineSharingEvent {
  final String deviceName;
  
  const BluetoothStartedEvent({
    required this.deviceName,
    required super.timestamp,
  }) : super(type: 'bluetoothStarted');
  
  factory BluetoothStartedEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothStartedEvent(
      deviceName: map['deviceName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class BluetoothStoppedEvent extends OfflineSharingEvent {
  const BluetoothStoppedEvent({required super.timestamp}) : super(type: 'bluetoothStopped');
  
  factory BluetoothStoppedEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothStoppedEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class BluetoothConnectedEvent extends OfflineSharingEvent {
  final String deviceId;
  final String deviceName;
  
  const BluetoothConnectedEvent({
    required this.deviceId,
    required this.deviceName,
    required super.timestamp,
  }) : super(type: 'bluetoothConnected');
  
  factory BluetoothConnectedEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothConnectedEvent(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class BluetoothDisconnectedEvent extends OfflineSharingEvent {
  final String deviceId;
  
  const BluetoothDisconnectedEvent({
    required this.deviceId,
    required super.timestamp,
  }) : super(type: 'bluetoothDisconnected');
  
  factory BluetoothDisconnectedEvent.fromMap(Map<String, dynamic> map) {
    return BluetoothDisconnectedEvent(
      deviceId: map['deviceId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class OfflineTransferProgressEvent extends OfflineSharingEvent {
  final String transferId;
  final String fileName;
  final int bytesTransferred;
  final int totalBytes;
  final double speed;
  final OfflineSharingMethod method;
  
  const OfflineTransferProgressEvent({
    required this.transferId,
    required this.fileName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speed,
    required this.method,
    required super.timestamp,
  }) : super(type: 'offlineTransferProgress');
  
  factory OfflineTransferProgressEvent.fromMap(Map<String, dynamic> map) {
    return OfflineTransferProgressEvent(
      transferId: map['transferId'] as String,
      fileName: map['fileName'] as String,
      bytesTransferred: map['bytesTransferred'] as int,
      totalBytes: map['totalBytes'] as int,
      speed: (map['speed'] as num).toDouble(),
      method: OfflineSharingMethod.values.firstWhere(
        (e) => e.toString().split('.').last == map['method'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class OfflineTransferCompleteEvent extends OfflineSharingEvent {
  final String transferId;
  final String fileName;
  final String filePath;
  final OfflineSharingMethod method;
  
  const OfflineTransferCompleteEvent({
    required this.transferId,
    required this.fileName,
    required this.filePath,
    required this.method,
    required super.timestamp,
  }) : super(type: 'offlineTransferComplete');
  
  factory OfflineTransferCompleteEvent.fromMap(Map<String, dynamic> map) {
    return OfflineTransferCompleteEvent(
      transferId: map['transferId'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      method: OfflineSharingMethod.values.firstWhere(
        (e) => e.toString().split('.').last == map['method'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class OfflineTransferFailedEvent extends OfflineSharingEvent {
  final String transferId;
  final String fileName;
  final String error;
  final OfflineSharingMethod method;
  
  const OfflineTransferFailedEvent({
    required this.transferId,
    required this.fileName,
    required this.error,
    required this.method,
    required super.timestamp,
  }) : super(type: 'offlineTransferFailed');
  
  factory OfflineTransferFailedEvent.fromMap(Map<String, dynamic> map) {
    return OfflineTransferFailedEvent(
      transferId: map['transferId'] as String,
      fileName: map['fileName'] as String,
      error: map['error'] as String,
      method: OfflineSharingMethod.values.firstWhere(
        (e) => e.toString().split('.').last == map['method'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

/// Offline sharing specific exception
class OfflineSharingException implements Exception {
  final String message;
  const OfflineSharingException(this.message);
  
  @override
  String toString() => 'OfflineSharingException: $message';
}
