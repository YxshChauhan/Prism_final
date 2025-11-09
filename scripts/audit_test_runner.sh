#!/bin/bash

# AirLink Audit Test Runner
# Automated device testing script for comprehensive audit validation

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/audit_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$RESULTS_DIR/audit_test_$TIMESTAMP.log"

# CLI Flags
COMPREHENSIVE=false
AUTOMATED_ONLY=false
CHECK_DEVICES=false
SHOW_STATUS=false
INCLUDE_MANUAL=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse CLI arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --comprehensive)
                COMPREHENSIVE=true
                INCLUDE_MANUAL=true
                shift
                ;;
            --automated)
                AUTOMATED_ONLY=true
                shift
                ;;
            --check-devices)
                CHECK_DEVICES=true
                shift
                ;;
            --status)
                SHOW_STATUS=true
                shift
                ;;
            --manual)
                INCLUDE_MANUAL=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --comprehensive     Run comprehensive audit (automated + manual tests)
    --automated         Run only automated tests (default)
    --manual            Include manual test prompts
    --check-devices     Check connected devices and exit
    --status            Show audit status and exit
    -h, --help          Show this help message

Examples:
    $0 --comprehensive              # Full audit with manual tests
    $0 --automated                  # Automated tests only
    $0 --check-devices              # Check device connectivity
    $0 --status                     # Show previous audit status

EOF
}

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check device status
check_device_status() {
    log "Checking connected devices..."
    
    local android_count=0
    local ios_count=0
    
    if command -v adb &> /dev/null; then
        android_count=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
        echo -e "${GREEN}Android Devices:${NC} $android_count"
        if [ "$android_count" -gt 0 ]; then
            adb devices | grep -v "List of devices" | grep "device$"
        fi
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]] && command -v idevice_id &> /dev/null; then
        ios_count=$(idevice_id -l 2>/dev/null | wc -l)
        echo -e "${GREEN}iOS Devices:${NC} $ios_count"
        if [ "$ios_count" -gt 0 ]; then
            idevice_id -l 2>/dev/null
        fi
    fi
    
    if [ "$android_count" -eq 0 ] && [ "$ios_count" -eq 0 ]; then
        log_warning "No devices connected"
        return 1
    fi
    
    return 0
}

# Show audit status
show_audit_status() {
    log "Checking audit status..."
    
    if [ ! -d "$RESULTS_DIR" ]; then
        log_warning "No audit results found"
        return 1
    fi
    
    echo -e "\n${BLUE}Recent Audit Runs:${NC}"
    ls -lt "$RESULTS_DIR" | grep "audit_test_" | head -n 5
    
    local latest_log=$(ls -t "$RESULTS_DIR"/audit_test_*.log 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ]; then
        echo -e "\n${BLUE}Latest Audit Log:${NC}"
        tail -n 20 "$latest_log"
    fi
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check Android SDK
    if [ -z "$ANDROID_HOME" ]; then
        log_warning "ANDROID_HOME not set, Android tests may fail"
    fi
    
    # Check iOS development tools (macOS only)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v xcodebuild &> /dev/null; then
            log_warning "Xcode command line tools not found, iOS tests may fail"
        fi
    fi
    
    # Check project structure
    if [ ! -f "$PROJECT_ROOT/pubspec.yaml" ]; then
        log_error "Not a Flutter project (pubspec.yaml not found)"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Run Flutter tests
run_flutter_tests() {
    log "Running Flutter unit and integration tests..."
    
    cd "$PROJECT_ROOT"
    
    # Run unit tests
    log "Running unit tests..."
    if flutter test test/unit/ --coverage --reporter=json > "$RESULTS_DIR/unit_test_results_$TIMESTAMP.json" 2>&1; then
        log_success "Unit tests completed"
    else
        log_error "Unit tests failed"
        return 1
    fi
    
    # Run integration tests
    log "Running integration tests..."
    if flutter test test/integration/ --reporter=json > "$RESULTS_DIR/integration_test_results_$TIMESTAMP.json" 2>&1; then
        log_success "Integration tests completed"
    else
        log_error "Integration tests failed"
        return 1
    fi
    
    # Generate coverage report
    if command -v genhtml &> /dev/null; then
        log "Generating coverage report..."
        genhtml coverage/lcov.info -o "$RESULTS_DIR/coverage_$TIMESTAMP" 2>&1 | tee -a "$LOG_FILE"
        log_success "Coverage report generated at $RESULTS_DIR/coverage_$TIMESTAMP"
    else
        log_warning "genhtml not found, skipping coverage report generation"
    fi
}

# Run Android device tests
run_android_tests() {
    log "Running Android device tests..."
    
    # Check for connected Android devices
    if ! command -v adb &> /dev/null; then
        log_warning "ADB not found, skipping Android device tests"
        return 0
    fi
    
    local devices=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
    if [ "$devices" -eq 0 ]; then
        log_warning "No Android devices connected, skipping Android device tests"
        return 0
    fi
    
    log "Found $devices Android device(s), running tests..."
    
    cd "$PROJECT_ROOT"
    
    # Build and install debug APK
    log "Building Android debug APK..."
    if flutter build apk --debug 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Android APK built successfully"
    else
        log_error "Failed to build Android APK"
        return 1
    fi
    
    # Run integration tests on device
    log "Running integration tests on Android device..."
    if flutter test integration_test/ -d android 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Android integration tests completed"
    else
        log_error "Android integration tests failed"
        return 1
    fi
}

# Run iOS device tests (macOS only)
run_ios_tests() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "iOS tests can only run on macOS, skipping..."
        return 0
    fi
    
    log "Running iOS device tests..."
    
    # Check for connected iOS devices
    if ! command -v ios-deploy &> /dev/null; then
        log_warning "ios-deploy not found, skipping iOS device tests"
        return 0
    fi
    
    local devices=$(ios-deploy -c 2>/dev/null | wc -l)
    if [ "$devices" -eq 0 ]; then
        log_warning "No iOS devices connected, skipping iOS device tests"
        return 0
    fi
    
    log "Found $devices iOS device(s), running tests..."
    
    cd "$PROJECT_ROOT"
    
    # Build iOS app
    log "Building iOS app..."
    if flutter build ios --debug --no-codesign 2>&1 | tee -a "$LOG_FILE"; then
        log_success "iOS app built successfully"
    else
        log_error "Failed to build iOS app"
        return 1
    fi
    
    # Run integration tests on device
    log "Running integration tests on iOS device..."
    if flutter test integration_test/ -d ios 2>&1 | tee -a "$LOG_FILE"; then
        log_success "iOS integration tests completed"
    else
        log_error "iOS integration tests failed"
        return 1
    fi
}

