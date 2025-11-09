import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/benchmark_storage_interface.dart';
import 'package:airlink/core/services/transfer_benchmark.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:injectable/injectable.dart';

/// System resource snapshot for tracking device performance during transfers
class SystemResourceSnapshot {
  final DateTime timestamp;
  final double cpuUsagePercent;
  final int memoryUsageMB;
  final int batteryLevel;
  final double networkSpeedMbps;
  final String deviceTemperature;
  
  const SystemResourceSnapshot({
    required this.timestamp,
    required this.cpuUsagePercent,
    required this.memoryUsageMB,
    required this.batteryLevel,
    required this.networkSpeedMbps,
    required this.deviceTemperature,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cpuUsagePercent': cpuUsagePercent,
      'memoryUsageMB': memoryUsageMB,
      'batteryLevel': batteryLevel,
      'networkSpeedMbps': networkSpeedMbps,
      'deviceTemperature': deviceTemperature,
    };
  }
  
  factory SystemResourceSnapshot.fromMap(Map<String, dynamic> map) {
    return SystemResourceSnapshot(
      timestamp: DateTime.parse(map['timestamp']),
      cpuUsagePercent: map['cpuUsagePercent']?.toDouble() ?? 0.0,
      memoryUsageMB: map['memoryUsageMB']?.toInt() ?? 0,
      batteryLevel: map['batteryLevel']?.toInt() ?? 0,
      networkSpeedMbps: map['networkSpeedMbps']?.toDouble() ?? 0.0,
      deviceTemperature: map['deviceTemperature'] ?? 'unknown',
    );
  }
}

/// Transfer benchmarking service for collecting and analyzing transfer metrics
@injectable
class TransferBenchmarkingService {
  static final TransferBenchmarkingService _instance = TransferBenchmarkingService._internal();
  factory TransferBenchmarkingService() => _instance;
  TransferBenchmarkingService._internal();

  Database? _database;
  final LoggerService _logger = LoggerService();
  BenchmarkStorageInterface? _storage;
  Timer? _cleanupTimer;
  
  // Benchmark tracking
  final Map<String, TransferBenchmark> _activeBenchmarks = {};
  final Map<String, DateTime> _benchmarkStartTimes = {};
  final Map<String, List<double>> _speedHistory = {};
  
  // System resource tracking
  final Map<String, Timer?> _resourceMonitors = {};
  final Map<String, List<SystemResourceSnapshot>> _resourceHistory = {};
  final Map<String, Map<String, dynamic>> _nativeMetricsAccumulator = {};
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Constants
  static const int MAX_BENCHMARK_RECORDS = 1000;
  static const Duration CLEANUP_INTERVAL = Duration(days: 30);

  /// Initialize the benchmarking service
  Future<void> initialize({BenchmarkStorageInterface? storage}) async {
    try {
      // Use injected storage if provided
      if (storage != null) {
        _storage = storage;
        await _storage!.initialize();
        _logger.info('TransferBenchmarkingService initialized with injected storage');
        return;
      }

      // Detect test environment and use appropriate storage
      final isTestEnvironment = Platform.environment['FLUTTER_TEST'] == 'true' ||
          Platform.environment['TEST'] == 'true' ||
          !Platform.isAndroid && !Platform.isIOS;
      
      if (isTestEnvironment) {
        _storage = InMemoryBenchmarkStorage();
        await _storage!.initialize();
        _logger.info('TransferBenchmarkingService initialized with in-memory storage for testing');
      } else {
        _database = await _initDatabase();
        await _cleanupOldRecords();
        _logger.info('TransferBenchmarkingService initialized with SQLite storage');
      }
    } catch (e) {
      _logger.error('Failed to initialize TransferBenchmarkingService: $e');
      rethrow;
    }
  }

