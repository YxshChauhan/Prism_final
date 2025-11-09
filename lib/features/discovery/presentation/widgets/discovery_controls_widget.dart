import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/features/discovery/presentation/providers/discovery_provider.dart';

class DiscoveryControlsWidget extends ConsumerWidget {
  const DiscoveryControlsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryController = ref.watch(discoveryControllerProvider);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Discovery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await discoveryController.startDiscovery();
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Start Discovery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await discoveryController.stopDiscovery();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Make sure Bluetooth and Location are enabled for device discovery.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
