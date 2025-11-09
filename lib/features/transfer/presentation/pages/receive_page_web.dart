import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/app_providers_web.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Web version of the receive page
class ReceivePageWeb extends ConsumerStatefulWidget {
  const ReceivePageWeb({super.key});

  @override
  ConsumerState<ReceivePageWeb> createState() => _ReceivePageWebState();
}

class _ReceivePageWebState extends ConsumerState<ReceivePageWeb> {
  bool _isReceiving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Files'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isReceiving 
                            ? Colors.green.withValues(alpha: 0.1)
                            : theme.colorScheme.primaryContainer,
                        border: Border.all(
                          color: _isReceiving 
                              ? Colors.green
                              : theme.colorScheme.primary,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        _isReceiving ? Icons.download : Icons.download_outlined,
                        size: 48,
                        color: _isReceiving 
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isReceiving ? 'Ready to Receive' : 'Start Receiving',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isReceiving 
                          ? 'Your device is visible to nearby devices'
                          : 'Make your device discoverable to receive files',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isReceiving = !_isReceiving;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isReceiving 
                              ? Colors.red
                              : theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _isReceiving ? 'Stop Receiving' : 'Start Receiving',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to Receive Files',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      context,
                      '1',
                      'Start Receiving',
                      'Tap the "Start Receiving" button to make your device discoverable',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '2',
                      'Wait for Connection',
                      'Other devices will be able to see and connect to your device',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '3',
                      'Accept Files',
                      'You\'ll be notified when someone wants to send you files',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Demo simulation card
            if (_isReceiving)
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.computer,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Web Demo Mode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Your browser is now ready to receive files',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _simulateIncomingTransfer,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                          child: const Text('Simulate Incoming Transfer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(
    BuildContext context,
    String number,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _simulateIncomingTransfer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.download,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('Incoming Transfer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demo iPhone wants to send you:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.image, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'vacation_photos.zip',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '45.2 MB',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Do you want to accept this file?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showTransferProgress();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showTransferProgress() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Receiving File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(value: 0.7),
            const SizedBox(height: 16),
            Text('vacation_photos.zip'),
            const SizedBox(height: 8),
            Text(
              '31.6 MB / 45.2 MB (70%)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Speed: 2.3 MB/s • ETA: 6s',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showTransferComplete();
            },
            child: const Text('Simulate Complete'),
          ),
        ],
      ),
    );
  }

  void _showTransferComplete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('Transfer Complete'),
          ],
        ),
        content: const Text(
          'Successfully received vacation_photos.zip (45.2 MB)\n\n'
          'File saved to Downloads folder.',
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