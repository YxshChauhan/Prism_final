import 'package:flutter/material.dart';
import 'package:airlink/core/services/error_handling_service.dart';

/// Enhanced Error Widget
/// 
/// Provides user-friendly error display with recovery suggestions
/// and categorized error handling for better user experience.
class EnhancedErrorWidget extends StatefulWidget {
  final dynamic error;
  final String context;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showRecoverySuggestions;
  final bool showErrorDetails;
  
  const EnhancedErrorWidget({
    super.key,
    required this.error,
    required this.context,
    this.onRetry,
    this.onDismiss,
    this.showRecoverySuggestions = true,
    this.showErrorDetails = false,
  });

  @override
  State<EnhancedErrorWidget> createState() => _EnhancedErrorWidgetState();
}

class _EnhancedErrorWidgetState extends State<EnhancedErrorWidget> {
  final ErrorHandlingService _errorHandlingService = ErrorHandlingService();
  
  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorHandlingService.getUserFriendlyMessage(widget.error, widget.context);
    final suggestions = widget.showRecoverySuggestions 
        ? _errorHandlingService.getRecoverySuggestions(widget.error, widget.context)
        : <String>[];
    
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error header
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error in ${widget.context.replaceAll('_', ' ')}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onDismiss,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Error message
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            
            // Recovery suggestions
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRecoverySuggestions(suggestions),
            ],
            
            // Error details (if enabled)
            if (widget.showErrorDetails) ...[
              const SizedBox(height: 16),
              _buildErrorDetails(),
            ],
            
            // Action buttons
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecoverySuggestions(List<String> suggestions) {
    return ExpansionTile(
      title: Text(
        'Recovery Suggestions',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: suggestions.map((suggestion) => ListTile(
        leading: Icon(
          Icons.lightbulb_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
          size: 20,
        ),
        title: Text(
          suggestion,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      )).toList(),
    );
  }
  
  Widget _buildErrorDetails() {
    return ExpansionTile(
      title: Text(
        'Technical Details',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            widget.error.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.onRetry != null)
          ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        if (widget.onRetry != null && widget.onDismiss != null)
          const SizedBox(width: 12),
        if (widget.onDismiss != null)
          OutlinedButton.icon(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.close),
            label: const Text('Dismiss'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }
}

/// Error Snackbar Widget
/// 
/// Shows error messages as snackbars with recovery actions.
class ErrorSnackbar {
  static void show(
    BuildContext context,
    dynamic error,
    String contextName, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final errorHandlingService = ErrorHandlingService();
    final errorMessage = errorHandlingService.getUserFriendlyMessage(error, contextName);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        duration: duration,
        action: onRetry != null ? SnackBarAction(
          label: 'Retry',
          onPressed: onRetry,
        ) : null,
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Error Dialog Widget
/// 
/// Shows error messages as dialogs with detailed information.
class ErrorDialog {
  static void show(
    BuildContext context,
    dynamic error,
    String contextName, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error in ${contextName.replaceAll('_', ' ')}'),
        content: EnhancedErrorWidget(
          error: error,
          context: contextName,
          onRetry: onRetry,
          onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
          showRecoverySuggestions: true,
          showErrorDetails: true,
        ),
        actions: [
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
