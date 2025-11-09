import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/dependency_injection.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';
import 'package:airlink/core/protocol/resume_database.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/core/constants/feature_flags.dart';
import 'package:airlink/shared/providers/app_providers.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/features/home/presentation/pages/modern_home_page.dart';
import 'package:airlink/features/transfer/presentation/pages/modern_send_page.dart';
import 'package:airlink/features/transfer/presentation/pages/modern_receive_page.dart';
import 'package:airlink/features/transfer/presentation/pages/modern_transfer_history_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/media_player_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/file_manager_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/video_compression_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/apk_sharing_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/cloud_sync_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/group_sharing_page.dart';
import 'package:airlink/features/advanced_features/presentation/pages/phone_replication_page.dart';
import 'package:airlink/shared/theme/zapya_theme.dart';
import 'package:airlink/shared/widgets/smart_navigation_widget.dart';
import 'package:airlink/pages/enhanced_qr_scanner_page.dart';
import 'package:airlink/pages/enhanced_qr_display_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On desktop platforms, initialize sqflite FFI so `sqflite` APIs work.
  // Without this, calls to openDatabase will throw "databaseFactory not initialized"
  // and can cause dependency registration (which depends on DB init) to fail.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  try {
    // Initialize core services with error handling for mobile platforms
    await configureDependencies();
  } catch (e) {
    // If dependency injection fails, continue with limited functionality
    print('Warning: Failed to initialize dependencies: $e');
  }
  
  runApp(const AirLinkApp());
}

class AirLinkApp extends StatelessWidget {
  const AirLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: ErrorBoundary(
        child: MaterialApp(
          title: 'AirLink',
          theme: ZapyaTheme.lightTheme,
          darkTheme: ZapyaTheme.darkTheme,
          themeMode: FeatureFlags.DARK_MODE_ENABLED ? ThemeMode.system : ThemeMode.light,
          home: const SplashInitPage(),
          routes: {
            '/enhanced_qr_scanner': (context) => const EnhancedQRScannerPage(),
            '/enhanced_qr_display': (context) => const EnhancedQRDisplayPage(
                  deviceName: 'AirLink Device',
                ),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: Text('Route not found'),
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Splash/initializer that defers heavy startup work until after first frame
class SplashInitPage extends StatefulWidget {
  const SplashInitPage({super.key});

  @override
  State<SplashInitPage> createState() => _SplashInitPageState();
}

class _SplashInitPageState extends State<SplashInitPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAsync();
    });
  }

  Future<void> _initializeAsync() async {
    try {
      // Cap initialization to avoid indefinite white screen if a plugin hangs
      final futures = <Future>[];
      
      // Add ResumeDatabase initialization with error handling
      try {
        futures.add(ResumeDatabase.initialize().timeout(const Duration(seconds: 3)));
      } catch (e) {
        print('Warning: ResumeDatabase initialization failed: $e');
      }
      
      // Add TransferBenchmarkingService initialization with error handling
      try {
        if (getIt.isRegistered<TransferBenchmarkingService>()) {
          futures.add(getIt<TransferBenchmarkingService>().initialize().timeout(const Duration(seconds: 3)));
        }
      } catch (e) {
        print('Warning: TransferBenchmarkingService initialization failed: $e');
      }
      
      // Wait for all futures with individual error handling
      await Future.wait(futures, eagerError: false);
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppNavigator()),
      );
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      // Still navigate after a short delay to show UI even if init partially failed
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppNavigator()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text('Initialization failed'),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _errorMessage = null);
                    _initializeAsync();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Main app navigator that handles page routing
class AppNavigator extends ConsumerWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProvider);
    
    return SmartNavigationWidget(
      child: _buildPage(currentPage),
    );
  }

  Widget _buildPage(AppPage page) {
    switch (page) {
      case AppPage.home:
        return const ModernHomePage();
      case AppPage.send:
        return const ModernSendPage();
      case AppPage.receive:
        return const ModernReceivePage();
      case AppPage.history:
        return const ModernTransferHistoryPage();
      case AppPage.mediaPlayer:
        return const MediaPlayerPage();
      case AppPage.fileManager:
        return const FileManagerPage();
      case AppPage.apkSharing:
        return const ApkSharingPage();
      case AppPage.cloudSync:
        return const CloudSyncPage();
      case AppPage.videoCompression:
        return const VideoCompressionPage();
      case AppPage.phoneReplication:
        return const PhoneReplicationPage();
      case AppPage.groupSharing:
        return const GroupSharingPage();
      case AppPage.settings:
        return const SettingsPage();
    }
  }
}

