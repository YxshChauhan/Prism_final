import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'dart:io';

void main() {
  group('Transfer Resume Tests', () {
    test('should handle transfer resume correctly', () async {
      // Test basic transfer resume functionality
      final testFile = File('test_file.txt');
      await testFile.writeAsString('Test content for resume');
      
      try {
        // Test that we can create a transfer session
        final session = unified.TransferSession(
          id: 'test_session',
          targetDeviceId: 'target_device',
          connectionMethod: 'wifi_aware',
          files: [
            unified.TransferFile(
              id: 'file1',
              name: 'test_file.txt',
              size: testFile.lengthSync(),
              path: testFile.path,
              mimeType: 'text/plain',
            ),
          ],
          status: unified.TransferStatus.pending,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );
        
        expect(session.id, equals('test_session'));
        expect(session.files.length, equals(1));
        expect(session.status, equals(unified.TransferStatus.pending));
        
      } finally {
        // Clean up test file
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('should handle transfer pause and resume', () async {
      // Test pause and resume functionality
      final testFile = File('test_resume_file.txt');
      await testFile.writeAsString('Test content for pause/resume');
      
      try {
        // Test pause functionality
        final session = unified.TransferSession(
          id: 'pause_test_session',
          targetDeviceId: 'target_device',
          connectionMethod: 'wifi_aware',
          files: [
            unified.TransferFile(
              id: 'file1',
              name: 'test_resume_file.txt',
              size: testFile.lengthSync(),
              path: testFile.path,
              mimeType: 'text/plain',
            ),
          ],
          status: unified.TransferStatus.paused,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );
        
        expect(session.status, equals(unified.TransferStatus.paused));
        
        // Test resume functionality
        final resumedSession = session.copyWith(
          status: unified.TransferStatus.resuming,
        );
        
        expect(resumedSession.status, equals(unified.TransferStatus.resuming));
        
      } finally {
        // Clean up test file
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('should handle transfer cancellation', () async {
      // Test cancellation functionality
      final testFile = File('test_cancel_file.txt');
      await testFile.writeAsString('Test content for cancellation');
      
      try {
        final session = unified.TransferSession(
          id: 'cancel_test_session',
          targetDeviceId: 'target_device',
          connectionMethod: 'wifi_aware',
          files: [
            unified.TransferFile(
              id: 'file1',
              name: 'test_cancel_file.txt',
              size: testFile.lengthSync(),
              path: testFile.path,
              mimeType: 'text/plain',
            ),
          ],
          status: unified.TransferStatus.cancelled,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );
        
        expect(session.status, equals(unified.TransferStatus.cancelled));
        
      } finally {
        // Clean up test file
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    test('should handle all transfer statuses', () async {
      // Test all transfer statuses
      final statuses = [
        unified.TransferStatus.pending,
        unified.TransferStatus.connecting,
        unified.TransferStatus.transferring,
        unified.TransferStatus.paused,
        unified.TransferStatus.completed,
        unified.TransferStatus.failed,
        unified.TransferStatus.cancelled,
        unified.TransferStatus.handshaking,
        unified.TransferStatus.resuming,
      ];
      
      for (final status in statuses) {
        final session = unified.TransferSession(
          id: 'status_test_${status.name}',
          targetDeviceId: 'target_device',
          connectionMethod: 'wifi_aware',
          files: [],
          status: status,
          createdAt: DateTime.now(),
          direction: unified.TransferDirection.sent,
        );
        
        expect(session.status, equals(status));
      }
    });
  });
}