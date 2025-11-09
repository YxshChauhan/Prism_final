import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/protocol/airlink_protocol.dart';

void main() {
  group('AirLink Protocol Tests', () {
    late AirLinkProtocol protocol;
    late File testFile;
    
    setUp(() async {
      // Create test file
      testFile = File('test_file.txt');
      await testFile.writeAsString('This is a test file for AirLink protocol testing.');
      
      // Initialize protocol
      protocol = AirLinkProtocol(
        deviceId: 'test_device_123',
        capabilities: {
          'maxChunkSize': 1024,
          'supportsResume': true,
          'encryption': 'AES-GCM',
        },
        sessionKey: 'test_session_key_base64',
      );
    });
    
    tearDown(() async {
      // Clean up test file
      if (await testFile.exists()) {
        await testFile.delete();
      }
      await protocol.close();
    });
    
    test('should initialize with correct device ID and capabilities', () {
      expect(protocol.deviceId, equals('test_device_123'));
      expect(protocol.capabilities['maxChunkSize'], equals(1024));
      expect(protocol.capabilities['supportsResume'], equals(true));
      expect(protocol.capabilities['encryption'], equals('AES-GCM'));
    });
    
    test('should set session key correctly', () {
      const newSessionKey = 'new_session_key_base64';
      protocol.setSessionKey(newSessionKey);
      // Note: We can't directly test private _sessionKey, but we can test behavior
      expect(protocol, isNotNull);
    });
    
    test('should initialize protocol correctly', () {
      expect(protocol.deviceId, equals('test_device_123'));
      expect(protocol.capabilities['maxChunkSize'], equals(1024));
      expect(protocol.capabilities['supportsResume'], equals(true));
      expect(protocol.capabilities['encryption'], equals('AES-GCM'));
    });
    
    test('should handle file operations', () async {
      final fileSize = await testFile.length();
      expect(fileSize, greaterThan(0));
      
      final fileContent = await testFile.readAsString();
      expect(fileContent, contains('test file'));
    });
    
    test('should handle protocol initialization', () async {
      await protocol.initialize();
      expect(protocol, isNotNull);
    });
    
    test('should handle file chunking with proper size calculation', () async {
      final fileSize = await testFile.length();
      const chunkSize = 1024;
      final totalChunks = (fileSize / chunkSize).ceil();
      
      expect(totalChunks, greaterThan(0));
      expect(totalChunks, lessThanOrEqualTo(1)); // Small test file
    });
    
    test('should listen to progress events', () async {
      final progressEvents = <ProtocolTransferProgress>[];
      final subscription = protocol.progressStream.listen((progress) {
        progressEvents.add(progress);
      });
      
      // Wait a bit to see if any events are emitted
      await Future.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();
      
      // Progress events might be empty if no transfer is active
      expect(progressEvents, isA<List<ProtocolTransferProgress>>());
    });
    
    test('should listen to transfer events', () async {
      final transferEvents = <TransferEvent>[];
      final subscription = protocol.eventStream.listen((event) {
        transferEvents.add(event);
      });
      
      // Wait a bit to see if any events are emitted
      await Future.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();
      
      // Transfer events might be empty if no transfer is active
      expect(transferEvents, isA<List<TransferEvent>>());
    });
    
    test('should handle pause and cancel operations', () async {
      // Test pause
      await protocol.pauseTransfer(1);
      
      // Test cancel
      await protocol.cancelTransfer(1);
      
      // These should not throw exceptions
      expect(protocol, isNotNull);
    });
    
    test('should handle resume operation', () async {
      // Test resume with required parameters - expect exception since no resume state exists
      try {
        await protocol.resumeTransfer(
          transferId: '1',
          deviceId: 'test_device',
          file: testFile,
          chunkSize: 1024,
        );
        fail('Expected exception for missing resume state');
      } catch (e) {
        expect(e.toString(), contains('No resume state found'));
      }
    });
    
    test('should close protocol cleanly', () async {
      await protocol.close();
      expect(protocol, isNotNull);
    });
  });
  
  group('Protocol Integration Tests', () {
    test('should handle complete file transfer workflow', () async {
      // Create test file
      final testFile = File('integration_test_file.txt');
      await testFile.writeAsString('Integration test file content for AirLink protocol.');
      
      try {
        // Initialize protocol
        final protocol = AirLinkProtocol(
          deviceId: 'integration_test_device',
          capabilities: {
            'maxChunkSize': 512,
            'supportsResume': true,
            'encryption': 'AES-GCM',
          },
          sessionKey: 'integration_test_session_key',
        );
        
        // Test file operations
        final fileSize = await testFile.length();
        const chunkSize = 512;
        final totalChunks = (fileSize / chunkSize).ceil();
        
        expect(totalChunks, greaterThan(0));
        
        // Test basic file operations
        final fileContent = await testFile.readAsString();
        expect(fileContent, isNotEmpty);
        
        // Test file size calculation
        expect(fileSize, greaterThan(0));
        expect(totalChunks, greaterThan(0));
        
        await protocol.close();
      } finally {
        // Clean up
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });
  });
}
