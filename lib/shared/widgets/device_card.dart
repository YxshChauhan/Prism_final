import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Device card widget for displaying discovered devices
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final bool showConnectionStatus;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.showConnectionStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Row(
            children: [
              // Device icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getDeviceColor(context, device.type),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDeviceIcon(device.type),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showConnectionStatus && device.isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Connected',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getDeviceTypeIcon(device.type),
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getDeviceTypeName(device.type),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (device.rssi != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            _getSignalIcon(device.rssi!),
                            size: 16,
                            color: _getSignalColor(device.rssi!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${device.rssi} dBm',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (device.ipAddress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        device.ipAddress!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Action indicator
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDeviceColor(BuildContext context, DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return const Color(0xFF4CAF50); // Green
      case DeviceType.ios:
        return const Color(0xFF2196F3); // Blue
      case DeviceType.desktop:
        return const Color(0xFF9C27B0); // Purple
      case DeviceType.windows:
        return const Color(0xFF2196F3); // Blue
      case DeviceType.mac:
        return const Color(0xFF757575); // Grey
      case DeviceType.linux:
        return const Color(0xFFFF9800); // Orange
      case DeviceType.unknown:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return Icons.android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.desktop:
        return Icons.computer;
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

  IconData _getDeviceTypeIcon(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return Icons.android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.desktop:
        return Icons.computer;
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

  String _getDeviceTypeName(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.ios:
        return 'iPhone';
      case DeviceType.desktop:
        return 'Computer';
      case DeviceType.windows:
        return 'Windows PC';
      case DeviceType.mac:
        return 'Mac';
      case DeviceType.linux:
        return 'Linux PC';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -50) return Icons.signal_cellular_4_bar;
    if (rssi >= -60) return Icons.network_wifi_3_bar;
    if (rssi >= -70) return Icons.network_wifi_2_bar;
    if (rssi >= -80) return Icons.network_wifi_1_bar;
    return Icons.signal_cellular_0_bar;
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.orange;
    if (rssi >= -80) return Colors.deepOrange;
    return Colors.red;
  }
}