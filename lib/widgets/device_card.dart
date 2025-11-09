import 'package:flutter/material.dart';

/// Device card widget for displaying discovered devices
/// TODO: Implement device connection and status management
class DeviceCard extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final bool isConnected;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.deviceId,
    this.isConnected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
          child: Icon(
            isConnected ? Icons.devices : Icons.device_unknown,
            color: Colors.white,
          ),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(deviceId),
        trailing: isConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