  /// Ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (_database == null && _storage == null) {
      await initialize();
    }
  }

  /// Start tracking a transfer benchmark
  Future<void> startBenchmark({
    required String transferId,
    required String fileName,
    required int fileSize,
    required String transferMethod,
    required String deviceType,
  }) async {
    try {
      await _ensureInitialized();
      
      final benchmark = TransferBenchmark(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        transferMethod: transferMethod,
        deviceType: deviceType,
        startTime: DateTime.now(),
        status: unified.TransferStatus.pending,
      );

      _activeBenchmarks[transferId] = benchmark;
      _benchmarkStartTimes[transferId] = DateTime.now();
      _speedHistory[transferId] = [];
      _resourceHistory[transferId] = [];
      
      // Start periodic resource monitoring
      _startResourceMonitoring(transferId);

      _logger.info('Started benchmark for transfer: $transferId');
    } catch (e) {
      _logger.error('Failed to start benchmark for $transferId: $e');
    }
  }

  /// Update transfer progress and speed with system resource monitoring
  Future<void> updateProgress({
    required String transferId,
    required int bytesTransferred,
    required double currentSpeed,
  }) async {
    try {
      if (!_activeBenchmarks.containsKey(transferId)) return;

      final benchmark = _activeBenchmarks[transferId]!;
      _speedHistory[transferId]!.add(currentSpeed);
      
      // Capture system resource snapshot
      final resourceSnapshot = await _captureSystemResourceSnapshot();
      _resourceHistory[transferId]?.add(resourceSnapshot);

      // Periodically pull native audit metrics (every 10 updates to avoid overhead)
      if (_speedHistory[transferId]!.length % 10 == 0) {
        try {
          final nativeMetrics = await AirLinkPlugin.getAuditMetrics(transferId);
          if (nativeMetrics.isNotEmpty) {
            _logger.debug('Native metrics for $transferId: ${nativeMetrics.keys.join(", ")}');
            
            // Parse and accumulate native metrics
            final cpuUsage = _parseDouble(nativeMetrics['cpuUsagePercent']);
            final memoryUsage = _parseInt(nativeMetrics['memoryUsageMB']);
            final batteryLevel = _parseInt(nativeMetrics['batteryLevel']);
            final temperature = nativeMetrics['deviceTemperature']?.toString();
            
            // Initialize accumulator if needed
            if (!_nativeMetricsAccumulator.containsKey(transferId)) {
              _nativeMetricsAccumulator[transferId] = {
                'cpuValues': <double>[],
                'memoryValues': <int>[],
                'batteryValues': <int>[],
                'temperatures': <String>[],
                'sampleCount': 0,
              };
            }
            
            // Accumulate values
            final accumulator = _nativeMetricsAccumulator[transferId]!;
            if (cpuUsage != null) (accumulator['cpuValues'] as List<double>).add(cpuUsage);
            if (memoryUsage != null) (accumulator['memoryValues'] as List<int>).add(memoryUsage);
            if (batteryLevel != null) (accumulator['batteryValues'] as List<int>).add(batteryLevel);
            if (temperature != null) (accumulator['temperatures'] as List<String>).add(temperature);
            accumulator['sampleCount'] = (accumulator['sampleCount'] as int) + 1;
          }
        } catch (e) {
          _logger.debug('Failed to get native metrics for $transferId: $e');
          // Continue without native metrics - not critical
        }
      }

      // Update benchmark with current progress
      final updatedBenchmark = benchmark.copyWith(
        bytesTransferred: bytesTransferred,
        currentSpeed: currentSpeed,
        status: unified.TransferStatus.transferring,
      );

      _activeBenchmarks[transferId] = updatedBenchmark;

      _logger.debug('Updated progress for transfer: $transferId - ${bytesTransferred} bytes at ${currentSpeed.toStringAsFixed(2)} B/s');
    } catch (e) {
      _logger.error('Failed to update progress for $transferId: $e');
    }
  }

  /// Complete a transfer benchmark
  Future<void> completeBenchmark({
    required String transferId,
    required unified.TransferStatus status,
    String? errorMessage,
  }) async {
    try {
      if (!_activeBenchmarks.containsKey(transferId)) return;

      final benchmark = _activeBenchmarks[transferId]!;
      final startTime = _benchmarkStartTimes[transferId]!;
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Calculate final metrics
      final speedHistory = _speedHistory[transferId] ?? [];
      final averageSpeed = speedHistory.isNotEmpty 
          ? speedHistory.reduce((a, b) => a + b) / speedHistory.length 
          : 0.0;
      final peakSpeed = speedHistory.isNotEmpty 
          ? speedHistory.reduce((a, b) => a > b ? a : b) 
          : 0.0;
      
      // Compute native metrics aggregates from accumulator
      final nativeMetrics = _nativeMetricsAccumulator[transferId];
      double? avgCpu;
      double? maxCpu;
      int? avgMemory;
      int? maxMemory;
      int? minBattery;
      String? deviceTemp;
      int? resourceSamples;
      
      if (nativeMetrics != null && nativeMetrics['sampleCount'] as int > 0) {
        final cpuValues = nativeMetrics['cpuValues'] as List<double>;
        final memoryValues = nativeMetrics['memoryValues'] as List<int>;
        final batteryValues = nativeMetrics['batteryValues'] as List<int>;
        final temperatures = nativeMetrics['temperatures'] as List<String>;
        
        if (cpuValues.isNotEmpty) {
          avgCpu = cpuValues.reduce((a, b) => a + b) / cpuValues.length;
          maxCpu = cpuValues.reduce((a, b) => a > b ? a : b);
        }
        
        if (memoryValues.isNotEmpty) {
          avgMemory = (memoryValues.reduce((a, b) => a + b) / memoryValues.length).round();
          maxMemory = memoryValues.reduce((a, b) => a > b ? a : b);
        }
        
        if (batteryValues.isNotEmpty) {
          minBattery = batteryValues.reduce((a, b) => a < b ? a : b);
        }
        
        if (temperatures.isNotEmpty) {
          deviceTemp = temperatures.last; // Use most recent temperature
        }
        
        resourceSamples = nativeMetrics['sampleCount'] as int;
      }
      
      final completedBenchmark = benchmark.copyWith(
        endTime: endTime,
        duration: duration,
        averageSpeed: averageSpeed,
        peakSpeed: peakSpeed,
        status: status,
        errorMessage: errorMessage,
        // Ensure bytesTransferred is set to fileSize for completed transfers
        bytesTransferred: status == unified.TransferStatus.completed 
            ? benchmark.fileSize 
            : benchmark.bytesTransferred,
        // Add native resource metrics
        avgCpuUsage: avgCpu,
        maxCpuUsage: maxCpu,
        avgMemoryUsage: avgMemory,
        maxMemoryUsage: maxMemory,
        minBatteryLevel: minBattery,
        deviceTemperature: deviceTemp,
        resourceSamples: resourceSamples,
      );

      // Save to storage
      await _saveBenchmark(completedBenchmark);

      // Clean up active tracking
      _activeBenchmarks.remove(transferId);
      _benchmarkStartTimes.remove(transferId);
      _speedHistory.remove(transferId);
      _nativeMetricsAccumulator.remove(transferId);
      
      // Stop resource monitoring and cleanup
      _stopResourceMonitoring(transferId);
      _resourceHistory.remove(transferId);

      _logger.info('Completed benchmark for transfer: $transferId - Status: ${status.name}');
    } catch (e) {
      _logger.error('Failed to complete benchmark for $transferId: $e');
    }
  }

  /// Get benchmark for a specific transfer
  Future<TransferBenchmark?> getBenchmark(String transferId) async {
    try {
      if (_storage != null) {
        return await _storage!.getBenchmark(transferId);
      } else if (_database == null) return null;

      final List<Map<String, dynamic>> results = await _database!.query(
        'transfer_benchmarks',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
        limit: 1,
      );

      if (results.isEmpty) return null;

      return _benchmarkFromMap(results.first);
    } catch (e) {
      _logger.error('Failed to get benchmark for $transferId: $e');
      return null;
    }
  }

  /// Get all benchmarks
  Future<List<TransferBenchmark>> getAllBenchmarks() async {
    try {
      if (_storage != null) {
        return await _storage!.getAllBenchmarks();
      } else if (_database == null) return [];

      final List<Map<String, dynamic>> results = await _database!.query(
        'transfer_benchmarks',
        orderBy: 'start_time DESC',
      );

      return results.map((map) => _benchmarkFromMap(map)).toList();
    } catch (e) {
      _logger.error('Failed to get all benchmarks: $e');
      return [];
    }
  }

  /// Get benchmarks by transfer method
  Future<List<TransferBenchmark>> getBenchmarksByMethod(String method) async {
    try {
      if (_storage != null) {
        return await _storage!.getBenchmarksByMethod(method);
      } else if (_database == null) return [];

      final List<Map<String, dynamic>> results = await _database!.query(
        'transfer_benchmarks',
        where: 'transfer_method = ?',
        whereArgs: [method],
        orderBy: 'start_time DESC',
      );

      return results.map((map) => _benchmarkFromMap(map)).toList();
    } catch (e) {
      _logger.error('Failed to get benchmarks by method $method: $e');
      return [];
    }
  }

  /// Start periodic resource monitoring for a transfer
  void _startResourceMonitoring(String transferId) {
    try {
      // Monitor resources every 2 seconds during transfer
      final timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!_activeBenchmarks.containsKey(transferId)) {
          timer.cancel();
          return;
        }
        
        final snapshot = await _captureSystemResourceSnapshot();
        _resourceHistory[transferId]?.add(snapshot);
      });
      
      _resourceMonitors[transferId] = timer;
      _logger.debug('Started resource monitoring for transfer: $transferId');
    } catch (e) {
      _logger.error('Failed to start resource monitoring for $transferId: $e');
    }
  }
  
  /// Stop resource monitoring for a transfer
  void _stopResourceMonitoring(String transferId) {
    try {
      _resourceMonitors[transferId]?.cancel();
      _resourceMonitors.remove(transferId);
      _logger.debug('Stopped resource monitoring for transfer: $transferId');
    } catch (e) {
      _logger.error('Failed to stop resource monitoring for $transferId: $e');
    }
  }
  
  /// Capture current system resource snapshot
  Future<SystemResourceSnapshot> _captureSystemResourceSnapshot() async {
    try {
      // Get device info for memory and other metrics
      final deviceInfo = await _deviceInfo.deviceInfo;
      
      // Default values
      double cpuUsage = 0.0;
      int memoryUsage = 0;
      int batteryLevel = 100;
      double networkSpeed = 0.0;
      String temperature = 'normal';
      
      // Platform-specific resource collection
      if (Platform.isAndroid) {
        final androidInfo = deviceInfo as AndroidDeviceInfo;
        _logger.debug('TransferBenchmark', 'Android device model: ${androidInfo.model}');
        // Estimate memory usage based on available info
        memoryUsage = _estimateMemoryUsage();
        cpuUsage = _estimateCpuUsage();
        batteryLevel = await _getBatteryLevel();
        temperature = await _getDeviceTemperature();
      } else if (Platform.isIOS) {
        final iosInfo = deviceInfo as IosDeviceInfo;
        _logger.debug('TransferBenchmark', 'iOS device model: ${iosInfo.model}');
        // iOS has more restrictions, use estimates
        memoryUsage = _estimateMemoryUsage();
        cpuUsage = _estimateCpuUsage();
        batteryLevel = await _getBatteryLevel();
        temperature = 'normal'; // iOS doesn't expose temperature
      }
      
      return SystemResourceSnapshot(
        timestamp: DateTime.now(),
        cpuUsagePercent: cpuUsage,
        memoryUsageMB: memoryUsage,
        batteryLevel: batteryLevel,
        networkSpeedMbps: networkSpeed,
        deviceTemperature: temperature,
      );
    } catch (e) {
      _logger.error('Failed to capture system resource snapshot: $e');
      // Return default snapshot on error
      return SystemResourceSnapshot(
        timestamp: DateTime.now(),
        cpuUsagePercent: 0.0,
        memoryUsageMB: 0,
        batteryLevel: 100,
        networkSpeedMbps: 0.0,
        deviceTemperature: 'unknown',
      );
    }
  }
  
  /// Estimate current memory usage in MB
  int _estimateMemoryUsage() {
    try {
      // Use ProcessInfo to get memory usage (approximate)
      final info = ProcessInfo.currentRss;
      return (info / (1024 * 1024)).round(); // Convert bytes to MB
    } catch (e) {
      return 0;
    }
  }
  
  /// Estimate current CPU usage percentage
  double _estimateCpuUsage() {
    try {
      // Simple CPU usage estimation based on active transfers
      final activeTransfers = _activeBenchmarks.length;
      return (activeTransfers * 15.0).clamp(0.0, 100.0); // Rough estimate
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Get battery level (platform-specific)
  Future<int> _getBatteryLevel() async {
    try {
      // This would typically use battery_plus package
      // For now, return a default value
      return 100;
    } catch (e) {
      return 100;
    }
  }
  
  /// Get device temperature (Android only)
  Future<String> _getDeviceTemperature() async {
    try {
      if (Platform.isAndroid) {
        // This would typically use native Android APIs
        // For now, return a default value
        return 'normal';
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }
  
  /// Get system resource statistics for a transfer
  Map<String, dynamic> getResourceStatistics(String transferId) {
    try {
      final resourceHistory = _resourceHistory[transferId] ?? [];
      
      if (resourceHistory.isEmpty) {
        return {
          'avgCpuUsage': 0.0,
          'maxCpuUsage': 0.0,
          'avgMemoryUsage': 0,
          'maxMemoryUsage': 0,
          'minBatteryLevel': 100,
          'avgNetworkSpeed': 0.0,
          'resourceSamples': 0,
        };
      }
      
      final cpuValues = resourceHistory.map((s) => s.cpuUsagePercent).toList();
      final memoryValues = resourceHistory.map((s) => s.memoryUsageMB).toList();
      final batteryValues = resourceHistory.map((s) => s.batteryLevel).toList();
      final networkValues = resourceHistory.map((s) => s.networkSpeedMbps).toList();
      
      return {
        'avgCpuUsage': cpuValues.reduce((a, b) => a + b) / cpuValues.length,
        'maxCpuUsage': cpuValues.reduce((a, b) => a > b ? a : b),
        'avgMemoryUsage': (memoryValues.reduce((a, b) => a + b) / memoryValues.length).round(),
        'maxMemoryUsage': memoryValues.reduce((a, b) => a > b ? a : b),
        'minBatteryLevel': batteryValues.reduce((a, b) => a < b ? a : b),
        'avgNetworkSpeed': networkValues.reduce((a, b) => a + b) / networkValues.length,
        'resourceSamples': resourceHistory.length,
      };
    } catch (e) {
      _logger.error('Failed to get resource statistics for $transferId: $e');
      return {};
    }
  }

  /// Get average speed for a transfer method
  Future<double> getAverageSpeed(String method) async {
    try {
      if (_storage != null) {
        return await _storage!.getAverageSpeed(method);
      } else if (_database == null) return 0.0;

      final List<Map<String, dynamic>> results = await _database!.rawQuery(
        'SELECT AVG(average_speed) as avg_speed FROM transfer_benchmarks WHERE transfer_method = ? AND status = ?',
        [method, unified.TransferStatus.completed.name],
      );

      return results.first['avg_speed']?.toDouble() ?? 0.0;
    } catch (e) {
      _logger.error('Failed to get average speed for $method: $e');
      return 0.0;
    }
  }

  /// Generate benchmark statistics report
  Future<Map<String, dynamic>> generateReport() async {
    try {
      if (_database == null && _storage == null) return {};

      final benchmarks = await getAllBenchmarks();
      final completedBenchmarks = benchmarks.where((b) => b.status == unified.TransferStatus.completed).toList();

      if (completedBenchmarks.isEmpty) {
        return {
          'total_transfers': 0,
          'success_rate': 0.0,
          'average_speed': 0.0,
          'total_data_transferred': 0,
          'methods': <String, dynamic>{},
        };
      }

      // Calculate overall statistics
      final totalTransfers = benchmarks.length;
      final successfulTransfers = completedBenchmarks.length;
      final successRate = totalTransfers > 0 ? successfulTransfers / totalTransfers : 0.0;
      
      final totalDataTransferred = completedBenchmarks.fold<int>(
        0, (sum, benchmark) => sum + benchmark.fileSize,
      );
      
      final averageSpeed = completedBenchmarks.isNotEmpty
          ? completedBenchmarks.map((b) => b.averageSpeed).reduce((a, b) => a + b) / completedBenchmarks.length
          : 0.0;

      // Calculate statistics by method
      final methods = <String, dynamic>{};
      final methodGroups = <String, List<TransferBenchmark>>{};
      
      for (final benchmark in completedBenchmarks) {
        methodGroups.putIfAbsent(benchmark.transferMethod, () => []).add(benchmark);
      }

      for (final entry in methodGroups.entries) {
        final method = entry.key;
        final methodBenchmarks = entry.value;
        
        final methodAverageSpeed = methodBenchmarks.isNotEmpty
            ? methodBenchmarks.map((b) => b.averageSpeed).reduce((a, b) => a + b) / methodBenchmarks.length
            : 0.0;
        
        final methodPeakSpeed = methodBenchmarks.isNotEmpty
            ? methodBenchmarks.map((b) => b.peakSpeed).reduce((a, b) => a > b ? a : b)
            : 0.0;

        methods[method] = {
          'count': methodBenchmarks.length,
          'average_speed': methodAverageSpeed,
          'peak_speed': methodPeakSpeed,
          'total_data': methodBenchmarks.fold<int>(0, (sum, b) => sum + b.fileSize),
        };
      }

      return {
        'total_transfers': totalTransfers,
        'successful_transfers': successfulTransfers,
        'success_rate': successRate,
        'average_speed': averageSpeed,
        'total_data_transferred': totalDataTransferred,
        'methods': methods,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.error('Failed to generate report: $e');
      return {};
    }
  }

  /// Export benchmarks as JSON
  Future<String> exportBenchmarksAsJson() async {
    try {
      final benchmarks = await getAllBenchmarks();
      final report = await generateReport();
      
      final exportData = {
        'report': report,
        'benchmarks': benchmarks.map((b) => b.toMap()).toList(),
        'exported_at': DateTime.now().toIso8601String(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      _logger.error('Failed to export benchmarks: $e');
      return '{}';
    }
  }

  /// Export benchmarks as CSV
  Future<String> exportBenchmarksAsCsv() async {
    try {
      final benchmarks = await getAllBenchmarks();
      
      if (benchmarks.isEmpty) {
        return 'No benchmark data available';
      }
      
      final StringBuffer csv = StringBuffer();
      
      // CSV Header
      csv.writeln('transfer_id,file_name,file_size,transfer_method,device_type,start_time,end_time,duration_ms,bytes_transferred,average_speed,peak_speed,status,error_message');
      
      // CSV Data
      for (final benchmark in benchmarks) {
        csv.writeln([
          benchmark.transferId,
          benchmark.fileName,
          benchmark.fileSize,
          benchmark.transferMethod,
          benchmark.deviceType,
          benchmark.startTime.toIso8601String(),
          benchmark.endTime?.toIso8601String() ?? '',
          benchmark.duration?.inMilliseconds ?? '',
          benchmark.bytesTransferred,
          benchmark.averageSpeed,
          benchmark.peakSpeed,
          benchmark.status.name,
          benchmark.errorMessage ?? '',
        ].map((field) => '"${field.toString().replaceAll('"', '""')}"').join(','));
      }
      
      return csv.toString();
    } catch (e) {
      _logger.error('Failed to export benchmarks as CSV: $e');
      return 'Error exporting CSV data';
    }
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'transfer_benchmarks.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transfer_benchmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transfer_id TEXT UNIQUE NOT NULL,
            file_name TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            transfer_method TEXT NOT NULL,
            device_type TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            duration_ms INTEGER,
            bytes_transferred INTEGER DEFAULT 0,
            average_speed REAL DEFAULT 0.0,
            peak_speed REAL DEFAULT 0.0,
            status TEXT NOT NULL,
            error_message TEXT,
            created_at TEXT NOT NULL,
            avg_cpu_usage REAL,
            max_cpu_usage REAL,
            avg_memory_usage INTEGER,
            max_memory_usage INTEGER,
            min_battery_level INTEGER,
            avg_network_speed REAL,
            resource_samples INTEGER,
            device_temperature TEXT
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_transfer_method ON transfer_benchmarks(transfer_method)
        ''');

        await db.execute('''
          CREATE INDEX idx_start_time ON transfer_benchmarks(start_time)
        ''');

        await db.execute('''
          CREATE INDEX idx_status ON transfer_benchmarks(status)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add native resource metric columns
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN avg_cpu_usage REAL');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN max_cpu_usage REAL');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN avg_memory_usage INTEGER');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN max_memory_usage INTEGER');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN min_battery_level INTEGER');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN avg_network_speed REAL');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN resource_samples INTEGER');
          await db.execute('ALTER TABLE transfer_benchmarks ADD COLUMN device_temperature TEXT');
          _logger.info('Upgraded transfer_benchmarks table to version 2 with resource metrics');
        }
      },
    );
  }

  /// Save benchmark to storage
  Future<void> _saveBenchmark(TransferBenchmark benchmark) async {
    if (_storage != null) {
      await _storage!.insertBenchmark(benchmark);
    } else if (_database != null) {
      await _database!.insert(
        'transfer_benchmarks',
        benchmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Clean up old records
  Future<void> _cleanupOldRecords() async {
    if (_database == null) return;

    final cutoffDate = DateTime.now().subtract(CLEANUP_INTERVAL);
    
    // Keep only the most recent records if we exceed the limit
    final count = await _database!.rawQuery('SELECT COUNT(*) as count FROM transfer_benchmarks');
    final totalCount = count.first['count'] as int;
    
    if (totalCount > MAX_BENCHMARK_RECORDS) {
      await _database!.rawDelete('''
        DELETE FROM transfer_benchmarks 
        WHERE id NOT IN (
          SELECT id FROM transfer_benchmarks 
          ORDER BY start_time DESC 
          LIMIT ?
        )
      ''', [MAX_BENCHMARK_RECORDS]);
    }

    // Remove old records
    await _database!.delete(
      'transfer_benchmarks',
      where: 'start_time < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Convert database map to TransferBenchmark
  TransferBenchmark _benchmarkFromMap(Map<String, dynamic> map) {
    return TransferBenchmark(
      transferId: map['transfer_id'],
      fileName: map['file_name'],
      fileSize: map['file_size'],
      transferMethod: map['transfer_method'],
      deviceType: map['device_type'],
      startTime: DateTime.parse(map['start_time']),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      duration: map['duration_ms'] != null ? Duration(milliseconds: map['duration_ms']) : null,
      bytesTransferred: map['bytes_transferred'] ?? 0,
      averageSpeed: map['average_speed']?.toDouble() ?? 0.0,
      peakSpeed: map['peak_speed']?.toDouble() ?? 0.0,
      status: unified.TransferStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => unified.TransferStatus.failed,
      ),
      errorMessage: map['error_message'],
      // Native resource metrics
      avgCpuUsage: map['avg_cpu_usage']?.toDouble(),
      maxCpuUsage: map['max_cpu_usage']?.toDouble(),
      avgMemoryUsage: map['avg_memory_usage']?.toInt(),
      maxMemoryUsage: map['max_memory_usage']?.toInt(),
      minBatteryLevel: map['min_battery_level']?.toInt(),
      avgNetworkSpeed: map['avg_network_speed']?.toDouble(),
      resourceSamples: map['resource_samples']?.toInt(),
      deviceTemperature: map['device_temperature']?.toString(),
    );
  }
  
  /// Parse double from dynamic value with null safety
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  /// Parse int from dynamic value with null safety
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Schedule periodic cleanup of old records
  void scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(days: 7), (timer) async {
      try {
        await _cleanupOldRecords();
        _logger.info('Scheduled cleanup completed');
      } catch (e) {
        _logger.error('Scheduled cleanup failed: $e');
      }
    });
    _logger.info('Cleanup scheduled to run weekly');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _database?.close();
    await _storage?.close();
    _database = null;
    _storage = null;
  }
}

