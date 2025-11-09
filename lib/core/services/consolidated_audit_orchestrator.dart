import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:airlink/core/services/audit_service.dart';
import 'package:airlink/core/services/checksum_verification_service.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';
import 'package:airlink/core/services/qr_connection_service.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:airlink/models/manual_test_result.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Master audit orchestrator service
/// Provides single entry point for comprehensive audit execution
class ConsolidatedAuditOrchestrator {
  final AuditService _auditService;
  // ignore: unused_field
  final ChecksumVerificationService _checksumService;
  // ignore: unused_field
  final TransferBenchmarkingService _benchmarkingService;
  // ignore: unused_field
  final QRConnectionService _qrService;
  final LoggerService _logger;

  final StreamController<AuditProgress> _progressController =
      StreamController<AuditProgress>.broadcast();

  Stream<AuditProgress> get progressStream => _progressController.stream;

  ConsolidatedAuditOrchestrator({
    required AuditService auditService,
    required ChecksumVerificationService checksumService,
    required TransferBenchmarkingService benchmarkingService,
    required QRConnectionService qrService,
    required LoggerService logger,
  })  : _auditService = auditService,
        _checksumService = checksumService,
        _benchmarkingService = benchmarkingService,
        _qrService = qrService,
        _logger = logger;

  /// Run comprehensive audit orchestrating all phases
  Future<ConsolidatedAuditResult> runComprehensiveAudit({
    required String outputDirectory,
    bool includeManualTests = true,
  }) async {
    _logger.info('ConsolidatedAuditOrchestrator',
        'Starting comprehensive audit...');

    final startTime = DateTime.now();
    final result = ConsolidatedAuditResult(
      startTime: startTime,
      outputDirectory: outputDirectory,
    );

    try {
      // Phase 1: Environment validation
      _emitProgress(AuditPhase.environmentValidation, 0, 'Validating environment...');
      final envValidation = await _validateEnvironment();
      result.environmentValidation = envValidation;
      _emitProgress(AuditPhase.environmentValidation, 100, 'Environment validated');

      if (!envValidation.isValid) {
        throw Exception('Environment validation failed: ${envValidation.errors.join(', ')}');
      }

      // Phase 2: Automated tests
      _emitProgress(AuditPhase.automatedTests, 0, 'Running automated tests...');
      final automatedResults = await _runAutomatedTests();
      result.automatedResults = automatedResults;
      _emitProgress(AuditPhase.automatedTests, 100,
          'Automated tests complete: ${automatedResults.length} tests');

      // Phase 3: Manual tests (if enabled)
      if (includeManualTests) {
        _emitProgress(AuditPhase.manualTests, 0, 'Waiting for manual tests...');
        final manualResults = await _coordinateManualTests();
        result.manualResults = manualResults;
        _emitProgress(AuditPhase.manualTests, 100,
            'Manual tests complete: ${manualResults.results.length} tests');
      }

      // Phase 4: Evidence collection
      _emitProgress(AuditPhase.evidenceCollection, 0, 'Collecting evidence...');
      final evidence = await _collectEvidence(outputDirectory);
      result.evidence = evidence;
      _emitProgress(AuditPhase.evidenceCollection, 100,
          'Evidence collected: ${evidence.length} items');

      // Phase 5: Report generation
      _emitProgress(AuditPhase.reportGeneration, 0, 'Generating consolidated report...');
      final reportPaths = await _generateConsolidatedReport(result, outputDirectory);
      result.reportPaths = reportPaths;
      _emitProgress(AuditPhase.reportGeneration, 100,
          'Reports generated: ${reportPaths.length} formats');

      result.endTime = DateTime.now();
      result.success = true;

      _logger.info('ConsolidatedAuditOrchestrator',
          'Comprehensive audit completed successfully in ${result.duration.inSeconds}s');

      return result;
    } catch (e, stackTrace) {
      _logger.error('ConsolidatedAuditOrchestrator',
          'Comprehensive audit failed: $e\n$stackTrace');
      result.endTime = DateTime.now();
      result.success = false;
      result.error = e.toString();
      return result;
    } finally {
      _progressController.close();
    }
  }

