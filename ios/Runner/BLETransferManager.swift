import Foundation
import CoreBluetooth
import Flutter

/// BLE Transfer Manager for iOS - Cross-platform compatibility with Android
/// Implements file transfer over Bluetooth Low Energy for iOS↔Android transfers
class BLETransferManager: NSObject {
    
    // MARK: - Constants
    private static let SERVICE_UUID = CBUUID(string: "0000FE00-0000-1000-8000-00805F9B34FB")
    private static let CHAR_FILE_META_UUID = CBUUID(string: "0000FE01-0000-1000-8000-00805F9B34FB")
    private static let CHAR_FILE_DATA_UUID = CBUUID(string: "0000FE02-0000-1000-8000-00805F9B34FB")
    private static let CHAR_CONTROL_UUID = CBUUID(string: "0000FE03-0000-1000-8000-00805F9B34FB")
    private static let DEVICE_INFO_UUID = CBUUID(string: "0000FE04-0000-1000-8000-00805F9B34FB")
    
    private static let MTU_SIZE = 512 // BLE MTU size
    private static let CHUNK_SIZE = 480 // Leave room for headers
    
    // MARK: - Properties
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var activeSessions: [String: BLETransferSession] = [:]
    
    private weak var methodChannel: FlutterMethodChannel?
    private weak var auditLogger: AuditLogger?
    
    private let sessionQueue = DispatchQueue(label: "com.airlink.ble.session")
    private var isScanning = false
    private var isAdvertising = false
    
    // Characteristics for peripheral mode
    private var fileMetaCharacteristic: CBMutableCharacteristic?
    private var fileDataCharacteristic: CBMutableCharacteristic?
    private var controlCharacteristic: CBMutableCharacteristic?
    private var deviceInfoCharacteristic: CBMutableCharacteristic?
    
    // MARK: - Transfer Session
    private class BLETransferSession {
        let transferId: String
        let filePath: String
        let fileSize: Int64
        let peerDeviceId: String
        var peripheral: CBPeripheral?
        var bytesTransferred: Int64 = 0
        var startTime: Date = Date()
        var isPaused: Bool = false
        var isCancelled: Bool = false
        var resumeOffset: Int64 = 0
        var fileHandle: FileHandle?
        var characteristics: [CBUUID: CBCharacteristic] = [:]
        
        init(transferId: String, filePath: String, fileSize: Int64, peerDeviceId: String) {
            self.transferId = transferId
            self.filePath = filePath
            self.fileSize = fileSize
            self.peerDeviceId = peerDeviceId
        }
    }
    
    // MARK: - Initialization
    init(methodChannel: FlutterMethodChannel?, auditLogger: AuditLogger?) {
        self.methodChannel = methodChannel
        self.auditLogger = auditLogger
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Initialize BLE manager (call after object creation)
    func initialize() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        NSLog("[BLETransferManager] Initialized")
    }
    
    /// Start scanning for BLE devices
    func startScanning() -> Bool {
        guard let central = centralManager, central.state == .poweredOn else {
            NSLog("[BLETransferManager] Bluetooth not ready")
            return false
        }
        
        central.scanForPeripherals(
            withServices: [BLETransferManager.SERVICE_UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
        NSLog("[BLETransferManager] Started scanning")
        return true
    }
    
    /// Stop scanning
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        NSLog("[BLETransferManager] Stopped scanning")
    }
    
    /// Start advertising as BLE peripheral
    func startAdvertising(metadata: [String: Any]) -> Bool {
        guard let peripheral = peripheralManager, peripheral.state == .poweredOn else {
            NSLog("[BLETransferManager] Peripheral manager not ready")
            return false
        }
        
        // Setup GATT services
        setupPeripheralServices()
        
        // Start advertising
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BLETransferManager.SERVICE_UUID],
            CBAdvertisementDataLocalNameKey: UIDevice.current.name
        ]
        
