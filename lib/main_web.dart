import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/core/constants/feature_flags.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/features/home/presentation/pages/home_page_web.dart';
import 'package:airlink/features/transfer/presentation/pages/send_picker_page_web.dart';
import 'package:airlink/features/transfer/presentation/pages/receive_page_web.dart';
import 'package:airlink/features/transfer/presentation/pages/transfer_history_page_web.dart';
import 'package:airlink/features/common/presentation/pages/coming_soon_page.dart';
import 'package:airlink/shared/theme/zapya_theme.dart';
import 'package:airlink/shared/providers/app_providers_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AirLinkWebApp());
}

class AirLinkWebApp extends StatelessWidget {
  const AirLinkWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: ErrorBoundary(
        child: MaterialApp(
          title: 'AirLink - Web Demo',
          theme: ZapyaTheme.lightTheme,
          darkTheme: ZapyaTheme.darkTheme,
          themeMode: FeatureFlags.DARK_MODE_ENABLED ? ThemeMode.system : ThemeMode.light,
          home: const WebAppNavigator(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Web app navigator that handles page routing
class WebAppNavigator extends ConsumerWidget {
  const WebAppNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProviderWeb);
    
    return Scaffold(
      body: _buildPage(currentPage),
      bottomNavigationBar: _buildBottomNavigation(context, ref),
      drawer: _buildDrawer(context, ref),
    );
  }

  Widget _buildPage(AppPage page) {
    switch (page) {
      case AppPage.home:
        return const HomePageWeb();
      case AppPage.send:
        return const SendPickerPageWeb();
      case AppPage.receive:
        return const ReceivePageWeb();
      case AppPage.history:
        return const TransferHistoryPageWeb();
      case AppPage.mediaPlayer:
        return const ComingSoonPage(
          featureName: 'Media Player',
          description: 'Play media files directly in the app.',
          icon: Icons.play_circle_outline,
          capabilities: [
            'Video playback',
            'Audio playback',
            'Playlist management',
            'Media controls',
          ],
          estimatedRelease: 'Q3 2024',
          completionPercentage: 25,
        );
      case AppPage.fileManager:
        return const ComingSoonPage(
          featureName: 'File Manager',
          description: 'Browse and manage files on your device.',
          icon: Icons.folder_outlined,
          capabilities: [
            'File browsing',
            'File operations',
            'Storage analysis',
            'File search',
          ],
          estimatedRelease: 'Q3 2024',
          completionPercentage: 30,
        );
      case AppPage.apkSharing:
        return const ComingSoonPage(
          featureName: 'APK Sharing',
          description: 'Share and install apps easily.',
          icon: Icons.android,
          capabilities: [
            'APK file sharing',
            'App installation assistance',
            'App metadata display',
            'Version compatibility checking',
          ],
          estimatedRelease: 'Q3 2024',
          completionPercentage: 20,
        );
      case AppPage.cloudSync:
        return const ComingSoonPage(
          featureName: 'Cloud Sync',
          description: 'Sync files with cloud storage providers.',
          icon: Icons.cloud,
          capabilities: [
            'Multi-cloud provider support',
            'Automatic sync scheduling',
            'Conflict resolution',
            'Bandwidth optimization',
          ],
          estimatedRelease: 'Q3 2024',
          completionPercentage: 15,
        );
      case AppPage.videoCompression:
        return const ComingSoonPage(
          featureName: 'Video Compression',
          description: 'Compress videos before sharing.',
          icon: Icons.video_settings,
          capabilities: [
            'Smart video compression',
            'Quality vs size optimization',
            'Batch processing',
            'Format conversion',
          ],
          estimatedRelease: 'Q3 2024',
          completionPercentage: 25,
        );
      case AppPage.phoneReplication:
        return const ComingSoonPage(
          featureName: 'Phone Replication',
          description: 'Replicate phone data to another device.',
          icon: Icons.phone_android,
          capabilities: [
            'Contact synchronization',
            'App data transfer',
            'Settings migration',
            'Media library sync',
          ],
          estimatedRelease: 'Q4 2024',
          completionPercentage: 10,
        );
      case AppPage.groupSharing:
        return const ComingSoonPage(
          featureName: 'Group Sharing',
          description: 'Share files with multiple devices simultaneously.',
          icon: Icons.group,
          capabilities: [
            'Multi-device broadcasting',
            'Group management',
            'Selective sharing',
            'Progress tracking',
          ],
          estimatedRelease: 'Q4 2024',
          completionPercentage: 5,
        );
      case AppPage.settings:
        return const SettingsPageWeb();
    }
  }

  Widget _buildBottomNavigation(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProviderWeb);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                ref,
                AppPage.home,
                Icons.home_outlined,
                Icons.home,
                'Home',
                currentPage,
              ),
              _buildNavItem(
                context,
                ref,
                AppPage.send,
                Icons.send_outlined,
                Icons.send,
                'Send',
                currentPage,
              ),
              _buildNavItem(
                context,
                ref,
                AppPage.receive,
                Icons.download_outlined,
                Icons.download,
                'Receive',
                currentPage,
              ),
              _buildNavItem(
                context,
                ref,
                AppPage.history,
                Icons.history_outlined,
                Icons.history,
                'History',
                currentPage,
              ),
              _buildNavItem(
                context,
                ref,
                AppPage.settings,
                Icons.settings_outlined,
                Icons.settings,
                'Settings',
                currentPage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProviderWeb);
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.airplanemode_active,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Text(
                  'AirLink',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Fast & Secure File Transfer - Web Demo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.history,
            Icons.history,
            'Transfer History',
            currentPage,
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            ref,
            AppPage.mediaPlayer,
            Icons.play_circle_outline,
            'Media Player',
            currentPage,
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.fileManager,
            Icons.folder_outlined,
            'File Manager',
            currentPage,
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.apkSharing,
            Icons.android,
            'APK Sharing',
            currentPage,
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.cloudSync,
            Icons.cloud,
            'Cloud Sync',
            currentPage,
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.videoCompression,
            Icons.video_settings,
            'Video Compression',
            currentPage,
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.phoneReplication,
            Icons.phone_android,
            'Phone Replication',
            currentPage,
          ),
          _buildDrawerItem(
            context,
            ref,
            AppPage.groupSharing,
            Icons.group,
            'Group Sharing',
            currentPage,
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            ref,
            AppPage.settings,
            Icons.settings,
            'Settings',
            currentPage,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    WidgetRef ref,
    AppPage page,
    IconData icon,
    String title,
    AppPage currentPage,
  ) {
    final isSelected = currentPage == page;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context);
        ref.read(currentPageProviderWeb.notifier).state = page;
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    AppPage page,
    IconData icon,
    IconData activeIcon,
    String label,
    AppPage currentPage,
  ) {
    final isSelected = currentPage == page;
    
    return GestureDetector(
      onTap: () {
        ref.read(currentPageProviderWeb.notifier).state = page;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder settings page for web
class SettingsPageWeb extends StatelessWidget {
  const SettingsPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Web demo - Settings page coming soon',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}