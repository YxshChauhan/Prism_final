import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/apk_extractor_service.dart' hide ExtractionHistoryItem;
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/widgets/apk_sharing_widgets.dart';

/// APK Sharing Page
/// 
/// Provides APK extraction, sharing, and management interface
/// Similar to SHAREit/Zapya app sharing functionality
class ApkSharingPage extends ConsumerStatefulWidget {
  const ApkSharingPage({super.key});

  @override
  ConsumerState<ApkSharingPage> createState() => _ApkSharingPageState();
}

class _ApkSharingPageState extends ConsumerState<ApkSharingPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.trim().isEmpty 
          ? const Text('APK Sharing')
          : Text('APK Sharing - "${_searchQuery.trim()}"'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (_searchQuery.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshApps,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'extract_all',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Extract All'),
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('Backup Apps'),
                ),
              ),
              const PopupMenuItem(
                value: 'cleanup',
                child: ListTile(
                  leading: Icon(Icons.cleaning_services),
                  title: Text('Cleanup APKs'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.apps), text: 'Installed Apps'),
            Tab(icon: Icon(Icons.file_download), text: 'Extracted APKs'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInstalledAppsTab(),
          _buildExtractedApksTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExtractDialog,
        child: const Icon(Icons.download),
      ),
    );
  }

  Widget _buildInstalledAppsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final installedApps = ref.watch(getInstalledAppsProvider);
        
        return installedApps.when(
          data: (apps) => _buildAppsList(apps.map((app) => InstalledApp(
            packageName: app.packageName,
            name: app.appName,
            version: app.versionName,
            versionCode: app.versionCode,
            size: app.size,
            iconPath: app.iconPath,
            installedAt: app.installDate,
          )).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading apps: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getInstalledAppsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtractedApksTab() {
    return Consumer(
      builder: (context, ref, child) {
        final extractedApks = ref.watch(getExtractedApksProvider);
        
        return extractedApks.when(
          data: (apks) => _buildApksList(apks),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading APKs: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getExtractedApksProvider),
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
        final history = ref.watch(extractionHistoryProvider);
        
        return history.when(
          data: (historyItems) => _buildHistoryList(historyItems),
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
                  onPressed: () => ref.invalidate(extractionHistoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppsList(List<InstalledApp> apps) {
    // Filter apps based on search query
    final filteredApps = _filterApps(apps);
    
    if (filteredApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apps,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.trim().isEmpty ? 'No apps found' : 'No apps match your search',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.trim().isEmpty 
                ? 'Make sure apps are installed on your device'
                : 'Try a different search term',
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
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        return AppCard(
          app: _createAppInfo(app),
          isSelected: false,
          isExtracting: false,
          extractionProgress: 0.0,
          onTap: () => _selectApp(app),
          onLongPress: () => _showAppOptions(app),
          onExtract: () => _extractApk(app),
        );
      },
    );
  }

  Widget _buildApksList(List<ExtractedApk> apks) {
    // Filter APKs based on search query
    final filteredApks = _filterApks(apks);
    
    if (filteredApks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.file_download,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.trim().isEmpty ? 'No extracted APKs' : 'No APKs match your search',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.trim().isEmpty 
                ? 'Extract APKs from installed apps to see them here'
                : 'Try a different search term',
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
      itemCount: filteredApks.length,
      itemBuilder: (context, index) {
        final apk = filteredApks[index];
        return ExtractedApkCard(
          packageName: apk.packageName,
          apkPath: apk.apkPath,
          onInstall: () => _installApk(apk),
          onShare: () => _shareApk(apk),
          onDelete: () => _deleteApk(apk),
          onInfo: () => _showApkInfo(apk),
        );
      },
    );
  }

  Widget _buildHistoryList(List<ExtractionHistoryItem> history) {
    // Filter history based on search query
    final filteredHistory = _filterHistory(history);
    
    if (filteredHistory.isEmpty) {
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
              _searchQuery.trim().isEmpty ? 'No extraction history' : 'No history matches your search',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.trim().isEmpty 
                ? 'Your APK extraction history will appear here'
                : 'Try a different search term',
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
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final item = filteredHistory[index];
        return ExtractionHistoryCard(
          item: item,
          onTap: () => _viewHistoryItem(item),
          onDelete: () => _deleteHistoryItem(item),
        );
      },
    );
  }

  // Filtering methods
  List<InstalledApp> _filterApps(List<InstalledApp> apps) {
    if (_searchQuery.trim().isEmpty) {
      return apps;
    }
    
    final query = _searchQuery.trim().toLowerCase();
    return apps.where((app) {
      return app.name.toLowerCase().contains(query) ||
             app.packageName.toLowerCase().contains(query);
    }).toList();
  }

  List<ExtractedApk> _filterApks(List<ExtractedApk> apks) {
    if (_searchQuery.trim().isEmpty) {
      return apks;
    }
    
    final query = _searchQuery.trim().toLowerCase();
    return apks.where((apk) {
      return apk.name.toLowerCase().contains(query) ||
             apk.packageName.toLowerCase().contains(query);
    }).toList();
  }

  List<ExtractionHistoryItem> _filterHistory(List<ExtractionHistoryItem> history) {
    if (_searchQuery.trim().isEmpty) {
      return history;
    }
    
    final query = _searchQuery.trim().toLowerCase();
    return history.where((item) {
      return item.appName.toLowerCase().contains(query) ||
             item.packageName.toLowerCase().contains(query);
    }).toList();
  }

  void _extractApk(InstalledApp app) {
    // TODO: Implement APK extraction
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Extracting APK: ${app.name}')),
    );
  }


  void _installApk(ExtractedApk apk) {
    // TODO(apk-sharing): Implement APK installation
    // Call ApkExtractorService.installApk(apk.apkPath)
    // Native layer will open system install prompt
    throw UnimplementedError('APK installation backend not yet implemented - see Phase 4 plan');
  }

  void _shareApk(ExtractedApk apk) {
    // TODO(apk-sharing): Implement APK sharing
    // Hook into transfer system to share apk.apkPath via TransferRepository
    throw UnimplementedError('APK sharing backend not yet implemented - see Phase 4 plan');
  }

  void _deleteApk(ExtractedApk apk) {
    // TODO: Implement APK deletion
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting APK: ${apk.name}')),
    );
  }

  void _showApkInfo(ExtractedApk apk) {
    showDialog(
      context: context,
      builder: (context) => ApkInfoDialog(apk: apk),
    );
  }


  void _deleteHistoryItem(ExtractionHistoryItem item) {
    // TODO: Implement history item deletion
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting history: ${item.appName}')),
    );
  }

  void _showSearchDialog() {
    _searchController.text = _searchQuery;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Apps'),
        content: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for apps, APKs, or history...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = _searchController.text;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _refreshApps() {
    // TODO: Implement app refresh
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing apps...')),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'extract_all':
        _extractAllApps();
        break;
      case 'backup':
        _backupApps();
        break;
      case 'cleanup':
        _cleanupApks();
        break;
    }
  }

  void _extractAllApps() {
    // TODO: Implement extract all apps
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extracting all apps...')),
    );
  }

  void _backupApps() {
    // TODO: Implement app backup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backing up apps...')),
    );
  }

  void _cleanupApks() {
    // TODO: Implement APK cleanup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleaning up APKs...')),
    );
  }

  void _showExtractDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extract APK'),
        content: const Text('Select an app to extract its APK file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Show app selection dialog
            },
            child: const Text('Select App'),
          ),
        ],
      ),
    );
  }

  /// Creates AppInfo from InstalledApp with consistent field mapping
  AppInfo _createAppInfo(InstalledApp app) {
    return AppInfo(
      packageName: app.packageName,
      appName: app.name,
      versionName: app.version,
      versionCode: app.versionCode,
      size: app.size,
      iconPath: app.iconPath,
      installDate: app.installedAt,
      updateDate: app.installedAt, // TODO: Get actual update date from app metadata
      isSystemApp: false, // TODO: Determine if app is system app
      isUserApp: true, // TODO: Determine if app is user app
      permissions: [], // TODO: Get actual app permissions
    );
  }

  void _selectApp(InstalledApp app) {
    // TODO: Implement app selection
  }

  void _showAppOptions(InstalledApp app) {
    // TODO: Implement app options
  }

  void _viewHistoryItem(ExtractionHistoryItem item) {
    // TODO: Implement view history item
  }
}
