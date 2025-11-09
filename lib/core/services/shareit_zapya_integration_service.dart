import 'dart:async';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/enhanced_transfer_service.dart';
import 'package:airlink/core/services/wifi_direct_service.dart';
import 'package:airlink/core/services/offline_sharing_service.dart';
import 'package:airlink/core/services/phone_replication_service.dart';
import 'package:airlink/core/services/group_sharing_service.dart';
import 'package:airlink/shared/models/transfer_models.dart';
import 'package:injectable/injectable.dart';

/// Main integration service that combines all SHAREit/Zapya functionalities
/// Provides a unified interface for all transfer methods and features
@injectable
class ShareitZapyaIntegrationService {
  final LoggerService _logger;
  final EnhancedTransferService _transferService;
  final WifiDirectService _wifiDirectService;
  final OfflineSharingService _offlineSharingService;
  final PhoneReplicationService _phoneReplicationService;
  final GroupSharingService _groupSharingService;
  
  // Service state
  bool _isInitialized = false;
  final Map<String, StreamController<IntegrationEvent>> _eventControllers = {};
  
  ShareitZapyaIntegrationService({
    required LoggerService logger,
    required EnhancedTransferService transferService,
    required WifiDirectService wifiDirectService,
    required OfflineSharingService offlineSharingService,
    required PhoneReplicationService phoneReplicationService,
    required GroupSharingService groupSharingService,
  }) : _logger = logger,
       _transferService = transferService,
       _wifiDirectService = wifiDirectService,
       _offlineSharingService = offlineSharingService,
       _phoneReplicationService = phoneReplicationService,
       _groupSharingService = groupSharingService;
  
  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.info('Initializing SHAREit/Zapya integration service...');
      
      // Initialize all core services
      await _wifiDirectService.initialize();
      await _offlineSharingService.initialize();
      await _phoneReplicationService.initialize();
      await _groupSharingService.initialize();
      