        peripheral.startAdvertising(advertisementData)
        isAdvertising = true
        NSLog("[BLETransferManager] Started advertising")
        return true
    }
    
    /// Stop advertising
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        NSLog("[BLETransferManager] Stopped advertising")
    }
    
    /// Connect to a discovered peripheral
    func connectToPeripheral(deviceId: String) -> String {
        let connectionToken = "ble_\(Int(Date().timeIntervalSince1970))"
        
        // Find peripheral by device ID
        if let peripheral = discoveredPeripherals.values.first(where: { $0.identifier.uuidString == deviceId }) {
            centralManager?.connect(peripheral, options: nil)
            connectedPeripherals[peripheral.identifier] = peripheral
            NSLog("[BLETransferManager] Connecting to peripheral: \(deviceId)")
        } else {
            NSLog("[BLETransferManager] Peripheral not found: \(deviceId)")
        }
        
        return connectionToken
    }
    
    /// Start BLE file transfer
    func startTransfer(params: [String: Any]) -> String {
        guard let transferId = params["transferId"] as? String,
              let filePath = params["filePath"] as? String,
              let fileSize = params["fileSize"] as? Int64,
              let deviceId = params["deviceId"] as? String else {
            NSLog("[BLETransferManager] Invalid transfer parameters")
            return ""
        }
        
        NSLog("[BLETransferManager] Starting transfer: \(transferId)")
        auditLogger?.logEvent("ble_transfer_start", data: [
            "transferId": transferId,
            "fileSize": fileSize,
            "deviceId": deviceId
        ])
        
        // Validate file exists
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            NSLog("[BLETransferManager] File not found: \(filePath)")
            return ""
        }
        
        // Create transfer session
        let session = BLETransferSession(
            transferId: transferId,
            filePath: filePath,
            fileSize: fileSize,
            peerDeviceId: deviceId
        )
        
        // Find connected peripheral for this device
        if let peripheral = connectedPeripherals.values.first(where: { $0.identifier.uuidString == deviceId }) {
            session.peripheral = peripheral
        }
        
        sessionQueue.async { [weak self] in
            self?.activeSessions[transferId] = session
            self?.executeTransfer(session: session)
        }
        
        return transferId
    }
    
    /// Pause transfer
    func pauseTransfer(transferId: String) -> Bool {
        var result = false
        sessionQueue.sync {
            if let session = activeSessions[transferId] {
                session.isPaused = true
                session.resumeOffset = session.bytesTransferred
                NSLog("[BLETransferManager] Transfer paused: \(transferId) at \(session.bytesTransferred) bytes")
                result = true
            }
        }
        return result
    }
    
    /// Resume transfer
    func resumeTransfer(transferId: String) -> Bool {
        var result = false
        sessionQueue.sync {
            if let session = activeSessions[transferId] {
                session.isPaused = false
                NSLog("[BLETransferManager] Transfer resumed: \(transferId) from \(session.resumeOffset) bytes")
                result = true
            }
        }
        return result
    }
    
    /// Cancel transfer
    func cancelTransfer(transferId: String) {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.activeSessions[transferId] else { return }
            
            session.isCancelled = true
            session.fileHandle?.closeFile()
            
            self.methodChannel?.invokeMethod("onTransferCancelled", arguments: [
                "transferId": transferId,
                "bytesTransferred": session.bytesTransferred
            ])
            
            self.activeSessions.removeValue(forKey: transferId)
            NSLog("[BLETransferManager] Transfer cancelled: \(transferId)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupPeripheralServices() {
        // Create service
        let service = CBMutableService(type: BLETransferManager.SERVICE_UUID, primary: true)
        
        // File metadata characteristic
        fileMetaCharacteristic = CBMutableCharacteristic(
            type: BLETransferManager.CHAR_FILE_META_UUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // File data characteristic
        fileDataCharacteristic = CBMutableCharacteristic(
            type: BLETransferManager.CHAR_FILE_DATA_UUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Control characteristic (pause/resume/cancel)
        controlCharacteristic = CBMutableCharacteristic(
            type: BLETransferManager.CHAR_CONTROL_UUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Device info characteristic
        deviceInfoCharacteristic = CBMutableCharacteristic(
            type: BLETransferManager.DEVICE_INFO_UUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        
        service.characteristics = [
            fileMetaCharacteristic!,
            fileDataCharacteristic!,
            controlCharacteristic!,
            deviceInfoCharacteristic!
        ]
        
        peripheralManager?.add(service)
        NSLog("[BLETransferManager] GATT service configured")
    }
    
    private func executeTransfer(session: BLETransferSession) {
        guard let peripheral = session.peripheral else {
            NSLog("[BLETransferManager] No peripheral for transfer: \(session.transferId)")
            handleTransferError(session: session, error: NSError(
                domain: "BLETransferManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No connected peripheral"]
            ))
            return
        }
        
        // Open file for reading
        let fileURL = URL(fileURLWithPath: session.filePath)
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            NSLog("[BLETransferManager] Cannot open file: \(session.filePath)")
            handleTransferError(session: session, error: NSError(
                domain: "BLETransferManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Cannot open file"]
            ))
            return
        }
        
        session.fileHandle = fileHandle
        
        // Send file metadata first
        sendFileMetadata(session: session, peripheral: peripheral)
        
        // Start sending file data in chunks
        sendNextChunk(session: session, peripheral: peripheral)
    }
    
    private func sendFileMetadata(session: BLETransferSession, peripheral: CBPeripheral) {
        let fileURL = URL(fileURLWithPath: session.filePath)
        let metadata: [String: Any] = [
            "type": "file_meta",
            "transferId": session.transferId,
            "fileName": fileURL.lastPathComponent,
            "fileSize": session.fileSize,
            "offset": session.resumeOffset
        ]
        
        if let metaData = try? JSONSerialization.data(withJSONObject: metadata),
           let characteristic = session.characteristics[BLETransferManager.CHAR_FILE_META_UUID] {
            peripheral.writeValue(metaData, for: characteristic, type: .withResponse)
            NSLog("[BLETransferManager] Sent file metadata for \(session.transferId)")
        }
    }
    
    private func sendNextChunk(session: BLETransferSession, peripheral: CBPeripheral) {
        guard !session.isCancelled, !session.isPaused else { return }
        guard let fileHandle = session.fileHandle else { return }
        
        // Seek to resume offset if needed
        if session.bytesTransferred == 0 && session.resumeOffset > 0 {
            fileHandle.seek(toFileOffset: UInt64(session.resumeOffset))
            session.bytesTransferred = session.resumeOffset
        }
        
        // Read next chunk
        let chunkData = fileHandle.readData(ofLength: BLETransferManager.CHUNK_SIZE)
        
        if chunkData.isEmpty {
            // Transfer complete
            fileHandle.closeFile()
            handleTransferComplete(session: session)
            return
        }
        
        // Write chunk to BLE characteristic
        if let characteristic = session.characteristics[BLETransferManager.CHAR_FILE_DATA_UUID] {
            peripheral.writeValue(chunkData, for: characteristic, type: .withResponse)
            session.bytesTransferred += Int64(chunkData.count)
            
            // Emit progress
            emitProgress(for: session)
            
            // Schedule next chunk (with small delay to avoid overwhelming BLE)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.sendNextChunk(session: session, peripheral: peripheral)
            }
        }
    }
    
    private func emitProgress(for session: BLETransferSession) {
        let progress = session.fileSize > 0 ? Int((Double(session.bytesTransferred) / Double(session.fileSize)) * 100) : 0
        let elapsedTime = Date().timeIntervalSince(session.startTime)
        let speed = elapsedTime > 0 ? Int64(Double(session.bytesTransferred) / elapsedTime) : 0
        
        methodChannel?.invokeMethod("onTransferProgress", arguments: [
            "transferId": session.transferId,
            "progress": progress,
            "bytesTransferred": session.bytesTransferred,
            "totalBytes": session.fileSize,
            "speed": speed,
            "connectionMethod": "ble"
        ])
        
        auditLogger?.logMetric("ble_transfer_progress", data: [
            "transferId": session.transferId,
            "progress": progress,
            "speed": speed
        ])
    }
    
    private func handleTransferComplete(session: BLETransferSession) {
        let duration = Date().timeIntervalSince(session.startTime)
        let avgSpeed = duration > 0 ? Int64(Double(session.fileSize) / duration) : 0
        
        NSLog("[BLETransferManager] Transfer completed: \(session.transferId)")
        
        methodChannel?.invokeMethod("onTransferComplete", arguments: [
            "transferId": session.transferId,
            "success": true,
            "bytesTransferred": session.bytesTransferred,
            "duration": Int(duration * 1000),
            "averageSpeed": avgSpeed,
            "connectionMethod": "ble"
        ])
        
        auditLogger?.logEvent("ble_transfer_complete", data: [
            "transferId": session.transferId,
            "fileSize": session.fileSize,
            "duration": Int(duration * 1000),
            "averageSpeed": avgSpeed
        ])
        
        sessionQueue.async { [weak self] in
            self?.activeSessions.removeValue(forKey: session.transferId)
        }
    }
    
    private func handleTransferError(session: BLETransferSession, error: Error) {
        NSLog("[BLETransferManager] Transfer error: \(session.transferId) - \(error.localizedDescription)")
        
        methodChannel?.invokeMethod("onTransferError", arguments: [
            "transferId": session.transferId,
            "error": error.localizedDescription,
            "bytesTransferred": session.bytesTransferred,
            "connectionMethod": "ble"
        ])
        
        auditLogger?.logEvent("ble_transfer_error", data: [
            "transferId": session.transferId,
            "error": error.localizedDescription
        ])
        
        sessionQueue.async { [weak self] in
            self?.activeSessions.removeValue(forKey: session.transferId)
        }
    }
    
    /// Cleanup resources
    func dispose() {
        stopScanning()
        stopAdvertising()
        
        sessionQueue.sync {
            activeSessions.values.forEach { $0.fileHandle?.closeFile() }
            activeSessions.removeAll()
        }
        
        connectedPeripherals.values.forEach { peripheral in
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripherals.removeAll()
        
        NSLog("[BLETransferManager] Disposed")
    }
}

// MARK: - CBCentralManagerDelegate
extension BLETransferManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            NSLog("[BLETransferManager] Central powered on")
            if isScanning {
                startScanning()
            }
        case .poweredOff:
            NSLog("[BLETransferManager] Central powered off")
        case .unauthorized:
            NSLog("[BLETransferManager] Central unauthorized")
        case .unsupported:
            NSLog("[BLETransferManager] BLE unsupported")
        default:
            NSLog("[BLETransferManager] Central state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        NSLog("[BLETransferManager] Discovered peripheral: \(peripheral.name ?? "Unknown")")
        
        discoveredPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        
        // Notify Flutter
        methodChannel?.invokeMethod("onDeviceDiscovered", arguments: [
            "deviceId": peripheral.identifier.uuidString,
            "deviceName": peripheral.name ?? "BLE Device",
            "deviceType": "ios",
            "discoveryMethod": "ble",
            "rssi": RSSI.intValue,
            "connectionMethod": "ble"
        ])
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("[BLETransferManager] Connected to peripheral: \(peripheral.name ?? "Unknown")")
        
        connectedPeripherals[peripheral.identifier] = peripheral
        peripheral.discoverServices([BLETransferManager.SERVICE_UUID])
        
        methodChannel?.invokeMethod("onPeerConnected", arguments: [
            "deviceId": peripheral.identifier.uuidString,
            "deviceName": peripheral.name ?? "BLE Device",
            "connectionMethod": "ble"
        ])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLETransferManager] Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        
        methodChannel?.invokeMethod("onPeerDisconnected", arguments: [
            "deviceId": peripheral.identifier.uuidString,
            "error": error?.localizedDescription ?? ""
        ])
    }
}

