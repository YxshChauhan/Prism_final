import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/core/services/transfer_benchmark.dart';

abstract class TransferRepository {
  /// Start a new transfer session
  Future<String> startTransferSession({
    required String targetDeviceId,
    required String connectionMethod,
    required List<unified.TransferFile> files,
  });
  
  /// Send files to a device
  Future<void> sendFiles({
    required String sessionId,
    required List<unified.TransferFile> files,
  });
  
  /// Receive files from a device
  Future<void> receiveFiles({
    required String sessionId,
    required String savePath,
  });
  
  /// Start receiving files (for testing purposes)
  Future<void> startReceivingFiles({
    required String sessionId,
    required String connectionToken,
    required String connectionMethod,
    required String savePath,
  });
  
  /// Pause a transfer
  Future<void> pauseTransfer(String transferId);
  
  /// Resume a paused transfer
  Future<void> resumeTransfer(String transferId);
  
  /// Cancel a transfer
  Future<void> cancelTransfer(String transferId);
  
  /// Get transfer progress
  Stream<unified.TransferProgress> getTransferProgress(String transferId);

  /// Get overall queue progress for a session (completedFiles/totalFiles)
  Stream<TransferQueueProgress> getQueueProgress(String sessionId);
  
  /// Get all active transfers
  List<unified.TransferSession> getActiveTransfers();
  
  /// Get transfer history
  List<unified.TransferSession> getTransferHistory();
  
  /// Clean up completed transfers
  Future<void> cleanupCompletedTransfers();
  
  /// Get transfer benchmark for a specific transfer
  Future<TransferBenchmark?> getTransferBenchmark(String compositeId);
}

/// Overall queue progress event
class TransferQueueProgress {
  final String sessionId;
  final int completedFiles;
  final int totalFiles;

  const TransferQueueProgress({
    required this.sessionId,
    required this.completedFiles,
    required this.totalFiles,
  });
}
