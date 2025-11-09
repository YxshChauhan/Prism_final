import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/dependency_injection.dart';
import 'package:airlink/core/services/media_player_service.dart';
import 'package:airlink/core/services/file_manager_service.dart' hide SortOrder;
import 'package:airlink/core/services/file_manager_service.dart' as file_manager_service;
import 'package:airlink/core/services/apk_extractor_service.dart' hide ExtractionHistoryItem;
import 'package:airlink/core/services/cloud_sync_service.dart' hide CloudProvider, SyncHistoryItem, SyncStatus, CloudStorageInfo;
import 'package:airlink/core/services/video_compression_service.dart' as video_compression_service;
import 'package:airlink/core/services/phone_replication_service.dart';
import 'package:airlink/core/services/group_sharing_service.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Advanced Features Providers
/// 
/// These providers connect the new advanced services to the UI layer,
/// following the same architectural pattern as the existing providers.



/// Media Player service provider
final mediaPlayerServiceProvider = Provider<MediaPlayerService>((ref) {
  return getIt<MediaPlayerService>();
});

/// File Manager service provider
final fileManagerServiceProvider = Provider<FileManagerService>((ref) {
  return getIt<FileManagerService>();
});

/// APK Extractor service provider
final apkExtractorServiceProvider = Provider<ApkExtractorService>((ref) {
  return getIt<ApkExtractorService>();
});

/// Cloud Sync service provider
final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return getIt<CloudSyncService>();
});

/// Video Compression service provider
final videoCompressionServiceProvider = Provider<video_compression_service.VideoCompressionService>((ref) {
  return getIt<video_compression_service.VideoCompressionService>();
});

/// Phone Replication service provider
final phoneReplicationServiceProvider = Provider<PhoneReplicationService>((ref) {
  return getIt<PhoneReplicationService>();
});

/// Group Sharing service provider
final groupSharingServiceProvider = Provider<GroupSharingService>((ref) {
  return getIt<GroupSharingService>();
});

/// File Manager Providers
final getAllFilesProvider = FutureProvider.family<List<FileItem>, FileSortBy>((ref, sortBy) async {
  final service = ref.watch(fileManagerServiceProvider);
  final sortOrder = ref.watch(fileSortOrderProvider);
  
  // Convert app state SortOrder to service SortOrder
  final serviceSortOrder = sortOrder == SortOrder.ascending 
      ? file_manager_service.SortOrder.ascending 
      : file_manager_service.SortOrder.descending;
  
  final files = await service.getAllFiles();
  
  // Apply sorting to the results
  _sortFileItems(files, sortBy, serviceSortOrder);
  
  return files;
});

final getFilesByCategoryProvider = FutureProvider.family<List<FileItem>, (FileCategory, FileSortBy)>((ref, params) async {
  final (category, sortBy) = params;
  final service = ref.watch(fileManagerServiceProvider);
  final sortOrder = ref.watch(fileSortOrderProvider);
  
  // Convert app state SortOrder to service SortOrder
  final serviceSortOrder = sortOrder == SortOrder.ascending 
      ? file_manager_service.SortOrder.ascending 
      : file_manager_service.SortOrder.descending;
  
  final files = await service.getFilesByCategory(category);
  
  // Apply sorting to the results
  _sortFileItems(files, sortBy, serviceSortOrder);
  
  return files;
});

final getStorageInfoProvider = FutureProvider<StorageInfo>((ref) async {
  final service = ref.watch(fileManagerServiceProvider);
  return await service.getStorageInfo();
});

/// Video Compression Providers
final getVideoFilesProvider = FutureProvider<List<VideoFile>>((ref) async {
  final service = ref.watch(videoCompressionServiceProvider);
  return await service.getVideoFiles();
});

final getActiveCompressionJobsProvider = FutureProvider<List<CompressionJob>>((ref) async {
  final service = ref.watch(videoCompressionServiceProvider);
  final serviceJobs = service.getActiveJobs();
  // Convert service models to app state models
  return serviceJobs.map((job) => CompressionJob(
    id: job.id,
    name: job.id, // Use id as name since service model doesn't have name
    inputPath: job.inputPath,
    outputPath: job.outputPath,
    status: job.status.toString(),
    progress: job.progress,
    createdAt: job.startedAt,
  )).toList();
});

/// APK Sharing Providers
final getExtractedApksProvider = FutureProvider<List<ExtractedApk>>((ref) async {
  final service = ref.watch(apkExtractorServiceProvider);
  return await service.getExtractedApks();
});

