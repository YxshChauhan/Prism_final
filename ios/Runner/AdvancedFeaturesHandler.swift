import Foundation
import UIKit
import AVFoundation
import Contacts
import CallKit

/**
 * Advanced Features Handler for AirLink iOS
 * Implements all 7 advanced features with iOS-specific implementations
 */
class AdvancedFeaturesHandler {
    
    // MARK: - Feature 1: APK Sharing (iOS Notes)
    
    func getInstalledApps(result: @escaping FlutterResult) {
        // iOS doesn't allow listing installed apps due to privacy restrictions
        // Return empty array with informational note
        result([
            ["note": "iOS privacy restrictions prevent listing installed apps"]
        ])
    }
    
    func extractApp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't allow app extraction
        result(FlutterError(
            code: "NOT_SUPPORTED",
            message: "App extraction is not supported on iOS due to platform restrictions",
            details: nil
        ))
    }
    
    func installApp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't allow programmatic app installation
        result(FlutterError(
            code: "NOT_SUPPORTED",
            message: "App installation is not supported on iOS. Use App Store or TestFlight",
            details: nil
        ))
    }
    
    // MARK: - Feature 2: File Manager Enhancements
    
    func getFileMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "File path required", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            let resourceValues = try fileURL.resourceValues(forKeys: [
                .contentTypeKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey
            ])
            
            let metadata: [String: Any] = [
                "name": fileURL.lastPathComponent,
                "path": filePath,
                "size": attributes[.size] as? Int64 ?? 0,
                "modified": (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0,
                "isDirectory": resourceValues.isDirectory ?? false,
                "isFile": !( resourceValues.isDirectory ?? false),
                "extension": fileURL.pathExtension,
                "mimeType": resourceValues.contentType?.preferredMIMEType ?? "application/octet-stream",
                "canRead": FileManager.default.isReadableFile(atPath: filePath),
                "canWrite": FileManager.default.isWritableFile(atPath: filePath),
                "thumbnail": generateThumbnail(fileURL: fileURL) as Any
            ]
            
            result(metadata)
        } catch {
            result(FlutterError(code: "METADATA_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    func bulkFileOperations(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let operation = args["operation"] as? String,
              let sourcePaths = args["sourcePaths"] as? [String],
              let destinationPath = args["destinationPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        var results: [[String: Any]] = []
        
        for sourcePath in sourcePaths {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(sourceURL.lastPathComponent)
            
            do {
                switch operation {
                case "copy":
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    results.append(["path": sourcePath, "success": true])
                    
                case "move":
                    try FileManager.default.moveItem(at: sourceURL, to: destURL)
                    results.append(["path": sourcePath, "success": true])
                    
                case "delete":
                    try FileManager.default.removeItem(at: sourceURL)
                    results.append(["path": sourcePath, "success": true])
                    
                default:
                    results.append(["path": sourcePath, "success": false, "error": "Unknown operation"])
                }
            } catch {
                results.append(["path": sourcePath, "success": false, "error": error.localizedDescription])
            }
        }
        
        result(results)
    }
    
    private func generateThumbnail(fileURL: URL) -> String? {
        let ext = fileURL.pathExtension.lowercased()
        
        if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
            if let image = UIImage(contentsOfFile: fileURL.path) {
                let size = CGSize(width: 200, height: 200)
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let data = thumbnail?.jpegData(compressionQuality: 0.8) {
                    return data.base64EncodedString()
                }
            }
        } else if ["mp4", "mov", "m4v"].contains(ext) {
            let asset = AVAsset(url: fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                
                if let data = image.jpegData(compressionQuality: 0.8) {
                    return data.base64EncodedString()
                }
            } catch {
                return nil
            }
        }
        
        return nil
    }
    
    // MARK: - Feature 3: Cloud Sync (iCloud)
    
    func connectCloudProvider(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let provider = args["provider"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Provider required", details: nil))
            return
        }
        
        switch provider {
        case "icloud":
            // Check if iCloud is available
            if FileManager.default.ubiquityIdentityToken != nil {
                result(true)
            } else {
                result(FlutterError(code: "ICLOUD_UNAVAILABLE", message: "iCloud not available or not signed in", details: nil))
            }
        case "google_drive", "dropbox", "onedrive":
            result(FlutterError(code: "NOT_IMPLEMENTED", message: "\(provider) not implemented on iOS yet", details: nil))
        default:
            result(FlutterError(code: "UNKNOWN_PROVIDER", message: "Unknown provider: \(provider)", details: nil))
        }
    }
    
    func uploadToCloud(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "File path required", details: nil))
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
                .appendingPathComponent(fileURL.lastPathComponent) else {
            result(FlutterError(code: "ICLOUD_ERROR", message: "Cannot access iCloud", details: nil))
            return
        }
        
        do {
            // Create Documents directory if it doesn't exist
            let documentsURL = ubiquityURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            
            // Copy file to iCloud
            if FileManager.default.fileExists(atPath: ubiquityURL.path) {
                try FileManager.default.removeItem(at: ubiquityURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: ubiquityURL)
            
            result([
                "fileId": ubiquityURL.lastPathComponent,
                "name": ubiquityURL.lastPathComponent,
                "path": ubiquityURL.path,
                "size": try FileManager.default.attributesOfItem(atPath: ubiquityURL.path)[.size] as? Int64 ?? 0
            ])
        } catch {
            result(FlutterError(code: "UPLOAD_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    func downloadFromCloud(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let fileId = args["fileId"] as? String,
              let destinationPath = args["destinationPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "File ID and destination path required", details: nil))
            return
        }
        
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
                .appendingPathComponent(fileId) else {
            result(FlutterError(code: "ICLOUD_ERROR", message: "Cannot access iCloud", details: nil))
            return
        }
        
        let destURL = URL(fileURLWithPath: destinationPath)
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: ubiquityURL, to: destURL)
            result(destinationPath)
        } catch {
            result(FlutterError(code: "DOWNLOAD_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    func listCloudFiles(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents") else {
            result(FlutterError(code: "ICLOUD_ERROR", message: "Cannot access iCloud", details: nil))
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: ubiquityURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            let files = try fileURLs.map { fileURL -> [String: Any] in
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                return [
                    "id": fileURL.lastPathComponent,
                    "name": fileURL.lastPathComponent,
                    "size": attributes[.size] as? Int64 ?? 0,
                    "modified": (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0,
                    "mimeType": "application/octet-stream"
                ]
            }
            
            result(files)
        } catch {
            result(FlutterError(code: "LIST_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Feature 5: Media Player Enhancements
    
    func getVideoInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Video path required", details: nil))
            return
        }
        
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.load(.tracks)
                
                var width = 0
                var height = 0
                var bitrate = 0
                var fps: Float = 0
                
                if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                    let size = try await videoTrack.load(.naturalSize)
                    width = Int(size.width)
                    height = Int(size.height)
                    bitrate = Int(try await videoTrack.load(.estimatedDataRate))
                    fps = try await videoTrack.load(.nominalFrameRate)
                }
                
                let fileSize = try FileManager.default.attributesOfItem(atPath: videoPath)[.size] as? Int64 ?? 0
                
                let info: [String: Any] = [
                    "duration": Int64(CMTimeGetSeconds(duration) * 1000),
                    "width": width,
                    "height": height,
                    "bitrate": bitrate,
                    "fps": fps,
                    "size": fileSize,
                    "mimeType": "video/mp4"
                ]
                
                result(info)
            } catch {
                result(FlutterError(code: "VIDEO_INFO_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    func extractAudioTrack(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String,
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Video path and output path required", details: nil))
            return
        }
        
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let outputURL = URL(fileURLWithPath: outputPath)
        
        Task {
            do {
                // Create export session
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                    result(FlutterError(code: "EXPORT_ERROR", message: "Cannot create export session", details: nil))
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .m4a
                
                await exportSession.export()
                
                if exportSession.status == .completed {
                    result(outputPath)
                } else if let error = exportSession.error {
                    result(FlutterError(code: "EXTRACT_AUDIO_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(FlutterError(code: "EXTRACT_AUDIO_ERROR", message: "Export failed", details: nil))
                }
            }
        }
    }
    
    // MARK: - Feature 6: Phone Replication
    
    func exportContacts(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Output path required", details: nil))
            return
        }
        
        let store = CNContactStore()
        
        store.requestAccess(for: .contacts) { granted, error in
            if !granted {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Contacts permission denied", details: nil))
                return
            }
            
            do {
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                
                var contacts: [[String: Any]] = []
                
                try store.enumerateContacts(with: request) { contact, _ in
                    let phones = contact.phoneNumbers.map { $0.value.stringValue }
                    let emails = contact.emailAddresses.map { $0.value as String }
                    
                    contacts.append([
                        "id": contact.identifier,
                        "name": "\(contact.givenName) \(contact.familyName)",
                        "phones": phones,
                        "emails": emails
                    ])
                }
                
                // Save to file as JSON
                let jsonData = try JSONSerialization.data(withJSONObject: contacts, options: .prettyPrinted)
                try jsonData.write(to: URL(fileURLWithPath: outputPath))
                
                result([
                    "path": outputPath,
                    "count": contacts.count
                ])
            } catch {
                result(FlutterError(code: "EXPORT_CONTACTS_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    func exportCallLogs(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS doesn't provide API to access call logs due to privacy restrictions
        result(FlutterError(
            code: "NOT_SUPPORTED",
            message: "Call log access is not available on iOS due to privacy restrictions",
            details: nil
        ))
    }
    
    // MARK: - Feature 4: Video Compression
    
    private var compressionTasks: [String: AVAssetExportSession] = [:]
    
    func compressVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Input path required", details: nil))
            return
        }
        
        let quality = args["quality"] as? String ?? "medium"
        let asset = AVAsset(url: URL(fileURLWithPath: inputPath))
        
        // Determine preset based on quality
        let preset: String
        switch quality {
        case "low":
            preset = AVAssetExportPresetLowQuality
        case "high":
            preset = AVAssetExportPresetHighestQuality
        default: // medium
            preset = AVAssetExportPresetMediumQuality
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            result(FlutterError(code: "EXPORT_ERROR", message: "Cannot create export session", details: nil))
            return
        }
        
        // Create output path
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("compressed_videos")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputURL = outputDir.appendingPathComponent("compressed_\(Date().timeIntervalSince1970).mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        let jobId = "compression_\(Date().timeIntervalSince1970)"
        compressionTasks[jobId] = exportSession
        
        Task {
            await exportSession.export()
            
            if exportSession.status == .completed {
                let originalSize = (try? FileManager.default.attributesOfItem(atPath: inputPath)[.size] as? Int64) ?? 0
                let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                
                result([
                    "jobId": jobId,
                    "outputPath": outputURL.path,
                    "success": true,
                    "originalSize": originalSize,
                    "compressedSize": compressedSize
                ])
            } else if let error = exportSession.error {
                result(FlutterError(code: "COMPRESSION_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result(FlutterError(code: "COMPRESSION_FAILED", message: "Export failed", details: nil))
            }
            
            compressionTasks.removeValue(forKey: jobId)
        }
    }
    
    func getCompressionProgress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let jobId = args["jobId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Job ID required", details: nil))
            return
        }
        
        guard let session = compressionTasks[jobId] else {
            result([
                "progress": 0.0,
                "status": "not_found"
            ])
            return
        }
        
        let status: String
        switch session.status {
        case .waiting, .exporting:
            status = "processing"
        case .completed:
            status = "completed"
        case .failed, .cancelled:
            status = "failed"
        default:
            status = "unknown"
        }
        
        result([
            "progress": session.progress * 100.0,
            "status": status
        ])
    }
    
    func cancelCompression(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let jobId = args["jobId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Job ID required", details: nil))
            return
        }
        
        if let session = compressionTasks[jobId] {
            session.cancelExport()
            compressionTasks.removeValue(forKey: jobId)
        }
        
        result(true)
    }
}
