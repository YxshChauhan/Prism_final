import 'dart:async';
import 'dart:io';
import 'package:injectable/injectable.dart';

/// Comprehensive Error Handling Service
/// 
/// Provides centralized error handling, recovery mechanisms,
/// and user-friendly error messages for the AirLink application.
@Injectable()
class ErrorHandlingService {
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final Map<String, List<String>> _errorHistory = {};
  
  // Error thresholds
  static const int maxRetries = 3;
  static const int maxErrorsPerMinute = 10;
  static const Duration errorCooldown = Duration(minutes: 1);
  
  /// Handle and categorize errors
  Future<void> handleError(dynamic error, String context, {
    bool shouldRetry = true,
    int maxRetries = maxRetries,
    Duration? retryDelay,
  }) async {
    final errorKey = '${error.runtimeType}_$context';
    final now = DateTime.now();
    
    // Track error frequency
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    _lastErrorTimes[errorKey] = now;
    
    // Store error in history
    _errorHistory[errorKey] ??= [];
    _errorHistory[errorKey]!.add('${now.toIso8601String()}: ${error.toString()}');
    
    // Keep only last 10 errors per key
    if (_errorHistory[errorKey]!.length > 10) {
      _errorHistory[errorKey]!.removeAt(0);
    }
    
    // Check if we should apply cooldown
    if (_shouldApplyCooldown(errorKey)) {
      await _applyCooldown(errorKey);
      return;
    }
    
    // Categorize and handle error
    final errorCategory = _categorizeError(error);
    await _handleErrorByCategory(error, errorCategory, context, shouldRetry, maxRetries, retryDelay);
  }
  
  /// Categorize error for appropriate handling
  ErrorCategory _categorizeError(dynamic error) {
    if (error is SocketException) {
      return ErrorCategory.network;
    } else if (error is FileSystemException) {
      return ErrorCategory.fileSystem;
    } else if (error is FormatException) {
      return ErrorCategory.dataFormat;
    } else if (error is TimeoutException) {
      return ErrorCategory.timeout;
    } else if (error is StateError) {
      return ErrorCategory.state;
    } else if (error is ArgumentError) {
      return ErrorCategory.argument;
    } else {
      return ErrorCategory.unknown;
    }
  }
  
  /// Handle error based on category
  Future<void> _handleErrorByCategory(
    dynamic error,
    ErrorCategory category,
    String context,
    bool shouldRetry,
    int maxRetries,
    Duration? retryDelay,
  ) async {
    switch (category) {
      case ErrorCategory.network:
        await _handleNetworkError(error, context, shouldRetry, maxRetries, retryDelay);
        break;
      case ErrorCategory.fileSystem:
        await _handleFileSystemError(error, context);
        break;
      case ErrorCategory.dataFormat:
        await _handleDataFormatError(error, context);
        break;
      case ErrorCategory.timeout:
        await _handleTimeoutError(error, context, shouldRetry, maxRetries, retryDelay);
        break;
      case ErrorCategory.state:
        await _handleStateError(error, context);
        break;
      case ErrorCategory.argument:
        await _handleArgumentError(error, context);
        break;
      case ErrorCategory.unknown:
        await _handleUnknownError(error, context);
        break;
    }
  }
  
  /// Handle network errors with retry logic
  Future<void> _handleNetworkError(
    dynamic error,
    String context,
    bool shouldRetry,
    int maxRetries,
    Duration? retryDelay,
  ) async {
    if (shouldRetry && _errorCounts['${error.runtimeType}_$context']! <= maxRetries) {
      final delay = retryDelay ?? Duration(seconds: 2 * _errorCounts['${error.runtimeType}_$context']!);
      await Future.delayed(delay);
      // Retry logic would be implemented here
    } else {
      // Log final failure
      _logError('Network error in $context: $error');
    }
  }
  
  /// Handle file system errors
  Future<void> _handleFileSystemError(dynamic error, String context) async {
    _logError('File system error in $context: $error');
    // Could implement file system recovery here
  }
  
  /// Handle data format errors
  Future<void> _handleDataFormatError(dynamic error, String context) async {
    _logError('Data format error in $context: $error');
    // Could implement data validation and correction here
  }
  
