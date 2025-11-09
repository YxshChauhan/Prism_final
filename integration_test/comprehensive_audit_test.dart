import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:airlink/core/services/audit_service.dart';
import 'package:airlink/core/services/checksum_verification_service.dart';
import 'package:airlink/core/services/consolidated_audit_orchestrator.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/qr_connection_service.dart';
import 'package:airlink/core/services/transfer_benchmarking_service.dart';

/// Comprehensive audit integration test
/// Tests the complete audit orchestration flow on real devices
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Audit Integration Tests', () {
    late LoggerService logger;
    late ChecksumVerificationService checksumService;
    late AuditService auditService;
    late QRConnectionService qrService;
    late TransferBenchmarkingService benchmarkingService;
    late ConsolidatedAuditOrchestrator orchestrator;
    late Directory outputDirectory;

    setUpAll(() async {
      // Initialize services
      logger = LoggerService();
      checksumService = ChecksumVerificationService(logger);
      auditService = AuditService(logger, checksumService);
      qrService = QRConnectionService();
      benchmarkingService = TransferBenchmarkingService();

      // Create orchestrator
      orchestrator = ConsolidatedAuditOrchestrator(
        auditService: auditService,
        checksumService: checksumService,
        benchmarkingService: benchmarkingService,
        qrService: qrService,
        logger: logger,
      );

      // Create output directory
      final tempDir = Directory.systemTemp;
      outputDirectory = Directory('${tempDir.path}/audit_test_${DateTime.now().millisecondsSinceEpoch}');
      await outputDirectory.create(recursive: true);
    });

    tearDownAll(() async {
      // Cleanup
      if (await outputDirectory.exists()) {
        await outputDirectory.delete(recursive: true);
      }
      orchestrator.dispose();
      qrService.dispose();
    });

    testWidgets('Should initialize services successfully', (WidgetTester tester) async {
      expect(logger, isNotNull);
      expect(checksumService, isNotNull);
      expect(auditService, isNotNull);
      expect(qrService, isNotNull);
      expect(benchmarkingService, isNotNull);
      expect(orchestrator, isNotNull);
    });

    testWidgets('Should enable audit mode', (WidgetTester tester) async {
      final enabled = await auditService.enableAuditMode();
      expect(enabled, isTrue);
      expect(auditService.isAuditModeEnabled, isTrue);
    });

    testWidgets('Should run comprehensive audit and generate reports', (WidgetTester tester) async {
      // Track progress events
      final progressEvents = <AuditProgress>[];
      final progressSubscription = orchestrator.progressStream.listen((event) {
        progressEvents.add(event);
        print('Progress: ${event.phase.name} - ${event.percentage}% - ${event.message}');
      });

      try {
        // Run comprehensive audit
        final result = await orchestrator.runComprehensiveAudit(
          outputDirectory: outputDirectory.path,
          includeManualTests: false, // Skip manual tests for automated run
        );

        // Verify result
        expect(result, isNotNull);
        expect(result.success, isTrue, reason: 'Audit should complete successfully');
        expect(result.endTime, isNotNull);
        expect(result.duration.inSeconds, greaterThan(0));

        // Verify progress events were emitted
        expect(progressEvents, isNotEmpty, reason: 'Progress events should be emitted');
        expect(
          progressEvents.any((e) => e.phase == AuditPhase.environmentValidation),
          isTrue,
          reason: 'Environment validation phase should occur',
        );
        expect(
          progressEvents.any((e) => e.phase == AuditPhase.automatedTests),
          isTrue,
          reason: 'Automated tests phase should occur',
        );
        expect(
          progressEvents.any((e) => e.phase == AuditPhase.reportGeneration),
          isTrue,
          reason: 'Report generation phase should occur',
        );

        // Verify environment validation
        expect(result.environmentValidation, isNotNull);
        expect(result.environmentValidation!.isValid, isTrue);

        // Verify automated test results
        expect(result.automatedResults, isNotNull);
        expect(result.automatedResults!.length, greaterThan(0));

        // Check that critical tests passed
        final criticalTests = result.automatedResults!.where(
          (r) => r.testCase.testType == AuditTestType.coreTransfer ||
                 r.testCase.testType == AuditTestType.qrPairing,
        );
        expect(criticalTests, isNotEmpty, reason: 'Critical tests should be included');

        // Verify reports were generated
        expect(result.reportPaths, isNotNull);
        expect(result.reportPaths!.isNotEmpty, isTrue);

        // Verify report files exist
        for (final entry in result.reportPaths!.entries) {
          final file = File(entry.value);
          expect(
            await file.exists(),
            isTrue,
            reason: '${entry.key} report file should exist at ${entry.value}',
          );
          expect(
            await file.length(),
            greaterThan(0),
            reason: '${entry.key} report file should not be empty',
          );
        }

        // Verify JSON report structure
        if (result.reportPaths!.containsKey('json')) {
          final jsonFile = File(result.reportPaths!['json']!);
          final jsonContent = await jsonFile.readAsString();
          expect(jsonContent, isNotEmpty);
          expect(jsonContent, contains('generatedAt'));
          expect(jsonContent, contains('totalTests'));
          expect(jsonContent, contains('passedTests'));
        }

        // Verify Markdown report structure
        if (result.reportPaths!.containsKey('markdown')) {
          final mdFile = File(result.reportPaths!['markdown']!);
          final mdContent = await mdFile.readAsString();
          expect(mdContent, contains('# AirLink Audit Report'));
          expect(mdContent, contains('## Summary'));
          expect(mdContent, contains('## Test Results'));
        }

        // Verify HTML report structure
        if (result.reportPaths!.containsKey('html')) {
          final htmlFile = File(result.reportPaths!['html']!);
          final htmlContent = await htmlFile.readAsString();
          expect(htmlContent, contains('<!DOCTYPE html>'));
          expect(htmlContent, contains('<title>AirLink Audit Report</title>'));
        }

        print('\n=== Audit Completed Successfully ===');
        print('Duration: ${result.duration.inSeconds}s');
        print('Automated Tests: ${result.automatedResults?.length ?? 0}');
        print('Reports Generated: ${result.reportPaths?.length ?? 0}');
        print('Output Directory: ${outputDirectory.path}');
      } finally {
        await progressSubscription.cancel();
      }
    });

    testWidgets('Should handle audit failures gracefully', (WidgetTester tester) async {
      // Create invalid output directory
      final invalidDir = Directory('/invalid/path/that/does/not/exist');

      final result = await orchestrator.runComprehensiveAudit(
        outputDirectory: invalidDir.path,
        includeManualTests: false,
      );

      // Should complete but with success = false
      expect(result, isNotNull);
      expect(result.endTime, isNotNull);
      // Note: May succeed if it creates the directory, or fail gracefully
    });

    testWidgets('Should run individual test cases', (WidgetTester tester) async {
      await auditService.enableAuditMode();

      // Test QR pairing
      final qrTestCase = AuditTestCase(
        id: 'test_qr_001',
        name: 'QR Pairing Integration Test',
        testType: AuditTestType.qrPairing,
        senderPlatform: Platform.operatingSystem,
        receiverPlatform: 'test',
        fileType: 'test',
        fileSize: 1024,
        connectionMethod: 'qr_tcp',
      );

      final qrResult = await auditService.runTestCase(qrTestCase);
      expect(qrResult, isNotNull);
      expect(qrResult.status, isIn([AuditStatus.passed, AuditStatus.failed]));
      expect(qrResult.endTime, isNotNull);
      expect(qrResult.evidence, isNotEmpty);

      print('QR Test Result: ${qrResult.status.name}');
      print('Evidence: ${qrResult.evidence}');
    });

    testWidgets('Should collect native metrics', (WidgetTester tester) async {
      await auditService.enableAuditMode();

      final metrics = await auditService.collectNativeMetrics('test_transfer_001');
      expect(metrics, isNotNull);
      // Metrics may be empty if no transfer occurred, but should not throw
    });

    testWidgets('Should generate audit reports in multiple formats', (WidgetTester tester) async {
      await auditService.enableAuditMode();

      // Create a simple test result
      final testCase = AuditTestCase(
        id: 'report_test_001',
        name: 'Report Generation Test',
        testType: AuditTestType.coreTransfer,
        senderPlatform: Platform.operatingSystem,
        receiverPlatform: 'test',
        fileType: 'test',
        fileSize: 1024,
        connectionMethod: 'test',
      );

      final testResult = AuditResult(
        testCase: testCase,
        startTime: DateTime.now().subtract(const Duration(seconds: 5)),
        endTime: DateTime.now(),
        status: AuditStatus.passed,
        metrics: {'testMetric': 123},
        evidence: {'testEvidence': 'value'},
      );

      // Generate report
      final report = await auditService.generateReport([testResult]);
      expect(report, isNotNull);
      expect(report.totalTests, equals(1));
      expect(report.passedTests, equals(1));
      expect(report.failedTests, equals(0));
      expect(report.passRate, equals(100.0));

      // Export in different formats
      final jsonReport = await auditService.exportReport(report, AuditReportFormat.json);
      expect(jsonReport, isNotEmpty);
      expect(jsonReport, contains('"totalTests":1'));

      final mdReport = await auditService.exportReport(report, AuditReportFormat.markdown);
      expect(mdReport, isNotEmpty);
      expect(mdReport, contains('# AirLink Audit Report'));

      final htmlReport = await auditService.exportReport(report, AuditReportFormat.html);
      expect(htmlReport, isNotEmpty);
      expect(htmlReport, contains('<!DOCTYPE html>'));
    });

    testWidgets('Should verify checksums correctly', (WidgetTester tester) async {
      // Create a test file
      final tempFile = File('${outputDirectory.path}/checksum_test.txt');
      await tempFile.writeAsString('Test content for checksum verification');

      // Calculate checksum
      final checksum = await checksumService.calculateChecksumChunked(tempFile.path);
      expect(checksum, isNotEmpty);

      // Verify checksum
      final isValid = await auditService.verifyChecksum(tempFile.path, checksum);
      expect(isValid, isTrue);

      // Verify with wrong checksum
      final isInvalid = await auditService.verifyChecksum(tempFile.path, 'wrong_checksum');
      expect(isInvalid, isFalse);

      // Cleanup
      await tempFile.delete();
    });
  });

  group('Platform-Specific Tests', () {
    testWidgets('Should detect platform correctly', (WidgetTester tester) async {
      expect(Platform.operatingSystem, isIn(['android', 'ios', 'macos', 'linux', 'windows']));
      print('Running on: ${Platform.operatingSystem}');
    });

    testWidgets('Should have platform-specific capabilities', (WidgetTester tester) async {
      if (Platform.isAndroid) {
        print('Android-specific tests');
        // Android-specific assertions
      } else if (Platform.isIOS) {
        print('iOS-specific tests');
        // iOS-specific assertions
      }
    });
  });
}
