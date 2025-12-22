//
//  GoogleMessagesManager.swift
//  2FHey
//
//  Monitors for notifications from Google Messages Pake app via HTTP server
//

import Foundation
import Combine

class GoogleMessagesManager: ObservableObject {
    @Published var messages: [MessageWithParsedOTP] = []

    private var processedIds: Set<String> = []
    private var otpParser: OTPParser

    init(withOTPParser otpParser: OTPParser) {
        self.otpParser = otpParser
    }

    func startListening() {
        // Start the notification server
        NotificationServer.shared.onNotificationReceived = { [weak self] title, body, id in
            self?.handleNotification(title: title, body: body, id: id)
        }
        NotificationServer.shared.start()

        DebugLogger.shared.log("Google Messages monitoring started", category: "GOOGLE_MESSAGES")
    }

    func stopListening() {
        NotificationServer.shared.stop()
        NotificationServer.shared.onNotificationReceived = nil
        DebugLogger.shared.log("Google Messages monitoring stopped", category: "GOOGLE_MESSAGES")
    }

    private func handleNotification(title: String, body: String, id: String) {
        // Check if already processed
        guard !processedIds.contains(id) else { return }
        processedIds.insert(id)

        // Combine title and body for parsing
        let fullMessage = body.isEmpty ? title : "\(title)\n\(body)"

        guard !fullMessage.isEmpty else { return }

        // Use OTP parser to extract code
        guard let parsedOTP = otpParser.parseMessage(fullMessage) else {
            DebugLogger.shared.log("No OTP found in notification", category: "GOOGLE_MESSAGES", data: ["message": String(fullMessage.prefix(100))])
            return
        }

        let message = Message(
            rowId: 0,
            guid: id,
            text: fullMessage,
            handle: "Google Messages",
            group: nil,
            fromMe: false
        )

        DispatchQueue.main.async {
            self.messages.append((message, parsedOTP))
        }

        DebugLogger.shared.log("Parsed Google Messages OTP", category: "GOOGLE_MESSAGES", data: [
            "code": parsedOTP.code,
            "service": parsedOTP.service ?? "unknown"
        ])
    }

    func reset() {
        stopListening()
        messages = []
        processedIds = []
        startListening()
    }

    // Test/Debug method to inject fake messages
    func injectTestMessage(_ text: String) {
        guard let parsedOTP = otpParser.parseMessage(text) else {
            print("Failed to parse test message: \(text)")
            return
        }

        let message = Message(
            rowId: 0,
            guid: UUID().uuidString,
            text: text,
            handle: "Google Messages",
            group: nil,
            fromMe: false
        )

        print("Parsed test message: \(parsedOTP.code) from \(parsedOTP.service ?? "unknown")")
        messages.append((message, parsedOTP))
    }

    deinit {
        stopListening()
    }
}
