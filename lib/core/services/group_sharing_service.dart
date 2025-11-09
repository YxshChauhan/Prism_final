import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/models/transfer_models.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:injectable/injectable.dart';

/// Group sharing service for simultaneous file sharing with multiple devices
/// Implements SHAREit/Zapya style group sharing functionality
@injectable
class GroupSharingService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<GroupSharingEvent> _eventController = StreamController<GroupSharingEvent>.broadcast();
  
  bool _isInitialized = false;
  bool _isGroupActive = false;
  String? _currentGroupId;
  String? _currentGroupName;
  GroupRole? _currentRole;
  final List<GroupMember> _groupMembers = [];
  final List<GroupFile> _groupFiles = [];
  
  GroupSharingService({
    required LoggerService logger,
    @Named('groupSharing') required MethodChannel methodChannel,
    @Named('groupSharingEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize group sharing service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.info('Initializing group sharing service...');
      
      // Check if group sharing is supported
      final bool isSupported = await _methodChannel.invokeMethod('isGroupSharingSupported');
      if (!isSupported) {
        throw GroupSharingException('Group sharing is not supported on this device');
      }
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Group sharing event error: $error'),
      );
      
      _isInitialized = true;
      _logger.info('Group sharing service initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize group sharing service: $e');
      throw GroupSharingException('Failed to initialize group sharing: $e');
    }
  }
  
  /// Create a new sharing group
  Future<String> createGroup({
    required String groupName,
    String? groupDescription,
    int maxMembers = 8,
    GroupPrivacy privacy = GroupPrivacy.private,
    String? password,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isGroupActive) {
      throw GroupSharingException('Already in a group');
    }
    
    try {
      _logger.info('Creating sharing group: $groupName');
      
      final String groupId = await _methodChannel.invokeMethod('createGroup', {
        'groupName': groupName,
        'groupDescription': groupDescription,
        'maxMembers': maxMembers,
        'privacy': privacy.toString().split('.').last,
        'password': password,
        'allowFileSharing': true,
        'allowChat': true,
        'allowScreenSharing': false,
      });
      
      _currentGroupId = groupId;
      _currentGroupName = groupName;
      _currentRole = GroupRole.owner;
      _isGroupActive = true;
      
      _logger.info('Sharing group created: $groupId');
      return groupId;
    } catch (e) {
      _logger.error('Failed to create sharing group: $e');
      throw GroupSharingException('Failed to create group: $e');
    }
  }
  
  /// Join an existing sharing group
  Future<void> joinGroup({
    required String groupId,
    String? password,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isGroupActive) {
      throw GroupSharingException('Already in a group');
    }
    
    try {
      _logger.info('Joining sharing group: $groupId');
      
      await _methodChannel.invokeMethod('joinGroup', {
        'groupId': groupId,
        'password': password,
      });
      
      _currentGroupId = groupId;
      _currentRole = GroupRole.member;
      _isGroupActive = true;
      
      _logger.info('Joined sharing group: $groupId');
    } catch (e) {
      _logger.error('Failed to join sharing group: $e');
      throw GroupSharingException('Failed to join group: $e');
    }
  }
  
  /// Leave current group
  Future<void> leaveGroup() async {
    if (!_isGroupActive || _currentGroupId == null) return;
    
    try {
      _logger.info('Leaving sharing group: $_currentGroupId');
      
      await _methodChannel.invokeMethod('leaveGroup', {
        'groupId': _currentGroupId,
      });
      
      _isGroupActive = false;
      _currentGroupId = null;
      _currentGroupName = null;
      _currentRole = null;
      _groupMembers.clear();
      _groupFiles.clear();
      
      _logger.info('Left sharing group');
    } catch (e) {
      _logger.error('Failed to leave sharing group: $e');
    }
  }
  
  /// Discover nearby groups
  Future<List<GroupInfo>> discoverGroups() async {
    try {
      _logger.info('Discovering nearby groups...');
      final List<dynamic> groups = await _methodChannel.invokeMethod('discoverGroups');
      return groups.map((group) => GroupInfo.fromMap(group)).toList();
    } catch (e) {
      _logger.error('Failed to discover groups: $e');
      return [];
    }
  }
  
  /// Get group members
  Future<List<GroupMember>> getGroupMembers() async {
    if (!_isGroupActive || _currentGroupId == null) return [];
    
    try {
      final List<dynamic> members = await _methodChannel.invokeMethod('getGroupMembers', {
        'groupId': _currentGroupId,
      });
      return members.map((member) => GroupMember.fromMap(member)).toList();
    } catch (e) {
      _logger.error('Failed to get group members: $e');
      return [];
    }
  }
  
  /// Get group files
  Future<List<GroupFile>> getGroupFiles() async {
    if (!_isGroupActive || _currentGroupId == null) return [];
    
    try {
      final List<dynamic> files = await _methodChannel.invokeMethod('getGroupFiles', {
        'groupId': _currentGroupId,
      });
      return files.map((file) => GroupFile.fromMap(file)).toList();
    } catch (e) {
      _logger.error('Failed to get group files: $e');
      return [];
    }
  }
  
  /// Share file with group
  Future<String> shareFile({
    required String filePath,
    required String fileName,
    required int fileSize,
    String? description,
    List<String>? targetMembers,
  }) async {
    if (!_isGroupActive || _currentGroupId == null) {
      throw GroupSharingException('Not in a group');
    }
    
    try {
      _logger.info('Sharing file with group: $fileName');
      
      final String shareId = await _methodChannel.invokeMethod('shareFile', {
        'groupId': _currentGroupId,
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'description': description,
        'targetMembers': targetMembers,
        'allowDownload': true,
        'allowPreview': true,
      });
      
      _logger.info('File shared with group: $shareId');
      return shareId;
    } catch (e) {
      _logger.error('Failed to share file with group: $e');
      throw GroupSharingException('Failed to share file: $e');
    }
  }
  
  /// Send file to multiple receivers simultaneously (multi-receiver broadcast)
  /// This is the core method for implementing 1-to-N file transfers
  Future<MultiReceiverTransferResult> sendToMultipleReceivers({
    required List<Device> receivers,
    required File file,
    Function(String receiverId, double progress)? onReceiverProgress,
    Function(MultiReceiverProgressUpdate)? onProgressUpdate,
  }) async {
    if (receivers.isEmpty) {
      throw GroupSharingException('No receivers specified');
    }
    
    try {
      final transferId = 'multi_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = file.path;
      final fileSize = await file.length();
      final deviceIds = receivers.map((d) => d.id).toList();
      
      _logger.info('Starting multi-receiver transfer to ${receivers.length} devices');
      _logger.info('Transfer ID: $transferId, File: ${file.path}, Size: $fileSize bytes');
      
      // For iOS, use metadata to indicate multi-receiver transfer
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS MultipeerConnectivity approach
        final Map<String, dynamic> params = {
          'transferId': transferId,
          'filePath': filePath,
          'fileSize': fileSize,
          'metadata': {
            'targetPeerIds': receivers.map((d) => d.name).toList(),
            'isMultiReceiver': true,
          }
        };
        
        await _methodChannel.invokeMethod('startTransfer', params);
      } else {
        // Android Wi-Fi Aware approach
        final Map<String, dynamic> params = {
          'transferId': transferId,
          'filePath': filePath,
          'fileSize': fileSize,
          'deviceIds': deviceIds,
          'connectionMethod': 'wifi_aware',
        };
        
        await _methodChannel.invokeMethod('startMultiReceiverTransfer', params);
      }
      
      // Track progress for each receiver
      final receiverProgress = <String, ReceiverTransferStatus>{};
      for (final receiver in receivers) {
        receiverProgress[receiver.id] = ReceiverTransferStatus(
          receiverId: receiver.id,
          receiverName: receiver.name,
          progress: 0.0,
          status: TransferStatus.transferring,
          bytesTransferred: 0,
          totalBytes: fileSize,
        );
      }
      
      _logger.info('Multi-receiver transfer started: $transferId');
      
      return MultiReceiverTransferResult(
        transferId: transferId,
        totalReceivers: receivers.length,
        receiverStatuses: receiverProgress,
        startTime: DateTime.now(),
      );
    } catch (e) {
      _logger.error('Failed to start multi-receiver transfer: $e');
      throw GroupSharingException('Failed to send to multiple receivers: $e');
    }
  }
  
  /// Download file from group
  Future<String> downloadFile({
    required String fileId,
    required String savePath,
    Function(double progress)? onProgress,
  }) async {
    if (!_isGroupActive || _currentGroupId == null) {
      throw GroupSharingException('Not in a group');
    }
    
    try {
      _logger.info('Downloading file from group: $fileId');
      
      final String downloadedPath = await _methodChannel.invokeMethod('downloadFile', {
        'groupId': _currentGroupId,
        'fileId': fileId,
        'savePath': savePath,
      });
      
      _logger.info('File downloaded from group: $downloadedPath');
      return downloadedPath;
    } catch (e) {
      _logger.error('Failed to download file from group: $e');
      throw GroupSharingException('Failed to download file: $e');
    }
  }
  
  /// Send message to group
  Future<String> sendMessage({
    required String message,
    MessageType type = MessageType.text,
    String? fileId,
  }) async {
    if (!_isGroupActive || _currentGroupId == null) {
      throw GroupSharingException('Not in a group');
    }
    
    try {
      _logger.info('Sending message to group');
      
      final String messageId = await _methodChannel.invokeMethod('sendMessage', {
        'groupId': _currentGroupId,
        'message': message,
        'type': type.toString().split('.').last,
        'fileId': fileId,
      });
      
      _logger.info('Message sent to group: $messageId');
      return messageId;
    } catch (e) {
      _logger.error('Failed to send message to group: $e');
      throw GroupSharingException('Failed to send message: $e');
    }
  }
  
  /// Get group messages
  Future<List<GroupMessage>> getGroupMessages({
    int limit = 50,
    String? beforeMessageId,
  }) async {
    if (!_isGroupActive || _currentGroupId == null) return [];
    
    try {
      final List<dynamic> messages = await _methodChannel.invokeMethod('getGroupMessages', {
        'groupId': _currentGroupId,
        'limit': limit,
        'beforeMessageId': beforeMessageId,
      });
      return messages.map((message) => GroupMessage.fromMap(message)).toList();
    } catch (e) {
      _logger.error('Failed to get group messages: $e');
      return [];
    }
  }
  
  /// Get current group status
  GroupStatus getGroupStatus() {
    return GroupStatus(
      isInitialized: _isInitialized,
      isGroupActive: _isGroupActive,
      groupId: _currentGroupId,
      groupName: _currentGroupName,
      role: _currentRole,
      memberCount: _groupMembers.length,
      fileCount: _groupFiles.length,
    );
  }
  
  /// Stream of group sharing events
  Stream<GroupSharingEvent> get eventStream => _eventController.stream;
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'groupCreated':
          _eventController.add(GroupCreatedEvent.fromMap(eventData));
          break;
        case 'groupJoined':
          _eventController.add(GroupJoinedEvent.fromMap(eventData));
          break;
        case 'groupLeft':
          _eventController.add(GroupLeftEvent.fromMap(eventData));
          break;
        case 'memberJoined':
          _eventController.add(MemberJoinedEvent.fromMap(eventData));
          break;
        case 'memberLeft':
          _eventController.add(MemberLeftEvent.fromMap(eventData));
          break;
        case 'fileShared':
          _eventController.add(FileSharedEvent.fromMap(eventData));
          break;
        case 'fileDownloaded':
          _eventController.add(FileDownloadedEvent.fromMap(eventData));
          break;
        case 'messageReceived':
          _eventController.add(MessageReceivedEvent.fromMap(eventData));
          break;
        case 'groupDiscovered':
          _eventController.add(GroupDiscoveredEvent.fromMap(eventData));
          break;
        default:
          _logger.warning('Unknown group sharing event type: $eventType');
      }
    } catch (e) {
      _logger.error('Failed to handle group sharing event: $e');
    }
  }
  
  /// Get active groups
  Future<List<Group>> getActiveGroups() async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Retrieving active groups...');
      final List<dynamic> groups = await _methodChannel.invokeMethod('getActiveGroups');
      return groups.map((group) => Group.fromMap(group)).toList();
    } catch (e) {
      _logger.error('Failed to get active groups: $e');
      return [];
    }
  }

  /// Get sharing sessions
  Future<List<SharingSession>> getSharingSessions() async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Retrieving sharing sessions...');
      final List<dynamic> sessions = await _methodChannel.invokeMethod('getSharingSessions');
      return sessions.map((session) => SharingSession.fromMap(session)).toList();
    } catch (e) {
      _logger.error('Failed to get sharing sessions: $e');
      return [];
    }
  }

  /// Get sharing history
  Future<List<GroupSharingHistoryItem>> getSharingHistory() async {
    if (!_isInitialized) await initialize();
    
    try {
      _logger.info('Retrieving sharing history...');
      final List<dynamic> history = await _methodChannel.invokeMethod('getSharingHistory');
      return history.map((item) => GroupSharingHistoryItem.fromMap(item)).toList();
    } catch (e) {
      _logger.error('Failed to get sharing history: $e');
      return [];
    }
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Group roles
enum GroupRole {
  owner,
  admin,
  member,
}

/// Group privacy levels
enum GroupPrivacy {
  public,
  private,
  passwordProtected,
}

/// Message types
enum MessageType {
  text,
  image,
  file,
  system,
}

/// Group information model
class GroupInfo {
  final String groupId;
  final String groupName;
  final String? groupDescription;
  final GroupPrivacy privacy;
  final int memberCount;
  final int maxMembers;
  final String? ownerName;
  final int signalStrength;
  final bool isPasswordProtected;
  final bool isNearby;
  
  const GroupInfo({
    required this.groupId,
    required this.groupName,
    this.groupDescription,
    required this.privacy,
    required this.memberCount,
    required this.maxMembers,
    this.ownerName,
    required this.signalStrength,
    required this.isPasswordProtected,
    required this.isNearby,
  });
  
  factory GroupInfo.fromMap(Map<String, dynamic> map) {
    return GroupInfo(
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      groupDescription: map['groupDescription'] as String?,
      privacy: GroupPrivacy.values.firstWhere(
        (e) => e.toString().split('.').last == map['privacy'] as String,
      ),
      memberCount: map['memberCount'] as int,
      maxMembers: map['maxMembers'] as int,
      ownerName: map['ownerName'] as String?,
      signalStrength: map['signalStrength'] as int,
      isPasswordProtected: map['isPasswordProtected'] as bool,
      isNearby: map['isNearby'] as bool,
    );
  }
}

/// Group member model
class GroupMember {
  final String memberId;
  final String memberName;
  final String deviceId;
  final GroupRole role;
  final bool isOnline;
  final DateTime joinedAt;
  final String? avatar;
  
  const GroupMember({
    required this.memberId,
    required this.memberName,
    required this.deviceId,
    required this.role,
    required this.isOnline,
    required this.joinedAt,
    this.avatar,
  });
  
  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      deviceId: map['deviceId'] as String,
      role: GroupRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'] as String,
      ),
      isOnline: map['isOnline'] as bool,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int),
      avatar: map['avatar'] as String?,
    );
  }
}

