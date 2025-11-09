import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/dependency_injection.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/core/constants/feature_flags.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:airlink/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:airlink/core/services/device_service.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';
import 'package:airlink/core/services/transfer_benchmark.dart';



/// Current app page
final currentPageProvider = StateProvider<AppPage>((ref) => AppPage.home);

/// App theme mode
final appThemeProvider = StateProvider<ThemeMode>((ref) => 
    FeatureFlags.DARK_MODE_ENABLED ? ThemeMode.system : ThemeMode.light);

/// App initialization state
final appInitializedProvider = StateProvider<bool>((ref) => false);


/// Discovery controller using repository pattern
final discoveryControllerProvider = StateNotifierProvider<DiscoveryController, DiscoveryState>((ref) {
  final repository = ref.watch(discoveryRepositoryProvider);
  return DiscoveryController(repository);
});

/// Nearby devices list
final nearbyDevicesProvider = Provider<List<Device>>((ref) {
  final state = ref.watch(discoveryControllerProvider);
  return state.devices;
});

/// Discovery status
final isDiscoveringProvider = Provider<bool>((ref) {
  final state = ref.watch(discoveryControllerProvider);
  return state.isDiscovering;
});

/// Ready to receive status
final isReceivingProvider = StateProvider<bool>((ref) => false);

/// Selected device for transfer
final selectedDeviceProvider = StateProvider<Device?>((ref) => null);


/// Transfer controller using repository pattern
/// Now uses the TransferController from features/transfer/presentation/providers/transfer_provider.dart

/// Selected files for transfer
final selectedFilesProvider = StateProvider<List<TransferFile>>((ref) => []);

// Note: Active transfers, transfer history, and transfer progress providers
// are now handled by the feature-based providers in transfer_provider.dart
// These are imported and available through the transfer_provider.dart file

// ==================== Repository Providers ====================

/// Discovery repository provider
final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return getIt<DiscoveryRepository>();
});

/// Transfer repository provider
final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return getIt<TransferRepository>();
});

/// Device service provider
final deviceServiceProvider = Provider<DeviceService>((ref) {
  return getIt<DeviceService>();
});

/// Transfer benchmarking service provider
final transferBenchmarkingServiceProvider = Provider<TransferBenchmarkingService>((ref) {
  return getIt<TransferBenchmarkingService>();
});

/// Transfer benchmarks data provider
final transferBenchmarksProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(transferBenchmarkingServiceProvider);
  final report = await service.generateReport();
  final benchmarks = await service.getAllBenchmarks();
  return {
    ...report,
    'benchmarks': benchmarks.map((b) => b.toMap()).toList(),
  };
});

/// Transfer benchmarks list provider
final transferBenchmarksListProvider = FutureProvider<List<TransferBenchmark>>((ref) async {
  final service = ref.watch(transferBenchmarkingServiceProvider);
  return await service.getAllBenchmarks();
});

/// Combined transfer benchmarks provider that returns both summary and list
final transferBenchmarksCombinedProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(transferBenchmarkingServiceProvider);
  final report = await service.generateReport();
  final benchmarks = await service.getAllBenchmarks();
  
  return {
    'report': report,
    'benchmarks': benchmarks,
    'summary': {
      'total_transfers': benchmarks.length,
      'successful_transfers': benchmarks.where((b) => b.status == unified.TransferStatus.completed).length,
      'average_speed': benchmarks.isNotEmpty 
          ? benchmarks.where((b) => b.status == unified.TransferStatus.completed)
              .map((b) => b.averageSpeed)
              .fold(0.0, (a, b) => a + b) / benchmarks.where((b) => b.status == unified.TransferStatus.completed).length
          : 0.0,
    },
  };
});

/// Aggregated transfer statistics provider
final transferStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(transferBenchmarkingServiceProvider);
  final benchmarks = await service.getAllBenchmarks();
  int filesSent = 0;
  int filesReceived = 0;
  int totalBytes = 0; // Dart int is arbitrary precision
  double totalSpeed = 0.0;
  int completedCount = 0;

  for (final b in benchmarks) {
    // Direction inference by transferId suffix or metadata is not guaranteed; approximate by method
    if (b.status == unified.TransferStatus.completed) {
      completedCount += 1;
      totalSpeed += b.averageSpeed;
    }
    totalBytes += b.bytesTransferred;
    // Count as sent/received based on naming convention
    if (b.transferId.contains('_ble_receive')) {
      filesReceived += 1;
    } else if (b.transferId.contains('_')) {
      filesSent += 1;
    }
  }

  final avgSpeed = completedCount > 0 ? totalSpeed / completedCount : 0.0;
  return {
    'files_sent': filesSent,
    'files_received': filesReceived,
    'total_bytes': totalBytes,
    'avg_speed': avgSpeed,
  };
});

