// unified transfer models

class TransferModelsSerializationException implements Exception {
  final String message;
  const TransferModelsSerializationException(this.message);
  @override
  String toString() => 'TransferModelsSerializationException: $message';
}

enum TransferStatus {
  pending,
  connecting,
  handshaking,
  transferring,
  paused,
  resuming,
  completed,
  failed,
  cancelled,
}

enum TransferDirection {
  sent,
  received,
}

class TransferProgress {
  final String transferId;
  final String fileId;
  final String fileName;
  final int bytesTransferred;
  final int totalBytes;
  final double progress; // 0.0 - 1.0
  final double speed; // bytes per second
  final TransferStatus status;
  final DateTime startedAt;
  final Duration? estimatedTimeRemaining;
  final String? errorMessage;
  const TransferProgress({
    required this.transferId,
    required this.fileId,
    required this.fileName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.progress,
    required this.speed,
    required this.status,
    required this.startedAt,
    this.estimatedTimeRemaining,
    this.errorMessage,
  });
  TransferProgress copyWith({
    String? transferId,
    String? fileId,
    String? fileName,
    int? bytesTransferred,
    int? totalBytes,
    double? progress,
    double? speed,
    TransferStatus? status,
    DateTime? startedAt,
    Duration? estimatedTimeRemaining,
    String? errorMessage,
  }) {
    return TransferProgress(
      transferId: transferId ?? this.transferId,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      estimatedTimeRemaining: estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'fileId': fileId,
      'fileName': fileName,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
      'progress': progress,
      'speed': speed,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'estimatedTimeRemaining': estimatedTimeRemaining?.inMilliseconds,
      'errorMessage': errorMessage,
    };
  }
  static TransferProgress fromJson(Map<String, dynamic> json) {
    try {
      return TransferProgress(
        transferId: json['transferId'] as String,
        fileId: json['fileId'] as String,
        fileName: (json['fileName'] as String?) ?? '',
        bytesTransferred: (json['bytesTransferred'] as num).toInt(),
        totalBytes: (json['totalBytes'] as num).toInt(),
        progress: (json['progress'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
        status: TransferStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String),
          orElse: () => TransferStatus.pending,
        ),
        startedAt: DateTime.parse(json['startedAt'] as String),
        estimatedTimeRemaining: json['estimatedTimeRemaining'] == null
            ? null
            : Duration(milliseconds: (json['estimatedTimeRemaining'] as num).toInt()),
        errorMessage: json['errorMessage'] as String?,
      );
    } catch (e) {
      throw TransferModelsSerializationException('Failed to deserialize TransferProgress: $e');
    }
  }
}

class TransferFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String mimeType;
  final String? checksum;
  final int bytesTransferred;
  final TransferStatus status;
  const TransferFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    this.checksum,
    this.bytesTransferred = 0,
    this.status = TransferStatus.pending,
  });
  TransferFile copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    String? mimeType,
    String? checksum,
    int? bytesTransferred,
    TransferStatus? status,
  }) {
    return TransferFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      checksum: checksum ?? this.checksum,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'mimeType': mimeType,
      'checksum': checksum,
      'bytesTransferred': bytesTransferred,
      'status': status.name,
    };
  }
  static TransferFile fromJson(Map<String, dynamic> json) {
    try {
      return TransferFile(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        size: (json['size'] as num).toInt(),
        mimeType: json['mimeType'] as String,
        checksum: json['checksum'] as String?,
        bytesTransferred: (json['bytesTransferred'] as num?)?.toInt() ?? 0,
        status: TransferStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? 'pending'),
          orElse: () => TransferStatus.pending,
        ),
      );
    } catch (e) {
      throw TransferModelsSerializationException('Failed to deserialize TransferFile: $e');
    }
  }
}

class TransferSession {
  final String id;
  final String targetDeviceId;
  final List<TransferFile> files;
  final String connectionMethod; // 'wifi_aware', 'ble', 'multipeer'
  final TransferStatus status;
  final TransferDirection direction; // 'sent' or 'received'
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int totalBytes;
  final int bytesTransferred;
  final bool encryptionEnabled;
  const TransferSession({
    required this.id,
    required this.targetDeviceId,
    required this.files,
    required this.connectionMethod,
    required this.status,
    required this.direction,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.totalBytes = 0,
    this.bytesTransferred = 0,
    this.encryptionEnabled = true,
  });
  TransferSession copyWith({
    String? id,
    String? targetDeviceId,
    List<TransferFile>? files,
    String? connectionMethod,
    TransferStatus? status,
    TransferDirection? direction,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? totalBytes,
    int? bytesTransferred,
    bool? encryptionEnabled,
  }) {
    return TransferSession(
      id: id ?? this.id,
      targetDeviceId: targetDeviceId ?? this.targetDeviceId,
      files: files ?? this.files,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetDeviceId': targetDeviceId,
      'files': files.map((f) => f.toJson()).toList(),
      'connectionMethod': connectionMethod,
      'status': status.name,
      'direction': direction.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'totalBytes': totalBytes,
      'bytesTransferred': bytesTransferred,
      'encryptionEnabled': encryptionEnabled,
    };
  }
  static TransferSession fromJson(Map<String, dynamic> json) {
    try {
      return TransferSession(
        id: json['id'] as String,
        targetDeviceId: json['targetDeviceId'] as String,
        files: ((json['files'] as List?) ?? const [])
            .map((e) => TransferFile.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        connectionMethod: json['connectionMethod'] as String,
        status: TransferStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String),
          orElse: () => TransferStatus.pending,
        ),
        direction: TransferDirection.values.firstWhere(
          (e) => e.name == (json['direction'] as String?),
          orElse: () => TransferDirection.sent, // Default to sent for backward compatibility
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        startedAt: json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String),
        completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        bytesTransferred: (json['bytesTransferred'] as num?)?.toInt() ?? 0,
        encryptionEnabled: (json['encryptionEnabled'] as bool?) ?? true,
      );
    } catch (e) {
      throw TransferModelsSerializationException('Failed to deserialize TransferSession: $e');
    }
  }
}


