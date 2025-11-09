import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Phone Replication Page
/// 
/// Provides complete device cloning interface
/// Similar to SHAREit/Zapya phone replication functionality
class PhoneReplicationPage extends ConsumerStatefulWidget {
  const PhoneReplicationPage({super.key});

  @override
  ConsumerState<PhoneReplicationPage> createState() => _PhoneReplicationPageState();
}

class _PhoneReplicationPageState extends ConsumerState<PhoneReplicationPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  UIReplicationStatus _replicationStatus = UIReplicationStatus.idle;
  double _replicationProgress = 0.0;
  
  // Replication option state fields
  bool _includeApps = true;
  bool _includeMedia = true;
  bool _includeContacts = true;
  bool _includeSettings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Replication'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Backup Device'),
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Restore Device'),
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Sync Devices'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.phone_android), text: 'Source Device'),
            Tab(icon: Icon(Icons.phone_iphone), text: 'Target Device'),
            Tab(icon: Icon(Icons.history), text: 'Replication History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSourceDeviceTab(),
          _buildTargetDeviceTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSourceDeviceTab() {
    return Consumer(
      builder: (context, ref, child) {
        final sourceData = ref.watch(getSourceDeviceDataProvider);
        
        return sourceData.when(
          data: (data) => _buildSourceDeviceContent(data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading source device: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getSourceDeviceDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTargetDeviceTab() {
    return Consumer(
      builder: (context, ref, child) {
        final targetData = ref.watch(getTargetDeviceDataProvider);
        
        return targetData.when(
          data: (data) => _buildTargetDeviceContent(data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading target device: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getTargetDeviceDataProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer(
      builder: (context, ref, child) {
        final history = ref.watch(getReplicationHistoryProvider);
        
        return history.when(
          data: (historyItems) => _buildHistoryContent(historyItems),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading history: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getReplicationHistoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceDeviceContent(SourceDeviceData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeviceInfoCard(data.deviceInfo),
          const SizedBox(height: 16),
          _buildDataCategoriesCard(data.categories),
          const SizedBox(height: 16),
          _buildStorageInfoCard(data.storageInfo),
          const SizedBox(height: 16),
          _buildReplicationOptionsCard(),
        ],
      ),
    );
  }

  Widget _buildTargetDeviceContent(TargetDeviceData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetDeviceInfoCard(data.deviceInfo),
          const SizedBox(height: 16),
          _buildReplicationProgressCard(),
          const SizedBox(height: 16),
          _buildReplicationControlsCard(),
        ],
      ),
    );
  }

  Widget _buildHistoryContent(List<ReplicationHistoryItem> history) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No replication history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your replication history will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return _buildHistoryItemCard(item);
      },
    );
  }

  Widget _buildDeviceInfoCard(DeviceInfo deviceInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceInfo.deviceName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        deviceInfo.model,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('OS Version', deviceInfo.osVersion),
            _buildInfoRow('Storage', '${deviceInfo.totalStorage} GB'),
            _buildInfoRow('Available', '${deviceInfo.availableStorage} GB'),
            _buildInfoRow('Battery', '${deviceInfo.batteryLevel}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDeviceInfoCard(DeviceInfo deviceInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_iphone, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceInfo.deviceName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        deviceInfo.model,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('OS Version', deviceInfo.osVersion),
            _buildInfoRow('Storage', '${deviceInfo.totalStorage} GB'),
            _buildInfoRow('Available', '${deviceInfo.availableStorage} GB'),
            _buildInfoRow('Battery', '${deviceInfo.batteryLevel}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCategoriesCard(List<DataCategory> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Categories',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...categories.map((category) => _buildCategoryItem(category)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(DataCategory category) {
    return ListTile(
      leading: Icon(_getCategoryIcon(category.type)),
      title: Text(category.name),
      subtitle: Text('${category.itemCount} items'),
      trailing: Switch(
        value: category.isSelected,
        onChanged: (value) {
          // TODO: Implement category selection
        },
      ),
    );
  }

  Widget _buildStorageInfoCard(StorageInfo storageInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildStorageBar(storageInfo),
            const SizedBox(height: 16),
            _buildInfoRow('Total', '${storageInfo.totalSpace} GB'),
            _buildInfoRow('Used', '${storageInfo.usedSpace} GB'),
            _buildInfoRow('Available', '${storageInfo.availableSpace} GB'),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBar(StorageInfo storageInfo) {
    final usedPercentage = storageInfo.totalSpace > 0 
        ? (storageInfo.usedSpace / storageInfo.totalSpace).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      children: [
        LinearProgressIndicator(
          value: usedPercentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            usedPercentage > 0.9 ? Colors.red : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(usedPercentage * 100).toStringAsFixed(1)}% used',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildReplicationOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replication Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Include Apps'),
              subtitle: const Text('Transfer installed applications'),
              value: _includeApps,
              onChanged: (value) {
                setState(() {
                  _includeApps = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Include Media'),
              subtitle: const Text('Transfer photos, videos, and music'),
              value: _includeMedia,
              onChanged: (value) {
                setState(() {
                  _includeMedia = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Include Contacts'),
              subtitle: const Text('Transfer contact information'),
              value: _includeContacts,
              onChanged: (value) {
                setState(() {
                  _includeContacts = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Include Settings'),
              subtitle: const Text('Transfer device settings and preferences'),
              value: _includeSettings,
              onChanged: (value) {
                setState(() {
                  _includeSettings = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplicationProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replication Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _replicationProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_replicationProgress * 100).toStringAsFixed(1)}% complete',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _replicationStatus == UIReplicationStatus.running
                      ? _pauseReplication
                      : _startReplication,
                  icon: Icon(_replicationStatus == UIReplicationStatus.running
                      ? Icons.pause
                      : Icons.play_arrow),
                  label: Text(_replicationStatus == UIReplicationStatus.running
                      ? 'Pause'
                      : 'Start'),
                ),
                ElevatedButton.icon(
                  onPressed: _cancelReplication,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplicationControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replication Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startReplication,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Replication'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showReplicationSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItemCard(ReplicationHistoryItem item) {
    return Card(
      child: ListTile(
        leading: Icon(_getStatusIcon(_parseUIReplicationStatus(item.status))),
        title: Text(item.deviceName),
        subtitle: Text('${item.date} - ${item.status}'),
        trailing: Text('${item.dataSize} MB'),
        onTap: () => _showHistoryDetails(item),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    switch (_replicationStatus) {
      case UIReplicationStatus.idle:
        return FloatingActionButton(
          onPressed: _startReplication,
          child: const Icon(Icons.play_arrow),
        );
      case UIReplicationStatus.running:
        return FloatingActionButton(
          onPressed: _pauseReplication,
          child: const Icon(Icons.pause),
        );
      case UIReplicationStatus.paused:
        return FloatingActionButton(
          onPressed: _resumeReplication,
          child: const Icon(Icons.play_arrow),
        );
      case UIReplicationStatus.completed:
        return FloatingActionButton(
          onPressed: _startReplication,
          child: const Icon(Icons.refresh),
        );
      case UIReplicationStatus.failed:
        return FloatingActionButton(
          onPressed: _retryReplication,
          child: const Icon(Icons.refresh),
        );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(DataCategoryType type) {
    switch (type) {
      case DataCategoryType.apps:
        return Icons.apps;
      case DataCategoryType.media:
        return Icons.photo_library;
      case DataCategoryType.contacts:
        return Icons.contacts;
      case DataCategoryType.settings:
        return Icons.settings;
      case DataCategoryType.documents:
        return Icons.description;
    }
  }

  UIReplicationStatus _parseUIReplicationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return UIReplicationStatus.idle;
      case 'running':
        return UIReplicationStatus.running;
      case 'paused':
        return UIReplicationStatus.paused;
      case 'completed':
        return UIReplicationStatus.completed;
      case 'failed':
        return UIReplicationStatus.failed;
      default:
        return UIReplicationStatus.idle;
    }
  }

  IconData _getStatusIcon(UIReplicationStatus status) {
    switch (status) {
      case UIReplicationStatus.idle:
        return Icons.phone_android;
      case UIReplicationStatus.running:
        return Icons.sync;
      case UIReplicationStatus.paused:
        return Icons.pause_circle;
      case UIReplicationStatus.completed:
        return Icons.check_circle;
      case UIReplicationStatus.failed:
        return Icons.error;
    }
  }

  void _startReplication() {
    setState(() {
      _replicationStatus = UIReplicationStatus.running;
    });
    // TODO: Implement replication start
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting replication...')),
    );
  }

  void _pauseReplication() {
    setState(() {
      _replicationStatus = UIReplicationStatus.paused;
    });
    // TODO: Implement replication pause
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pausing replication...')),
    );
  }

  void _resumeReplication() {
    setState(() {
      _replicationStatus = UIReplicationStatus.running;
    });
    // TODO: Implement replication resume
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resuming replication...')),
    );
  }

  void _cancelReplication() {
    setState(() {
      _replicationStatus = UIReplicationStatus.idle;
      _replicationProgress = 0.0;
    });
    // TODO: Implement replication cancellation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cancelling replication...')),
    );
  }

  void _retryReplication() {
    setState(() {
      _replicationStatus = UIReplicationStatus.running;
    });
    // TODO: Implement replication retry
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Retrying replication...')),
    );
  }

  void _refreshData() {
    // TODO: Implement data refresh
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing data...')),
    );
  }

  void _showSettings() {
    // TODO: Implement settings dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings coming soon')),
    );
  }

  void _showReplicationSettings() {
    // TODO: Implement replication settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Replication settings coming soon')),
    );
  }

  void _showHistoryDetails(ReplicationHistoryItem item) {
    // TODO: Implement history details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('History details: ${item.deviceName}')),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'backup':
        _backupDevice();
        break;
      case 'restore':
        _restoreDevice();
        break;
      case 'sync':
        _syncDevices();
        break;
    }
  }

  void _backupDevice() {
    // TODO: Implement device backup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backing up device...')),
    );
  }

  void _restoreDevice() {
    // TODO: Implement device restore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restoring device...')),
    );
  }

  void _syncDevices() {
    // TODO: Implement device sync
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing devices...')),
    );
  }
}
