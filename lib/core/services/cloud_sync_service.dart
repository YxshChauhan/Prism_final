import 'dart:async';
import 'package:flutter/services.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/shared/utils/format_utils.dart';
import 'package:injectable/injectable.dart';

/// Cloud Sync Service
/// Provides cloud storage integration similar to SHAREit/Zapya
/// Supports Google Drive, Dropbox, OneDrive, and iCloud
@injectable
class CloudSyncService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<CloudSyncEvent> _eventController = StreamController<CloudSyncEvent>.broadcast();
  
  // Sync state
  final Map<String, CloudProvider> _connectedProviders = {};
  final Map<String, SyncStatus> _syncStatuses = {};
  
  CloudSyncService({
    required LoggerService logger,
    @Named('cloudSync') required MethodChannel methodChannel,
    @Named('cloudSyncEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize cloud sync service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing cloud sync service...');
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Cloud sync event error: $error'),
      );
      
      _logger.info('Cloud sync service initialized');
    } catch (e) {
      _logger.error('Failed to initialize cloud sync: $e');
      throw CloudSyncException('Failed to initialize: $e');
    }
  }
  
  /// Connect to cloud provider
  Future<bool> connectProvider(CloudProviderType provider) async {
    try {
      _logger.info('Connecting to ${provider.toString().split('.').last}...');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('connectProvider', {
        'provider': provider.toString().split('.').last,
      });
      
      final bool success = result['success'] as bool;
      if (success) {
        _connectedProviders[provider.toString()] = CloudProvider(
          type: provider,
          isConnected: true,
          connectedAt: DateTime.now(),
          accessToken: result['accessToken'] as String?,
          refreshToken: result['refreshToken'] as String?,
        );
        _logger.info('Successfully connected to ${provider.toString().split('.').last}');
      } else {
        _logger.warning('Failed to connect to ${provider.toString().split('.').last}');
      }
      
      return success;
    } catch (e) {
      _logger.error('Failed to connect provider: $e');
      return false;
    }
  }
  
  /// Disconnect from cloud provider
  Future<void> disconnectProvider(CloudProviderType provider) async {
    try {
      _logger.info('Disconnecting from ${provider.toString().split('.').last}...');
      
      await _methodChannel.invokeMethod('disconnectProvider', {
        'provider': provider.toString().split('.').last,
      });
      
      _connectedProviders.remove(provider.toString());
      _logger.info('Disconnected from ${provider.toString().split('.').last}');
    } catch (e) {
      _logger.error('Failed to disconnect provider: $e');
    }
  }
  
  /// Get connected providers
  List<CloudProvider> getConnectedProviders() {
    return _connectedProviders.values.toList();
  }
  
  /// Check if provider is connected
  bool isProviderConnected(CloudProviderType provider) {
    return _connectedProviders.containsKey(provider.toString()) &&
           _connectedProviders[provider.toString()]!.isConnected;
  }
  
  /// Upload file to cloud
  Future<String> uploadFile({
    required String localPath,
    required String remotePath,
    required CloudProviderType provider,
    bool overwrite = false,
    Function(double)? onProgress,
  }) async {
    try {
      _logger.info('Uploading file: $localPath to $remotePath');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('uploadFile', {
        'localPath': localPath,
        'remotePath': remotePath,
        'provider': provider.toString().split('.').last,
        'overwrite': overwrite,
      });
      
      final String fileId = result['fileId'] as String;
      _logger.info('File uploaded successfully: $fileId');
      return fileId;
    } catch (e) {
      _logger.error('Failed to upload file: $e');
      throw CloudSyncException('Failed to upload file: $e');
    }
  }
  
  /// Download file from cloud
  Future<String> downloadFile({
    required String fileId,
    required String localPath,
    required CloudProviderType provider,
    Function(double)? onProgress,
  }) async {
    try {
      _logger.info('Downloading file: $fileId to $localPath');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('downloadFile', {
        'fileId': fileId,
        'localPath': localPath,
        'provider': provider.toString().split('.').last,
      });
      
      final String downloadedPath = result['localPath'] as String;
      _logger.info('File downloaded successfully: $downloadedPath');
      return downloadedPath;
    } catch (e) {
      _logger.error('Failed to download file: $e');
      throw CloudSyncException('Failed to download file: $e');
    }
  }
  
  /// List files in cloud folder
  Future<List<CloudFile>> listFiles({
    required CloudProviderType provider,
    String? folderPath,
    int limit = 100,
    String? nextToken,
  }) async {
    try {
      _logger.info('Listing files from ${provider.toString().split('.').last}');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('listFiles', {
        'provider': provider.toString().split('.').last,
        'folderPath': folderPath,
        'limit': limit,
        'nextToken': nextToken,
      });
      
      final List<dynamic> filesData = result['files'] as List<dynamic>;
      final List<CloudFile> files = filesData.map((data) => CloudFile.fromMap(Map<String, dynamic>.from(data))).toList();
      
      _logger.info('Found ${files.length} files');
      return files;
    } catch (e) {
      _logger.error('Failed to list files: $e');
      return [];
    }
  }
  
  /// Create folder in cloud
  Future<String> createFolder({
    required String folderName,
    required String parentPath,
    required CloudProviderType provider,
  }) async {
    try {
      _logger.info('Creating folder: $folderName in $parentPath');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('createFolder', {
        'folderName': folderName,
        'parentPath': parentPath,
        'provider': provider.toString().split('.').last,
      });
      
      final String folderId = result['folderId'] as String;
      _logger.info('Folder created successfully: $folderId');
      return folderId;
    } catch (e) {
      _logger.error('Failed to create folder: $e');
      throw CloudSyncException('Failed to create folder: $e');
    }
  }
  
  /// Delete file from cloud
  Future<bool> deleteFile({
    required String fileId,
    required CloudProviderType provider,
  }) async {
    try {
      _logger.info('Deleting file: $fileId');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('deleteFile', {
        'fileId': fileId,
        'provider': provider.toString().split('.').last,
      });
      
      final bool success = result['success'] as bool;
      _logger.info('File deletion ${success ? 'successful' : 'failed'}');
      return success;
    } catch (e) {
      _logger.error('Failed to delete file: $e');
      return false;
    }
  }
  
  /// Get file info from cloud
  Future<CloudFile?> getFileInfo({
    required String fileId,
    required CloudProviderType provider,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getFileInfo', {
        'fileId': fileId,
        'provider': provider.toString().split('.').last,
      });
      
      if (result['file'] != null) {
        return CloudFile.fromMap(Map<String, dynamic>.from(result['file']));
      }
      return null;
    } catch (e) {
      _logger.error('Failed to get file info: $e');
      return null;
    }
  }
  
  /// Start two-way sync
  Future<String> startTwoWaySync({
    required String localPath,
    required String remotePath,
    required CloudProviderType provider,
    SyncMode mode = SyncMode.automatic,
    List<String>? includeExtensions,
    List<String>? excludeExtensions,
  }) async {
    try {
      _logger.info('Starting two-way sync: $localPath <-> $remotePath');
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('startTwoWaySync', {
        'localPath': localPath,
        'remotePath': remotePath,
        'provider': provider.toString().split('.').last,
        'mode': mode.toString().split('.').last,
        'includeExtensions': includeExtensions,
        'excludeExtensions': excludeExtensions,
      });
      
      final String syncId = result['syncId'] as String;
      _syncStatuses[syncId] = SyncStatus(
        syncId: syncId,
        status: SyncStatusType.active,
        localPath: localPath,
        remotePath: remotePath,
        provider: provider,
        startedAt: DateTime.now(),
      );
      
      _logger.info('Two-way sync started: $syncId');
      return syncId;
    } catch (e) {
      _logger.error('Failed to start two-way sync: $e');
      throw CloudSyncException('Failed to start two-way sync: $e');
    }
  }
  
  /// Stop sync
  Future<void> stopSync(String syncId) async {
    try {
      _logger.info('Stopping sync: $syncId');
      
      await _methodChannel.invokeMethod('stopSync', {
        'syncId': syncId,
      });
      
      _syncStatuses.remove(syncId);
      _logger.info('Sync stopped: $syncId');
    } catch (e) {
      _logger.error('Failed to stop sync: $e');
    }
  }
  
  /// Get sync status
  SyncStatus? getSyncStatus(String syncId) {
    return _syncStatuses[syncId];
  }
  
  /// Get all sync statuses
  List<SyncStatus> getAllSyncStatuses() {
    return _syncStatuses.values.toList();
  }
  
  /// Resolve sync conflict
  Future<void> resolveConflict({
    required String syncId,
    required String fileId,
    required ConflictResolution resolution,
    String? customPath,
  }) async {
    try {
      _logger.info('Resolving conflict for sync: $syncId, file: $fileId');
      
      await _methodChannel.invokeMethod('resolveConflict', {
        'syncId': syncId,
        'fileId': fileId,
        'resolution': resolution.toString().split('.').last,
        'customPath': customPath,
      });
      
      _logger.info('Conflict resolved successfully');
    } catch (e) {
      _logger.error('Failed to resolve conflict: $e');
      throw CloudSyncException('Failed to resolve conflict: $e');
    }
  }
  
  /// Get storage info
  Future<CloudStorageInfo> getStorageInfo(CloudProviderType provider) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getStorageInfo', {
        'provider': provider.toString().split('.').last,
      });
      
      return CloudStorageInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logger.error('Failed to get storage info: $e');
      throw CloudSyncException('Failed to get storage info: $e');
    }
  }
  
  /// Get sync history
  Future<List<SyncHistoryItem>> getSyncHistory({
    CloudProviderType? provider,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getSyncHistory', {
        'provider': provider?.toString().split('.').last,
        'fromDate': fromDate?.millisecondsSinceEpoch,
        'toDate': toDate?.millisecondsSinceEpoch,
        'limit': limit,
      });
      
      final List<dynamic> historyData = result['history'] as List<dynamic>;
      return historyData.map((data) => SyncHistoryItem.fromMap(Map<String, dynamic>.from(data))).toList();
    } catch (e) {
      _logger.error('Failed to get sync history: $e');
      return [];
    }
  }
  
  /// Stream of cloud sync events
  Stream<CloudSyncEvent> get eventStream => _eventController.stream;
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'syncStarted':
          _eventController.add(SyncStartedEvent.fromMap(eventData));
          break;
        case 'syncCompleted':
          _eventController.add(SyncCompletedEvent.fromMap(eventData));
          break;
        case 'syncFailed':
          _eventController.add(SyncFailedEvent.fromMap(eventData));
          break;
        case 'fileUploaded':
          _eventController.add(FileUploadedEvent.fromMap(eventData));
          break;
        case 'fileDownloaded':
          _eventController.add(FileDownloadedEvent.fromMap(eventData));
          break;
        case 'conflictDetected':
          _eventController.add(ConflictDetectedEvent.fromMap(eventData));
          break;
        case 'error':
          final String error = eventData['error'] as String;
          _eventController.add(CloudSyncErrorEvent(
            error: error,
            timestamp: DateTime.now(),
          ));
          break;
      }
    } catch (e) {
      _logger.error('Failed to handle cloud sync event: $e');
    }
  }
  
  /// Get active sync jobs
  Future<List<SyncJob>> getActiveSyncJobs() async {
    // TODO: Implement active sync jobs retrieval
    return [];
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Cloud provider types
enum CloudProviderType {
  googleDrive,
  dropbox,
  oneDrive,
  iCloud,
}

/// Sync modes
enum SyncMode {
  automatic,
  manual,
  scheduled,
}

/// Conflict resolution strategies
enum ConflictResolution {
  keepLocal,
  keepRemote,
  keepBoth,
  custom,
}

/// Cloud provider model
class CloudProvider {
  final CloudProviderType type;
  final bool isConnected;
  final DateTime connectedAt;
  final String? accessToken;
  final String? refreshToken;
  
  const CloudProvider({
    required this.type,
    required this.isConnected,
    required this.connectedAt,
    this.accessToken,
    this.refreshToken,
  });
}

/// Cloud file model
class CloudFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String mimeType;
  final DateTime createdDate;
  final DateTime modifiedDate;
  final bool isFolder;
  final String? parentId;
  final String? downloadUrl;
  final String? thumbnailUrl;
  
  const CloudFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.createdDate,
    required this.modifiedDate,
    required this.isFolder,
    this.parentId,
    this.downloadUrl,
    this.thumbnailUrl,
  });
  
  factory CloudFile.fromMap(Map<String, dynamic> map) {
    return CloudFile(
      id: map['id'] as String,
      name: map['name'] as String,
      path: map['path'] as String,
      size: map['size'] as int,
      mimeType: map['mimeType'] as String,
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate'] as int),
      modifiedDate: DateTime.fromMillisecondsSinceEpoch(map['modifiedDate'] as int),
      isFolder: map['isFolder'] as bool,
      parentId: map['parentId'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
    );
  }
  
  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Sync status model
class SyncStatus {
  final String syncId;
  final SyncStatusType status;
  final String localPath;
  final String remotePath;
  final CloudProviderType provider;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int filesProcessed;
  final int totalFiles;
  final String? errorMessage;
  
  const SyncStatus({
    required this.syncId,
    required this.status,
    required this.localPath,
    required this.remotePath,
    required this.provider,
    required this.startedAt,
    this.completedAt,
    this.filesProcessed = 0,
    this.totalFiles = 0,
    this.errorMessage,
  });
  
  double get progress {
    if (totalFiles == 0) return 0.0;
    return filesProcessed / totalFiles;
  }
}

/// Sync status types
enum SyncStatusType {
  active,
  paused,
  completed,
  failed,
  cancelled,
}

/// Sync item model
class SyncItem {
  final String id;
  final String localPath;
  final String remotePath;
  final CloudProviderType provider;
  final SyncItemType type;
  final DateTime createdAt;
  final SyncItemStatus status;
  
  const SyncItem({
    required this.id,
    required this.localPath,
    required this.remotePath,
    required this.provider,
    required this.type,
    required this.createdAt,
    required this.status,
  });
}

/// Sync item types
enum SyncItemType {
  upload,
  download,
  delete,
  update,
}

/// Sync item status
enum SyncItemStatus {
  pending,
  inProgress,
  completed,
  failed,
}

/// Cloud storage info model
class CloudStorageInfo {
  final CloudProviderType provider;
  final int totalSpace;
  final int usedSpace;
  final int freeSpace;
  final double usagePercentage;
  
  const CloudStorageInfo({
    required this.provider,
    required this.totalSpace,
    required this.usedSpace,
    required this.freeSpace,
    required this.usagePercentage,
  });
  
  factory CloudStorageInfo.fromMap(Map<String, dynamic> map) {
    return CloudStorageInfo(
      provider: CloudProviderType.values.firstWhere(
        (e) => e.toString().split('.').last == map['provider'] as String,
      ),
      totalSpace: map['totalSpace'] as int,
      usedSpace: map['usedSpace'] as int,
      freeSpace: map['freeSpace'] as int,
      usagePercentage: (map['usagePercentage'] as num).toDouble(),
    );
  }
  
  String get totalSpaceFormatted => FormatUtils.formatBytes(totalSpace);
  String get usedSpaceFormatted => FormatUtils.formatBytes(usedSpace);
  String get freeSpaceFormatted => FormatUtils.formatBytes(freeSpace);
}

/// Sync history item model
class SyncHistoryItem {
  final String id;
  final String syncId;
  final String fileName;
  final String localPath;
  final String remotePath;
  final CloudProviderType provider;
  final SyncItemType type;
  final SyncItemStatus status;
  final DateTime timestamp;
  final String? errorMessage;
  
  const SyncHistoryItem({
    required this.id,
    required this.syncId,
    required this.fileName,
    required this.localPath,
    required this.remotePath,
    required this.provider,
    required this.type,
    required this.status,
    required this.timestamp,
    this.errorMessage,
  });
  
  factory SyncHistoryItem.fromMap(Map<String, dynamic> map) {
    return SyncHistoryItem(
      id: map['id'] as String,
      syncId: map['syncId'] as String,
      fileName: map['fileName'] as String,
      localPath: map['localPath'] as String,
      remotePath: map['remotePath'] as String,
      provider: CloudProviderType.values.firstWhere(
        (e) => e.toString().split('.').last == map['provider'] as String,
      ),
      type: SyncItemType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'] as String,
      ),
      status: SyncItemStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

/// Cloud sync event base class
abstract class CloudSyncEvent {
  final String type;
  final DateTime timestamp;
  
  const CloudSyncEvent({
    required this.type,
    required this.timestamp,
  });
}

class SyncStartedEvent extends CloudSyncEvent {
  final String syncId;
  final String localPath;
  final String remotePath;
  final CloudProviderType provider;
  
  const SyncStartedEvent({
    required this.syncId,
    required this.localPath,
    required this.remotePath,
    required this.provider,
    required super.timestamp,
  }) : super(type: 'syncStarted');
  
  factory SyncStartedEvent.fromMap(Map<String, dynamic> map) {
    return SyncStartedEvent(
      syncId: map['syncId'] as String,
      localPath: map['localPath'] as String,
      remotePath: map['remotePath'] as String,
      provider: CloudProviderType.values.firstWhere(
        (e) => e.toString().split('.').last == map['provider'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class SyncCompletedEvent extends CloudSyncEvent {
  final String syncId;
  final int filesProcessed;
  
  const SyncCompletedEvent({
    required this.syncId,
    required this.filesProcessed,
    required super.timestamp,
  }) : super(type: 'syncCompleted');
  
  factory SyncCompletedEvent.fromMap(Map<String, dynamic> map) {
    return SyncCompletedEvent(
      syncId: map['syncId'] as String,
      filesProcessed: map['filesProcessed'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class SyncFailedEvent extends CloudSyncEvent {
  final String syncId;
  final String error;
  
  const SyncFailedEvent({
    required this.syncId,
    required this.error,
    required super.timestamp,
  }) : super(type: 'syncFailed');
  
  factory SyncFailedEvent.fromMap(Map<String, dynamic> map) {
    return SyncFailedEvent(
      syncId: map['syncId'] as String,
      error: map['error'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class FileUploadedEvent extends CloudSyncEvent {
  final String fileId;
  final String fileName;
  final String remotePath;
  
  const FileUploadedEvent({
    required this.fileId,
    required this.fileName,
    required this.remotePath,
    required super.timestamp,
  }) : super(type: 'fileUploaded');
  
  factory FileUploadedEvent.fromMap(Map<String, dynamic> map) {
    return FileUploadedEvent(
      fileId: map['fileId'] as String,
      fileName: map['fileName'] as String,
      remotePath: map['remotePath'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class FileDownloadedEvent extends CloudSyncEvent {
  final String fileId;
  final String fileName;
  final String localPath;
  
  const FileDownloadedEvent({
    required this.fileId,
    required this.fileName,
    required this.localPath,
    required super.timestamp,
  }) : super(type: 'fileDownloaded');
  
  factory FileDownloadedEvent.fromMap(Map<String, dynamic> map) {
    return FileDownloadedEvent(
      fileId: map['fileId'] as String,
      fileName: map['fileName'] as String,
      localPath: map['localPath'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class ConflictDetectedEvent extends CloudSyncEvent {
  final String syncId;
  final String fileId;
  final String fileName;
  final String localPath;
  final String remotePath;
  
  const ConflictDetectedEvent({
    required this.syncId,
    required this.fileId,
    required this.fileName,
    required this.localPath,
    required this.remotePath,
    required super.timestamp,
  }) : super(type: 'conflictDetected');
  
  factory ConflictDetectedEvent.fromMap(Map<String, dynamic> map) {
    return ConflictDetectedEvent(
      syncId: map['syncId'] as String,
      fileId: map['fileId'] as String,
      fileName: map['fileName'] as String,
      localPath: map['localPath'] as String,
      remotePath: map['remotePath'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CloudSyncErrorEvent extends CloudSyncEvent {
  final String error;
  
  const CloudSyncErrorEvent({
    required this.error,
    required super.timestamp,
  }) : super(type: 'error');
}

/// Cloud sync exception
class CloudSyncException implements Exception {
  final String message;
  const CloudSyncException(this.message);
  
  @override
  String toString() => 'CloudSyncException: $message';
}
