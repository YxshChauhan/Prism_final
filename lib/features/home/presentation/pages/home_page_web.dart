import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/shared/providers/app_providers_web.dart';
import 'package:airlink/shared/widgets/radar_discovery_widget.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;

/// Web version of the home page with demo data
class HomePageWeb extends ConsumerStatefulWidget {
  const HomePageWeb({super.key});

  @override
  ConsumerState<HomePageWeb> createState() => _HomePageWebState();
}

class _HomePageWebState extends ConsumerState<HomePageWeb> {

  // Helper methods for status formatting
  Color _getStatusColor(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return Colors.orange;
      case unified.TransferStatus.connecting:
        return Colors.blue;
      case unified.TransferStatus.transferring:
        return Colors.blue;
      case unified.TransferStatus.paused:
        return Colors.amber;
      case unified.TransferStatus.completed:
        return Colors.green;
      case unified.TransferStatus.failed:
        return Colors.red;
      case unified.TransferStatus.cancelled:
        return Colors.grey;
      case unified.TransferStatus.handshaking:
        return Colors.purple;
      case unified.TransferStatus.resuming:
        return Colors.teal;
    }
  }

  String _getStatusText(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return 'Pending';
      case unified.TransferStatus.connecting:
        return 'Connecting';
      case unified.TransferStatus.transferring:
        return 'Transferring';
      case unified.TransferStatus.paused:
        return 'Paused';
      case unified.TransferStatus.completed:
        return 'Completed';
      case unified.TransferStatus.failed:
        return 'Failed';
      case unified.TransferStatus.cancelled:
        return 'Cancelled';
      case unified.TransferStatus.handshaking:
        return 'Handshaking';
      case unified.TransferStatus.resuming:
        return 'Resuming';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Convert Device objects to RadarDevice objects for the radar widget
  List<RadarDevice> _convertToRadarDevices(List<Device> devices) {
    return devices.asMap().entries.map((entry) {
      final index = entry.key;
      final device = entry.value;
      
      // Calculate angle based on device index (distribute around circle)
      final angle = (index * 2 * 3.14159) / devices.length;
      
      // Calculate distance based on RSSI (if available) or random
      final distance = device.rssi != null 
          ? (100 + device.rssi!) / 100.0  // Convert RSSI to 0-1 range
          : 0.3 + (index * 0.1); // Fallback to distributed distances
      
      return RadarDevice(
        id: device.id,
        name: device.name,
        type: _convertDeviceType(device.type),
        angle: angle,
        distance: distance.clamp(0.1, 1.0),
        isConnected: device.isConnected,
      );
    }).toList();
  }
  
  /// Convert DeviceType to RadarDeviceType
  RadarDeviceType _convertDeviceType(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
      case DeviceType.ios:
        return RadarDeviceType.phone;
      case DeviceType.windows:
      case DeviceType.mac:
      case DeviceType.linux:
        return RadarDeviceType.computer;
      default:
        return RadarDeviceType.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Simulate refresh for web demo
              await Future.delayed(const Duration(seconds: 1));
            },
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                _buildUserProfileCard(context),
                _buildRadarDiscovery(context),
                _buildQuickActions(context),
                _buildTransferStats(context),
                _buildRecentTransfers(context),
                _buildFeatureGrid(context),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primaryContainer,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Row(
              children: [
                const Icon(
                  Icons.airplanemode_active,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'AirLink',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Fast & Secure File Transfer - Web Demo',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(currentPageProviderWeb.notifier).state = AppPage.settings;
                  },
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(
                Icons.computer,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Web Browser',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Demo mode - Ready to share files',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Demo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarDiscovery(BuildContext context) {
    final nearbyDevices = ref.watch(nearbyDevicesProviderWeb);
    final isDiscovering = ref.watch(isDiscoveringProviderWeb);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isDiscovering)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Discovering nearby devices...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            RadarDiscoveryWidget(
              key: const Key('discovery_button'),
              devices: _convertToRadarDevices(nearbyDevices),
              isScanning: isDiscovering,
              instructionText: 'Demo devices - Click to simulate connection',
              onDeviceTap: () {
                // Switch to send page via provider
                ref.read(currentPageProviderWeb.notifier).state = AppPage.send;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Send Files',
                    Icons.send,
                    Colors.blue,
                    () {
                      ref.read(currentPageProviderWeb.notifier).state = AppPage.send;
                    },
                    key: const Key('send_files_button'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Receive Files',
                    Icons.download,
                    Colors.green,
                    () {
                      ref.read(currentPageProviderWeb.notifier).state = AppPage.receive;
                    },
                    key: const Key('receive_files_button'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    'Start Discovery',
                    Icons.radar,
                    Colors.purple,
                    () {
                      ref.read(isDiscoveringProviderWeb.notifier).state = 
                          !ref.read(isDiscoveringProviderWeb);
                    },
                    key: const Key('discovery_button'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferStats(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ref.watch(transferStatisticsProviderWeb);

    final filesSent = stats['files_sent'] as int;
    final filesReceived = stats['files_received'] as int;
    final totalBytes = stats['total_bytes'] as int;
    final avgSpeed = stats['avg_speed'] as double;

    String formatBytes(int bytes) {
      const units = ['B', 'KB', 'MB', 'GB', 'TB'];
      double size = bytes.toDouble();
      int unit = 0;
      while (size >= 1024 && unit < units.length - 1) {
        size /= 1024;
        unit++;
      }
      return '${size.toStringAsFixed(1)} ${units[unit]}';
    }

    String formatSpeed(double bps) {
      return '${formatBytes(bps.toInt())}/s';
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer Statistics (Demo)',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Files Sent',
                    '$filesSent',
                    Icons.upload,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Files Received',
                    '$filesReceived',
                    Icons.download,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Data Transferred',
                    formatBytes(totalBytes),
                    Icons.storage,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Average Speed',
                    formatSpeed(avgSpeed),
                    Icons.speed,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentTransfers(BuildContext context) {
    final theme = Theme.of(context);
    final recentTransfers = ref.watch(recentTransfersProviderWeb);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transfers (Demo)',
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
                children: recentTransfers.take(3).map((t) {
                  final fileCount = t.files.length;
                  final directionIcon = t.direction == unified.TransferDirection.sent ? Icons.north_east : Icons.south_west;
                  final directionColor = t.direction == unified.TransferDirection.sent ? Colors.blue : Colors.green;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(directionIcon, color: directionColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.files.isNotEmpty ? t.files.first.name : 'Transfer',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$fileCount file${fileCount == 1 ? '' : 's'} • ${_formatDateTime(t.createdAt)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(t.status).withAlpha(0x1F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(t.status),
                            style: theme.textTheme.labelSmall?.copyWith(color: _getStatusColor(t.status)),
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final theme = Theme.of(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Features',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildFeatureCard(
                  context,
                  'Media Player',
                  Icons.play_circle_outline,
                  Colors.purple,
                  () {
                    ref.read(currentPageProviderWeb.notifier).state = AppPage.mediaPlayer;
                  },
                ),
                _buildFeatureCard(
                  context,
                  'File Manager',
                  Icons.folder_outlined,
                  Colors.orange,
                  () {
                    ref.read(currentPageProviderWeb.notifier).state = AppPage.fileManager;
                  },
                ),
                _buildFeatureCard(
                  context,
                  'APK Sharing',
                  Icons.android,
                  Colors.green,
                  () {
                    ref.read(currentPageProviderWeb.notifier).state = AppPage.apkSharing;
                  },
                ),
                _buildFeatureCard(
                  context,
                  'Cloud Sync',
                  Icons.cloud,
                  Colors.blue,
                  () {
                    ref.read(currentPageProviderWeb.notifier).state = AppPage.cloudSync;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}