/// Cloud Sync Providers
final getCloudProvidersProvider = FutureProvider<List<CloudProvider>>((ref) async {
  final service = ref.watch(cloudSyncServiceProvider);
  final serviceProviders = service.getConnectedProviders();
  
  // Convert service models to app state models with storage info
  final List<CloudProvider> cloudProviders = [];
  
  for (final provider in serviceProviders) {
    int? storageUsed;
    int? storageTotal;
    
    try {
      // Attempt to get storage information for the provider
      final storageInfo = await service.getStorageInfo(provider.type);
      storageUsed = storageInfo.usedSpace;
      storageTotal = storageInfo.totalSpace;
    } catch (e) {
      // Storage info unavailable - provider may not support storage queries
      // or may require additional authentication
      storageUsed = null;
      storageTotal = null;
    }
    
    cloudProviders.add(CloudProvider(
      id: provider.type.toString(),
      name: provider.type.toString(),
      type: provider.type.toString(),
      isConnected: provider.isConnected,
      storageUsed: storageUsed,
      storageTotal: storageTotal,
    ));
  }
  
  return cloudProviders;
});

final getActiveSyncJobsProvider = FutureProvider<List<SyncJob>>((ref) async {
  final service = ref.watch(cloudSyncServiceProvider);
  return await service.getActiveSyncJobs();
});

/// Phone Replication Providers
final getSourceDeviceDataProvider = FutureProvider<SourceDeviceData>((ref) async {
  final service = ref.watch(phoneReplicationServiceProvider);
  return await service.getSourceDeviceData();
});

final getTargetDeviceDataProvider = FutureProvider<TargetDeviceData>((ref) async {
  final service = ref.watch(phoneReplicationServiceProvider);
  return await service.getTargetDeviceData();
});

final getReplicationHistoryProvider = FutureProvider<List<ReplicationHistoryItem>>((ref) async {
  final service = ref.watch(phoneReplicationServiceProvider);
  final serviceHistory = await service.getReplicationHistory();
  // Convert service models to app state models
  return serviceHistory.map((item) => ReplicationHistoryItem(
    id: item.id,
    deviceName: item.deviceName,
    date: item.startedAt,
    status: item.status.toString(),
    dataSize: item.totalBytes,
  )).toList();
});

/// Group Sharing Providers
final getActiveGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final service = ref.watch(groupSharingServiceProvider);
  return await service.getActiveGroups();
});

final getSharingSessionsProvider = FutureProvider<List<SharingSession>>((ref) async {
  final service = ref.watch(groupSharingServiceProvider);
  return await service.getSharingSessions();
});

final getGroupSharingHistoryProvider = FutureProvider<List<GroupSharingHistoryItem>>((ref) async {
  final service = ref.watch(groupSharingServiceProvider);
  return await service.getSharingHistory();
});

/// Group Sharing State
final groupSharingStatusProvider = StateProvider<GroupSharingStatus>((ref) => GroupSharingStatus.idle);

/// Media Player State
final mediaPlayerStateProvider = StateProvider<MediaPlayerState?>((ref) => null);
final currentPlaylistProvider = StateProvider<List<MediaItem>>((ref) => []);
final mediaPlayerVolumeProvider = StateProvider<double>((ref) => 1.0);
final mediaPlayerSpeedProvider = StateProvider<double>((ref) => 1.0);
final isMediaPlayerLoopingProvider = StateProvider<bool>((ref) => false);

/// File Manager State
final currentDirectoryProvider = StateProvider<String>((ref) => '/');
final fileListProvider = StateProvider<List<FileItem>>((ref) => []);
final fileSearchQueryProvider = StateProvider<String>((ref) => '');
final fileSortByProvider = StateProvider<FileSortBy>((ref) => FileSortBy.name);
final fileSortOrderProvider = StateProvider<SortOrder>((ref) => SortOrder.ascending);
final selectedFilesProvider = StateProvider<List<String>>((ref) => []);
final fileManagerViewModeProvider = StateProvider<FileManagerViewMode>((ref) => FileManagerViewMode.list);

/// Favorites State
final favoritesListProvider = StateProvider<List<String>>((ref) => []);

/// APK Extractor State
final installedAppsProvider = StateProvider<List<AppInfo>>((ref) => []);
final extractedApksProvider = StateProvider<Map<String, String>>((ref) => {});
final selectedAppsProvider = StateProvider<List<String>>((ref) => []);
final apkExtractionProgressProvider = StateProvider<Map<String, double>>((ref) => {});

