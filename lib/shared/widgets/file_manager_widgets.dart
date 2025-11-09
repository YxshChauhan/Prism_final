import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/utils/format_utils.dart';

/// File List Item Widget
class FileListItem extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onFavoriteToggle;

  const FileListItem({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _getFileIcon(),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatFileSize(file.size)} • ${_formatDate(file.modifiedAt)}'),
            if (file.category.name.isNotEmpty)
              Text(
                file.category.name.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFavoriteToggle != null)
              IconButton(
                onPressed: onFavoriteToggle,
                icon: Icon(
                  file.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: file.isFavorite ? Colors.red : null,
                ),
                tooltip: file.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              ),
            const Icon(Icons.more_vert),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _getFileIcon() {
    if (file.isDirectory) {
      return const Icon(Icons.folder, color: Colors.blue);
    }

    switch (file.category) {
      case FileCategory.image:
        return const Icon(Icons.image, color: Colors.green);
      case FileCategory.video:
        return const Icon(Icons.video_library, color: Colors.purple);
      case FileCategory.audio:
        return const Icon(Icons.audiotrack, color: Colors.orange);
      case FileCategory.document:
        return const Icon(Icons.description, color: Colors.blue);
      case FileCategory.archive:
        return const Icon(Icons.archive, color: Colors.brown);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

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

/// File Grid Item Widget
class FileGridItem extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileGridItem({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: _getCategoryColor().withValues(alpha: 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _getFileIcon(),
                    if (file.isDirectory)
                      const SizedBox(height: 4),
                    if (file.isDirectory)
                      Text(
                        '${_countFiles()} items',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(file.size),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getFileIcon() {
    if (file.isDirectory) {
      return const Icon(Icons.folder);
    }

    switch (file.category) {
      case FileCategory.image:
        return const Icon(Icons.image);
      case FileCategory.video:
        return const Icon(Icons.video_library);
      case FileCategory.audio:
        return const Icon(Icons.audiotrack);
      case FileCategory.document:
        return const Icon(Icons.description);
      case FileCategory.archive:
        return const Icon(Icons.archive);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  Color _getCategoryColor() {
    if (file.isDirectory) return Colors.blue;

    switch (file.category) {
      case FileCategory.image:
        return Colors.green;
      case FileCategory.video:
        return Colors.purple;
      case FileCategory.audio:
        return Colors.orange;
      case FileCategory.document:
        return Colors.blue;
      case FileCategory.archive:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _countFiles() {
    // TODO: Get actual file count for directories
    return '0';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Storage Analyzer Widget
class StorageAnalyzerWidget extends StatelessWidget {
  final StorageInfo storageInfo;
  final Function(String) onCategoryTap;

  const StorageAnalyzerWidget({
    super.key,
    required this.storageInfo,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Storage overview
          _buildStorageOverview(context),
          const SizedBox(height: 24),
          
          // Storage breakdown
          _buildStorageBreakdown(context),
          const SizedBox(height: 24),
          
          // Quick actions
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildStorageOverview(BuildContext context) {
    final usedPercentage = storageInfo.totalSpace > 0
        ? storageInfo.usedSpace / storageInfo.totalSpace
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Storage bar
            LinearProgressIndicator(
              value: usedPercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                usedPercentage > 0.9 ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            
            // Storage info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Used: ${FormatUtils.formatBytes(storageInfo.usedSpace)}'),
                Text('Free: ${FormatUtils.formatBytes(storageInfo.freeSpace)}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${FormatUtils.formatBytes(storageInfo.totalSpace)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBreakdown(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Breakdown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Category breakdown
            ...storageInfo.categoryBreakdown.entries.map((entry) {
              final category = entry.key;
              final size = entry.value;
              final percentage = storageInfo.totalSpace > 0
                  ? size / storageInfo.totalSpace
                  : 0.0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => onCategoryTap(category.name),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          _getCategoryDisplayName(category.name),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getCategoryColor(category.name),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.formatBytes(size),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.find_in_page,
                    label: 'Find Duplicates',
                    onTap: () => _findDuplicates(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.delete_sweep,
                    label: 'Clean Storage',
                    onTap: () => _cleanStorage(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.analytics,
                    label: 'Storage Analysis',
                    onTap: () => _showStorageAnalysis(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.settings,
                    label: 'Storage Settings',
                    onTap: () => _showStorageSettings(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'image':
        return 'Images';
      case 'video':
        return 'Videos';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Documents';
      case 'archive':
        return 'Archives';
      case 'app':
        return 'Apps';
      default:
        return category.toUpperCase();
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.purple;
      case 'audio':
        return Colors.orange;
      case 'document':
        return Colors.blue;
      case 'archive':
        return Colors.brown;
      case 'app':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  void _findDuplicates(BuildContext context) {
    // TODO: Navigate to duplicate finder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finding duplicate files...')),
    );
  }

  void _cleanStorage(BuildContext context) {
    // TODO: Navigate to storage cleaner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleaning storage...')),
    );
  }

  void _showStorageAnalysis(BuildContext context) {
    // TODO: Show detailed storage analysis
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening storage analysis...')),
    );
  }

  void _showStorageSettings(BuildContext context) {
    // TODO: Navigate to storage settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening storage settings...')),
    );
  }
}

/// File Options Sheet
class FileOptionsSheet extends StatelessWidget {
  final FileItem file;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onProperties;

  const FileOptionsSheet({
    super.key,
    required this.file,
    required this.onOpen,
    required this.onRename,
    required this.onCopy,
    required this.onMove,
    required this.onDelete,
    required this.onShare,
    required this.onProperties,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File info
          ListTile(
            leading: _getFileIcon(),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${_formatFileSize(file.size)} • ${_formatDate(file.modifiedAt)}'),
          ),
          const Divider(),
          
          // Options
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(context);
              onOpen();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              onRename();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(context);
              onCopy();
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: const Text('Move'),
            onTap: () {
              Navigator.pop(context);
              onMove();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              onShare();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Properties'),
            onTap: () {
              Navigator.pop(context);
              onProperties();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }

  Widget _getFileIcon() {
    if (file.isDirectory) {
      return const Icon(Icons.folder, color: Colors.blue);
    }

    switch (file.category) {
      case FileCategory.image:
        return const Icon(Icons.image, color: Colors.green);
      case FileCategory.video:
        return const Icon(Icons.video_library, color: Colors.purple);
      case FileCategory.audio:
        return const Icon(Icons.audiotrack, color: Colors.orange);
      case FileCategory.document:
        return const Icon(Icons.description, color: Colors.blue);
      case FileCategory.archive:
        return const Icon(Icons.archive, color: Colors.brown);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

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

/// File Properties Dialog
class FilePropertiesDialog extends StatelessWidget {
  final FileItem file;

  const FilePropertiesDialog({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('File Properties'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPropertyRow('Name', file.name),
            _buildPropertyRow('Size', _formatFileSize(file.size)),
            _buildPropertyRow('Type', file.category.name.isNotEmpty ? file.category.name.toUpperCase() : 'Unknown'),
            _buildPropertyRow('Location', file.path),
            _buildPropertyRow('Created', _formatDate(file.createdAt)),
            _buildPropertyRow('Modified', _formatDate(file.modifiedAt)),
            _buildPropertyRow('Accessed', _formatDate(file.accessedAt)),
            _buildPropertyRow('Hidden', file.isHidden ? 'Yes' : 'No'),
            _buildPropertyRow('Favorite', file.isFavorite ? 'Yes' : 'No'),
            if (file.checksum.isNotEmpty)
              _buildPropertyRow('Checksum', file.checksum),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// File Item Card Widget
class FileItemCard extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onOpen;
  final VoidCallback? onMenu;

  const FileItemCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
    this.onOpen,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_getFileIcon()),
        title: Text(file.name),
        subtitle: Text('${_formatFileSize(file.size)} • ${_formatDate(file.modifiedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpen != null)
              IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
              ),
            if (onMenu != null)
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  IconData _getFileIcon() {
    switch (file.category) {
      case FileCategory.image:
        return Icons.image;
      case FileCategory.video:
        return Icons.video_file;
      case FileCategory.audio:
        return Icons.audio_file;
      case FileCategory.document:
        return Icons.description;
      case FileCategory.archive:
        return Icons.archive;
      case FileCategory.apk:
        return Icons.android;
      case FileCategory.other:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }
}

/// Storage Info Dialog
class StorageInfoDialog extends StatelessWidget {
  const StorageInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Storage Information'),
      content: const Text('Storage information will be displayed here.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
