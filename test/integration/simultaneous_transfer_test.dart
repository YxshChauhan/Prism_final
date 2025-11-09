import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/transfer/data/repositories/transfer_repository_impl.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/connection_service.dart';
import 'package:airlink/core/services/checksum_verification_service.dart';
import 'package:airlink/core/services/error_handling_service.dart';
import 'package:airlink/core/services/performance_optimization_service.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';
import 'package:airlink/core/security/secure_session.dart';
import 'package:airlink/core/constants/app_constants.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:airlink/core/protocol/airlink_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:airlink/core/services/rate_limiting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> _secureStore = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (MethodCall call) async {
    switch (call.method) {
      case 'read':
        return _secureStore[call.arguments['key'] as String?] ?? null;
      case 'write':
        _secureStore[call.arguments['key'] as String] = call.arguments['value'] as String? ?? '';
        return true;
      case 'delete':
        _secureStore.remove(call.arguments['key'] as String);
        return true;
      case 'readAll':
        return _secureStore;
      case 'deleteAll':
        _secureStore.clear();
        return true;
      case 'containsKey':
        return _secureStore.containsKey(call.arguments['key'] as String);
      default:
        return null;
    }
  });
  group('Simultaneous Transfer Tests', () {
    late MethodChannel mockChannel;
    late TransferRepositoryImpl repository;
    
    setUp(() async {
      // Setup mock method channel
      mockChannel = MethodChannel('airlink/core');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'startWifiAwareSend':
            return {'success': true, 'transferId': methodCall.arguments['transferId']};
          case 'startWifiAwareReceive':
            return {'success': true, 'transferId': methodCall.arguments['transferId']};
          case 'getTransferProgress':
            // Simulate progress updates
            return {
              'status': 'transferring',
              'bytesTransferred': 1024,
              'totalBytes': 4096,
              'speed': 1024.0,
            };
          case 'pauseTransfer':
            return {'success': true};
          case 'resumeTransfer':
            return {'success': true};
          case 'cancelTransfer':
            return {'success': true};
          default:
            return {'success': false, 'error': 'Unknown method'};
        }
      });
      
      // Initialize AirLinkPlugin with mock channels
      AirLinkPlugin.initializeWithChannels(
        channel: mockChannel,
        eventChannel: const EventChannel('airlink/events'),
        wifiAwareDataChannel: const EventChannel('airlink/wifi_aware_data'),
      );
      
      // Setup repository with mocked dependencies
      final logger = LoggerService();
      repository = TransferRepositoryImpl(
        loggerService: logger,
        connectionService: ConnectionService(
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          ),
          await SharedPreferences.getInstance(),
        ),
        errorHandlingService: ErrorHandlingService(),
        performanceService: PerformanceOptimizationService(),
        benchmarkingService: TransferBenchmarkingService(),
        checksumService: ChecksumVerificationService(logger),
        rateLimitingService: RateLimitingService(),
        airLinkProtocol: AirLinkProtocol(
          deviceId: 'test_device',
          capabilities: const {
            'maxChunkSize': 1024 * 1024,
            'supportsResume': true,
            'encryption': 'AES-GCM',
          },
        ),
        secureSessionManager: SecureSessionManager(),
      );
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });
    
    group('Multiple Concurrent Transfers', () {
      test('should handle simultaneous transfers with MethodChannel mocks', () async {
        // Arrange
        final files1 = [
          unified.TransferFile(
            id: 'file1',
            name: 'test1.txt',
            path: '/path/test1.txt',
            size: 1024,
            mimeType: 'text/plain',
          ),
        ];

        final files2 = [
          unified.TransferFile(
            id: 'file2',
            name: 'test2.txt',
            path: '/path/test2.txt',
            size: 2048,
            mimeType: 'text/plain',
          ),
        ];

        // Act - Start multiple transfers
        final session1 = await repository.startTransferSession(
          targetDeviceId: 'device1',
          files: files1,
          connectionMethod: 'wifi_aware',
        );

        final session2 = await repository.startTransferSession(
          targetDeviceId: 'device2',
          files: files2,
          connectionMethod: 'wifi_aware',
        );

        // Assert
        expect(session1, isNotNull);
        expect(session2, isNotNull);
        expect(session1, isNot(equals(session2)));
        
        // Verify both transfers are active
        expect(repository.getActiveTransferCount(), equals(2));
      });
      
      test('should enforce transfer limits', () async {
        // Arrange - Create 6 transfer sessions (exceeds AppConstants.maxConcurrentTransfers = 5)
        final sessions = <String>[];
        
        for (int i = 0; i < 6; i++) {
          final files = [
            unified.TransferFile(
              id: 'file$i',
              name: 'test$i.txt',
              path: '/path/test$i.txt',
              size: 1024,
              mimeType: 'text/plain',
            ),
          ];
          
          try {
            final sessionId = await repository.startTransferSession(
              targetDeviceId: 'device$i',
              files: files,
              connectionMethod: 'wifi_aware',
            );
            sessions.add(sessionId);
          } catch (e) {
            // Expected to fail for the 6th transfer
            expect(e.toString(), contains('Maximum concurrent transfers'));
          }
        }
        
        // Assert - Should only have AppConstants.maxConcurrentTransfers active transfers
        expect(sessions.length, lessThanOrEqualTo(AppConstants.maxConcurrentTransfers));
        expect(repository.getActiveTransferCount(), lessThanOrEqualTo(AppConstants.maxConcurrentTransfers));
      });
      
      test('should track progress for multiple transfers', () async {
        // Arrange
        final files = [
          unified.TransferFile(
            id: 'file1',
            name: 'test1.txt',
            path: '/path/test1.txt',
            size: 4096,
            mimeType: 'text/plain',
          ),
        ];

        // Act
        final sessionId = await repository.startTransferSession(
          targetDeviceId: 'device1',
          files: files,
          connectionMethod: 'wifi_aware',
        );

        // Start monitoring progress
        final progressStream = repository.getTransferProgress(sessionId);
        final progressEvents = <unified.TransferProgress>[];
        
        final subscription = progressStream.listen((progress) {
          progressEvents.add(progress);
        });

        // Simulate progress updates
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Assert
        expect(progressEvents.length, greaterThan(0));
        expect(progressEvents.last.bytesTransferred, greaterThan(0));
        expect(progressEvents.last.speed, greaterThan(0));
        
        subscription.cancel();
      });
    });
    
    group('Legacy Tests', () {
      test('should create multiple transfer sessions', () {
        // Arrange
        final files1 = [
          unified.TransferFile(
            id: 'file1',
            name: 'test1.txt',
            path: '/path/test1.txt',
            size: 1024,
            mimeType: 'text/plain',
          ),
        ];

        final files2 = [
          unified.TransferFile(
            id: 'file2',
            name: 'test2.txt',
            path: '/path/test2.txt',
            size: 2048,
            mimeType: 'text/plain',
          ),
        ];

        final files3 = [
          unified.TransferFile(
            id: 'file3',
            name: 'test3.txt',
            path: '/path/test3.txt',
            size: 4096,
            mimeType: 'text/plain',
          ),
        ];

        // Act - Create transfer sessions
        final session1 = unified.TransferSession(
          id: 'session1',
          targetDeviceId: 'device1',
          files: files1,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        final session2 = unified.TransferSession(
          id: 'session2',
          targetDeviceId: 'device2',
          files: files2,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        final session3 = unified.TransferSession(
          id: 'session3',
          targetDeviceId: 'device3',
          files: files3,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        // Assert
        expect(session1.id, equals('session1'));
        expect(session2.id, equals('session2'));
        expect(session3.id, equals('session3'));
        expect(session1.id, isNot(equals(session2.id)));
        expect(session2.id, isNot(equals(session3.id)));
        expect(session1.id, isNot(equals(session3.id)));
      });

      test('should handle mixed file sizes in simultaneous transfers', () {
        // Arrange
        final smallFile = unified.TransferFile(
          id: 'small',
          name: 'small.txt',
          path: '/path/small.txt',
          size: 1024, // 1KB
          mimeType: 'text/plain',
        );

        final largeFile = unified.TransferFile(
          id: 'large',
          name: 'large.mp4',
          path: '/path/large.mp4',
          size: 100 * 1024 * 1024, // 100MB
          mimeType: 'video/mp4',
        );

        // Act
        final session1 = unified.TransferSession(
          id: 'session1',
          targetDeviceId: 'device1',
          files: [smallFile],
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        final session2 = unified.TransferSession(
          id: 'session2',
          targetDeviceId: 'device2',
          files: [largeFile],
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        // Assert
        expect(session1.id, equals('session1'));
        expect(session2.id, equals('session2'));
        expect(session1.files.first.size, equals(1024));
        expect(session2.files.first.size, equals(100 * 1024 * 1024));
      });
    });

    group('Send and Receive Simultaneously', () {
      test('should handle bidirectional transfers', () {
        // Arrange
        final sendFiles = [
          unified.TransferFile(
            id: 'send1',
            name: 'send.txt',
            path: '/path/send.txt',
            size: 1024,
            mimeType: 'text/plain',
          ),
        ];

        // Act - Create send session
        final sendSession = unified.TransferSession(
          id: 'send_session',
          targetDeviceId: 'target_device',
          files: sendFiles,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        // Act - Create receive session
        final receiveSession = unified.TransferSession(
          id: 'receive_session',
          targetDeviceId: 'local_device',
          files: [],
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.received,
        );

        // Assert
        expect(sendSession.id, equals('send_session'));
        expect(receiveSession.id, equals('receive_session'));
        expect(sendSession.id, isNot(equals(receiveSession.id)));
        expect(sendSession.files.length, equals(1));
        expect(receiveSession.files.length, equals(0));
      });
    });

    group('Connection Method Mixing', () {
      test('should handle different connection methods', () {
        // Arrange
        final files = [
          unified.TransferFile(
            id: 'file1',
            name: 'test.txt',
            path: '/path/test.txt',
            size: 1024,
            mimeType: 'text/plain',
          ),
        ];

        // Act
        final wifiSession = unified.TransferSession(
          id: 'wifi_session',
          targetDeviceId: 'wifi_device',
          files: files,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        final bleSession = unified.TransferSession(
          id: 'ble_session',
          targetDeviceId: 'ble_device',
          files: files,
          connectionMethod: 'ble',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        // Assert
        expect(wifiSession.id, equals('wifi_session'));
        expect(bleSession.id, equals('ble_session'));
        expect(wifiSession.id, isNot(equals(bleSession.id)));
        expect(wifiSession.connectionMethod, equals('wifi_aware'));
        expect(bleSession.connectionMethod, equals('ble'));
      });
    });

    group('Transfer Status Management', () {
      test('should handle different transfer statuses', () {
        // Arrange
        final files = [
          unified.TransferFile(
            id: 'file1',
            name: 'test.txt',
            path: '/path/test.txt',
            size: 1024,
            mimeType: 'text/plain',
          ),
        ];

        // Act
        final pendingSession = unified.TransferSession(
          id: 'pending_session',
          targetDeviceId: 'device1',
          files: files,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        final transferringSession = unified.TransferSession(
          id: 'transferring_session',
          targetDeviceId: 'device2',
          files: files,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.transferring,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        final completedSession = unified.TransferSession(
          id: 'completed_session',
          targetDeviceId: 'device3',
          files: files,
          connectionMethod: 'wifi_aware',
          status: unified.TransferStatus.completed,
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );

        // Assert
        expect(pendingSession.status, equals(unified.TransferStatus.pending));
        expect(transferringSession.status, equals(unified.TransferStatus.transferring));
        expect(completedSession.status, equals(unified.TransferStatus.completed));
        expect(completedSession.completedAt, isNotNull);
      });
    });
  });
}