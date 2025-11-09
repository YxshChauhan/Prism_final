import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/error_handling_service.dart';
import 'dart:async';
import 'dart:io';

/// Error types for categorizing different failure scenarios
enum ErrorType {
  network,
  permission,
  platform,
  transfer,
  crypto,
  nativeTransport,
  connection,
  fileSystem,
  timeout,
  unknown,
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Error recovery strategies
enum RecoveryStrategy {
  retry,
  fallback,
  userAction,
  restart,
  none,
}

/// Custom exception classes for better error handling
class NetworkError extends Error {
  final String message;
  NetworkError(this.message);
  @override
  String toString() => 'NetworkError: $message';
}

class PermissionError extends Error {
  final String message;
  final String permission;
  PermissionError(this.message, this.permission);
  @override
  String toString() => 'PermissionError: $message (permission: $permission)';
}

class PlatformError extends Error {
  final String message;
  final String? platformDetails;
  PlatformError(this.message, [this.platformDetails]);
  @override
  String toString() =>
      'PlatformError: $message${platformDetails != null ? ' ($platformDetails)' : ''}';
}

class TransferError extends Error {
  final String message;
  final String? transferId;
  TransferError(this.message, [this.transferId]);
  @override
  String toString() =>
      'TransferError: $message${transferId != null ? ' (ID: $transferId)' : ''}';
}

class CryptoError extends Error {
  final String message;
  CryptoError(this.message);
  @override
  String toString() => 'CryptoError: $message';
}

class NativeTransportError extends Error {
  final String message;
  final String? transportType;
  final String? connectionToken;
  NativeTransportError(this.message, {this.transportType, this.connectionToken});
  @override
  String toString() => 'NativeTransportError: $message${transportType != null ? ' (transport: $transportType)' : ''}';
}

class ConnectionError extends Error {
  final String message;
  final String? deviceId;
  final String? connectionMethod;
  ConnectionError(this.message, {this.deviceId, this.connectionMethod});
  @override
  String toString() => 'ConnectionError: $message${deviceId != null ? ' (device: $deviceId)' : ''}';
}

class FileSystemError extends Error {
  final String message;
  final String? filePath;
  final String? operation;
  FileSystemError(this.message, {this.filePath, this.operation});
  @override
  String toString() => 'FileSystemError: $message${filePath != null ? ' (file: $filePath)' : ''}';
}

class TimeoutError extends Error {
  final String message;
  final Duration timeout;
  final String? operation;
  TimeoutError(this.message, this.timeout, {this.operation});
  @override
  String toString() => 'TimeoutError: $message (timeout: ${timeout.inSeconds}s)';
}

/// Enhanced error information
class ErrorInfo {
  final ErrorType type;
  final ErrorSeverity severity;
  final RecoveryStrategy recoveryStrategy;
  final String message;
  final String? details;
  final DateTime timestamp;
  final Map<String, dynamic>? context;
  final bool isRecoverable;
  final int retryCount;
  final int maxRetries;

  const ErrorInfo({
    required this.type,
    required this.severity,
    required this.recoveryStrategy,
    required this.message,
    this.details,
    required this.timestamp,
    this.context,
    this.isRecoverable = true,
    this.retryCount = 0,
    this.maxRetries = 3,
  });

  ErrorInfo copyWith({
    ErrorType? type,
    ErrorSeverity? severity,
    RecoveryStrategy? recoveryStrategy,
    String? message,
    String? details,
    DateTime? timestamp,
    Map<String, dynamic>? context,
    bool? isRecoverable,
    int? retryCount,
    int? maxRetries,
  }) {
    return ErrorInfo(
      type: type ?? this.type,
      severity: severity ?? this.severity,
      recoveryStrategy: recoveryStrategy ?? this.recoveryStrategy,
      message: message ?? this.message,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
      context: context ?? this.context,
      isRecoverable: isRecoverable ?? this.isRecoverable,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }
}

/// Widget that catches and handles errors from child widgets
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;
  final bool enableAutoRecovery;
  final Duration retryDelay;
  final int maxRetries;
  final bool enableErrorReporting;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.errorBuilder,
    this.enableAutoRecovery = true,
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetries = 3,
    this.enableErrorReporting = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  FlutterExceptionHandler? _previousHandler;
  ErrorInfo? _errorInfo;
  int _retryCount = 0;
  Timer? _retryTimer;
  final LoggerService _loggerService = LoggerService();
  final ErrorHandlingService _errorHandlingService = ErrorHandlingService();

