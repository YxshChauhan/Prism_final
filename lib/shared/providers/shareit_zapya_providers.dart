import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/dependency_injection.dart';
import 'package:airlink/core/services/shareit_zapya_integration_service.dart' as integration;
import 'package:airlink/core/services/wifi_direct_service.dart';
import 'package:airlink/core/services/offline_sharing_service.dart';
import 'package:airlink/core/services/phone_replication_service.dart';
import 'package:airlink/core/services/group_sharing_service.dart';
import 'package:airlink/shared/models/app_state.dart' as ui;
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/core/services/enhanced_transfer_service.dart' as svc;


/// Main integration service provider
final integrationServiceProvider = Provider<integration.ShareitZapyaIntegrationService>((ref) {
  return getIt<integration.ShareitZapyaIntegrationService>();
});

/// Wi-Fi Direct service provider
final wifiDirectServiceProvider = Provider<WifiDirectService>((ref) {
  return getIt<WifiDirectService>();
});

/// Offline sharing service provider
final offlineSharingServiceProvider = Provider<OfflineSharingService>((ref) {
  return getIt<OfflineSharingService>();
});

/// Phone replication service provider
final phoneReplicationServiceProvider = Provider<PhoneReplicationService>((ref) {
  return getIt<PhoneReplicationService>();
});

/// Group sharing service provider
final groupSharingServiceProvider = Provider<GroupSharingService>((ref) {
  return getIt<GroupSharingService>();
});

/// Enhanced transfer service provider
final enhancedTransferServiceProvider = Provider<svc.EnhancedTransferService?>((ref) {
  try {
    return getIt<svc.EnhancedTransferService>();
  } catch (e) {
    return null; // Service not registered
  }
});

// ==================== State Providers ====================

/// Service initialization status
final serviceInitializedProvider = StateProvider<bool>((ref) => false);

/// Current transfer method (using String instead of undefined enum)
final currentTransferMethodProvider = StateProvider<String>((ref) => 'wifiDirect');

/// Discovered devices from all sources
final discoveredDevicesProvider = StateProvider<List<ui.DeviceInfo>>((ref) => []);

/// Wi-Fi Direct devices
final wifiDirectDevicesProvider = StateProvider<List<dynamic>>((ref) => []);

/// Bluetooth devices
final bluetoothDevicesProvider = StateProvider<List<dynamic>>((ref) => []);

/// Available hotspots
final hotspotListProvider = StateProvider<List<dynamic>>((ref) => []);

/// Available groups
final groupListProvider = StateProvider<List<dynamic>>((ref) => []);

/// Active hotspot status
final activeHotspotProvider = StateProvider<String?>((ref) => null);

/// Active group status
final activeGroupProvider = StateProvider<String?>((ref) => null);

/// Current phone replication status
final replicationStatusProvider = StateProvider<ui.UIReplicationStatus?>((ref) => null);

/// Active transfer sessions (UI model)
final enhancedActiveTransfersProvider = StateProvider<List<ui.TransferSession>>((ref) => []);

/// Transfer metrics map (using dynamic for undefined type)
final transferMetricsProvider = StateProvider<Map<String, dynamic>>((ref) => {});

/// Service status (using dynamic for undefined type)
final serviceStatusProvider = StateProvider<dynamic>((ref) => null);

// ==================== Stream Providers ====================

/// Transfer progress stream for a specific transfer
final transferProgressStreamProvider = StreamProvider.family<ui.TransferProgress, String>((ref, transferId) {
  final integrationService = ref.watch(integrationServiceProvider);
  // Map the service TransferProgress to app_state TransferProgress
  return integrationService.getTransferProgress(transferId).map((progress) => ui.TransferProgress(
    transferId: transferId,
    fileName: 'Unknown',
    bytesTransferred: progress.bytesTransferred,
    totalBytes: progress.totalBytes,
    speed: progress.speed,
    status: unified.TransferStatus.transferring,
    startedAt: DateTime.now(),
  ));
});

/// Wi-Fi Direct events stream
final wifiDirectEventsProvider = StreamProvider<WifiDirectEvent>((ref) {
  final wifiDirectService = ref.watch(wifiDirectServiceProvider);
  return wifiDirectService.eventStream;
});

/// Offline sharing events stream
final offlineSharingEventsProvider = StreamProvider<OfflineSharingEvent>((ref) {
  final offlineSharingService = ref.watch(offlineSharingServiceProvider);
  return offlineSharingService.eventStream;
});

/// Phone replication events stream
final phoneReplicationEventsProvider = StreamProvider<PhoneReplicationEvent>((ref) {
  final phoneReplicationService = ref.watch(phoneReplicationServiceProvider);
  return phoneReplicationService.eventStream;
});

