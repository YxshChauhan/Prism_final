/// Data model for manual test results
/// Used by ConsolidatedAuditOrchestrator to store manual test results
/// and by generate_audit_report.dart to merge with automated results

/// Test status enum
enum TestStatus {
  pass,
  fail,
  skipped,
}

/// Represents result of a single manual test
class ManualTestResult {
  final String testId;
  final String testName;
  final String category;
  final TestStatus status;
  final String? notes;
  final List<String> evidence;
  final Map<String, dynamic> metrics;
  final DateTime timestamp;

  const ManualTestResult({
    required this.testId,
    required this.testName,
    required this.category,
    required this.status,
    this.notes,
    required this.evidence,
    required this.metrics,
    required this.timestamp,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'testName': testName,
      'category': category,
      'status': status.name,
      'notes': notes,
      'evidence': evidence,
      'metrics': metrics,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Parse from JSON
  factory ManualTestResult.fromJson(Map<String, dynamic> json) {
    return ManualTestResult(
      testId: json['testId'] as String,
      testName: json['testName'] as String,
      category: json['category'] as String,
      status: TestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TestStatus.skipped,
      ),
      notes: json['notes'] as String?,
      evidence: (json['evidence'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      metrics: (json['metrics'] as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'ManualTestResult(testId: $testId, testName: $testName, status: ${status.name})';
  }
}

/// Collection of manual test results
class ManualTestResults {
  final List<ManualTestResult> results;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> testEnvironment;
  final DateTime timestamp;

  const ManualTestResults({
    required this.results,
    required this.deviceInfo,
    required this.testEnvironment,
    required this.timestamp,
  });

  /// Get passed tests
  List<ManualTestResult> getPassedTests() {
    return results.where((r) => r.status == TestStatus.pass).toList();
  }

  /// Get failed tests
  List<ManualTestResult> getFailedTests() {
    return results.where((r) => r.status == TestStatus.fail).toList();
  }

  /// Get tests by category
  Map<String, List<ManualTestResult>> getTestsByCategory() {
    final Map<String, List<ManualTestResult>> grouped = {};
    for (final result in results) {
      grouped.putIfAbsent(result.category, () => []).add(result);
    }
    return grouped;
  }

  /// Calculate overall pass rate
  double calculatePassRate() {
    if (results.isEmpty) return 0.0;
    final passed = results.where((r) => r.status == TestStatus.pass).length;
    return (passed / results.length) * 100;
  }

  /// Validate data integrity
  bool validate() {
    // Check for unique test IDs
    final testIds = results.map((r) => r.testId).toSet();
    if (testIds.length != results.length) {
      return false;
    }

    // Validate evidence file paths exist (basic check)
    for (final result in results) {
      for (final evidencePath in result.evidence) {
        if (evidencePath.isEmpty) {
          return false;
        }
      }
    }

    // Validate metrics have required fields
    for (final result in results) {
      if (result.metrics.isEmpty && result.status == TestStatus.pass) {
        // Passed tests should have some metrics
        return false;
      }
    }

    return true;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'deviceInfo': deviceInfo,
      'testEnvironment': testEnvironment,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Parse from JSON
  factory ManualTestResults.fromJson(Map<String, dynamic> json) {
    return ManualTestResults(
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => ManualTestResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      deviceInfo: (json['deviceInfo'] as Map<String, dynamic>?) ?? {},
      testEnvironment:
          (json['testEnvironment'] as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() {
    return 'ManualTestResults(total: ${results.length}, passed: ${getPassedTests().length}, failed: ${getFailedTests().length}, passRate: ${calculatePassRate().toStringAsFixed(1)}%)';
  }
}
