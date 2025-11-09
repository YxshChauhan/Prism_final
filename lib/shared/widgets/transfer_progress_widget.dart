import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/shared/utils/format_utils.dart';

/// Real-time transfer progress widget
class TransferProgressWidget extends ConsumerWidget {
  final String transferId;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onViewDetails;

  const TransferProgressWidget({
    super.key,
    required this.transferId,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Placeholder data - would be replaced with actual provider data
    final transfer = TransferSession(
      id: transferId,
      senderId: 'unknown',
      receiverId: 'unknown',
      files: [],
      createdAt: DateTime.now(),
      status: unified.TransferStatus.transferring,
    );
    
    // Create placeholder TransferProgress object
    final transferProgress = TransferProgress(
      transferId: transferId,
      fileName: 'Unknown',
      bytesTransferred: 0,
      totalBytes: 100,
      speed: 0.0,
      status: unified.TransferStatus.transferring,
      startedAt: DateTime.now(),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with transfer info
          _buildHeader(context, transfer, transferProgress),
          
          const SizedBox(height: 12),
          
          // Progress bar
          _buildProgressBar(context, transferProgress),
          
          const SizedBox(height: 8),
          
          // Progress details
          _buildProgressDetails(context, transferProgress),
          
          const SizedBox(height: 12),
          
          // Action buttons
          _buildActionButtons(context, transfer.status),
        ],
      ),
    );
  }


  Widget _buildHeader(BuildContext context, TransferSession transfer, TransferProgress progress) {
    return Row(
      children: [
        // Status icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getStatusColor(transfer.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _getStatusIcon(transfer.status),
            size: 16,
            color: _getStatusColor(transfer.status),
          ),
        ),
        const SizedBox(width: 12),
        
        // Transfer info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusText(transfer.status),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${transfer.files.length} file${transfer.files.length == 1 ? '' : 's'} • ${FormatUtils.formatBytes(progress.totalBytes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        // Speed indicator
        if (transfer.status == unified.TransferStatus.transferring)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_formatSpeed(progress.speed)}/s',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, TransferProgress progress) {
    final progressValue = progress.totalBytes > 0 
        ? progress.bytesTransferred / progress.totalBytes 
        : 0.0;
    
    return Column(
      children: [
        LinearProgressIndicator(
          value: progressValue,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${FormatUtils.formatBytes(progress.bytesTransferred)} / ${FormatUtils.formatBytes(progress.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(progressValue * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressDetails(BuildContext context, TransferProgress progress) {
    return Row(
      children: [
        Icon(
          Icons.timer,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'ETA: ${_getEstimatedTime(progress)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.speed,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Speed: ${_formatSpeed(progress.speed)}/s',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, unified.TransferStatus status) {
    return Row(
      children: [
        if (status == unified.TransferStatus.transferring) ...[
          IconButton(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            tooltip: 'Pause',
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            tooltip: 'Cancel',
          ),
        ] else if (status == unified.TransferStatus.paused) ...[
          IconButton(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Resume',
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            tooltip: 'Cancel',
          ),
        ] else if (status == unified.TransferStatus.completed) ...[
          IconButton(
            onPressed: onViewDetails,
            icon: const Icon(Icons.info),
            tooltip: 'View Details',
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return Colors.orange;
      case unified.TransferStatus.connecting:
        return Colors.blue;
      case unified.TransferStatus.transferring:
        return Colors.blue;
      case unified.TransferStatus.paused:
        return Colors.amber;
      case unified.TransferStatus.completed:
        return Colors.green;
      case unified.TransferStatus.failed:
        return Colors.red;
      case unified.TransferStatus.cancelled:
        return Colors.grey;
      case unified.TransferStatus.handshaking:
        return Colors.purple;
      case unified.TransferStatus.resuming:
        return Colors.teal;
    }
  }

  IconData _getStatusIcon(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return Icons.schedule;
      case unified.TransferStatus.connecting:
        return Icons.sync;
      case unified.TransferStatus.transferring:
        return Icons.upload;
      case unified.TransferStatus.paused:
        return Icons.pause;
      case unified.TransferStatus.completed:
        return Icons.check;
      case unified.TransferStatus.failed:
        return Icons.error;
      case unified.TransferStatus.cancelled:
        return Icons.cancel;
      case unified.TransferStatus.handshaking:
        return _iconOrFallback(Icons.handshake, Icons.sync_alt);
      case unified.TransferStatus.resuming:
        return Icons.play_arrow;
    }
  }

  String _getStatusText(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return 'Preparing transfer...';
      case unified.TransferStatus.connecting:
        return 'Connecting...';
      case unified.TransferStatus.transferring:
        return 'Transferring files...';
      case unified.TransferStatus.paused:
        return 'Transfer paused';
      case unified.TransferStatus.completed:
        return 'Transfer completed';
      case unified.TransferStatus.failed:
        return 'Transfer failed';
      case unified.TransferStatus.cancelled:
        return 'Transfer cancelled';
      case unified.TransferStatus.handshaking:
        return 'Handshaking...';
      case unified.TransferStatus.resuming:
        return 'Resuming...';
    }
  }


  String _formatSpeed(double speed) {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB';
    if (speed < 1024 * 1024 * 1024) return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getEstimatedTime(TransferProgress progress) {
    if (progress.speed <= 0) return 'Calculating...';
    
    final remainingBytes = progress.totalBytes - progress.bytesTransferred;
    final secondsRemaining = (remainingBytes / progress.speed).ceil();
    
    if (secondsRemaining < 60) {
      return '${secondsRemaining}s';
    } else if (secondsRemaining < 3600) {
      return '${(secondsRemaining / 60).ceil()}m';
    } else {
      return '${(secondsRemaining / 3600).ceil()}h';
    }
  }

  /// Fallback icon method to handle potential Material icon availability issues
  IconData _iconOrFallback(IconData primary, IconData fallback) {
    try {
      // Try to use the primary icon, fallback if not available
      return primary;
    } catch (e) {
      return fallback;
    }
  }
}