/// Group sharing events stream
final groupSharingEventsProvider = StreamProvider<GroupSharingEvent>((ref) {
  final groupSharingService = ref.watch(groupSharingServiceProvider);
  return groupSharingService.eventStream;
});

// ==================== Future Providers ====================

/// Initialize all services
final initializeServicesProvider = FutureProvider<void>((ref) async {
  final integrationService = ref.watch(integrationServiceProvider);
  await integrationService.initialize();
  ref.read(serviceInitializedProvider.notifier).state = true;
});

/// Discover nearby devices
final discoverDevicesProvider = FutureProvider<List<ui.DeviceInfo>>((ref) async {
  final integrationService = ref.watch(integrationServiceProvider);
  final devices = await integrationService.discoverNearbyDevices();
  // Cast to app_state DeviceInfo type
  ref.read(discoveredDevicesProvider.notifier).state = devices.map((d) => ui.DeviceInfo(
    deviceName: d.name,
    model: d.type.toString(),
    osVersion: 'Unknown',
    totalStorage: 0,
    availableStorage: 0,
    batteryLevel: 100,
  )).toList();
  return ref.read(discoveredDevicesProvider);
});

/// Get Wi-Fi Direct discovered devices
final getWifiDirectDevicesProvider = FutureProvider<List<dynamic>>((ref) async {
  final wifiDirectService = ref.watch(wifiDirectServiceProvider);
  final devices = await wifiDirectService.getDiscoveredDevices();
  ref.read(wifiDirectDevicesProvider.notifier).state = devices;
  return devices;
});

/// Scan for hotspots
final scanHotspotsProvider = FutureProvider<List<dynamic>>((ref) async {
  final offlineSharingService = ref.watch(offlineSharingServiceProvider);
  final hotspots = await offlineSharingService.scanHotspots();
  ref.read(hotspotListProvider.notifier).state = hotspots;
  return hotspots;
});

/// Scan for Bluetooth devices
final scanBluetoothDevicesProvider = FutureProvider<List<dynamic>>((ref) async {
  final offlineSharingService = ref.watch(offlineSharingServiceProvider);
  final devices = await offlineSharingService.scanBluetoothDevices();
  ref.read(bluetoothDevicesProvider.notifier).state = devices;
  return devices;
});

/// Discover groups
final discoverGroupsProvider = FutureProvider<List<dynamic>>((ref) async {
  final groupSharingService = ref.watch(groupSharingServiceProvider);
  final groups = await groupSharingService.discoverGroups();
  ref.read(groupListProvider.notifier).state = groups;
  return groups;
});

/// Get device data summary
final deviceDataSummaryProvider = FutureProvider<dynamic>((ref) async {
  final phoneReplicationService = ref.watch(phoneReplicationServiceProvider);
  return await phoneReplicationService.getDeviceDataSummary();
});

/// Get service status
final getServiceStatusProvider = FutureProvider<dynamic>((ref) async {
  final integrationService = ref.watch(integrationServiceProvider);
  final status = integrationService.getServiceStatus();
  ref.read(serviceStatusProvider.notifier).state = status;
  return status;
});

// ==================== Action Providers ====================

/// Provider for starting Wi-Fi Direct transfer
final startWifiDirectTransferProvider = Provider.autoDispose.family<Future<String> Function(List<ui.TransferFile>), String>(
  (ref, targetDeviceId) {
    return (List<ui.TransferFile> files) async {
      final integrationService = ref.read(integrationServiceProvider);
      // Convert files to the format expected by the service
      final transferId = await integrationService.startWifiDirectTransfer(
        targetDeviceId: targetDeviceId,
        files: files as dynamic,
      );
      
      // Update active transfers
      final currentTransfers = ref.read(enhancedActiveTransfersProvider);
      final newTransfers = [...currentTransfers];
      ref.read(enhancedActiveTransfersProvider.notifier).state = newTransfers;
      
      return transferId;
    };
  },
);

/// Provider for starting hotspot transfer
final startHotspotTransferProvider = Provider.autoDispose.family<Future<String> Function(List<ui.TransferFile>), Map<String, String>>(
  (ref, credentials) {
    return (List<ui.TransferFile> files) async {
      final integrationService = ref.read(integrationServiceProvider);
      final transferId = await integrationService.startHotspotTransfer(
        hotspotName: credentials['name']!,
        password: credentials['password']!,
        files: files as dynamic,
      );
      return transferId;
    };
  },
);

