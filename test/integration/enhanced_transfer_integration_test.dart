import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:airlink/core/services/rate_limiting_service.dart';
import 'package:airlink/core/protocol/airlink_protocol_simplified.dart';
import 'package:airlink/core/services/error_handling_service.dart';
import 'package:airlink/core/services/performance_optimization_service.dart';
import 'package:airlink/features/transfer/data/repositories/transfer_repository_impl.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/connection_service.dart';
import 'package:airlink/core/services/checksum_verification_service.dart';
import 'package:airlink/core/errors/exceptions.dart';
import 'package:airlink/core/security/secure_session.dart';
import 'package:airlink/core/protocol/airlink_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('Enhanced Transfer Integration Tests', () {
    late TransferRepositoryImpl transferRepository;
    late ErrorHandlingService errorHandlingService;
    late PerformanceOptimizationService performanceService;
    late File testFile;
    
    setUp(() async {
      // Initialize services
      errorHandlingService = ErrorHandlingService();
      performanceService = PerformanceOptimizationService();
      
      // Create test file
      testFile = File('integration_test_file.txt');
      final content = 'Integration test file content for enhanced transfer testing. ' * 100;
      await testFile.writeAsString(content);
      
      // Initialize transfer repository with enhanced services
      final prefs = await SharedPreferences.getInstance();
      final logger = LoggerService();
      transferRepository = TransferRepositoryImpl(
        loggerService: logger,
        connectionService: ConnectionService(
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          ),
          prefs,
        ),
        errorHandlingService: errorHandlingService,
        performanceService: performanceService,
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
    
    tearDown(() async {
      // Clean up test file
      if (await testFile.exists()) {
        await testFile.delete();
      }
      performanceService.clearPerformanceData();
      errorHandlingService.clearErrorHistory();
    });
    
    test('should handle complete transfer workflow with enhanced services', () async {
      // Create transfer file
      final transferFile = unified.TransferFile(
        id: 'test_file_1',
        name: testFile.path.split('/').last,
        path: testFile.path,
        size: await testFile.length(),
        mimeType: 'text/plain',
      );
      
      // Start transfer session
      final sessionId = await transferRepository.startTransferSession(
        targetDeviceId: 'test_receiver',
        connectionMethod: 'wifi_aware',
        files: [transferFile],
      );
      
      expect(sessionId, isNotEmpty);
      
      // Verify session was created
      final activeTransfers = await transferRepository.getActiveTransfers();
      expect(activeTransfers.length, equals(1));
      expect(activeTransfers.first.id, equals(sessionId));
      
      // Test pause functionality
      await transferRepository.pauseTransfer(sessionId);
      final pausedTransfers = await transferRepository.getActiveTransfers();
      expect(pausedTransfers.first.status, equals(unified.TransferStatus.paused));
      
      // Test resume functionality
      await transferRepository.resumeTransfer(sessionId);
      final resumedTransfers = await transferRepository.getActiveTransfers();
      expect(resumedTransfers.first.status, equals(unified.TransferStatus.transferring));
      
      // Test cancel functionality
      await transferRepository.cancelTransfer(sessionId);
      final cancelledTransfers = await transferRepository.getActiveTransfers();
      expect(cancelledTransfers, isEmpty);
    });
    
    test('should handle errors gracefully with enhanced error handling', () async {
      // Create transfer file with invalid path
      final invalidFile = unified.TransferFile(
        id: 'invalid_file',
        name: 'nonexistent.txt',
        path: '/nonexistent/path/file.txt',
        size: 0,
        mimeType: 'text/plain',
      );
      
      try {
        await transferRepository.startTransferSession(
          targetDeviceId: 'test_receiver',
          connectionMethod: 'wifi_aware',
          files: [invalidFile],
        );
      } catch (e) {
        // Verify error was handled
        expect(e, isA<TransferException>());
        
        // Check error handling service recorded the error
        final errorStats = errorHandlingService.getErrorStatistics();
        expect(errorStats['totalErrors'], greaterThan(0));
      }
    });
    
    test('should optimize performance with enhanced optimization service', () async {
      // Create multiple test files
      final testFiles = <unified.TransferFile>[];
      for (int i = 0; i < 5; i++) {
        final file = File('test_file_$i.txt');
        await file.writeAsString('Test content $i' * 100);
        
        testFiles.add(unified.TransferFile(
          id: 'test_file_$i',
          name: file.path.split('/').last,
          path: file.path,
          size: await file.length(),
          mimeType: 'text/plain',
        ));
      }
      
      // Record performance for multiple operations
      for (int i = 0; i < 3; i++) {
        final stopwatch = Stopwatch()..start();
        
        // Simulate file processing
        await Future.delayed(const Duration(milliseconds: 100));
        
        stopwatch.stop();
        
        performanceService.recordOperation(
          'file_transfer',
          stopwatch.elapsed,
          1024 * 1024, // 1MB
        );
      }
      
      // Get optimized parameters
      final parameters = performanceService.getOptimizedParameters('file_transfer');
      
      expect(parameters.chunkSize, greaterThan(0));
      expect(parameters.concurrency, greaterThan(0));
      expect(parameters.timeout.inMilliseconds, greaterThan(0));
      expect(parameters.retryCount, greaterThan(0));
      
      // Verify performance statistics
      final stats = performanceService.getPerformanceStatistics();
      expect(stats, contains('file_transfer'));
      expect(stats['file_transfer']['totalOperations'], equals(3));
      
      // Clean up test files
      for (final file in testFiles) {
        final fileObj = File(file.path);
        if (await fileObj.exists()) {
          await fileObj.delete();
        }
      }
    });
    
    test('should handle protocol errors with retry logic', () async {
      // Create a mock protocol that fails initially
      final mockProtocol = MockAirLinkProtocol();
      
      // Test error handling with retry
      try {
        await mockProtocol.sendFile(testFile, 1);
      } catch (e) {
        // Test retry logic
        await errorHandlingService.handleError(
          e,
          'protocol_test',
          shouldRetry: true,
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 100),
        );
      }
    });
    
    test('should provide user-friendly error messages', () {
      final testErrors = [
        SocketException('Connection failed'),
        FileSystemException('Permission denied'),
        TimeoutException('Operation timed out'),
        FormatException('Invalid format'),
        StateError('Invalid state'),
        ArgumentError('Invalid argument'),
        Exception('Unknown error'),
      ];
      
      for (final error in testErrors) {
        final message = errorHandlingService.getUserFriendlyMessage(error, 'test_context');
        final suggestions = errorHandlingService.getRecoverySuggestions(error, 'test_context');
        
        expect(message, isNotEmpty);
        expect(suggestions, isNotEmpty);
        expect(suggestions.length, greaterThan(0));
        
        // Verify messages are user-friendly (not technical)
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('Error')));
        expect(message, contains('Please'));
      }
    });
    
    test('should handle concurrent transfers efficiently', () async {
      // Create multiple test files
      final testFiles = <File>[];
      for (int i = 0; i < 3; i++) {
        final file = File('concurrent_test_$i.txt');
        await file.writeAsString('Concurrent test content $i' * 50);
        testFiles.add(file);
      }
      
      // Process files concurrently
      final futures = testFiles.map((file) async {
        await performanceService.processFileInChunks(
          file,
          'concurrent_test',
          (chunk, index) async {
            // Simulate processing
            await Future.delayed(const Duration(milliseconds: 10));
          },
        );
      }).toList();
      
      // Wait for all to complete
      await Future.wait(futures);
      
      // Verify all files were processed
      final stats = performanceService.getPerformanceStatistics();
      expect(stats, contains('concurrent_test'));
      
      // Clean up
      for (final file in testFiles) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
    
    test('should handle network errors with appropriate recovery', () async {
      final networkError = SocketException('Network is unreachable');
      
      // Test error handling
      await errorHandlingService.handleError(
        networkError,
        'network_test',
        shouldRetry: true,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 1),
      );
      
      // Verify error was recorded
      final stats = errorHandlingService.getErrorStatistics();
      expect(stats['totalErrors'], greaterThan(0));
      
      // Verify recovery suggestions are network-specific
      final suggestions = errorHandlingService.getRecoverySuggestions(networkError, 'network_test');
      expect(suggestions, contains('Check your internet connection'));
      expect(suggestions, contains('Try switching between WiFi and mobile data'));
    });
    
    test('should optimize chunk size based on performance', () async {
      // Simulate different throughput scenarios
      final scenarios = [
        (15 * 1024 * 1024, 'high_throughput'),    // 15MB/s
        (5 * 1024 * 1024, 'medium_throughput'),   // 5MB/s
        (1024 * 1024, 'low_throughput'),          // 1MB/s
        (100 * 1024, 'very_low_throughput'),       // 100KB/s
      ];
      
      for (final scenario in scenarios) {
        final throughput = scenario.$1;
        final context = scenario.$2;
        
        final chunkSize = performanceService.optimizeChunkSize(context, throughput);
        
        expect(chunkSize, greaterThan(0));
        expect(chunkSize, greaterThanOrEqualTo(64 * 1024)); // At least 64KB
        expect(chunkSize, lessThanOrEqualTo(1024 * 1024));   // At most 1MB
      }
    });
  });
}

/// Mock AirLink Protocol for testing
class MockAirLinkProtocol extends AirLinkProtocolSimplified {
  MockAirLinkProtocol() : super(
    deviceId: 'mock_device',
    capabilities: {'maxChunkSize': 1024 * 1024},
  );
  
  @override
  Future<void> sendFile(File file, int transferId) async {
    // Simulate random failures for testing
    if (DateTime.now().millisecondsSinceEpoch % 3 == 0) {
      throw SocketException('Mock connection failure');
    }
    
    // Simulate successful transfer
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
