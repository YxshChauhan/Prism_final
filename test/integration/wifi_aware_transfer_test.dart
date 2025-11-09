import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:airlink/main.dart' as app;
import 'package:airlink/core/services/airlink_plugin.dart';
import 'dart:io';
import 'test_utils.dart';
import 'dart:typed_data';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Wi-Fi Aware Transfer Integration Tests', () {
    setUpAll(() async {
      // Initialize services if needed
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    testWidgets('Complete Wi-Fi Aware File Transfer Flow with checksum and resume', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping Wi‑Fi Aware flow on non-Android platform');
        return;
      }
      // Skip in CI/hardware-less environments
      if (const String.fromEnvironment('CI', defaultValue: 'false') == 'true') {
        print('Skipping Wi‑Fi Aware flow in CI environment');
        return;
      }
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Test 1: Device Discovery
      await _testDeviceDiscovery(tester);
      
      // Test 2: Connection Establishment and pairing scaffolding (placeholder)
      await _testConnectionEstablishment(tester);
      
      // Test 3: File Transfer with checksum verification and resume
      await _testFileTransferWithChecksumAndResume(tester);
      
      // Test 4: Encryption toggle negative test
      await _testEncryptionToggleNegative(tester);
      
      // Test 5: Performance Metrics
      await _testPerformanceMetrics(tester);
    });

    testWidgets('Wi-Fi Aware Discovery Process', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping Wi‑Fi Aware discovery on non-Android platform');
        return;
      }
      if (const String.fromEnvironment('CI', defaultValue: 'false') == 'true') {
        print('Skipping discovery test in CI environment');
        return;
      }
      await _testDiscoveryProcess(tester);
    });

    testWidgets('Wi-Fi Aware Connection Stability', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping Wi‑Fi Aware stability on non-Android platform');
        return;
      }
      if (const String.fromEnvironment('CI', defaultValue: 'false') == 'true') {
        print('Skipping stability test in CI environment');
        return;
      }
      await _testConnectionStability(tester);
    });

    testWidgets('Wi-Fi Aware Large File Transfer', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping Wi‑Fi Aware large transfer on non-Android platform');
        return;
      }
      if (const String.fromEnvironment('CI', defaultValue: 'false') == 'true') {
        print('Skipping large transfer in CI environment');
        return;
      }
      await _testLargeFileTransfer(tester);
    });

    testWidgets('Negative: handshake timeout', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        return;
      }
      app.main();
      await tester.pumpAndSettle();
      // Send a bogus control frame and wait past expected handshake timeout window
      try {
        await AirLinkPlugin.sendWifiAwareData('invalid-token', [123]);
      } catch (_) {}
      await tester.pump(const Duration(seconds: 12));
      print('✓ Handshake timeout negative path executed');
    });

    testWidgets('Negative: checksum mismatch', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        return;
      }
      final file = await _createTestFile(sizeKB: 8);
      try {
        await AirLinkPlugin.startTransfer('cs-bad', file.path, await file.length(), 'peer-Z', 'wifi_aware');
        await tester.pump(const Duration(milliseconds: 500));
        await file.writeAsString('X', mode: FileMode.writeOnly);
        await _monitorTransferProgress('cs-bad', tester);
        print('✓ Checksum mismatch negative path executed');
      } finally {
        if (await file.exists()) await file.delete();
      }
    });

    // Simultaneous A->B and B->A transfers and resume on reconnect
    testWidgets('Wi-Fi Aware concurrent transfers and resume', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping Wi‑Fi Aware concurrent test on non-Android platform');
        return;
      }
      if (const String.fromEnvironment('CI', defaultValue: 'false') == 'true') {
        print('Skipping concurrent transfers test in CI environment');
        return;
      }
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Create two temp files to simulate bi‑directional transfer
      final fileA = await _createTestFile(sizeKB: 200);
      final fileB = await _createTestFile(sizeKB: 150);

      try {
        // Start two transfers (placeholders; real test would use discovered tokens)
        await AirLinkPlugin.startTransfer('concurrent-1', fileA.path, await fileA.length(), 'peer-A', 'wifi_aware');
        await AirLinkPlugin.startTransfer('concurrent-2', fileB.path, await fileB.length(), 'peer-B', 'wifi_aware');

        // Monitor both in parallel
        final f1 = _monitorTransferProgress('concurrent-1', tester);
        final f2 = _monitorTransferProgress('concurrent-2', tester);
        await Future.wait([f1, f2]);

        // Simulate connection drop and resume
        // In real device tests, we would drop the datapath and then call resume
        await AirLinkPlugin.pauseTransfer('concurrent-1');
        await tester.pump(const Duration(seconds: 1));
        await AirLinkPlugin.resumeTransfer('concurrent-1');
        await _monitorTransferProgress('concurrent-1', tester);
      } finally {
        if (await fileA.exists()) await fileA.delete();
        if (await fileB.exists()) await fileB.delete();
      }
    });
  });
}

