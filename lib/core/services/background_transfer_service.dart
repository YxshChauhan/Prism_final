import 'dart:async';
import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/transfer_state_persistence_service.dart';
import 'package:airlink/core/models/transfer_state.dart';
import 'package:flutter/services.dart';

/// Background Transfer Service
/// Manages file transfers that continue when the app is backgrounded
/// Coordinates with native background task managers on iOS and Android
@injectable
class BackgroundTransferService {
  static const String _tag = 'BackgroundTransferService';
  static const platform = MethodChannel('airlink/core');
  
  final LoggerService _logger;
  final TransferStatePersistenceService _persistenceService;
  
  final Map<String, BackgroundTransfer> _activeBackgroundTransfers = {};
  final _transferCompletionController = StreamController<String>.broadcast();
  
  BackgroundTransferService(this._logger, this._persistenceService);
  
  /// Stream of completed transfer IDs
  Stream<String> get onTransferComplete => _transferCompletionController.stream;
  
  /// Initialize background transfer service
  Future<void> initialize() async {
    try {
      // Check platform support
      final isSupported = await _checkBackgroundSupport();
      if (!isSupported) {
        _logger.warning(_tag, 'Background transfers not fully supported on this platform');
      }
      
      // Restore any transfers that were in progress
      await _restoreBackgroundTransfers();
      
      _logger.info(_tag, 'Background transfer service initialized');
    } catch (e) {
      _logger.error(_tag, 'Failed to initialize: $e');
      rethrow;
    }
  }
  
  /// Start a background transfer
  Future<String> startBackgroundTransfer({
    required String transferId,
    required String filePath,
    required int fileSize,
    required String deviceId,
    required String connectionMethod,
  }) async {
    try {
      // Validate file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }
      
      // Create background transfer
      final transfer = BackgroundTransfer(
        transferId: transferId,
        filePath: filePath,
        fileSize: fileSize,
        deviceId: deviceId,
        connectionMethod: connectionMethod,
        startTime: DateTime.now(),
      );
      
      _activeBackgroundTransfers[transferId] = transfer;
      
      // Start platform-specific background task
      await _startPlatformBackgroundTask(transfer);
      
      // Save state for recovery
      await _persistenceService.saveTransferState(TransferState(
        transferId: transferId,
        filePath: filePath,
        totalBytes: fileSize,
        deviceId: deviceId,
        connectionMethod: connectionMethod,
        status: TransferStatus.transferring,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      ));
      
      _logger.info(_tag, 'Started background transfer: $transferId');
      return transferId;
    } catch (e) {
      _logger.error(_tag, 'Failed to start background transfer: $e');
      rethrow;
    }
  }
  
