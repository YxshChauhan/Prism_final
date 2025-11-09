import Foundation
import UIKit
import os.log

/**
 * AuditLogger - Centralized audit logging for iOS native layer
 * Collects audit-level metrics including CPU usage, memory consumption,
 * network throughput, and transfer events for production testing
 */
class AuditLogger {
    
    static var AUDIT_MODE = false
    private static let logger = OSLog(subsystem: "com.airlink.airlink_4", category: "AuditLogger")
    
    // Thread-safe collections for audit data
    private var transferLogs: [String: [AuditEvent]] = [:]
    private var systemMetricsCache: [String: SystemMetrics] = [:]
    private let lock = NSLock()
    private let dateFormatter: DateFormatter
    
    // CPU usage differential sampling
    private var previousUserTime: UInt32 = 0
    private var previousSystemTime: UInt32 = 0
    private var lastCpuSampleTime: TimeInterval = 0
    private let cpuSampleInterval: TimeInterval = 1.0 // Sample every 1 second
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    }
    
    /**
     * Log transfer initiation with timestamp and metadata
     */
    func logTransferStart(transferId: String, fileSize: Int64, method: String) {
        guard AuditLogger.AUDIT_MODE else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        do {
            let event = AuditEvent(
                type: "transfer_start",
                timestamp: getCurrentTimestamp(),
                transferId: transferId,
                data: [
                    "fileSize": fileSize,
                    "method": method,
                    "systemMetrics": getCurrentSystemMetrics().toDictionary()
                ]
            )
            addAuditEvent(transferId: transferId, event: event)
            os_log("Transfer start logged: %{public}@, size: %{public}lld, method: %{public}@", 
                   log: AuditLogger.logger, type: .info, transferId, fileSize, method)
        } catch {
            os_log("Failed to log transfer start: %{public}@", 
                   log: AuditLogger.logger, type: .error, error.localizedDescription)
        }
    }
    
    /**
     * Log transfer progress with current metrics
     */
    func logTransferProgress(transferId: String, bytesTransferred: Int64, speed: Double) {
        guard AuditLogger.AUDIT_MODE else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        do {
            let event = AuditEvent(
                type: "transfer_progress",
                timestamp: getCurrentTimestamp(),
                transferId: transferId,
                data: [
                    "bytesTransferred": bytesTransferred,
                    "speed": speed,
                    "systemMetrics": getCurrentSystemMetrics().toDictionary()
                ]
            )
            addAuditEvent(transferId: transferId, event: event)
        } catch {
            os_log("Failed to log transfer progress: %{public}@", 
                   log: AuditLogger.logger, type: .error, error.localizedDescription)
        }
    }
    
    /**
     * Log transfer completion with final metrics
     */
    func logTransferComplete(transferId: String, duration: Int64, checksum: String?) {
        guard AuditLogger.AUDIT_MODE else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        do {
            let event = AuditEvent(
                type: "transfer_complete",
                timestamp: getCurrentTimestamp(),
                transferId: transferId,
                data: [
                    "duration": duration,
                    "checksum": checksum as Any,
                    "systemMetrics": getCurrentSystemMetrics().toDictionary()
                ]
            )
            addAuditEvent(transferId: transferId, event: event)
            os_log("Transfer complete logged: %{public}@, duration: %{public}lldms", 
                   log: AuditLogger.logger, type: .info, transferId, duration)
        } catch {
            os_log("Failed to log transfer complete: %{public}@", 
                   log: AuditLogger.logger, type: .error, error.localizedDescription)
        }
    }
    
    /**
     * Capture current system metrics (CPU, memory, battery)
     */
    func logSystemMetrics(transferId: String) {
        guard AuditLogger.AUDIT_MODE else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        do {
            let metrics = getCurrentSystemMetrics()
            systemMetricsCache[transferId] = metrics
            
            let event = AuditEvent(
                type: "system_metrics",
                timestamp: getCurrentTimestamp(),
                transferId: transferId,
                data: ["systemMetrics": metrics.toDictionary()]
            )
            addAuditEvent(transferId: transferId, event: event)
        } catch {
            os_log("Failed to log system metrics: %{public}@", 
                   log: AuditLogger.logger, type: .error, error.localizedDescription)
        }
    }
    
    /**
     * Retrieve structured audit log for a transfer
     */
    func getAuditLog(transferId: String) -> [String: Any] {
        guard AuditLogger.AUDIT_MODE else { return [:] }
        
        lock.lock()
        defer { lock.unlock() }
        
        do {
            let events = transferLogs[transferId] ?? []
            let metrics = systemMetricsCache[transferId]
            
            return [
                "transferId": transferId,
                "events": events.map { $0.toDictionary() },
                "latestMetrics": metrics?.toDictionary() ?? [:],
                "eventCount": events.count,
                "generatedAt": getCurrentTimestamp()
            ]
        } catch {
            os_log("Failed to get audit log: %{public}@", 
                   log: AuditLogger.logger, type: .error, error.localizedDescription)
            return [:]
        }
    }
    
    /**
     * Export all audit logs to JSON file
     */
    func exportAuditLogs(outputPath: String) {
        guard AuditLogger.AUDIT_MODE else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        do {
            var allLogs: [String: Any] = [:]
            
            // Export all transfer logs
            for (transferId, events) in transferLogs {
                allLogs[transferId] = [
                    "events": events.map { $0.toDictionary() },
                    "metrics": systemMetricsCache[transferId]?.toDictionary() ?? [:]
                ]
            }
            
            let exportData: [String: Any] = [
                "auditLogs": allLogs,
                "exportedAt": getCurrentTimestamp(),
                "deviceInfo": getDeviceInfo()
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let fileURL = URL(fileURLWithPath: outputPath.isEmpty ? getDefaultLogPath() : outputPath)
            try jsonData.write(to: fileURL)
            
            os_log("Audit logs exported to: %{public}@", 
                   log: AuditLogger.logger, type: .info, fileURL.path)
        } catch {
            os_log("Failed to export audit logs: %{public}@", 
                   log: AuditLogger.logger, type: .error, error.localizedDescription)
        }
    }
    
    /**
     * Clear audit logs for a specific transfer
     */
    func clearTransferLogs(transferId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        transferLogs.removeValue(forKey: transferId)
        systemMetricsCache.removeValue(forKey: transferId)
    }
    
    /**
     * Clear all audit logs
     */
    func clearAllLogs() {
        lock.lock()
        defer { lock.unlock() }
        
        transferLogs.removeAll()
        systemMetricsCache.removeAll()
    }
    
    // MARK: - Private Helper Methods
    
    private func addAuditEvent(transferId: String, event: AuditEvent) {
        if transferLogs[transferId] == nil {
            transferLogs[transferId] = []
        }
        transferLogs[transferId]?.append(event)
        
        // Limit queue size to prevent memory issues
        if let eventCount = transferLogs[transferId]?.count, eventCount > 1000 {
            transferLogs[transferId]?.removeFirst()
        }
    }
    
    private func getCurrentTimestamp() -> String {
        return dateFormatter.string(from: Date())
    }
    
    private func getCurrentSystemMetrics() -> SystemMetrics {
        return SystemMetrics(
            cpuUsagePercent: getCpuUsagePercent(),
            memoryUsageMB: getMemoryUsageMB(),
            batteryLevel: getBatteryLevel(),
            availableMemoryMB: getAvailableMemoryMB(),
            timestamp: getCurrentTimestamp()
        )
    }
    
    private func getCpuUsagePercent() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let currentTime = Date().timeIntervalSince1970
            let currentUserTime = info.user_time.seconds
            let currentSystemTime = info.system_time.seconds
            
            // Use differential sampling if we have previous values and enough time has passed
            if previousUserTime > 0 && (currentTime - lastCpuSampleTime) >= cpuSampleInterval {
                let userDelta = currentUserTime - previousUserTime
                let systemDelta = currentSystemTime - previousSystemTime
                let timeDelta = currentTime - lastCpuSampleTime
                
                // Update previous values for next sample
                previousUserTime = currentUserTime
                previousSystemTime = currentSystemTime
                lastCpuSampleTime = currentTime
                
                // Calculate CPU usage as percentage over the time interval
                if timeDelta > 0 {
                    let totalCpuTime = Double(userDelta + systemDelta)
                    let usage = (totalCpuTime / timeDelta) * 100.0
                    return min(usage, 100.0) // Cap at 100%
                }
            } else if previousUserTime == 0 {
                // Initialize on first call
                previousUserTime = currentUserTime
                previousSystemTime = currentSystemTime
                lastCpuSampleTime = currentTime
            }
            
            // Fallback to instantaneous calculation
            return Double(currentUserTime + currentSystemTime) / 100.0
        } else {
            os_log("Failed to get CPU usage", log: AuditLogger.logger, type: .debug)
            return 0.0
        }
    }
    
    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        } else {
            os_log("Failed to get memory usage", log: AuditLogger.logger, type: .debug)
            return 0.0
        }
    }
    
    private func getAvailableMemoryMB() -> Double {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return Double(physicalMemory) / (1024.0 * 1024.0)
    }
    
    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        UIDevice.current.isBatteryMonitoringEnabled = false
        
        if batteryLevel < 0 {
            return -1 // Battery level unavailable
        } else {
            return Int(batteryLevel * 100)
        }
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "name": UIDevice.current.name,
            "identifierForVendor": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
    }
    
    private func getDefaultLogPath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("audit_logs.json").path
    }
}

// MARK: - Data Structures

private struct AuditEvent {
    let type: String
    let timestamp: String
    let transferId: String
    let data: [String: Any]
    
    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "timestamp": timestamp,
            "transferId": transferId,
            "data": data
        ]
    }
}

private struct SystemMetrics {
    let cpuUsagePercent: Double
    let memoryUsageMB: Double
    let batteryLevel: Int
    let availableMemoryMB: Double
    let timestamp: String
    
    func toDictionary() -> [String: Any] {
        return [
            "cpuUsagePercent": cpuUsagePercent,
            "memoryUsageMB": memoryUsageMB,
            "batteryLevel": batteryLevel,
            "availableMemoryMB": availableMemoryMB,
            "timestamp": timestamp
        ]
    }
}
