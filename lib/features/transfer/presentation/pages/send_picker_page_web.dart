import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/app_providers_web.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Web version of the send picker page
class SendPickerPageWeb extends ConsumerStatefulWidget {
  const SendPickerPageWeb({super.key});

  @override
  ConsumerState<SendPickerPageWeb> createState() => _SendPickerPageWebState();
}

class _SendPickerPageWebState extends ConsumerState<SendPickerPageWeb> {
  final List<DemoFile> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearbyDevices = ref.watch(nearbyDevicesProviderWeb);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File selection section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select Files to Send',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Web Demo: Click to simulate file selection',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFileTypeButton(
                          context,
                          'Photos',
                          Icons.photo,
                          Colors.green,
                          () => _simulateFileSelection('Photos', 'image/jpeg'),
                        ),
                        _buildFileTypeButton(
                          context,
                          'Videos',
                          Icons.videocam,
                          Colors.purple,
                          () => _simulateFileSelection('Videos', 'video/mp4'),
                        ),
                        _buildFileTypeButton(
                          context,
                          'Documents',
                          Icons.description,
                          Colors.blue,
                          () => _simulateFileSelection('Documents', 'application/pdf'),
                        ),
                        _buildFileTypeButton(
                          context,
                          'Music',
                          Icons.audiotrack,
                          Colors.orange,
                          () => _simulateFileSelection('Music', 'audio/mp3'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selected files section
            if (_selectedFiles.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Selected Files (${_selectedFiles.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._selectedFiles.map((file) => _buildSelectedFileItem(context, file)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Device selection section
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.devices,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select Destination Device',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (nearbyDevices.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.devices_other,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No devices found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Start discovery to find nearby devices',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: nearbyDevices.length,
                            itemBuilder: (context, index) {
                              final device = nearbyDevices[index];
                              return _buildDeviceItem(context, device);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTypeButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildSelectedFileItem(BuildContext context, DemoFile file) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            file.icon,
            color: file.color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  file.size,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedFiles.remove(file);
              });
            },
            icon: const Icon(Icons.close),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, Device device) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: device.isConnected 
              ? Colors.green.withValues(alpha: 0.2)
              : theme.colorScheme.primaryContainer,
          child: Icon(
            _getDeviceIcon(device.type),
            color: device.isConnected 
                ? Colors.green
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          device.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${device.type.name.toUpperCase()} • ${device.isConnected ? 'Connected' : 'Available'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: _selectedFiles.isNotEmpty
            ? ElevatedButton(
                onPressed: () => _simulateTransfer(device),
                child: const Text('Send'),
              )
            : null,
        onTap: _selectedFiles.isNotEmpty
            ? () => _simulateTransfer(device)
            : null,
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return Icons.android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.mac:
        return Icons.laptop_mac;
      case DeviceType.windows:
        return Icons.laptop_windows;
      case DeviceType.linux:
        return Icons.computer;
      default:
        return Icons.device_unknown;
    }
  }

  void _simulateFileSelection(String type, String mimeType) {
    setState(() {
      final file = DemoFile(
        name: 'demo_${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.${_getExtension(mimeType)}',
        size: '${(1 + (DateTime.now().millisecondsSinceEpoch % 100))} MB',
        mimeType: mimeType,
        icon: _getIconForMimeType(mimeType),
        color: _getColorForMimeType(mimeType),
      );
      _selectedFiles.add(file);
    });
  }

  String _getExtension(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'video/mp4':
        return 'mp4';
      case 'application/pdf':
        return 'pdf';
      case 'audio/mp3':
        return 'mp3';
      default:
        return 'file';
    }
  }

  IconData _getIconForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Color _getColorForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.green;
    if (mimeType.startsWith('video/')) return Colors.purple;
    if (mimeType.startsWith('audio/')) return Colors.orange;
    if (mimeType == 'application/pdf') return Colors.red;
    return Colors.grey;
  }

  void _simulateTransfer(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Started'),
        content: Text(
          'Simulating transfer of ${_selectedFiles.length} file(s) to ${device.name}.\n\n'
          'In a real app, this would initiate the actual file transfer process.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(currentPageProviderWeb.notifier).state = AppPage.history;
            },
            child: const Text('View History'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class DemoFile {
  final String name;
  final String size;
  final String mimeType;
  final IconData icon;
  final Color color;

  DemoFile({
    required this.name,
    required this.size,
    required this.mimeType,
    required this.icon,
    required this.color,
  });
}