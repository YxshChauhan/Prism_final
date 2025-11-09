import Foundation
import MultipeerConnectivity
import Flutter

/// MultipeerConnectivity Transfer Manager
/// Handles file transfers using MultipeerConnectivity with proper session management,
/// progress tracking, and audit logging.
class MultipeerTransferManager: NSObject {
    private let serviceType = "airlink-xfer"
    private var peerID: MCPeerID
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    
    private var activeSessions: [String: TransferSession] = [:]
    private let sessionQueue = DispatchQueue(label: "com.airlink.multipeer.session")
    private let progressUpdateInterval: TimeInterval = 0.5
    
    private weak var methodChannel: FlutterMethodChannel?
    private weak var auditLogger: AuditLogger?
    
    // Transfer session structure
    private class TransferSession {
        let transferId: String
        let filePath: String
        let fileSize: Int64
        let peerDeviceId: String
        let connectionMethod: String
        var progress: Progress?
        var bytesTransferred: Int64 = 0
        var startTime: Date = Date()
        var isPaused: Bool = false
        var isCancelled: Bool = false
        var lastProgressUpdate: Date = Date()
        
        init(transferId: String, filePath: String, fileSize: Int64, peerDeviceId: String, connectionMethod: String) {
            self.transferId = transferId
            self.filePath = filePath
            self.fileSize = fileSize
            self.peerDeviceId = peerDeviceId
            self.connectionMethod = connectionMethod
        }
    }
    
    init(methodChannel: FlutterMethodChannel?, auditLogger: AuditLogger?) {
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.methodChannel = methodChannel
        self.auditLogger = auditLogger
        super.init()
        
        setupSession()
    }
    
    /// Setup MultipeerConnectivity session
    private func setupSession() {
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
        
        // Setup browser for discovering peers
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        
        // Setup advertiser for being discovered
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        
        NSLog("[MultipeerTransferManager] Session setup completed")
    }
    
    /// Start browsing for peers
    func startBrowsing() {
        browser?.startBrowsingForPeers()
        advertiser?.startAdvertisingPeer()
        NSLog("[MultipeerTransferManager] Started browsing and advertising")
    }
    
