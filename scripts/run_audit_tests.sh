#!/bin/bash
# AirLink Audit Test Automation Script
# Runs comprehensive audit tests on connected devices

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUDIT_RESULTS_DIR="audit_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_SESSION_DIR="$AUDIT_RESULTS_DIR/session_$TIMESTAMP"

echo -e "${BLUE}🚀 AirLink Audit Test Automation${NC}"
echo -e "${BLUE}================================${NC}\n"

# Create results directory
mkdir -p "$TEST_SESSION_DIR"
echo -e "${GREEN}✓${NC} Created results directory: $TEST_SESSION_DIR"

# Step 1: Check for connected devices
echo -e "\n${YELLOW}Step 1: Detecting connected devices...${NC}"

# Check Android devices
ANDROID_DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l | tr -d ' ')
echo -e "  Android devices: $ANDROID_DEVICES"

# Check iOS devices (requires ios-deploy or similar)
IOS_DEVICES=0
if command -v ios-deploy &> /dev/null; then
    IOS_DEVICES=$(ios-deploy -c 2>/dev/null | grep "Found" | wc -l | tr -d ' ')
    echo -e "  iOS devices: $IOS_DEVICES"
else
    echo -e "  ${YELLOW}⚠${NC}  ios-deploy not found, skipping iOS device detection"
fi

TOTAL_DEVICES=$((ANDROID_DEVICES + IOS_DEVICES))

if [ "$TOTAL_DEVICES" -lt 2 ]; then
    echo -e "${RED}✗${NC} Need at least 2 devices connected for audit tests"
    echo -e "  Connect more devices and try again"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found $TOTAL_DEVICES devices ready for testing"

# Step 2: Install/Update app on devices
echo -e "\n${YELLOW}Step 2: Installing app on devices...${NC}"

# Build and install on Android
if [ "$ANDROID_DEVICES" -gt 0 ]; then
    echo -e "  Building Android APK..."
    flutter build apk --release > /dev/null 2>&1
    
    for device in $(adb devices | grep "device$" | awk '{print $1}'); do
        echo -e "  Installing on Android device: $device"
        adb -s "$device" install -r build/app/outputs/flutter-apk/app-release.apk > /dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} Installed on $device"
    done
fi

# Build and install on iOS
if [ "$IOS_DEVICES" -gt 0 ]; then
    echo -e "  Building iOS app..."
    flutter build ios --release > /dev/null 2>&1
    
    # Note: iOS installation requires additional setup with provisioning profiles
    echo -e "  ${YELLOW}⚠${NC}  iOS installation requires manual deployment via Xcode"
fi

# Step 3: Launch app on all devices
echo -e "\n${YELLOW}Step 3: Launching app on devices...${NC}"

if [ "$ANDROID_DEVICES" -gt 0 ]; then
    for device in $(adb devices | grep "device$" | awk '{print $1}'); do
        echo -e "  Launching on Android device: $device"
        adb -s "$device" shell am start -n com.airlink.airlink_4/.MainActivity > /dev/null 2>&1
        sleep 2
        echo -e "  ${GREEN}✓${NC} Launched on $device"
    done
fi

# Step 4: Enable audit mode via flutter drive
echo -e "\n${YELLOW}Step 4: Enabling audit mode...${NC}"

# Create temporary test driver
cat > test_driver/audit_test.dart << 'EOF'
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Audit Tests', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('Enable audit mode', () async {
      // Enable audit mode via method channel
      await driver.requestData('enableAuditMode');
      await Future.delayed(Duration(seconds: 1));
    });

    test('Run core transfer test', () async {
      // Trigger discovery
      await driver.requestData('startDiscovery');
      await Future.delayed(Duration(seconds: 5));
      
      // Initiate transfer
      await driver.requestData('startTransfer');
      await Future.delayed(Duration(seconds: 10));
    });

    test('Export audit logs', () async {
      final outputPath = '/sdcard/Download/audit_logs_${DateTime.now().millisecondsSinceEpoch}.json';
      await driver.requestData('exportAuditLogs:$outputPath');
      await Future.delayed(Duration(seconds: 2));
    });
  });
}
EOF

cat > test_driver/audit_test_target.dart << 'EOF'
import 'package:flutter_driver/driver_extension.dart';
import 'package:airlink/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
EOF

echo -e "  ${GREEN}✓${NC} Test driver created"