/// Provider for starting Bluetooth transfer
final startBluetoothTransferProvider = Provider.autoDispose.family<Future<String> Function(List<ui.TransferFile>), String>(
  (ref, targetDeviceId) {
    return (List<ui.TransferFile> files) async {
      final integrationService = ref.read(integrationServiceProvider);
      final transferId = await integrationService.startBluetoothTransfer(
        targetDeviceId: targetDeviceId,
        files: files as dynamic,
      );
      return transferId;
    };
  },
);

/// Provider for creating offline hotspot
final createOfflineHotspotProvider = Provider.autoDispose<Future<String> Function(String?, String?)>((ref) {
  return (String? hotspotName, String? password) async {
    final integrationService = ref.read(integrationServiceProvider);
    final hotspotId = await integrationService.createOfflineHotspot(
      hotspotName: hotspotName,
      password: password,
      maxConnections: 8,
    );
    ref.read(activeHotspotProvider.notifier).state = hotspotId;
    return hotspotId;
  };
});

/// Provider for starting phone replication
final startPhoneReplicationProvider = Provider.autoDispose.family<Future<String> Function(List<dynamic>), String>(
  (ref, targetDeviceId) {
    return (List<dynamic> categories) async {
      final integrationService = ref.read(integrationServiceProvider);
      final replicationId = await integrationService.startPhoneReplication(
        targetDeviceId: targetDeviceId,
        categories: categories as dynamic,
      );
      return replicationId;
    };
  },
);

/// Provider for creating group
final createGroupProvider = Provider.autoDispose<Future<String> Function(String, List<ui.TransferFile>, dynamic, String?)>((ref) {
  return (String groupName, List<ui.TransferFile> files, dynamic privacy, String? password) async {
    final integrationService = ref.read(integrationServiceProvider);
    final groupId = await integrationService.startGroupSharing(
      groupName: groupName,
      files: files as dynamic,
      maxMembers: 8,
      privacy: privacy,
      password: password,
    );
    ref.read(activeGroupProvider.notifier).state = groupId;
    return groupId;
  };
});

/// Provider for pausing transfer
final pauseTransferProvider = Provider.autoDispose.family<Future<void> Function(), String>((ref, transferId) {
  return () async {
    final integrationService = ref.read(integrationServiceProvider);
    await integrationService.pauseTransfer(transferId);
  };
});

/// Provider for resuming transfer
final resumeTransferProvider = Provider.autoDispose.family<Future<void> Function(), String>((ref, transferId) {
  return () async {
    final integrationService = ref.read(integrationServiceProvider);
    await integrationService.resumeTransfer(transferId);
  };
});

/// Provider for cancelling transfer
final cancelTransferProvider = Provider.autoDispose.family<Future<void> Function(), String>((ref, transferId) {
  return () async {
    final integrationService = ref.read(integrationServiceProvider);
    await integrationService.cancelTransfer(transferId);
  };
});

/// Provider for stopping hotspot
final stopHotspotProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  return () async {
    final offlineSharingService = ref.read(offlineSharingServiceProvider);
    await offlineSharingService.stopHotspot();
    ref.read(activeHotspotProvider.notifier).state = null;
  };
});

/// Provider for leaving group
final leaveGroupProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  return () async {
    final groupSharingService = ref.read(groupSharingServiceProvider);
    await groupSharingService.leaveGroup();
    ref.read(activeGroupProvider.notifier).state = null;
  };
});

// ==================== Controller Providers ====================

/// Discovery controller
final discoveryControllerProvider = Provider<DiscoveryController>((ref) {
  return DiscoveryController(ref);
});

/// Transfer controller
final transferControllerProvider = Provider<TransferController>((ref) {
  return TransferController(ref);
});

/// Hotspot controller
final hotspotControllerProvider = Provider<HotspotController>((ref) {
  return HotspotController(ref);
});

/// Group controller
final groupControllerProvider = Provider<GroupController>((ref) {
  return GroupController(ref);
});

/// Replication controller
final replicationControllerProvider = Provider<ReplicationController>((ref) {
  return ReplicationController(ref);
});

// ==================== Controller Classes ====================

/// Discovery controller for managing device discovery
class DiscoveryController {
  final Ref _ref;
  
  DiscoveryController(this._ref);
  
  Future<void> startDiscovery() async {
    final integrationService = _ref.read(integrationServiceProvider);
    final devices = await integrationService.discoverNearbyDevices();
    // Cast to app_state DeviceInfo type
    _ref.read(discoveredDevicesProvider.notifier).state = devices.map((d) => ui.DeviceInfo(
      deviceName: d.name,
      model: d.type.toString(),
      osVersion: 'Unknown',
      totalStorage: 0,
      availableStorage: 0,
      batteryLevel: 100,
    )).toList();
  }
  