  @override
  void initState() {
    super.initState();
    // Save the previous error handler and set our own
    _previousHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    // Restore the previous error handler
    FlutterError.onError = _previousHandler;
    super.dispose();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    if (mounted) {
      final errorInfo = _analyzeError(details.exception, details.stack);
      
      // Use SchedulerBinding to defer setState until after the current build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = details.exception;
            _stackTrace = details.stack;
            _errorInfo = errorInfo;
          });
        }
      });
      
      // Log error
      _loggerService.error('Error caught by ErrorBoundary: ${details.exception}');
      
      // Report error if enabled
      if (widget.enableErrorReporting) {
        _errorHandlingService.handleError(
          details.exception,
          'error_boundary',
          shouldRetry: errorInfo.isRecoverable,
          maxRetries: errorInfo.maxRetries,
          retryDelay: widget.retryDelay,
        );
      }
      
      // Call the custom error handler if provided
      widget.onError?.call(details.exception, details.stack ?? StackTrace.current);
      
      // Attempt auto-recovery if enabled
      if (widget.enableAutoRecovery && errorInfo.isRecoverable) {
        _attemptAutoRecovery(errorInfo);
      }
      
      // Call the previous handler to ensure upstream handling
      _previousHandler?.call(details);
    }
  }

  ErrorInfo _analyzeError(Object error, StackTrace? stackTrace) {
    final ErrorType type = _getErrorType(error);
    final ErrorSeverity severity = _getErrorSeverity(error, type);
    final RecoveryStrategy strategy = _getRecoveryStrategy(type, severity);
    
    return ErrorInfo(
      type: type,
      severity: severity,
      recoveryStrategy: strategy,
      message: error.toString(),
      details: stackTrace?.toString(),
      timestamp: DateTime.now(),
      context: _getErrorContext(error),
      isRecoverable: _isRecoverable(type, severity),
      retryCount: _retryCount,
      maxRetries: widget.maxRetries,
    );
  }

  ErrorType _getErrorType(Object error) {
    if (error is NetworkError) return ErrorType.network;
    if (error is PermissionError) return ErrorType.permission;
    if (error is PlatformError) return ErrorType.platform;
    if (error is TransferError) return ErrorType.transfer;
    if (error is CryptoError) return ErrorType.crypto;
    if (error is NativeTransportError) return ErrorType.nativeTransport;
    if (error is ConnectionError) return ErrorType.connection;
    if (error is FileSystemError) return ErrorType.fileSystem;
    if (error is TimeoutError) return ErrorType.timeout;
    return ErrorType.unknown;
  }

  ErrorSeverity _getErrorSeverity(Object error, ErrorType type) {
    if (error is TimeoutError) return ErrorSeverity.medium;
    if (error is NetworkError) return ErrorSeverity.high;
    if (error is PermissionError) return ErrorSeverity.high;
    if (error is PlatformError) return ErrorSeverity.critical;
    if (error is TransferError) return ErrorSeverity.medium;
    if (error is CryptoError) return ErrorSeverity.critical;
    if (error is NativeTransportError) return ErrorSeverity.high;
    if (error is ConnectionError) return ErrorSeverity.high;
    if (error is FileSystemError) return ErrorSeverity.medium;
    return ErrorSeverity.medium;
  }

  RecoveryStrategy _getRecoveryStrategy(ErrorType type, ErrorSeverity severity) {
    switch (type) {
      case ErrorType.network:
        return RecoveryStrategy.retry;
      case ErrorType.permission:
        return RecoveryStrategy.userAction;
      case ErrorType.platform:
        return RecoveryStrategy.restart;
      case ErrorType.transfer:
        return RecoveryStrategy.retry;
      case ErrorType.crypto:
        return RecoveryStrategy.fallback;
      case ErrorType.nativeTransport:
        return RecoveryStrategy.retry;
      case ErrorType.connection:
        return RecoveryStrategy.retry;
      case ErrorType.fileSystem:
        return RecoveryStrategy.userAction;
      case ErrorType.timeout:
        return RecoveryStrategy.retry;
      case ErrorType.unknown:
        return RecoveryStrategy.none;
    }
  }

  bool _isRecoverable(ErrorType type, ErrorSeverity severity) {
    if (severity == ErrorSeverity.critical) return false;
    return type != ErrorType.platform && type != ErrorType.crypto;
  }

  Map<String, dynamic> _getErrorContext(Object error) {
    final context = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (error is NativeTransportError) {
      context['transportType'] = error.transportType;
      context['connectionToken'] = error.connectionToken;
    } else if (error is ConnectionError) {
      context['deviceId'] = error.deviceId;
      context['connectionMethod'] = error.connectionMethod;
    } else if (error is FileSystemError) {
      context['filePath'] = error.filePath;
      context['operation'] = error.operation;
    } else if (error is TimeoutError) {
      context['timeout'] = error.timeout.inSeconds;
      context['operation'] = error.operation;
    }
    
    return context;
  }

  void _attemptAutoRecovery(ErrorInfo errorInfo) {
    if (_retryCount >= errorInfo.maxRetries) {
      _loggerService.warning('Max retry attempts reached for error: ${errorInfo.message}');
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(widget.retryDelay, () {
      if (mounted) {
        _retryCount++;
        _loggerService.info('Attempting auto-recovery (attempt $_retryCount/${errorInfo.maxRetries})');
        _clearError();
      }
    });
  }

  void _clearError() {
    setState(() {
      _error = null;
      _stackTrace = null;
      _errorInfo = null;
    });
    _retryCount = 0;
    _retryTimer?.cancel();
  }

  void _manualRetry() {
    _retryCount = 0;
    _clearError();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _stackTrace != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace!) ??
          ErrorScreen(
            error: _error!,
            stackTrace: _stackTrace!,
            errorInfo: _errorInfo,
            onRetry: _manualRetry,
            onDismiss: _clearError,
          );
    }
    
    return widget.child;
  }
}