      _isInitialized = true;
      _logger.info('SHAREit/Zapya integration service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize integration service: $e');
      throw IntegrationException('Failed to initialize service: $e');
    }
  }
  
  /// Start high-speed Wi-Fi Direct transfer
  Future<String> startWifiDirectTransfer({
    required String targetDeviceId,
    required List<TransferFile> files,
    TransferPriority priority = TransferPriority.normal,
    bool enableEncryption = true,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Starting Wi-Fi Direct transfer to: $targetDeviceId');
      
      final String transferId = await _transferService.startEnhancedTransfer(
        targetDeviceId: targetDeviceId,
        files: files,
        method: TransferMethod.wifiDirect,
        priority: priority,
        enableEncryption: enableEncryption,
        enableCompression: true,
        enableResume: true,
      );
      
      _logger.info('Wi-Fi Direct transfer started: $transferId');
      return transferId;
    } catch (e) {
      _logger.error('Failed to start Wi-Fi Direct transfer: $e');
      throw IntegrationException('Failed to start Wi-Fi Direct transfer: $e');
    }
  }
  
  /// Start offline hotspot transfer
  Future<String> startHotspotTransfer({
    required String hotspotName,
    required String password,
    required List<TransferFile> files,
    TransferPriority priority = TransferPriority.normal,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Starting hotspot transfer to: $hotspotName');
      
      // Connect to hotspot
      await _offlineSharingService.connectToHotspot(
        hotspotName: hotspotName,
        password: password,
      );
      
      final String transferId = await _transferService.startEnhancedTransfer(
        targetDeviceId: hotspotName,
        files: files,
        method: TransferMethod.hotspot,
        priority: priority,
        enableEncryption: true,
        enableCompression: true,
        enableResume: true,
      );
      
      _logger.info('Hotspot transfer started: $transferId');
      return transferId;
    } catch (e) {
      _logger.error('Failed to start hotspot transfer: $e');
      throw IntegrationException('Failed to start hotspot transfer: $e');
    }
  }
  
  /// Start Bluetooth transfer
  Future<String> startBluetoothTransfer({
    required String targetDeviceId,
    required List<TransferFile> files,
    TransferPriority priority = TransferPriority.normal,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Starting Bluetooth transfer to: $targetDeviceId');
      
      final String transferId = await _transferService.startEnhancedTransfer(
        targetDeviceId: targetDeviceId,
        files: files,
        method: TransferMethod.bluetooth,
        priority: priority,
        enableEncryption: true,
        enableCompression: false, // Bluetooth is slower, skip compression
        enableResume: true,
      );
      
      _logger.info('Bluetooth transfer started: $transferId');
      return transferId;
    } catch (e) {
      _logger.error('Failed to start Bluetooth transfer: $e');
      throw IntegrationException('Failed to start Bluetooth transfer: $e');
    }
  }
  
  /// Start phone replication
  Future<String> startPhoneReplication({
    required String targetDeviceId,
    required List<ReplicationCategory> categories,
    String? customName,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Starting phone replication to: $targetDeviceId');
      
      final String replicationId = await _phoneReplicationService.startReplication(
        targetDeviceId: targetDeviceId,
        categories: categories,
        customName: customName,
      );
      
      _logger.info('Phone replication started: $replicationId');
      return replicationId;
    } catch (e) {
      _logger.error('Failed to start phone replication: $e');
      throw IntegrationException('Failed to start phone replication: $e');
    }
  }
  
  /// Start group sharing
  Future<String> startGroupSharing({
    required String groupName,
    required List<TransferFile> files,
    int maxMembers = 8,
    GroupPrivacy privacy = GroupPrivacy.private,
    String? password,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Starting group sharing: $groupName');
      
      // Create group
      final String groupId = await _groupSharingService.createGroup(
        groupName: groupName,
        maxMembers: maxMembers,
        privacy: privacy,
        password: password,
      );
      
      // Share files with group
      for (final file in files) {
        await _groupSharingService.shareFile(
          filePath: file.path,
          fileName: file.name,
          fileSize: file.size,
        );
      }
      
      _logger.info('Group sharing started: $groupId');
      return groupId;
    } catch (e) {
      _logger.error('Failed to start group sharing: $e');
      throw IntegrationException('Failed to start group sharing: $e');
    }
  }
  
  /// Create Wi-Fi hotspot for offline sharing
  Future<String> createOfflineHotspot({
    String? hotspotName,
    String? password,
    int maxConnections = 8,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Creating offline hotspot...');
      
      final String hotspotId = await _offlineSharingService.createHotspot(
        hotspotName: hotspotName,
        password: password,
        maxConnections: maxConnections,
      );
      
      _logger.info('Offline hotspot created: $hotspotId');
      return hotspotId;
    } catch (e) {
      _logger.error('Failed to create offline hotspot: $e');
      throw IntegrationException('Failed to create offline hotspot: $e');
    }
  }
  
  /// Discover nearby devices
  Future<List<IntegrationDeviceInfo>> discoverNearbyDevices() async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Discovering nearby devices...');
      
      final List<IntegrationDeviceInfo> devices = [];
      
      // Discover Wi-Fi Direct devices
      final wifiDirectDevices = await _wifiDirectService.getDiscoveredDevices();
      for (final device in wifiDirectDevices) {
        devices.add(IntegrationDeviceInfo(
          id: device.deviceId,
          name: device.deviceName,
          type: IntegrationDeviceType.wifiDirect,
          signalStrength: device.signalStrength,
          isConnected: false,
          capabilities: device.capabilities,
        ));
      }
      
      // Discover Bluetooth devices
      final bluetoothDevices = await _offlineSharingService.scanBluetoothDevices();
      for (final device in bluetoothDevices) {
        devices.add(IntegrationDeviceInfo(
          id: device.deviceId,
          name: device.deviceName,
          type: IntegrationDeviceType.bluetooth,
          signalStrength: device.signalStrength,
          isConnected: device.isConnected,
          capabilities: {},
        ));
      }
      
      // Discover groups
      final groups = await _groupSharingService.discoverGroups();
      for (final group in groups) {
        devices.add(IntegrationDeviceInfo(
          id: group.groupId,
          name: group.groupName,
          type: IntegrationDeviceType.group,
          signalStrength: group.signalStrength,
          isConnected: false,
          capabilities: {
            'memberCount': group.memberCount,
            'maxMembers': group.maxMembers,
            'privacy': group.privacy.toString(),
          },
        ));
      }
      
      _logger.info('Discovered ${devices.length} nearby devices');
      return devices;
    } catch (e) {
      _logger.error('Failed to discover nearby devices: $e');
      return [];
    }
  }
  
  /// Get transfer progress
  Stream<TransferProgress> getTransferProgress(String transferId) {
    return _transferService.getTransferProgress(transferId);
  }
  
  /// Pause transfer
  Future<void> pauseTransfer(String transferId) async {
    await _transferService.pauseTransfer(transferId);
  }
  
  /// Resume transfer
  Future<void> resumeTransfer(String transferId) async {
    await _transferService.resumeTransfer(transferId);
  }
  
  /// Cancel transfer
  Future<void> cancelTransfer(String transferId) async {
    await _transferService.cancelTransfer(transferId);
  }
  
  /// Get all active transfers
  List<TransferSession> getActiveTransfers() {
    return _transferService.getActiveTransfers();
  }
  
  /// Get transfer metrics
  TransferMetrics? getTransferMetrics(String transferId) {
    return _transferService.getTransferMetrics(transferId);
  }
  
  /// Get service status
  IntegrationServiceStatus getServiceStatus() {
    return IntegrationServiceStatus(
      isInitialized: _isInitialized,
      wifiDirectStatus: _wifiDirectService.getStatus(),
      offlineSharingStatus: _offlineSharingService.getStatus(),
      groupSharingStatus: _groupSharingService.getGroupStatus(),
      activeTransfers: _transferService.getActiveTransfers().length,
    );
  }
  
  /// Cleanup all services
  Future<void> cleanup() async {
    try {
      _logger.info('Cleaning up integration service...');
      
      // Stop all active transfers
      for (final transfer in _transferService.getActiveTransfers()) {
        await _transferService.cancelTransfer(transfer.id);
      }
      
      // Stop all services
      await _wifiDirectService.disconnect();
      await _offlineSharingService.stopHotspot();
      await _offlineSharingService.stopBluetoothSharing();
      await _groupSharingService.leaveGroup();
      
      // Close event controllers
      for (final controller in _eventControllers.values) {
        controller.close();
      }
      _eventControllers.clear();
      
      _isInitialized = false;
      _logger.info('Integration service cleaned up');
    } catch (e) {
      _logger.error('Failed to cleanup integration service: $e');
    }
  }
}