  Future<void> startWifiDirectDiscovery() async {
    final wifiDirectService = _ref.read(wifiDirectServiceProvider);
    await wifiDirectService.startDiscovery();
  }
  
  Future<void> stopWifiDirectDiscovery() async {
    final wifiDirectService = _ref.read(wifiDirectServiceProvider);
    await wifiDirectService.stopDiscovery();
  }
  
  Future<void> refreshDevices() async {
    await startDiscovery();
  }
}

/// Transfer controller for managing file transfers
class TransferController {
  final Ref _ref;
  
  TransferController(this._ref);
  
  Future<String> startTransfer({
    required String targetDeviceId,
    required List<ui.TransferFile> files,
    required String method,
  }) async {
    final integrationService = _ref.read(integrationServiceProvider);
    
    switch (method) {
      case 'wifiDirect':
        return await integrationService.startWifiDirectTransfer(
          targetDeviceId: targetDeviceId,
          files: files as dynamic,
        );
      case 'bluetooth':
        return await integrationService.startBluetoothTransfer(
          targetDeviceId: targetDeviceId,
          files: files as dynamic,
        );
      default:
        throw Exception('Unsupported transfer method: $method');
    }
  }
  
  Future<void> pauseTransfer(String transferId) async {
    final action = _ref.read(pauseTransferProvider(transferId));
    await action();
  }
  
  Future<void> resumeTransfer(String transferId) async {
    final action = _ref.read(resumeTransferProvider(transferId));
    await action();
  }
  
  Future<void> cancelTransfer(String transferId) async {
    final action = _ref.read(cancelTransferProvider(transferId));
    await action();
  }
  
  List<ui.TransferSession> getActiveTransfers() {
    return _ref.read(enhancedActiveTransfersProvider);
  }
}

/// Hotspot controller for managing offline sharing
class HotspotController {
  final Ref _ref;
  
  HotspotController(this._ref);
  
  Future<String> createHotspot({String? name, String? password}) async {
    final action = _ref.read(createOfflineHotspotProvider);
    return await action(name, password);
  }
  
  Future<void> stopHotspot() async {
    final action = _ref.read(stopHotspotProvider);
    await action();
  }
  
  Future<List<dynamic>> scanHotspots() async {
    final offlineSharingService = _ref.read(offlineSharingServiceProvider);
    return await offlineSharingService.scanHotspots();
  }
  
  Future<void> connectToHotspot(String hotspotName, String password) async {
    final offlineSharingService = _ref.read(offlineSharingServiceProvider);
    await offlineSharingService.connectToHotspot(
      hotspotName: hotspotName,
      password: password,
    );
  }
}

/// Group controller for managing group sharing
class GroupController {
  final Ref _ref;
  
  GroupController(this._ref);
  
  Future<String> createGroup({
    required String groupName,
    required List<ui.TransferFile> files,
    dynamic privacy = null,
    String? password,
  }) async {
    final action = _ref.read(createGroupProvider);
    return await action(groupName, files, privacy, password);
  }
  
  Future<void> leaveGroup() async {
    final action = _ref.read(leaveGroupProvider);
    await action();
  }
  
  Future<List<dynamic>> discoverGroups() async {
    final groupSharingService = _ref.read(groupSharingServiceProvider);
    return await groupSharingService.discoverGroups();
  }
  
  Future<void> joinGroup(String groupId, {String? password}) async {
    final groupSharingService = _ref.read(groupSharingServiceProvider);
    await groupSharingService.joinGroup(groupId: groupId, password: password);
  }
}

/// Replication controller for managing phone replication
class ReplicationController {
  final Ref _ref;
  
  ReplicationController(this._ref);
  
  Future<String> startReplication({
    required String targetDeviceId,
    required List<dynamic> categories,
  }) async {
    final action = _ref.read(startPhoneReplicationProvider(targetDeviceId));
    return await action(categories);
  }
  
  Future<void> cancelReplication(String replicationId) async {
    final phoneReplicationService = _ref.read(phoneReplicationServiceProvider);
    await phoneReplicationService.cancelReplication();
  }
  
  Future<dynamic> getDeviceDataSummary() async {
    final phoneReplicationService = _ref.read(phoneReplicationServiceProvider);
    return await phoneReplicationService.getDeviceDataSummary();
  }
  
  Future<dynamic> getReplicationProgress(String replicationId) async {
    final phoneReplicationService = _ref.read(phoneReplicationServiceProvider);
    return await phoneReplicationService.getReplicationProgress(replicationId);
  }
}
