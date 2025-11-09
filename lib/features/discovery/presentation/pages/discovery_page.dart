import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:airlink/features/discovery/presentation/widgets/device_list_widget.dart';
import 'package:airlink/features/discovery/presentation/widgets/discovery_controls_widget.dart';
import 'package:airlink/features/discovery/presentation/widgets/platform_capabilities_widget.dart';

class DiscoveryPage extends ConsumerWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryState = ref.watch(discoveryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AirLink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Platform Capabilities
          const PlatformCapabilitiesWidget(),
          
          // Discovery Controls
          const DiscoveryControlsWidget(),
          
          // Device List
          Expanded(
            child: discoveryState.when(
              data: (devices) => DeviceListWidget(devices: devices),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to file picker
        },
        icon: const Icon(Icons.add),
        label: const Text('Send Files'),
      ),
    );
  }
}
