import 'package:flutter/material.dart';
import 'package:airlink/shared/utils/format_utils.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;

/// Export AppTheme for backward compatibility
export 'package:airlink/shared/theme/app_constants.dart' show AppTheme;

/// App-wide state models
enum AppPage {
  home,
  send,
  receive,
  history,
  mediaPlayer,
  fileManager,
  apkSharing,
  cloudSync,
  videoCompression,
  phoneReplication,
  groupSharing,
  settings,
}

enum DeviceType {
  android,
  ios,
  desktop,
  windows,
  mac,
  linux,
  unknown,
}

// TransferStatus moved to transfer_models.dart for unification

enum FileType {
  image,
  video,
  document,
  audio,
  other,
}

enum FileCategory {
  video,
  audio,
  image,
  document,
  archive,
  apk,
  other,
}

enum MediaType {
  video,
  audio,
  image,
  unknown,
}

enum FileSortBy {
  name,
  size,
  date,
  modifiedDate,
  type,
}

enum SortOrder {
  ascending,
  descending,
}

enum UIReplicationStatus {
  idle,
  running,
  paused,
  completed,
  failed,
}

enum DataCategoryType {
  apps,
  media,
  contacts,
  settings,
  documents,
}

enum GroupSharingStatus {
  idle,
  sharing,
  receiving,
}

enum SharingSessionStatus {
  active,
  paused,
  completed,
  failed,
}

enum GroupSharingType {
  sent,
  received,
  groupCreated,
  groupJoined,
}

/// Transfer state for managing transfer operations
class TransferState {
  final List<TransferSession> activeTransfers;
  final List<TransferSession> completedTransfers;
  final Map<String, TransferProgress> transferProgress;
  final bool isInitialized;
  final String? error;

  const TransferState({
    this.activeTransfers = const [],
    this.completedTransfers = const [],
    this.transferProgress = const {},
    this.isInitialized = false,
    this.error,
  });

  TransferState copyWith({
    List<TransferSession>? activeTransfers,
    List<TransferSession>? completedTransfers,
    Map<String, TransferProgress>? transferProgress,
    bool? isInitialized,
    String? error,
  }) {
    return TransferState(
      activeTransfers: activeTransfers ?? this.activeTransfers,
      completedTransfers: completedTransfers ?? this.completedTransfers,
      transferProgress: transferProgress ?? this.transferProgress,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
    );
  }
}

/// Device model for discovery
class Device {
  final String id;
  final String name;
  final DeviceType type;
  final String? ipAddress;
  final int? rssi;
  final Map<String, dynamic> metadata;
  final DateTime discoveredAt;
  final bool isConnected;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    this.ipAddress,
    this.rssi,
    this.metadata = const {},
    required this.discoveredAt,
    this.isConnected = false,
  });

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    String? ipAddress,
    int? rssi,
    Map<String, dynamic>? metadata,
    DateTime? discoveredAt,
    bool? isConnected,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ipAddress: ipAddress ?? this.ipAddress,
      rssi: rssi ?? this.rssi,
      metadata: metadata ?? this.metadata,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Device(id: $id, name: $name, type: $type, connected: $isConnected)';
  }
}