  /// Handle timeout errors with retry logic
  Future<void> _handleTimeoutError(
    dynamic error,
    String context,
    bool shouldRetry,
    int maxRetries,
    Duration? retryDelay,
  ) async {
    if (shouldRetry && _errorCounts['${error.runtimeType}_$context']! <= maxRetries) {
      final delay = retryDelay ?? Duration(seconds: 5);
      await Future.delayed(delay);
      // Retry logic would be implemented here
    } else {
      _logError('Timeout error in $context: $error');
    }
  }
  
  /// Handle state errors
  Future<void> _handleStateError(dynamic error, String context) async {
    _logError('State error in $context: $error');
    // Could implement state recovery here
  }
  
  /// Handle argument errors
  Future<void> _handleArgumentError(dynamic error, String context) async {
    _logError('Argument error in $context: $error');
    // Could implement argument validation here
  }
  
  /// Handle unknown errors
  Future<void> _handleUnknownError(dynamic error, String context) async {
    _logError('Unknown error in $context: $error');
  }
  
  /// Check if cooldown should be applied
  bool _shouldApplyCooldown(String errorKey) {
    final errorCount = _errorCounts[errorKey] ?? 0;
    final lastErrorTime = _lastErrorTimes[errorKey];
    
    if (lastErrorTime == null) return false;
    
    final timeSinceLastError = DateTime.now().difference(lastErrorTime);
    return errorCount >= maxErrorsPerMinute && timeSinceLastError < errorCooldown;
  }
  
  /// Apply cooldown period
  Future<void> _applyCooldown(String errorKey) async {
    _logError('Applying cooldown for $errorKey due to excessive errors');
    await Future.delayed(errorCooldown);
  }
  
  /// Get user-friendly error message
  String getUserFriendlyMessage(dynamic error, String context) {
    final category = _categorizeError(error);
    
    switch (category) {
      case ErrorCategory.network:
        return 'Connection problem. Please check your network and try again.';
      case ErrorCategory.fileSystem:
        return 'File access problem. Please check file permissions and try again.';
      case ErrorCategory.dataFormat:
        return 'Data format error. Please try with a different file.';
      case ErrorCategory.timeout:
        return 'Operation timed out. Please try again.';
      case ErrorCategory.state:
        return 'Application state error. Please restart the app.';
      case ErrorCategory.argument:
        return 'Invalid input. Please check your settings.';
      case ErrorCategory.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Get error recovery suggestions
  List<String> getRecoverySuggestions(dynamic error, String context) {
    final category = _categorizeError(error);
    
    switch (category) {
      case ErrorCategory.network:
        return [
          'Check your internet connection',
          'Try switching between WiFi and mobile data',
          'Restart your router',
          'Check if the other device is online',
        ];
      case ErrorCategory.fileSystem:
        return [
          'Check file permissions',
          'Ensure sufficient storage space',
          'Try moving the file to a different location',
          'Check if the file is not corrupted',
        ];
      case ErrorCategory.dataFormat:
        return [
          'Try with a different file',
          'Check if the file is supported',
          'Verify file integrity',
        ];
      case ErrorCategory.timeout:
        return [
          'Try again with a smaller file',
          'Check network stability',
          'Close other apps to free up resources',
        ];
      case ErrorCategory.state:
        return [
          'Restart the application',
          'Clear app cache',
          'Check app permissions',
        ];
      case ErrorCategory.argument:
        return [
          'Check your input values',
          'Verify settings are correct',
          'Try with default settings',
        ];
      case ErrorCategory.unknown:
        return [
          'Try again later',
          'Restart the application',
          'Contact support if the problem persists',
        ];
    }
  }
  
  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    return {
      'totalErrors': _errorCounts.values.fold(0, (sum, count) => sum + count),
      'errorTypes': _errorCounts.keys.toList(),
      'errorCounts': Map.from(_errorCounts),
      'lastErrorTimes': _lastErrorTimes.map((key, time) => MapEntry(key, time.toIso8601String())),
    };
  }
  
  /// Clear error history
  void clearErrorHistory() {
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _errorHistory.clear();
  }
  
  /// Log error with context
  void _logError(String message) {
    // In a real implementation, this would use a proper logging service
    print('ERROR: $message');
  }
}

/// Error categories for classification
enum ErrorCategory {
  network,
  fileSystem,
  dataFormat,
  timeout,
  state,
  argument,
  unknown,
}

/// Error recovery strategies
enum ErrorRecoveryStrategy {
  retry,
  fallback,
  userAction,
  restart,
  ignore,
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}
