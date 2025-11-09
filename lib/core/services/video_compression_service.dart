import 'dart:async';
import 'package:flutter/services.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:injectable/injectable.dart';

/// Video Compression Service
/// Provides video compression functionality similar to SHAREit/Zapya
/// Supports various compression presets and formats
@injectable
class VideoCompressionService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<CompressionEvent> _eventController = StreamController<CompressionEvent>.broadcast();
  
  // Active compressions
  final Map<String, CompressionJob> _activeJobs = {};
  
  VideoCompressionService({
    required LoggerService logger,
    @Named('videoCompression') required MethodChannel methodChannel,
    @Named('videoCompressionEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize video compression service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing video compression service...');
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Video compression event error: $error'),
      );
      
      _logger.info('Video compression service initialized');
    } catch (e) {
      _logger.error('Failed to initialize video compression: $e');
      throw VideoCompressionException('Failed to initialize: $e');
    }
  }
  
  /// Compress video with preset
  Future<String> compressVideo({
    required String inputPath,
    required String outputPath,
    required CompressionPreset preset,
    Function(double)? onProgress,
  }) async {
    try {
      _logger.info('Starting video compression: $inputPath');
      
      final String jobId = _generateJobId();
      final CompressionJob job = CompressionJob(
        id: jobId,
        inputPath: inputPath,
        outputPath: outputPath,
        preset: preset,
        status: CompressionStatus.started,
        startedAt: DateTime.now(),
      );
      
      _activeJobs[jobId] = job;
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('compressVideo', {
        'jobId': jobId,
        'inputPath': inputPath,
        'outputPath': outputPath,
        'preset': preset.toString().split('.').last,
      });
      
      final String compressedPath = result['outputPath'] as String;
      
      // Get input and output video info
      final inputInfo = await getVideoInfo(inputPath);
      final outputInfo = await getVideoInfo(compressedPath);
      
      // Update job with completion data
      final completedJob = job.copyWith(
        status: CompressionStatus.completed,
        completedAt: DateTime.now(),
        inputInfo: inputInfo,
        outputInfo: outputInfo,
      );
      
      _activeJobs[jobId] = completedJob;
      
      _logger.info('Video compression completed: $compressedPath');
      return compressedPath;
    } catch (e) {
      _logger.error('Failed to compress video: $e');
      throw VideoCompressionException('Failed to compress video: $e');
    }
  }
  
  /// Compress video with custom settings
  Future<String> compressVideoCustom({
    required String inputPath,
    required String outputPath,
    required VideoCompressionSettings settings,
    Function(double)? onProgress,
  }) async {
    try {
      _logger.info('Starting custom video compression: $inputPath');
      
      final String jobId = _generateJobId();
      final CompressionJob job = CompressionJob(
        id: jobId,
        inputPath: inputPath,
        outputPath: outputPath,
        preset: CompressionPreset.custom,
        status: CompressionStatus.started,
        startedAt: DateTime.now(),
        customSettings: settings,
      );
      
      _activeJobs[jobId] = job;
      
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('compressVideoCustom', {
        'jobId': jobId,
        'inputPath': inputPath,
        'outputPath': outputPath,
        'settings': settings.toMap(),
      });
      
      final String compressedPath = result['outputPath'] as String;
      
      // Get input and output video info
      final inputInfo = await getVideoInfo(inputPath);
      final outputInfo = await getVideoInfo(compressedPath);
      
      // Update job with completion data
      final completedJob = job.copyWith(
        status: CompressionStatus.completed,
        completedAt: DateTime.now(),
        inputInfo: inputInfo,
        outputInfo: outputInfo,
      );
      
      _activeJobs[jobId] = completedJob;
      
      _logger.info('Custom video compression completed: $compressedPath');
      return compressedPath;
    } catch (e) {
      _logger.error('Failed to compress video with custom settings: $e');
      throw VideoCompressionException('Failed to compress video: $e');
    }
  }
  
  /// Get video info
  Future<VideoInfo> getVideoInfo(String videoPath) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getVideoInfo', {
        'videoPath': videoPath,
      });
      
      return VideoInfo.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logger.error('Failed to get video info: $e');
      throw VideoCompressionException('Failed to get video info: $e');
    }
  }
  
  /// Cancel compression job
  Future<void> cancelCompression(String jobId) async {
    try {
      _logger.info('Cancelling compression job: $jobId');
      
      await _methodChannel.invokeMethod('cancelCompression', {
        'jobId': jobId,
      });
      
      if (_activeJobs.containsKey(jobId)) {
        _activeJobs[jobId] = _activeJobs[jobId]!.copyWith(
          status: CompressionStatus.cancelled,
          completedAt: DateTime.now(),
        );
      }
      
      _logger.info('Compression job cancelled: $jobId');
    } catch (e) {
      _logger.error('Failed to cancel compression: $e');
    }
  }
  
  /// Get compression job status
  CompressionJob? getCompressionJob(String jobId) {
    return _activeJobs[jobId];
  }
  
  /// Get all active compression jobs
  List<CompressionJob> getActiveJobs() {
    return _activeJobs.values.toList();
  }
  
  /// Get compression history
  Future<List<CompressionJob>> getCompressionHistory({
    int limit = 50,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getCompressionHistory', {
        'limit': limit,
        'fromDate': fromDate?.millisecondsSinceEpoch,
        'toDate': toDate?.millisecondsSinceEpoch,
      });
      
      final List<dynamic> historyData = result['history'] as List<dynamic>;
      return historyData.map((data) => CompressionJob.fromMap(Map<String, dynamic>.from(data))).toList();
    } catch (e) {
      _logger.error('Failed to get compression history: $e');
      return [];
    }
  }
  
  /// Estimate compression size
  Future<CompressionEstimate> estimateCompression({
    required String inputPath,
    required CompressionPreset preset,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('estimateCompression', {
        'inputPath': inputPath,
        'preset': preset.toString().split('.').last,
      });
      
      return CompressionEstimate.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logger.error('Failed to estimate compression: $e');
      throw VideoCompressionException('Failed to estimate compression: $e');
    }
  }
  
  /// Batch compress videos
  Future<List<String>> batchCompress({
    required List<String> inputPaths,
    required String outputDirectory,
    required CompressionPreset preset,
    Function(int, int)? onProgress, // (completed, total)
  }) async {
    try {
      _logger.info('Starting batch compression: ${inputPaths.length} videos');
      
      final List<String> compressedPaths = [];
      
      for (int i = 0; i < inputPaths.length; i++) {
        final inputPath = inputPaths[i];
        final fileName = inputPath.split('/').last.split('.').first;
        final outputPath = '$outputDirectory/${fileName}_compressed.mp4';
        
        try {
          final compressedPath = await compressVideo(
            inputPath: inputPath,
            outputPath: outputPath,
            preset: preset,
          );
          compressedPaths.add(compressedPath);
          
          onProgress?.call(i + 1, inputPaths.length);
        } catch (e) {
          _logger.warning('Failed to compress video $inputPath: $e');
        }
      }
      
      _logger.info('Batch compression completed: ${compressedPaths.length}/${inputPaths.length}');
      return compressedPaths;
    } catch (e) {
      _logger.error('Failed to batch compress videos: $e');
      throw VideoCompressionException('Failed to batch compress: $e');
    }
  }
  
  /// Get supported formats
  Future<List<String>> getSupportedFormats() async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getSupportedFormats');
      return List<String>.from(result['formats'] as List<dynamic>);
    } catch (e) {
      _logger.error('Failed to get supported formats: $e');
      return ['mp4', 'avi', 'mkv', 'mov'];
    }
  }
  
  /// Get compression presets
  List<CompressionPresetInfo> getCompressionPresets() {
    return [
      CompressionPresetInfo(
        preset: CompressionPreset.fast,
        name: 'Fast',
        description: 'Quick compression with moderate quality loss',
        compressionRatio: 0.3,
        estimatedTime: '30% of original',
      ),
      CompressionPresetInfo(
        preset: CompressionPreset.balanced,
        name: 'Balanced',
        description: 'Good balance between quality and file size',
        compressionRatio: 0.5,
        estimatedTime: '50% of original',
      ),
      CompressionPresetInfo(
        preset: CompressionPreset.best,
        name: 'Best Quality',
        description: 'Minimal quality loss with good compression',
        compressionRatio: 0.7,
        estimatedTime: '70% of original',
      ),
      CompressionPresetInfo(
        preset: CompressionPreset.small,
        name: 'Small Size',
        description: 'Maximum compression for smallest file size',
        compressionRatio: 0.2,
        estimatedTime: '20% of original',
      ),
    ];
  }
  
  /// Stream of compression events
  Stream<CompressionEvent> get eventStream => _eventController.stream;
  
  String _generateJobId() {
    return 'compression_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'compressionStarted':
          _eventController.add(CompressionStartedEvent.fromMap(eventData));
          break;
        case 'compressionProgress':
          _eventController.add(CompressionProgressEvent.fromMap(eventData));
          break;
        case 'compressionCompleted':
          _eventController.add(CompressionCompletedEvent.fromMap(eventData));
          break;
        case 'compressionFailed':
          _eventController.add(CompressionFailedEvent.fromMap(eventData));
          break;
        case 'compressionCancelled':
          _eventController.add(CompressionCancelledEvent.fromMap(eventData));
          break;
        case 'error':
          final String error = eventData['error'] as String;
          _eventController.add(CompressionErrorEvent(
            error: error,
            timestamp: DateTime.now(),
          ));
          break;
      }
    } catch (e) {
      _logger.error('Failed to handle compression event: $e');
    }
  }
  
  /// Get video files
  Future<List<VideoFile>> getVideoFiles() async {
    // TODO: Implement video files retrieval
    return [];
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Compression presets
enum CompressionPreset {
  fast,
  balanced,
  best,
  small,
  custom,
}

/// Compression status
enum CompressionStatus {
  pending,
  started,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Video compression settings
class VideoCompressionSettings {
  final int? width;
  final int? height;
  final int? bitrate;
  final int? framerate;
  final String? codec;
  final int? quality;
  final bool? removeAudio;
  final String? audioCodec;
  final int? audioBitrate;
  
  const VideoCompressionSettings({
    this.width,
    this.height,
    this.bitrate,
    this.framerate,
    this.codec,
    this.quality,
    this.removeAudio,
    this.audioCodec,
    this.audioBitrate,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
      'bitrate': bitrate,
      'framerate': framerate,
      'codec': codec,
      'quality': quality,
      'removeAudio': removeAudio,
      'audioCodec': audioCodec,
      'audioBitrate': audioBitrate,
    };
  }
}

/// Video info model
class VideoInfo {
  final String path;
  final int width;
  final int height;
  final Duration duration;
  final int bitrate;
  final int framerate;
  final String codec;
  final int fileSize;
  final String? audioCodec;
  final int? audioBitrate;
  final int? audioChannels;
  
  const VideoInfo({
    required this.path,
    required this.width,
    required this.height,
    required this.duration,
    required this.bitrate,
    required this.framerate,
    required this.codec,
    required this.fileSize,
    this.audioCodec,
    this.audioBitrate,
    this.audioChannels,
  });
  
  factory VideoInfo.fromMap(Map<String, dynamic> map) {
    return VideoInfo(
      path: map['path'] as String,
      width: map['width'] as int,
      height: map['height'] as int,
      duration: Duration(milliseconds: map['duration'] as int),
      bitrate: map['bitrate'] as int,
      framerate: map['framerate'] as int,
      codec: map['codec'] as String,
      fileSize: map['fileSize'] as int,
      audioCodec: map['audioCodec'] as String?,
      audioBitrate: map['audioBitrate'] as int?,
      audioChannels: map['audioChannels'] as int?,
    );
  }
  
  String get resolution => '${width}x$height';
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Compression job model
class CompressionJob {
  final String id;
  final String inputPath;
  final String outputPath;
  final CompressionPreset preset;
  final CompressionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double progress;
  final String? errorMessage;
  final VideoCompressionSettings? customSettings;
  final VideoInfo? inputInfo;
  final VideoInfo? outputInfo;
  
  const CompressionJob({
    required this.id,
    required this.inputPath,
    required this.outputPath,
    required this.preset,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.progress = 0.0,
    this.errorMessage,
    this.customSettings,
    this.inputInfo,
    this.outputInfo,
  });
  
  factory CompressionJob.fromMap(Map<String, dynamic> map) {
    return CompressionJob(
      id: map['id'] as String,
      inputPath: map['inputPath'] as String,
      outputPath: map['outputPath'] as String,
      preset: CompressionPreset.values.firstWhere(
        (e) => e.toString().split('.').last == map['preset'] as String,
      ),
      status: CompressionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'] as String,
      ),
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
      completedAt: map['completedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      progress: (map['progress'] as num).toDouble(),
      errorMessage: map['errorMessage'] as String?,
      inputInfo: map['inputInfo'] != null 
          ? VideoInfo.fromMap(Map<String, dynamic>.from(map['inputInfo']))
          : null,
      outputInfo: map['outputInfo'] != null 
          ? VideoInfo.fromMap(Map<String, dynamic>.from(map['outputInfo']))
          : null,
    );
  }
  
  CompressionJob copyWith({
    String? id,
    String? inputPath,
    String? outputPath,
    CompressionPreset? preset,
    CompressionStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    double? progress,
    String? errorMessage,
    VideoCompressionSettings? customSettings,
    VideoInfo? inputInfo,
    VideoInfo? outputInfo,
  }) {
    return CompressionJob(
      id: id ?? this.id,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      preset: preset ?? this.preset,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      customSettings: customSettings ?? this.customSettings,
      inputInfo: inputInfo ?? this.inputInfo,
      outputInfo: outputInfo ?? this.outputInfo,
    );
  }
  
  Duration? get duration {
    if (completedAt == null) return null;
    return completedAt!.difference(startedAt);
  }
  
  bool get isCompleted => status == CompressionStatus.completed;
  bool get isFailed => status == CompressionStatus.failed;
  bool get isCancelled => status == CompressionStatus.cancelled;
  bool get isActive => status == CompressionStatus.started || status == CompressionStatus.inProgress;
}

/// Compression preset info
class CompressionPresetInfo {
  final CompressionPreset preset;
  final String name;
  final String description;
  final double compressionRatio;
  final String estimatedTime;
  
  const CompressionPresetInfo({
    required this.preset,
    required this.name,
    required this.description,
    required this.compressionRatio,
    required this.estimatedTime,
  });
}

/// Compression estimate
class CompressionEstimate {
  final int estimatedSize;
  final Duration estimatedTime;
  final double compressionRatio;
  final String quality;
  
  const CompressionEstimate({
    required this.estimatedSize,
    required this.estimatedTime,
    required this.compressionRatio,
    required this.quality,
  });
  
  factory CompressionEstimate.fromMap(Map<String, dynamic> map) {
    return CompressionEstimate(
      estimatedSize: map['estimatedSize'] as int,
      estimatedTime: Duration(milliseconds: map['estimatedTime'] as int),
      compressionRatio: (map['compressionRatio'] as num).toDouble(),
      quality: map['quality'] as String,
    );
  }
  
  String get estimatedSizeFormatted {
    if (estimatedSize < 1024) return '$estimatedSize B';
    if (estimatedSize < 1024 * 1024) return '${(estimatedSize / 1024).toStringAsFixed(1)} KB';
    if (estimatedSize < 1024 * 1024 * 1024) return '${(estimatedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(estimatedSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String get estimatedTimeFormatted {
    final minutes = estimatedTime.inMinutes;
    final seconds = estimatedTime.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }
}

/// Compression event base class
abstract class CompressionEvent {
  final String type;
  final DateTime timestamp;
  
  const CompressionEvent({
    required this.type,
    required this.timestamp,
  });
}

class CompressionStartedEvent extends CompressionEvent {
  final String jobId;
  final String inputPath;
  final String outputPath;
  
  const CompressionStartedEvent({
    required this.jobId,
    required this.inputPath,
    required this.outputPath,
    required super.timestamp,
  }) : super(type: 'compressionStarted');
  
  factory CompressionStartedEvent.fromMap(Map<String, dynamic> map) {
    return CompressionStartedEvent(
      jobId: map['jobId'] as String,
      inputPath: map['inputPath'] as String,
      outputPath: map['outputPath'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CompressionProgressEvent extends CompressionEvent {
  final String jobId;
  final double progress;
  
  const CompressionProgressEvent({
    required this.jobId,
    required this.progress,
    required super.timestamp,
  }) : super(type: 'compressionProgress');
  
  factory CompressionProgressEvent.fromMap(Map<String, dynamic> map) {
    return CompressionProgressEvent(
      jobId: map['jobId'] as String,
      progress: (map['progress'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CompressionCompletedEvent extends CompressionEvent {
  final String jobId;
  final String outputPath;
  final int originalSize;
  final int compressedSize;
  
  const CompressionCompletedEvent({
    required this.jobId,
    required this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    required super.timestamp,
  }) : super(type: 'compressionCompleted');
  
  factory CompressionCompletedEvent.fromMap(Map<String, dynamic> map) {
    return CompressionCompletedEvent(
      jobId: map['jobId'] as String,
      outputPath: map['outputPath'] as String,
      originalSize: map['originalSize'] as int,
      compressedSize: map['compressedSize'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
  
  double get compressionRatio => compressedSize / originalSize;
  String get sizeReduction => '${((1 - compressionRatio) * 100).toStringAsFixed(1)}%';
}

class CompressionFailedEvent extends CompressionEvent {
  final String jobId;
  final String error;
  
  const CompressionFailedEvent({
    required this.jobId,
    required this.error,
    required super.timestamp,
  }) : super(type: 'compressionFailed');
  
  factory CompressionFailedEvent.fromMap(Map<String, dynamic> map) {
    return CompressionFailedEvent(
      jobId: map['jobId'] as String,
      error: map['error'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CompressionCancelledEvent extends CompressionEvent {
  final String jobId;
  
  const CompressionCancelledEvent({
    required this.jobId,
    required super.timestamp,
  }) : super(type: 'compressionCancelled');
  
  factory CompressionCancelledEvent.fromMap(Map<String, dynamic> map) {
    return CompressionCancelledEvent(
      jobId: map['jobId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class CompressionErrorEvent extends CompressionEvent {
  final String error;
  
  const CompressionErrorEvent({
    required this.error,
    required super.timestamp,
  }) : super(type: 'error');
}

/// Video compression exception
class VideoCompressionException implements Exception {
  final String message;
  const VideoCompressionException(this.message);
  
  @override
  String toString() => 'VideoCompressionException: $message';
}
