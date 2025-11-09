import 'package:flutter/material.dart';
import 'package:airlink/core/services/apk_extractor_service.dart' hide ExtractionHistoryItem;
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/utils/format_utils.dart';

/// App Card Widget
class AppCard extends StatelessWidget {
  final AppInfo app;
  final bool isSelected;
  final bool isExtracting;
  final double extractionProgress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onExtract;

  const AppCard({
    super.key,
    required this.app,
    required this.isSelected,
    required this.isExtracting,
    required this.extractionProgress,
    required this.onTap,
    required this.onLongPress,
    required this.onExtract,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected 
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // App icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: app.iconPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              app.iconPath!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.android, size: 24),
                  ),
                  const SizedBox(width: 12),
                  
                  // App info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.appName,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          app.packageName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'v${app.versionName} • ${_formatFileSize(app.size)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  
                  // Selection indicator
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.blue),
                  
                  // Extract button
                  IconButton(
                    onPressed: isExtracting ? null : onExtract,
                    icon: isExtracting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: extractionProgress,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.file_download),
                    tooltip: isExtracting ? 'Extracting...' : 'Extract APK',
                  ),
                ],
              ),
              
              // Extraction progress
              if (isExtracting) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: extractionProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(extractionProgress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              
              // App type indicators
              const SizedBox(height: 8),
              Row(
                children: [
                  if (app.isSystemApp)
                    _buildChip('System', Colors.orange),
                  if (app.isUserApp)
                    _buildChip('User', Colors.green),
                  _buildChip(app.versionName, Colors.blue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Extracted APK Card Widget
class ExtractedApkCard extends StatelessWidget {
  final String packageName;
  final String apkPath;
  final VoidCallback onInstall;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onInfo;

  const ExtractedApkCard({
    super.key,
    required this.packageName,
    required this.apkPath,
    required this.onInstall,
    required this.onShare,
    required this.onDelete,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.android, color: Colors.green),
        title: Text(
          packageName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          apkPath,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'install':
                onInstall();
                break;
              case 'share':
                onShare();
                break;
              case 'info':
                onInfo();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'install',
              child: ListTile(
                leading: Icon(Icons.install_mobile),
                title: Text('Install'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share),
                title: Text('Share'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App Options Sheet
class AppOptionsSheet extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onExtract;
  final VoidCallback onInfo;
  final VoidCallback onUninstall;
  final VoidCallback onPermissions;

  const AppOptionsSheet({
    super.key,
    required this.app,
    required this.onExtract,
    required this.onInfo,
    required this.onUninstall,
    required this.onPermissions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App info header
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: app.iconPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        app.iconPath!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.android, size: 24),
            ),
            title: Text(
              app.appName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'v${app.versionName} • ${_formatFileSize(app.size)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          
          // Options
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Extract APK'),
            onTap: () {
              Navigator.pop(context);
              onExtract();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Info'),
            onTap: () {
              Navigator.pop(context);
              onInfo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Permissions'),
            onTap: () {
              Navigator.pop(context);
              onPermissions();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Uninstall', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              onUninstall();
            },
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
}

/// App Info Dialog
class AppInfoDialog extends StatelessWidget {
  final AppInfo app;

  const AppInfoDialog({
    super.key,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('App Information'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon and basic info
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: app.iconPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            app.iconPath!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.android, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        app.packageName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Version ${app.versionName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Detailed information
            _buildInfoRow('App Name', app.appName),
            _buildInfoRow('Package Name', app.packageName),
            _buildInfoRow('Version Name', app.versionName),
            _buildInfoRow('Version Code', app.versionCode.toString()),
            _buildInfoRow('Size', _formatFileSize(app.size)),
            _buildInfoRow('Install Date', _formatDate(app.installDate)),
            _buildInfoRow('Update Date', _formatDate(app.updateDate)),
            _buildInfoRow('Type', app.isSystemApp ? 'System App' : 'User App'),
            if (app.sourceDir != null)
              _buildInfoRow('Source Directory', app.sourceDir!),
            if (app.dataDir != null)
              _buildInfoRow('Data Directory', app.dataDir!),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

/// App Permissions Dialog
class AppPermissionsDialog extends StatelessWidget {
  final String appName;
  final List<String> permissions;

  const AppPermissionsDialog({
    super.key,
    required this.appName,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$appName Permissions'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: permissions.length,
          itemBuilder: (context, index) {
            final permission = permissions[index];
            return ListTile(
              leading: _getPermissionIcon(permission),
              title: Text(
                _getPermissionDisplayName(permission),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                permission,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            );
          },
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

  Widget _getPermissionIcon(String permission) {
    if (permission.contains('CAMERA')) {
      return const Icon(Icons.camera_alt, color: Colors.blue);
    } else if (permission.contains('LOCATION')) {
      return const Icon(Icons.location_on, color: Colors.green);
    } else if (permission.contains('STORAGE')) {
      return const Icon(Icons.storage, color: Colors.orange);
    } else if (permission.contains('MICROPHONE')) {
      return const Icon(Icons.mic, color: Colors.red);
    } else if (permission.contains('CONTACTS')) {
      return const Icon(Icons.contacts, color: Colors.purple);
    } else if (permission.contains('PHONE')) {
      return const Icon(Icons.phone, color: Colors.teal);
    } else if (permission.contains('SMS')) {
      return const Icon(Icons.sms, color: Colors.indigo);
    } else {
      return const Icon(Icons.security, color: Colors.grey);
    }
  }

  String _getPermissionDisplayName(String permission) {
    // Extract the permission name from the full permission string
    final parts = permission.split('.');
    if (parts.isNotEmpty) {
      final name = parts.last;
      return name.replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
        return word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '';
      }).join(' ');
    }
    return permission;
  }
}

/// Extraction History Card Widget
class ExtractionHistoryCard extends StatelessWidget {
  final ExtractionHistoryItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ExtractionHistoryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.android),
        title: Text(item.appName),
        subtitle: Text('${FormatUtils.formatBytes(item.size)} • ${_formatDate(item.extractedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
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

/// APK Info Dialog
class ApkInfoDialog extends StatelessWidget {
  final ExtractedApk apk;

  const ApkInfoDialog({
    super.key,
    required this.apk,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(apk.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Package: ${apk.packageName}'),
          Text('Size: ${FormatUtils.formatBytes(apk.size)}'),
          Text('Extracted: ${_formatDate(apk.extractedAt)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