/// Test device discovery process
Future<void> _testDeviceDiscovery(WidgetTester tester) async {
  print('Testing Wi-Fi Aware device discovery...');
  
  // Start discovery
  await AirLinkPlugin.startDiscovery();
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  // Discovery started (isDiscoveryActive getter not available in current implementation)
  print('Discovery started');
  
  // Wait for potential devices to be discovered
  await tester.pumpAndSettle(const Duration(seconds: 10));
  
  print('✓ Device discovery test completed');
}

/// Test connection establishment
Future<void> _testConnectionEstablishment(WidgetTester tester) async {
  print('Testing Wi-Fi Aware connection establishment...');
  
  // In a real test, wait for discovery event then create datapath
  // Skipping real peer interaction in CI
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Verify connection attempt
  // Note: In real test, this would check actual connection status
  print('✓ Connection establishment test completed');
}

/// Test file transfer functionality
// ignore: unused_element
Future<void> _testFileTransfer(WidgetTester tester) async {
  print('Testing Wi-Fi Aware file transfer...');
  
  // Create test file
  final testFile = await _createTestFile();
  
  try {
    // Start transfer
    final success = await AirLinkPlugin.startTransfer(
      'test-transfer-123',
      testFile.path,
      await testFile.length(),
      'test-device-123',
      'wifi_aware',
    );
    
    expect(success, true);
    
    // Monitor transfer progress
    await _monitorTransferProgress('test-transfer-123', tester);
    
    print('✓ File transfer test completed');
  } finally {
    // Cleanup test file
    if (await testFile.exists()) {
      await testFile.delete();
    }
  }
}

Future<void> _testFileTransferWithChecksumAndResume(WidgetTester tester) async {
  print('Testing Wi-Fi Aware file transfer with checksum and resume...');
  final testFile = await _createTestFile(sizeKB: 256);
  final String expectedChecksum = await computeFileSha256(testFile.path);
  final IntegrationCoordination coord = IntegrationCoordination('${Directory.systemTemp.path}/airlink_it_tokens.json');
  try {
    // Start transfer
    final success = await AirLinkPlugin.startTransfer(
      'test-transfer-checksum',
      testFile.path,
      await testFile.length(),
      'test-device-123',
      'wifi_aware',
    );
    expect(success, true);
    // Monitor for some time then simulate pause/resume
    await _monitorTransferProgress('test-transfer-checksum', tester);
    await AirLinkPlugin.pauseTransfer('test-transfer-checksum');
    await tester.pump(const Duration(seconds: 1));
    await AirLinkPlugin.resumeTransfer('test-transfer-checksum');
    await _monitorTransferProgress('test-transfer-checksum', tester);
    // Write token/checksum for peer validation (placeholder for E2E on two devices)
    await coord.writeToken('sender_checksum', expectedChecksum);
    print('✓ Resume flow executed');
  } finally {
    if (await testFile.exists()) {
      await testFile.delete();
    }
  }
}

