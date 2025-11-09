import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/core/constants/feature_flags.dart';

/// Receive files page for accepting incoming transfers
class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage({super.key});

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends ConsumerState<ReceivePage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isReceiving = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ErrorBoundary(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receive Files'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isReceiving = !_isReceiving;
                });
                if (_isReceiving) {
                  _startReceiving();
                } else {
                  _stopReceiving();
                }
              },
              icon: Icon(
                _isReceiving ? Icons.stop : Icons.play_arrow,
                color: _isReceiving ? Colors.red : colorScheme.primary,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReceiveStatus(context),
                const SizedBox(height: 32),
                _buildDeviceList(context),
                const SizedBox(height: 32),
                _buildIncomingTransfers(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiveStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isReceiving
              ? [Colors.green, Colors.green.shade300]
              : [colorScheme.primary, colorScheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isReceiving ? Colors.green : colorScheme.primary).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isReceiving ? _pulseAnimation.value : 1.0,
                child: Icon(
                  _isReceiving ? Icons.wifi_find : Icons.wifi_off,
                  size: 64,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _isReceiving ? 'Receiving Files' : 'Ready to Receive',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isReceiving 
                ? 'Waiting for incoming transfers...'
                : 'Tap the play button to start receiving',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isReceiving) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nearby Devices',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (!FeatureFlags.DISCOVERY_ENABLED)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Discovery is disabled. Enable in feature flags.',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _buildMockDeviceList(context),
      ],
    );
  }

  Widget _buildMockDeviceList(BuildContext context) {
    final theme = Theme.of(context);
    final devices = [
      {'name': 'John\'s iPhone', 'type': 'iOS', 'status': 'Available'},
      {'name': 'Samsung Galaxy', 'type': 'Android', 'status': 'Connected'},
      {'name': 'MacBook Pro', 'type': 'macOS', 'status': 'Available'},
    ];

    return Column(
      children: devices.map((device) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: device['status'] == 'Connected' 
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: device['status'] == 'Connected' 
                    ? Colors.green.withValues(alpha: 0.1)
                    : theme.colorScheme.primaryContainer,
                child: Icon(
                  device['type'] == 'iOS' 
                      ? Icons.phone_iphone
                      : device['type'] == 'Android'
                          ? Icons.android
                          : Icons.laptop_mac,
                  color: device['status'] == 'Connected' 
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device['name'] as String,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      device['type'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: device['status'] == 'Connected' 
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device['status'] as String,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: device['status'] == 'Connected' 
                        ? Colors.green
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIncomingTransfers(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Incoming Transfers',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.inbox,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No incoming transfers',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Files sent to this device will appear here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startReceiving() {
    // Start receiving mode
    // This would typically:
    // 1. Start discovery service
    // 2. Begin listening for incoming connections
    // 3. Update UI state
  }

  void _stopReceiving() {
    // Stop receiving mode
    // This would typically:
    // 1. Stop discovery service
    // 2. Close incoming connections
    // 3. Update UI state
  }
}
