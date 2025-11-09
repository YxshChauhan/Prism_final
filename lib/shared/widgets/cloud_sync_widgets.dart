import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Cloud Provider Card Widget
class CloudProviderCard extends StatelessWidget {
  final CloudProvider provider;
  final VoidCallback onDisconnect;
  final VoidCallback onSettings;
  final VoidCallback onStorageInfo;

  const CloudProviderCard({
    super.key,
    required this.provider,
    required this.onDisconnect,
    required this.onSettings,
    required this.onStorageInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _getProviderIcon(),
        title: Text(provider.name.isNotEmpty ? provider.name : _getProviderName()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${provider.type}'),
            if (provider.isConnected)
              const Text('Connected', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'settings':
                onSettings();
                break;
              case 'storage':
                onStorageInfo();
                break;
              case 'disconnect':
                onDisconnect();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'storage',
              child: ListTile(
                leading: Icon(Icons.storage),
                title: Text('Storage Info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'disconnect',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Disconnect', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getProviderIcon() {
    switch (provider.type) {
      case 'googleDrive':
        return const Icon(Icons.cloud, color: Colors.blue);
      case 'dropbox':
        return const Icon(Icons.folder, color: Colors.blue);
      case 'oneDrive':
        return const Icon(Icons.business, color: Colors.blue);
      case 'iCloud':
        return const Icon(Icons.apple, color: Colors.grey);
      default:
        return const Icon(Icons.cloud, color: Colors.grey);
    }
  }

  String _getProviderName() {
    switch (provider.type) {
      case 'googleDrive':
        return 'Google Drive';
      case 'dropbox':
        return 'Dropbox';
      case 'oneDrive':
        return 'OneDrive';
      case 'iCloud':
        return 'iCloud';
      default:
        return provider.name;
    }
  }

  // Removed unused _formatDate helper to clean dead code
}

/// Sync Job Card Widget
class SyncJobCard extends StatelessWidget {
  final SyncStatus job;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const SyncJobCard({
    super.key,
    required this.job,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getProviderName(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _getStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            
            if (job.localPath != null && job.remotePath != null)
              Text(
                '${job.localPath} ↔ ${job.remotePath}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            
            // Progress bar
            LinearProgressIndicator(
              value: job.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStatusColor(),
              ),
            ),
            const SizedBox(height: 4),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${job.filesProcessed ?? 0}/${job.totalFiles ?? 0} files',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${(job.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Action buttons
            Row(
              children: [
                if (job.status == 'active')
                  TextButton.icon(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Pause'),
                  )
                else if (job.status == 'paused')
                  TextButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Resume'),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusChip() {
    Color color;
    String text;
    
    switch (job.status) {
      case 'active':
        color = Colors.green;
        text = 'Active';
        break;
      case 'paused':
        color = Colors.orange;
        text = 'Paused';
        break;
      case 'completed':
        color = Colors.blue;
        text = 'Completed';
        break;
      case 'failed':
        color = Colors.red;
        text = 'Failed';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (job.status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getProviderName() {
    return job.name;
  }
}

/// Sync History Card Widget
class SyncHistoryCard extends StatelessWidget {
  final SyncHistoryItem item;
  final VoidCallback onRetry;
  final VoidCallback onViewDetails;

  const SyncHistoryCard({
    super.key,
    required this.item,
    required this.onRetry,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _getStatusIcon(),
        title: Text(item.action),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.providerName} • ${_formatDate(item.timestamp)}'),
            Text('Files: ${item.fileCount}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getStatusChip(),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'retry':
                    onRetry();
                    break;
                  case 'details':
                    onViewDetails();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (item.status == 'failed')
                  const PopupMenuItem(
                    value: 'retry',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Retry'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'details',
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('Details'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onViewDetails,
      ),
    );
  }

  Widget _getStatusIcon() {
    switch (item.status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'failed':
        return const Icon(Icons.error, color: Colors.red);
      case 'inProgress':
        return const Icon(Icons.sync, color: Colors.blue);
      case 'pending':
        return const Icon(Icons.schedule, color: Colors.orange);
      default:
        return const Icon(Icons.help, color: Colors.grey);
    }
  }

  Widget _getStatusChip() {
    Color color;
    String text;
    
    switch (item.status) {
      case 'completed':
        color = Colors.green;
        text = 'Completed';
        break;
      case 'failed':
        color = Colors.red;
        text = 'Failed';
        break;
      case 'inProgress':
        color = Colors.blue;
        text = 'In Progress';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Using item.providerName inline; removed unused _getProviderName

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Cloud Storage Info Widget
class CloudStorageInfoWidget extends StatelessWidget {
  final CloudStorageInfo storageInfo;

  const CloudStorageInfoWidget({
    super.key,
    required this.storageInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getProviderName(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            // Storage bar
            LinearProgressIndicator(
              value: storageInfo.usagePercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                storageInfo.usagePercentage > 0.9 ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            
            // Storage details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Used: ${storageInfo.usedSpaceFormatted}'),
                Text('Free: ${storageInfo.freeSpaceFormatted}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${storageInfo.totalSpaceFormatted}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Usage: ${(storageInfo.usagePercentage * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: storageInfo.usagePercentage > 0.9 ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProviderName() {
    if (storageInfo.provider == null) return 'Unknown Provider';
    switch (storageInfo.provider) {
      case 'googleDrive':
        return 'Google Drive';
      case 'dropbox':
        return 'Dropbox';
      case 'oneDrive':
        return 'OneDrive';
      case 'iCloud':
        return 'iCloud';
      default:
        return storageInfo.provider ?? 'Unknown Provider';
    }
  }
}
