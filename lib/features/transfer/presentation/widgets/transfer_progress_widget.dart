import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/transfer/presentation/providers/transfer_provider.dart';

class TransferProgressWidget extends ConsumerWidget {
  const TransferProgressWidget({
    super.key,
    required this.file,
    required this.sessionId,
  });

  final unified.TransferFile file;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(transferProgressProvider(sessionId));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Info
            Row(
              children: [
                _buildFileIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatFileSize(file.size),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(progressState),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress Bar
            progressState.when(
              data: (progress) => _buildProgressBar(context, progress),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => _buildErrorState(error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    IconData iconData;
    Color iconColor;

    // Infer icon from mimeType
    if (file.mimeType.startsWith('image/')) {
        iconData = Icons.image;
        iconColor = Colors.blue;
    } else if (file.mimeType.startsWith('video/')) {
        iconData = Icons.videocam;
        iconColor = Colors.purple;
    } else if (file.mimeType.startsWith('text/') || file.mimeType.contains('pdf')) {
        iconData = Icons.description;
        iconColor = Colors.orange;
    } else if (file.mimeType.startsWith('audio/')) {
        iconData = Icons.audiotrack;
        iconColor = Colors.green;
    } else {
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildStatusIcon(AsyncValue<unified.TransferProgress> progressState) {
    return progressState.when(
      data: (progress) {
        switch (progress.status) {
          case unified.TransferStatus.pending:
            return const Icon(Icons.schedule, color: Colors.orange);
          case unified.TransferStatus.transferring:
            return const Icon(Icons.sync, color: Colors.blue);
          case unified.TransferStatus.paused:
            return const Icon(Icons.pause, color: Colors.amber);
          case unified.TransferStatus.connecting:
            return const Icon(Icons.wifi_tethering, color: Colors.blueGrey);
          case unified.TransferStatus.handshaking:
            return Icon(_iconOrFallback(Icons.handshake, Icons.sync_alt), color: Colors.indigo);
          case unified.TransferStatus.resuming:
            return const Icon(Icons.play_arrow, color: Colors.teal);
          case unified.TransferStatus.completed:
            return const Icon(Icons.check_circle, color: Colors.green);
          case unified.TransferStatus.failed:
            return const Icon(Icons.error, color: Colors.red);
          case unified.TransferStatus.cancelled:
            return const Icon(Icons.cancel, color: Colors.grey);
        }
      },
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => const Icon(Icons.error, color: Colors.red),
    );
  }

  Widget _buildProgressBar(BuildContext context, unified.TransferProgress progress) {
    final percentage = progress.totalBytes > 0
        ? progress.bytesTransferred / progress.totalBytes
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress Bar
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(progress.status),
          ),
        ),
        const SizedBox(height: 8),
        
        // Progress Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatFileSize(progress.bytesTransferred)} / ${_formatFileSize(progress.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${(percentage * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        
        // Speed and Time
        if (progress.speed > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatFileSize(progress.speed.round())}/s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                _formatTimeRemaining(
                  (progress.totalBytes - progress.bytesTransferred) / progress.speed,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Transfer failed: $error',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return Colors.orange;
      case unified.TransferStatus.transferring:
        return Colors.blue;
      case unified.TransferStatus.paused:
        return Colors.amber;
      case unified.TransferStatus.connecting:
        return Colors.blueGrey;
      case unified.TransferStatus.handshaking:
        return Colors.indigo;
      case unified.TransferStatus.resuming:
        return Colors.teal;
      case unified.TransferStatus.completed:
        return Colors.green;
      case unified.TransferStatus.failed:
        return Colors.red;
      case unified.TransferStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTimeRemaining(double seconds) {
    if (seconds < 60) {
      return '${seconds.round()}s remaining';
    } else if (seconds < 3600) {
      return '${(seconds / 60).round()}m remaining';
    } else {
      return '${(seconds / 3600).round()}h remaining';
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
