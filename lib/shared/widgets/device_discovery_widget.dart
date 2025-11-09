import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/providers/app_providers.dart';

/// Device discovery widget with radar animation
class DeviceDiscoveryWidget extends ConsumerStatefulWidget {
  final VoidCallback? onDeviceSelected;
  final VoidCallback? onRefresh;

  const DeviceDiscoveryWidget({
    super.key,
    this.onDeviceSelected,
    this.onRefresh,
  });

  @override
  ConsumerState<DeviceDiscoveryWidget> createState() => _DeviceDiscoveryWidgetState();
}

class _DeviceDiscoveryWidgetState extends ConsumerState<DeviceDiscoveryWidget>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _radarController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearbyDevices = ref.watch(nearbyDevicesProvider);
    final isDiscovering = ref.watch(isDiscoveringProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return Card(
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, isDiscovering),
            
            const SizedBox(height: 16),
            
            // Discovery status
            if (isDiscovering) _buildDiscoveryStatus(context),
            
            const SizedBox(height: 16),
            
            // Devices list
            if (nearbyDevices.isNotEmpty)
              _buildDevicesList(context, nearbyDevices, selectedDevice)
            else if (!isDiscovering)
              _buildEmptyState(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDiscovering) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDiscovering 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDiscovering ? Icons.radar : Icons.devices,
                  color: isDiscovering 
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDiscovering ? 'Discovering Devices...' : 'Nearby Devices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isDiscovering 
                    ? 'Looking for devices to connect to'
                    : 'Tap a device to connect',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.onRefresh != null)
          IconButton(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
      ],
    );
  }

  Widget _buildDiscoveryStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Scanning for devices using Wi-Fi Direct and Bluetooth...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList(BuildContext context, List<Device> devices, Device? selectedDevice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found ${devices.length} device${devices.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final isSelected = selectedDevice?.id == device.id;
            return _buildDeviceCard(context, device, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildDeviceCard(BuildContext context, Device device, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected 
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectDevice(device),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Device icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getDeviceTypeColor(device.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _getDeviceTypeIcon(device.type),
                    color: _getDeviceTypeColor(device.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_getDeviceTypeName(device.type)} • ${_getSignalStrength(device.rssi)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.radio_button_unchecked,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.devices_other,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No devices found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure the other device is nearby and has AirLink open',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              ref.read(discoveryControllerProvider.notifier).startDiscovery();
            },
            icon: const Icon(Icons.search),
            label: const Text('Start Discovery'),
          ),
        ],
      ),
    );
  }

  void _selectDevice(Device device) {
    ref.read(selectedDeviceProvider.notifier).state = device;
    widget.onDeviceSelected?.call();
  }

  Color _getDeviceTypeColor(DeviceType type) {
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

  IconData _getDeviceTypeIcon(DeviceType type) {
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

  String _getDeviceTypeName(DeviceType type) {
    switch (type) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.ios:
        return 'iPhone';
      case DeviceType.desktop:
        return 'Desktop';
      case DeviceType.windows:
        return 'Windows';
      case DeviceType.mac:
        return 'Mac';
      case DeviceType.linux:
        return 'Linux';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  String _getSignalStrength(int? strength) {
    if (strength == null) return 'Unknown';
    if (strength >= -50) return 'Excellent';
    if (strength >= -60) return 'Good';
    if (strength >= -70) return 'Fair';
    return 'Weak';
  }
}
