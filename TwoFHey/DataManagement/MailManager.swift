//
//  MailManager.swift
//  TwoFHey
//
//  Created for Apple Mail integration
//

import Foundation

typealias EmailWithParsedOTP = (Message, ParsedOTP)

class MailManager: ObservableObject {
    @Published var messages: [EmailWithParsedOTP] = []

    private var processedIds: Set<String> = []

    var otpParser: OTPParser
    private var plistFileMonitor: DispatchSourceFileSystemObject?
    private var plistFileDescriptor: Int32 = -1

    init(withOTPParser otpParser: OTPParser) {
        self.otpParser = otpParser
    }

    func startListening() {
        syncMessages()
        setupPlistFileMonitor()
    }

    func stopListening() {
        cleanupPlistFileMonitor()
    }

    private func setupPlistFileMonitor() {
        let plistPath: String = NSString(string: "~/Library/Mail/V10/MailData/EMUbiquitouslyPersistedDictionary-com.apple.mail.mailboxCategories.plist").expandingTildeInPath

        plistFileDescriptor = open(plistPath, O_EVTONLY)
        guard plistFileDescriptor >= 0 else {
            DebugLogger.shared.log("Failed to open Mail plist file for monitoring", category: "MAIL_SYNC", data: ["path": plistPath])
            return
        }

        let queue = DispatchQueue.global(qos: .background)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: plistFileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            let eventData = source.data
            DebugLogger.shared.log("Mail plist file event detected", category: "MAIL_SYNC", data: ["eventMask": "\(eventData)"])
            DispatchQueue.main.async {
                self?.syncMessages()
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.plistFileDescriptor, fd >= 0 {
                close(fd)
                self?.plistFileDescriptor = -1
            }
        }

        plistFileMonitor = source
        source.resume()

        DebugLogger.shared.log("Mail plist file monitoring started", category: "MAIL_SYNC", data: ["path": plistPath, "fd": plistFileDescriptor])
    }

    private func cleanupPlistFileMonitor() {
        plistFileMonitor?.cancel()
        plistFileMonitor = nil
    }

    func reset() {
        stopListening()
        messages = []
        processedIds = []
        startListening()
    }

    deinit {
        cleanupPlistFileMonitor()
    }


    @objc func syncMessages() {
        guard AppStateManager.shared.hasFullDiscAccess() == .authorized else {
            DebugLogger.shared.log("syncMessages skipped - no Full Disk Access", category: "MAIL_SYNC")
            return
        }

        DebugLogger.shared.log("Starting syncMessages for Mail", category: "MAIL_SYNC")

        do {
            let parsedOtps = try findPossibleOTPEmailMessages()
            guard parsedOtps.count > 0 else {
                DebugLogger.shared.log("No new OTP email messages found", category: "MAIL_SYNC")
                return
            }
            messages.append(contentsOf: parsedOtps)
            DebugLogger.shared.log("Added new OTP email messages", category: "MAIL_SYNC", data: ["count": parsedOtps.count])
        } catch let err {
            // Only log unexpected errors (not permission denied)
            let errorString = String(describing: err)
            if !errorString.contains("authorization denied") {
                print("ERR: \(err)")
                DebugLogger.shared.log("Error during Mail sync", category: "ERROR", data: ["error": errorString])
            }
        }
    }

    private func findPossibleOTPEmailMessages() throws -> [EmailWithParsedOTP] {
        guard let emailData = fetchLatestEmailViaAppleScript() else {
            return []
        }

        if processedIds.contains(emailData.id) {
            return []
        }

        processedIds.insert(emailData.id)

        let message = Message(
            guid: emailData.id,
            text: emailData.fullText,
            handle: emailData.sender,
            group: nil,
            fromMe: false
        )

        guard let parsedOTP = otpParser.parseMessage(emailData.fullText) else {
            return []
        }

        return [(message, parsedOTP)]
    }

    private struct EmailData {
        let id: String
        let subject: String
        let sender: String
        let date: String
        let body: String

        var fullText: String {
            return "Subject: \(subject)\nFrom: \(sender)\n\n\(body)"
        }
    }

    private var hasLoggedAutomationError = false

    private func markMessageAsRead() {
        let script = """
        tell application "Mail"
         set read status of every message of inbox to true
        end tell
        """
        
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            DebugLogger.shared.log("Failed to create AppleScript object for marking message as read", category: "MAIL_SYNC")
            return
        }
        
        scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            DebugLogger.shared.log("Failed to mark message as read", category: "MAIL_SYNC", data: ["error": error])
        }
    }

    private func fetchLatestEmailViaAppleScript() -> EmailData? {
        let script = """
        tell application "Mail"
          set latestMessage to missing value
          set latestDate to missing value
        
          repeat with currentAccount in every account
            try
              set inboxMailbox to mailbox "INBOX" of currentAccount
              set firstMessage to message 1 of inboxMailbox -- latest message is indexed as 1
              set msgDate to date received of firstMessage
              if latestDate is missing value or msgDate > latestDate then
                set latestDate to msgDate
                set latestMessage to firstMessage
              end if
            end try
          end repeat

          if latestMessage is not missing value then
            set output to "SUBJECT: " & subject of latestMessage & linefeed
            set output to output & "FROM: " & sender of latestMessage & linefeed
            set output to output & "DATE: " & (date received of latestMessage) & linefeed
            set output to output & "ID: " & id of latestMessage & linefeed
            set output to output & "CONTENT:" & linefeed & content of latestMessage
            return output
          else
            return ""
          end if
        end tell
        """

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            DebugLogger.shared.log("Failed to create AppleScript object", category: "MAIL_SYNC")
            return nil
        }

        let output = scriptObject.executeAndReturnError(&error)

        if let error = error {
            // Check for automation permission error (-1743)
            if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int, errorNumber == -1743 {
                if !hasLoggedAutomationError {
                    DebugLogger.shared.log("Mail automation permission not granted. Please allow 2FHey to control Mail in System Settings > Privacy & Security > Automation", category: "MAIL_SYNC")
                    hasLoggedAutomationError = true
                }
                return nil
            }

            DebugLogger.shared.log("AppleScript execution failed", category: "MAIL_SYNC", data: ["error": error])
            return nil
        }

        guard let result = output.stringValue, !result.isEmpty else {
            DebugLogger.shared.log("No email found in the last hour", category: "MAIL_SYNC")
            return nil
        }

        return parseAppleScriptOutput(result)
    }

    private func parseAppleScriptOutput(_ output: String) -> EmailData? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        var subject = ""
        var sender = ""
        var date = ""
        var id = ""
        var content = ""
        var inContent = false

        for line in lines {
            let lineStr = String(line)

            if lineStr.hasPrefix("SUBJECT: ") {
                subject = String(lineStr.dropFirst("SUBJECT: ".count))
            } else if lineStr.hasPrefix("FROM: ") {
                sender = String(lineStr.dropFirst("FROM: ".count))
            } else if lineStr.hasPrefix("DATE: ") {
                date = String(lineStr.dropFirst("DATE: ".count))
            } else if lineStr.hasPrefix("ID: ") {
                id = String(lineStr.dropFirst("ID: ".count))
            } else if lineStr.hasPrefix("CONTENT:") {
                inContent = true
            } else if inContent {
                content += lineStr + "\n"
            }
        }

        guard !subject.isEmpty, !sender.isEmpty, !id.isEmpty else {
            DebugLogger.shared.log("Failed to parse AppleScript output", category: "MAIL_SYNC", data: ["output": output])
            return nil
        }

        return EmailData(
            id: id,
            subject: subject,
            sender: sender,
            date: date,
            body: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
