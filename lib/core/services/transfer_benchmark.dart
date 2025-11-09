import 'package:airlink/shared/models/transfer_models.dart' as unified;

/// Transfer benchmark data model with system resource metrics
class TransferBenchmark {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String transferMethod;
  final String deviceType;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final int bytesTransferred;
  final double averageSpeed;
  final double peakSpeed;
  final double currentSpeed;
  final unified.TransferStatus status;
  final String? errorMessage;
  
  // System resource metrics
  final double? avgCpuUsage;
  final double? maxCpuUsage;
  final int? avgMemoryUsage;
  final int? maxMemoryUsage;
  final int? minBatteryLevel;
  final double? avgNetworkSpeed;
  final int? resourceSamples;
  final String? deviceTemperature;

  const TransferBenchmark({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.transferMethod,
    required this.deviceType,
    required this.startTime,
    this.endTime,
    this.duration,
    this.bytesTransferred = 0,
    this.averageSpeed = 0.0,
    this.peakSpeed = 0.0,
    this.currentSpeed = 0.0,
    required this.status,
    this.errorMessage,
    // System resource metrics
    this.avgCpuUsage,
    this.maxCpuUsage,
    this.avgMemoryUsage,
    this.maxMemoryUsage,
    this.minBatteryLevel,
    this.avgNetworkSpeed,
    this.resourceSamples,
    this.deviceTemperature,
  });

  TransferBenchmark copyWith({
    String? transferId,
    String? fileName,
    int? fileSize,
    String? transferMethod,
    String? deviceType,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    int? bytesTransferred,
    double? averageSpeed,
    double? peakSpeed,
    double? currentSpeed,
    unified.TransferStatus? status,
    String? errorMessage,
    // System resource metrics
    double? avgCpuUsage,
    double? maxCpuUsage,
    int? avgMemoryUsage,
    int? maxMemoryUsage,
    int? minBatteryLevel,
    double? avgNetworkSpeed,
    int? resourceSamples,
    String? deviceTemperature,
  }) {
    return TransferBenchmark(
      transferId: transferId ?? this.transferId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      transferMethod: transferMethod ?? this.transferMethod,
      deviceType: deviceType ?? this.deviceType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      peakSpeed: peakSpeed ?? this.peakSpeed,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      // System resource metrics
      avgCpuUsage: avgCpuUsage ?? this.avgCpuUsage,
      maxCpuUsage: maxCpuUsage ?? this.maxCpuUsage,
      avgMemoryUsage: avgMemoryUsage ?? this.avgMemoryUsage,
      maxMemoryUsage: maxMemoryUsage ?? this.maxMemoryUsage,
      minBatteryLevel: minBatteryLevel ?? this.minBatteryLevel,
      avgNetworkSpeed: avgNetworkSpeed ?? this.avgNetworkSpeed,
      resourceSamples: resourceSamples ?? this.resourceSamples,
      deviceTemperature: deviceTemperature ?? this.deviceTemperature,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transfer_id': transferId,
      'file_name': fileName,
      'file_size': fileSize,
      'transfer_method': transferMethod,
      'device_type': deviceType,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_ms': duration?.inMilliseconds,
      'bytes_transferred': bytesTransferred,
      'average_speed': averageSpeed,
      'peak_speed': peakSpeed,
      'status': status.name,
      'error_message': errorMessage,
      'created_at': DateTime.now().toIso8601String(),
      // System resource metrics
      'avg_cpu_usage': avgCpuUsage,
      'max_cpu_usage': maxCpuUsage,
      'avg_memory_usage': avgMemoryUsage,
      'max_memory_usage': maxMemoryUsage,
      'min_battery_level': minBatteryLevel,
      'avg_network_speed': avgNetworkSpeed,
      'resource_samples': resourceSamples,
      'device_temperature': deviceTemperature,
    };
  }

  double get progressPercentage {
    if (fileSize == 0) return 0.0;
    return (bytesTransferred / fileSize).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (averageSpeed < 1024) return '${averageSpeed.toStringAsFixed(0)} B/s';
    if (averageSpeed < 1024 * 1024) return '${(averageSpeed / 1024).toStringAsFixed(1)} KB/s';
    return '${(averageSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDuration {
    if (duration == null) return 'Unknown';
    
    final d = duration!;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    } else {
      return '${d.inSeconds}s';
    }
  }
  
  // System resource metric formatters
  
  String get formattedCpuUsage {
    if (avgCpuUsage == null) return 'N/A';
    return '${avgCpuUsage!.toStringAsFixed(1)}%';
  }
  
  String get formattedMaxCpuUsage {
    if (maxCpuUsage == null) return 'N/A';
    return '${maxCpuUsage!.toStringAsFixed(1)}%';
  }
  
  String get formattedMemoryUsage {
    if (avgMemoryUsage == null) return 'N/A';
    if (avgMemoryUsage! < 1024) return '${avgMemoryUsage}MB';
    return '${(avgMemoryUsage! / 1024).toStringAsFixed(1)}GB';
  }
  
  String get formattedMaxMemoryUsage {
    if (maxMemoryUsage == null) return 'N/A';
    if (maxMemoryUsage! < 1024) return '${maxMemoryUsage}MB';
    return '${(maxMemoryUsage! / 1024).toStringAsFixed(1)}GB';
  }
  
  String get formattedBatteryLevel {
    if (minBatteryLevel == null) return 'N/A';
    return '${minBatteryLevel}%';
  }
  
  String get formattedNetworkSpeed {
    if (avgNetworkSpeed == null) return 'N/A';
    if (avgNetworkSpeed! < 1) return '${(avgNetworkSpeed! * 1000).toStringAsFixed(0)} Kbps';
    return '${avgNetworkSpeed!.toStringAsFixed(1)} Mbps';
  }
  
  String get resourceEfficiencyRating {
    if (avgCpuUsage == null || avgMemoryUsage == null) return 'Unknown';
    
    // Simple efficiency rating based on resource usage
    final cpuScore = avgCpuUsage! < 30 ? 3 : (avgCpuUsage! < 60 ? 2 : 1);
    final memoryScore = avgMemoryUsage! < 200 ? 3 : (avgMemoryUsage! < 500 ? 2 : 1);
    final totalScore = (cpuScore + memoryScore) / 2;
    
    if (totalScore >= 2.5) return 'Excellent';
    if (totalScore >= 2.0) return 'Good';
    if (totalScore >= 1.5) return 'Fair';
    return 'Poor';
  }
  
  /// Get a comprehensive resource summary
  Map<String, String> get resourceSummary {
    return {
      'CPU Usage': formattedCpuUsage,
      'Max CPU': formattedMaxCpuUsage,
      'Memory Usage': formattedMemoryUsage,
      'Max Memory': formattedMaxMemoryUsage,
      'Battery Level': formattedBatteryLevel,
      'Network Speed': formattedNetworkSpeed,
      'Temperature': deviceTemperature ?? 'N/A',
      'Efficiency': resourceEfficiencyRating,
      'Samples': resourceSamples?.toString() ?? 'N/A',
    };
  }
}