    /// Stop browsing for peers
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        NSLog("[MultipeerTransferManager] Stopped browsing and advertising")
    }
    
    /// Start a MultipeerConnectivity transfer
    /// - Parameter params: Transfer parameters including transferId, filePath, fileSize, deviceId, connectionMethod
    /// - Returns: Transfer ID on success, empty string on failure
    func startTransfer(params: [String: Any]) -> String {
        guard let transferId = params["transferId"] as? String,
              let filePath = params["filePath"] as? String,
              let fileSize = params["fileSize"] as? Int64,
              let deviceId = params["deviceId"] as? String else {
            NSLog("[MultipeerTransferManager] Invalid transfer parameters")
            return ""
        }
        
        let connectionMethod = params["connectionMethod"] as? String ?? "multipeer"
        
        NSLog("[MultipeerTransferManager] Starting transfer: \(transferId)")
        auditLogger?.logEvent("transfer_start", data: [
            "transferId": transferId,
            "fileSize": fileSize,
            "connectionMethod": connectionMethod
        ])
        
        // Validate file exists
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            NSLog("[MultipeerTransferManager] File not found: \(filePath)")
            return ""
        }
        
        // Create transfer session
        let transferSession = TransferSession(
            transferId: transferId,
            filePath: filePath,
            fileSize: fileSize,
            peerDeviceId: deviceId,
            connectionMethod: connectionMethod
        )
        
        sessionQueue.async { [weak self] in
            self?.activeSessions[transferId] = transferSession
            self?.executeTransfer(session: transferSession, fileURL: fileURL)
        }
        
        return transferId
    }
    
    /// Execute the actual file transfer
    private func executeTransfer(session transferSession: TransferSession, fileURL: URL) {
        guard let mcSession = self.session,
              !mcSession.connectedPeers.isEmpty else {
            NSLog("[MultipeerTransferManager] No connected peers")
            handleTransferError(session: transferSession, error: NSError(domain: "MultipeerTransferManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No connected peers"]))
            return
        }
        
        // Check if this is a multi-receiver transfer (indicated by targetPeerIds in metadata)
        if let targetPeerIds = transferSession.metadata?["targetPeerIds"] as? [String], targetPeerIds.count > 1 {
            executeMultiReceiverTransfer(session: transferSession, fileURL: fileURL, targetPeerIds: targetPeerIds)
        } else {
            executeSingleReceiverTransfer(session: transferSession, fileURL: fileURL)
        }
    }
    
    /// Execute single receiver transfer (original behavior)
    private func executeSingleReceiverTransfer(session transferSession: TransferSession, fileURL: URL) {
        guard let mcSession = self.session else { return }
        
        // Use first connected peer for single transfer
        let targetPeer = mcSession.connectedPeers.first!
        
        NSLog("[MultipeerTransferManager] Sending file to peer: \(targetPeer.displayName)")
        auditLogger?.logEvent("connection_established", data: [
            "transferId": transferSession.transferId,
            "peerName": targetPeer.displayName
        ])
        
        // Send resource with progress tracking
        let progress = mcSession.sendResource(at: fileURL, withName: fileURL.lastPathComponent, toPeer: targetPeer) { error in
            if let error = error {
                NSLog("[MultipeerTransferManager] Transfer failed: \(error.localizedDescription)")
                self.handleTransferError(session: transferSession, error: error)
            } else {
                NSLog("[MultipeerTransferManager] Transfer completed: \(transferSession.transferId)")
                self.handleTransferComplete(session: transferSession)
            }
        }
        
        transferSession.progress = progress
        observeProgress(for: transferSession, progress: progress)
    }
    
    /// Execute multi-receiver transfer (send to multiple peers simultaneously)
    private func executeMultiReceiverTransfer(session transferSession: TransferSession, fileURL: URL, targetPeerIds: [String]) {
        guard let mcSession = self.session else { return }
        
        NSLog("[MultipeerTransferManager] Multi-receiver transfer to \(targetPeerIds.count) peers")
        
        // Filter connected peers by target IDs
        let targetPeers = mcSession.connectedPeers.filter { peer in
            targetPeerIds.contains(peer.displayName)
        }
        
        guard !targetPeers.isEmpty else {
            NSLog("[MultipeerTransferManager] No target peers connected")
            handleTransferError(session: transferSession, error: NSError(domain: "MultipeerTransferManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Target peers not connected"]))
            return
        }
        
        var completedPeers = [String]()
        var failedPeers = [(String, Error)]()
        let completionLock = NSLock()
        
        // Send to each peer
        for peer in targetPeers {
            let peerTransferId = "\(transferSession.transferId)_\(peer.displayName)"
            
            NSLog("[MultipeerTransferManager] Sending file to peer: \(peer.displayName)")
            auditLogger?.logEvent("multi_receiver_peer_start", data: [
                "transferId": peerTransferId,
                "peerName": peer.displayName,
                "totalPeers": targetPeers.count
            ])
            
            let progress = mcSession.sendResource(at: fileURL, withName: fileURL.lastPathComponent, toPeer: peer) { error in
                completionLock.lock()
                defer { completionLock.unlock() }
                
                if let error = error {
                    NSLog("[MultipeerTransferManager] Transfer to \(peer.displayName) failed: \(error.localizedDescription)")
                    failedPeers.append((peer.displayName, error))
                } else {
                    NSLog("[MultipeerTransferManager] Transfer to \(peer.displayName) completed")
                    completedPeers.append(peer.displayName)
                }
                
                // Check if all peers completed (success or failure)
                if completedPeers.count + failedPeers.count == targetPeers.count {
                    self.handleMultiReceiverComplete(
                        session: transferSession,
                        completedPeers: completedPeers,
                        failedPeers: failedPeers
                    )
                }
            }
            
            // Observe progress for first peer (aggregated progress tracking would be more complex)
            if transferSession.progress == nil {
                transferSession.progress = progress
                observeProgress(for: transferSession, progress: progress)
            }
        }
    }
    
    /// Handle multi-receiver transfer completion
    private func handleMultiReceiverComplete(session: TransferSession, completedPeers: [String], failedPeers: [(String, Error)]) {
        auditLogger?.logEvent("multi_receiver_complete", data: [
            "transferId": session.transferId,
            "completedCount": completedPeers.count,
            "failedCount": failedPeers.count,
            "completedPeers": completedPeers,
            "failedPeers": failedPeers.map { $0.0 }
        ])
        
        // Consider transfer successful if at least one peer succeeded
        if !completedPeers.isEmpty {
            NSLog("[MultipeerTransferManager] Multi-receiver transfer completed: \(completedPeers.count) succeeded, \(failedPeers.count) failed")
            
            // Update session metadata with results
            var metadata = session.metadata ?? [:]
            metadata["completedPeers"] = completedPeers
            metadata["failedPeers"] = failedPeers.map { $0.0 }
            metadata["successRate"] = Double(completedPeers.count) / Double(completedPeers.count + failedPeers.count)
            session.metadata = metadata
            
            handleTransferComplete(session: session)
        } else {
            // All peers failed
            let error = NSError(domain: "MultipeerTransferManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "All \(failedPeers.count) peer transfers failed"
            ])
            handleTransferError(session: session, error: error)
        }
    }
    
    /// Observe transfer progress
    private func observeProgress(for session: TransferSession, progress: Progress) {
        let observation = progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            self?.sessionQueue.async {
                guard let self = self,
                      let transferSession = self.activeSessions[session.transferId] else { return }
                
                // Update bytes transferred
                transferSession.bytesTransferred = Int64(progress.completedUnitCount)
                
                // Emit progress updates at intervals
                let now = Date()
                if now.timeIntervalSince(transferSession.lastProgressUpdate) >= self.progressUpdateInterval {
                    self.emitProgress(for: transferSession)
                    transferSession.lastProgressUpdate = now
                }
            }
        }
        
        // Keep observation alive
        objc_setAssociatedObject(progress, "observation", observation, .OBJC_ASSOCIATION_RETAIN)
    }
    
    /// Emit progress update to Flutter
    private func emitProgress(for session: TransferSession) {
        let progressPercent = session.fileSize > 0 ? Int((Double(session.bytesTransferred) / Double(session.fileSize)) * 100) : 0
        
        let elapsedTime = Date().timeIntervalSince(session.startTime)
        let speed = elapsedTime > 0 ? Int64(Double(session.bytesTransferred) / elapsedTime) : 0
        
        methodChannel?.invokeMethod("onTransferProgress", arguments: [
            "transferId": session.transferId,
            "progress": progressPercent,
            "bytesTransferred": session.bytesTransferred,
            "totalBytes": session.fileSize,
            "speed": speed
        ])
        
        auditLogger?.logMetric("transfer_progress", data: [
            "transferId": session.transferId,
            "progress": progressPercent,
            "speed": speed
        ])
    }
    
    /// Handle transfer completion
    private func handleTransferComplete(session: TransferSession) {
        NSLog("[MultipeerTransferManager] Transfer completed: \(session.transferId)")
        
        let duration = Date().timeIntervalSince(session.startTime)
        let avgSpeed = duration > 0 ? Int64(Double(session.fileSize) / duration) : 0
        
        methodChannel?.invokeMethod("onTransferComplete", arguments: [
            "transferId": session.transferId,
            "success": true,
            "bytesTransferred": session.bytesTransferred,
            "duration": Int(duration * 1000),
            "averageSpeed": avgSpeed
        ])
        
        auditLogger?.logEvent("transfer_complete", data: [
            "transferId": session.transferId,
            "fileSize": session.fileSize,
            "duration": Int(duration * 1000),
            "averageSpeed": avgSpeed
        ])
        
        sessionQueue.async { [weak self] in
            self?.activeSessions.removeValue(forKey: session.transferId)
        }
    }
    
    /// Handle transfer error
    private func handleTransferError(session: TransferSession, error: Error) {
        NSLog("[MultipeerTransferManager] Transfer error: \(session.transferId) - \(error.localizedDescription)")
        
        methodChannel?.invokeMethod("onTransferError", arguments: [
            "transferId": session.transferId,
            "error": error.localizedDescription,
            "bytesTransferred": session.bytesTransferred
        ])
        
        auditLogger?.logEvent("transfer_error", data: [
            "transferId": session.transferId,
            "error": error.localizedDescription,
            "bytesTransferred": session.bytesTransferred
        ])
        
        sessionQueue.async { [weak self] in
            self?.activeSessions.removeValue(forKey: session.transferId)
        }
    }
    
    /// Stop an active transfer
    /// - Parameter transferId: Transfer ID to stop
    func stopTransfer(transferId: String) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.activeSessions[transferId] else { return }
            
            NSLog("[MultipeerTransferManager] Stopping transfer: \(transferId)")
            session.isCancelled = true
            session.progress?.cancel()
            
            self.methodChannel?.invokeMethod("onTransferCancelled", arguments: [
                "transferId": transferId,
                "bytesTransferred": session.bytesTransferred
            ])
            
            self.auditLogger?.logEvent("transfer_cancelled", data: [
                "transferId": transferId,
                "bytesTransferred": session.bytesTransferred
            ])
            
            self.activeSessions.removeValue(forKey: transferId)
        }
    }
    
    /// Pause a transfer
    func pauseTransfer(transferId: String) -> Bool {
        var result = false
        sessionQueue.sync {
            if let session = activeSessions[transferId] {
                session.isPaused = true
                session.progress?.pause()
                NSLog("[MultipeerTransferManager] Transfer paused: \(transferId)")
                result = true
            }
        }
        return result
    }
    
    /// Resume a paused transfer
    func resumeTransfer(transferId: String) -> Bool {
        var result = false
        sessionQueue.sync {
            if let session = activeSessions[transferId] {
                session.isPaused = false
                session.progress?.resume()
                NSLog("[MultipeerTransferManager] Transfer resumed: \(transferId)")
                result = true
            }
        }
        return result
    }
    
    /// Get active transfer count
    func getActiveTransferCount() -> Int {
        var count = 0
        sessionQueue.sync {
            count = activeSessions.count
        }
        return count
    }
    
    /// Get transfer status
    func getTransferStatus(transferId: String) -> [String: Any]? {
        var status: [String: Any]?
        sessionQueue.sync {
            if let session = activeSessions[transferId] {
                let progressPercent = session.fileSize > 0 ? Int((Double(session.bytesTransferred) / Double(session.fileSize)) * 100) : 0
                status = [
                    "transferId": session.transferId,
                    "progress": progressPercent,
                    "bytesTransferred": session.bytesTransferred,
                    "totalBytes": session.fileSize,
                    "isPaused": session.isPaused,
                    "isCancelled": session.isCancelled
                ]
            }
        }
        return status
    }
    
    /// Cleanup all resources
    func dispose() {
        NSLog("[MultipeerTransferManager] Disposing")
        stopBrowsing()
        
        sessionQueue.sync {
            activeSessions.values.forEach { $0.progress?.cancel() }
            activeSessions.removeAll()
        }
        
        session?.disconnect()
        session = nil
    }
}

