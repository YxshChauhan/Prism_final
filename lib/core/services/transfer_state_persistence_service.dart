import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:injectable/injectable.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/models/transfer_state.dart';

/// Transfer State Persistence Service
/// Handles saving and restoring transfer states for pause/resume functionality
/// Enables resume after app restart or disconnect
@injectable
class TransferStatePersistenceService {
  static const String _tag = 'TransferStatePersistence';
  static const String _stateFileName = 'transfer_states.json';
  
  final LoggerService _logger;
  File? _stateFile;
  final Map<String, TransferState> _activeStates = {};
  
  TransferStatePersistenceService(this._logger);
  
  /// Initialize the service
  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _stateFile = File('${directory.path}/$_stateFileName');
      
      if (await _stateFile!.exists()) {
        await _loadStates();
      }
      
      _logger.info(_tag, 'Transfer state persistence initialized');
    } catch (e) {
      _logger.error(_tag, 'Failed to initialize: $e');
      rethrow;
    }
  }
  
  /// Save a transfer state
  Future<void> saveTransferState(TransferState state) async {
    try {
      _activeStates[state.transferId] = state;
      await _persistStates();
      _logger.debug(_tag, 'Saved state for transfer: ${state.transferId}');
    } catch (e) {
      _logger.error(_tag, 'Failed to save transfer state: $e');
      rethrow;
    }
  }
  
  /// Get a transfer state by ID
  TransferState? getTransferState(String transferId) {
    return _activeStates[transferId];
  }
  
  /// Get all active transfer states
  List<TransferState> getAllTransferStates() {
    return _activeStates.values.toList();
  }
  
  /// Get resumable transfers (paused or failed with retry capability)
  List<TransferState> getResumableTransfers() {
    return _activeStates.values
        .where((state) =>
            state.status == TransferStatus.paused ||
            (state.status == TransferStatus.failed && state.canRetry))
        .toList();
  }
  
  /// Update transfer progress
  Future<void> updateTransferProgress(
    String transferId,
    int bytesTransferred,
  ) async {
    try {
      final state = _activeStates[transferId];
      if (state != null) {
        final updatedState = state.copyWith(
          bytesTransferred: bytesTransferred,
          lastUpdated: DateTime.now(),
        );
        _activeStates[transferId] = updatedState;
        
        // Persist every 5% progress or 10MB transferred
        if (_shouldPersist(state, updatedState)) {
          await _persistStates();
        }
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to update progress: $e');
    }
  }
  
  /// Mark transfer as paused
  Future<void> pauseTransfer(String transferId) async {
    try {
      final state = _activeStates[transferId];
      if (state != null) {
        final pausedState = state.copyWith(
          status: TransferStatus.paused,
          pausedAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        _activeStates[transferId] = pausedState;
        await _persistStates();
        _logger.info(_tag, 'Transfer paused: $transferId at ${state.bytesTransferred} bytes');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to pause transfer: $e');
      rethrow;
    }
  }
  
  /// Resume transfer
  Future<void> resumeTransfer(String transferId) async {
    try {
      final state = _activeStates[transferId];
      if (state != null) {
        final resumedState = state.copyWith(
          status: TransferStatus.transferring,
          resumedAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        _activeStates[transferId] = resumedState;
        await _persistStates();
        _logger.info(_tag, 'Transfer resumed: $transferId from ${state.bytesTransferred} bytes');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to resume transfer: $e');
      rethrow;
    }
  }
  
  /// Mark transfer as complete
  Future<void> completeTransfer(String transferId) async {
    try {
      final state = _activeStates[transferId];
      if (state != null) {
        final completedState = state.copyWith(
          status: TransferStatus.completed,
          completedAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        _activeStates[transferId] = completedState;
        await _persistStates();
        
        // Remove after 24 hours to keep storage clean
        Future.delayed(const Duration(hours: 24), () {
          removeTransferState(transferId);
        });
        
        _logger.info(_tag, 'Transfer completed: $transferId');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to complete transfer: $e');
    }
  }
  
  /// Mark transfer as failed
  Future<void> failTransfer(String transferId, String error, {bool canRetry = false}) async {
    try {
      final state = _activeStates[transferId];
      if (state != null) {
        final failedState = state.copyWith(
          status: TransferStatus.failed,
          error: error,
          canRetry: canRetry,
          lastUpdated: DateTime.now(),
        );
        _activeStates[transferId] = failedState;
        await _persistStates();
        _logger.warning(_tag, 'Transfer failed: $transferId - $error (canRetry: $canRetry)');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to mark transfer as failed: $e');
    }
  }
  
  /// Cancel transfer
  Future<void> cancelTransfer(String transferId) async {
    try {
      final state = _activeStates[transferId];
      if (state != null) {
        final cancelledState = state.copyWith(
          status: TransferStatus.cancelled,
          lastUpdated: DateTime.now(),
        );
        _activeStates[transferId] = cancelledState;
        await _persistStates();
        
        // Remove cancelled transfers after 1 hour
        Future.delayed(const Duration(hours: 1), () {
          removeTransferState(transferId);
        });
        
        _logger.info(_tag, 'Transfer cancelled: $transferId');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to cancel transfer: $e');
    }
  }
  
  /// Remove a transfer state
  Future<void> removeTransferState(String transferId) async {
    try {
      _activeStates.remove(transferId);
      await _persistStates();
      _logger.debug(_tag, 'Removed state for transfer: $transferId');
    } catch (e) {
      _logger.error(_tag, 'Failed to remove transfer state: $e');
    }
  }
  
  /// Clean up old completed/cancelled transfers
  Future<void> cleanupOldTransfers({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final cutoffTime = DateTime.now().subtract(maxAge);
      final toRemove = <String>[];
      
      for (final entry in _activeStates.entries) {
        final state = entry.value;
        if ((state.status == TransferStatus.completed ||
                state.status == TransferStatus.cancelled ||
                state.status == TransferStatus.failed) &&
            state.lastUpdated.isBefore(cutoffTime)) {
          toRemove.add(entry.key);
        }
      }
      
      for (final transferId in toRemove) {
        _activeStates.remove(transferId);
      }
      
      if (toRemove.isNotEmpty) {
        await _persistStates();
        _logger.info(_tag, 'Cleaned up ${toRemove.length} old transfers');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to cleanup old transfers: $e');
    }
  }
  
  /// Private: Persist states to disk
  Future<void> _persistStates() async {
    try {
      if (_stateFile == null) return;
      
      final statesJson = _activeStates.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      
      final jsonString = jsonEncode(statesJson);
      await _stateFile!.writeAsString(jsonString);
    } catch (e) {
      _logger.error(_tag, 'Failed to persist states: $e');
    }
  }
  
  /// Private: Load states from disk
  Future<void> _loadStates() async {
    try {
      if (_stateFile == null || !await _stateFile!.exists()) return;
      
      final jsonString = await _stateFile!.readAsString();
      final statesJson = jsonDecode(jsonString) as Map<String, dynamic>;
      
      _activeStates.clear();
      for (final entry in statesJson.entries) {
        try {
          final state = TransferState.fromJson(entry.value as Map<String, dynamic>);
          _activeStates[entry.key] = state;
        } catch (e) {
          _logger.warning(_tag, 'Failed to parse state for ${entry.key}: $e');
        }
      }
      
      _logger.info(_tag, 'Loaded ${_activeStates.length} transfer states');
    } catch (e) {
      _logger.error(_tag, 'Failed to load states: $e');
    }
  }
  
  /// Private: Check if state should be persisted
  bool _shouldPersist(TransferState oldState, TransferState newState) {
    // Persist if progress increased by 5% or 10MB
    final progressDiff = newState.bytesTransferred - oldState.bytesTransferred;
    final percentDiff = (progressDiff / newState.totalBytes) * 100;
    
    return percentDiff >= 5.0 || progressDiff >= 10 * 1024 * 1024;
  }
}