# Run performance benchmarks
run_performance_tests() {
    log "Running performance benchmarks..."
    
    cd "$PROJECT_ROOT"
    
    # Run benchmark tests
    if flutter test test/integration/cross_platform_benchmarking_test.dart --reporter=json > "$RESULTS_DIR/benchmark_results_$TIMESTAMP.json" 2>&1; then
        log_success "Performance benchmarks completed"
    else
        log_error "Performance benchmarks failed"
        return 1
    fi
}

# Run on-device transfer tests
run_device_transfer_tests() {
    log "Running on-device transfer tests..."
    
    # Check for connected devices
    local android_devices=0
    local ios_devices=0
    
    if command -v adb &> /dev/null; then
        android_devices=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]] && command -v idevice_id &> /dev/null; then
        ios_devices=$(idevice_id -l 2>/dev/null | wc -l)
    fi
    
    if [ "$android_devices" -eq 0 ] && [ "$ios_devices" -eq 0 ]; then
        log_warning "No devices connected, skipping on-device transfer tests"
        return 0
    fi
    
    log "Found $android_devices Android device(s) and $ios_devices iOS device(s)"
    
    # Create device test results directory
    local device_test_dir="$RESULTS_DIR/device_tests_$TIMESTAMP"
    mkdir -p "$device_test_dir"
    
    cd "$PROJECT_ROOT"
    
    # Build and install on Android if devices available
    if [ "$android_devices" -gt 0 ]; then
        log "Building and installing on Android devices..."
        if flutter build apk --debug 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Android APK built"
            
            # Install on all connected Android devices
            adb devices | grep -v "List of devices" | grep "device$" | while read -r device_line; do
                local device_id=$(echo "$device_line" | awk '{print $1}')
                log "Installing on Android device: $device_id"
                adb -s "$device_id" install -r build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tee -a "$LOG_FILE"
            done
        else
            log_error "Failed to build Android APK"
            return 1
        fi
    fi
    
    # Build and install on iOS if devices available (macOS only)
    if [ "$ios_devices" -gt 0 ] && [[ "$OSTYPE" == "darwin"* ]]; then
        log "Building iOS app for device testing..."
        if flutter build ios --debug --no-codesign 2>&1 | tee -a "$LOG_FILE"; then
            log_success "iOS app built"
            
            # Note: Actual installation requires ios-deploy or Xcode
            if command -v ios-deploy &> /dev/null; then
                log "Installing on iOS devices using ios-deploy..."
                ios-deploy --bundle build/ios/iphoneos/Runner.app 2>&1 | tee -a "$LOG_FILE" || log_warning "iOS installation may have failed"
            else
                log_warning "ios-deploy not found, manual installation required"
            fi
        else
            log_error "Failed to build iOS app"
            return 1
        fi
    fi
    
    # Run device integration test harness on Android
    if [ "$android_devices" -gt 0 ]; then
        log "Running audit device test on Android..."
        
        # Get first Android device ID
        local android_device_id=$(adb devices | grep -v "List of devices" | grep "device$" | head -n1 | awk '{print $1}')
        
        # Set environment variables for test
        export AUDIT_DEVICE_ID="$android_device_id"
        export AUDIT_TIMEOUT="300"
        export AUDIT_FILE_SIZE="10"
        export AUDIT_OUTPUT_PATH="/data/data/com.airlink.airlink_4/files/audit_logs.json"
        
        if flutter test integration_test/audit_device_test.dart -d "$android_device_id" --reporter=json > "$device_test_dir/android_device_test_results.json" 2>&1; then
            log_success "Android device integration tests completed"
        else
            log_warning "Android device integration tests failed (check $device_test_dir/android_device_test_results.json)"
        fi
    fi
    
    # Run device integration test harness on iOS
    if [ "$ios_devices" -gt 0 ] && [[ "$OSTYPE" == "darwin"* ]]; then
        log "Running audit device test on iOS..."
        
        # Get first iOS device ID
        local ios_device_id=$(idevice_id -l 2>/dev/null | head -n1)
        
        # Set environment variables for test
        export AUDIT_DEVICE_ID="$ios_device_id"
        export AUDIT_TIMEOUT="300"
        export AUDIT_FILE_SIZE="10"
        export AUDIT_OUTPUT_PATH="Documents/audit_logs.json"
        
        if flutter test integration_test/audit_device_test.dart -d "$ios_device_id" --reporter=json > "$device_test_dir/ios_device_test_results.json" 2>&1; then
            log_success "iOS device integration tests completed"
        else
            log_warning "iOS device integration tests failed (check $device_test_dir/ios_device_test_results.json)"
        fi
    fi
    
    # Export native audit logs from devices
    export_native_audit_logs "$device_test_dir"
    
    log_success "On-device transfer tests completed"
}