/// Comprehensive Settings Page
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernAppBar(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsSection(
                      theme,
                      'General',
                      Icons.tune_rounded,
                      [
                        _buildSettingsTile(
                          theme,
                          'Device Name',
                          'AirLink Device',
                          Icons.phone_android_rounded,
                          onTap: () => _showDeviceNameDialog(context),
                        ),
                        _buildSettingsTile(
                          theme,
                          'Theme',
                          'System',
                          Icons.palette_rounded,
                          onTap: () => _showThemeDialog(context),
                        ),
                        _buildSettingsTile(
                          theme,
                          'Language',
                          'English',
                          Icons.language_rounded,
                          onTap: () => _showLanguageDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      theme,
                      'Transfer',
                      Icons.swap_horiz_rounded,
                      [
                        _buildSwitchTile(
                          theme,
                          'Auto Accept Transfers',
                          'Automatically accept incoming transfers',
                          false,
                          Icons.download_rounded,
                          (value) {},
                        ),
                        _buildSwitchTile(
                          theme,
                          'Background Transfers',
                          'Continue transfers when app is in background',
                          true,
                          Icons.cloud_download_rounded,
                          (value) {},
                        ),
                        _buildSwitchTile(
                          theme,
                          'WiFi Only',
                          'Only transfer files over WiFi',
                          false,
                          Icons.wifi_rounded,
                          (value) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      theme,
                      'Security',
                      Icons.security_rounded,
                      [
                        _buildSwitchTile(
                          theme,
                          'Encryption',
                          'Encrypt all file transfers',
                          true,
                          Icons.lock_rounded,
                          (value) {},
                        ),
                        _buildSwitchTile(
                          theme,
                          'Certificate Pinning',
                          'Enhanced security for connections',
                          false,
                          Icons.verified_user_rounded,
                          (value) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      theme,
                      'Notifications',
                      Icons.notifications_rounded,
                      [
                        _buildSwitchTile(
                          theme,
                          'Push Notifications',
                          'Receive transfer notifications',
                          true,
                          Icons.notifications_active_rounded,
                          (value) {},
                        ),
                        _buildSwitchTile(
                          theme,
                          'Sound',
                          'Play sound for notifications',
                          true,
                          Icons.volume_up_rounded,
                          (value) {},
                        ),
                        _buildSwitchTile(
                          theme,
                          'Vibration',
                          'Vibrate for notifications',
                          true,
                          Icons.vibration_rounded,
                          (value) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      theme,
                      'Advanced',
                      Icons.engineering_rounded,
                      [
                        _buildSettingsTile(
                          theme,
                          'Storage Location',
                          'Downloads',
                          Icons.folder_rounded,
                          onTap: () => _showStorageDialog(context),
                        ),
                        _buildSettingsTile(
                          theme,
                          'File Types',
                          'Manage allowed file types',
                          Icons.file_present_rounded,
                          onTap: () => _showFileTypesDialog(context),
                        ),
                        _buildSettingsTile(
                          theme,
                          'Clear History',
                          'Remove all transfer history',
                          Icons.delete_sweep_rounded,
                          onTap: () => _showClearHistoryDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsSection(
                      theme,
                      'About',
                      Icons.info_rounded,
                      [
                        _buildSettingsTile(
                          theme,
                          'Version',
                          '1.0.0',
                          Icons.info_outline_rounded,
                        ),
                        _buildSettingsTile(
                          theme,
                          'Privacy Policy',
                          'View privacy policy',
                          Icons.privacy_tip_rounded,
                          onTap: () => _showPrivacyPolicy(context),
                        ),
                        _buildSettingsTile(
                          theme,
                          'Terms of Service',
                          'View terms of service',
                          Icons.description_rounded,
                          onTap: () => _showTermsOfService(context),
                        ),
                      ],
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
  
  Widget _buildModernAppBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Customize your AirLink experience',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color.fromARGB(25, 
                  (theme.colorScheme.primary.computeLuminance() * 255).round(),
                  (theme.colorScheme.primary.computeLuminance() * 255).round(),
                  (theme.colorScheme.primary.computeLuminance() * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
  
  Widget _buildSettingsTile(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: onTap,
    );
  }
  
  Widget _buildSwitchTile(
    ThemeData theme,
    String title,
    String subtitle,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
  
  // Dialog methods
  void _showDeviceNameDialog(BuildContext context) {
    // TODO: Implement device name dialog
  }
  
  void _showThemeDialog(BuildContext context) {
    // TODO: Implement theme selection dialog
  }
  
  void _showLanguageDialog(BuildContext context) {
    // TODO: Implement language selection dialog
  }
  
  void _showStorageDialog(BuildContext context) {
    // TODO: Implement storage location dialog
  }
  
  void _showFileTypesDialog(BuildContext context) {
    // TODO: Implement file types dialog
  }
  
  void _showClearHistoryDialog(BuildContext context) {
    // TODO: Implement clear history dialog
  }
  
  void _showPrivacyPolicy(BuildContext context) {
    // TODO: Implement privacy policy viewer
  }
  
  void _showTermsOfService(BuildContext context) {
    // TODO: Implement terms of service viewer
  }
}