/// Recent transfers provider (last 5 by createdAt desc)
final recentTransfersProvider = FutureProvider<List<unified.TransferSession>>((ref) async {
  final repository = ref.watch(transferRepositoryProvider);
  final all = await repository.getTransferHistory();
  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all.take(5).toList();
});

/// Core method channel
final coreMethodChannelProvider = Provider<MethodChannel>((ref) {
  return getIt<MethodChannel>(instanceName: 'airlink/core');
});

/// Core event channel
final coreEventChannelProvider = Provider<EventChannel>((ref) {
  return getIt<EventChannel>(instanceName: 'airlink/events');
});

/// Discovery method channel
final discoveryMethodChannelProvider = Provider<MethodChannel>((ref) {
  return getIt<MethodChannel>(instanceName: 'discovery');
});

/// Discovery event channel
final discoveryEventChannelProvider = Provider<EventChannel>((ref) {
  return getIt<EventChannel>(instanceName: 'discoveryEvents');
});

/// Transfer method channel
final transferMethodChannelProvider = Provider<MethodChannel>((ref) {
  return getIt<MethodChannel>(instanceName: 'transfer');
});

/// Transfer event channel
final transferEventChannelProvider = Provider<EventChannel>((ref) {
  return getIt<EventChannel>(instanceName: 'transferEvents');
});

// ==================== Event Stream Processing ====================

/// Discovery events stream
final discoveryEventStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final eventChannel = ref.watch(discoveryEventChannelProvider);
  return eventChannel.receiveBroadcastStream().map((event) {
    if (event is Map<String, dynamic>) {
      return event;
    }
    return <String, dynamic>{};
  });
});

/// Transfer events stream
final transferEventStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final eventChannel = ref.watch(transferEventChannelProvider);
  return eventChannel.receiveBroadcastStream().map((event) {
    if (event is Map<String, dynamic>) {
      return event;
    }
    return <String, dynamic>{};
  });
});

// ==================== Discovery Controller ====================

/// Discovery controller state
class DiscoveryState {
  final List<Device> devices;
  final bool isDiscovering;
  final bool isPublishing;
  final String? error;
  final bool isInitialized;

  const DiscoveryState({
    this.devices = const [],
    this.isDiscovering = false,
    this.isPublishing = false,
    this.error,
    this.isInitialized = false,
  });

