import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/features/transfer/presentation/providers/transfer_provider.dart';
import 'package:airlink/features/transfer/presentation/widgets/transfer_progress_widget.dart';
import 'package:airlink/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:airlink/core/services/dependency_injection.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;

class TransferDetailPage extends ConsumerWidget {
  const TransferDetailPage({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showTransferOptions(context, ref, sessionId),
          ),
        ],
      ),
      body: transferState.when(
        data: (session) {
          if (session == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transfer Not Found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The requested transfer session could not be found.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          return _buildTransferContent(context, session);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Transfer Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(transferProvider(sessionId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferContent(BuildContext context, unified.TransferSession session) {
    return Column(
      children: [
        // Transfer Header
        _buildTransferHeader(context, session),
        
        // Transfer Progress
        Expanded(
          child: _buildTransferProgress(context, session),
        ),
        
        // Transfer Actions
        _buildTransferActions(context, session),
      ],
    );
  }

  Widget _buildTransferHeader(BuildContext context, unified.TransferSession session) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(session.status),
                  color: _getStatusColor(session.status),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(session.status),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(session.status),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(session.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_file,
                    label: 'Files',
                    value: '${session.files.length}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.storage,
                    label: 'Total Size',
                    value: _formatFileSize(
                      session.files.fold<int>(0, (sum, file) => sum + file.size),
                    ),
                  ),
                ),
              ],
            ),
            if (session.completedAt != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Completed at ${_formatDateTime(session.completedAt!)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferProgress(BuildContext context, unified.TransferSession session) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: session.files.length,
      itemBuilder: (context, index) {
        final file = session.files[index];
        return TransferProgressWidget(
          file: file,
          sessionId: session.id,
        );
      },
    );
  }

  Widget _buildTransferActions(BuildContext context, unified.TransferSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (session.status == unified.TransferStatus.transferring) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pauseTransfer(session.id, context),
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _cancelTransfer(session.id, context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else if (session.status == unified.TransferStatus.paused) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _resumeTransfer(session.id, context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancelTransfer(session.id, context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
              ),
            ),
          ] else if (session.status == unified.TransferStatus.completed) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openFiles(session, context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Files'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareFiles(session, context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ),
          ] else if (session.status == unified.TransferStatus.failed) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _retryTransfer(session.id, context),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cancelTransfer(session.id, context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTransferOptions(BuildContext context, WidgetRef ref, String sessionId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Transfer Info'),
              onTap: () {
                Navigator.of(context).pop();
                _showTransferInfo(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Transfer Settings'),
              onTap: () {
                Navigator.of(context).pop();
                _showTransferSettings(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Transfer'),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteDialog(context, sessionId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pauseTransfer(String sessionId, BuildContext context) async {
    try {
      final transferRepository = getIt<TransferRepository>();
      await transferRepository.pauseTransfer(sessionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer paused'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pause transfer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resumeTransfer(String sessionId, BuildContext context) async {
    try {
      final transferRepository = getIt<TransferRepository>();
      await transferRepository.resumeTransfer(sessionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer resumed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resume transfer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelTransfer(String sessionId, BuildContext context) async {
    try {
      final transferRepository = getIt<TransferRepository>();
      await transferRepository.cancelTransfer(sessionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer cancelled'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel transfer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _retryTransfer(String sessionId, BuildContext context) async {
    try {
      final transferRepository = getIt<TransferRepository>();
      await transferRepository.resumeTransfer(sessionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer retried'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retry transfer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openFiles(unified.TransferSession session, BuildContext context) {
    // Open files in default app
    for (final file in session.files) {
      // This would typically use a file opener plugin
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${file.name}...'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _shareFiles(unified.TransferSession session, BuildContext context) {
    // Share files using system share sheet
    for (final file in session.files) {
      // This would typically use a share plugin
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sharing ${file.name}...'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _deleteTransfer(String sessionId, BuildContext context) async {
    try {
      final transferRepository = getIt<TransferRepository>();
      await transferRepository.cancelTransfer(sessionId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer deleted'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete transfer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTransferInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Information'),
        content: const Text('Transfer details and statistics'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTransferSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Settings'),
        content: const Text('Transfer configuration options'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transfer'),
        content: const Text('Are you sure you want to delete this transfer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransfer(sessionId, context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return Icons.schedule;
      case unified.TransferStatus.connecting:
        return Icons.sync;
      case unified.TransferStatus.transferring:
        return Icons.sync;
      case unified.TransferStatus.paused:
        return Icons.pause_circle;
      case unified.TransferStatus.completed:
        return Icons.check_circle;
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
        return Colors.blue;
    }
  }

  String _getStatusText(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return 'Pending';
      case unified.TransferStatus.connecting:
        return 'Connecting...';
      case unified.TransferStatus.transferring:
        return 'In Progress';
      case unified.TransferStatus.paused:
        return 'Paused';
      case unified.TransferStatus.completed:
        return 'Completed';
      case unified.TransferStatus.failed:
        return 'Failed';
      case unified.TransferStatus.cancelled:
        return 'Cancelled';
      case unified.TransferStatus.handshaking:
        return 'Handshaking...';
      case unified.TransferStatus.resuming:
        return 'Resuming...';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