# Run manual tests with interactive prompts
run_manual_tests() {
    if [ "$INCLUDE_MANUAL" = false ]; then
        log "Skipping manual tests (use --manual or --comprehensive to include)"
        return 0
    fi
    
    log "Starting manual test phase..."
    
    local manual_results_file="$RESULTS_DIR/manual_test_results.json"
    echo '{"tests": [' > "$manual_results_file"
    local first_test=true
    
    # Manual Test 1: Device Discovery
    echo -e "\n${YELLOW}=== Manual Test 1: Device Discovery ===${NC}"
    echo "Instructions: Open the app on 2 devices and verify both appear in discovery list within 10 seconds"
    read -p "Did all devices appear within 10s? (y/n): " response
    
    if [ "$first_test" = false ]; then echo ',' >> "$manual_results_file"; fi
    first_test=false
    
    cat >> "$manual_results_file" << EOF
    {
      "testId": "manual_device_discovery_001",
      "testName": "Device Discovery Test",
      "category": "discovery",
      "passed": $([ "$response" = "y" ] && echo "true" || echo "false"),
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "notes": "User response: $response"
    }
EOF
    
    # Manual Test 2: Cross-Platform Transfer
    echo -e "\n${YELLOW}=== Manual Test 2: Cross-Platform Transfer ===${NC}"
    echo "Instructions: Transfer a 10MB file from Android to iOS and verify checksum"
    read -p "Did the transfer complete successfully? (y/n): " response
    
    echo ',' >> "$manual_results_file"
    cat >> "$manual_results_file" << EOF
    {
      "testId": "manual_cross_platform_001",
      "testName": "Cross-Platform Transfer Test",
      "category": "transfer",
      "passed": $([ "$response" = "y" ] && echo "true" || echo "false"),
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "notes": "User response: $response"
    }
EOF
    
    # Manual Test 3: QR Pairing
    echo -e "\n${YELLOW}=== Manual Test 3: QR Pairing ===${NC}"
    echo "Instructions: Generate QR code on device 1, scan with device 2, verify connection"
    read -p "Did QR pairing work correctly? (y/n): " response
    
    echo ',' >> "$manual_results_file"
    cat >> "$manual_results_file" << EOF
    {
      "testId": "manual_qr_pairing_001",
      "testName": "QR Pairing Test",
      "category": "pairing",
      "passed": $([ "$response" = "y" ] && echo "true" || echo "false"),
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "notes": "User response: $response"
    }
EOF
    
    # Manual Test 4: Large File Transfer
    echo -e "\n${YELLOW}=== Manual Test 4: Large File Transfer ===${NC}"
    echo "Instructions: Transfer a 200MB file and verify checksum matches"
    read -p "Did the large file transfer succeed? (y/n): " response
    
    echo ',' >> "$manual_results_file"
    cat >> "$manual_results_file" << EOF
    {
      "testId": "manual_large_file_001",
      "testName": "Large File Transfer Test",
      "category": "transfer",
      "passed": $([ "$response" = "y" ] && echo "true" || echo "false"),
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "notes": "User response: $response"
    }
EOF
    
    # Manual Test 5: Error Handling
    echo -e "\n${YELLOW}=== Manual Test 5: Error Handling ===${NC}"
    echo "Instructions: Test disconnect during transfer, verify app handles gracefully"
    read -p "Did error handling work correctly? (y/n): " response
    
    echo ',' >> "$manual_results_file"
    cat >> "$manual_results_file" << EOF
    {
      "testId": "manual_error_handling_001",
      "testName": "Error Handling Test",
      "category": "error_handling",
      "passed": $([ "$response" = "y" ] && echo "true" || echo "false"),
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "notes": "User response: $response"
    }
EOF
    
    echo ']}' >> "$manual_results_file"
    
    log_success "Manual tests completed. Results saved to: $manual_results_file"
}

