#!/bin/bash

# AirLink Device Log Collection Script
# Collects logs from Android and iOS devices for audit analysis

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_ROOT/device_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
APP_PACKAGE="com.airlink.airlink_4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create logs directory
mkdir -p "$LOGS_DIR"

log "Starting AirLink device log collection..."

# Collect Android logs
collect_android_logs() {
    log "Collecting Android device logs..."
    
    if ! command -v adb &> /dev/null; then
        log_warning "ADB not found, skipping Android log collection"
        return 0
    fi
    
    local devices=$(adb devices | grep -v "List of devices" | grep "device$")
    if [ -z "$devices" ]; then
        log_warning "No Android devices connected"
        return 0
    fi
    
    echo "$devices" | while read -r device_line; do
        local device_id=$(echo "$device_line" | awk '{print $1}')
        log "Collecting logs from Android device: $device_id"
        
        local device_dir="$LOGS_DIR/android_${device_id}_$TIMESTAMP"
        mkdir -p "$device_dir"
        
        # Get device info
        log "Getting device information..."
        adb -s "$device_id" shell getprop > "$device_dir/device_properties.txt" 2>/dev/null || true
        adb -s "$device_id" shell dumpsys battery > "$device_dir/battery_info.txt" 2>/dev/null || true
        adb -s "$device_id" shell dumpsys meminfo > "$device_dir/memory_info.txt" 2>/dev/null || true
        adb -s "$device_id" shell dumpsys cpuinfo > "$device_dir/cpu_info.txt" 2>/dev/null || true
        
        # Get app-specific logs
        log "Collecting application logs..."
        adb -s "$device_id" logcat -d -s "AirLinkPlugin:*" "AuditLogger:*" "WifiAwareManagerWrapper:*" "BleAdvertiser:*" > "$device_dir/app_logs.txt" 2>/dev/null || true
        
        # Get system logs (last 1000 lines)
        log "Collecting system logs..."
        adb -s "$device_id" logcat -d -t 1000 > "$device_dir/system_logs.txt" 2>/dev/null || true
        
        # Get crash logs
        log "Collecting crash logs..."
        adb -s "$device_id" logcat -d -b crash > "$device_dir/crash_logs.txt" 2>/dev/null || true
        
        # Get network information
        log "Collecting network information..."
        adb -s "$device_id" shell dumpsys wifi > "$device_dir/wifi_info.txt" 2>/dev/null || true
        adb -s "$device_id" shell dumpsys bluetooth_manager > "$device_dir/bluetooth_info.txt" 2>/dev/null || true
        
        # Get app-specific information
        log "Collecting app information..."
        adb -s "$device_id" shell dumpsys package "$APP_PACKAGE" > "$device_dir/app_package_info.txt" 2>/dev/null || true
        adb -s "$device_id" shell pm list permissions "$APP_PACKAGE" > "$device_dir/app_permissions.txt" 2>/dev/null || true
        
        # Get file system information
        log "Collecting storage information..."
        adb -s "$device_id" shell df > "$device_dir/storage_info.txt" 2>/dev/null || true
        adb -s "$device_id" shell ls -la "/data/data/$APP_PACKAGE/" > "$device_dir/app_files.txt" 2>/dev/null || true
        
        # Export app databases and preferences (if accessible)
        log "Attempting to export app data..."
        adb -s "$device_id" shell "run-as $APP_PACKAGE ls -la" > "$device_dir/app_internal_files.txt" 2>/dev/null || true
        
        # Create summary file
        cat > "$device_dir/collection_summary.txt" << EOF
Android Device Log Collection Summary
=====================================

Device ID: $device_id
Collection Time: $(date)
Collection Script: $0

Files Collected:
- device_properties.txt: Device system properties
- battery_info.txt: Battery status and information
- memory_info.txt: Memory usage information
- cpu_info.txt: CPU usage information
- app_logs.txt: AirLink application logs
- system_logs.txt: System logs (last 1000 lines)
- crash_logs.txt: System crash logs
- wifi_info.txt: Wi-Fi system information
- bluetooth_info.txt: Bluetooth system information
- app_package_info.txt: AirLink package information
- app_permissions.txt: AirLink app permissions
- storage_info.txt: Device storage information
- app_files.txt: AirLink app file listing
- app_internal_files.txt: AirLink internal files (if accessible)

Notes:
- Some files may be empty if information is not accessible
- Root access may be required for some system information
- App internal files require debuggable build or root access
EOF
        
        log_success "Android logs collected for device $device_id: $device_dir"
    done
}