  /// Phase 1: Validate environment
  Future<EnvironmentValidation> _validateEnvironment() async {
    final validation = EnvironmentValidation();

    try {
      // Check audit mode can be enabled
      final auditModeEnabled = await _auditService.enableAuditMode();
      if (!auditModeEnabled) {
        validation.errors.add('Failed to enable audit mode');
      }
      validation.details['auditMode'] = auditModeEnabled;

      // Check network connectivity (Wi-Fi/BLE)
      final networkStatus = await _checkNetworkConnectivity();
      validation.details['network'] = networkStatus;
      if (!networkStatus['wifiAvailable'] && !networkStatus['bleAvailable']) {
        validation.errors.add('No network connectivity (Wi-Fi or BLE required)');
      }

      // Check required permissions
      final permissionsStatus = await _checkPermissions();
      validation.details['permissions'] = permissionsStatus;
      if (permissionsStatus['missingPermissions'].isNotEmpty) {
        validation.errors.add('Missing permissions: ${permissionsStatus['missingPermissions'].join(', ')}');
      }

      // Check available storage
      final storageStatus = await _checkStorage();
      validation.details['storage'] = storageStatus;
      if (storageStatus['availableGB'] < 0.1) {
        validation.errors.add('Insufficient storage (< 100 MB available)');
      }

      validation.isValid = validation.errors.isEmpty;
    } catch (e) {
      validation.errors.add('Environment validation error: $e');
      validation.isValid = false;
    }

    return validation;
  }
  
  /// Check network connectivity (Wi-Fi and BLE) with platform capabilities
  Future<Map<String, dynamic>> _checkNetworkConnectivity() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      final wifiName = await networkInfo.getWifiName();
      
      // Get platform capabilities
      final capabilities = await AirLinkPlugin.getCapabilities();
      
