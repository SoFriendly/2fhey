//
//  MessageManager.swift
//  ohtipi
//
//  Created by Drew Pomerleau on 4/22/22.
//

import Foundation
import SQLite

typealias MessageWithParsedOTP = (Message, ParsedOTP)
typealias Expression = SQLite.Expression

class MessageManager: ObservableObject {
    @Published var messages: [MessageWithParsedOTP] = []

    private let checkTimeInterval: TimeInterval = 2.0
    private var processedGuids: Set<String> = []

    var otpParser: OTPParser
    var timer: Timer?

    init(withOTPParser otpParser: OTPParser) {
        self.otpParser = otpParser
    }
    
    private func timeOffsetForDate(_ date: Date) -> Int {
        var appleOffsetForDate = Int(date.timeIntervalSinceReferenceDate)

        // macOS 26 (Tahoe) and later use a different timestamp format
        if #available(macOS 26.0, *) {
            // For macOS 26+, Messages database uses nanosecond precision with different epoch
            let factor = Int(pow(10.0, 9))
            appleOffsetForDate *= factor
        } else if #available(macOS 10.13, *) {
            let factor = Int(pow(10.0, 9))
            appleOffsetForDate *= factor
        }

        return appleOffsetForDate
    }

    // Parse attributedBody to extract text content
    // In macOS 26 (Tahoe), message.text is often NULL and the content is in attributedBody
    private func parseAttributedBody(_ attributedBody: Data?) -> String? {
        guard let data = attributedBody else { return nil }

        // Method 1: Try to unarchive as NSAttributedString (proper way)
        if let attributedString = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            let text = attributedString.string
            DebugLogger.shared.log("Successfully unarchived NSAttributedString", category: "PARSING", data: ["text_length": text.count, "text_preview": String(text.prefix(100))])
            return text.isEmpty ? nil : text
        }

        // Method 2: Try legacy unarchiver
        if let attributedString = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSAttributedString {
            let text = attributedString.string
            DebugLogger.shared.log("Successfully unarchived with legacy method", category: "PARSING", data: ["text_length": text.count, "text_preview": String(text.prefix(100))])
            return text.isEmpty ? nil : text
        }

        // Method 3: Try to decode as streamtyped (iOS/macOS format)
        // The data might be in a different encoding format
        if let decodedString = decodeStreamTypedData(data) {
            DebugLogger.shared.log("Successfully decoded streamtyped data", category: "PARSING", data: ["text_length": decodedString.count, "text_preview": String(decodedString.prefix(100))])
            return decodedString
        }

        // Method 4: Fallback to string scanning (original Raycast method)
        // This works if the data happens to contain readable UTF-8 text
        if var bodyString = String(data: data, encoding: .utf8) {
            DebugLogger.shared.log("Attempting string scanning fallback", category: "PARSING")

            guard let nsStringRange = bodyString.range(of: "NSString") else {
                DebugLogger.shared.log("No NSString marker found in attributedBody", category: "PARSING")
                return nil
            }

            // Skip 8 characters after "NSString"
            let startIndex = bodyString.index(nsStringRange.upperBound, offsetBy: 8, limitedBy: bodyString.endIndex) ?? bodyString.endIndex
            bodyString = String(bodyString[startIndex...])

            // Look for "NSDictionary" and extract text before it (minus 10 characters)
            if let nsDictionaryRange = bodyString.range(of: "NSDictionary") {
                let endIndex = bodyString.index(nsDictionaryRange.lowerBound, offsetBy: -10, limitedBy: bodyString.startIndex) ?? nsDictionaryRange.lowerBound
                bodyString = String(bodyString[..<endIndex])
            }

            let cleanedText = bodyString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedText.isEmpty {
                DebugLogger.shared.log("String scanning succeeded", category: "PARSING", data: ["text": cleanedText])
                return cleanedText
            }
        }

        DebugLogger.shared.log("All parsing methods failed for attributedBody", category: "PARSING", data: ["data_length": data.count])
        return nil
    }

    // Attempt to decode streamtyped data format used by iMessage
    private func decodeStreamTypedData(_ data: Data) -> String? {
        // Try reading as property list
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
            // The plist might contain the string in various formats
            if let string = plist as? String {
                return string
            }
            if let dict = plist as? [String: Any], let string = dict["NSString"] as? String {
                return string
            }
            if let dict = plist as? [String: Any], let string = dict["string"] as? String {
                return string
            }
        }

        return nil
    }
    
    private func loadMessagesAfterDate(_ date: Date) throws -> [Message] {
        DebugLogger.shared.log("Starting loadMessagesAfterDate", category: "DATABASE", data: ["date": date, "macOS_version": ProcessInfo.processInfo.operatingSystemVersionString])

        var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        homeDirectory.appendPathComponent("/Library/Messages/chat.db")

        DebugLogger.shared.log("Database path", category: "DATABASE", data: ["path": homeDirectory.path])

        let db = try Connection(homeDirectory.absoluteString)
        DebugLogger.shared.log("Successfully connected to database", category: "DATABASE")
        
        let textColumn = Expression<String?>("text")
        let attributedBodyColumn = Expression<Data?>("attributedBody")
        let guidColumn = Expression<String>("guid")
        let cacheRoomnamesColumn = Expression<String?>("cache_roomnames")
        let fromMeColumn = Expression<Bool>("is_from_me")
        let dateColumn = Expression<Int>("date")
        let serviceColumn = Expression<String>("service")
        
        let ROWID = Expression<Int>("ROWID")

        let handleTable = Table("handle")
        let handleFrom = handleTable[Expression<String?>("id")]
        let messageTable = Table("message")
        let messageHandleId = messageTable[Expression<Int>("handle_id")]
        
        // For macOS 26+, we need to handle the database query differently
        let query: QueryType
        let isMacOS26 = if #available(macOS 26.0, *) { true } else { false }

        DebugLogger.shared.log("Building query", category: "DATABASE", data: ["macOS_26_or_later": isMacOS26, "timeOffset": timeOffsetForDate(date)])

        if #available(macOS 26.0, *) {
            // macOS 26 (Tahoe) may have changed the database schema or date handling
            // Use a more flexible date comparison and include both SMS and iMessage
            // Include attributedBody for when text is NULL
            query = messageTable
                .select(messageTable[guidColumn], messageTable[fromMeColumn], messageTable[textColumn], messageTable[attributedBodyColumn], messageTable[cacheRoomnamesColumn], messageTable[dateColumn], handleFrom, messageTable[serviceColumn])
                .join(.leftOuter, handleTable, on: messageHandleId == handleTable[ROWID])
                .where(messageTable[dateColumn] > timeOffsetForDate(date))
                .order(messageTable[dateColumn].desc)
                .limit(1000)  // Limit results for performance
            DebugLogger.shared.log("Using macOS 26+ query path", category: "DATABASE")
        } else {
            query = messageTable
                .select(messageTable[guidColumn], messageTable[fromMeColumn], messageTable[textColumn], messageTable[attributedBodyColumn], messageTable[cacheRoomnamesColumn], messageTable[dateColumn], handleFrom, messageTable[serviceColumn])
                .join(.leftOuter, handleTable, on: messageHandleId == handleTable[ROWID])
                .where(messageTable[dateColumn] > timeOffsetForDate(date))  // Removed SMS filter to include iMessage
                // Original: .where(messageTable[dateColumn] > timeOffsetForDate(date) && messageTable[serviceColumn] == "SMS")
                .order(messageTable[dateColumn].asc)
            DebugLogger.shared.log("Using pre-macOS 26 query path", category: "DATABASE")
        }

        let mapRowIterator = try db.prepareRowIterator(query)
        DebugLogger.shared.log("Executing query and iterating results", category: "DATABASE")

        var rowCount = 0
        var messagesWithText = 0
        var messagesWithAttributedBody = 0
        var messagesParsedFromAttributedBody = 0
        var messagesSkipped = 0

        let messages = try mapRowIterator.map { messageRow -> Message? in
            rowCount += 1
            let guid = messageRow[guidColumn]

            // Get handle first - required field
            guard let handle = messageRow[handleFrom] else {
                DebugLogger.shared.log("Row \(rowCount): Skipped - no handle", category: "PARSING", data: ["guid": guid])
                messagesSkipped += 1
                return nil
            }

            // Try to get text, fallback to parsing attributedBody if text is NULL
            let text: String?
            let usedAttributedBody: Bool
            if let directText = messageRow[textColumn] {
                text = directText
                usedAttributedBody = false
                messagesWithText += 1
                DebugLogger.shared.log("Row \(rowCount): Has direct text", category: "PARSING", data: ["guid": guid, "text_length": directText.count, "text_preview": String(directText.prefix(50))])
            } else {
                // For macOS 26 (Tahoe), text may be NULL and content is in attributedBody
                messagesWithAttributedBody += 1
                let attributedBodyData = messageRow[attributedBodyColumn]
                DebugLogger.shared.logAttributedBody(attributedBodyData, messageGuid: guid)

                text = parseAttributedBody(attributedBodyData)
                usedAttributedBody = true

                if text != nil {
                    messagesParsedFromAttributedBody += 1
                }

                DebugLogger.shared.logMessageParse(guid: guid, text: nil, attributedBodyUsed: true, parsedText: text)
            }

            // If we couldn't get text from either source, skip this message
            guard let messageText = text else {
                DebugLogger.shared.log("Row \(rowCount): Skipped - no text available", category: "PARSING", data: ["guid": guid])
                messagesSkipped += 1
                return nil
            }

            return Message(
                guid: messageRow[guidColumn],
                text: messageText,
                handle: handle,
                group: messageRow[cacheRoomnamesColumn],
                fromMe: messageRow[fromMeColumn])
        }

        let finalMessages = messages.compactMap { $0 }

        DebugLogger.shared.log("Query complete", category: "DATABASE", data: [
            "total_rows": rowCount,
            "messages_with_direct_text": messagesWithText,
            "messages_with_null_text": messagesWithAttributedBody,
            "successfully_parsed_from_attributedBody": messagesParsedFromAttributedBody,
            "messages_skipped": messagesSkipped,
            "final_message_count": finalMessages.count
        ])

        return finalMessages
    }
    
    func startListening() {
        syncMessages()

        timer = Timer.scheduledTimer(withTimeInterval: checkTimeInterval, repeats: true) { [weak self] _ in
            self?.syncMessages()
        }
    }

    func stopListening() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        stopListening()
        messages = []
        processedGuids = []
        startListening()
    }

    // Test/Debug method to inject fake messages
    func injectTestMessage(_ text: String) {
        let testMessage = Message(
            guid: UUID().uuidString,
            text: text,
            handle: "+15555551234",
            group: nil,
            fromMe: false
        )

        guard let parsedOTP = otpParser.parseMessage(text) else {
            print("❌ Failed to parse test message: \(text)")
            return
        }

        print("✅ Parsed test message: \(parsedOTP.code) from \(parsedOTP.service ?? "unknown")")
        messages.append((testMessage, parsedOTP))
    }
    
    @objc func syncMessages() {
        // Don't try to sync if we don't have Full Disk Access
        guard AppStateManager.shared.hasFullDiscAccess() == .authorized else {
            DebugLogger.shared.log("syncMessages skipped - no Full Disk Access", category: "SYNC")
            return
        }

        guard let modifiedDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) else { return }

        DebugLogger.shared.log("Starting syncMessages", category: "SYNC", data: ["looking_back_to": modifiedDate])

        do {
            let parsedOtps = try findPossibleOTPMessagesAfterDate(modifiedDate)
            guard parsedOtps.count > 0 else {
                DebugLogger.shared.log("No new OTP messages found", category: "SYNC")
                return
            }
            messages.append(contentsOf: parsedOtps)
            DebugLogger.shared.log("Added new OTP messages", category: "SYNC", data: ["count": parsedOtps.count])
        } catch let err {
            // Only log unexpected errors (not permission denied)
            let errorString = String(describing: err)
            if !errorString.contains("authorization denied") {
                print("ERR: \(err)")
                DebugLogger.shared.log("Error during sync", category: "ERROR", data: ["error": errorString])
            }
        }
    }
    
    private func findPossibleOTPMessagesAfterDate(_ date: Date) throws -> [MessageWithParsedOTP] {
        let messagesFromDB = try loadMessagesAfterDate(date)
        let filteredMessages = messagesFromDB
            // .filter { !$0.fromMe }  // Commented out to allow testing with messages sent to yourself
            .filter { !isInvalidMessageBodyValidPerCustomBlacklist($0.text) }
            .filter { !processedGuids.contains($0.guid) }
        
        filteredMessages.forEach { message in
            processedGuids.insert(message.guid)
        }
        
        return filteredMessages.compactMap { message in
            guard let parsedOTP = otpParser.parseMessage(message.text) else { return nil }
            return (message, parsedOTP)
        }
    }
    
    private func isInvalidMessageBodyValidPerCustomBlacklist(_ messageBody: String) -> Bool {
        return (
            messageBody.isEmpty ||
            messageBody.count < 5 ||
            messageBody.contains("$") ||
            messageBody.contains("€") ||
            messageBody.contains("₹") ||
            messageBody.contains("¥")
        )
    }

    func markMessageAsRead(guid: String) {
        guard AppStateManager.shared.markAsReadEnabled else {
            DebugLogger.shared.log("Mark as read skipped - feature disabled", category: "MARK_READ")
            return
        }
        guard AppStateManager.shared.hasFullDiscAccess() == .authorized else {
            DebugLogger.shared.log("Mark as read skipped - no Full Disk Access", category: "MARK_READ")
            return
        }

        DebugLogger.shared.log("Attempting to mark message as read", category: "MARK_READ", data: ["guid": guid])

        // Method 1: Update the database directly
        let dbSuccess = markMessageAsReadInDatabase(guid: guid)

        // Method 2: Try to notify Messages app via AppleScript (more reliable for UI updates)
        if dbSuccess {
            notifyMessagesAppViaAppleScript()
        }
    }

    private func markMessageAsReadInDatabase(guid: String) -> Bool {
        do {
            var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            homeDirectory.appendPathComponent("/Library/Messages/chat.db")
            let db = try Connection(homeDirectory.absoluteString)

            let messageTable = Table("message")
            let guidColumn = Expression<String>("guid")
            let isReadColumn = Expression<Int>("is_read")
            let dateReadColumn = Expression<Int>("date_read")

            // Get current time in Apple's epoch format (nanoseconds since 2001-01-01)
            let currentDate = Date()
            let dateRead = Int(currentDate.timeIntervalSinceReferenceDate * 1_000_000_000)

            let message = messageTable.filter(guidColumn == guid)

            // Update both is_read and date_read
            let updateResult = try db.run(message.update(
                isReadColumn <- 1,
                dateReadColumn <- dateRead
            ))

            if updateResult > 0 {
                DebugLogger.shared.log("Successfully marked message as read in database", category: "MARK_READ", data: ["guid": guid, "rows_updated": updateResult, "date_read": dateRead])
                return true
            } else {
                DebugLogger.shared.log("No rows updated - message may not exist", category: "MARK_READ", data: ["guid": guid])
                return false
            }
        } catch {
            DebugLogger.shared.log("Failed to mark message as read in database", category: "MARK_READ", data: ["guid": guid, "error": String(describing: error)])
            return false
        }
    }

    private func notifyMessagesAppViaAppleScript() {
        // The fundamental issue: Messages.app caches read status and doesn't automatically
        // detect database changes. There are a few approaches:
        //
        // 1. AppleScript - Requires "Automation" permissions for Messages
        // 2. Distributed notifications - Messages might listen to these
        // 3. Kill and restart imagent - Too invasive
        // 4. Wait for Messages to naturally refresh - Happens on app launch/wake
        //
        // Try sending a distributed notification that Messages might respond to
        DebugLogger.shared.log("Attempting to notify Messages via distributed notification", category: "MARK_READ")

        let notificationCenter = DistributedNotificationCenter.default()

        // Try various notification names that Messages might listen to
        let notificationNames = [
            "com.apple.imdpersistence.IMDMessageStore.MessageStoreDidMarkMessagesAsRead",
            "com.apple.imdpersistence.IMDMessageStore.MessageStoreDidChange",
            "com.apple.MobileSMS.MarkAsRead",
            "com.apple.messages.MarkAsRead"
        ]

        for notificationName in notificationNames {
            notificationCenter.post(
                name: NSNotification.Name(notificationName),
                object: nil,
                userInfo: nil
            )
        }

        DebugLogger.shared.log("Distributed notifications sent", category: "MARK_READ", data: ["notifications": notificationNames])

        // Also try a simple AppleScript that doesn't require automation permissions
        // Just check if Messages is running - this shouldn't require special permissions
        let simpleScript = """
        tell application "System Events"
            set messagesRunning to exists (processes where name is "Messages")
            if messagesRunning then
                return "Messages is running"
            else
                return "Messages is not running"
            end if
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: simpleScript) {
            let output = scriptObject.executeAndReturnError(&error)
            if let error = error {
                DebugLogger.shared.log("AppleScript check failed", category: "MARK_READ", data: ["error": error])
            } else {
                DebugLogger.shared.log("Messages app status check", category: "MARK_READ", data: ["status": output.stringValue ?? "unknown"])
            }
        }
    }
}