// MARK: - CBPeripheralDelegate
extension BLETransferManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            NSLog("[BLETransferManager] Error discovering services: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        for service in services where service.uuid == BLETransferManager.SERVICE_UUID {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            NSLog("[BLETransferManager] Error discovering characteristics: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        // Store characteristics for active sessions
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            for session in self.activeSessions.values where session.peripheral?.identifier == peripheral.identifier {
                for characteristic in characteristics {
                    session.characteristics[characteristic.uuid] = characteristic
                }
            }
        }
        
        NSLog("[BLETransferManager] Discovered \(characteristics.count) characteristics")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("[BLETransferManager] Error writing characteristic: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLETransferManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            NSLog("[BLETransferManager] Peripheral powered on")
            if isAdvertising {
                startAdvertising(metadata: [:])
            }
        case .poweredOff:
            NSLog("[BLETransferManager] Peripheral powered off")
        default:
            NSLog("[BLETransferManager] Peripheral state: \(peripheral.state.rawValue)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            NSLog("[BLETransferManager] Error adding service: \(error.localizedDescription)")
        } else {
            NSLog("[BLETransferManager] Service added successfully")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            NSLog("[BLETransferManager] Error starting advertising: \(error.localizedDescription)")
        } else {
            NSLog("[BLETransferManager] Advertising started successfully")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == BLETransferManager.CHAR_FILE_META_UUID {
                // Handle file metadata
                if let data = request.value,
                   let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    NSLog("[BLETransferManager] Received file metadata: \(metadata)")
                }
            } else if request.characteristic.uuid == BLETransferManager.CHAR_FILE_DATA_UUID {
                // Handle file data chunk
                if let data = request.value {
                    NSLog("[BLETransferManager] Received data chunk: \(data.count) bytes")
                }
            }
            
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
