/// Transfer State Model
/// Represents the state of a file transfer for persistence and resume functionality
class TransferState {
  final String transferId;
  final String filePath;
  final int totalBytes;
  final int bytesTransferred;
  final String deviceId;
  final String connectionMethod;
  final TransferStatus status;
  final String? error;
  final bool canRetry;
  final DateTime createdAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? completedAt;
  final DateTime lastUpdated;
  final Map<String, dynamic>? metadata;
  
  const TransferState({
    required this.transferId,
    required this.filePath,
    required this.totalBytes,
    this.bytesTransferred = 0,
    required this.deviceId,
    required this.connectionMethod,
    this.status = TransferStatus.pending,
    this.error,
    this.canRetry = false,
    required this.createdAt,
    this.pausedAt,
    this.resumedAt,
    this.completedAt,
    required this.lastUpdated,
    this.metadata,
  });
  
  /// Create a copy with updated fields
  TransferState copyWith({
    int? bytesTransferred,
    TransferStatus? status,
    String? error,
    bool? canRetry,
    DateTime? pausedAt,
    DateTime? resumedAt,
    DateTime? completedAt,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return TransferState(
      transferId: transferId,
      filePath: filePath,
      totalBytes: totalBytes,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      deviceId: deviceId,
      connectionMethod: connectionMethod,
      status: status ?? this.status,
      error: error ?? this.error,
      canRetry: canRetry ?? this.canRetry,
      createdAt: createdAt,
      pausedAt: pausedAt ?? this.pausedAt,
      resumedAt: resumedAt ?? this.resumedAt,
      completedAt: completedAt ?? this.completedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'filePath': filePath,
      'totalBytes': totalBytes,
      'bytesTransferred': bytesTransferred,
      'deviceId': deviceId,
      'connectionMethod': connectionMethod,
      'status': status.toString(),
      'error': error,
      'canRetry': canRetry,
      'createdAt': createdAt.toIso8601String(),
      'pausedAt': pausedAt?.toIso8601String(),
      'resumedAt': resumedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// Create from JSON
  factory TransferState.fromJson(Map<String, dynamic> json) {
    return TransferState(
      transferId: json['transferId'] as String,
      filePath: json['filePath'] as String,
      totalBytes: json['totalBytes'] as int,
      bytesTransferred: json['bytesTransferred'] as int? ?? 0,
      deviceId: json['deviceId'] as String,
      connectionMethod: json['connectionMethod'] as String,
      status: _statusFromString(json['status'] as String),
      error: json['error'] as String?,
      canRetry: json['canRetry'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt'] as String) : null,
      resumedAt: json['resumedAt'] != null ? DateTime.parse(json['resumedAt'] as String) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  static TransferStatus _statusFromString(String status) {
    return TransferStatus.values.firstWhere(
      (e) => e.toString() == status,
      orElse: () => TransferStatus.pending,
    );
  }
  
  /// Get progress percentage
  double get progressPercent {
    if (totalBytes == 0) return 0.0;
    return (bytesTransferred / totalBytes) * 100;
  }
  
  /// Check if transfer is active
  bool get isActive {
    return status == TransferStatus.transferring || status == TransferStatus.pending;
  }
  
  /// Check if transfer is resumable
  bool get isResumable {
    return status == TransferStatus.paused || (status == TransferStatus.failed && canRetry);
  }
}

/// Transfer Status Enum
enum TransferStatus {
  pending,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}