/// Cloud Sync State
final connectedCloudProvidersProvider = StateProvider<List<CloudProvider>>((ref) => []);
final activeSyncJobsProvider = StateProvider<List<SyncStatus>>((ref) => []);
final syncHistoryProvider = FutureProvider<List<SyncHistoryItem>>((ref) async {
  final service = ref.watch(cloudSyncServiceProvider);
  final serviceHistory = await service.getSyncHistory();
  // Convert service models to app state models
  return serviceHistory.map((item) => SyncHistoryItem(
    id: item.id,
    providerName: item.provider.toString(),
    action: item.type.toString(),
    timestamp: item.timestamp,
    status: item.status.toString(),
    fileCount: 0, // Unknown - service model doesn't provide fileCount
  )).toList();
});

/// Video Compression State
final activeCompressionJobsProvider = StateProvider<List<CompressionJob>>((ref) => []);
final compressionHistoryProvider = FutureProvider<List<video_compression_service.CompressionJob>>((ref) async {
  final service = ref.watch(videoCompressionServiceProvider);
  return await service.getCompressionHistory();
});
final compressionPresetsProvider = StateProvider<List<video_compression_service.CompressionPresetInfo>>((ref) => []);



/// Media Player Events
final mediaPlayerEventsProvider = StreamProvider<MediaEvent>((ref) {
  final mediaPlayerService = ref.watch(mediaPlayerServiceProvider);
  return mediaPlayerService.eventStream;
});

/// File Manager Events (if needed)
final fileManagerEventsProvider = StreamProvider<FileManagerEvent>((ref) {
  // File manager doesn't have events yet, but we can add them
  return const Stream.empty();
});

/// APK Extractor Events
final apkExtractorEventsProvider = StreamProvider<ApkEvent>((ref) {
  final apkExtractorService = ref.watch(apkExtractorServiceProvider);
  return apkExtractorService.eventStream;
});

/// Cloud Sync Events
final cloudSyncEventsProvider = StreamProvider<CloudSyncEvent>((ref) {
  final cloudSyncService = ref.watch(cloudSyncServiceProvider);
  return cloudSyncService.eventStream;
});

/// Video Compression Events
final videoCompressionEventsProvider = StreamProvider<video_compression_service.CompressionEvent>((ref) {
  final videoCompressionService = ref.watch(videoCompressionServiceProvider);
  return videoCompressionService.eventStream;
});

// ==================== Future Providers ====================

/// Initialize all advanced services
final initializeAdvancedServicesProvider = FutureProvider<void>((ref) async {
  final mediaPlayerService = ref.watch(mediaPlayerServiceProvider);
  final fileManagerService = ref.watch(fileManagerServiceProvider);
  final apkExtractorService = ref.watch(apkExtractorServiceProvider);
  final cloudSyncService = ref.watch(cloudSyncServiceProvider);
  final videoCompressionService = ref.watch(videoCompressionServiceProvider);
  
  await Future.wait([
    mediaPlayerService.initialize(),
    fileManagerService.initialize(),
    apkExtractorService.initialize(),
    cloudSyncService.initialize(),
    videoCompressionService.initialize(),
  ]);
});

/// Get installed apps
final getInstalledAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final apkExtractorService = ref.watch(apkExtractorServiceProvider);
  final apps = await apkExtractorService.getInstalledApps();
  ref.read(installedAppsProvider.notifier).state = apps;
  return apps;
});

/// Get file list for directory
final getFileListProvider = FutureProvider.family<List<FileItem>, String>((ref, directoryPath) async {
  final fileManagerService = ref.watch(fileManagerServiceProvider);
  final sortBy = ref.watch(fileSortByProvider);
  final sortOrder = ref.watch(fileSortOrderProvider);
  
  // Convert app state SortOrder to service SortOrder
  final serviceSortOrder = sortOrder == SortOrder.ascending 
      ? file_manager_service.SortOrder.ascending 
      : file_manager_service.SortOrder.descending;
  
  final files = await fileManagerService.listFiles(
    directoryPath,
    sortBy: sortBy,
    sortOrder: serviceSortOrder,
  );
  
  ref.read(fileListProvider.notifier).state = files;
  return files;
});

/// Search files
final searchFilesProvider = FutureProvider.family<List<FileItem>, String>((ref, query) async {
  final fileManagerService = ref.watch(fileManagerServiceProvider);
  return await fileManagerService.searchFiles(query: query);
});


/// Get recent files
final getRecentFilesProvider = FutureProvider<List<FileItem>>((ref) async {
  final fileManagerService = ref.watch(fileManagerServiceProvider);
  return await fileManagerService.getRecentFiles();
});

