import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized error handling service
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Handle and display errors to users
  static void handleError(
    BuildContext context,
    dynamic error, {
    String? title,
    String? customMessage,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    String message = customMessage ?? _getErrorMessage(error);
    String errorTitle = title ?? 'Error';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(errorTitle),
        content: Text(message),
        actions: [
          if (onDismiss != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss();
              },
              child: const Text('Dismiss'),
            ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    String title = 'Success',
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    String title = 'Warning',
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info message
  static void showInfo(
    BuildContext context,
    String message, {
    String title = 'Info',
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error is String) return error;
    
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }
    
    // Permission errors
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please grant the required permissions in settings.';
    }
    
    // Bluetooth errors
    if (errorString.contains('bluetooth') || errorString.contains('ble')) {
      return 'Bluetooth error. Please ensure Bluetooth is enabled and try again.';
    }
    
    // Wi-Fi errors
    if (errorString.contains('wifi') || errorString.contains('aware')) {
      return 'Wi-Fi error. Please ensure Wi-Fi is enabled and try again.';
    }
    
    // File errors
    if (errorString.contains('file') || errorString.contains('storage')) {
      return 'File operation failed. Please check file permissions and try again.';
    }
    
    // Transfer errors
    if (errorString.contains('transfer') || errorString.contains('send') || errorString.contains('receive')) {
      return 'Transfer failed. Please try again or check your connection.';
    }
    
    // Discovery errors
    if (errorString.contains('discovery') || errorString.contains('scan')) {
      return 'Device discovery failed. Please try again.';
    }
    
    // Generic error
    return 'An unexpected error occurred. Please try again.';
  }

  /// Handle specific error types
  static void handleDiscoveryError(BuildContext context, dynamic error) {
    handleError(
      context,
      error,
      title: 'Discovery Error',
      customMessage: 'Failed to discover nearby devices. Please ensure Bluetooth and Wi-Fi are enabled.',
      onRetry: () {
        // Retry discovery logic would go here
      },
    );
  }

  static void handleTransferError(BuildContext context, dynamic error) {
    handleError(
      context,
      error,
      title: 'Transfer Error',
      customMessage: 'File transfer failed. Please check your connection and try again.',
      onRetry: () {
        // Retry transfer logic would go here
      },
    );
  }

  static void handleConnectionError(BuildContext context, dynamic error) {
    handleError(
      context,
      error,
      title: 'Connection Error',
      customMessage: 'Failed to connect to device. Please ensure the device is nearby and try again.',
      onRetry: () {
        // Retry connection logic would go here
      },
    );
  }

  static void handlePermissionError(BuildContext context, dynamic error) {
    handleError(
      context,
      error,
      title: 'Permission Required',
      customMessage: 'AirLink needs location and Bluetooth permissions to discover nearby devices.',
      onRetry: () {
        // Open app settings logic would go here
      },
    );
  }
}

/// Error handler provider for dependency injection
final errorHandlerProvider = Provider<ErrorHandler>((ref) => ErrorHandler());
