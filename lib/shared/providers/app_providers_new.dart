import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/dependency_injection.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/core/constants/feature_flags.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:airlink/features/transfer/domain/repositories/transfer_repository.dart';

/// Global app state providers with proper architecture

// ==================== App State ====================

/// Current app page
final currentPageProvider = StateProvider<AppPage>((ref) => AppPage.home);

/// App theme mode
final appThemeProvider = StateProvider<ThemeMode>((ref) => 
    FeatureFlags.DARK_MODE_ENABLED ? ThemeMode.system : ThemeMode.light);

/// App initialization state
final appInitializedProvider = StateProvider<bool>((ref) => false);

// ==================== Discovery State ====================

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

// ==================== Transfer State ====================

/// Transfer controller using repository pattern
/// TODO: Implement TransferController that extends StateNotifier<TransferState>
// final transferControllerProvider = StateNotifierProvider<TransferController, TransferState>((ref) {
//   final repository = ref.watch(transferRepositoryProvider);
//   return TransferController(repository);
// });

/// Selected files for transfer
final selectedFilesProvider = StateProvider<List<TransferFile>>((ref) => []);

/// Active transfers
/// TODO: Uncomment when TransferController is implemented
// final activeTransfersProvider = Provider<List<TransferSession>>((ref) {
//   final state = ref.watch(transferControllerProvider);
//   return state.activeTransfers;
// });

/// Transfer history
/// TODO: Uncomment when TransferController is implemented
// final transferHistoryProvider = Provider<List<TransferSession>>((ref) {
//   final state = ref.watch(transferControllerProvider);
//   return state.completedTransfers;
// });

/// Current transfer progress
/// TODO: Uncomment when TransferController is implemented
// final transferProgressProvider = Provider<Map<String, TransferProgress>>((ref) {
//   final state = ref.watch(transferControllerProvider);
//   return state.transferProgress;
// });

// ==================== Repository Providers ====================

/// Discovery repository provider
final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return getIt<DiscoveryRepository>();
});

/// Transfer repository provider
final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return getIt<TransferRepository>();
});

// ==================== Platform Channel Providers ====================

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
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  DiscoveryController(this._repository) : super(const DiscoveryState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // TODO: Implement initialize in DiscoveryRepository if needed
      // await _repository.initialize();
      // _eventSubscription = _repository.eventStream.listen(_handleEvent);
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  

  Future<void> startDiscovery() async {
    if (!FeatureFlags.DISCOVERY_ENABLED) {
      state = state.copyWith(error: 'Discovery is disabled in feature flags');
      return;
    }

    try {
      state = state.copyWith(isDiscovering: true, error: null);
      _repository.startDiscovery();
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
      // TODO: Implement startPublishing in DiscoveryRepository if needed
      // await _repository.startPublishing();
    } catch (e) {
      state = state.copyWith(
        isPublishing: false,
        error: 'Failed to start publishing: $e',
      );
    }
  }

  Future<void> stopPublishing() async {
    try {
      // TODO: Implement stopPublishing in DiscoveryRepository if needed
      // await _repository.stopPublishing();
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
              discoveredAt: d.discoveredAt,
              isConnected: true,
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
    child: Container(), // Placeholder child
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
