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
        
        if #available(macOS 10.13, *) {
            let factor = Int(pow(10.0, 9))
            appleOffsetForDate *= factor
        }
        
        return appleOffsetForDate
    }
    
    private func loadMessagesAfterDate(_ date: Date) throws -> [Message] {
        var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        homeDirectory.appendPathComponent("/Library/Messages/chat.db")
        let db = try Connection(homeDirectory.absoluteString)
        
        let textColumn = Expression<String?>("text")
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
        
        let query = messageTable
            .select(messageTable[guidColumn], messageTable[fromMeColumn], messageTable[textColumn], messageTable[cacheRoomnamesColumn], messageTable[dateColumn], handleFrom, messageTable[serviceColumn])
            .join(.leftOuter, handleTable, on: messageHandleId == handleTable[ROWID])
            .where(messageTable[dateColumn] > timeOffsetForDate(date))  // Removed SMS filter to include iMessage
            // Original: .where(messageTable[dateColumn] > timeOffsetForDate(date) && messageTable[serviceColumn] == "SMS")
            .order(messageTable[dateColumn].asc)

        let mapRowIterator = try db.prepareRowIterator(query)
        let messages = try mapRowIterator.map { messageRow -> Message? in
            guard let text = messageRow[textColumn], let handle = messageRow[handleFrom] else { return nil }
            
            return Message(
                guid: messageRow[guidColumn],
                text: text,
                handle: handle,
                group: messageRow[cacheRoomnamesColumn],
                fromMe: messageRow[fromMeColumn])
        }
        
        return messages.compactMap { $0 }
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
            return
        }

        guard let modifiedDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) else { return }

        do {
            let parsedOtps = try findPossibleOTPMessagesAfterDate(modifiedDate)
            guard parsedOtps.count > 0 else { return }
            messages.append(contentsOf: parsedOtps)
        } catch let err {
            // Only log unexpected errors (not permission denied)
            let errorString = String(describing: err)
            if !errorString.contains("authorization denied") {
                print("ERR: \(err)")
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
        guard AppStateManager.shared.markAsReadEnabled else { return }
        guard AppStateManager.shared.hasFullDiscAccess() == .authorized else { return }

        do {
            var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            homeDirectory.appendPathComponent("/Library/Messages/chat.db")
            let db = try Connection(homeDirectory.absoluteString)

            let messageTable = Table("message")
            let guidColumn = Expression<String>("guid")
            let isReadColumn = Expression<Bool>("is_read")

            let message = messageTable.filter(guidColumn == guid)

            try db.run(message.update(isReadColumn <- true))
        } catch {
            // Silently fail - avoid log spam
        }
    }
}