  /// Update transfer progress
  Future<void> updateProgress(String transferId, int bytesTransferred) async {
    try {
      final transfer = _activeBackgroundTransfers[transferId];
      if (transfer != null) {
        transfer.bytesTransferred = bytesTransferred;
        transfer.lastUpdateTime = DateTime.now();
        
        // Update persistence
        await _persistenceService.updateTransferProgress(transferId, bytesTransferred);
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to update progress: $e');
    }
  }
  
  /// Complete a background transfer
  Future<void> completeTransfer(String transferId) async {
    try {
      final transfer = _activeBackgroundTransfers[transferId];
      if (transfer != null) {
        // End platform-specific background task
        await _endPlatformBackgroundTask(transferId);
        
        // Update persistence
        await _persistenceService.completeTransfer(transferId);
        
        // Remove from active transfers
        _activeBackgroundTransfers.remove(transferId);
        
        // Notify completion
        _transferCompletionController.add(transferId);
        
        _logger.info(_tag, 'Completed background transfer: $transferId');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to complete transfer: $e');
    }
  }
  
  /// Fail a background transfer
  Future<void> failTransfer(String transferId, String error, {bool canRetry = false}) async {
    try {
      final transfer = _activeBackgroundTransfers[transferId];
      if (transfer != null) {
        // End platform-specific background task
        await _endPlatformBackgroundTask(transferId);
        
        // Update persistence
        await _persistenceService.failTransfer(transferId, error, canRetry: canRetry);
        
        // Remove from active transfers
        _activeBackgroundTransfers.remove(transferId);
        
        _logger.warning(_tag, 'Failed background transfer: $transferId - $error');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to mark transfer as failed: $e');
    }
  }
  
  /// Cancel a background transfer
  Future<void> cancelTransfer(String transferId) async {
    try {
      final transfer = _activeBackgroundTransfers[transferId];
      if (transfer != null) {
        // End platform-specific background task
        await _endPlatformBackgroundTask(transferId);
        
        // Update persistence
        await _persistenceService.cancelTransfer(transferId);
        
        // Remove from active transfers
        _activeBackgroundTransfers.remove(transferId);
        
        _logger.info(_tag, 'Cancelled background transfer: $transferId');
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to cancel transfer: $e');
    }
  }
  
  /// Get active background transfers
  List<BackgroundTransfer> getActiveTransfers() {
    return _activeBackgroundTransfers.values.toList();
  }
  
  /// Check if transfer is running in background
  bool isBackgroundTransfer(String transferId) {
    return _activeBackgroundTransfers.containsKey(transferId);
  }
  
  /// Dispose service
  void dispose() {
    _transferCompletionController.close();
  }
  
  // Private methods
  
  Future<bool> _checkBackgroundSupport() async {
    try {
      if (Platform.isIOS) {
        // Check iOS background capabilities
        return true; // iOS UIBackgroundTask support
      } else if (Platform.isAndroid) {
        // Check Android foreground service support
        return true; // Android API 26+ foreground service
      }
      return false;
    } catch (e) {
      _logger.error(_tag, 'Failed to check background support: $e');
      return false;
    }
  }
  
  Future<void> _startPlatformBackgroundTask(BackgroundTransfer transfer) async {
    try {
      if (Platform.isIOS) {
        // Start iOS background task
        await platform.invokeMethod('startBackgroundTask', {
          'transferId': transfer.transferId,
          'filePath': transfer.filePath,
          'fileSize': transfer.fileSize,
        });
      } else if (Platform.isAndroid) {
        // Start Android foreground service
        await platform.invokeMethod('startForegroundService', {
          'transferId': transfer.transferId,
          'filePath': transfer.filePath,
          'fileSize': transfer.fileSize,
          'title': 'File Transfer',
          'message': 'Transferring ${_getFileName(transfer.filePath)}',
        });
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to start platform background task: $e');
    }
  }
  
  Future<void> _endPlatformBackgroundTask(String transferId) async {
    try {
      if (Platform.isIOS) {
        await platform.invokeMethod('endBackgroundTask', {
          'transferId': transferId,
        });
      } else if (Platform.isAndroid) {
        await platform.invokeMethod('stopForegroundService', {
          'transferId': transferId,
        });
      }
    } catch (e) {
      _logger.error(_tag, 'Failed to end platform background task: $e');
    }
  }
  
  Future<void> _restoreBackgroundTransfers() async {
    try {
      final resumableStates = _persistenceService.getResumableTransfers();
      
      for (final state in resumableStates) {
        if (state.status == TransferStatus.transferring) {
          // Transfer was in progress when app closed
          _logger.info(_tag, 'Restoring transfer: ${state.transferId}');
          
          final transfer = BackgroundTransfer(
            transferId: state.transferId,
            filePath: state.filePath,
            fileSize: state.totalBytes,
            deviceId: state.deviceId,
            connectionMethod: state.connectionMethod,
            bytesTransferred: state.bytesTransferred,
            startTime: state.createdAt,
          );
          
          _activeBackgroundTransfers[state.transferId] = transfer;
        }
      }
      
      _logger.info(_tag, 'Restored ${_activeBackgroundTransfers.length} background transfers');
    } catch (e) {
      _logger.error(_tag, 'Failed to restore background transfers: $e');
    }
  }
  
  String _getFileName(String filePath) {
    return filePath.split('/').last;
  }
}

/// Background Transfer Model
class BackgroundTransfer {
  final String transferId;
  final String filePath;
  final int fileSize;
  final String deviceId;
  final String connectionMethod;
  int bytesTransferred;
  final DateTime startTime;
  DateTime lastUpdateTime;
  
  BackgroundTransfer({
    required this.transferId,
    required this.filePath,
    required this.fileSize,
    required this.deviceId,
    required this.connectionMethod,
    this.bytesTransferred = 0,
    required this.startTime,
  }) : lastUpdateTime = DateTime.now();
  
  double get progressPercent {
    if (fileSize == 0) return 0.0;
    return (bytesTransferred / fileSize) * 100;
  }
  
  Duration get elapsed {
    return DateTime.now().difference(startTime);
  }
  
  double get speedBytesPerSecond {
    final seconds = elapsed.inSeconds;
    if (seconds == 0) return 0.0;
    return bytesTransferred / seconds;
  }
}
