import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:airlink/core/services/dependency_injection.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return getIt<TransferRepository>();
});

final transferHistoryProvider = FutureProvider<List<unified.TransferSession>>((ref) async {
  final repository = ref.read(transferRepositoryProvider);
  return repository.getTransferHistory();
});

final activeTransfersProvider = FutureProvider<List<unified.TransferSession>>((ref) async {
  final repository = ref.read(transferRepositoryProvider);
  return repository.getActiveTransfers();
});

final transferProvider = FutureProvider.family<unified.TransferSession?, String>((ref, sessionId) async {
  final repository = ref.read(transferRepositoryProvider);
  final sessions = repository.getActiveTransfers();
  try {
    return sessions.firstWhere((session) => session.id == sessionId);
  } catch (e) {
    // Session not found, return null
    return null;
  }
});

final transferProgressProvider = StreamProvider.family<unified.TransferProgress, String>((ref, sessionId) {
  final repository = ref.read(transferRepositoryProvider);
  return repository.getTransferProgress(sessionId);
});

final transferControllerProvider = Provider<TransferController>((ref) {
  return TransferController(ref);
});

class TransferController {
  final Ref _ref;
  
  TransferController(this._ref);
  
  Future<String> startTransfer({
    required String receiverId,
    required List<unified.TransferFile> files,
  }) async {
    final repository = _ref.read(transferRepositoryProvider);
    return await repository.startTransferSession(
      targetDeviceId: receiverId,
      connectionMethod: 'wifi_aware',
      files: files,
    );
  }
  
  Future<void> sendFiles({
    required String sessionId,
    required List<unified.TransferFile> files,
  }) async {
    final repository = _ref.read(transferRepositoryProvider);
    await repository.sendFiles(
      sessionId: sessionId,
      files: files,
    );
  }
  
  Future<void> receiveFiles({
    required String sessionId,
    required String savePath,
  }) async {
    final repository = _ref.read(transferRepositoryProvider);
    await repository.receiveFiles(
      sessionId: sessionId,
      savePath: savePath,
    );
  }
  
  Future<void> pauseTransfer(String transferId) async {
    final repository = _ref.read(transferRepositoryProvider);
    await repository.pauseTransfer(transferId);
  }
  
  Future<void> resumeTransfer(String transferId) async {
    final repository = _ref.read(transferRepositoryProvider);
    await repository.resumeTransfer(transferId);
  }
  
  Future<void> cancelTransfer(String transferId) async {
    final repository = _ref.read(transferRepositoryProvider);
    await repository.cancelTransfer(transferId);
  }
  
  Future<void> cleanupCompletedTransfers() async {
    final repository = _ref.read(transferRepositoryProvider);
    await repository.cleanupCompletedTransfers();
  }
}