# Export native audit logs from connected devices
export_native_audit_logs() {
    local output_dir="$1"
    log "Exporting native audit logs from devices..."
    
    mkdir -p "$output_dir/native_logs"
    
    # Export from Android devices
    if command -v adb &> /dev/null; then
        adb devices | grep -v "List of devices" | grep "device$" | while read -r device_line; do
            local device_id=$(echo "$device_line" | awk '{print $1}')
            log "Exporting audit logs from Android device: $device_id"
            
            # Pull audit logs from app's internal storage
            local android_log_dir="$output_dir/native_logs/android_${device_id}"
            mkdir -p "$android_log_dir"
            
            # Try to pull audit log files
            adb -s "$device_id" shell "run-as com.airlink.airlink_4 cat files/audit_logs.json" > "$android_log_dir/audit_logs.json" 2>/dev/null || log_warning "Could not export audit logs from $device_id"
            
            # Pull logcat with audit tags
            adb -s "$device_id" logcat -d -s "AuditLogger:*" > "$android_log_dir/audit_logcat.txt" 2>/dev/null || true
            
            # Pull benchmark database if accessible
            adb -s "$device_id" shell "run-as com.airlink.airlink_4 cat databases/transfer_benchmarks.db" > "$android_log_dir/transfer_benchmarks.db" 2>/dev/null || log_warning "Could not export benchmark DB from $device_id"
            
            log_success "Android audit logs exported from $device_id"
        done
    fi
    
    # Export from iOS devices (macOS only)
    if [[ "$OSTYPE" == "darwin"* ]] && command -v idevice_id &> /dev/null; then
        idevice_id -l 2>/dev/null | while read -r device_id; do
            if [ -n "$device_id" ]; then
                log "Exporting audit logs from iOS device: $device_id"
                
                local ios_log_dir="$output_dir/native_logs/ios_${device_id}"
                mkdir -p "$ios_log_dir"
                
                # Capture system logs with audit filter
                if command -v idevicesyslog &> /dev/null; then
                    timeout 10 idevicesyslog -u "$device_id" | grep -i "audit" > "$ios_log_dir/audit_syslog.txt" 2>/dev/null || true
                fi
                
                log_success "iOS audit logs exported from $device_id"
            fi
        done
    fi
    
    # Collect device logs using existing script
    log "Collecting comprehensive device logs..."
    "$SCRIPT_DIR/collect_device_logs.sh" 2>&1 | tee -a "$LOG_FILE" || log_warning "Device log collection script failed"
    
    log_success "Native audit logs exported to $output_dir/native_logs"
}