/// Get favorite files
final getFavoritesProvider = FutureProvider<List<FileItem>>((ref) async {
  final fileManagerService = ref.watch(fileManagerServiceProvider);
  return await fileManagerService.getFavorites();
});

final extractionHistoryProvider = FutureProvider<List<ExtractionHistoryItem>>((ref) async {
  final apkExtractorService = ref.watch(apkExtractorServiceProvider);
  final serviceHistory = await apkExtractorService.getExtractionHistory();
  // Convert service models to app state models
  return serviceHistory.map((item) => ExtractionHistoryItem(
    id: item.id,
    appName: item.appName,
    packageName: item.packageName,
    extractedAt: item.extractedAt,
    size: item.fileSize,
    status: 'completed', // Default status since service model doesn't provide it
  )).toList();
});

final getConnectedCloudProvidersProvider = Provider<List<CloudProvider>>((ref) {
  final cloudSyncService = ref.watch(cloudSyncServiceProvider);
  final serviceProviders = cloudSyncService.getConnectedProviders();
  // Convert service models to app state models
  final appStateProviders = serviceProviders.map((provider) => CloudProvider(
    id: provider.type.toString(),
    name: provider.type.toString(),
    type: provider.type.toString(),
    isConnected: provider.isConnected,
    storageUsed: null,
    storageTotal: null,
  )).toList();
  ref.read(connectedCloudProvidersProvider.notifier).state = appStateProviders;
  return appStateProviders;
});

/// Get compression presets
final getCompressionPresetsProvider = FutureProvider<List<video_compression_service.CompressionPresetInfo>>((ref) async {
  final videoCompressionService = ref.watch(videoCompressionServiceProvider);
  final presets = videoCompressionService.getCompressionPresets();
  ref.read(compressionPresetsProvider.notifier).state = presets;
  return presets;
});

// ==================== Action Providers ====================

/// Play media action
final playMediaProvider = Provider.autoDispose.family<Future<void> Function(String, MediaType), String>(
  (ref, filePath) {
    return (String path, MediaType mediaType) async {
      final mediaPlayerService = ref.read(mediaPlayerServiceProvider);
      await mediaPlayerService.play(
        filePath: path,
        mediaType: mediaType,
      );
    };
  },
);

/// Extract APK action
final extractApkProvider = Provider.autoDispose.family<Future<String> Function(), String>(
  (ref, packageName) {
    return () async {
      final apkExtractorService = ref.read(apkExtractorServiceProvider);
      final apkPath = await apkExtractorService.extractApk(packageName);
      
      // Update extracted APKs
      final currentExtracted = ref.read(extractedApksProvider);
      ref.read(extractedApksProvider.notifier).state = {
        ...currentExtracted,
        packageName: apkPath,
      };
      
      return apkPath;
    };
  },
);

/// Connect cloud provider action
final connectCloudProviderAction = Provider.autoDispose.family<Future<bool> Function(), CloudProviderType>(
  (ref, providerType) {
    return () async {
      final cloudSyncService = ref.read(cloudSyncServiceProvider);
      final success = await cloudSyncService.connectProvider(providerType);
      
    if (success) {
      // Refresh connected providers
      ref.invalidate(getConnectedCloudProvidersProvider);
    }
      
      return success;
    };
  },
);

/// Compress video action
final compressVideoProvider = Provider.autoDispose.family<Future<String> Function(String, String, CompressionPreset), String>(
  (ref, jobId) {
    return (String inputPath, String outputPath, CompressionPreset preset) async {
      final videoCompressionService = ref.read(videoCompressionServiceProvider);
      // Convert app_state CompressionPreset to service CompressionPreset
      final servicePreset = _convertPreset(preset.id);
      return await videoCompressionService.compressVideo(
        inputPath: inputPath,
        outputPath: outputPath,
        preset: servicePreset,
      );
    };
  },
);

// ==================== Controller Providers ====================

/// Media Player Controller
final mediaPlayerControllerProvider = Provider<MediaPlayerController>((ref) {
  return MediaPlayerController(ref);
});

/// File Manager Controller
final fileManagerControllerProvider = Provider<FileManagerController>((ref) {
  return FileManagerController(ref);
});

/// APK Extractor Controller
final apkExtractorControllerProvider = Provider<ApkExtractorController>((ref) {
  return ApkExtractorController(ref);
});

/// Cloud Sync Controller
final cloudSyncControllerProvider = Provider<CloudSyncController>((ref) {
  return CloudSyncController(ref);
});

/// Video Compression Controller
final videoCompressionControllerProvider = Provider<VideoCompressionController>((ref) {
  return VideoCompressionController(ref);
});