  DiscoveryState copyWith({
    List<Device>? devices,
    bool? isDiscovering,
    bool? isPublishing,
    String? error,
    bool? isInitialized,
  }) {
    return DiscoveryState(
      devices: devices ?? this.devices,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      isPublishing: isPublishing ?? this.isPublishing,
      error: error ?? this.error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Discovery controller using repository pattern
class DiscoveryController extends StateNotifier<DiscoveryState> {
  final DiscoveryRepository _repository;
  StreamSubscription<List<Device>>? _eventSubscription;

  DiscoveryController(this._repository) : super(const DiscoveryState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Start discovery stream with proper error handling
      _eventSubscription = _repository.startDiscovery().listen(
        (devices) {
          state = state.copyWith(devices: devices);
        },
        onError: (error) {
          state = state.copyWith(error: 'Discovery stream error: $error');
        },
      );
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize discovery: $e');
    }
  }



  Future<void> startDiscovery() async {
    if (!FeatureFlags.DISCOVERY_ENABLED) {
      state = state.copyWith(error: 'Discovery is disabled in feature flags');
      return;
    }

    try {
      state = state.copyWith(isDiscovering: true, error: null);
      // Discovery is already started in _initialize()
    } catch (e) {
      state = state.copyWith(
        isDiscovering: false,
        error: 'Failed to start discovery: $e',
      );
    }
  }
  
  Future<void> stopDiscovery() async {
    try {
      await _repository.stopDiscovery();
      state = state.copyWith(isDiscovering: false);
    } catch (e) {
      state = state.copyWith(error: 'Failed to stop discovery: $e');
    }
  }

  Future<void> startPublishing() async {
    if (!FeatureFlags.DISCOVERY_ENABLED) {
      state = state.copyWith(error: 'Discovery is disabled in feature flags');
      return;
    }

    try {
      state = state.copyWith(isPublishing: true, error: null);
      await _repository.startAdvertising();
    } catch (e) {
      state = state.copyWith(
        isPublishing: false,
        error: 'Failed to start publishing: $e',
      );
    }
  }
  
  Future<void> stopPublishing() async {
    try {
      await _repository.stopAdvertising();
      state = state.copyWith(isPublishing: false);
    } catch (e) {
      state = state.copyWith(error: 'Failed to stop publishing: $e');
    }
  }

  Future<bool> connectToDevice(Device device) async {
    try {
      final success = await _repository.connectToDevice(device);
      if (success) {
        // Update device connection status
        final devices = state.devices.map((d) {
          if (d.id == device.id) {
            return Device(
              id: d.id,
              name: d.name,
              type: d.type,
              ipAddress: d.ipAddress,
              rssi: d.rssi,
              metadata: d.metadata,
              isConnected: true,
              discoveredAt: d.discoveredAt,
            );
          }
          return d;
        }).toList();
        state = state.copyWith(devices: devices);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: 'Failed to connect to device: $e');
      return false;
    }
  }

  // Note: Device event parsing is now handled by the DiscoveryRepository
  // which provides proper error handling and validation

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

// ==================== Error Boundary Provider ====================

/// Error boundary provider for handling app-wide errors
final errorBoundaryProvider = Provider<ErrorBoundary>((ref) {
  return ErrorBoundary(
    child: const SizedBox.shrink(), // Placeholder child
    onError: (error, stackTrace) {
      // Log error
      debugPrint('App Error: $error');
      debugPrint('Stack trace: $stackTrace');
      
      // Could send to crash reporting service here
    },
  );
});

// ==================== Feature Flag Providers ====================

/// Feature availability provider
final featureAvailabilityProvider = Provider<Map<String, bool>>((ref) {
  return {
    'discovery': FeatureFlags.DISCOVERY_ENABLED,
    'transfer': FeatureFlags.TRANSFER_ENABLED,
    'resume': FeatureFlags.RESUME_ENABLED,
    'encryption': FeatureFlags.ENCRYPTION_ENABLED,
    'media_player': FeatureFlags.MEDIA_PLAYER_ENABLED,
    'file_manager': FeatureFlags.FILE_MANAGER_ENABLED,
    'apk_sharing': FeatureFlags.APK_SHARING_ENABLED,
    'cloud_sync': FeatureFlags.CLOUD_SYNC_ENABLED,
    'video_compression': FeatureFlags.VIDEO_COMPRESSION_ENABLED,
    'phone_replication': FeatureFlags.PHONE_REPLICATION_ENABLED,
    'group_sharing': FeatureFlags.GROUP_SHARING_ENABLED,
  };
});

/// Feature completion provider
final featureCompletionProvider = Provider<Map<String, int>>((ref) {
  return {
    'discovery': FeatureFlags.getFeatureCompletion('discovery'),
    'transfer': FeatureFlags.getFeatureCompletion('transfer'),
    'resume': FeatureFlags.getFeatureCompletion('resume'),
    'encryption': FeatureFlags.getFeatureCompletion('encryption'),
    'media_player': FeatureFlags.getFeatureCompletion('media_player'),
    'file_manager': FeatureFlags.getFeatureCompletion('file_manager'),
    'apk_sharing': FeatureFlags.getFeatureCompletion('apk_sharing'),
    'cloud_sync': FeatureFlags.getFeatureCompletion('cloud_sync'),
    'video_compression': FeatureFlags.getFeatureCompletion('video_compression'),
    'phone_replication': FeatureFlags.getFeatureCompletion('phone_replication'),
    'group_sharing': FeatureFlags.getFeatureCompletion('group_sharing'),
  };
});

// ==================== Transfer Controller ====================
// Note: TransferController is now imported from features/transfer/presentation/providers/transfer_provider.dart
// This removes duplication and uses the repository-based implementation