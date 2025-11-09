import 'dart:async';
import 'package:flutter/services.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';

/// Phone replication service for complete device data transfer
/// Implements SHAREit/Zapya style phone replication functionality
@injectable
class PhoneReplicationService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<PhoneReplicationEvent> _eventController = StreamController<PhoneReplicationEvent>.broadcast();
  
  bool _isInitialized = false;
  bool _isReplicating = false;
  String? _currentReplicationId;
  ReplicationStatus? _currentStatus;
  
  PhoneReplicationService({
    required LoggerService logger,
    @Named('phoneReplication') required MethodChannel methodChannel,
    @Named('phoneReplicationEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize phone replication service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.info('Initializing phone replication service...');
      
      // Check if phone replication is supported
      final bool isSupported = await _methodChannel.invokeMethod('isPhoneReplicationSupported');
      if (!isSupported) {
        throw PhoneReplicationException('Phone replication is not supported on this device');
      }
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Phone replication event error: $error'),
      );
      
      _isInitialized = true;
      _logger.info('Phone replication service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize phone replication service: $e');
      throw PhoneReplicationException('Failed to initialize phone replication: $e');
    }
  }
  
  /// Start phone replication (send all data to target device)
  Future<String> startReplication({
    required String targetDeviceId,
    required List<ReplicationCategory> categories,
    String? customName,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isReplicating) {
      throw PhoneReplicationException('Phone replication is already in progress');
    }
    
    try {
      _logger.info('Starting phone replication to device: $targetDeviceId');
      
      final String replicationId = await _methodChannel.invokeMethod('startReplication', {
        'targetDeviceId': targetDeviceId,
        'categories': categories.map((c) => c.toString().split('.').last).toList(),
        'customName': customName,
        'includeSystemData': true,
        'includeUserData': true,
        'includeAppData': true,
      });
      
      _currentReplicationId = replicationId;
      _isReplicating = true;
      _currentStatus = ReplicationStatus.started;
      
      _logger.info('Phone replication started: $replicationId');
      return replicationId;
    } catch (e) {
      _logger.error('Failed to start phone replication: $e');
      throw PhoneReplicationException('Failed to start phone replication: $e');
    }
  }
  
  /// Receive phone replication (receive all data from source device)
  Future<String> receiveReplication({
    required String sourceDeviceId,
    required String savePath,
    List<ReplicationCategory>? filterCategories,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isReplicating) {
      throw PhoneReplicationException('Phone replication is already in progress');
    }
    
    try {
      _logger.info('Starting phone replication reception from device: $sourceDeviceId');
      
      final String replicationId = await _methodChannel.invokeMethod('receiveReplication', {
        'sourceDeviceId': sourceDeviceId,
        'savePath': savePath,
        'filterCategories': filterCategories?.map((c) => c.toString().split('.').last).toList(),
        'autoInstall': true,
        'mergeData': true,
      });
      
      _currentReplicationId = replicationId;
      _isReplicating = true;
      _currentStatus = ReplicationStatus.receiving;
      
      _logger.info('Phone replication reception started: $replicationId');
      return replicationId;
    } catch (e) {
      _logger.error('Failed to start phone replication reception: $e');
      throw PhoneReplicationException('Failed to start phone replication reception: $e');
    }
  }
  
  /// Cancel current phone replication
  Future<void> cancelReplication() async {
    if (!_isReplicating || _currentReplicationId == null) return;
    
    try {
      _logger.info('Cancelling phone replication: $_currentReplicationId');
      await _methodChannel.invokeMethod('cancelReplication', {
        'replicationId': _currentReplicationId,
      });
      
      _isReplicating = false;
      _currentReplicationId = null;
      _currentStatus = ReplicationStatus.cancelled;
      
      _logger.info('Phone replication cancelled');
    } catch (e) {
      _logger.error('Failed to cancel phone replication: $e');
    }
  }
  
  /// Get replication progress
  Future<ReplicationProgress> getReplicationProgress(String replicationId) async {
    try {
      final Map<String, dynamic> progress = await _methodChannel.invokeMethod('getReplicationProgress', {
        'replicationId': replicationId,
      });
      
      return ReplicationProgress.fromMap(progress);
    } catch (e) {
      _logger.error('Failed to get replication progress: $e');
      throw PhoneReplicationException('Failed to get replication progress: $e');
    }
  }
  
  /// Get device data summary
  Future<DeviceDataSummary> getDeviceDataSummary() async {
    try {
      _logger.info('Getting device data summary...');
      final Map<String, dynamic> summary = await _methodChannel.invokeMethod('getDeviceDataSummary');
      return DeviceDataSummary.fromMap(summary);
    } catch (e) {
      _logger.error('Failed to get device data summary: $e');
      throw PhoneReplicationException('Failed to get device data summary: $e');
    }
  }
  
  /// Get replication history
  Future<List<ReplicationHistory>> getReplicationHistory() async {
    try {
      final List<dynamic> history = await _methodChannel.invokeMethod('getReplicationHistory');
      return history.map((item) => ReplicationHistory.fromMap(item)).toList();
    } catch (e) {
      _logger.error('Failed to get replication history: $e');
      return [];
    }
  }
  
  /// Clear replication history
  Future<void> clearReplicationHistory() async {
    try {
      _logger.info('Clearing replication history...');
      await _methodChannel.invokeMethod('clearReplicationHistory');
      _logger.info('Replication history cleared');
    } catch (e) {
      _logger.error('Failed to clear replication history: $e');
    }
  }
  
  /// Get current replication status
  ReplicationStatus? getCurrentStatus() => _currentStatus;
  
  /// Check if replication is in progress
  bool get isReplicating => _isReplicating;
  
  /// Get current replication ID
  String? get currentReplicationId => _currentReplicationId;
  
  /// Stream of phone replication events
  Stream<PhoneReplicationEvent> get eventStream => _eventController.stream;
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'replicationStarted':
          _eventController.add(ReplicationStartedEvent.fromMap(eventData));
          break;
        case 'replicationProgress':
          _eventController.add(ReplicationProgressEvent.fromMap(eventData));
          break;
        case 'replicationComplete':
          _eventController.add(ReplicationCompleteEvent.fromMap(eventData));
          break;
        case 'replicationFailed':
          _eventController.add(ReplicationFailedEvent.fromMap(eventData));
          break;
        case 'replicationCancelled':
          _eventController.add(ReplicationCancelledEvent.fromMap(eventData));
          break;
        case 'categoryProgress':
          _eventController.add(CategoryProgressEvent.fromMap(eventData));
          break;
        case 'fileProgress':
          _eventController.add(FileProgressEvent.fromMap(eventData));
          break;
        default:
          _logger.warning('Unknown phone replication event type: $eventType');
      }
    } catch (e) {
      _logger.error('Failed to handle phone replication event: $e');
    }
  }
  
  /// Get source device data
  Future<SourceDeviceData> getSourceDeviceData() async {
    // TODO: Implement source device data retrieval
    return SourceDeviceData(
      deviceInfo: DeviceInfo(
        deviceName: 'Source Device',
        model: 'Android Device',
        osVersion: 'Android 13',
        totalStorage: 0,
        availableStorage: 0,
        batteryLevel: 100,
      ),
      categories: [],
      storageInfo: StorageInfo(
        totalSpace: 0,
        usedSpace: 0,
        freeSpace: 0,
        usagePercentage: 0.0,
        categoryBreakdown: {},
      ),
    );
  }

  /// Get target device data
  Future<TargetDeviceData> getTargetDeviceData() async {
    // TODO: Implement target device data retrieval
    return TargetDeviceData(
      deviceInfo: DeviceInfo(
        deviceName: 'Target Device',
        model: 'Android Device',
        osVersion: 'Android 13',
        totalStorage: 0,
        availableStorage: 0,
        batteryLevel: 100,
      ),
    );
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Replication categories
enum ReplicationCategory {
  contacts,
  messages,
  callLogs,
  photos,
  videos,
  music,
  documents,
  apps,
  settings,
  wifi,
  bluetooth,
  calendar,
  notes,
  bookmarks,
  passwords,
  systemData,
}

/// Replication status
enum ReplicationStatus {
  idle,
  started,
  receiving,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Device data summary model
class DeviceDataSummary {
  final int totalContacts;
  final int totalMessages;
  final int totalCallLogs;
  final int totalPhotos;
  final int totalVideos;
  final int totalMusic;
  final int totalDocuments;
  final int totalApps;
  final int totalSize;
  final Map<ReplicationCategory, int> categorySizes;
  
  const DeviceDataSummary({
    required this.totalContacts,
    required this.totalMessages,
    required this.totalCallLogs,
    required this.totalPhotos,
    required this.totalVideos,
    required this.totalMusic,
    required this.totalDocuments,
    required this.totalApps,
    required this.totalSize,
    required this.categorySizes,
  });
  
  factory DeviceDataSummary.fromMap(Map<String, dynamic> map) {
    return DeviceDataSummary(
      totalContacts: map['totalContacts'] as int,
      totalMessages: map['totalMessages'] as int,
      totalCallLogs: map['totalCallLogs'] as int,
      totalPhotos: map['totalPhotos'] as int,
      totalVideos: map['totalVideos'] as int,
      totalMusic: map['totalMusic'] as int,
      totalDocuments: map['totalDocuments'] as int,
      totalApps: map['totalApps'] as int,
      totalSize: map['totalSize'] as int,
      categorySizes: Map<ReplicationCategory, int>.from(
        (map['categorySizes'] as Map).map(
          (key, value) => MapEntry(
            ReplicationCategory.values.firstWhere(
              (e) => e.toString().split('.').last == key as String,
            ),
            value as int,
          ),
        ),
      ),
    );
  }
}

/// Replication progress model
class ReplicationProgress {
  final String replicationId;
  final ReplicationStatus status;
  final int totalFiles;
  final int completedFiles;
  final int totalBytes;
  final int completedBytes;
  final double speed;
  final DateTime startedAt;
  final DateTime? estimatedCompletion;
  final Map<ReplicationCategory, CategoryProgress> categoryProgress;
  
  const ReplicationProgress({
    required this.replicationId,
    required this.status,
    required this.totalFiles,
    required this.completedFiles,
    required this.totalBytes,
    required this.completedBytes,
    required this.speed,
    required this.startedAt,
    this.estimatedCompletion,
    required this.categoryProgress,
  });
  
  factory ReplicationProgress.fromMap(Map<String, dynamic> map) {
    return ReplicationProgress(
      replicationId: map['replicationId'] as String,
      status: ReplicationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'] as String,
      ),
      totalFiles: map['totalFiles'] as int,
      completedFiles: map['completedFiles'] as int,
      totalBytes: map['totalBytes'] as int,
      completedBytes: map['completedBytes'] as int,
      speed: (map['speed'] as num).toDouble(),
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      estimatedCompletion: map['estimatedCompletion'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['estimatedCompletion'] as int)
          : null,
      categoryProgress: Map<ReplicationCategory, CategoryProgress>.from(
        (map['categoryProgress'] as Map).map(
          (key, value) => MapEntry(
            ReplicationCategory.values.firstWhere(
              (e) => e.toString().split('.').last == key as String,
            ),
            CategoryProgress.fromMap(value as Map<String, dynamic>),
          ),
        ),
      ),
    );
  }
}

/// Category progress model
class CategoryProgress {
  final ReplicationCategory category;
  final int totalFiles;
  final int completedFiles;
  final int totalBytes;
  final int completedBytes;
  final double progress;
  
  const CategoryProgress({
    required this.category,
    required this.totalFiles,
    required this.completedFiles,
    required this.totalBytes,
    required this.completedBytes,
    required this.progress,
  });
  
  factory CategoryProgress.fromMap(Map<String, dynamic> map) {
    return CategoryProgress(
      category: ReplicationCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'] as String,
      ),
      totalFiles: map['totalFiles'] as int,
      completedFiles: map['completedFiles'] as int,
      totalBytes: map['totalBytes'] as int,
      completedBytes: map['completedBytes'] as int,
      progress: (map['progress'] as num).toDouble(),
    );
  }
}