// ==================== Controller Classes ====================

/// Media Player Controller
class MediaPlayerController {
  final Ref _ref;
  
  MediaPlayerController(this._ref);
  
  Future<void> playMedia(String filePath, MediaType mediaType) async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.play(filePath: filePath, mediaType: mediaType);
  }
  
  Future<void> pauseMedia() async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.pause();
  }
  
  Future<void> resumeMedia() async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.resume();
  }
  
  Future<void> stopMedia() async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.stop();
  }
  
  Future<void> seekTo(Duration position) async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.seek(position);
  }
  
  Future<void> setVolume(double volume) async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.setVolume(volume);
    _ref.read(mediaPlayerVolumeProvider.notifier).state = volume;
  }
  
  Future<void> setPlaybackSpeed(double speed) async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.setPlaybackSpeed(speed);
    _ref.read(mediaPlayerSpeedProvider.notifier).state = speed;
  }
  
  Future<void> setLooping(bool isLooping) async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.setLooping(isLooping);
    _ref.read(isMediaPlayerLoopingProvider.notifier).state = isLooping;
  }
  
  Future<void> loadPlaylist(List<MediaItem> items, {int startIndex = 0}) async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.loadPlaylist(items, startIndex: startIndex);
    _ref.read(currentPlaylistProvider.notifier).state = items;
  }
  
  Future<void> playNext() async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.playNext();
  }
  
  Future<void> playPrevious() async {
    final service = _ref.read(mediaPlayerServiceProvider);
    await service.playPrevious();
  }
  
  MediaPlayerState? getCurrentState() {
    final service = _ref.read(mediaPlayerServiceProvider);
    return service.getState();
  }
}

/// File Manager Controller
class FileManagerController {
  final Ref _ref;
  
  FileManagerController(this._ref);
  
  Future<void> navigateToDirectory(String path) async {
    _ref.read(currentDirectoryProvider.notifier).state = path;
    _ref.invalidate(getFileListProvider(path));
  }
  
  Future<void> searchFiles(String query) async {
    _ref.read(fileSearchQueryProvider.notifier).state = query;
    if (query.isNotEmpty) {
      _ref.invalidate(searchFilesProvider(query));
    }
  }
  
  Future<void> sortFiles(FileSortBy sortBy, SortOrder sortOrder) async {
    _ref.read(fileSortByProvider.notifier).state = sortBy;
    _ref.read(fileSortOrderProvider.notifier).state = sortOrder;
    
    final currentDir = _ref.read(currentDirectoryProvider);
    _ref.invalidate(getFileListProvider(currentDir));
  }
  
  Future<void> copyFile(String sourcePath, String destPath) async {
    final service = _ref.read(fileManagerServiceProvider);
    await service.copyFile(sourcePath, destPath);
    
    // Refresh current directory
    final currentDir = _ref.read(currentDirectoryProvider);
    _ref.invalidate(getFileListProvider(currentDir));
  }
  
  Future<void> moveFile(String sourcePath, String destPath) async {
    final service = _ref.read(fileManagerServiceProvider);
    await service.moveFile(sourcePath, destPath);
    
    // Refresh current directory
    final currentDir = _ref.read(currentDirectoryProvider);
    _ref.invalidate(getFileListProvider(currentDir));
  }
  
  Future<void> deleteFile(String filePath, {bool permanent = false}) async {
    final service = _ref.read(fileManagerServiceProvider);
    await service.deleteFile(filePath, permanent: permanent);
    
    // Refresh current directory
    final currentDir = _ref.read(currentDirectoryProvider);
    _ref.invalidate(getFileListProvider(currentDir));
  }
  
  Future<void> renameFile(String filePath, String newName) async {
    final service = _ref.read(fileManagerServiceProvider);
    await service.renameFile(filePath, newName);
    
    // Refresh current directory
    final currentDir = _ref.read(currentDirectoryProvider);
    _ref.invalidate(getFileListProvider(currentDir));
  }
  
  Future<void> addToFavorites(String filePath) async {
    final service = _ref.read(fileManagerServiceProvider);
    service.addToFavorites(filePath);
  }
  
  Future<void> removeFromFavorites(String filePath) async {
    final service = _ref.read(fileManagerServiceProvider);
    service.removeFromFavorites(filePath);
  }
  
  Future<List<FileItem>> getFavorites() async {
    final service = _ref.read(fileManagerServiceProvider);
    return await service.getFavorites();
  }
  
  Future<List<FileItem>> getRecentFiles({int limit = 20}) async {
    final service = _ref.read(fileManagerServiceProvider);
    return await service.getRecentFiles(limit: limit);
  }
  
