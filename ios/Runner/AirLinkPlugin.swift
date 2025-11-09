import Foundation
import CoreBluetooth
import Network
import MultipeerConnectivity
import CryptoKit

@objc(AirLinkPlugin)
class AirLinkPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralManagerDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    
    // Audit logging
    private let auditLogger = AuditLogger()
    static var AUDIT_MODE = false
    
    // Advanced features handler
    private let advancedFeaturesHandler = AdvancedFeaturesHandler()
    
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var methodChannel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?
    private var discoveredPeripherals: [CBPeripheral] = []
    private var connectedPeripherals: [CBPeripheral] = []
    private var encryptionKeys: [String: Data] = [:] // connectionToken -> AES key
    private var bleTargetCharacteristics: [String: CBCharacteristic] = [:] // connectionToken -> characteristic
    private var bleConnectedByToken: [String: CBPeripheral] = [:] // connectionToken -> peripheral
    private var bleTransferProgress: [String: [String: Any]] = [:] // transferId -> progress map
    private struct SendState { var transferId: String; var filePath: String; var totalBytes: Int64; var sentBytes: Int64; var paused: Bool; var cancelled: Bool; var lastAckAt: Date? = nil }
    private struct ReceiveState { var fileId: String; var expectedSize: Int64; var received: Int64; var fileURL: URL; var handle: FileHandle }
    
    // BLE Service and Characteristic UUIDs
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    private let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-cba987654321")
    
    // Network discovery
    private var networkBrowser: NWBrowser?
    private var listener: NWListener?
    
    // MultipeerConnectivity
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var multipeerBrowser: MCNearbyServiceBrowser!
    private var connectedPeers: [MCPeerID] = []
    private var peerIdToToken: [Int: String] = [:] // peer.hash -> connectionToken
    private var sendStates: [String: SendState] = [:] // transferId -> state
    private var receiveStates: [String: ReceiveState] = [:] // transferId -> state
    
    // BLE Transfer Manager for cross-platform compatibility
    private var bleTransferManager: BLETransferManager?
    private var multipeerTransferManager: MultipeerTransferManager?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "airlink/core", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "airlink/events", binaryMessenger: registrar.messenger())
        let instance = AirLinkPlugin()
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel
        instance.setMethodChannel(methodChannel) // Initialize managers with channel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        // Initialize MultipeerConnectivity
        peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        // Initialize BLE Transfer Manager
        bleTransferManager = BLETransferManager(methodChannel: nil, auditLogger: auditLogger)
        bleTransferManager?.initialize()
        
        // Initialize Multipeer Transfer Manager
        multipeerTransferManager = MultipeerTransferManager(methodChannel: nil, auditLogger: auditLogger)
    }
    
    // Update managers with method channel after registration
    func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
        bleTransferManager = BLETransferManager(methodChannel: channel, auditLogger: auditLogger)
        bleTransferManager?.initialize()
        multipeerTransferManager = MultipeerTransferManager(methodChannel: channel, auditLogger: auditLogger)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Handle namespaced method calls by splitting on '.'
        let methodParts = call.method.split(separator: ".")
        let service = methodParts.count > 1 ? String(methodParts[0]) : nil
        let method = methodParts.count > 1 ? String(methodParts[1]) : call.method
        
        print("Method call: \(call.method) -> service: \(service ?? "nil"), method: \(method)")
        
        // Route based on service if provided
        if let service = service {
            switch service {
            case "discovery":
                handleDiscoveryMethod(method, call: call, result: result)
            case "transfer":
                handleTransferMethod(method, call: call, result: result)
            case "media":
                handleMediaMethod(method, call: call, result: result)
            case "file":
                handleFileMethod(method, call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
            return
        }
        
        // Legacy routing for non-namespaced calls
        switch method {
        case "enableAuditMode":
            AirLinkPlugin.AUDIT_MODE = true
            AuditLogger.AUDIT_MODE = true
            result(true)
        case "disableAuditMode":
            AirLinkPlugin.AUDIT_MODE = false
            AuditLogger.AUDIT_MODE = false
            result(false)
        case "getAuditMetrics":
            let transferId = (call.arguments as? [String: Any])?["transferId"] as? String ?? ""
            let metrics = auditLogger.getAuditLog(transferId: transferId)
            result(metrics)
        case "exportAuditLogs":
            let outputPath = (call.arguments as? [String: Any])?["outputPath"] as? String ?? ""
            auditLogger.exportAuditLogs(outputPath: outputPath)
            result(true)
        // Audit Evidence Collection
        case "getStorageStatus":
            handleGetStorageStatus(result: result)
        case "getCapabilities":
            handleGetCapabilities(result: result)
        case "captureScreenshot":
            handleCaptureScreenshot(call: call, result: result)
        case "exportDeviceLogs":
            handleExportDeviceLogs(call: call, result: result)
        case "listTransferredFiles":
            handleListTransferredFiles(result: result)
        case "setEncryptionKey":
            handleSetEncryptionKey(call: call, result: result)
        // Core Discovery & Transfer
        case "startDiscovery":
            handleStartDiscovery(result: result)
        case "stopDiscovery":
            handleStopDiscovery(result: result)
        case "publishService":
            handlePublishService(call: call, result: result)
        case "subscribeService":
            handleSubscribeService(result: result)
        case "connectToPeer":
            handleConnectToPeer(call: call, result: result)
        case "createDatapath":
            handleCreateDatapath(call: call, result: result)
        case "closeDatapath":
            handleCloseDatapath(result: result)
        case "isWifiAwareSupported":
            result(false) // Wi-Fi Aware not available on iOS
        case "isBleSupported":
            checkBLESupport(result: result)
            
        // Legacy BLE methods (for backward compatibility)
        case "initialize":
            initializeBLE(result: result)
        case "startAdvertising":
            startBLEAdvertising(result: result)
        case "stopAdvertising":
            stopBLEAdvertising(result: result)
        case "startBLEDiscovery":
            startBLEDiscovery(result: result)
        case "stopBLEDiscovery":
            stopBLEDiscovery(result: result)
        case "isBLESupported":
            checkBLESupport(result: result)
        case "startNetworkDiscovery":
            startNetworkDiscovery(result: result)
        case "stopNetworkDiscovery":
            stopNetworkDiscovery(result: result)
        case "startMultipeerAdvertising":
            startMultipeerAdvertising(result: result)
        case "stopMultipeerAdvertising":
            stopMultipeerAdvertising(result: result)
        case "startMultipeerBrowsing":
            startMultipeerBrowsing(result: result)
        case "stopMultipeerBrowsing":
            stopMultipeerBrowsing(result: result)
        case "isMultipeerSupported":
            checkMultipeerSupport(result: result)
            
        // Media Player
        case "playMedia":
            handlePlayMedia(call: call, result: result)
        case "pauseMedia":
            handlePauseMedia(result: result)
        case "stopMedia":
            handleStopMedia(result: result)
        case "seekMedia":
            handleSeekMedia(call: call, result: result)
        case "setVolume":
            handleSetVolume(call: call, result: result)
        case "setPlaybackSpeed":
            handleSetPlaybackSpeed(call: call, result: result)
        case "getMediaInfo":
            handleGetMediaInfo(call: call, result: result)
            
        // File Manager
        case "listFiles":
            handleListFiles(call: call, result: result)
        case "getFileInfo":
            handleGetFileInfo(call: call, result: result)
        case "copyFile":
            handleCopyFile(call: call, result: result)
        case "moveFile":
            handleMoveFile(call: call, result: result)
        case "deleteFile":
            handleDeleteFile(call: call, result: result)
        case "createFolder":
            handleCreateFolder(call: call, result: result)
        case "searchFiles":
            handleSearchFiles(call: call, result: result)
        case "getStorageInfo":
            handleGetStorageInfo(result: result)
            
        // App Management (iOS equivalent of APK)
        case "getInstalledApps":
            handleGetInstalledApps(result: result)
        case "extractApk":
            handleExtractApp(call: call, result: result)
        case "installApk":
            handleInstallApp(call: call, result: result)
        case "uninstallApp":
            handleUninstallApp(call: call, result: result)
        case "getAppInfo":
            handleGetAppInfo(call: call, result: result)
        case "getExtractionHistory":
            handleGetExtractionHistory(result: result)
        case "deleteFromHistory":
            handleDeleteFromHistory(call: call, result: result)
            
        // Cloud Sync
        case "connectCloudProvider":
            handleConnectCloudProvider(call: call, result: result)
        case "disconnectCloudProvider":
            handleDisconnectCloudProvider(call: call, result: result)
        case "uploadToCloud":
            handleUploadToCloud(call: call, result: result)
        case "downloadFromCloud":
            handleDownloadFromCloud(call: call, result: result)
        case "syncCloud":
            handleSyncCloud(call: call, result: result)
        case "getCloudStorageInfo":
            handleGetCloudStorageInfo(call: call, result: result)
            
        // Video Compression
        case "compressVideo":
            advancedFeaturesHandler.compressVideo(call: call, result: result)
        case "getCompressionProgress":
            advancedFeaturesHandler.getCompressionProgress(call: call, result: result)
        case "cancelCompression":
            advancedFeaturesHandler.cancelCompression(call: call, result: result)
        case "getCompressionHistory":
            handleGetCompressionHistory(result: result)
        case "deleteCompressionJob":
            handleDeleteCompressionJob(call: call, result: result)
            
        // File Manager Enhancements
        case "getFileMetadata":
            advancedFeaturesHandler.getFileMetadata(call: call, result: result)
        case "bulkFileOperations":
            advancedFeaturesHandler.bulkFileOperations(call: call, result: result)
            
        // Media Player Enhancements
        case "getVideoInfo":
            advancedFeaturesHandler.getVideoInfo(call: call, result: result)
        case "extractAudioTrack":
            advancedFeaturesHandler.extractAudioTrack(call: call, result: result)
            
        // Phone Replication
        case "exportContacts":
            advancedFeaturesHandler.exportContacts(call: call, result: result)
        case "exportCallLogs":
            advancedFeaturesHandler.exportCallLogs(call: call, result: result)
        case "listCloudFiles":
            advancedFeaturesHandler.listCloudFiles(call: call, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    // MARK: - Encryption Key Handling
    private func handleSetEncryptionKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let connectionToken = args["connectionToken"] as? String,
              let keyList = args["key"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "connectionToken and key are required", details: nil))
            return
        }
        let keyData = keyList.data
        encryptionKeys[connectionToken] = keyData
        result(true)
    }
    
    // MARK: - Core Discovery & Transfer Handlers
    
    private func handleStartDiscovery(result: @escaping FlutterResult) {
        // Start BLE and MultipeerConnectivity discovery
        startBLEDiscovery(result: result)
        startMultipeerBrowsing(result: result)
    }
    
    private func handleStopDiscovery(result: @escaping FlutterResult) {
        stopBLEDiscovery(result: result)
        stopMultipeerBrowsing(result: result)
    }
    
    private func handlePublishService(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        // Start MultipeerConnectivity advertising
        startMultipeerAdvertising(result: result)
    }
    
    private func handleSubscribeService(result: @escaping FlutterResult) {
        startMultipeerBrowsing(result: result)
    }
    
    private func handleConnectToPeer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let peerId = args["peerId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "peerId is required", details: nil))
            return
        }
        
        // Find the peer by ID
        guard let peer = connectedPeers.first(where: { "multipeer_\($0.hash)" == peerId }) else {
            result(FlutterError(code: "PEER_NOT_FOUND", message: "Peer not found: \(peerId)", details: nil))
            return
        }
        
        // Invite peer to session
        multipeerBrowser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
        
        let connectionToken = "multipeer_\(Date().timeIntervalSince1970)"
        result(connectionToken)
    }
    
    private func handleCreateDatapath(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let connectionToken = args["connectionToken"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "connectionToken is required", details: nil))
            return
        }
        
        // Create datapath info for MultipeerConnectivity
        let datapathInfo: [String: Any] = [
            "connectionToken": connectionToken,
            "socketType": "multipeer",
            "isConnected": session.connectedPeers.count > 0,
            "connectedPeers": session.connectedPeers.map { [
                "peerID": $0.hash,
                "displayName": $0.displayName
            ]},
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        result(datapathInfo)
    }
    
    private func handleCloseDatapath(result: @escaping FlutterResult) {
        // Disconnect all peers
        session.disconnect()
        
        // Stop advertising and browsing
        advertiser?.stopAdvertisingPeer()
        multipeerBrowser?.stopBrowsingForPeers()
        
        // Clear connected peers
        connectedPeers.removeAll()
        
        result(true)
    }
    
    // MARK: - Event Channel Stream Handler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    private func sendEvent(_ eventType: String, data: [String: Any], service: String = "discovery") {
        guard let eventSink = eventSink else { return }
        
        let event: [String: Any] = [
            "type": eventType,
            "service": service,
            "data": data
        ]
        
        eventSink(event)
    }
    
    func sendTransferProgress(transferId: String, sentBytes: Int64, totalBytes: Int64, speed: Double) {
        let progressData: [String: Any] = [
            "transferId": transferId,
            "fileId": transferId, // Use transferId as fileId for now
            "bytesTransferred": sentBytes,
            "totalBytes": totalBytes,
            "status": "inProgress",
            "startedAt": ISO8601DateFormatter().string(from: Date()),
            "speed": speed
        ]
        
        sendEvent("transferProgress", data: progressData, service: "transfer")
    }
    
    // MARK: - Media Player Handlers
    
    private func handlePlayMedia(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native media player
        result(true)
    }
    
    private func handlePauseMedia(result: @escaping FlutterResult) {
        // TODO: Implement native media player pause
        result(true)
    }
    
    private func handleStopMedia(result: @escaping FlutterResult) {
        // TODO: Implement native media player stop
        result(true)
    }
    
    private func handleSeekMedia(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native media player seek
        result(true)
    }
    
    private func handleSetVolume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native volume control
        result(true)
    }
    
    private func handleSetPlaybackSpeed(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native playback speed control
        result(true)
    }
    
    private func handleGetMediaInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native media info extraction
        let mediaInfo = [
            "duration": 0,
            "width": 0,
            "height": 0,
            "bitrate": 0,
            "format": "unknown"
        ]
        result(mediaInfo)
    }
    
    // MARK: - File Manager Handlers
    
    private func handleListFiles(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        let path = args["path"] as? String ?? "/"
        let includeHidden = args["includeHidden"] as? Bool ?? false
        
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: path)
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .isReadableKey,
                .isWritableKey,
                .isHiddenKey
            ])
            
            let files = contents.compactMap { url -> [String: Any]? in
                let fileName = url.lastPathComponent
                
                // Skip hidden files if not including them
                if !includeHidden && fileName.hasPrefix(".") {
                    return nil
                }
                
                do {
                    let resourceValues = try url.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isReadableKey,
                        .isWritableKey,
                        .isHiddenKey
                    ])
                    
                    return [
                        "name": fileName,
                        "path": url.path,
                        "size": resourceValues.fileSize ?? 0,
                        "isDirectory": resourceValues.isDirectory ?? false,
                        "lastModified": Int((resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000),
                        "canRead": resourceValues.isReadable ?? false,
                        "canWrite": resourceValues.isWritable ?? false,
                        "isHidden": resourceValues.isHidden ?? false
                    ]
                } catch {
                    print("Error getting resource values for \(url.path): \(error)")
                    return nil
                }
            }
            
            result(files)
        } catch {
            print("Error listing files: \(error)")
            result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleGetFileInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "filePath is required", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "File does not exist: \(filePath)", details: nil))
            return
        }
        
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .isReadableKey,
                .isWritableKey,
                .isHiddenKey
            ])
            
            let fileInfo = [
                "name": fileURL.lastPathComponent,
                "path": fileURL.path,
                "size": resourceValues.fileSize ?? 0,
                "isDirectory": resourceValues.isDirectory ?? false,
                "lastModified": Int((resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000),
                "canRead": resourceValues.isReadable ?? false,
                "canWrite": resourceValues.isWritable ?? false,
                "isHidden": resourceValues.isHidden ?? false,
                "extension": fileURL.pathExtension,
                "parent": fileURL.deletingLastPathComponent().path
            ]
            result(fileInfo)
        } catch {
            print("Error getting file info: \(error)")
            result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleCopyFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let destinationPath = args["destinationPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath and destinationPath are required", details: nil))
            return
        }
        
        do {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = URL(fileURLWithPath: destinationPath)
            
            // Create destination directory if it doesn't exist
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Copy file
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            print("File copied successfully: \(sourcePath) -> \(destinationPath)")
            result(true)
        } catch {
            print("Failed to copy file: \(error.localizedDescription)")
            result(FlutterError(code: "COPY_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleMoveFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native file move
        result(true)
    }
    
    private func handleDeleteFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native file deletion
        result(true)
    }
    
    private func handleCreateFolder(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native folder creation
        result(true)
    }
    
    private func handleSearchFiles(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let query = args["query"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "query is required", details: nil))
            return
        }
        
        let path = args["path"] as? String ?? "/"
        let searchDirectory = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            result(FlutterError(code: "DIRECTORY_NOT_FOUND", message: "Directory does not exist: \(path)", details: nil))
            return
        }
        
        var searchResults: [[String: Any]] = []
        
        func searchRecursively(in directory: URL) {
            do {
                let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey
                ])
                
                for url in contents {
                    let fileName = url.lastPathComponent
                    
                    if fileName.localizedCaseInsensitiveContains(query) {
                        do {
                            let resourceValues = try url.resourceValues(forKeys: [
                                .isDirectoryKey,
                                .fileSizeKey,
                                .contentModificationDateKey
                            ])
                            
                            searchResults.append([
                                "name": fileName,
                                "path": url.path,
                                "size": resourceValues.fileSize ?? 0,
                                "isDirectory": resourceValues.isDirectory ?? false,
                                "lastModified": Int((resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000)
                            ])
                        } catch {
                            print("Error getting resource values for \(url.path): \(error)")
                        }
                    }
                    
                    // Recursively search subdirectories
                    if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        searchRecursively(in: url)
                    }
                }
            } catch {
                print("Error searching in directory \(directory.path): \(error)")
            }
        }
        
        searchRecursively(in: searchDirectory)
        result(searchResults)
    }
    
    private func handleGetStorageInfo(result: @escaping FlutterResult) {
        do {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            let resourceValues = try homeDirectory.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey
            ])
            
            let totalSpace = resourceValues.volumeTotalCapacity ?? 0
            let freeSpace = resourceValues.volumeAvailableCapacity ?? 0
            let usedSpace = totalSpace - freeSpace
            
            let storageInfo = [
                "totalSpace": totalSpace,
                "freeSpace": freeSpace,
                "usedSpace": usedSpace
            ]
            result(storageInfo)
        } catch {
            print("Error getting storage info: \(error)")
            result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - App Management Handlers (iOS equivalent of APK)
    
    private func handleGetInstalledApps(result: @escaping FlutterResult) {
        advancedFeaturesHandler.getInstalledApps(result: result)
    }
    
    private func handleExtractApp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        advancedFeaturesHandler.extractApp(call: call, result: result)
    }
    
    private func handleInstallApp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        advancedFeaturesHandler.installApp(call: call, result: result)
    }
    
    private func handleUninstallApp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Note: iOS doesn't allow uninstalling apps programmatically for security reasons
        // This would require special entitlements and App Store approval
        result(FlutterError(code: "NOT_SUPPORTED", message: "App uninstallation not supported on iOS", details: nil))
    }
    
    private func handleGetAppInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Note: iOS doesn't allow getting detailed app info for security reasons
        // This would require special entitlements and App Store approval
        result(FlutterError(code: "NOT_SUPPORTED", message: "App info not supported on iOS", details: nil))
    }
    
    private func handleGetExtractionHistory(result: @escaping FlutterResult) {
        // Note: iOS doesn't support app extraction, so no history
        result([])
    }
    
    private func handleDeleteFromHistory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Note: iOS doesn't support app extraction, so no history to delete
        result(true)
    }
    
    // MARK: - Cloud Sync Handlers
    
    private func handleConnectCloudProvider(call: FlutterMethodCall, result: @escaping FlutterResult) {
        advancedFeaturesHandler.connectCloudProvider(call: call, result: result)
    }
    
    private func handleDisconnectCloudProvider(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Disconnect is just a success response for now
        result(true)
    }
    
    private func handleUploadToCloud(call: FlutterMethodCall, result: @escaping FlutterResult) {
        advancedFeaturesHandler.uploadToCloud(call: call, result: result)
    }
    
    private func handleDownloadFromCloud(call: FlutterMethodCall, result: @escaping FlutterResult) {
        advancedFeaturesHandler.downloadFromCloud(call: call, result: result)
    }
    
    private func handleSyncCloud(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Sync is handled by iCloud automatically
        result(true)
    }
    
    private func handleGetCloudStorageInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iCloud storage info is not easily accessible
        let storageInfo = [
            "totalSpace": 0,
            "usedSpace": 0,
            "freeSpace": 0
        ]
        result(storageInfo)
    }
    
    // MARK: - Video Compression Handlers
    
    private func handleCompressVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native video compression
        let jobId = "compression_\(Date().timeIntervalSince1970)"
        result(jobId)
    }
    
    private func handleGetCompressionProgress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native compression progress
        let progress = [
            "progress": 0.0,
            "status": "pending"
        ]
        result(progress)
    }
    
    private func handleCancelCompression(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native compression cancellation
        result(true)
    }
    
    private func handleGetCompressionHistory(result: @escaping FlutterResult) {
        // TODO: Implement native compression history
        result([])
    }
    
    private func handleDeleteCompressionJob(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // TODO: Implement native compression job deletion
        result(true)
    }
    
    // MARK: - BLE Methods
    
    private func initializeBLE(result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(code: "UNAVAILABLE", message: "Bluetooth not available", details: nil))
            return
        }
        result("Bluetooth initialized")
    }
    
    private func startBLEAdvertising(result: @escaping FlutterResult) {
        guard peripheralManager.state == .poweredOn else {
            result(FlutterError(code: "UNAVAILABLE", message: "Bluetooth not available", details: nil))
            return
        }
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        service.characteristics = [characteristic]
        peripheralManager.add(service)
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "AirLink"
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        result("BLE advertising started")
    }
    
    private func stopBLEAdvertising(result: @escaping FlutterResult) {
        peripheralManager.stopAdvertising()
        result("BLE advertising stopped")
    }
    
    private func startBLEDiscovery(result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(code: "UNAVAILABLE", message: "Bluetooth not available", details: nil))
            return
        }
        
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        result("BLE discovery started")
    }
    
    private func stopBLEDiscovery(result: @escaping FlutterResult) {
        centralManager.stopScan()
        result("BLE discovery stopped")
    }
    
    private func checkBLESupport(result: @escaping FlutterResult) {
        let isSupported = centralManager.state == .poweredOn
        result(isSupported)
    }
    
    // MARK: - Network Discovery Methods
    
    private func startNetworkDiscovery(result: @escaping FlutterResult) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        networkBrowser = NWBrowser(for: .bonjourWithTXTRecord(type: "_airlink._tcp"), using: parameters)
        networkBrowser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Network browser ready")
            case .failed(let error):
                print("Network browser failed: \(error)")
            default:
                break
            }
        }
        
        networkBrowser?.browseResultsChangedHandler = { [weak self] results, changes in
            for result in results {
                if case .bonjour(let endpoint) = result.endpoint {
                    print("Discovered service: \(endpoint)")
                    self?.methodChannel.invokeMethod("onServiceDiscovered", arguments: [
                        "name": endpoint.name,
                        "type": endpoint.type
                    ])
                }
            }
        }
        
        networkBrowser?.start(queue: .main)
        result("Network discovery started")
    }
    
    private func stopNetworkDiscovery(result: @escaping FlutterResult) {
        networkBrowser?.cancel()
        networkBrowser = nil
        result("Network discovery stopped")
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .resetting:
            print("Bluetooth is resetting")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Bluetooth state is unknown")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        discoveredPeripherals.append(peripheral)
        
        // Emit unified discovery event
        let deviceInfo: [String: Any] = [
            "deviceId": "ble_\(peripheral.identifier.uuidString)",
            "deviceName": peripheral.name ?? "Unknown Device",
            "deviceType": "ios",
            "rssi": RSSI.intValue,
            "discoveryMethod": "ble",
            "metadata": [
                "deviceType": "ios",
                "discoveryMethod": "ble",
                "macAddress": peripheral.identifier.uuidString
            ],
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        sendEvent("discoveryUpdate", data: deviceInfo, service: "discovery")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        connectedPeripherals.append(peripheral)
        
        methodChannel.invokeMethod("onPeripheralConnected", arguments: [
            "name": peripheral.name ?? "Unknown",
            "identifier": peripheral.identifier.uuidString
        ])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
        
        methodChannel.invokeMethod("onPeripheralConnectionFailed", arguments: [
            "name": peripheral.name ?? "Unknown",
            "identifier": peripheral.identifier.uuidString,
            "error": error?.localizedDescription ?? "Unknown error"
        ])
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral manager is powered on")
        case .poweredOff:
            print("Peripheral manager is powered off")
        case .unauthorized:
            print("Peripheral manager is unauthorized")
        case .unsupported:
            print("Peripheral manager is unsupported")
        case .resetting:
            print("Peripheral manager is resetting")
        case .unknown:
            print("Peripheral manager state is unknown")
        @unknown default:
            print("Peripheral manager state is unknown")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed to start advertising: \(error.localizedDescription)")
        } else {
            print("Started advertising successfully")
        }
    }
    
    // MARK: - MultipeerConnectivity Methods
    
    private func startMultipeerAdvertising(result: @escaping FlutterResult) {
        guard advertiser == nil else {
            result("Multipeer advertising already active")
            return
        }
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "airlink")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        result("Multipeer advertising started")
    }
    
    private func stopMultipeerAdvertising(result: @escaping FlutterResult) {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        result("Multipeer advertising stopped")
    }
    
    private func startMultipeerBrowsing(result: @escaping FlutterResult) {
        guard multipeerBrowser == nil else {
            result("Multipeer browsing already active")
            return
        }
        
        multipeerBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: "airlink")
        multipeerBrowser.delegate = self
        multipeerBrowser.startBrowsingForPeers()
        
        result("Multipeer browsing started")
    }
    
    private func stopMultipeerBrowsing(result: @escaping FlutterResult) {
        multipeerBrowser?.stopBrowsingForPeers()
        multipeerBrowser = nil
        result("Multipeer browsing stopped")
    }
    
    private func checkMultipeerSupport(result: @escaping FlutterResult) {
        let isSupported = MCSession.self != nil
        result(isSupported)
    }
    
    // MARK: - MCNearbyServiceAdvertiserDelegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("Received invitation from peer: \(peerID.displayName)")
        
        // Accept invitation and connect
        invitationHandler(true, session)
        
        methodChannel.invokeMethod("onPeerInvitation", arguments: [
            "peerName": peerID.displayName,
            "peerID": peerID.hash
        ])
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error.localizedDescription)")
        
        methodChannel.invokeMethod("onAdvertisingError", arguments: [
            "error": error.localizedDescription
        ])
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate
    
    func browser(_ multipeerBrowser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        
        // Avoid duplicates
        if !connectedPeers.contains(peerID) {
            connectedPeers.append(peerID)
        }
        
        // Emit unified discovery event with enhanced metadata
        let deviceInfo: [String: Any] = [
            "deviceId": "multipeer_\(peerID.hash)",
            "deviceName": peerID.displayName,
            "deviceType": "ios",
            "discoveryMethod": "multipeer",
            "rssi": -50, // Estimated RSSI for MultipeerConnectivity
            "metadata": [
                "deviceType": "ios",
                "discoveryMethod": "multipeer",
                "peerID": peerID.hash,
                "displayName": peerID.displayName,
                "discoveryInfo": info ?? [:],
                "isConnected": false,
                "connectionState": "discovered"
            ],
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        sendEvent("discoveryUpdate", data: deviceInfo, service: "discovery")
    }
    
    func browser(_ multipeerBrowser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
        
        connectedPeers.removeAll { $0 == peerID }
        
        methodChannel.invokeMethod("onPeerLost", arguments: [
            "peerName": peerID.displayName,
            "peerID": peerID.hash
        ])
    }
    
    func browser(_ multipeerBrowser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing: \(error.localizedDescription)")
        
        methodChannel.invokeMethod("onBrowsingError", arguments: [
            "error": error.localizedDescription
        ])
    }
    
    // MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("Peer \(peerID.displayName) changed state to: \(state.rawValue)")
        
        switch state {
        case .connected:
            // Emit connectionReady for Multipeer
            sendEvent("connectionReady", data: [
                "deviceId": "multipeer_\(peerID.hash)",
                "connectionToken": "multipeer_\(peerID.hash)",
                "connectionMethod": "multipeer"
            ], service: "discovery")
            peerIdToToken[peerID.hash] = "multipeer_\(peerID.hash)"
            methodChannel.invokeMethod("onPeerConnected", arguments: [
                "peerName": peerID.displayName,
                "peerID": peerID.hash
            ])
        case .connecting:
            methodChannel.invokeMethod("onPeerConnecting", arguments: [
                "peerName": peerID.displayName,
                "peerID": peerID.hash
            ])
        case .notConnected:
            methodChannel.invokeMethod("onPeerDisconnected", arguments: [
                "peerName": peerID.displayName,
                "peerID": peerID.hash
            ])
        @unknown default:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("Received data from peer: \(peerID.displayName)")
        // Handle framed protocol: JSON meta (starts with '{'), binary frames: [type][transferIdLen][transferId][offset:8][dataLen:4][data] or ACK type 2
        if data.count > 0, data.first == 0x7B { // '{'
            // Meta JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String,
               type == "file_meta",
               let fileId = json["fileId"] as? String,
               let name = json["name"] as? String,
               let size = json["size"] as? NSNumber {
                // Prepare receive state
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dest = docs.appendingPathComponent(name)
                FileManager.default.createFile(atPath: dest.path, contents: nil)
                if let handle = try? FileHandle(forWritingTo: dest) {
                    receiveStates[fileId] = ReceiveState(fileId: fileId, expectedSize: size.int64Value, received: 0, fileURL: dest, handle: handle)
                    
                    // Audit logging - receive start
                    if AirLinkPlugin.AUDIT_MODE {
                        auditLogger.logTransferStart(transferId: fileId, fileSize: size.int64Value, method: "multipeer")
                        auditLogger.logSystemMetrics(transferId: fileId)
                    }
                }
            }
            return
        }
        // Otherwise parse binary
        var idx = 0
        guard data.count > 1 else { return }
        let frameType = data[idx]; idx += 1
        if frameType == 1 { // data frame
            guard data.count >= idx + 1 else { return }
            let idLen = Int(data[idx]); idx += 1
            guard data.count >= idx + idLen + 8 + 4 else { return }
            let idData = data.subdata(in: idx..<(idx+idLen)); idx += idLen
            let transferId = String(data: idData, encoding: .utf8) ?? ""
            let offset = data.subdata(in: idx..<(idx+8)).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }; idx += 8
            let dataLen = data.subdata(in: idx..<(idx+4)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }; idx += 4
            guard data.count >= idx + Int(dataLen) else { return }
            var payload = data.subdata(in: idx..<(idx+Int(dataLen)))
            // Decrypt if key set
            if let token = peerIdToToken[peerID.hash], let key = encryptionKeys[token] {
                if #available(iOS 13.0, *) {
                    do {
                        // CryptoKit combined: nonce(12)+cipher+tag(16)
                        let sealedBox = try AES.GCM.SealedBox(combined: payload)
                        let clear = try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
                        payload = Data(clear)
                    } catch {
                        // keep payload as is on failure
                    }
                }
            }
            if var state = receiveStates[transferId] {
                state.handle.seek(toFileOffset: offset)
                state.handle.write(payload)
                state.received += Int64(payload.count)
                receiveStates[transferId] = state
                // Send ack
                sendAck(for: transferId, offset: offset + UInt64(payload.count), to: peerID)
                // Audit logging - receive progress
                if AirLinkPlugin.AUDIT_MODE {
                    auditLogger.logTransferProgress(transferId: transferId, bytesTransferred: state.received, speed: 0.0)
                }
                
                // Progress
                sendEvent("transferProgress", data: [
                    "transferId": transferId,
                    "bytesTransferred": state.received,
                    "totalBytes": state.expectedSize,
                    "status": "receiving"
                ], service: "transfer")
                if state.expectedSize > 0 && state.received >= state.expectedSize {
                    state.handle.closeFile()
                    
                    // Audit logging - receive completion
                    if AirLinkPlugin.AUDIT_MODE {
                        let duration = Int64(Date().timeIntervalSince1970 * 1000) // Convert to milliseconds
                        auditLogger.logTransferComplete(transferId: transferId, duration: duration, checksum: nil)
                    }
                    
                    receiveStates.removeValue(forKey: transferId)
                    sendEvent("transferCompleted", data: ["transferId": transferId, "filePath": state.fileURL.path], service: "transfer")
                }
            }
        } else if frameType == 2 { // ack
            // [2][transferIdLen][transferId][offset:8]
            let idLen = Int(data[idx]); idx += 1
            let idData = data.subdata(in: idx..<(idx+idLen)); idx += idLen
            let transferId = String(data: idData, encoding: .utf8) ?? ""
            let _ = data.subdata(in: idx..<(idx+8)).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
            // we could use this to advance send window; simplified as MCSession is reliable
            if var st = sendStates[transferId] { st.lastAckAt = Date(); sendStates[transferId] = st }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("Received stream from peer: \(peerID.displayName)")
        
        methodChannel.invokeMethod("onStreamReceived", arguments: [
            "peerName": peerID.displayName,
            "peerID": peerID.hash,
            "streamName": streamName
        ])
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("Started receiving resource: \(resourceName) from peer: \(peerID.displayName)")
        
        // Set up progress monitoring for received resources
        progress.addObserver(self, forKeyPath: "fractionCompleted", options: [.new], context: nil)
        activeTransfers["\(peerID.hash)_\(resourceName)"] = progress
        
        sendEvent("transferStarted", data: [
            "peerId": "multipeer_\(peerID.hash)",
            "peerName": peerID.displayName,
            "resourceName": resourceName,
            "fractionCompleted": progress.fractionCompleted
        ], service: "transfer")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("Finished receiving resource: \(resourceName) from peer: \(peerID.displayName)")
        
        // Clean up progress monitoring
        let transferKey = "\(peerID.hash)_\(resourceName)"
        if let progress = activeTransfers[transferKey] {
            progress.removeObserver(self, forKeyPath: "fractionCompleted")
            activeTransfers.removeValue(forKey: transferKey)
        }
        
        if let error = error {
            sendEvent("transferFailed", data: [
                "peerId": "multipeer_\(peerID.hash)",
                "peerName": peerID.displayName,
                "resourceName": resourceName,
                "error": error.localizedDescription
            ], service: "transfer")
        } else if let localURL = localURL {
            // Move file to Documents directory for persistence
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsPath.appendingPathComponent(resourceName)
            
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Move file to Documents directory
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                sendEvent("transferCompleted", data: [
                    "peerId": "multipeer_\(peerID.hash)",
                    "peerName": peerID.displayName,
                    "resourceName": resourceName,
                    "localURL": destinationURL.absoluteString,
                    "filePath": destinationURL.path
                ], service: "transfer")
            } catch {
                sendEvent("transferFailed", data: [
                    "peerId": "multipeer_\(peerID.hash)",
                    "peerName": peerID.displayName,
                    "resourceName": resourceName,
                    "error": "Failed to move file to Documents directory: \(error.localizedDescription)"
                ], service: "transfer")
            }
        } else {
            sendEvent("transferFailed", data: [
                "peerId": "multipeer_\(peerID.hash)",
                "peerName": peerID.displayName,
                "resourceName": resourceName,
                "error": "No local URL provided"
            ], service: "transfer")
        }
    }
    
    // Service-specific method handlers
    private func handleDiscoveryMethod(_ method: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch method {
        case "startDiscovery":
            handleStartDiscovery(result: result)
        case "stopDiscovery":
            handleStopDiscovery(result: result)
        case "publishService":
            handlePublishService(call: call, result: result)
        case "subscribeService":
            handleSubscribeService(result: result)
        case "connectToPeer":
            handleConnectToPeer(call: call, result: result)
        case "createDatapath":
            handleCreateDatapath(call: call, result: result)
        case "closeDatapath":
            handleCloseDatapath(result: result)
        case "isWifiAwareSupported":
            result(false) // Wi-Fi Aware not available on iOS
        case "isBleSupported":
            checkBLESupport(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleTransferMethod(_ method: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch method {
        case "startTransfer":
            handleStartTransfer(call: call, result: result)
        case "pauseTransfer":
            handlePauseTransfer(call: call, result: result)
        case "resumeTransfer":
            handleResumeTransfer(call: call, result: result)
        case "cancelTransfer":
            handleCancelTransfer(call: call, result: result)
        case "getTransferProgress":
            handleGetTransferProgress(call: call, result: result)
        case "startBleFileTransfer":
            handleStartBleFileTransfer(call: call, result: result)
        case "startReceivingBleFile":
            handleStartReceivingBleFile(call: call, result: result)
        case "getBleTransferProgress":
            handleGetBleTransferProgress(call: call, result: result)
        case "cancelBleFileTransfer":
            handleCancelBleFileTransfer(call: call, result: result)
        case "sendResource":
            handleSendResource(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - BLE File Transfer (iOS) with AES-GCM
    private func handleStartBleFileTransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let connectionToken = args["connectionToken"] as? String,
              let filePath = args["filePath"] as? String,
              let transferId = args["transferId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "connectionToken, filePath, transferId required", details: nil))
            return
        }
        guard let peripheral = bleConnectedByToken[connectionToken],
              let characteristic = bleTargetCharacteristics[connectionToken] else {
            result(FlutterError(code: "BLE_NOT_READY", message: "BLE connection not ready for token", details: nil))
            return
        }
        let fileURL = URL(fileURLWithPath: filePath)
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            result(FlutterError(code: "FILE_ERROR", message: "Cannot open file", details: nil))
            return
        }
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? NSNumber)?.intValue ?? 0
        bleTransferProgress[transferId] = [
            "transferId": transferId,
            "bytesTransferred": 0,
            "totalBytes": fileSize,
            "status": "starting",
        ]
        let key = encryptionKeys[connectionToken]
        DispatchQueue.global(qos: .userInitiated).async {
            var sent: Int = 0
            let chunkSize = 180 // conservative BLE payload
            while true {
                autoreleasepool {
                    let data = fileHandle.readData(ofLength: chunkSize)
                    if data.count == 0 { break }
                    let payload: Data
                    if let key = key {
                        if #available(iOS 13.0, *) {
                            do {
                                let sealed = try AES.GCM.seal(data, using: SymmetricKey(data: key))
                                // nonce (12) + ciphertext + tag (16)
                                guard let combined = sealed.combined else { payload = data; return }
                                payload = combined
                            } catch {
                                payload = data
                            }
                        } else {
                            payload = data
                        }
                    } else {
                        payload = data
                    }
                    peripheral.writeValue(payload, for: characteristic, type: .withoutResponse)
                    sent += data.count
                    self.bleTransferProgress[transferId] = [
                        "transferId": transferId,
                        "bytesTransferred": sent,
                        "totalBytes": fileSize,
                        "status": "transferring",
                    ]
                    self.sendEvent("transferProgress", data: [
                        "transferId": transferId,
                        "fileId": transferId,
                        "bytesTransferred": sent,
                        "totalBytes": fileSize,
                        "status": "transferring",
                        "startedAt": ISO8601DateFormatter().string(from: Date()),
                        "speed": 0.0,
                    ], service: "transfer")
                }
            }
            fileHandle.closeFile()
            self.bleTransferProgress[transferId] = [
                "transferId": transferId,
                "bytesTransferred": fileSize,
                "totalBytes": fileSize,
                "status": "completed",
            ]
            self.sendEvent("transferCompleted", data: [
                "transferId": transferId,
            ], service: "transfer")
        }
        result(true)
    }

    private func handleStartReceivingBleFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Reception occurs via peripheralManager didReceiveWrite requests; here we just acknowledge
        result(true)
    }

    private func handleGetBleTransferProgress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transferId = args["transferId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "transferId is required", details: nil))
            return
        }
        let progress = bleTransferProgress[transferId] ?? [
            "transferId": transferId,
            "bytesTransferred": 0,
            "totalBytes": 0,
            "status": "not_found",
            "speed": 0.0,
        ]
        result(progress)
    }

    private func handleCancelBleFileTransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // No active cancellable operation in this simplified implementation
        result(true)
    }
    
    private func handleMediaMethod(_ method: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch method {
        case "playMedia":
            handlePlayMedia(call: call, result: result)
        case "pauseMedia":
            handlePauseMedia(result: result)
        case "stopMedia":
            handleStopMedia(result: result)
        case "seekMedia":
            handleSeekMedia(call: call, result: result)
        case "setVolume":
            handleSetVolume(call: call, result: result)
        case "setPlaybackSpeed":
            handleSetPlaybackSpeed(call: call, result: result)
        case "getMediaInfo":
            handleGetMediaInfo(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleFileMethod(_ method: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch method {
        case "selectFiles":
            handleSelectFiles(result: result)
        case "getFileInfo":
            handleGetFileInfo(call: call, result: result)
        case "deleteFile":
            handleDeleteFile(call: call, result: result)
        case "copyFile":
            handleCopyFile(call: call, result: result)
        case "moveFile":
            handleMoveFile(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Transfer Method Handlers
    
    private func handleStartTransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String,
              let peerId = args["peerId"] as? String,
              let transferId = args["transferId"] as? String? ?? "transfer_\(Int(Date().timeIntervalSince1970))" as String? else {
            result(FlutterError(code: "INVALID_ARGS", message: "filePath and peerId are required", details: nil))
            return
        }
        
        // Find the peer by ID
        guard let peer = connectedPeers.first(where: { "multipeer_\($0.hash)" == peerId }) else {
            result(FlutterError(code: "PEER_NOT_FOUND", message: "Peer not found: \(peerId)", details: nil))
            return
        }
        // Start chunked encrypted send over MCSession
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "File does not exist: \(filePath)", details: nil))
            return
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? NSNumber)?.int64Value ?? 0
        let tid = transferId ?? "transfer_\(Int(Date().timeIntervalSince1970))"
        sendStates[tid] = SendState(transferId: tid, filePath: filePath, totalBytes: size, sentBytes: 0, paused: false, cancelled: false)
        
        // Audit logging - transfer start
        if AirLinkPlugin.AUDIT_MODE {
            auditLogger.logTransferStart(transferId: tid, fileSize: size, method: "multipeer")
            auditLogger.logSystemMetrics(transferId: tid)
        }
        // Send meta JSON first
        let meta: [String: Any] = [
            "type": "file_meta",
            "fileId": tid,
            "name": fileURL.lastPathComponent,
            "size": size
        ]
        if let metaData = try? JSONSerialization.data(withJSONObject: meta) {
            try? session.send(metaData, toPeers: [peer], with: .reliable)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
            var offset: UInt64 = 0
            let chunkSize = 256 * 1024
            let token = self.peerIdToToken[peer.hash]
            while true {
                if var state = self.sendStates[tid], state.cancelled { break }
                if var state = self.sendStates[tid], state.paused { Thread.sleep(forTimeInterval: 0.1); continue }
                autoreleasepool {
                    let data = handle.readData(ofLength: chunkSize)
                    if data.count == 0 { break }
                    var payload = data
                    if let token = token, let key = self.encryptionKeys[token] {
                        if #available(iOS 13.0, *) {
                            do {
                                let sealed = try AES.GCM.seal(data, using: SymmetricKey(data: key))
                                if let combined = sealed.combined { payload = combined }
                            } catch { /* fallback to plaintext */ }
                        }
                    }
                    // Build frame
                    let idBytes = tid.data(using: .utf8) ?? Data()
                    var frame = Data()
                    frame.append(1) // type
                    frame.append(UInt8(idBytes.count))
                    frame.append(idBytes)
                    var offBE = offset.bigEndian
                    withUnsafeBytes(of: &offBE) { frame.append(contentsOf: $0) }
                    var lenBE = UInt32(payload.count).bigEndian
                    withUnsafeBytes(of: &lenBE) { frame.append(contentsOf: $0) }
                    frame.append(payload)
                    do {
                        try self.session.send(frame, toPeers: [peer], with: .reliable)
                        offset += UInt64(data.count)
                        if var st = self.sendStates[tid] { st.sentBytes = Int64(offset); self.sendStates[tid] = st }
                        
                        // Audit logging - transfer progress
                        if AirLinkPlugin.AUDIT_MODE {
                            let speed = Double(offset) / (Date().timeIntervalSince1970 - (st?.lastAckAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970))
                            self.auditLogger.logTransferProgress(transferId: tid, bytesTransferred: Int64(offset), speed: speed)
                        }
                        
                        self.sendEvent("transferProgress", data: [
                            "transferId": tid,
                            "bytesTransferred": Int64(offset),
                            "totalBytes": size,
                            "status": "transferring"
                        ], service: "transfer")
                    } catch { break }
                }
            }
            handle.closeFile()
            
            // Audit logging - transfer completion
            if AirLinkPlugin.AUDIT_MODE {
                let duration = Int64(Date().timeIntervalSince1970 * 1000) // Convert to milliseconds
                self.auditLogger.logTransferComplete(transferId: tid, duration: duration, checksum: nil)
            }
            
            self.sendStates.removeValue(forKey: tid)
            self.sendEvent("transferCompleted", data: ["transferId": tid], service: "transfer")
        }
        result(tid)
    }
    
    private func handlePauseTransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let transferId = args["transferId"] as? String else { result(false); return }
        if var st = sendStates[transferId] { st.paused = true; sendStates[transferId] = st; result(true) } else { result(false) }
    }
    
    private func handleResumeTransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let transferId = args["transferId"] as? String else { result(false); return }
        if var st = sendStates[transferId] { st.paused = false; sendStates[transferId] = st; result(true) } else { result(false) }
    }
    
    private func handleCancelTransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let transferId = args["transferId"] as? String else { result(false); return }
        if var st = sendStates[transferId] { st.cancelled = true; sendStates[transferId] = st; result(true) } else { result(false) }
    }
    
    private func handleGetTransferProgress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let transferId = args["transferId"] as? String else {
            result(["progress": 0.0, "status": "idle"]) ; return
        }
        if let st = sendStates[transferId] {
            let pct = st.totalBytes > 0 ? Double(st.sentBytes) / Double(st.totalBytes) : 0.0
            result(["bytesTransferred": st.sentBytes, "totalBytes": st.totalBytes, "progress": pct * 100.0, "status": st.paused ? "paused" : "transferring"]) ; return
        }
        result(["progress": 0.0, "status": "not_found"])        
    }
    
    private func handleSendResource(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String,
              let peerId = args["peerId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "filePath and peerId are required", details: nil))
            return
        }
        
        // Find the peer by ID
        guard let peer = connectedPeers.first(where: { "multipeer_\($0.hash)" == peerId }) else {
            result(FlutterError(code: "PEER_NOT_FOUND", message: "Peer not found: \(peerId)", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "File does not exist: \(filePath)", details: nil))
            return
        }
        
        // Send resource using MultipeerConnectivity
        let resourceName = fileURL.lastPathComponent
        let progress = session.sendResource(at: fileURL, withName: resourceName, toPeer: peer) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to send resource: \(error.localizedDescription)")
                    self?.sendEvent("transferFailed", data: [
                        "peerId": peerId,
                        "resourceName": resourceName,
                        "error": error.localizedDescription
                    ], service: "transfer")
                } else {
                    print("Resource sent successfully: \(resourceName)")
                    self?.sendEvent("transferCompleted", data: [
                        "peerId": peerId,
                        "resourceName": resourceName
                    ], service: "transfer")
                }
            }
        }
        
        // Set up progress monitoring
        progress.addObserver(self, forKeyPath: "fractionCompleted", options: [.new], context: nil)
        
        // Store progress for cleanup
        activeTransfers[peerId] = progress
        
        let transferId = "transfer_\(Date().timeIntervalSince1970)"
        result(transferId)
    }
    
    private func handleSelectFiles(result: @escaping FlutterResult) {
        // TODO: Implement file selection
        result([])
    }
    
    // MARK: - Transfer Progress Monitoring
    
    private var activeTransfers: [String: Progress] = [:]
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "fractionCompleted" {
            guard let progress = object as? Progress else { return }
            
            // Find the transfer by progress object
            for (transferKey, activeProgress) in activeTransfers {
                if activeProgress == progress {
                    let bytesTransferred = Int(progress.completedUnitCount)
                    let totalBytes = Int(progress.totalUnitCount)
                    let status = progress.fractionCompleted >= 1.0 ? "completed" : "inProgress"
                    
                    let progressData: [String: Any] = [
                        "transferId": transferKey,
                        "fileId": transferKey, // Use transferKey as fileId
                        "bytesTransferred": bytesTransferred,
                        "totalBytes": totalBytes,
                        "status": status,
                        "startedAt": ISO8601DateFormatter().string(from: Date()),
                        "speed": 0.0 // Speed calculation not available here
                    ]
                    
                    sendEvent("transferProgress", data: progressData, service: "transfer")
                    break
                }
            }
        }
    }
    
    // MARK: - Audit Evidence Collection Handlers
    
    private func handleGetStorageStatus(result: @escaping FlutterResult) {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])
            
            let availableBytes = values.volumeAvailableCapacityForImportantUsage ?? 0
            let totalBytes = values.volumeTotalCapacity ?? 0
            
            let storageStatus: [String: Any] = [
                "availableBytes": availableBytes,
                "totalBytes": totalBytes
            ]
            
            print("Storage status: \(availableBytes / (1024 * 1024)) MB available of \(totalBytes / (1024 * 1024)) MB total")
            result(storageStatus)
        } catch {
            print("Failed to get storage status: \(error.localizedDescription)")
            result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleGetCapabilities(result: @escaping FlutterResult) {
        // Check BLE support
        let bleSupported = CBCentralManager.authorization != .notDetermined
        let bleEnabled = centralManager.state == .poweredOn
        
        let capabilities: [String: Any] = [
            "wifiAwareAvailable": false, // iOS doesn't have Wi-Fi Aware
            "bleSupported": bleSupported,
            "bleEnabled": bleEnabled,
            "platform": "ios"
        ]
        
        print("Device capabilities: BLE=\(bleSupported)/\(bleEnabled)")
        result(capabilities)
    }
    
    private func handleCaptureScreenshot(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
            return
        }
        
        // Note: Screenshot capture on iOS requires access to the key window
        // This is a placeholder implementation that logs the request
        print("Screenshot capture requested but not fully implemented: \(path)")
        print("Screenshot capture requires UIGraphicsImageRenderer on key window")
        
        // Return false to indicate screenshot not captured
        // In a full implementation, this would use UIGraphicsImageRenderer
        result(false)
    }
    
    private func handleExportDeviceLogs(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let destDir = args["destDir"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "destDir is required", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .utility).async {
            do {
                let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
                let logFilePath = "\(destDir)/ios_logs_\(timestamp).txt"
                let logFileURL = URL(fileURLWithPath: logFilePath)
                
                var logContent = "iOS Device Logs\n"
                logContent += "Timestamp: \(ISO8601DateFormatter().string(from: Date()))\n"
                logContent += "Device: \(UIDevice.current.model)\n"
                logContent += "iOS Version: \(UIDevice.current.systemVersion)\n"
                logContent += "Device Name: \(UIDevice.current.name)\n"
                logContent += String(repeating: "=", count: 80) + "\n\n"
                
                // Get audit logs from the audit logger
                logContent += "Audit Logs:\n"
                logContent += self.auditLogger.getAllLogs()
                logContent += "\n"
                
                // Write to file
                try logContent.write(to: logFileURL, atomically: true, encoding: .utf8)
                
                print("Device logs exported: \(logFilePath)")
                DispatchQueue.main.async {
                    result([logFilePath])
                }
            } catch {
                print("Failed to export device logs: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOG_EXPORT_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleListTransferredFiles(result: @escaping FlutterResult) {
        var transferredFiles: [[String: Any]] = []
        
        // Collect files from send states
        for (transferId, state) in sendStates {
            let fileURL = URL(fileURLWithPath: state.filePath)
            if FileManager.default.fileExists(atPath: state.filePath) {
                transferredFiles.append([
                    "transferId": transferId,
                    "filePath": state.filePath,
                    "fileSize": state.totalBytes,
                    "status": state.cancelled ? "cancelled" : (state.paused ? "paused" : "completed")
                ])
            }
        }
        
        print("Listed \(transferredFiles.count) transferred files")
        result(transferredFiles)
    }
    
    // MARK: - BLE Transfer Handlers
    
    private func handleStartBLETransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        if let transferId = bleTransferManager?.startTransfer(params: args), !transferId.isEmpty {
            result(transferId)
        } else {
            result(FlutterError(code: "TRANSFER_START_FAILED", message: "Failed to start BLE transfer", details: nil))
        }
    }
    
    private func handlePauseBLETransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transferId = args["transferId"] as? String else {
            result(false)
            return
        }
        
        let success = bleTransferManager?.pauseTransfer(transferId: transferId) ?? false
        result(success)
    }
    
    private func handleResumeBLETransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transferId = args["transferId"] as? String else {
            result(false)
            return
        }
        
        let success = bleTransferManager?.resumeTransfer(transferId: transferId) ?? false
        result(success)
    }
    
    private func handleCancelBLETransfer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let transferId = args["transferId"] as? String else {
            result(false)
            return
        }
        
        bleTransferManager?.cancelTransfer(transferId: transferId)
        result(true)
    }
    
    private func handleSetEncryptionKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let connectionToken = args["connectionToken"] as? String,
              let keyBytes = args["key"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "connectionToken and key required", details: nil))
            return
        }
        
        encryptionKeys[connectionToken] = keyBytes.data
        result(true)
    }
}
