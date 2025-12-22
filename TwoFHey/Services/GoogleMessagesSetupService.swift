//
//  GoogleMessagesSetupService.swift
//  2FHey
//

import Foundation
import AppKit

enum GoogleMessagesSetupError: Error, LocalizedError {
    case downloadFailed
    case mountFailed
    case copyFailed
    case unmountFailed
    case appNotFoundInDMG
    case certificateGenerationFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download Google Messages app"
        case .mountFailed:
            return "Failed to mount the disk image"
        case .copyFailed:
            return "Failed to copy app to Applications folder"
        case .unmountFailed:
            return "Failed to unmount disk image"
        case .appNotFoundInDMG:
            return "Google Messages app not found in disk image"
        case .certificateGenerationFailed:
            return "Failed to generate TLS certificate"
        }
    }
}

enum GoogleMessagesSetupStep: Equatable {
    case notStarted
    case downloading(progress: Double)
    case mounting
    case copying
    case unmounting
    case generatingCertificate
    case launchingApp
    case completed
    case failed(String)
}

class GoogleMessagesSetupService: ObservableObject {
    static let shared = GoogleMessagesSetupService()

    private let dmgURL = URL(string: "https://sofriendly.s3.amazonaws.com/Google-Messages.dmg")!
    private let appName = "Google Messages"
    private let applicationsPath = "/Applications"

    @Published var currentStep: GoogleMessagesSetupStep = .notStarted
    @Published var downloadProgress: Double = 0

    private var downloadTask: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?

    var appPath: String {
        return "\(applicationsPath)/\(appName).app"
    }

    var isAppInstalled: Bool {
        return FileManager.default.fileExists(atPath: appPath)
    }

    func startSetup() async {
        await MainActor.run {
            currentStep = .downloading(progress: 0)
        }

        do {
            // Step 1: Download DMG
            let dmgPath = try await downloadDMG()

            // Step 2: Mount DMG
            await MainActor.run {
                currentStep = .mounting
            }
            let mountPoint = try await mountDMG(at: dmgPath)

            // Step 3: Copy app to /Applications
            await MainActor.run {
                currentStep = .copying
            }
            try await copyApp(from: mountPoint)

            // Step 4: Unmount DMG
            await MainActor.run {
                currentStep = .unmounting
            }
            try await unmountDMG(at: mountPoint)

            // Step 5: Clean up downloaded DMG
            try? FileManager.default.removeItem(atPath: dmgPath)

            // Step 6: Generate TLS certificate for WebSocket server
            await MainActor.run {
                currentStep = .generatingCertificate
            }
            try await generateTLSCertificate()

            // Step 7: Launch the app
            await MainActor.run {
                currentStep = .launchingApp
            }
            launchGoogleMessagesApp()

            // Mark as installed
            AppStateManager.shared.googleMessagesAppInstalled = true

            await MainActor.run {
                currentStep = .completed
            }

        } catch {
            await MainActor.run {
                currentStep = .failed(error.localizedDescription)
            }
        }
    }

    private func downloadDMG() async throws -> String {
        let destinationPath = NSTemporaryDirectory() + "Google-Messages.dmg"

        // Remove existing file if present
        try? FileManager.default.removeItem(atPath: destinationPath)

        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default)
            downloadTask = session.downloadTask(with: dmgURL) { [weak self] tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let tempURL = tempURL else {
                    continuation.resume(throwing: GoogleMessagesSetupError.downloadFailed)
                    return
                }

                do {
                    try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destinationPath))
                    continuation.resume(returning: destinationPath)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Observe download progress
            observation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    self?.downloadProgress = progress.fractionCompleted
                    self?.currentStep = .downloading(progress: progress.fractionCompleted)
                }
            }

            downloadTask?.resume()
        }
    }

    private func mountDMG(at path: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", path, "-nobrowse", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GoogleMessagesSetupError.mountFailed
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        // Parse plist to find mount point
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let systemEntities = plist["system-entities"] as? [[String: Any]] else {
            throw GoogleMessagesSetupError.mountFailed
        }

        // Find the mount point
        for entity in systemEntities {
            if let mountPoint = entity["mount-point"] as? String {
                return mountPoint
            }
        }

        throw GoogleMessagesSetupError.mountFailed
    }

    private func copyApp(from mountPoint: String) async throws {
        let sourcePath = "\(mountPoint)/\(appName).app"
        let destinationPath = appPath

        guard FileManager.default.fileExists(atPath: sourcePath) else {
            throw GoogleMessagesSetupError.appNotFoundInDMG
        }

        // Remove existing app if present
        if FileManager.default.fileExists(atPath: destinationPath) {
            try FileManager.default.removeItem(atPath: destinationPath)
        }

        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
        } catch {
            throw GoogleMessagesSetupError.copyFailed
        }
    }

    private func unmountDMG(at mountPoint: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint, "-quiet"]

        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        // Don't throw on unmount failure, it's not critical
    }

    func launchGoogleMessagesApp() {
        guard isAppInstalled else { return }

        let url = URL(fileURLWithPath: appPath)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                DebugLogger.shared.log("Failed to launch Google Messages: \(error.localizedDescription)", category: "GOOGLE_MESSAGES")
            }
        }
    }

    func cancelSetup() {
        downloadTask?.cancel()
        observation?.invalidate()
        currentStep = .notStarted
    }

    // MARK: - TLS Certificate Setup

    private func generateTLSCertificate() async throws {
        let certDir = NSHomeDirectory() + "/.2fhey"
        let p12Path = certDir + "/server.p12"

        // Skip if already exists
        if FileManager.default.fileExists(atPath: p12Path) {
            DebugLogger.shared.log("TLS certificate already exists", category: "GOOGLE_MESSAGES")
            return
        }

        // Create directory
        try? FileManager.default.createDirectory(atPath: certDir, withIntermediateDirectories: true)

        // Copy bundled P12 to user directory
        guard let bundledP12 = Bundle.main.url(forResource: "server", withExtension: "p12") else {
            DebugLogger.shared.log("Bundled P12 not found", category: "GOOGLE_MESSAGES")
            throw GoogleMessagesSetupError.certificateGenerationFailed
        }

        do {
            try FileManager.default.copyItem(at: bundledP12, to: URL(fileURLWithPath: p12Path))
            DebugLogger.shared.log("TLS certificate installed successfully", category: "GOOGLE_MESSAGES")
        } catch {
            DebugLogger.shared.log("Failed to copy P12: \(error)", category: "GOOGLE_MESSAGES")
            throw GoogleMessagesSetupError.certificateGenerationFailed
        }
    }
}
