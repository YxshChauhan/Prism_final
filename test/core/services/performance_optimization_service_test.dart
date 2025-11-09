import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/services/performance_optimization_service.dart';

void main() {
  group('Performance Optimization Service Tests', () {
    late PerformanceOptimizationService performanceService;
    late File testFile;
    
    setUp(() async {
      performanceService = PerformanceOptimizationService();
      
      // Create test file
      testFile = File('performance_test_file.txt');
      final content = 'Performance test file content. ' * 1000; // ~30KB
      await testFile.writeAsString(content);
    });
    
    tearDown(() async {
      performanceService.clearPerformanceData();
      if (await testFile.exists()) {
        await testFile.delete();
      }
    });
    
    test('should optimize chunk size based on throughput', () {
      final context = 'test_operation';
      final highThroughput = 15 * 1024 * 1024; // 15MB/s
      final mediumThroughput = 7 * 1024 * 1024;  // 7MB/s
      final lowThroughput = 2 * 1024 * 1024;     // 2MB/s
      final veryLowThroughput = 500 * 1024;      // 500KB/s
      
      // Test high throughput
      final highChunkSize = performanceService.optimizeChunkSize(context, highThroughput);
      expect(highChunkSize, equals(1024 * 1024)); // 1MB
      
      // Test medium throughput
      final mediumChunkSize = performanceService.optimizeChunkSize(context, mediumThroughput);
      expect(mediumChunkSize, equals((1024 * 1024 * 0.75).round())); // 768KB
      
      // Test low throughput
      final lowChunkSize = performanceService.optimizeChunkSize(context, lowThroughput);
      expect(lowChunkSize, equals((1024 * 1024 * 0.5).round())); // 512KB
      
      // Test very low throughput
      final veryLowChunkSize = performanceService.optimizeChunkSize(context, veryLowThroughput);
      expect(veryLowChunkSize, equals(64 * 1024)); // 64KB
    });
    
    test('should optimize concurrency based on system load', () {
      final context = 'test_operation';
      final concurrency = performanceService.optimizeConcurrency(context);
      
      expect(concurrency, isA<int>());
      expect(concurrency, greaterThan(0));
      expect(concurrency, lessThanOrEqualTo(4));
    });
    
    test('should record operation performance', () {
      final operation = 'test_operation';
      final duration = const Duration(milliseconds: 1000);
      final bytesProcessed = 1024 * 1024; // 1MB
      
      performanceService.recordOperation(operation, duration, bytesProcessed);
      
      final stats = performanceService.getPerformanceStatistics();
      expect(stats, contains(operation));
      expect(stats[operation]['totalOperations'], equals(1));
      expect(stats[operation]['totalDuration'], equals(1000));
      expect(stats[operation]['totalBytes'], equals(1024 * 1024));
    });
    
    test('should calculate performance metrics correctly', () {
      final operation = 'test_operation';
      
      // Record multiple operations
      for (int i = 0; i < 5; i++) {
        final duration = Duration(milliseconds: 1000 + i * 100);
        final bytesProcessed = 1024 * 1024 + i * 100000;
        performanceService.recordOperation(operation, duration, bytesProcessed);
      }
      
      final stats = performanceService.getPerformanceStatistics();
      final operationStats = stats[operation];
      
      expect(operationStats['totalOperations'], equals(5));
      expect(operationStats['totalDuration'], greaterThan(5000));
      expect(operationStats['totalBytes'], greaterThan(5 * 1024 * 1024));
      expect(operationStats['averageDuration'], greaterThan(1000));
      expect(operationStats['averageThroughput'], greaterThan(0));
    });
    
    test('should get optimized parameters', () {
      final operation = 'test_operation';
      
      // Record some performance data
      performanceService.recordOperation(
        operation,
        const Duration(milliseconds: 2000),
        1024 * 1024,
      );
      
      final parameters = performanceService.getOptimizedParameters(operation);
      
      expect(parameters.chunkSize, isA<int>());
      expect(parameters.concurrency, isA<int>());
      expect(parameters.timeout, isA<Duration>());
      expect(parameters.retryCount, isA<int>());
      
      expect(parameters.chunkSize, greaterThan(0));
      expect(parameters.concurrency, greaterThan(0));
      expect(parameters.timeout.inMilliseconds, greaterThan(0));
      expect(parameters.retryCount, greaterThan(0));
    });
    
    test('should process file in optimized chunks', () async {
      final operation = 'file_processing';
      final processedChunks = <int>[];
      
      await performanceService.processFileInChunks(
        testFile,
        operation,
        (chunk, index) async {
          processedChunks.add(index);
          // Simulate processing time
          await Future.delayed(const Duration(milliseconds: 10));
        },
      );
      
      expect(processedChunks, isNotEmpty);
      expect(processedChunks.length, greaterThan(0));
      
      // Verify all chunks were processed
      final fileSize = await testFile.length();
      final expectedChunks = (fileSize / 256 * 1024).ceil(); // Default chunk size
      expect(processedChunks.length, equals(expectedChunks));
    });
    
    test('should handle empty file', () async {
      final emptyFile = File('empty_test_file.txt');
      await emptyFile.writeAsString('');
      
      try {
        final processedChunks = <int>[];
        
        await performanceService.processFileInChunks(
          emptyFile,
          'empty_file_test',
          (chunk, index) async {
            processedChunks.add(index);
          },
        );
        
        expect(processedChunks, isEmpty);
      } finally {
        if (await emptyFile.exists()) {
          await emptyFile.delete();
        }
      }
    });
    
    test('should clear performance data', () {
      final operation = 'test_operation';
      
      // Record some data
      performanceService.recordOperation(
        operation,
        const Duration(milliseconds: 1000),
        1024 * 1024,
      );
      
      // Verify data exists
      var stats = performanceService.getPerformanceStatistics();
      expect(stats, isNotEmpty);
      
      // Clear data
      performanceService.clearPerformanceData();
      
      // Verify data is cleared
      stats = performanceService.getPerformanceStatistics();
      expect(stats, isEmpty);
    });
  });
  
  group('Performance Optimization Integration Tests', () {
    test('should optimize parameters based on historical performance', () async {
      final performanceService = PerformanceOptimizationService();
      final testFile = File('integration_test_file.txt');
      
      try {
        // Create test file
        final content = 'Integration test content. ' * 2000; // ~60KB
        await testFile.writeAsString(content);
        
        // Process file multiple times to build performance history
        for (int i = 0; i < 3; i++) {
          await performanceService.processFileInChunks(
            testFile,
            'integration_test',
            (chunk, index) async {
              // Simulate varying processing time
              await Future.delayed(Duration(milliseconds: 50 + i * 10));
            },
          );
        }
        
        // Get optimized parameters
        final parameters = performanceService.getOptimizedParameters('integration_test');
        
        // Verify parameters are reasonable
        expect(parameters.chunkSize, greaterThan(0));
        expect(parameters.concurrency, greaterThan(0));
        expect(parameters.timeout.inMilliseconds, greaterThan(0));
        expect(parameters.retryCount, greaterThan(0));
        
        // Verify parameters are within expected ranges
        expect(parameters.chunkSize, greaterThanOrEqualTo(64 * 1024));
        expect(parameters.chunkSize, lessThanOrEqualTo(1024 * 1024));
        expect(parameters.concurrency, lessThanOrEqualTo(4));
        expect(parameters.timeout.inSeconds, lessThanOrEqualTo(300));
        
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });
    
    test('should handle concurrent operations efficiently', () async {
      final performanceService = PerformanceOptimizationService();
      final testFile = File('concurrent_test_file.txt');
      
      try {
        // Create test file
        final content = 'Concurrent test content. ' * 1000; // ~30KB
        await testFile.writeAsString(content);
        
        // Process file with concurrent operations
        final stopwatch = Stopwatch()..start();
        
        await performanceService.processFileInChunks(
          testFile,
          'concurrent_test',
          (chunk, index) async {
            // Simulate processing time
            await Future.delayed(const Duration(milliseconds: 20));
          },
        );
        
        stopwatch.stop();
        
        // Verify processing completed
        expect(stopwatch.elapsed.inMilliseconds, greaterThan(0));
        
        // Verify performance was recorded
        final stats = performanceService.getPerformanceStatistics();
        expect(stats, contains('concurrent_test'));
        
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });
  });
}