  Future<StorageInfo> getStorageInfo() async {
    final service = _ref.read(fileManagerServiceProvider);
    return await service.getStorageInfo();
  }
  
  Future<List<List<FileItem>>> findDuplicates({String? basePath, int minSize = 1024}) async {
    final service = _ref.read(fileManagerServiceProvider);
    return await service.findDuplicates(basePath: basePath, minSize: minSize);
  }
}

/// APK Extractor Controller
class ApkExtractorController {
  final Ref _ref;
  
  ApkExtractorController(this._ref);
  
  Future<void> loadInstalledApps({bool includeSystemApps = false}) async {
    final service = _ref.read(apkExtractorServiceProvider);
    final apps = await service.getInstalledApps(includeSystemApps: includeSystemApps);
    _ref.read(installedAppsProvider.notifier).state = apps;
  }
  
  Future<String> extractApk(String packageName) async {
    final service = _ref.read(apkExtractorServiceProvider);
    final apkPath = await service.extractApk(packageName);
    
    // Update extracted APKs
    final currentExtracted = _ref.read(extractedApksProvider);
    _ref.read(extractedApksProvider.notifier).state = {
      ...currentExtracted,
      packageName: apkPath,
    };
    
    return apkPath;
  }
  
  Future<List<String>> extractMultipleApks(List<String> packageNames) async {
    final service = _ref.read(apkExtractorServiceProvider);
    final extractedPaths = await service.extractMultipleApks(packageNames);
    
    // Update extracted APKs
    final currentExtracted = _ref.read(extractedApksProvider);
    final newExtracted = Map<String, String>.from(currentExtracted);
    
    for (int i = 0; i < packageNames.length; i++) {
      if (i < extractedPaths.length) {
        newExtracted[packageNames[i]] = extractedPaths[i];
      }
    }
    
    _ref.read(extractedApksProvider.notifier).state = newExtracted;
    return extractedPaths;
  }
  
  Future<bool> installApk(String apkPath) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.installApk(apkPath);
  }
  
  Future<bool> uninstallApp(String packageName) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.uninstallApp(packageName);
  }
  
  Future<List<String>> getAppPermissions(String packageName) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.getAppPermissions(packageName);
  }
  
  Future<void> deleteFromHistory(String historyId) async {
    final service = _ref.read(apkExtractorServiceProvider);
    await service.deleteFromHistory(historyId);
  }
  
  Future<bool> isAppInstalled(String packageName) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.isAppInstalled(packageName);
  }
  
  Future<AppVersionInfo> getAppVersionInfo(String packageName) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.getAppVersionInfo(packageName);
  }
  
  Future<String> createAppBackup(String packageName) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.createAppBackup(packageName);
  }
  
  Future<bool> restoreAppFromBackup(String backupPath) async {
    final service = _ref.read(apkExtractorServiceProvider);
    return await service.restoreAppFromBackup(backupPath);
  }
  
  Future<void> clearExtractedApks() async {
    final service = _ref.read(apkExtractorServiceProvider);
    await service.clearExtractedApks();
    _ref.read(extractedApksProvider.notifier).state = {};
  }
}

/// Cloud Sync Controller
class CloudSyncController {
  final Ref _ref;
  
  CloudSyncController(this._ref);
  
  Future<bool> connectProvider(CloudProviderType provider) async {
    final service = _ref.read(cloudSyncServiceProvider);
    final success = await service.connectProvider(provider);
    
    if (success) {
      // Refresh connected providers
      final serviceProviders = service.getConnectedProviders();
      final appStateProviders = serviceProviders.map((sp) => CloudProvider(
        id: sp.type.toString(),
        name: sp.type.toString(),
        type: sp.type.toString(),
        isConnected: sp.isConnected,
        storageUsed: null,
        storageTotal: null,
      )).toList();
      _ref.read(connectedCloudProvidersProvider.notifier).state = appStateProviders;
    }
    
    return success;
  }
  
  Future<void> disconnectProvider(CloudProviderType provider) async {
    final service = _ref.read(cloudSyncServiceProvider);
    await service.disconnectProvider(provider);
    
    // Refresh connected providers
    final serviceProviders = service.getConnectedProviders();
    final appStateProviders = serviceProviders.map((sp) => CloudProvider(
      id: sp.type.toString(),
      name: sp.type.toString(),
      type: sp.type.toString(),
      isConnected: sp.isConnected,
      storageUsed: null,
      storageTotal: null,
    )).toList();
    _ref.read(connectedCloudProvidersProvider.notifier).state = appStateProviders;
  }
  