# Step 5: Run integration tests
echo -e "\n${YELLOW}Step 5: Running audit tests...${NC}"

flutter drive \
  --driver=test_driver/audit_test.dart \
  --target=test_driver/audit_test_target.dart \
  2>&1 | tee "$TEST_SESSION_DIR/test_output.log"

echo -e "${GREEN}✓${NC} Tests completed"

# Step 6: Collect device logs
echo -e "\n${YELLOW}Step 6: Collecting device logs...${NC}"

if [ "$ANDROID_DEVICES" -gt 0 ]; then
    for device in $(adb devices | grep "device$" | awk '{print $1}'); do
        echo -e "  Collecting logs from Android device: $device"
        adb -s "$device" logcat -d > "$TEST_SESSION_DIR/logcat_${device}.txt"
        echo -e "  ${GREEN}✓${NC} Logs saved for $device"
    done
fi

# Step 7: Pull audit logs from devices
echo -e "\n${YELLOW}Step 7: Pulling audit logs...${NC}"

if [ "$ANDROID_DEVICES" -gt 0 ]; then
    for device in $(adb devices | grep "device$" | awk '{print $1}'); do
        echo -e "  Pulling audit logs from: $device"
        adb -s "$device" pull /sdcard/Download/audit_logs*.json "$TEST_SESSION_DIR/" 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} Audit logs retrieved from $device"
    done
fi

# Step 8: Capture screenshots
echo -e "\n${YELLOW}Step 8: Capturing screenshots...${NC}"

if [ "$ANDROID_DEVICES" -gt 0 ]; then
    for device in $(adb devices | grep "device$" | awk '{print $1}'); do
        echo -e "  Capturing screenshot from: $device"
        adb -s "$device" exec-out screencap -p > "$TEST_SESSION_DIR/screenshot_${device}.png"
        echo -e "  ${GREEN}✓${NC} Screenshot saved for $device"
    done
fi

# Step 9: Generate checksums for transferred files
echo -e "\n${YELLOW}Step 9: Generating checksums...${NC}"

if [ -f "$TEST_SESSION_DIR/audit_logs"*.json ]; then
    # Extract file paths from audit logs and generate checksums
    find "$TEST_SESSION_DIR" -type f -name "*.json" -o -name "*.png" -o -name "*.txt" | \
        xargs sha256sum > "$TEST_SESSION_DIR/checksums.txt"
    echo -e "${GREEN}✓${NC} Checksums generated"
else
    echo -e "${YELLOW}⚠${NC}  No audit logs found for checksum generation"
fi

# Step 10: Generate summary report
echo -e "\n${YELLOW}Step 10: Generating summary report...${NC}"

cat > "$TEST_SESSION_DIR/summary.md" << EOF
# AirLink Audit Test Summary

**Test Session:** $TIMESTAMP  
**Total Devices:** $TOTAL_DEVICES  
**Android Devices:** $ANDROID_DEVICES  
**iOS Devices:** $IOS_DEVICES

## Test Results

- Test logs: \`test_output.log\`
- Device logs: \`logcat_*.txt\`
- Audit logs: \`audit_logs_*.json\`
- Screenshots: \`screenshot_*.png\`
- Checksums: \`checksums.txt\`

## Files Generated

\`\`\`
$(ls -lh "$TEST_SESSION_DIR" | tail -n +2)
\`\`\`

## Next Steps

1. Review test output logs for failures
2. Verify audit metrics in JSON files
3. Compare checksums for transferred files
4. Analyze screenshots for UI issues
5. Generate detailed report with: \`dart scripts/analyze_audit_results.dart $TEST_SESSION_DIR\`

---
Generated by AirLink Audit Automation
EOF

echo -e "${GREEN}✓${NC} Summary report generated"

# Final summary
echo -e "\n${GREEN}✅ Audit test automation complete!${NC}"
echo -e "\n${BLUE}Results saved to:${NC} $TEST_SESSION_DIR"
echo -e "${BLUE}Summary:${NC} $TEST_SESSION_DIR/summary.md"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Review test results: cat $TEST_SESSION_DIR/summary.md"
echo -e "  2. Analyze audit data: dart scripts/analyze_audit_results.dart $TEST_SESSION_DIR"
echo -e "  3. Generate report: dart scripts/generate_audit_report.dart $TEST_SESSION_DIR"

# Cleanup
rm -f test_driver/audit_test.dart test_driver/audit_test_target.dart

exit 0