# Collect iOS logs
collect_ios_logs() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_warning "iOS log collection only available on macOS"
        return 0
    fi
    
    log "Collecting iOS device logs..."
    
    # Check for iOS devices using libimobiledevice
    if command -v idevice_id &> /dev/null; then
        local devices=$(idevice_id -l 2>/dev/null)
        if [ -z "$devices" ]; then
            log_warning "No iOS devices found via libimobiledevice"
        else
            echo "$devices" | while read -r device_id; do
                if [ -n "$device_id" ]; then
                    collect_ios_device_logs "$device_id"
                fi
            done
        fi
    else
        log_warning "libimobiledevice not found, trying alternative methods..."
    fi
    
    # Try using Xcode tools
    if command -v xcrun &> /dev/null; then
        log "Attempting to collect iOS logs using Xcode tools..."
        local device_dir="$LOGS_DIR/ios_xcode_$TIMESTAMP"
        mkdir -p "$device_dir"
        
        # Get device list
        xcrun simctl list devices > "$device_dir/simulator_list.txt" 2>/dev/null || true
        
        # Try to get system logs
        log "Collecting iOS system logs..."
        xcrun simctl spawn booted log collect --output "$device_dir/system_logs.logarchive" 2>/dev/null || true
        
        log_success "iOS logs collected using Xcode tools: $device_dir"
    fi
}

# Collect logs from specific iOS device
collect_ios_device_logs() {
    local device_id="$1"
    log "Collecting logs from iOS device: $device_id"
    
    local device_dir="$LOGS_DIR/ios_${device_id}_$TIMESTAMP"
    mkdir -p "$device_dir"
    
    # Get device information
    if command -v ideviceinfo &> /dev/null; then
        log "Getting iOS device information..."
        ideviceinfo -u "$device_id" > "$device_dir/device_info.txt" 2>/dev/null || true
    fi
    
    # Get system logs
    if command -v idevicesyslog &> /dev/null; then
        log "Collecting iOS system logs..."
        timeout 30 idevicesyslog -u "$device_id" > "$device_dir/system_logs.txt" 2>/dev/null || true
    fi
    
    # Get crash logs
    if command -v idevicecrashreport &> /dev/null; then
        log "Collecting iOS crash reports..."
        idevicecrashreport -u "$device_id" -e "$device_dir/crash_reports/" 2>/dev/null || true
    fi
    
    # Get app installation info
    if command -v ideviceinstaller &> /dev/null; then
        log "Getting iOS app installation info..."
        ideviceinstaller -u "$device_id" -l > "$device_dir/installed_apps.txt" 2>/dev/null || true
    fi
    
    # Create summary file
    cat > "$device_dir/collection_summary.txt" << EOF
iOS Device Log Collection Summary
=================================

Device ID: $device_id
Collection Time: $(date)
Collection Script: $0

Files Collected:
- device_info.txt: Device information and properties
- system_logs.txt: System logs (30 second capture)
- crash_reports/: Crash report files
- installed_apps.txt: List of installed applications

Notes:
- Device must be trusted and unlocked for full access
- Some information requires developer provisioning
- Crash reports may require specific entitlements
EOF
    
    log_success "iOS logs collected for device $device_id: $device_dir"
}

# Collect Flutter logs
collect_flutter_logs() {
    log "Collecting Flutter application logs..."
    
    local flutter_dir="$LOGS_DIR/flutter_$TIMESTAMP"
    mkdir -p "$flutter_dir"
    
    cd "$PROJECT_ROOT"
    
    # Get Flutter doctor output
    log "Running Flutter doctor..."
    flutter doctor -v > "$flutter_dir/flutter_doctor.txt" 2>&1 || true
    
    # Get Flutter version info
    flutter --version > "$flutter_dir/flutter_version.txt" 2>&1 || true
    
    # Get pub dependencies
    flutter pub deps > "$flutter_dir/pub_dependencies.txt" 2>&1 || true
    
    # Get build logs if available
    if [ -d "build" ]; then
        log "Collecting build logs..."
        find build -name "*.log" -type f -exec cp {} "$flutter_dir/" \; 2>/dev/null || true
    fi
    
    # Create summary
    cat > "$flutter_dir/collection_summary.txt" << EOF
Flutter Application Log Collection Summary
==========================================

Collection Time: $(date)
Project Root: $PROJECT_ROOT

Files Collected:
- flutter_doctor.txt: Flutter environment diagnostics
- flutter_version.txt: Flutter version information
- pub_dependencies.txt: Package dependencies
- *.log: Build log files (if available)

Notes:
- Run from project root directory
- Build logs only available after building the app
EOF
    
    log_success "Flutter logs collected: $flutter_dir"
}

