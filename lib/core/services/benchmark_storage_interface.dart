import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/core/services/transfer_benchmark.dart';

/// Interface for benchmark storage operations
abstract class BenchmarkStorageInterface {
  /// Initialize the storage
  Future<void> initialize();
  
  /// Insert a benchmark record
  Future<void> insertBenchmark(TransferBenchmark benchmark);
  
  /// Get a benchmark by transfer ID
  Future<TransferBenchmark?> getBenchmark(String transferId);
  
  /// Get all benchmarks
  Future<List<TransferBenchmark>> getAllBenchmarks();
  
  /// Get benchmarks by transfer method
  Future<List<TransferBenchmark>> getBenchmarksByMethod(String method);
  
  /// Get average speed for a transfer method
  Future<double> getAverageSpeed(String method);
  
  /// Clean up old records
  Future<void> cleanupOldRecords();
  
  /// Close the storage
  Future<void> close();
}

/// In-memory storage implementation for testing
class InMemoryBenchmarkStorage implements BenchmarkStorageInterface {
  final List<TransferBenchmark> _benchmarks = [];
  
  @override
  Future<void> initialize() async {
    // No initialization needed for in-memory storage
  }
  
  @override
  Future<void> insertBenchmark(TransferBenchmark benchmark) async {
    // Remove existing benchmark with same transferId if exists
    _benchmarks.removeWhere((b) => b.transferId == benchmark.transferId);
    _benchmarks.add(benchmark);
  }
  
  @override
  Future<TransferBenchmark?> getBenchmark(String transferId) async {
    try {
      return _benchmarks.firstWhere((b) => b.transferId == transferId);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<List<TransferBenchmark>> getAllBenchmarks() async {
    return List.from(_benchmarks);
  }
  
  @override
  Future<List<TransferBenchmark>> getBenchmarksByMethod(String method) async {
    return _benchmarks.where((b) => b.transferMethod == method).toList();
  }
  
  @override
  Future<double> getAverageSpeed(String method) async {
    final methodBenchmarks = await getBenchmarksByMethod(method);
    final completedBenchmarks = methodBenchmarks
        .where((b) => b.status == unified.TransferStatus.completed)
        .toList();
    
    if (completedBenchmarks.isEmpty) return 0.0;
    
    final totalSpeed = completedBenchmarks.fold<double>(
      0.0, (sum, b) => sum + b.averageSpeed);
    return totalSpeed / completedBenchmarks.length;
  }
  
  @override
  Future<void> cleanupOldRecords() async {
    // For in-memory storage, we could implement a simple cleanup
    // but for testing purposes, we'll keep all records
  }
  
  @override
  Future<void> close() async {
    _benchmarks.clear();
  }
}