      return {
        'wifiAvailable': wifiIP != null && wifiIP.isNotEmpty,
        'wifiIP': wifiIP ?? 'N/A',
        'wifiName': wifiName ?? 'N/A',
        'wifiAwareAvailable': capabilities['wifiAwareAvailable'] ?? false,
        'bleSupported': capabilities['bleSupported'] ?? false,
        'bleEnabled': capabilities['bleEnabled'] ?? false,
        'platform': capabilities['platform'] ?? Platform.operatingSystem,
      };
    } catch (e) {
      _logger.warning('ConsolidatedAuditOrchestrator', 'Network check failed: $e');
      return {
        'wifiAvailable': false,
        'wifiIP': 'N/A',
        'wifiName': 'N/A',
        'wifiAwareAvailable': false,
        'bleSupported': false,
        'bleEnabled': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Check required permissions
  Future<Map<String, dynamic>> _checkPermissions() async {
    final requiredPermissions = [
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];
    
    final permissionStatus = <String, bool>{};
    final missingPermissions = <String>[];
    
    for (final permission in requiredPermissions) {
      try {
        final status = await permission.status;
        final granted = status.isGranted;
        permissionStatus[permission.toString()] = granted;
        if (!granted) {
          missingPermissions.add(permission.toString());
        }
      } catch (e) {
        // Permission not applicable on this platform
        permissionStatus[permission.toString()] = false;
      }
    }
    
    return {
      'permissionStatus': permissionStatus,
      'missingPermissions': missingPermissions,
      'allGranted': missingPermissions.isEmpty,
    };
  }
  
  /// Check available storage using platform-backed methods
  Future<Map<String, dynamic>> _checkStorage() async {
    try {
      final storageStatus = await AirLinkPlugin.getStorageStatus();
      final availableBytes = storageStatus['availableBytes'] as int? ?? 0;
      final totalBytes = storageStatus['totalBytes'] as int? ?? 0;
      final availableMB = availableBytes / (1024 * 1024);
      final availableGB = availableBytes / (1024 * 1024 * 1024);
      final totalMB = totalBytes / (1024 * 1024);
      final totalGB = totalBytes / (1024 * 1024 * 1024);
      
      return {
        'availableBytes': availableBytes,
        'availableMB': availableMB,
        'availableGB': availableGB,
        'totalBytes': totalBytes,
        'totalMB': totalMB,
        'totalGB': totalGB,
        'usedPercentage': totalBytes > 0 ? ((totalBytes - availableBytes) / totalBytes * 100) : 0,
        'sufficient': availableGB >= 0.1, // At least 100 MB
      };
    } catch (e) {
      _logger.warning('ConsolidatedAuditOrchestrator', 'Storage check failed: $e');
      return {
        'availableBytes': 0,
        'availableMB': 0,
        'availableGB': 0,
        'totalBytes': 0,
        'totalMB': 0,
        'totalGB': 0,
        'usedPercentage': 0,
        'sufficient': false,
        'error': e.toString(),
      };
    }
  }

  /// Phase 2: Run automated tests
  Future<List<AuditResult>> _runAutomatedTests() async {
    final results = <AuditResult>[];

    // Define test cases
    final testCases = [
      AuditTestCase(
        id: 'core_transfer_001',
        name: 'Core Transfer Test',
        testType: AuditTestType.coreTransfer,
        senderPlatform: 'android',
        receiverPlatform: 'ios',
        fileType: 'image',
        fileSize: 10485760, // 10 MB
        connectionMethod: 'wifi_aware',
      ),
      AuditTestCase(
        id: 'simultaneous_transfer_001',
        name: 'Simultaneous Transfer Test',
        testType: AuditTestType.simultaneousTransfer,
        senderPlatform: 'android',
        receiverPlatform: 'ios',
        fileType: 'document',
        fileSize: 5242880, // 5 MB
        connectionMethod: 'wifi_aware',
      ),
      AuditTestCase(
        id: 'multi_receiver_001',
        name: 'Multi-Receiver Test',
        testType: AuditTestType.multiReceiver,
        senderPlatform: 'android',
        receiverPlatform: 'multiple',
        fileType: 'video',
        fileSize: 52428800, // 50 MB
        connectionMethod: 'wifi_aware',
      ),
      AuditTestCase(
        id: 'qr_pairing_001',
        name: 'QR Pairing Test',
        testType: AuditTestType.qrPairing,
        senderPlatform: 'android',
        receiverPlatform: 'ios',
        fileType: 'image',
        fileSize: 1048576, // 1 MB
        connectionMethod: 'qr_wifi_aware',
      ),
      AuditTestCase(
        id: 'error_scenario_001',
        name: 'Error Scenario Test',
        testType: AuditTestType.errorScenario,
        senderPlatform: 'android',
        receiverPlatform: 'ios',
        fileType: 'document',
        fileSize: 10485760, // 10 MB
        connectionMethod: 'wifi_aware',
      ),
    ];

    // Run each test case
    for (var i = 0; i < testCases.length; i++) {
      final testCase = testCases[i];
      _emitProgress(
        AuditPhase.automatedTests,
        ((i / testCases.length) * 100).toInt(),
        'Running: ${testCase.name}',
      );

      try {
        final result = await _auditService.runTestCase(testCase);
        results.add(result);
      } catch (e) {
        _logger.error('ConsolidatedAuditOrchestrator',
            'Test case ${testCase.id} failed: $e');
        // Add failed result
        results.add(AuditResult(
          testCase: testCase,
          startTime: DateTime.now(),
          status: AuditStatus.failed,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Phase 3: Coordinate manual tests
  Future<ManualTestResults> _coordinateManualTests() async {
    final results = <ManualTestResult>[];

    // Define manual test scenarios
    final manualTests = [
      {
        'id': 'manual_device_discovery_001',
        'name': 'Device Discovery Test',
        'category': 'discovery',
        'instructions':
            'Verify all devices appear in discovery list within 10 seconds',
      },
      {
        'id': 'manual_cross_platform_001',
        'name': 'Cross-Platform Transfer Test',
        'category': 'transfer',
        'instructions':
            'Transfer files between Android and iOS devices in both directions',
      },
      {
        'id': 'manual_simultaneous_001',
        'name': 'Simultaneous Send+Receive Test',
        'category': 'transfer',
        'instructions':
            'Perform simultaneous send and receive operations on same device',
      },
      {
        'id': 'manual_multi_receiver_001',
        'name': 'Multi-Receiver Send Test',
        'category': 'transfer',
        'instructions': 'Send same file to 1, 3, and 5 receivers simultaneously',
      },
      {
        'id': 'manual_qr_pairing_001',
        'name': 'QR Pairing Test',
        'category': 'pairing',
        'instructions': 'Generate QR code, scan, and verify connection',
      },
      {
        'id': 'manual_large_file_001',
        'name': 'Large File Transfer Test',
        'category': 'transfer',
        'instructions': 'Transfer 200 MB file and verify checksum',
      },
      {
        'id': 'manual_error_handling_001',
        'name': 'Error Handling Test',
        'category': 'error_handling',
        'instructions':
            'Test disconnect, storage full, and permission denied scenarios',
      },
    ];

    // Prompt user for each manual test
    for (final test in manualTests) {
      _emitProgress(
        AuditPhase.manualTests,
        ((results.length / manualTests.length) * 100).toInt(),
        'Manual test: ${test['name']}',
      );

      // In a real implementation, this would show a UI prompt
      // For now, we'll create a placeholder result
      _logger.info('ConsolidatedAuditOrchestrator',
          'Manual test required: ${test['name']} - ${test['instructions']}');

      // Placeholder: In real implementation, wait for user input
      // For now, mark as skipped
      results.add(ManualTestResult(
        testId: test['id'] as String,
        testName: test['name'] as String,
        category: test['category'] as String,
        status: TestStatus.skipped,
        notes: 'Manual test - requires user interaction',
        evidence: [],
        metrics: {},
        timestamp: DateTime.now(),
      ));
    }

    return ManualTestResults(
      results: results,
      deviceInfo: {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      },
      testEnvironment: {
        'network': 'WiFi',
        'bluetooth': 'enabled',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Phase 4: Collect evidence
  Future<List<EvidenceItem>> _collectEvidence(String outputDirectory) async {
    final evidence = <EvidenceItem>[];

    try {
      // Ensure output directory exists
      final outputDir = Directory(outputDirectory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      // Create evidence subdirectories
      final screenshotsDir = Directory('$outputDirectory/screenshots');
      final logsDir = Directory('$outputDirectory/logs');
      final checksumsDir = Directory('$outputDirectory/checksums');
      
      await screenshotsDir.create(recursive: true);
      await logsDir.create(recursive: true);
      await checksumsDir.create(recursive: true);

      // Collect screenshots (platform-specific)
      _emitProgress(AuditPhase.evidenceCollection, 20, 'Capturing screenshots...');
      final screenshots = await _captureScreenshots(screenshotsDir.path);
      evidence.addAll(screenshots);

      // Export native audit logs
      _emitProgress(AuditPhase.evidenceCollection, 40, 'Exporting audit logs...');
      final auditLogs = await _exportNativeAuditLogs(logsDir.path);
      evidence.addAll(auditLogs);

      // Collect device logs
      _emitProgress(AuditPhase.evidenceCollection, 60, 'Collecting device logs...');
      final deviceLogs = await _collectDeviceLogs(logsDir.path);
      evidence.addAll(deviceLogs);

      // Calculate checksums for test files
      _emitProgress(AuditPhase.evidenceCollection, 80, 'Calculating checksums...');
      final checksums = await _calculateChecksums(checksumsDir.path);
      evidence.addAll(checksums);

      _logger.info('ConsolidatedAuditOrchestrator',
          'Evidence collection completed: ${evidence.length} items');
    } catch (e) {
      _logger.error(
          'ConsolidatedAuditOrchestrator', 'Evidence collection failed: $e');
    }

    return evidence;
  }
  
  /// Capture screenshots using platform-specific implementation
  Future<List<EvidenceItem>> _captureScreenshots(String outputPath) async {
    final items = <EvidenceItem>[];
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Capture multiple screenshots during audit
      final screenshotNames = [
        'audit_start',
        'device_list',
        'transfer_progress',
        'audit_complete',
      ];
      
      for (final name in screenshotNames) {
        try {
          final screenshotPath = '$outputPath/${name}_$timestamp.png';
          final captured = await AirLinkPlugin.captureScreenshot(screenshotPath).timeout(
            const Duration(seconds: 5),
            onTimeout: () => false,
          );
          
          if (captured && await File(screenshotPath).exists()) {
            items.add(EvidenceItem(
              type: 'screenshot',
              path: screenshotPath,
              description: 'Screenshot: $name',
              timestamp: DateTime.now(),
            ));
            _logger.info('ConsolidatedAuditOrchestrator', 'Screenshot captured: $name');
          }
          
          // Small delay between screenshots
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _logger.warning('ConsolidatedAuditOrchestrator', 'Failed to capture screenshot $name: $e');
        }
      }
      
      if (items.isEmpty) {
        _logger.warning('ConsolidatedAuditOrchestrator', 'No screenshots captured');
      }
    } catch (e) {
      _logger.error('ConsolidatedAuditOrchestrator', 'Screenshot capture failed: $e');
    }
    
    return items;
  }
  
  /// Export native audit logs
  Future<List<EvidenceItem>> _exportNativeAuditLogs(String outputPath) async {
    final items = <EvidenceItem>[];
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final logPath = '$outputPath/native_audit_logs_$timestamp.json';
      
      // Export logs via platform channel
      final exported = await AirLinkPlugin.exportAuditLogs(logPath);
      
      if (exported) {
        final logFile = File(logPath);
        if (await logFile.exists()) {
          items.add(EvidenceItem(
            type: 'native_audit_log',
            path: logPath,
            description: 'Native audit logs from platform',
            timestamp: DateTime.now(),
          ));
          _logger.info('ConsolidatedAuditOrchestrator', 'Native audit logs exported');
        }
      } else {
        _logger.warning('ConsolidatedAuditOrchestrator', 'Native audit log export returned false');
      }
    } catch (e) {
      _logger.error('ConsolidatedAuditOrchestrator', 'Native audit log export failed: $e');
    }
    
    return items;
  }
  
  /// Collect device logs using platform-specific export
  Future<List<EvidenceItem>> _collectDeviceLogs(String outputPath) async {
    final items = <EvidenceItem>[];
    
    try {
      // Export device logs via platform channel
      final exportedPaths = await AirLinkPlugin.exportDeviceLogs(outputPath).timeout(
        const Duration(seconds: 30),
        onTimeout: () => <String>[],
      );
      
      for (final logPath in exportedPaths) {
        final logFile = File(logPath);
        if (await logFile.exists()) {
          final platform = Platform.isAndroid ? 'android' : 'ios';
          items.add(EvidenceItem(
            type: 'device_log',
            path: logPath,
            description: 'Device logs ($platform)',
            timestamp: DateTime.now(),
          ));
          _logger.info('ConsolidatedAuditOrchestrator', 'Device log exported: $logPath');
        }
      }
      
      if (items.isEmpty) {
        _logger.warning('ConsolidatedAuditOrchestrator', 'No device logs exported');
      }
    } catch (e) {
      _logger.error('ConsolidatedAuditOrchestrator', 'Device log collection failed: $e');
    }
    
    return items;
  }
  
  /// Calculate checksums for transferred files
  Future<List<EvidenceItem>> _calculateChecksums(String outputPath) async {
    final items = <EvidenceItem>[];
    
    try {
      final checksumFile = File('$outputPath/checksums.json');
      
      // Get list of transferred files from platform
      final transferredFiles = await AirLinkPlugin.listTransferredFiles().timeout(
        const Duration(seconds: 10),
        onTimeout: () => <Map<String, dynamic>>[],
      );
      
      final checksumResults = <Map<String, dynamic>>[];
      
      // Calculate SHA-256 for each transferred file
      for (final fileInfo in transferredFiles) {
        try {
          final transferId = fileInfo['transferId'] as String?;
          final filePath = fileInfo['filePath'] as String?;
          
          if (filePath == null || !await File(filePath).exists()) {
            continue;
          }
          
          _logger.debug('ConsolidatedAuditOrchestrator', 'Calculating checksum for: $filePath');
          
          final checksum = await _checksumService.calculateChecksumChunked(filePath).timeout(
            const Duration(minutes: 5),
          );
          
          checksumResults.add({
            'transferId': transferId,
            'filePath': filePath,
            'fileName': filePath.split('/').last,
            'checksum': checksum,
            'algorithm': 'SHA-256',
            'calculatedAt': DateTime.now().toIso8601String(),
          });
          
          _logger.info('ConsolidatedAuditOrchestrator', 'Checksum calculated for ${filePath.split('/').last}');
        } catch (e) {
          _logger.warning('ConsolidatedAuditOrchestrator', 'Failed to calculate checksum: $e');
        }
      }
      
      // Write checksums to JSON file
      final checksumData = {
        'timestamp': DateTime.now().toIso8601String(),
        'totalFiles': checksumResults.length,
        'algorithm': 'SHA-256',
        'files': checksumResults,
      };
      
      await checksumFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(checksumData),
      );
      
      items.add(EvidenceItem(
        type: 'checksum',
        path: checksumFile.path,
        description: 'SHA-256 checksums for ${checksumResults.length} files',
        timestamp: DateTime.now(),
      ));
      
      _logger.info('ConsolidatedAuditOrchestrator', 'Checksum file saved with ${checksumResults.length} entries');
    } catch (e) {
      _logger.error('ConsolidatedAuditOrchestrator', 'Checksum calculation failed: $e');
    }
    
    return items;
  }

  /// Phase 5: Generate consolidated report
  Future<Map<String, String>> _generateConsolidatedReport(
    ConsolidatedAuditResult result,
    String outputDirectory,
  ) async {
    final reportPaths = <String, String>{};

    try {
      // Generate report using AuditService
      final auditReport = await _auditService.generateReport(
        result.automatedResults ?? [],
      );

      // Export in multiple formats
      final formats = [
        AuditReportFormat.json,
        AuditReportFormat.markdown,
        AuditReportFormat.html,
      ];

      for (final format in formats) {
        _emitProgress(
          AuditPhase.reportGeneration,
          ((formats.indexOf(format) / formats.length) * 100).toInt(),
          'Generating ${format.name} report...',
        );

        final reportContent =
            await _auditService.exportReport(auditReport, format);
        final fileName =
            'consolidated_audit_report_${DateTime.now().millisecondsSinceEpoch}.${format.name}';
        final filePath = '$outputDirectory/$fileName';

        final file = File(filePath);
        await file.writeAsString(reportContent);

        reportPaths[format.name] = filePath;
        _logger.info('ConsolidatedAuditOrchestrator',
            'Generated ${format.name} report: $filePath');
      }
    } catch (e) {
      _logger.error(
          'ConsolidatedAuditOrchestrator', 'Report generation failed: $e');
    }

    return reportPaths;
  }

  /// Emit progress event
  void _emitProgress(AuditPhase phase, int percentage, String message) {
    if (!_progressController.isClosed) {
      _progressController.add(AuditProgress(
        phase: phase,
        percentage: percentage,
        message: message,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}

/// Audit phase enum
enum AuditPhase {
  environmentValidation,
  automatedTests,
  manualTests,
  evidenceCollection,
  reportGeneration,
}

/// Audit progress event
class AuditProgress {
  final AuditPhase phase;
  final int percentage;
  final String message;
  final DateTime timestamp;

  AuditProgress({
    required this.phase,
    required this.percentage,
    required this.message,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AuditProgress(phase: ${phase.name}, percentage: $percentage%, message: $message)';
  }
}

/// Environment validation result
class EnvironmentValidation {
  bool isValid = false;
  final List<String> errors = [];
  final Map<String, dynamic> details = {};
}

/// Evidence item
class EvidenceItem {
  final String type;
  final String path;
  final String description;
  final DateTime timestamp;

  EvidenceItem({
    required this.type,
    required this.path,
    required this.description,
    required this.timestamp,
  });
}

/// Consolidated audit result
class ConsolidatedAuditResult {
  final DateTime startTime;
  DateTime? endTime;
  final String outputDirectory;
  bool success = false;
  String? error;

  EnvironmentValidation? environmentValidation;
  List<AuditResult>? automatedResults;
  ManualTestResults? manualResults;
  List<EvidenceItem>? evidence;
  Map<String, String>? reportPaths;

  ConsolidatedAuditResult({
    required this.startTime,
    required this.outputDirectory,
  });

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  @override
  String toString() {
    return 'ConsolidatedAuditResult(success: $success, duration: ${duration.inSeconds}s, automatedTests: ${automatedResults?.length ?? 0}, manualTests: ${manualResults?.results.length ?? 0})';
  }
}