/// Replication history model
class ReplicationHistory {
  final String id;
  final String deviceId;
  final String deviceName;
  final ReplicationStatus status;
  final List<ReplicationCategory> categories;
  final int totalFiles;
  final int totalBytes;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration? duration;
  
  const ReplicationHistory({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.categories,
    required this.totalFiles,
    required this.totalBytes,
    required this.startedAt,
    this.completedAt,
    this.duration,
  });
  
  factory ReplicationHistory.fromMap(Map<String, dynamic> map) {
    return ReplicationHistory(
      id: map['id'] as String,
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      status: ReplicationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'] as String,
      ),
      categories: (map['categories'] as List)
          .map((c) => ReplicationCategory.values.firstWhere(
                (e) => e.toString().split('.').last == c as String,
              ))
          .toList(),
      totalFiles: map['totalFiles'] as int,
      totalBytes: map['totalBytes'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      duration: map['duration'] != null
          ? Duration(milliseconds: map['duration'] as int)
          : null,
    );
  }
}

/// Phone replication event base class
abstract class PhoneReplicationEvent {
  final String type;
  final DateTime timestamp;
  
  const PhoneReplicationEvent({
    required this.type,
    required this.timestamp,
  });
}

class ReplicationStartedEvent extends PhoneReplicationEvent {
  final String replicationId;
  final String deviceId;
  final String deviceName;
  final List<ReplicationCategory> categories;
  