/// Transfer file model
class TransferFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String mimeType;
  final String? thumbnailPath;
  final DateTime selectedAt;
  final FileType type;
  final DateTime createdAt;
  final String? checksum;
  final Map<String, dynamic>? metadata;

  const TransferFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    this.thumbnailPath,
    required this.selectedAt,
    required this.type,
    required this.createdAt,
    this.checksum,
    this.metadata,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get fileExtension {
    return name.split('.').last.toLowerCase();
  }

  IconData get fileIcon {
    switch (fileExtension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get fileColor {
    switch (fileExtension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Colors.green;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Colors.purple;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'flac':
        return Colors.orange;
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'txt':
        return Colors.grey;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}

/// Transfer progress model
class TransferProgress {
  final String transferId;
  final String fileName;
  final int bytesTransferred;
  final int totalBytes;
  final double speed; // bytes per second
  final unified.TransferStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? error;

  const TransferProgress({
    required this.transferId,
    required this.fileName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speed,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
  });

  double get progressPercentage {
    if (totalBytes == 0) return 0.0;
    return (bytesTransferred / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedSize {
    if (totalBytes < 1024) return '$bytesTransferred / $totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(bytesTransferred / 1024).toStringAsFixed(1)} / ${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalBytes < 1024 * 1024 * 1024) {
      return '${(bytesTransferred / (1024 * 1024)).toStringAsFixed(1)} / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytesTransferred / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Duration? get estimatedTimeRemaining {
    if (speed <= 0 || status != unified.TransferStatus.transferring) return null;
    final remainingBytes = totalBytes - bytesTransferred;
    final secondsRemaining = remainingBytes / speed;
    return Duration(seconds: secondsRemaining.round());
  }

  String get formattedTimeRemaining {
    final eta = estimatedTimeRemaining;
    if (eta == null) return 'Unknown';
    
    if (eta.inHours > 0) {
      return '${eta.inHours}h ${eta.inMinutes.remainder(60)}m';
    } else if (eta.inMinutes > 0) {
      return '${eta.inMinutes}m ${eta.inSeconds.remainder(60)}s';
    } else {
      return '${eta.inSeconds}s';
    }
  }
}

/// File item model for file manager
class FileItem {
  final String id;
  final String path;
  final String name;
  final int size;
  final String extension;
  final bool isDirectory;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime accessedAt;
  final String mimeType;
  final FileCategory category;
  final bool isFavorite;
  final bool isHidden;
  final String checksum;

  const FileItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.extension,
    required this.isDirectory,
    required this.createdAt,
    required this.modifiedAt,
    required this.accessedAt,
    required this.mimeType,
    required this.category,
    required this.isFavorite,
    required this.isHidden,
    required this.checksum,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Storage info model
class StorageInfo {
  final int totalSpace;
  final int usedSpace;
  final int freeSpace;
  final double usagePercentage;
  final Map<FileCategory, int> categoryBreakdown;

  const StorageInfo({
    required this.totalSpace,
    required this.usedSpace,
    required this.freeSpace,
    required this.usagePercentage,
    required this.categoryBreakdown,
  });

  String get totalSpaceFormatted => FormatUtils.formatBytes(totalSpace);
  String get usedSpaceFormatted => FormatUtils.formatBytes(usedSpace);
  String get freeSpaceFormatted => FormatUtils.formatBytes(freeSpace);
  int get availableSpace => freeSpace;
}

/// Installed app model
class InstalledApp {
  final String packageName;
  final String name;
  final String version;
  final int versionCode;
  final String? iconPath;
  final int size;
  final DateTime installedAt;

  InstalledApp({
    required this.packageName,
    required this.name,
    required this.version,
    required this.versionCode,
    this.iconPath,
    required this.size,
    required this.installedAt,
  });
}

/// Extracted APK model
class ExtractedApk {
  final String id;
  final String name;
  final String packageName;
  final String appName;
  final String apkPath;
  final int size;
  final DateTime extractedAt;

  const ExtractedApk({
    required this.id,
    required this.name,
    required this.packageName,
    required this.appName,
    required this.apkPath,
    required this.size,
    required this.extractedAt,
  });

  factory ExtractedApk.fromMap(Map<String, dynamic> map) {
    final dynamic extractedAtRaw = map['extractedAt'];
    DateTime extractedAt;
    if (extractedAtRaw is int) {
      extractedAt = DateTime.fromMillisecondsSinceEpoch(extractedAtRaw);
    } else if (extractedAtRaw is String) {
      extractedAt = DateTime.tryParse(extractedAtRaw) ?? DateTime.now();
    } else {
      extractedAt = DateTime.now();
    }
    return ExtractedApk(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      packageName: (map['packageName'] ?? '').toString(),
      appName: (map['appName'] ?? '').toString(),
      apkPath: (map['apkPath'] ?? '').toString(),
      size: (map['size'] as num?)?.toInt() ?? 0,
      extractedAt: extractedAt,
    );
  }
}

/// Extraction history item
class ExtractionHistoryItem {
  final String id;
  final String appName;
  final String packageName;
  final DateTime extractedAt;
  final int size;
  final String status;

  ExtractionHistoryItem({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.extractedAt,
    required this.size,
    required this.status,
  });
}

/// Cloud provider model
class CloudProvider {
  final String id;
  final String name;
  final String type;
  final bool isConnected;
  final int? storageUsed;
  final int? storageTotal;

  CloudProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.isConnected,
    this.storageUsed,
    this.storageTotal,
  });
}

/// Sync job model
class SyncJob {
  final String id;
  final String name;
  final String providerId;
  final String status;
  final double progress;
  final DateTime createdAt;

  SyncJob({
    required this.id,
    required this.name,
    required this.providerId,
    required this.status,
    required this.progress,
    required this.createdAt,
  });
}

/// Sync history item
class SyncHistoryItem {
  final String id;
  final String providerName;
  final String action;
  final DateTime timestamp;
  final String status;
  final int fileCount;
  final String? filePath;
  final int? fileSize;
  final String? error;

  SyncHistoryItem({
    required this.id,
    required this.providerName,
    required this.action,
    required this.timestamp,
    required this.status,
    required this.fileCount,
    this.filePath,
    this.fileSize,
    this.error,
  });
}

/// Video file model
class VideoFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final Duration duration;
  final int width;
  final int height;
  final String format;

  VideoFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.duration,
    required this.width,
    required this.height,
    required this.format,
  });
}

/// Compression job model
class CompressionJob {
  final String id;
  final String name;
  final String inputPath;
  final String outputPath;
  final String status;
  final double progress;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? originalSize;
  final int? compressedSize;

  CompressionJob({
    required this.id,
    required this.name,
    required this.inputPath,
    required this.outputPath,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.completedAt,
    this.originalSize,
    this.compressedSize,
  });
}

/// Compression status enum
enum CompressionStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

/// Compression preset model
class CompressionPreset {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> settings;
  final int width;
  final int height;
  final int bitrate;

  CompressionPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.settings,
    required this.width,
    required this.height,
    required this.bitrate,
  });
}