  Future<String> uploadFile({
    required String localPath,
    required String remotePath,
    required CloudProviderType provider,
    bool overwrite = false,
  }) async {
    final service = _ref.read(cloudSyncServiceProvider);
    return await service.uploadFile(
      localPath: localPath,
      remotePath: remotePath,
      provider: provider,
      overwrite: overwrite,
    );
  }
  
  Future<String> downloadFile({
    required String fileId,
    required String localPath,
    required CloudProviderType provider,
  }) async {
    final service = _ref.read(cloudSyncServiceProvider);
    return await service.downloadFile(
      fileId: fileId,
      localPath: localPath,
      provider: provider,
    );
  }
  
  Future<List<CloudFile>> listFiles({
    required CloudProviderType provider,
    String? folderPath,
    int limit = 100,
  }) async {
    final service = _ref.read(cloudSyncServiceProvider);
    return await service.listFiles(
      provider: provider,
      folderPath: folderPath,
      limit: limit,
    );
  }
  
  Future<String> startTwoWaySync({
    required String localPath,
    required String remotePath,
    required CloudProviderType provider,
    SyncMode mode = SyncMode.automatic,
  }) async {
    final service = _ref.read(cloudSyncServiceProvider);
    final syncId = await service.startTwoWaySync(
      localPath: localPath,
      remotePath: remotePath,
      provider: provider,
      mode: mode,
    );
    
    // Update active sync jobs
    final serviceSyncStatus = service.getSyncStatus(syncId);
    if (serviceSyncStatus != null) {
      final appStateSyncStatus = SyncStatus(
        id: serviceSyncStatus.syncId,
        name: serviceSyncStatus.provider.toString(),
        status: serviceSyncStatus.status.toString(),
        progress: 0.0,
        createdAt: serviceSyncStatus.startedAt,
        localPath: serviceSyncStatus.localPath,
        remotePath: serviceSyncStatus.remotePath,
        filesProcessed: serviceSyncStatus.filesProcessed,
        totalFiles: serviceSyncStatus.totalFiles,
      );
      final currentJobs = _ref.read(activeSyncJobsProvider);
      _ref.read(activeSyncJobsProvider.notifier).state = [...currentJobs, appStateSyncStatus];
    }
    
    return syncId;
  }
  
  Future<void> stopSync(String syncId) async {
    final service = _ref.read(cloudSyncServiceProvider);
    await service.stopSync(syncId);
    
    // Remove from active sync jobs
    final currentJobs = _ref.read(activeSyncJobsProvider);
    _ref.read(activeSyncJobsProvider.notifier).state = 
        currentJobs.where((job) => job.id != syncId).toList();
  }
  
  Future<CloudStorageInfo> getStorageInfo(CloudProviderType provider) async {
    final service = _ref.read(cloudSyncServiceProvider);
    final serviceInfo = await service.getStorageInfo(provider);
    return CloudStorageInfo(
      providerId: provider.toString(),
      totalSpace: serviceInfo.totalSpace,
      usedSpace: serviceInfo.usedSpace,
      freeSpace: serviceInfo.freeSpace,
      usagePercentage: serviceInfo.usagePercentage,
      provider: provider.toString(),
    );
  }
  
  Future<List<SyncHistoryItem>> getSyncHistory({
    CloudProviderType? provider,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    final service = _ref.read(cloudSyncServiceProvider);
    final serviceHistory = await service.getSyncHistory(
      provider: provider,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
    );
    // Convert service models to app state models
    final List<SyncHistoryItem> result = [];
    for (final item in serviceHistory) {
      final fileSize = await _getFileSize(item);
      result.add(SyncHistoryItem(
        id: item.id,
        providerName: item.provider.toString(),
        action: item.type.toString(),
        timestamp: item.timestamp,
        status: item.status.toString(),
        fileCount: _getFileCount(item),
        filePath: item.localPath,
        fileSize: fileSize,
        error: item.errorMessage,
      ));
    }
    return result;
  }

  /// Get file count for sync history item
  /// Since the service model doesn't provide file count directly,
  /// we default to 1 for single file operations
  int _getFileCount(dynamic item) {
    // For single file operations, the count is always 1
    // TODO: If the service model is enhanced to include file count,
    // this should be updated to use item.fileCount or similar field
    return 1;
  }

  /// Get file size for sync history item
  /// Attempts to get size from local file system as fallback
  Future<int> _getFileSize(dynamic item) async {
    try {
      // Try to get file size from local file system
      final file = File(item.localPath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.size;
      }
    } catch (e) {
      // If we can't access the local file, return 0
      // This is a limitation of the current service model
    }
    
    // Fallback to 0 if file size cannot be determined
    // TODO: If the service model is enhanced to include file size,
    // this should be updated to use item.fileSize or similar field
    return 0;
  }
}

/// Video Compression Controller
class VideoCompressionController {
  final Ref _ref;
  