  const ReplicationStartedEvent({
    required this.replicationId,
    required this.deviceId,
    required this.deviceName,
    required this.categories,
    required super.timestamp,
  }) : super(type: 'replicationStarted');
  
  factory ReplicationStartedEvent.fromMap(Map<String, dynamic> map) {
    return ReplicationStartedEvent(
      replicationId: map['replicationId'] as String,
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      categories: (map['categories'] as List)
          .map((c) => ReplicationCategory.values.firstWhere(
                (e) => e.toString().split('.').last == c as String,
              ))
          .toList(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class ReplicationProgressEvent extends PhoneReplicationEvent {
  final String replicationId;
  final int totalFiles;
  final int completedFiles;
  final int totalBytes;
  final int completedBytes;
  final double speed;
  final double progress;
  
  const ReplicationProgressEvent({
    required this.replicationId,
    required this.totalFiles,
    required this.completedFiles,
    required this.totalBytes,
    required this.completedBytes,
    required this.speed,
    required this.progress,
    required super.timestamp,
  }) : super(type: 'replicationProgress');
  
  factory ReplicationProgressEvent.fromMap(Map<String, dynamic> map) {
    return ReplicationProgressEvent(
      replicationId: map['replicationId'] as String,
      totalFiles: map['totalFiles'] as int,
      completedFiles: map['completedFiles'] as int,
      totalBytes: map['totalBytes'] as int,
      completedBytes: map['completedBytes'] as int,
      speed: (map['speed'] as num).toDouble(),
      progress: (map['progress'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class ReplicationCompleteEvent extends PhoneReplicationEvent {
  final String replicationId;
  final String deviceId;
  final int totalFiles;
  final int totalBytes;
  final Duration duration;
  
  const ReplicationCompleteEvent({
    required this.replicationId,
    required this.deviceId,
    required this.totalFiles,
    required this.totalBytes,
    required this.duration,
    required super.timestamp,
  }) : super(type: 'replicationComplete');
  
  factory ReplicationCompleteEvent.fromMap(Map<String, dynamic> map) {
    return ReplicationCompleteEvent(
      replicationId: map['replicationId'] as String,
      deviceId: map['deviceId'] as String,
      totalFiles: map['totalFiles'] as int,
      totalBytes: map['totalBytes'] as int,
      duration: Duration(milliseconds: map['duration'] as int),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class ReplicationFailedEvent extends PhoneReplicationEvent {
  final String replicationId;
  final String deviceId;
  final String error;
  final String? errorCode;
  
  const ReplicationFailedEvent({
    required this.replicationId,
    required this.deviceId,
    required this.error,
    this.errorCode,
    required super.timestamp,
  }) : super(type: 'replicationFailed');
  
  factory ReplicationFailedEvent.fromMap(Map<String, dynamic> map) {
    return ReplicationFailedEvent(
      replicationId: map['replicationId'] as String,
      deviceId: map['deviceId'] as String,
      error: map['error'] as String,
      errorCode: map['errorCode'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class ReplicationCancelledEvent extends PhoneReplicationEvent {
  final String replicationId;
  final String deviceId;
  
  const ReplicationCancelledEvent({
    required this.replicationId,
    required this.deviceId,
    required super.timestamp,
  }) : super(type: 'replicationCancelled');
  
  factory ReplicationCancelledEvent.fromMap(Map<String, dynamic> map) {
    return ReplicationCancelledEvent(
      replicationId: map['replicationId'] as String,
      deviceId: map['deviceId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CategoryProgressEvent extends PhoneReplicationEvent {
  final String replicationId;
  final ReplicationCategory category;
  final int totalFiles;
  final int completedFiles;
  final double progress;
  
  const CategoryProgressEvent({
    required this.replicationId,
    required this.category,
    required this.totalFiles,
    required this.completedFiles,
    required this.progress,
    required super.timestamp,
  }) : super(type: 'categoryProgress');
  
  factory CategoryProgressEvent.fromMap(Map<String, dynamic> map) {
    return CategoryProgressEvent(
      replicationId: map['replicationId'] as String,
      category: ReplicationCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'] as String,
      ),
      totalFiles: map['totalFiles'] as int,
      completedFiles: map['completedFiles'] as int,
      progress: (map['progress'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class FileProgressEvent extends PhoneReplicationEvent {
  final String replicationId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final int bytesTransferred;
  final double progress;
  
  const FileProgressEvent({
    required this.replicationId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.bytesTransferred,
    required this.progress,
    required super.timestamp,
  }) : super(type: 'fileProgress');
  
  factory FileProgressEvent.fromMap(Map<String, dynamic> map) {
    return FileProgressEvent(
      replicationId: map['replicationId'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      fileSize: map['fileSize'] as int,
      bytesTransferred: map['bytesTransferred'] as int,
      progress: (map['progress'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

/// Phone replication specific exception

class PhoneReplicationException implements Exception {
  final String message;
  const PhoneReplicationException(this.message);
  
  @override
  String toString() => 'PhoneReplicationException: $message';
}