/// Device information model
class IntegrationDeviceInfo {
  final String id;
  final String name;
  final IntegrationDeviceType type;
  final int signalStrength;
  final bool isConnected;
  final Map<String, dynamic> capabilities;
  
  const IntegrationDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.signalStrength,
    required this.isConnected,
    required this.capabilities,
  });
}

/// Device type enum
enum IntegrationDeviceType {
  wifiDirect,
  bluetooth,
  hotspot,
  group,
}

/// Service status model
class IntegrationServiceStatus {
  final bool isInitialized;
  final dynamic wifiDirectStatus;
  final dynamic offlineSharingStatus;
  final dynamic groupSharingStatus;
  final int activeTransfers;
  
  const IntegrationServiceStatus({
    required this.isInitialized,
    required this.wifiDirectStatus,
    required this.offlineSharingStatus,
    required this.groupSharingStatus,
    required this.activeTransfers,
  });
}

/// Integration event base class
abstract class IntegrationEvent {
  final String type;
  final DateTime timestamp;
  
  const IntegrationEvent({
    required this.type,
    required this.timestamp,
  });
}

/// Integration specific exception
class IntegrationException implements Exception {
  final String message;
  const IntegrationException(this.message);
  
  @override
  String toString() => 'IntegrationException: $message';
}
