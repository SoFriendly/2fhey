//
//  MessageManager.swift
//  ohtipi
//
//  Created by Drew Pomerleau on 4/22/22.
//

extension String {
  var isBlank: Bool {
    return allSatisfy({ $0.isWhitespace })
  }
}

import Foundation
import SQLite

typealias MessageWithParsedOTP = (Message, ParsedOTP)
typealias Expression = SQLite.Expression

class MessageManager: ObservableObject {
    @Published var messages: [MessageWithParsedOTP] = []
    
    private let checkTimeInterval: TimeInterval = 1
    private var processedGuids: Set<String> = []
    
    var otpParser: OTPParser
    
    init(withOTPParser otpParser: OTPParser) {
        self.otpParser = otpParser
    }
    
    var timer: Timer?
    
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
            .where(messageTable[dateColumn] > timeOffsetForDate(date) && messageTable[serviceColumn] == "SMS")
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
    
    @objc func syncMessages() {
        guard let modifiedDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) else { return }
        
        do {
            let parsedOtps = try findPossibleOTPMessagesAfterDate(modifiedDate)
            guard parsedOtps.count > 0 else { return }
            messages.append(contentsOf: parsedOtps)
        } catch let err {
            print("ERR: \(err)")
        }
    }
    
    private func findPossibleOTPMessagesAfterDate(_ date: Date) throws -> [MessageWithParsedOTP] {
        let messagesFromDB = try loadMessagesAfterDate(date)
        let filteredMessages = messagesFromDB
            .filter { !$0.fromMe }
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
}
