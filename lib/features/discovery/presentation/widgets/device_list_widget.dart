import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';

class DeviceListWidget extends StatelessWidget {
  const DeviceListWidget({
    super.key,
    required this.devices,
  });
  
  final List<Device> devices;
  
  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 18,
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
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return DeviceCard(device: device);
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
  });
  
  final Device device;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
        onTap: () {
          // Handle device tap
        },
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
}
