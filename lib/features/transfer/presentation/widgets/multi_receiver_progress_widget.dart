import 'package:flutter/material.dart';
import 'package:airlink/core/services/group_sharing_service.dart';
import 'package:airlink/shared/models/transfer_models.dart';

/// Widget to display progress for multi-receiver transfers
/// Shows individual progress for each recipient with color-coded status
class MultiReceiverProgressWidget extends StatelessWidget {
  final MultiReceiverTransferResult transferResult;
  final VoidCallback? onCancel;
  final Function(String receiverId)? onCancelReceiver;
  
  const MultiReceiverProgressWidget({
    super.key,
    required this.transferResult,
    this.onCancel,
    this.onCancelReceiver,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall header
            _buildOverallHeader(context),
            const SizedBox(height: 16),
            
            // Overall progress bar
            _buildOverallProgress(context),
            const SizedBox(height: 16),
            
            // Statistics row
            _buildStatisticsRow(context),
            const SizedBox(height: 16),
            
            // Divider
            const Divider(),
            const SizedBox(height: 8),
            
            // Individual receiver progress
            Text(
              'Per-Recipient Progress',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Receiver list
            ...transferResult.receiverStatuses.values.map((status) {
              return _buildReceiverCard(context, status);
            }).toList(),
            
            // Cancel all button
            if (onCancel != null && !transferResult.isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('Cancel All Transfers'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOverallHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Multi-Receiver Transfer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sending to ${transferResult.totalReceivers} devices',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildStatusIcon(context),
      ],
    );
  }
  
  Widget _buildStatusIcon(BuildContext context) {
    if (transferResult.isCompleted) {
      if (transferResult.hasFailures) {
        return const Icon(Icons.warning, color: Colors.orange, size: 32);
      } else {
        return const Icon(Icons.check_circle, color: Colors.green, size: 32);
      }
    } else {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
  }
  
  Widget _buildOverallProgress(BuildContext context) {
    final progress = transferResult.overallProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Progress',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(progress),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatisticsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          context,
          icon: Icons.check_circle_outline,
          label: 'Completed',
          value: '${transferResult.completedCount}',
          color: Colors.green,
        ),
        _buildStatItem(
          context,
          icon: Icons.sync,
          label: 'In Progress',
          value: '${transferResult.inProgressCount}',
          color: Colors.blue,
        ),
        _buildStatItem(
          context,
          icon: Icons.error_outline,
          label: 'Failed',
          value: '${transferResult.failedCount}',
          color: Colors.red,
        ),
      ],
    );
  }
  
  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildReceiverCard(BuildContext context, ReceiverTransferStatus status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: _getReceiverCardColor(status),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receiver name and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(status.status),
                      color: _getStatusColor(status.status),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.receiverName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status.status),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStatusText(status.status),
                  style: TextStyle(
                    color: _getStatusColor(status.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Cancel button for individual receiver
              if (onCancelReceiver != null && status.status == TransferStatus.transferring)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onCancelReceiver!(status.receiverId),
                  tooltip: 'Cancel this transfer',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          
          // Progress bar (only for in-progress transfers)
          if (status.status == TransferStatus.transferring) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: status.progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(status.status),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(status.progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatBytes(status.bytesTransferred, status.totalBytes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
          
          // Error message (if failed)
          if (status.status == TransferStatus.failed && status.error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    status.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          
          // Completion time (if completed)
          if (status.status == TransferStatus.completed && status.completedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Completed at ${_formatTime(status.completedAt!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.5) return Colors.blue;
    return Colors.orange;
  }
  
  Color _getReceiverCardColor(ReceiverTransferStatus status) {
    switch (status.status) {
      case TransferStatus.completed:
        return Colors.green.withValues(alpha: 0.05);
      case TransferStatus.failed:
        return Colors.red.withValues(alpha: 0.05);
      default:
        return Colors.transparent;
    }
  }
  
  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.transferring:
        return Icons.sync;
      case TransferStatus.paused:
        return Icons.pause_circle;
      case TransferStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }
  
  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.transferring:
        return Colors.blue;
      case TransferStatus.paused:
        return Colors.orange;
      case TransferStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.transferring:
        return 'Transferring';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
  
  String _formatBytes(int bytes, int total) {
    final mb = bytes / (1024 * 1024);
    final totalMb = total / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB';
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
