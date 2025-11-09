import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:airlink/core/services/platform_detection_service.dart';

class PlatformCapabilitiesWidget extends ConsumerStatefulWidget {
  const PlatformCapabilitiesWidget({super.key});

  @override
  ConsumerState<PlatformCapabilitiesWidget> createState() => _PlatformCapabilitiesWidgetState();
}

class _PlatformCapabilitiesWidgetState extends ConsumerState<PlatformCapabilitiesWidget> {
  PlatformCapabilities? _capabilities;
  bool _isLoading = true;
  
  GetIt get getIt => GetIt.instance;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    try {
      final platformDetectionService = getIt<PlatformDetectionService>();
      final capabilities = await platformDetectionService.detectPlatformCapabilities();
      
      if (mounted) {
        setState(() {
          _capabilities = capabilities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_capabilities == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 32,
              ),
              const SizedBox(height: 8),
              const Text(
                'Failed to detect platform capabilities',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadCapabilities,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Platform Capabilities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadCapabilities,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Platform Info
            _buildPlatformInfo(),
            const SizedBox(height: 16),
            
            // Discovery Methods
            _buildDiscoveryMethods(),
            const SizedBox(height: 16),
            
            // Capabilities
            _buildCapabilities(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platform Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _capabilities!.isAndroid ? Icons.android : Icons.phone_iphone,
              color: _capabilities!.isAndroid ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              _capabilities!.isAndroid ? 'Android' : 'iOS',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            if (_capabilities!.isAndroidAPI26Plus || _capabilities!.isIOS12Plus)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Modern OS',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiscoveryMethods() {
    final primaryMethod = _capabilities!.getPrimaryDiscoveryMethod();
    final fallbackMethods = _capabilities!.getFallbackDiscoveryMethods();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Discovery Methods',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Primary Method
        _buildMethodTile(
          primaryMethod,
          'Primary',
          Colors.green,
          Icons.star,
        ),
        
        // Fallback Methods
        ...fallbackMethods.map((method) => _buildMethodTile(
          method,
          'Fallback',
          Colors.orange,
          Icons.keyboard_arrow_down,
        )),
      ],
    );
  }

  Widget _buildMethodTile(DiscoveryMethod method, String label, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getMethodDisplayName(method),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  _getMethodDescription(method),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supported Features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _capabilities!.supportedCapabilities.map((capability) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCapabilityIcon(capability),
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCapabilityDisplayName(capability),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getMethodDisplayName(DiscoveryMethod method) {
    switch (method) {
      case DiscoveryMethod.wifiAware:
        return 'Wi-Fi Aware (NAN)';
      case DiscoveryMethod.ble:
        return 'Bluetooth Low Energy';
      case DiscoveryMethod.webrtc:
        return 'WebRTC P2P';
      case DiscoveryMethod.hotspot:
        return 'Mobile Hotspot';
      case DiscoveryMethod.cloudRelay:
        return 'Cloud Relay';
    }
  }

  String _getMethodDescription(DiscoveryMethod method) {
    switch (method) {
      case DiscoveryMethod.wifiAware:
        return 'High-speed discovery using Wi-Fi Aware (Android API 26+)';
      case DiscoveryMethod.ble:
        return 'Bluetooth Low Energy for device discovery';
      case DiscoveryMethod.webrtc:
        return 'Peer-to-peer connections using WebRTC';
      case DiscoveryMethod.hotspot:
        return 'TCP connections over mobile hotspot';
      case DiscoveryMethod.cloudRelay:
        return 'Cloud-based relay for remote connections';
    }
  }

  IconData _getCapabilityIcon(PlatformCapability capability) {
    switch (capability) {
      case PlatformCapability.wifiAware:
        return Icons.wifi;
      case PlatformCapability.ble:
        return Icons.bluetooth;
      case PlatformCapability.webrtc:
        return Icons.cloud;
      case PlatformCapability.hotspot:
        return Icons.wifi_tethering;
      case PlatformCapability.cloudRelay:
        return Icons.cloud_queue;
      case PlatformCapability.multipeerConnectivity:
        return Icons.devices;
      case PlatformCapability.networkDiscovery:
        return Icons.network_check;
    }
  }

  String _getCapabilityDisplayName(PlatformCapability capability) {
    switch (capability) {
      case PlatformCapability.wifiAware:
        return 'Wi-Fi Aware';
      case PlatformCapability.ble:
        return 'BLE';
      case PlatformCapability.webrtc:
        return 'WebRTC';
      case PlatformCapability.hotspot:
        return 'Hotspot';
      case PlatformCapability.cloudRelay:
        return 'Cloud Relay';
      case PlatformCapability.multipeerConnectivity:
        return 'Multipeer';
      case PlatformCapability.networkDiscovery:
        return 'Network';
    }
  }
}
