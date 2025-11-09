import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Group Sharing Page
/// 
/// Provides multi-device sharing interface
/// Similar to SHAREit/Zapya group sharing functionality
class GroupSharingPage extends ConsumerStatefulWidget {
  const GroupSharingPage({super.key});

  @override
  ConsumerState<GroupSharingPage> createState() => _GroupSharingPageState();
}

class _GroupSharingPageState extends ConsumerState<GroupSharingPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // Removed unused private field _sharingStatus; provider-driven status is used

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

  /// Formats error objects into user-friendly messages while logging full details for debugging
  String _formatError(Object error) {
    // Log full error details for debugging
    debugPrint('GroupSharingPage Error: $error');
    
    // Convert error to string for pattern matching
    final errorString = error.toString().toLowerCase();
    
    // Map network-related errors to user-friendly messages
    if (errorString.contains('network') || 
        errorString.contains('connection') || 
        errorString.contains('timeout') ||
        errorString.contains('unreachable') ||
        errorString.contains('socket') ||
        errorString.contains('dns')) {
      return 'Network connection error. Please check your internet connection.';
    }
    
    // Map permission-related errors
    if (errorString.contains('permission') || 
        errorString.contains('denied') ||
        errorString.contains('unauthorized')) {
      return 'Permission denied. Please check your app permissions.';
    }
    
    // Map storage-related errors
    if (errorString.contains('storage') || 
        errorString.contains('disk') ||
        errorString.contains('space')) {
      return 'Storage error. Please check available space.';
    }
    
    // Map server-related errors
    if (errorString.contains('server') || 
        errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return 'Server error. Please try again later.';
    }
    
    // Default generic message for unknown errors
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Sharing'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshGroups,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create_group',
                child: ListTile(
                  leading: Icon(Icons.group_add),
                  title: Text('Create Group'),
                ),
              ),
              const PopupMenuItem(
                value: 'join_group',
                child: ListTile(
                  leading: Icon(Icons.group),
                  title: Text('Join Group'),
                ),
              ),
              const PopupMenuItem(
                value: 'scan_qr',
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner),
                  title: Text('Scan QR Code'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Active Groups'),
            Tab(icon: Icon(Icons.share), text: 'Sharing'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveGroupsTab(),
          _buildSharingTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildActiveGroupsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final activeGroups = ref.watch(getActiveGroupsProvider);
        
        return activeGroups.when(
          data: (groups) => _buildGroupsList(groups),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading groups: ${_formatError(error)}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getActiveGroupsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSharingTab() {
    return Consumer(
      builder: (context, ref, child) {
        final sharingSessions = ref.watch(getSharingSessionsProvider);
        
        return sharingSessions.when(
          data: (sessions) => _buildSharingSessionsList(sessions),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading sharing sessions: ${_formatError(error)}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getSharingSessionsProvider),
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
        final history = ref.watch(getGroupSharingHistoryProvider);
        
        return history.when(
          data: (historyItems) => _buildHistoryList(historyItems),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading history: ${_formatError(error)}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getGroupSharingHistoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList(List<Group> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No active groups',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a group to start sharing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.group_add),
              label: const Text('Create Group'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildSharingSessionsList(List<SharingSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No active sharing sessions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start sharing files to see sessions here',
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
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSharingSessionCard(session);
      },
    );
  }

  Widget _buildHistoryList(List<GroupSharingHistoryItem> history) {
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
              'No sharing history',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your group sharing history will appear here',
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

  Widget _buildGroupCard(Group group) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${group.memberCount} members',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showGroupMenu(group),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGroupMembers(group.members),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _joinGroup(group),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Join'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareToGroup(group),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMembers(List<GroupMember> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Members',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _buildMemberAvatar(member);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(GroupMember member) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member.name,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSharingSessionCard(SharingSession session) {
    return Card(
      child: ListTile(
        leading: Icon(_getSessionIcon(_parseSharingSessionStatus(session.status))),
        title: Text(session.groupName),
        subtitle: Text('${session.fileCount} files - ${session.status}'),
        trailing: Text('${session.progress}%'),
        onTap: () => _showSessionDetails(session),
      ),
    );
  }

  Widget _buildHistoryItemCard(GroupSharingHistoryItem item) {
    return Card(
      child: ListTile(
        leading: Icon(_getHistoryIcon(item.type)),
        title: Text(item.groupName),
        subtitle: Text('${item.date} - ${item.fileCount} files'),
        trailing: Text('${item.dataSize} MB'),
        onTap: () => _showHistoryDetails(item),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final sharingStatus = ref.watch(groupSharingStatusProvider);
    
    switch (sharingStatus) {
      case GroupSharingStatus.idle:
        return FloatingActionButton(
          onPressed: _createGroup,
          child: const Icon(Icons.group_add),
        );
      case GroupSharingStatus.sharing:
        return FloatingActionButton(
          onPressed: _stopSharing,
          child: const Icon(Icons.stop),
        );
      case GroupSharingStatus.receiving:
        return FloatingActionButton(
          onPressed: _stopReceiving,
          child: const Icon(Icons.stop),
        );
    }
  }

  SharingSessionStatus _parseSharingSessionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SharingSessionStatus.active;
      case 'paused':
        return SharingSessionStatus.paused;
      case 'completed':
        return SharingSessionStatus.completed;
      case 'failed':
        return SharingSessionStatus.failed;
      default:
        return SharingSessionStatus.active;
    }
  }

  IconData _getSessionIcon(SharingSessionStatus status) {
    switch (status) {
      case SharingSessionStatus.active:
        return Icons.share;
      case SharingSessionStatus.paused:
        return Icons.pause;
      case SharingSessionStatus.completed:
        return Icons.check_circle;
      case SharingSessionStatus.failed:
        return Icons.error;
    }
  }

  IconData _getHistoryIcon(GroupSharingType type) {
    switch (type) {
      case GroupSharingType.sent:
        return Icons.upload;
      case GroupSharingType.received:
        return Icons.download;
      case GroupSharingType.groupCreated:
        return Icons.group_add;
      case GroupSharingType.groupJoined:
        return Icons.group;
    }
  }

  void _createGroup() {
    final TextEditingController groupNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'Enter group name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final groupName = groupNameController.text.trim();
              Navigator.of(context).pop();
              
              if (groupName.isNotEmpty) {
                // TODO: Implement group creation with groupName
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Creating group: $groupName')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a group name')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((_) {
      groupNameController.dispose();
    });
  }

  void _joinGroup(Group group) {
    // TODO: Implement join group
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joining group: ${group.name}')),
    );
  }

  void _shareToGroup(Group group) {
    // Update sharing status to sharing
    ref.read(groupSharingStatusProvider.notifier).state = GroupSharingStatus.sharing;
    // TODO: Implement share to group
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing to group: ${group.name}')),
    );
  }

  void _showGroupMenu(Group group) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Group Info'),
            onTap: () {
              Navigator.of(context).pop();
              _showGroupInfo(group);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Group Settings'),
            onTap: () {
              Navigator.of(context).pop();
              _showGroupSettings(group);
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave Group'),
            onTap: () {
              Navigator.of(context).pop();
              _leaveGroup(group);
            },
          ),
        ],
      ),
    );
  }

  void _showGroupInfo(Group group) {
    // TODO: Implement group info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group info: ${group.name}')),
    );
  }

  void _showGroupSettings(Group group) {
    // TODO: Implement group settings
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group settings: ${group.name}')),
    );
  }

  void _leaveGroup(Group group) {
    // TODO: Implement leave group
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Leaving group: ${group.name}')),
    );
  }

  void _showSessionDetails(SharingSession session) {
    // TODO: Implement session details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Session details: ${session.groupName}')),
    );
  }

  void _showHistoryDetails(GroupSharingHistoryItem item) {
    // TODO: Implement history details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('History details: ${item.groupName}')),
    );
  }

  void _stopSharing() {
    ref.read(groupSharingStatusProvider.notifier).state = GroupSharingStatus.idle;
    // TODO: Implement stop sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stopping sharing...')),
    );
  }

  // Removed unused _startSharing placeholder (not wired)

  // Removed unused _startReceiving placeholder (not wired)

  void _stopReceiving() {
    ref.read(groupSharingStatusProvider.notifier).state = GroupSharingStatus.idle;
    // TODO: Implement stop receiving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stopping receiving...')),
    );
  }

  Future<void> _refreshGroups() async {
    try {
      // Refresh all group-related providers
      await Future.wait([
        ref.refresh(getActiveGroupsProvider.future),
        ref.refresh(getSharingSessionsProvider.future),
        ref.refresh(getGroupSharingHistoryProvider.future),
      ]);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Groups refreshed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh groups: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSettings() {
    // TODO: Implement settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings coming soon')),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'create_group':
        _createGroup();
        break;
      case 'join_group':
        _joinGroupDialog();
        break;
      case 'scan_qr':
        _scanQRCode();
        break;
    }
  }

  void _joinGroupDialog() {
    final TextEditingController groupIdController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: groupIdController,
          decoration: const InputDecoration(
            labelText: 'Group ID',
            hintText: 'Enter group ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final groupId = groupIdController.text.trim();
              Navigator.of(context).pop();
              
              if (groupId.isNotEmpty) {
                // TODO: Implement join group with groupId
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Joining group: $groupId')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a group ID')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    ).then((_) {
      groupIdController.dispose();
    });
  }

  void _scanQRCode() {
    // TODO: Implement QR code scanning
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning QR code...')),
    );
  }
}
