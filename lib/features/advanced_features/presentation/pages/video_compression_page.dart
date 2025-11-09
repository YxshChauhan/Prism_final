import 'package:flutter/material.dart';

/// Video Compression Page
/// 
/// Provides video compression interface with presets and custom settings
/// Similar to SHAREit/Zapya video compression functionality
class VideoCompressionPage extends StatefulWidget {
  const VideoCompressionPage({super.key});

  @override
  State<VideoCompressionPage> createState() => _VideoCompressionPageState();
}

class _VideoCompressionPageState extends State<VideoCompressionPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Compression'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'batch_compress',
                child: Text('Batch Compress'),
              ),
              const PopupMenuItem(
                value: 'presets',
                child: Text('Manage Presets'),
              ),
              const PopupMenuItem(
                value: 'cleanup',
                child: Text('Cleanup'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            Tab(text: 'Active', icon: Icon(Icons.play_circle)),
            Tab(text: 'History', icon: Icon(Icons.history)),
            Tab(text: 'Presets', icon: Icon(Icons.tune)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideosTab(),
          _buildActiveJobsTab(),
          _buildHistoryTab(),
          _buildPresetsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCompressDialog,
        child: const Icon(Icons.compress),
      ),
    );
  }

  Widget _buildVideosTab() {
    return _buildEmptyState(
      icon: Icons.video_library_outlined,
      title: 'No videos found',
      subtitle: 'Add videos to compress them',
    );
  }

  Widget _buildActiveJobsTab() {
    return _buildEmptyState(
      icon: Icons.play_circle_outline,
      title: 'No active compression jobs',
      subtitle: 'Start compressing videos to see active jobs here',
    );
  }

  Widget _buildHistoryTab() {
    return _buildEmptyState(
      icon: Icons.history,
      title: 'No compression history',
      subtitle: 'Your compression history will appear here',
    );
  }

  Widget _buildPresetsTab() {
    return _buildEmptyState(
      icon: Icons.tune,
      title: 'No compression presets',
      subtitle: 'Create presets to quickly compress videos',
      showCreateButton: true,
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showCreateButton = false,
  }) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (showCreateButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _createPreset,
                icon: const Icon(Icons.add),
                label: const Text('Create Preset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Videos'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search for videos...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            // Search functionality placeholder
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement search
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compression Settings'),
        content: const Text('Video compression settings will be available here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'batch_compress':
        _batchCompress();
        break;
      case 'presets':
        _managePresets();
        break;
      case 'cleanup':
        _cleanup();
        break;
    }
  }

  void _batchCompress() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Batch compression feature coming soon')),
    );
  }

  void _managePresets() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preset management feature coming soon')),
    );
  }

  void _cleanup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleanup feature coming soon')),
    );
  }

  void _createPreset() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create preset feature coming soon')),
    );
  }

  void _showCompressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compress Video'),
        content: const Text('Video compression feature is coming soon. This will allow you to compress videos with various quality presets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