/// Full-screen error display widget
class ErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;
  final ErrorInfo? errorInfo;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.stackTrace,
    this.errorInfo,
    this.onRetry,
    this.onDismiss,
  });

  ErrorType _getErrorType(Object error) {
    if (error is NetworkError) return ErrorType.network;
    if (error is PermissionError) return ErrorType.permission;
    if (error is PlatformError) return ErrorType.platform;
    if (error is TransferError) return ErrorType.transfer;
    if (error is CryptoError) return ErrorType.crypto;
    if (error is NativeTransportError) return ErrorType.nativeTransport;
    if (error is ConnectionError) return ErrorType.connection;
    if (error is FileSystemError) return ErrorType.fileSystem;
    if (error is TimeoutError) return ErrorType.timeout;
    return ErrorType.unknown;
  }

  IconData _getErrorIcon(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.permission:
        return Icons.lock;
      case ErrorType.platform:
        return Icons.phonelink_erase;
      case ErrorType.transfer:
        return Icons.sync_problem;
      case ErrorType.crypto:
        return Icons.security;
      case ErrorType.nativeTransport:
        return Icons.bluetooth;
      case ErrorType.connection:
        return Icons.link_off;
      case ErrorType.fileSystem:
        return Icons.folder_off;
      case ErrorType.timeout:
        return Icons.timer_off;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.permission:
        return 'Permission Required';
      case ErrorType.platform:
        return 'Platform Error';
      case ErrorType.transfer:
        return 'Transfer Failed';
      case ErrorType.crypto:
        return 'Security Error';
      case ErrorType.nativeTransport:
        return 'Transport Error';
      case ErrorType.connection:
        return 'Connection Failed';
      case ErrorType.fileSystem:
        return 'File System Error';
      case ErrorType.timeout:
        return 'Operation Timeout';
      case ErrorType.unknown:
        return 'Something Went Wrong';
    }
  }

  String _getSuggestion(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Please check your internet connection and try again.';
      case ErrorType.permission:
        return 'Grant the required permissions to continue.';
      case ErrorType.platform:
        return 'There was a problem communicating with the system.';
      case ErrorType.transfer:
        return 'The file transfer could not be completed.';
      case ErrorType.crypto:
        return 'There was a problem with encryption/decryption.';
      case ErrorType.nativeTransport:
        return 'There was a problem with the native transport layer.';
      case ErrorType.connection:
        return 'Failed to establish connection with the device.';
      case ErrorType.fileSystem:
        return 'There was a problem accessing the file system.';
      case ErrorType.timeout:
        return 'The operation took too long to complete.';
      case ErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ErrorType errorType = _getErrorType(error);
    final ThemeData theme = Theme.of(context);
    final bool isRecoverable = errorInfo?.isRecoverable ?? true;
    final int retryCount = errorInfo?.retryCount ?? 0;
    final int maxRetries = errorInfo?.maxRetries ?? 3;
    
    return Material(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getErrorIcon(errorType),
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                _getErrorTitle(errorType),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getSuggestion(errorType),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (retryCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Retry attempt $retryCount of $maxRetries',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              if (kDebugMode) ...[
                ExpansionTile(
                  title: const Text('Technical Details'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        '$error\n\n$stackTrace',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onRetry != null && isRecoverable)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  if (onRetry != null && isRecoverable) const SizedBox(width: 16),
                  if (onDismiss != null)
                    OutlinedButton.icon(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close),
                      label: const Text('Dismiss'),
                    ),
                  if (onDismiss != null) const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}

/// Inline error banner widget
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              color: theme.colorScheme.onErrorContainer,
            ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              color: theme.colorScheme.onErrorContainer,
            ),
        ],
      ),
    );
  }
}

