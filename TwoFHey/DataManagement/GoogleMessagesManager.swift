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
    private let cacheKey = "com.sofriendly.2fhey.googleMessagesCache"
    private let maxCachedMessages = 10

    init(withOTPParser otpParser: OTPParser) {
        self.otpParser = otpParser
        loadCachedMessages()
    }

    // MARK: - Cache Management

    private func loadCachedMessages() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CachedMessage].self, from: data) else {
            return
        }

        // Convert cached messages back to MessageWithParsedOTP
        for cachedMsg in cached {
            processedIds.insert(cachedMsg.id)
            let message = Message(
                rowId: 0,
                guid: cachedMsg.id,
                text: cachedMsg.text,
                handle: "Google Messages",
                group: nil,
                fromMe: false
            )
            let parsedOTP = ParsedOTP(service: cachedMsg.service, code: cachedMsg.code)
            messages.append((message, parsedOTP))
        }
    }

    private func saveCachedMessages() {
        let cached = messages.suffix(maxCachedMessages).map { msg, otp in
            CachedMessage(id: msg.guid, text: msg.text ?? "", code: otp.code, service: otp.service)
        }

        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private struct CachedMessage: Codable {
        let id: String
        let text: String
        let code: String
        let service: String?
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

        // For Google Messages, the title often contains the sender's phone number
        // which can be mistaken for an OTP code (e.g., short codes like "787473").
        // Priority: 1) Parse body only, 2) Parse body + title for context

        var parsedOTP: ParsedOTP?
        var messageForDisplay: String

        if !body.isEmpty {
            // Try parsing the body first (contains the actual message)
            parsedOTP = otpParser.parseMessage(body)
            messageForDisplay = body

            // If body parsing failed, try with title for additional context
            // but put body first so its codes get priority
            if parsedOTP == nil {
                let fullMessage = "\(body)\n\(title)"
                parsedOTP = otpParser.parseMessage(fullMessage)
                messageForDisplay = fullMessage
            }
        } else {
            // No body, use title only
            parsedOTP = otpParser.parseMessage(title)
            messageForDisplay = title
        }

        guard !messageForDisplay.isEmpty else { return }

        // Use OTP parser to extract code
        guard let parsedOTP = parsedOTP else {
            DebugLogger.shared.log("No OTP found in notification", category: "GOOGLE_MESSAGES", data: ["message": String(messageForDisplay.prefix(100))])
            return
        }

        let message = Message(
            rowId: 0,
            guid: id,
            text: messageForDisplay,
            handle: "Google Messages",
            group: nil,
            fromMe: false
        )

        DispatchQueue.main.async {
            self.messages.append((message, parsedOTP))
            self.saveCachedMessages()
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
        UserDefaults.standard.removeObject(forKey: cacheKey)
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