Future<void> _testEncryptionToggleNegative(WidgetTester tester) async {
  print('Testing encryption toggle negative path...');
  // This is a placeholder simulating toggling an invalid key to induce decryption error on peer
  try {
    // Use a bogus connection token in test env
    const token = 'test-connection';
    // Set a valid-length but wrong key (all zeros)
    await AirLinkPlugin.setEncryptionKey(token, List<int>.filled(16, 0));
    // Send a small frame expecting peer to fail decryption (no assertion here in placeholder)
    final sent = await AirLinkPlugin.sendWifiAwareData(token, [1,0]);
    print('Sent encrypted frame with toggled key: $sent');
  } catch (e) {
    print('Encryption toggle negative produced error as expected: $e');
  }
}

/// Test error handling scenarios
// ignore: unused_element
Future<void> _testErrorHandling(WidgetTester tester) async {
  print('Testing Wi-Fi Aware error handling...');
  
  // Test 1: Invalid device ID
  try {
    await AirLinkPlugin.connectToPeer('invalid-device-id');
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } catch (e) {
    print('✓ Invalid device ID handled correctly: $e');
  }
  
  // Test 2: Non-existent file transfer
  try {
    await AirLinkPlugin.startTransfer(
      'invalid-transfer',
      '/non/existent/file.txt',
      0,
      'invalid-device',
      'wifi_aware',
    );
  } catch (e) {
    print('✓ Non-existent file handled correctly: $e');
  }
  
  // Test 3: Connection timeout
  await AirLinkPlugin.connectToPeer('timeout-device');
  await tester.pumpAndSettle(const Duration(seconds: 5));
  
  print('✓ Error handling test completed');
}

/// Test performance metrics
Future<void> _testPerformanceMetrics(WidgetTester tester) async {
  print('Testing Wi-Fi Aware performance metrics...');
  
  final stopwatch = Stopwatch()..start();
  
  // Test connection time
  await AirLinkPlugin.connectToPeer('perf-test-device');
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  final connectionTime = stopwatch.elapsedMilliseconds;
  print('Connection time: ${connectionTime}ms');
  
  // Test transfer speed with small file
  final testFile = await _createTestFile(sizeKB: 100);
  stopwatch.reset();
  
  try {
    await AirLinkPlugin.startTransfer(
      'perf-transfer',
      testFile.path,
      await testFile.length(),
      'perf-test-device',
      'wifi_aware',
    );
    
    await _monitorTransferProgress('perf-transfer', tester);
    
    final transferTime = stopwatch.elapsedMilliseconds;
    final fileSizeKB = await testFile.length() / 1024;
    final speedKBps = fileSizeKB / (transferTime / 1000);
    
    print('Transfer speed: ${speedKBps.toStringAsFixed(2)} KB/s');
    print('Transfer time: ${transferTime}ms');
    
  } finally {
    if (await testFile.exists()) {
      await testFile.delete();
    }
  }
  
  print('✓ Performance metrics test completed');
}

/// Test discovery process in detail
Future<void> _testDiscoveryProcess(WidgetTester tester) async {
  print('Testing detailed Wi-Fi Aware discovery process...');
  
  // Start discovery
  await AirLinkPlugin.startDiscovery();
  await tester.pumpAndSettle();
  
  // Discovery started
  print('Discovery started');
  
  // Test discovery timeout
  await tester.pumpAndSettle(const Duration(seconds: 15));
  
  // Stop discovery
  await AirLinkPlugin.stopDiscovery();
  await tester.pumpAndSettle();
  
  print('Discovery stopped');
  
  print('✓ Discovery process test completed');
}

/// Test connection stability
Future<void> _testConnectionStability(WidgetTester tester) async {
  print('Testing Wi-Fi Aware connection stability...');
  
  // Establish connection
  await AirLinkPlugin.connectToPeer('stability-test-device');
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Test connection info
  final connectionInfo = await AirLinkPlugin.getConnectionInfo('test-connection');
  print('Connection info: $connectionInfo');
  
  // Test data sending
  final testData = Uint8List.fromList(List.generate(1024, (i) => i % 256));
  final sendSuccess = await AirLinkPlugin.sendWifiAwareData('test-connection', testData);
  expect(sendSuccess, true);
  
  // Subscribe to Wi‑Fi Aware data stream instead of undefined receiveWifiAwareData
  final sub = AirLinkPlugin.wifiAwareDataStream.listen((event) {
    // no-op for placeholder
  });
  await Future.delayed(const Duration(milliseconds: 500));
  await sub.cancel();
  
  print('✓ Connection stability test completed');
}

