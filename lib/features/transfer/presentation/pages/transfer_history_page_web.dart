import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/app_providers_web.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;

/// Web version of the transfer history page
class TransferHistoryPageWeb extends ConsumerWidget {
  const TransferHistoryPageWeb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferHistory = ref.watch(transferHistoryProviderWeb);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showFilterDialog(context),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: transferHistory.isEmpty
          ? _buildEmptyState(context)
          : _buildHistoryList(context, transferHistory),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Transfer History',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed transfers will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<unified.TransferSession> transfers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _buildTransferItem(context, transfer);
      },
    );
  }

  Widget _buildTransferItem(BuildContext context, unified.TransferSession transfer) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildDirectionIcon(transfer.direction),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.files.isNotEmpty 
                            ? transfer.files.first.name
                            : 'Unknown File',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transfer.files.length} file${transfer.files.length == 1 ? '' : 's'} • ${_formatFileSize(transfer.totalBytes)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(context, transfer.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _getConnectionIcon(transfer.connectionMethod),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatConnectionMethod(transfer.connectionMethod),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(transfer.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (transfer.status == unified.TransferStatus.transferring) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: transfer.totalBytes > 0 
                    ? transfer.bytesTransferred / transfer.totalBytes
                    : 0.0,
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatFileSize(transfer.bytesTransferred)} / ${_formatFileSize(transfer.totalBytes)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (transfer.files.length > 1) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: Text(
                  'View all files (${transfer.files.length})',
                  style: theme.textTheme.bodyMedium,
                ),
                children: transfer.files.map((file) => ListTile(
                  leading: Icon(_getFileIcon(file.mimeType)),
                  title: Text(file.name),
                  subtitle: Text(_formatFileSize(file.size)),
                  dense: true,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionIcon(unified.TransferDirection direction) {
    final color = direction == unified.TransferDirection.sent 
        ? Colors.blue 
        : Colors.green;
    final icon = direction == unified.TransferDirection.sent 
        ? Icons.north_east 
        : Icons.south_west;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, unified.TransferStatus status) {
    final theme = Theme.of(context);
    final color = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.completed:
        return Colors.green;
      case unified.TransferStatus.failed:
        return Colors.red;
      case unified.TransferStatus.cancelled:
        return Colors.grey;
      case unified.TransferStatus.transferring:
        return Colors.blue;
      case unified.TransferStatus.paused:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.completed:
        return 'Completed';
      case unified.TransferStatus.failed:
        return 'Failed';
      case unified.TransferStatus.cancelled:
        return 'Cancelled';
      case unified.TransferStatus.transferring:
        return 'In Progress';
      case unified.TransferStatus.paused:
        return 'Paused';
      case unified.TransferStatus.pending:
        return 'Pending';
      case unified.TransferStatus.connecting:
        return 'Connecting';
      case unified.TransferStatus.handshaking:
        return 'Handshaking';
      case unified.TransferStatus.resuming:
        return 'Resuming';
    }
  }

  IconData _getConnectionIcon(String connectionMethod) {
    switch (connectionMethod) {
      case 'wifi_aware':
        return Icons.wifi;
      case 'ble':
        return Icons.bluetooth;
      case 'multipeer':
        return Icons.device_hub;
      default:
        return Icons.device_unknown;
    }
  }

  String _formatConnectionMethod(String connectionMethod) {
    switch (connectionMethod) {
      case 'wifi_aware':
        return 'Wi-Fi Aware';
      case 'ble':
        return 'Bluetooth LE';
      case 'multipeer':
        return 'Multipeer';
      default:
        return connectionMethod.toUpperCase();
    }
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    if (mimeType.contains('document')) return Icons.description;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(1)} ${units[unit]}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Transfers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Sent'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Received'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Completed'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Failed'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}