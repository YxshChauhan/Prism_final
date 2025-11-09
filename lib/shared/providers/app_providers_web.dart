import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;

/// Current app page for web
final currentPageProviderWeb = StateProvider<AppPage>((ref) => AppPage.home);

/// Mock devices for web demo
final nearbyDevicesProviderWeb = StateProvider<List<Device>>((ref) => [
  Device(
    id: 'demo-device-1',
    name: 'Demo iPhone',
    type: DeviceType.ios,
    ipAddress: '192.168.1.100',
    rssi: -45,
    discoveredAt: DateTime.now().subtract(const Duration(minutes: 2)),
    isConnected: false,
    metadata: {'demo': true},
  ),
  Device(
    id: 'demo-device-2',
    name: 'Demo Android',
    type: DeviceType.android,
    ipAddress: '192.168.1.101',
    rssi: -52,
    discoveredAt: DateTime.now().subtract(const Duration(minutes: 1)),
    isConnected: false,
    metadata: {'demo': true},
  ),
  Device(
    id: 'demo-device-3',
    name: 'Demo MacBook',
    type: DeviceType.mac,
    ipAddress: '192.168.1.102',
    rssi: -38,
    discoveredAt: DateTime.now().subtract(const Duration(seconds: 30)),
    isConnected: true,
    metadata: {'demo': true},
  ),
]);

/// Mock discovery status for web demo
final isDiscoveringProviderWeb = StateProvider<bool>((ref) => false);

/// Mock transfer statistics for web demo
final transferStatisticsProviderWeb = Provider<Map<String, dynamic>>((ref) {
  return {
    'files_sent': 15,
    'files_received': 8,
    'total_bytes': 1024 * 1024 * 250, // 250 MB
    'avg_speed': 1024 * 1024 * 2.5, // 2.5 MB/s
  };
});

/// Mock recent transfers for web demo
final recentTransfersProviderWeb = Provider<List<unified.TransferSession>>((ref) {
  return [
    unified.TransferSession(
      id: 'demo-transfer-1',
      targetDeviceId: 'demo-device-1',
      files: [
        unified.TransferFile(
          id: 'file-1',
          name: 'vacation_photos.zip',
          path: '/demo/vacation_photos.zip',
          size: 1024 * 1024 * 45, // 45 MB
          mimeType: 'application/zip',
        ),
      ],
      connectionMethod: 'wifi_aware',
      status: unified.TransferStatus.completed,
      direction: unified.TransferDirection.sent,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      completedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
    ),
    unified.TransferSession(
      id: 'demo-transfer-2',
      targetDeviceId: 'demo-device-2',
      files: [
        unified.TransferFile(
          id: 'file-2',
          name: 'presentation.pdf',
          path: '/demo/presentation.pdf',
          size: 1024 * 1024 * 12, // 12 MB
          mimeType: 'application/pdf',
        ),
      ],
      connectionMethod: 'ble',
      status: unified.TransferStatus.completed,
      direction: unified.TransferDirection.received,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      completedAt: DateTime.now().subtract(const Duration(minutes: 55)),
    ),
    unified.TransferSession(
      id: 'demo-transfer-3',
      targetDeviceId: 'demo-device-3',
      files: [
        unified.TransferFile(
          id: 'file-3',
          name: 'music_collection.zip',
          path: '/demo/music_collection.zip',
          size: 1024 * 1024 * 128, // 128 MB
          mimeType: 'application/zip',
        ),
      ],
      connectionMethod: 'multipeer',
      status: unified.TransferStatus.transferring,
      direction: unified.TransferDirection.sent,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      bytesTransferred: 1024 * 1024 * 64, // 64 MB transferred
      totalBytes: 1024 * 1024 * 128, // 128 MB total
    ),
  ];
});

/// Mock selected files for web demo
final selectedFilesProviderWeb = StateProvider<List<TransferFile>>((ref) => []);

/// Mock transfer history for web demo
final transferHistoryProviderWeb = Provider<List<unified.TransferSession>>((ref) {
  final recent = ref.watch(recentTransfersProviderWeb);
  
  // Add more historical transfers
  final historical = [
    unified.TransferSession(
      id: 'demo-transfer-4',
      targetDeviceId: 'demo-device-1',
      files: [
        unified.TransferFile(
          id: 'file-4',
          name: 'document.docx',
          path: '/demo/document.docx',
          size: 1024 * 1024 * 2, // 2 MB
          mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ],
      connectionMethod: 'wifi_aware',
      status: unified.TransferStatus.completed,
      direction: unified.TransferDirection.sent,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      completedAt: DateTime.now().subtract(const Duration(days: 1, minutes: 2)),
    ),
    unified.TransferSession(
      id: 'demo-transfer-5',
      targetDeviceId: 'demo-device-2',
      files: [
        unified.TransferFile(
          id: 'file-5',
          name: 'video.mp4',
          path: '/demo/video.mp4',
          size: 1024 * 1024 * 89, // 89 MB
          mimeType: 'video/mp4',
        ),
      ],
      connectionMethod: 'ble',
      status: unified.TransferStatus.failed,
      direction: unified.TransferDirection.received,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
  
  return [...recent, ...historical];
});