/// Group file model
class GroupFile {
  final String fileId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String mimeType;
  final String sharedBy;
  final String sharedByName;
  final DateTime sharedAt;
  final String? description;
  final int downloadCount;
  final bool isDownloaded;
  
  const GroupFile({
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.sharedBy,
    required this.sharedByName,
    required this.sharedAt,
    this.description,
    required this.downloadCount,
    required this.isDownloaded,
  });
  
  factory GroupFile.fromMap(Map<String, dynamic> map) {
    return GroupFile(
      fileId: map['fileId'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      fileSize: map['fileSize'] as int,
      mimeType: map['mimeType'] as String,
      sharedBy: map['sharedBy'] as String,
      sharedByName: map['sharedByName'] as String,
      sharedAt: DateTime.fromMillisecondsSinceEpoch(map['sharedAt'] as int),
      description: map['description'] as String?,
      downloadCount: map['downloadCount'] as int,
      isDownloaded: map['isDownloaded'] as bool,
    );
  }
}

/// Group message model
class GroupMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String message;
  final MessageType messageType;
  final DateTime sentAt;
  final String? fileId;
  final String? fileName;
  final int? fileSize;
  
  const GroupMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.messageType,
    required this.sentAt,
    this.fileId,
    this.fileName,
    this.fileSize,
  });
  
  factory GroupMessage.fromMap(Map<String, dynamic> map) {
    return GroupMessage(
      messageId: map['messageId'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      message: map['message'] as String,
      messageType: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'] as String,
      ),
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt'] as int),
      fileId: map['fileId'] as String?,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
    );
  }
}

