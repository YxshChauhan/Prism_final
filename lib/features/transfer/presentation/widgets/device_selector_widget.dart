import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/features/discovery/presentation/providers/discovery_provider.dart';

class DeviceSelectorWidget extends ConsumerWidget {
  const DeviceSelectorWidget({
    super.key,
    required this.files,
    required this.onSend,
  });

  final List<TransferFile> files;
  final Function(String deviceId) onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryState = ref.watch(discoveryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Select Device',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Files Summary
          _buildFilesSummary(),
          const SizedBox(height: 16),

          // Device List
          Expanded(
            child: discoveryState.when(
              data: (devices) => _buildDeviceList(context, devices),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load devices',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(discoveryProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSummary() {
    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final fileCount = files.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$fileCount file${fileCount == 1 ? '' : 's'} • ${_formatFileSize(totalSize)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, List<Device> devices) {
    if (devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure other devices are nearby and have AirLink open',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _buildDeviceTile(context, device);
      },
    );
  }

  Widget _buildDeviceTile(BuildContext context, Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getDeviceColor(device.type),
          child: Icon(
            _getDeviceIcon(device.type),
            color: Colors.white,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.ipAddress ?? 'Unknown IP'),
            if (device.metadata['deviceModel'] != null)
              Text(
                device.metadata['deviceModel'] as String,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (device.rssi != null)
              Row(
                children: [
                  Icon(
                    Icons.signal_cellular_alt,
                    size: 16,
                    color: _getSignalColor(device.rssi!),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${device.rssi} dBm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
        trailing: _getStatusChip(device.isConnected),
        onTap: !device.isConnected
            ? () => onSend(device.id)
            : null,
      ),
    );
  }

  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return Colors.green;
      case DeviceType.ios:
        return Colors.blue;
      case DeviceType.desktop:
        return Colors.purple;
      case DeviceType.windows:
        return Colors.blue;
      case DeviceType.mac:
        return Colors.grey;
      case DeviceType.linux:
        return Colors.orange;
      case DeviceType.unknown:
        return Colors.grey;
    }
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return Icons.android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.desktop:
        return Icons.desktop_windows;
      case DeviceType.windows:
        return Icons.computer;
      case DeviceType.mac:
        return Icons.laptop_mac;
      case DeviceType.linux:
        return Icons.computer;
      case DeviceType.unknown:
        return Icons.device_unknown;
    }
  }

  Color _getSignalColor(int strength) {
    if (strength >= 80) return Colors.green;
    if (strength >= 60) return Colors.orange;
    if (strength >= 40) return Colors.red;
    return Colors.grey;
  }

  Widget _getStatusChip(bool isConnected) {
    Color color;
    String text;

    if (isConnected) {
      color = Colors.blue;
      text = 'Connected';
    } else {
      color = Colors.grey;
      text = 'Available';
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
