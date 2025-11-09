import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/providers/app_providers.dart';

/// Smart Navigation Widget with micro-connected buttons and fallback mechanisms
/// Provides intuitive navigation with breadcrumbs, back/forward functionality, and quick access
class SmartNavigationWidget extends ConsumerStatefulWidget {
  final Widget child;
  final String? title;
  final List<NavigationAction>? actions;
  final bool showBackButton;
  final bool showBreadcrumbs;
  final VoidCallback? onBack;

  const SmartNavigationWidget({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showBackButton = true,
    this.showBreadcrumbs = true,
    this.onBack,
  });

  @override
  ConsumerState<SmartNavigationWidget> createState() => _SmartNavigationWidgetState();
}

class _SmartNavigationWidgetState extends ConsumerState<SmartNavigationWidget> {
  final List<AppPage> _navigationHistory = [AppPage.home];
  int _currentHistoryIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with current page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentPage = ref.read(currentPageProvider);
      if (!_navigationHistory.contains(currentPage)) {
        _addToHistory(currentPage);
      }
    });
  }

  void _addToHistory(AppPage page) {
    // Remove any forward history if we're not at the end
    if (_currentHistoryIndex < _navigationHistory.length - 1) {
      _navigationHistory.removeRange(_currentHistoryIndex + 1, _navigationHistory.length);
    }
    
    // Add new page if it's different from current
    if (_navigationHistory.isEmpty || _navigationHistory.last != page) {
      _navigationHistory.add(page);
      _currentHistoryIndex = _navigationHistory.length - 1;
    }
    
    // Limit history size
    if (_navigationHistory.length > 10) {
      _navigationHistory.removeAt(0);
      _currentHistoryIndex--;
    }
  }

  bool get canGoBack => _currentHistoryIndex > 0;
  bool get canGoForward => _currentHistoryIndex < _navigationHistory.length - 1;

  void _goBack() {
    if (canGoBack) {
      _currentHistoryIndex--;
      final page = _navigationHistory[_currentHistoryIndex];
      ref.read(currentPageProvider.notifier).state = page;
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else {
      // Fallback to home
      ref.read(currentPageProvider.notifier).state = AppPage.home;
    }
  }

  void _goForward() {
    if (canGoForward) {
      _currentHistoryIndex++;
      final page = _navigationHistory[_currentHistoryIndex];
      ref.read(currentPageProvider.notifier).state = page;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = ref.watch(currentPageProvider);
    
    // Update history when page changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigationHistory.isEmpty || _navigationHistory[_currentHistoryIndex] != currentPage) {
        _addToHistory(currentPage);
      }
    });

    return Scaffold(
      appBar: _buildSmartAppBar(theme, currentPage),
      body: Column(
        children: [
          if (widget.showBreadcrumbs) _buildBreadcrumbs(theme),
          Expanded(child: widget.child),
          _buildMicroNavigationBar(theme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSmartAppBar(ThemeData theme, AppPage currentPage) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      leading: widget.showBackButton
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: _goBack,
            )
          : null,
      title: Row(
        children: [
          if (widget.title != null) ...[
            Expanded(
              child: Text(
                widget.title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Text(
                _getPageTitle(currentPage),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Navigation history buttons
        if (canGoBack)
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20),
            onPressed: _goBack,
            tooltip: 'Go Back',
          ),
        if (canGoForward)
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 20),
            onPressed: _goForward,
            tooltip: 'Go Forward',
          ),
        
        // Quick access menu
        PopupMenuButton<AppPage>(
          icon: Icon(Icons.apps_rounded),
          tooltip: 'Quick Access',
          onSelected: (page) {
            ref.read(currentPageProvider.notifier).state = page;
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: AppPage.home,
              child: ListTile(
                leading: Icon(Icons.home_rounded, size: 20),
                title: Text('Home'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: AppPage.send,
              child: ListTile(
                leading: Icon(Icons.send_rounded, size: 20),
                title: Text('Send Files'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: AppPage.receive,
              child: ListTile(
                leading: Icon(Icons.download_rounded, size: 20),
                title: Text('Receive Files'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: AppPage.history,
              child: ListTile(
                leading: Icon(Icons.history_rounded, size: 20),
                title: Text('History'),
                dense: true,
              ),
            ),
          ],
        ),
        
        // Custom actions
        if (widget.actions != null)
          ...widget.actions!.map((action) => IconButton(
                icon: Icon(action.icon),
                onPressed: action.onPressed,
                tooltip: action.tooltip,
              )),
      ],
    );
  }

  Widget _buildBreadcrumbs(ThemeData theme) {
    if (_navigationHistory.length <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.navigation_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbItems(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBreadcrumbItems(ThemeData theme) {
    final items = <Widget>[];
    final visibleHistory = _navigationHistory.take(_currentHistoryIndex + 1).toList();
    
    for (int i = 0; i < visibleHistory.length; i++) {
      final page = visibleHistory[i];
      final isLast = i == visibleHistory.length - 1;
      final isCurrent = i == _currentHistoryIndex;
      
      items.add(
        GestureDetector(
          onTap: () {
            if (!isCurrent) {
              _currentHistoryIndex = i;
              ref.read(currentPageProvider.notifier).state = page;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent 
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getPageTitle(page),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCurrent 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
      
      if (!isLast) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        );
      }
    }
    
    return items;
  }

  Widget _buildMicroNavigationBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMicroButton(
            theme,
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: () => ref.read(currentPageProvider.notifier).state = AppPage.home,
            isActive: ref.watch(currentPageProvider) == AppPage.home,
          ),
          _buildMicroButton(
            theme,
            icon: Icons.send_rounded,
            label: 'Send',
            onTap: () => ref.read(currentPageProvider.notifier).state = AppPage.send,
            isActive: ref.watch(currentPageProvider) == AppPage.send,
          ),
          _buildMicroButton(
            theme,
            icon: Icons.download_rounded,
            label: 'Receive',
            onTap: () => ref.read(currentPageProvider.notifier).state = AppPage.receive,
            isActive: ref.watch(currentPageProvider) == AppPage.receive,
          ),
          _buildMicroButton(
            theme,
            icon: Icons.history_rounded,
            label: 'History',
            onTap: () => ref.read(currentPageProvider.notifier).state = AppPage.history,
            isActive: ref.watch(currentPageProvider) == AppPage.history,
          ),
          _buildMicroButton(
            theme,
            icon: Icons.more_horiz_rounded,
            label: 'More',
            onTap: () => _showMoreOptions(context),
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMicroButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More Options',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                            // Core Features Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.video_settings_rounded,
                                label: 'Video\nCompression',
                                color: Colors.red,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.videoCompression;
                                },
                              ),
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.play_circle_rounded,
                                label: 'Media\nPlayer',
                                color: Colors.purple,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.mediaPlayer;
                                },
                              ),
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.folder_rounded,
                                label: 'File\nManager',
                                color: Colors.orange,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.fileManager;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // QR Features Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'QR\nScanner',
                                color: Colors.green,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.of(context).pushNamed('/enhanced_qr_scanner');
                                },
                              ),
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.qr_code_rounded,
                                label: 'QR\nDisplay',
                                color: Colors.blue,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.of(context).pushNamed('/enhanced_qr_display');
                                },
                              ),
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.settings_rounded,
                                label: 'Settings',
                                color: Colors.grey,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.settings;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Advanced Features Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.android_rounded,
                                label: 'APK\nSharing',
                                color: Colors.teal,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.apkSharing;
                                },
                              ),
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.cloud_rounded,
                                label: 'Cloud\nSync',
                                color: Colors.indigo,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.cloudSync;
                                },
                              ),
                              _buildMoreOptionItem(
                                context,
                                icon: Icons.group_rounded,
                                label: 'Group\nSharing',
                                color: Colors.pink,
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(currentPageProvider.notifier).state = AppPage.groupSharing;
                                },
                              ),
                            ],
                          ),
                            ],
                          ),
                        ),
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

  Widget _buildMoreOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.primary;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: itemColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: itemColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: itemColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: itemColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: itemColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle(AppPage page) {
    switch (page) {
      case AppPage.home:
        return 'Home';
      case AppPage.send:
        return 'Send Files';
      case AppPage.receive:
        return 'Receive Files';
      case AppPage.history:
        return 'Transfer History';
      case AppPage.mediaPlayer:
        return 'Media Player';
      case AppPage.fileManager:
        return 'File Manager';
      case AppPage.apkSharing:
        return 'APK Sharing';
      case AppPage.cloudSync:
        return 'Cloud Sync';
      case AppPage.videoCompression:
        return 'Video Compression';
      case AppPage.phoneReplication:
        return 'Phone Replication';
      case AppPage.groupSharing:
        return 'Group Sharing';
      default:
        return 'AirLink';
    }
  }
}

/// Navigation action for custom app bar buttons
class NavigationAction {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const NavigationAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });
}
