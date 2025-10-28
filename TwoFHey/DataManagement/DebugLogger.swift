//
//  DebugLogger.swift
//  TwoFHey
//
//  Debug logging utility for iMessage database operations
//

import Foundation

class DebugLogger {
    static let shared = DebugLogger()

    private var logFileURL: URL?
    private let queue = DispatchQueue(label: "com.sofriendly.2fhey.debugLogger", qos: .utility)

    private init() {
        // Set up log file in Documents folder
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logFileURL = documentsPath.appendingPathComponent("2FHey_Debug.log")
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    /// Log a message to the debug log file
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: Category of the log (e.g., "DATABASE", "PARSING")
    ///   - data: Optional data to include (will be formatted)
    func log(_ message: String, category: String = "INFO", data: Any? = nil) {
        guard AppStateManager.shared.debugLoggingEnabled else { return }

        guard let logFileURL = logFileURL else { return }
        let timestamp = formatTimestamp(Date())

        var logEntry = "[\(timestamp)] [\(category)] \(message)"
        if let data = data {
            logEntry += "\n  Data: \(String(describing: data))"
        }
        logEntry += "\n"

        queue.async {
            // Create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                let header = "2FHey Debug Log\nStarted: \(timestamp)\n" + String(repeating: "=", count: 80) + "\n"
                try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
            }

            // Append to file
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
            }

            // Also print to console for development
            print(logEntry)
        }
    }

    /// Log a database query
    func logDatabaseQuery(_ query: String, parameters: [String: Any]? = nil) {
        var message = "Executing database query"
        log(message, category: "DATABASE", data: ["query": query, "parameters": parameters ?? [:]])
    }

    /// Log raw attributedBody data for debugging
    func logAttributedBody(_ data: Data?, messageGuid: String) {
        guard let data = data else {
            log("attributedBody is NULL for message \(messageGuid)", category: "PARSING")
            return
        }

        // Log the raw data length
        log("attributedBody length: \(data.count) bytes for message \(messageGuid)", category: "PARSING")

        // Try to convert to UTF-8 string and log first 500 chars
        if let bodyString = String(data: data, encoding: .utf8) {
            let preview = String(bodyString.prefix(500))
            log("attributedBody preview for \(messageGuid):", category: "PARSING", data: preview)
        } else {
            log("Failed to convert attributedBody to UTF-8 string for \(messageGuid)", category: "PARSING")
        }
    }

    /// Log message parsing result
    func logMessageParse(guid: String, text: String?, attributedBodyUsed: Bool, parsedText: String?) {
        var details: [String: Any] = [
            "guid": guid,
            "hasDirectText": text != nil,
            "attributedBodyUsed": attributedBodyUsed,
            "parsedText": parsedText ?? "nil"
        ]

        if let originalText = text {
            details["originalText"] = originalText
        }

        log("Message parse result", category: "PARSING", data: details)
    }

    /// Clear the log file
    func clearLog() {
        // Capture values on calling thread to avoid race conditions
        guard let logFileURL = logFileURL else { return }
        let timestamp = formatTimestamp(Date())

        queue.async {
            try? FileManager.default.removeItem(at: logFileURL)

            let header = "2FHey Debug Log\nStarted: \(timestamp)\n" + String(repeating: "=", count: 80) + "\n"
            try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Get the log file path for sharing
    func getLogFilePath() -> String? {
        return logFileURL?.path
    }
}