# Generate audit report using Dart script
generate_audit_report() {
    log "Generating comprehensive audit report..."
    
    # Create evidence directory
    local evidence_dir="$RESULTS_DIR/evidence_$TIMESTAMP"
    mkdir -p "$evidence_dir"
    
    # Invoke Dart report generator
    cd "$PROJECT_ROOT"
    
    local dart_args="--project-root=$PROJECT_ROOT --output-dir=$RESULTS_DIR --timestamp=$TIMESTAMP"
    
    if [ -d "$RESULTS_DIR/device_tests_$TIMESTAMP" ]; then
        dart_args="$dart_args --automated-results=$RESULTS_DIR/device_tests_$TIMESTAMP"
    fi
    
    if [ -f "$RESULTS_DIR/manual_test_results.json" ]; then
        dart_args="$dart_args --manual-results=$RESULTS_DIR/manual_test_results.json"
    fi
    
    if [ -d "$evidence_dir" ]; then
        dart_args="$dart_args --evidence-dir=$evidence_dir"
    fi
    
    log "Invoking report generator: dart run scripts/generate_audit_report.dart $dart_args"
    
    if dart run scripts/generate_audit_report.dart $dart_args 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Dart report generator completed successfully"
    else
        log_warning "Dart report generator failed, generating basic report"
        generate_basic_report
    fi
}

# Generate basic Markdown report (fallback)
generate_basic_report() {
    log "Generating basic audit report..."
    
    local report_file="$RESULTS_DIR/audit_report_$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# AirLink Audit Test Report

**Generated:** $(date)
**Test Run ID:** $TIMESTAMP

## Test Summary

### Environment
- **OS:** $(uname -s) $(uname -r)
- **Flutter Version:** $(flutter --version | head -n1)
- **Project Root:** $PROJECT_ROOT

### Test Results
EOF

    # Add test results summary
    if [ -f "$RESULTS_DIR/unit_test_results_$TIMESTAMP.json" ]; then
        echo "- **Unit Tests:** ✅ Completed" >> "$report_file"
    else
        echo "- **Unit Tests:** ❌ Failed or Skipped" >> "$report_file"
    fi
    
    if [ -f "$RESULTS_DIR/integration_test_results_$TIMESTAMP.json" ]; then
        echo "- **Integration Tests:** ✅ Completed" >> "$report_file"
    else
        echo "- **Integration Tests:** ❌ Failed or Skipped" >> "$report_file"
    fi
    
    if [ -f "$RESULTS_DIR/benchmark_results_$TIMESTAMP.json" ]; then
        echo "- **Performance Benchmarks:** ✅ Completed" >> "$report_file"
    else
        echo "- **Performance Benchmarks:** ❌ Failed or Skipped" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### Coverage Report
$(if [ -d "$RESULTS_DIR/coverage_$TIMESTAMP" ]; then echo "Coverage report available at: coverage_$TIMESTAMP/index.html"; else echo "Coverage report not generated"; fi)

### Log Files
- **Main Log:** audit_test_$TIMESTAMP.log
- **Unit Test Results:** unit_test_results_$TIMESTAMP.json
- **Integration Test Results:** integration_test_results_$TIMESTAMP.json
- **Benchmark Results:** benchmark_results_$TIMESTAMP.json

## Recommendations

1. Review failed tests and address any issues
2. Check coverage report for areas needing more tests
3. Analyze benchmark results for performance optimizations
4. Run tests on multiple device configurations

---
*Report generated by AirLink Audit Test Runner*
EOF

    log_success "Audit report generated: $report_file"
}

# Main execution
main() {
    local exit_code=0
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Handle special flags
    if [ "$CHECK_DEVICES" = true ]; then
        check_device_status
        exit $?
    fi
    
    if [ "$SHOW_STATUS" = true ]; then
        show_audit_status
        exit $?
    fi
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Initialize log file
    echo "AirLink Audit Test Runner - Started at $(date)" > "$LOG_FILE"
    echo "Project Root: $PROJECT_ROOT" >> "$LOG_FILE"
    echo "Results Directory: $RESULTS_DIR" >> "$LOG_FILE"
    echo "Mode: $([ "$COMPREHENSIVE" = true ] && echo "Comprehensive" || echo "Automated Only")" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    log "Starting AirLink audit test suite..."
    
    check_prerequisites
    
    # Run test suites
    if [ "$AUTOMATED_ONLY" = false ]; then
        run_flutter_tests || exit_code=1
        run_android_tests || exit_code=1
        run_ios_tests || exit_code=1
        run_performance_tests || exit_code=1
        run_device_transfer_tests || exit_code=1
    else
        log "Running automated tests only..."
        run_flutter_tests || exit_code=1
        run_performance_tests || exit_code=1
    fi
    
    # Run manual tests if requested
    run_manual_tests || exit_code=1
    
    # Generate final report
    generate_audit_report
    
    if [ $exit_code -eq 0 ]; then
        log_success "All audit tests completed successfully!"
        log "Results available in: $RESULTS_DIR"
    else
        log_error "Some tests failed. Check the logs for details."
        log "Results available in: $RESULTS_DIR"
    fi
    
    exit $exit_code
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"