/// Compression history item
class CompressionHistoryItem {
  final String id;
  final String name;
  final String inputPath;
  final String outputPath;
  final DateTime compressedAt;
  final int originalSize;
  final int compressedSize;
  final String status;

  CompressionHistoryItem({
    required this.id,
    required this.name,
    required this.inputPath,
    required this.outputPath,
    required this.compressedAt,
    required this.originalSize,
    required this.compressedSize,
    required this.status,
  });
}

/// Source device data model
class SourceDeviceData {
  final DeviceInfo deviceInfo;
  final List<DataCategory> categories;
  final StorageInfo storageInfo;

  SourceDeviceData({
    required this.deviceInfo,
    required this.categories,
    required this.storageInfo,
  });
}

/// Target device data model
class TargetDeviceData {
  final DeviceInfo deviceInfo;

  TargetDeviceData({
    required this.deviceInfo,
  });
}

/// Device info model
class DeviceInfo {
  final String deviceName;
  final String model;
  final String osVersion;
  final int totalStorage;
  final int availableStorage;
  final int batteryLevel;

  DeviceInfo({
    required this.deviceName,
    required this.model,
    required this.osVersion,
    required this.totalStorage,
    required this.availableStorage,
    required this.batteryLevel,
  });
}

/// Data category model
class DataCategory {
  final String name;
  final DataCategoryType type;
  final int itemCount;
  final bool isSelected;

  DataCategory({
    required this.name,
    required this.type,
    required this.itemCount,
    required this.isSelected,
  });
}

/// Replication history item
class ReplicationHistoryItem {
  final String id;
  final String deviceName;
  final DateTime date;
  final String status;
  final int dataSize;

  ReplicationHistoryItem({
    required this.id,
    required this.deviceName,
    required this.date,
    required this.status,
    required this.dataSize,
  });
}