# Generate collection report
generate_collection_report() {
    log "Generating log collection report..."
    
    local report_file="$LOGS_DIR/collection_report_$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# AirLink Device Log Collection Report

**Generated:** $(date)
**Collection ID:** $TIMESTAMP

## Collection Summary

### Environment
- **OS:** $(uname -s) $(uname -r)
- **Script Location:** $SCRIPT_DIR
- **Logs Directory:** $LOGS_DIR

### Collected Logs

#### Android Devices
EOF

    # List Android log directories
    find "$LOGS_DIR" -type d -name "android_*_$TIMESTAMP" | while read -r dir; do
        local device_id=$(basename "$dir" | sed "s/android_\(.*\)_$TIMESTAMP/\1/")
        echo "- **Device ID:** $device_id" >> "$report_file"
        echo "  - **Directory:** $(basename "$dir")" >> "$report_file"
        if [ -f "$dir/collection_summary.txt" ]; then
            echo "  - **Status:** ✅ Collected" >> "$report_file"
        else
            echo "  - **Status:** ❌ Failed" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

#### iOS Devices
EOF

    # List iOS log directories
    find "$LOGS_DIR" -type d -name "ios_*_$TIMESTAMP" | while read -r dir; do
        local device_id=$(basename "$dir" | sed "s/ios_\(.*\)_$TIMESTAMP/\1/")
        echo "- **Device ID:** $device_id" >> "$report_file"
        echo "  - **Directory:** $(basename "$dir")" >> "$report_file"
        if [ -f "$dir/collection_summary.txt" ]; then
            echo "  - **Status:** ✅ Collected" >> "$report_file"
        else
            echo "  - **Status:** ❌ Failed" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

#### Flutter Application
EOF

    if [ -d "$LOGS_DIR/flutter_$TIMESTAMP" ]; then
        echo "- **Status:** ✅ Collected" >> "$report_file"
        echo "- **Directory:** flutter_$TIMESTAMP" >> "$report_file"
    else
        echo "- **Status:** ❌ Not collected" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Usage Instructions

1. **Review Log Files:** Check individual device directories for specific logs
2. **Analyze Issues:** Look for error patterns in app_logs.txt and system_logs.txt
3. **Check Performance:** Review memory_info.txt and cpu_info.txt for resource usage
4. **Network Issues:** Examine wifi_info.txt and bluetooth_info.txt for connectivity problems
5. **Crashes:** Check crash_logs.txt and crash_reports/ for application crashes

## Tools Required

### Android
- ADB (Android Debug Bridge)
- Connected Android device with USB debugging enabled

### iOS (macOS only)
- libimobiledevice tools (brew install libimobiledevice)
- Xcode command line tools
- Trusted iOS device

### Flutter
- Flutter SDK
- Project dependencies installed

---
*Report generated by AirLink Device Log Collection Script*
EOF

    log_success "Collection report generated: $report_file"
}

# Main execution
main() {
    local start_time=$(date)
    
    log "Starting device log collection at $start_time"
    
    # Collect logs from all sources
    collect_android_logs
    collect_ios_logs
    collect_flutter_logs
    
    # Generate final report
    generate_collection_report
    
    local end_time=$(date)
    log_success "Log collection completed!"
    log "Started: $start_time"
    log "Finished: $end_time"
    log "Results available in: $LOGS_DIR"
    
    # Show directory contents
    log "Collected log directories:"
    ls -la "$LOGS_DIR" | grep "^d" | grep "$TIMESTAMP" || log_warning "No log directories found"
}

# Handle script interruption
trap 'log_error "Log collection interrupted"; exit 130' INT TERM

# Run main function
main "$@"
