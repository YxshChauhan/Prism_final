import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/constants/feature_flags.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/features/common/presentation/pages/coming_soon_page.dart';
import 'package:airlink/shared/providers/app_providers.dart';
import 'package:airlink/shared/widgets/radar_discovery_widget.dart';
import 'package:airlink/shared/widgets/concentric_circle_widget.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;

/// Feature-based home page with Zapya-inspired design
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {

  @override
  void initState() {
    super.initState();
  }

  // Reuse helpers from history page for status formatting
  Color _getStatusColor(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return const Color(0xFFFF9800);
      case unified.TransferStatus.connecting:
        return const Color(0xFF2196F3);
      case unified.TransferStatus.transferring:
        return const Color(0xFF2196F3);
      case unified.TransferStatus.paused:
        return const Color(0xFFFFC107);
      case unified.TransferStatus.completed:
        return const Color(0xFF4CAF50);
      case unified.TransferStatus.failed:
        return const Color(0xFFF44336);
      case unified.TransferStatus.cancelled:
        return const Color(0xFF9E9E9E);
      case unified.TransferStatus.handshaking:
        return const Color(0xFF9C27B0);
      case unified.TransferStatus.resuming:
        return const Color(0xFF009688);
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
              // Trigger discovery refresh
              if (FeatureFlags.DISCOVERY_ENABLED) {
                ref.read(discoveryControllerProvider.notifier).startDiscovery();
              }
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
      backgroundColor: const Color(0x00000000),
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
                Icon(
                  Icons.airplanemode_active,
                  size: 32,
                  color: const Color(0xFFFFFFFF),
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
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Fast & Secure File Transfer',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xB3FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Open settings
                  },
                  icon: const Icon(
                    Icons.settings,
                    color: const Color(0xFFFFFFFF),
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
          color: const Color(0x1A000000),
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
                Icons.person,
                color: Color(0xFFFFFFFF),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Device',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to share files',
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
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Online',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFFFFFFF),
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
    if (!FeatureFlags.DISCOVERY_ENABLED) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Discovery is currently disabled. Enable in feature flags.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Read nearby devices from provider
    final nearbyDevices = ref.watch(nearbyDevicesProvider);
    final isDiscovering = ref.watch(isDiscoveringProvider);
    final discoveryState = ref.watch(discoveryControllerProvider);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (discoveryState.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        discoveryState.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            if (nearbyDevices.isEmpty && !isDiscovering)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No devices found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to refresh or enable Wi-Fi/Bluetooth',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              RadarDiscoveryWidget(
                key: const Key('discovery_button'),
                devices: _convertToRadarDevices(nearbyDevices),
                onDeviceTap: () {
                  // Switch to send page via provider
                  ref.read(currentPageProvider.notifier).state = AppPage.send;
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final nearbyDevices = ref.watch(nearbyDevicesProvider);
    
    // Convert Device objects to NearbyDevice objects
    final nearbyDevicesList = nearbyDevices.map((device) {
      return NearbyDevice(
        id: device.id,
        name: device.name,
        type: device.type.toString().split('.').last,
        isConnected: device.isConnected,
      );
    }).toList();
    
    return SliverToBoxAdapter(
      child: ConcentricCircleWidget(
        nearbyDevices: nearbyDevicesList,
        onDeviceTap: () {
          // Handle device tap
        },
      ),
    );
  }


  Widget _buildTransferStats(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(transferStatisticsProvider);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: statsAsync.when(
          loading: () => Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading statistics...'),
              ],
            ),
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer Statistics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load stats',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          data: (stats) {
            final filesSent = stats['files_sent'] as int? ?? 0;
            final filesReceived = stats['files_received'] as int? ?? 0;
            final totalBytes = stats['total_bytes'] as int? ?? 0;
            final avgSpeed = stats['avg_speed'] as double? ?? 0.0;

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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer Statistics',
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
                        const Color(0xFF2196F3),
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Files Received',
                        '$filesReceived',
                        Icons.download,
                        const Color(0xFF4CAF50),
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        'Data Transferred',
                        formatBytes(totalBytes),
                        Icons.storage,
                        const Color(0xFFFF9800),
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
                        const Color(0xFF9C27B0),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
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
    final recentAsync = ref.watch(recentTransfersProvider);
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transfers',
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
              child: recentAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Failed to load recent transfers', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)))
                  ],
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recent transfers',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your transfer history will appear here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: items.map((t) {
                      final fileCount = t.files.length;
                      final directionIcon = t.direction == unified.TransferDirection.sent ? Icons.north_east : Icons.south_west;
            final directionColor = t.direction == unified.TransferDirection.sent
              ? const Color(0xFF2196F3)
              : const Color(0xFF4CAF50);
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
                                color: _getStatusColor(t.status).withValues(alpha: 25),
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
                  );
                },
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
                  FeatureFlags.MEDIA_PLAYER_ENABLED,
                  () {
                    if (FeatureFlags.MEDIA_PLAYER_ENABLED) {
                      // Navigate to media player
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComingSoonPage(
                            featureName: 'Media Player',
                            description: 'Play videos and music directly in AirLink.',
                            icon: Icons.play_circle_outline,
                            capabilities: [
                              'Video playback with controls',
                              'Music player with playlists',
                              'Image viewer with gestures',
                              'Document preview',
                            ],
                            estimatedRelease: 'Q2 2024',
                            completionPercentage: FeatureFlags.getFeatureCompletion('media_player'),
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildFeatureCard(
                  context,
                  'File Manager',
                  Icons.folder_outlined,
                  FeatureFlags.FILE_MANAGER_ENABLED,
                  () {
                    if (FeatureFlags.FILE_MANAGER_ENABLED) {
                      // Navigate to file manager
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComingSoonPage(
                            featureName: 'File Manager',
                            description: 'Browse and manage files with advanced features.',
                            icon: Icons.folder_outlined,
                            capabilities: [
                              'File browsing and organization',
                              'Search and filter files',
                              'File operations (copy, move, delete)',
                              'Storage analysis',
                            ],
                            estimatedRelease: 'Q2 2024',
                            completionPercentage: FeatureFlags.getFeatureCompletion('file_manager'),
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildFeatureCard(
                  context,
                  'APK Sharing',
                  Icons.android,
                  FeatureFlags.APK_SHARING_ENABLED,
                  () {
                    if (FeatureFlags.APK_SHARING_ENABLED) {
                      // Navigate to APK sharing
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComingSoonPage(
                            featureName: 'APK Sharing',
                            description: 'Share and install apps easily.',
                            icon: Icons.android,
                            capabilities: [
                              'Extract APK from installed apps',
                              'Share APK files',
                              'Install APK files',
                              'App backup and restore',
                            ],
                            estimatedRelease: 'Q3 2024',
                            completionPercentage: FeatureFlags.getFeatureCompletion('apk_sharing'),
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildFeatureCard(
                  context,
                  'Cloud Sync',
                  Icons.cloud_outlined,
                  FeatureFlags.CLOUD_SYNC_ENABLED,
                  () {
                    if (FeatureFlags.CLOUD_SYNC_ENABLED) {
                      // Navigate to cloud sync
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComingSoonPage(
                            featureName: 'Cloud Sync',
                            description: 'Sync files with cloud storage providers.',
                            icon: Icons.cloud_outlined,
                            capabilities: [
                              'Google Drive integration',
                              'Dropbox integration',
                              'OneDrive integration',
                              'Automatic sync',
                            ],
                            estimatedRelease: 'Q3 2024',
                            completionPercentage: FeatureFlags.getFeatureCompletion('cloud_sync'),
                          ),
                        ),
                      );
                    }
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
    bool isEnabled,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final color = isEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled 
              ? color.withValues(alpha: 25)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 77) : const Color(0x00000000),
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
            if (!isEnabled) ...[
              const SizedBox(height: 4),
              Text(
                'Coming Soon',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