/// Group model
class Group {
  final String id;
  final String name;
  final List<GroupMember> members;
  final int memberCount;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.memberCount,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      members: (map['members'] as List<dynamic>?)
          ?.map((member) => GroupMember.fromMap(member))
          .toList() ?? [],
      memberCount: map['memberCount'] ?? 0,
    );
  }
}

/// Group member model
class GroupMember {
  final String id;
  final String name;
  final String deviceId;
  final bool isOnline;

  GroupMember({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.isOnline,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      deviceId: map['deviceId'] ?? '',
      isOnline: map['isOnline'] ?? false,
    );
  }
}

/// Sync status model
class SyncStatus {
  final String id;
  final String name;
  final String status;
  final double progress;
  final DateTime createdAt;
  final String? localPath;
  final String? remotePath;
  final int? filesProcessed;
  final int? totalFiles;

  SyncStatus({
    required this.id,
    required this.name,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.localPath,
    this.remotePath,
    this.filesProcessed,
    this.totalFiles,
  });
}

/// Cloud storage info model
class CloudStorageInfo {
  final String providerId;
  final int totalSpace;
  final int usedSpace;
  final int freeSpace;
  final double usagePercentage;
  final String? provider;

  CloudStorageInfo({
    required this.providerId,
    required this.totalSpace,
    required this.usedSpace,
    required this.freeSpace,
    required this.usagePercentage,
    this.provider,
  });

  String get usedSpaceFormatted => FormatUtils.formatBytes(usedSpace);
  String get freeSpaceFormatted => FormatUtils.formatBytes(freeSpace);
  String get totalSpaceFormatted => FormatUtils.formatBytes(totalSpace);
}

/// Sync status type enum
enum SyncStatusType {
  active,
  paused,
  completed,
  failed,
  cancelled,
}

/// Sync item status enum
enum SyncItemStatus {
  completed,
  failed,
  inProgress,
  pending,
}

/// Sharing session model
class SharingSession {
  final String id;
  final String groupName;
  final int fileCount;
  final String status;
  final double progress;

  SharingSession({
    required this.id,
    required this.groupName,
    required this.fileCount,
    required this.status,
    required this.progress,
  });

  factory SharingSession.fromMap(Map<String, dynamic> map) {
    return SharingSession(
      id: map['id'] ?? '',
      groupName: map['groupName'] ?? '',
      fileCount: map['fileCount'] ?? 0,
      status: map['status'] ?? '',
      progress: (map['progress'] ?? 0.0).toDouble(),
    );
  }
}

/// Group sharing history item
class GroupSharingHistoryItem {
  final String id;
  final String groupName;
  final DateTime date;
  final int fileCount;
  final int dataSize;
  final GroupSharingType type;

  GroupSharingHistoryItem({
    required this.id,
    required this.groupName,
    required this.date,
    required this.fileCount,
    required this.dataSize,
    required this.type,
  });

  factory GroupSharingHistoryItem.fromMap(Map<String, dynamic> map) {
    return GroupSharingHistoryItem(
      id: map['id'] ?? '',
      groupName: map['groupName'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      fileCount: map['fileCount'] ?? 0,
      dataSize: map['dataSize'] ?? 0,
      type: GroupSharingType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => GroupSharingType.sent,
      ),
    );
  }
}

/// Transfer session model
class TransferSession {
  final String id;
  final String senderId;
  final String receiverId;
  final List<TransferFile> files;
  final DateTime createdAt;
  final DateTime? completedAt;
  final unified.TransferStatus status;
  final String? error;
  final Map<String, dynamic> metadata;

  TransferSession({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.files,
    required this.createdAt,
    this.completedAt,
    required this.status,
    this.error,
    this.metadata = const {},
  });

  int get totalSize {
    return files.fold(0, (sum, file) => sum + file.size);
  }

  String get formattedTotalSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Duration get duration {
    final end = completedAt ?? DateTime.now();
    return end.difference(createdAt);
  }

  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    } else {
      return '${d.inSeconds}s';
    }
  }
}