  VideoCompressionController(this._ref);
  
  Future<String> compressVideo({
    required String inputPath,
    required String outputPath,
    required CompressionPreset preset,
  }) async {
    final service = _ref.read(videoCompressionServiceProvider);
    final servicePreset = _convertPreset(preset.id);
    return await service.compressVideo(
      inputPath: inputPath,
      outputPath: outputPath,
      preset: servicePreset,
    );
  }
  
  Future<String> compressVideoCustom({
    required String inputPath,
    required String outputPath,
    required video_compression_service.VideoCompressionSettings settings,
  }) async {
    final service = _ref.read(videoCompressionServiceProvider);
    return await service.compressVideoCustom(
      inputPath: inputPath,
      outputPath: outputPath,
      settings: settings,
    );
  }
  
  Future<video_compression_service.VideoInfo> getVideoInfo(String videoPath) async {
    final service = _ref.read(videoCompressionServiceProvider);
    return await service.getVideoInfo(videoPath);
  }
  
  Future<void> cancelCompression(String jobId) async {
    final service = _ref.read(videoCompressionServiceProvider);
    await service.cancelCompression(jobId);
    
    // Remove from active jobs
    final currentJobs = _ref.read(activeCompressionJobsProvider);
    _ref.read(activeCompressionJobsProvider.notifier).state = 
        currentJobs.where((job) => job.id != jobId).toList();
  }
  
  Future<video_compression_service.CompressionEstimate> estimateCompression({
    required String inputPath,
    required CompressionPreset preset,
  }) async {
    final service = _ref.read(videoCompressionServiceProvider);
    final servicePreset = _convertPreset(preset.id);
    return await service.estimateCompression(
      inputPath: inputPath,
      preset: servicePreset,
    );
  }
  
  Future<List<String>> batchCompress({
    required List<String> inputPaths,
    required String outputDirectory,
    required CompressionPreset preset,
  }) async {
    final service = _ref.read(videoCompressionServiceProvider);
    final servicePreset = _convertPreset(preset.id);
    return await service.batchCompress(
      inputPaths: inputPaths,
      outputDirectory: outputDirectory,
      preset: servicePreset,
    );
  }
  
  Future<List<String>> getSupportedFormats() async {
    final service = _ref.read(videoCompressionServiceProvider);
    return await service.getSupportedFormats();
  }
  
  List<video_compression_service.CompressionPresetInfo> getCompressionPresets() {
    final service = _ref.read(videoCompressionServiceProvider);
    return service.getCompressionPresets();
  }
}

// ==================== Additional Enums ====================

/// File manager view modes
enum FileManagerViewMode {
  list,
  grid,
}

/// File manager event (placeholder for future events)
abstract class FileManagerEvent {
  final String type;
  final DateTime timestamp;
  
  const FileManagerEvent({
    required this.type,
    required this.timestamp,
  });
}

/// Helper function to convert app_state CompressionPreset to service CompressionPreset
video_compression_service.CompressionPreset _convertPreset(String presetId) {
  switch (presetId.toLowerCase()) {
    case 'fast':
      return video_compression_service.CompressionPreset.fast;
    case 'balanced':
      return video_compression_service.CompressionPreset.balanced;
    case 'best':
      return video_compression_service.CompressionPreset.best;
    case 'small':
      return video_compression_service.CompressionPreset.small;
    default:
      return video_compression_service.CompressionPreset.balanced;
  }
}

/// Helper function to sort file items
void _sortFileItems(List<FileItem> items, FileSortBy sortBy, file_manager_service.SortOrder sortOrder) {
  items.sort((a, b) {
    int comparison;
    
    switch (sortBy) {
      case FileSortBy.name:
        comparison = a.name.compareTo(b.name);
        break;
      case FileSortBy.size:
        comparison = a.size.compareTo(b.size);
        break;
      case FileSortBy.date:
        comparison = a.modifiedAt.compareTo(b.modifiedAt);
        break;
      case FileSortBy.modifiedDate:
        comparison = a.modifiedAt.compareTo(b.modifiedAt);
        break;
      case FileSortBy.type:
        comparison = a.extension.compareTo(b.extension);
        break;
    }
    
    return sortOrder == file_manager_service.SortOrder.ascending ? comparison : -comparison;
  });
}