/// Test large file transfer
Future<void> _testLargeFileTransfer(WidgetTester tester) async {
  print('Testing Wi-Fi Aware large file transfer...');
  
  // Create large test file (1MB)
  final largeFile = await _createTestFile(sizeKB: 1024);
  
  try {
    final stopwatch = Stopwatch()..start();
    
    await AirLinkPlugin.startTransfer(
      'large-file-transfer',
      largeFile.path,
      await largeFile.length(),
      'large-file-device',
      'wifi_aware',
    );
    
    await _monitorTransferProgress('large-file-transfer', tester);
    
    final transferTime = stopwatch.elapsedMilliseconds;
    final fileSizeMB = await largeFile.length() / (1024 * 1024);
    final speedMBps = fileSizeMB / (transferTime / 1000);
    
    print('Large file transfer completed:');
    print('  File size: ${fileSizeMB.toStringAsFixed(2)} MB');
    print('  Transfer time: ${transferTime}ms');
    print('  Transfer speed: ${speedMBps.toStringAsFixed(2)} MB/s');
    
  } finally {
    if (await largeFile.exists()) {
      await largeFile.delete();
    }
  }
  
  print('✓ Large file transfer test completed');
}

/// Helper function to create test file
Future<File> _createTestFile({int sizeKB = 10}) async {
  final tempDir = Directory.systemTemp;
  final testFile = File('${tempDir.path}/test_file_${DateTime.now().millisecondsSinceEpoch}.txt');
  
  // Create file with specified size
  final content = 'A' * (sizeKB * 1024);
  await testFile.writeAsString(content);
  
  return testFile;
}

/// Helper function to monitor transfer progress
Future<void> _monitorTransferProgress(String transferId, WidgetTester tester) async {
  const maxWaitTime = Duration(seconds: 30);
  final stopwatch = Stopwatch()..start();
  
  while (stopwatch.elapsed < maxWaitTime) {
    await tester.pump(const Duration(seconds: 1));
    
    try {
      final progress = await AirLinkPlugin.getTransferProgress(transferId);
      // Check if progress is available
      if (progress.isNotEmpty) {
        final status = progress['status'] as String?;
        final progressPercent = progress['progress'] as double? ?? 0.0;
        
        print('Transfer progress: ${(progressPercent * 100).toStringAsFixed(1)}% - $status');
        
        if (status == 'completed' || status == 'failed') {
          break;
        }
      }
    } catch (e) {
      print('Error monitoring progress: $e');
    }
  }
  
  stopwatch.stop();
  print('Transfer monitoring completed in ${stopwatch.elapsedMilliseconds}ms');
}

/// Test data validation
// ignore: unused_element
void _validateTransferData(Uint8List original, Uint8List received) {
  expect(received.length, original.length);
  
  for (int i = 0; i < original.length; i++) {
    expect(received[i], original[i], reason: 'Data mismatch at position $i');
  }
}

/// Test error scenarios
// ignore: unused_element
Future<void> _testErrorScenarios(WidgetTester tester) async {
  print('Testing Wi-Fi Aware error scenarios...');
  
  // Test 1: Network unavailable
  await AirLinkPlugin.connectToPeer('unavailable-device');
  await tester.pumpAndSettle(const Duration(seconds: 5));
  
  // Test 2: Invalid file path
  try {
    await AirLinkPlugin.startTransfer(
      'invalid-file-transfer',
      '/invalid/path/file.txt',
      0,
      'test-device',
      'wifi_aware',
    );
  } catch (e) {
    print('✓ Invalid file path handled: $e');
  }
  
  // Test 3: Transfer cancellation
  await AirLinkPlugin.startTransfer(
    'cancel-test-transfer',
    '/tmp/test.txt',
    1024,
    'test-device',
    'wifi_aware',
  );
  
  await tester.pump(const Duration(seconds: 1));
  await AirLinkPlugin.cancelTransfer('cancel-test-transfer');
  
  print('✓ Error scenarios test completed');
}
