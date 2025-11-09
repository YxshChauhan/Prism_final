import 'dart:io';

/// Transfer file model
class TransferFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String mimeType;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  const TransferFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.createdAt,
    this.modifiedAt,
  });

  /// Create from File
  factory TransferFile.fromFile(File file) {
    final stat = file.statSync();
    return TransferFile(
      id: file.path.hashCode.toString(),
      name: file.path.split('/').last,
      path: file.path,
      size: stat.size,
      mimeType: _getMimeType(file.path),
      createdAt: stat.changed,
      modifiedAt: stat.modified,
    );
  }

  static String _getMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'mimeType': mimeType,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  factory TransferFile.fromJson(Map<String, dynamic> json) {
    return TransferFile(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      mimeType: json['mimeType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: json['modifiedAt'] != null 
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransferFile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Transfer session model
class TransferSession {
  final String id;
  final String senderId;
  final String receiverId;
  final List<TransferFile> files;
  final TransferStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  const TransferSession({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.files,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'files': files.map((f) => f.toJson()).toList(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory TransferSession.fromJson(Map<String, dynamic> json) {
    return TransferSession(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      files: (json['files'] as List)
          .map((f) => TransferFile.fromJson(f as Map<String, dynamic>))
          .toList(),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// Transfer status enum
enum TransferStatus {
  pending,
  inProgress,
  paused,
  completed,
  failed,
  cancelled,
}