/// Group status model
class GroupStatus {
  final bool isInitialized;
  final bool isGroupActive;
  final String? groupId;
  final String? groupName;
  final GroupRole? role;
  final int memberCount;
  final int fileCount;
  
  const GroupStatus({
    required this.isInitialized,
    required this.isGroupActive,
    this.groupId,
    this.groupName,
    this.role,
    required this.memberCount,
    required this.fileCount,
  });
}

/// Group sharing event base class
abstract class GroupSharingEvent {
  final String type;
  final DateTime timestamp;
  
  const GroupSharingEvent({
    required this.type,
    required this.timestamp,
  });
}

class GroupCreatedEvent extends GroupSharingEvent {
  final String groupId;
  final String groupName;
  final String creatorId;
  
  const GroupCreatedEvent({
    required this.groupId,
    required this.groupName,
    required this.creatorId,
    required super.timestamp,
  }) : super(type: 'groupCreated');
  
  factory GroupCreatedEvent.fromMap(Map<String, dynamic> map) {
    return GroupCreatedEvent(
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      creatorId: map['creatorId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class GroupJoinedEvent extends GroupSharingEvent {
  final String groupId;
  final String groupName;
  final String memberId;
  final String memberName;
  
  const GroupJoinedEvent({
    required this.groupId,
    required this.groupName,
    required this.memberId,
    required this.memberName,
    required super.timestamp,
  }) : super(type: 'groupJoined');
  
  factory GroupJoinedEvent.fromMap(Map<String, dynamic> map) {
    return GroupJoinedEvent(
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class GroupLeftEvent extends GroupSharingEvent {
  final String groupId;
  final String memberId;
  
  const GroupLeftEvent({
    required this.groupId,
    required this.memberId,
    required super.timestamp,
  }) : super(type: 'groupLeft');
  
  factory GroupLeftEvent.fromMap(Map<String, dynamic> map) {
    return GroupLeftEvent(
      groupId: map['groupId'] as String,
      memberId: map['memberId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class MemberJoinedEvent extends GroupSharingEvent {
  final String groupId;
  final String memberId;
  final String memberName;
  final GroupRole role;
  
  const MemberJoinedEvent({
    required this.groupId,
    required this.memberId,
    required this.memberName,
    required this.role,
    required super.timestamp,
  }) : super(type: 'memberJoined');
  
  factory MemberJoinedEvent.fromMap(Map<String, dynamic> map) {
    return MemberJoinedEvent(
      groupId: map['groupId'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      role: GroupRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class MemberLeftEvent extends GroupSharingEvent {
  final String groupId;
  final String memberId;
  final String memberName;
  
  const MemberLeftEvent({
    required this.groupId,
    required this.memberId,
    required this.memberName,
    required super.timestamp,
  }) : super(type: 'memberLeft');
  
  factory MemberLeftEvent.fromMap(Map<String, dynamic> map) {
    return MemberLeftEvent(
      groupId: map['groupId'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class FileSharedEvent extends GroupSharingEvent {
  final String groupId;
  final String fileId;
  final String fileName;
  final String sharedBy;
  final String sharedByName;
  final int fileSize;
  
  const FileSharedEvent({
    required this.groupId,
    required this.fileId,
    required this.fileName,
    required this.sharedBy,
    required this.sharedByName,
    required this.fileSize,
    required super.timestamp,
  }) : super(type: 'fileShared');
  
  factory FileSharedEvent.fromMap(Map<String, dynamic> map) {
    return FileSharedEvent(
      groupId: map['groupId'] as String,
      fileId: map['fileId'] as String,
      fileName: map['fileName'] as String,
      sharedBy: map['sharedBy'] as String,
      sharedByName: map['sharedByName'] as String,
      fileSize: map['fileSize'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class FileDownloadedEvent extends GroupSharingEvent {
  final String groupId;
  final String fileId;
  final String fileName;
  final String downloadedBy;
  final String downloadedByName;
  
  const FileDownloadedEvent({
    required this.groupId,
    required this.fileId,
    required this.fileName,
    required this.downloadedBy,
    required this.downloadedByName,
    required super.timestamp,
  }) : super(type: 'fileDownloaded');
  
  factory FileDownloadedEvent.fromMap(Map<String, dynamic> map) {
    return FileDownloadedEvent(
      groupId: map['groupId'] as String,
      fileId: map['fileId'] as String,
      fileName: map['fileName'] as String,
      downloadedBy: map['downloadedBy'] as String,
      downloadedByName: map['downloadedByName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class MessageReceivedEvent extends GroupSharingEvent {
  final String groupId;
  final String messageId;
  final String senderId;
  final String senderName;
  final String message;
  final MessageType messageType;
  
  const MessageReceivedEvent({
    required this.groupId,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.messageType,
    required super.timestamp,
  }) : super(type: 'messageReceived');
  
  factory MessageReceivedEvent.fromMap(Map<String, dynamic> map) {
    return MessageReceivedEvent(
      groupId: map['groupId'] as String,
      messageId: map['messageId'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      message: map['message'] as String,
      messageType: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class GroupDiscoveredEvent extends GroupSharingEvent {
  final String groupId;
  final String groupName;
  final int memberCount;
  final int signalStrength;
  
  const GroupDiscoveredEvent({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.signalStrength,
    required super.timestamp,
  }) : super(type: 'groupDiscovered');
  
  factory GroupDiscoveredEvent.fromMap(Map<String, dynamic> map) {
    return GroupDiscoveredEvent(
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      memberCount: map['memberCount'] as int,
      signalStrength: map['signalStrength'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

/// Group sharing specific exception
class GroupSharingException implements Exception {
  final String message;
  const GroupSharingException(this.message);
  
  @override
  String toString() => 'GroupSharingException: $message';
}

/// Receiver transfer status for multi-receiver transfers
class ReceiverTransferStatus {
  final String receiverId;
  final String receiverName;
  final double progress;
  final TransferStatus status;
  final int bytesTransferred;
  final int totalBytes;
  final DateTime? completedAt;
  final String? error;
  
  ReceiverTransferStatus({
    required this.receiverId,
    required this.receiverName,
    required this.progress,
    required this.status,
    required this.bytesTransferred,
    required this.totalBytes,
    this.completedAt,
    this.error,
  });
  
  ReceiverTransferStatus copyWith({
    double? progress,
    TransferStatus? status,
    int? bytesTransferred,
    DateTime? completedAt,
    String? error,
  }) {
    return ReceiverTransferStatus(
      receiverId: receiverId,
      receiverName: receiverName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
    );
  }
}

/// Multi-receiver transfer result
class MultiReceiverTransferResult {
  final String transferId;
  final int totalReceivers;
  final Map<String, ReceiverTransferStatus> receiverStatuses;
  final DateTime startTime;
  DateTime? endTime;
  
  MultiReceiverTransferResult({
    required this.transferId,
    required this.totalReceivers,
    required this.receiverStatuses,
    required this.startTime,
    this.endTime,
  });
  
  int get completedCount => receiverStatuses.values
      .where((s) => s.status == TransferStatus.completed)
      .length;
  
  int get failedCount => receiverStatuses.values
      .where((s) => s.status == TransferStatus.failed)
      .length;
  
  int get inProgressCount => receiverStatuses.values
      .where((s) => s.status == TransferStatus.transferring)
      .length;
  
  double get overallProgress {
    if (receiverStatuses.isEmpty) return 0.0;
    final totalProgress = receiverStatuses.values
        .map((s) => s.progress)
        .reduce((a, b) => a + b);
    return totalProgress / receiverStatuses.length;
  }
  
  bool get isCompleted => completedCount + failedCount == totalReceivers;
  
  bool get hasFailures => failedCount > 0;
}

/// Progress update for multi-receiver transfers
class MultiReceiverProgressUpdate {
  final String transferId;
  final String receiverId;
  final String receiverName;
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final TransferStatus status;
  final DateTime timestamp;
  
  MultiReceiverProgressUpdate({
    required this.transferId,
    required this.receiverId,
    required this.receiverName,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
    required this.timestamp,
  });
}