// MARK: - MCSessionDelegate
extension MultipeerTransferManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("[MultipeerTransferManager] Peer \(peerID.displayName) changed state: \(state.rawValue)")
        
        switch state {
        case .connected:
            NSLog("[MultipeerTransferManager] Connected to peer: \(peerID.displayName)")
        case .connecting:
            NSLog("[MultipeerTransferManager] Connecting to peer: \(peerID.displayName)")
        case .notConnected:
            NSLog("[MultipeerTransferManager] Disconnected from peer: \(peerID.displayName)")
        @unknown default:
            NSLog("[MultipeerTransferManager] Unknown state for peer: \(peerID.displayName)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle received data if needed
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle received stream if needed
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("[MultipeerTransferManager] Started receiving resource: \(resourceName) from \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            NSLog("[MultipeerTransferManager] Error receiving resource: \(error.localizedDescription)")
        } else {
            NSLog("[MultipeerTransferManager] Finished receiving resource: \(resourceName)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerTransferManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("[MultipeerTransferManager] Found peer: \(peerID.displayName)")
        // Auto-invite peer
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("[MultipeerTransferManager] Lost peer: \(peerID.displayName)")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerTransferManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("[MultipeerTransferManager] Received invitation from peer: \(peerID.displayName)")
        // Auto-accept invitation
        invitationHandler(true, session)
    }
}


