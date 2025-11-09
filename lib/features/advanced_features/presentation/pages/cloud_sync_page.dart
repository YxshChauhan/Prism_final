import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/widgets/cloud_sync_widgets.dart';
import 'package:airlink/shared/widgets/cloud_sync_dialogs.dart';

/// Cloud Sync Page
/// 
/// Provides cloud storage integration interface
/// Supports Google Drive, Dropbox, OneDrive, and iCloud
class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});

  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

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
        title: const Text('Cloud Sync'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncAll,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_provider',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Add Provider'),
                ),
              ),
              const PopupMenuItem(
                value: 'backup_all',
                child: ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Backup All'),
                ),
              ),
              const PopupMenuItem(
                value: 'restore_all',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Restore All'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cloud), text: 'Providers'),
            Tab(icon: Icon(Icons.sync), text: 'Sync Jobs'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProvidersTab(),
          _buildSyncJobsTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCloudProvider,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Reusable helper for AsyncValue UI states
  Widget _buildAsyncValueWidget<T>(
    AsyncValue<T> asyncValue,
    Widget Function(T data) dataBuilder,
    String errorMessage,
    VoidCallback onRetry,
  ) {
    return asyncValue.when(
      data: dataBuilder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('$errorMessage: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersTab() {
    return Consumer(
      builder: (context, ref, child) {
        final providers = ref.watch(getCloudProvidersProvider);
        
        return _buildAsyncValueWidget(
          providers,
          (providerList) => _buildProvidersList(providerList),
          'Error loading providers',
          () => ref.invalidate(getCloudProvidersProvider),
        );
      },
    );
  }

  Widget _buildSyncJobsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final syncJobs = ref.watch(getActiveSyncJobsProvider);
        
        return _buildAsyncValueWidget(
          syncJobs,
          (jobs) => _buildSyncJobsList(jobs),
          'Error loading sync jobs',
          () => ref.invalidate(getActiveSyncJobsProvider),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer(
      builder: (context, ref, child) {
        final history = ref.watch(syncHistoryProvider);
        
        return _buildAsyncValueWidget(
          history,
          (historyItems) => _buildHistoryList(historyItems),
          'Error loading history',
          () => ref.invalidate(syncHistoryProvider),
        );
      },
    );
  }

  Widget _buildProvidersList(List<CloudProvider> providers) {
    if (providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No cloud providers connected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a cloud provider to start syncing your files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addCloudProvider,
              icon: const Icon(Icons.add),
              label: const Text('Add Provider'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final provider = providers[index];
        return CloudProviderCard(
          provider: provider,
          onDisconnect: () => _disconnectProvider(provider),
          onSettings: () => _showProviderSettings(provider),
          onStorageInfo: () => _showStorageInfo(provider),
        );
      },
    );
  }

  Widget _buildSyncJobsList(List<SyncJob> jobs) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sync_disabled,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No active sync jobs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start syncing files to see active jobs here',
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
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return SyncJobCard(
          job: SyncStatus(
            id: job.id,
            name: job.name,
            status: job.status,
            progress: job.progress,
            createdAt: job.createdAt,
            localPath: null,
            remotePath: null,
            filesProcessed: 0,
            totalFiles: 1,
          ),
          onPause: () => _pauseSyncJob(job),
          onResume: () => _resumeSyncJob(job),
          onStop: () => _cancelSyncJob(job),
        );
      },
    );
  }

  Widget _buildHistoryList(List<SyncHistoryItem> history) {
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
              'No sync history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your sync history will appear here',
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
        return SyncHistoryCard(
          item: item,
          onRetry: () => _retrySync(item),
          onViewDetails: () => _showHistoryDetails(item),
        );
      },
    );
  }


  void _disconnectProvider(CloudProvider provider) {
    // TODO: Implement provider disconnection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disconnecting from ${provider.name}...')),
    );
  }


  void _showProviderSettings(CloudProvider provider) {
    showDialog(
      context: context,
      builder: (context) => CloudProviderSettingsDialog(provider: provider),
    );
  }

  void _pauseSyncJob(SyncJob job) {
    // TODO: Implement sync job pause
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pausing sync job: ${job.name}')),
    );
  }

  void _resumeSyncJob(SyncJob job) {
    // TODO: Implement sync job resume
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Resuming sync job: ${job.name}')),
    );
  }

  void _cancelSyncJob(SyncJob job) {
    // TODO: Implement sync job cancellation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cancelling sync job: ${job.name}')),
    );
  }


  void _retrySync(SyncHistoryItem item) {
    // TODO: Implement sync retry
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retrying sync: ${item.providerName}')),
    );
  }

  void _showHistoryDetails(SyncHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => SyncHistoryDetailsDialog(item: item),
    );
  }

  void _syncAll() {
    // TODO: Implement sync all
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing all providers...')),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => const CloudSyncSettingsDialog(),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_provider':
        _addCloudProvider();
        break;
      case 'backup_all':
        _backupAll();
        break;
      case 'restore_all':
        _restoreAll();
        break;
    }
  }

  void _addCloudProvider() {
    showDialog(
      context: context,
      builder: (context) => const AddCloudProviderDialog(),
    );
  }

  void _backupAll() {
    // TODO: Implement backup all
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backing up all files...')),
    );
  }

  void _restoreAll() {
    // TODO: Implement restore all
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restoring all files...')),
    );
  }

  void _showStorageInfo(CloudProvider provider) {
    // TODO: Implement storage info dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Storage info for ${provider.name}')),
    );
  }



}
