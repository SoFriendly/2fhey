//
//  TwoFHeyTests.swift
//  TwoFHeyTests
//
//  Parser tests: every supported message format must parse, and no phone
//  number may ever be returned as a code.
//

import XCTest
import Network
@testable import _FHey

class OTPParserTests: XCTestCase {
    let parser = OTPParser()

    private func assertCode(_ message: String, _ expected: String, sender: String? = nil,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(parser.parse(message, sender: sender)?.code, expected, file: file, line: line)
    }

    private func assertNoCode(_ message: String, sender: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(parser.parse(message, sender: sender), file: file, line: line)
    }

    // MARK: - Supported formats (feature parity)

    func testCommonEnglishFormats() {
        assertCode("Your Apple ID Code is: 654321. Don't share it with anyone.", "654321")
        assertCode("123456 is your Amazon OTP. Do not share it with anyone.", "123456")
        assertCode("Your code: 456789", "456789")
        assertCode("Your verification code is 789012", "789012")
        assertCode("Your security code is: 654321", "654321")
        assertCode("Your login code: 123456", "123456")
        assertCode("Your one-time password is 987654", "987654")
        assertCode("Your validation code is 456123", "456123")
        assertCode("Your confirmation code: 789456", "789456")
        assertCode("132637 is your Link verification code.", "132637")
        assertCode("Your portal verification code is : jh7112 Msg&Data rates may apply.", "jh7112")
    }

    func testGoogleFormat() {
        let parsed = parser.parse("G-123456 is your Google verification code.")
        XCTAssertEqual(parsed?.code, "G-123456")
        XCTAssertEqual(parsed?.service, "google")
    }

    func testAlphanumericCodes() {
        assertCode("ABC123 is your verification code", "ABC123")
        assertCode("GEICO: Your verification code is: ABC123. It expires in 10 minutes.", "ABC123")
        assertCode("Your code is AB12C.", "AB12C")
    }

    func testBankFormats() {
        assertCode("Truist Alerts: To verify the JAILATM CO transaction on card 0323, use 582270. We won't contact you for this code.", "582270")
        assertCode("From: Chase\nWe'll NEVER call you to ask for this code.\nOne-Time Code:12345678\nOnly use this online. Code expires in 30 min.", "12345678")
        assertCode("123456 is the OTP for transaction on your Kotak Bank Card valid for 15 mins. DONT SHARE OTP WITH ANYONE.", "123456")
    }

    func testChineseFormats() {
        assertCode("【知乎】你的验证码是 700185，此验证码用于登录知乎或重置密码。10 分钟内有效。", "700185")
        assertCode("【京东】验证码：548393，您正在新设备上登录。", "548393")
    }

    func testHebrewFormat() {
        assertCode("קוד האימות שלך הוא 123456", "123456")
    }

    func testCustomPatterns() {
        assertCode("Please use SGD-123456 within 3 minutes to authorize this transaction.", "123456")
        assertCode("Your passcode is\n1234-567890", "1234")
        assertCode("12345678\nValid 5 minutes. Do not share.", "12345678")
        assertCode("@valid.aoc.cat #654321", "654321")
        assertCode("Ihr Bestätigungscode ist: AB3C45", "AB3C45")
        assertCode("OTP to MAKE A NEW PAYMENT of GBP 9.94 to 560027 & 27613445. Call us if this wasn't you. NEVER share this code, not even with Cater Allen staff 699486", "699486")
    }

    func testSpacedAndDashedCodes() {
        assertCode("Your verification code is 123 456", "123456")
        assertCode("Your code: 123-456", "123456")
    }

    func testServiceExtraction() {
        XCTAssertEqual(parser.parse("Your Google verification code is 123456")?.service, "google")
        XCTAssertEqual(parser.parse("123456 is your Amazon OTP.")?.service, "amazon")
    }

    // MARK: - Phone numbers must never be codes

    func testPhoneNumberIsNeverTheCode() {
        // Phone numbers in every common format, alongside a real code.
        assertCode("New login from +1 (415) 555-2671. Your code is 887766.", "887766")
        assertCode("Your verification code is 123456. Call us at 555-123-4567 if this wasn't you.", "123456")
        assertCode("Call 555.123.4567 to opt out. Your code: 246810", "246810")
        assertCode("Your code is 445566. Questions? Text 787473.", "445566")
        assertCode("Verification code 998877. Support: +447911123456.", "998877")
    }

    func testMessageWithOnlyPhoneNumbersHasNoCode() {
        assertNoCode("Call us to verify your account at 555-123-4567.")
        assertNoCode("Your verification call will come from +1 415 555 2671.")
        assertNoCode("To verify, text HELP to 466453.")
        assertNoCode("787473") // bare short-code sender in a title
    }

    func testSenderNumberIsNeverTheCode() {
        // The sender's own number (or any fragment of it) must never be returned,
        // even when the message contains keywords licensing digit extraction.
        assertNoCode("Verification message from 787473", sender: "787473")
        assertNoCode("Your code is 314159", sender: "314159263")
        assertCode("Use code 528491 to log in.", "528491", sender: "+15555551234")
    }

    func testTenDigitNumbersAreNotCodes() {
        // Bare 10-digit strings look like phone numbers, not OTPs.
        assertNoCode("Your verification code request was received. Ref 4155552671123.")
        assertNoCode("code: 4155552671")
    }

    // MARK: - Other non-codes

    func testMoneyTimesAndDatesAreNotCodes() {
        assertNoCode("Your payment of 1234.56 was confirmed at 10:30 on 12/25/2025.")
        assertCode("Your code 654321 expires at 10:30 am on the 25th.", "654321")
    }

    func testURLPathsAreNotCodes() {
        assertCode("Your code is 246813. Details: https://example.com/verify/999999", "246813")
        assertNoCode("Verify at https://example.com/session/12345678")
    }

    func testOptOutFootersAreNotCodes() {
        // A keyword with no real code must not fall through to the opt-out footer.
        assertNoCode("Please verify your account at example.com/account. Reply Stop2End to opt out")
        assertNoCode("Please verify your account at example.com/account. Reply STOP2END to opt out")
        assertNoCode("Please verify your account at example.com/account.\n\nEnd2End")
        // A real code in the same message is still returned.
        assertCode("Your verification code is 482913. Reply Stop2End to opt out", "482913")
    }

    func testKeywordInsideOrdinaryWordDoesNotEnableExtraction() {
        // "auth" appears only inside "authoritarian".
        assertNoCode("His authoritarian agenda is a threat. We won in 2024 and can win again. Give $15 today.")
        // "pin" appears only inside "helping".
        assertNoCode("Thanks for helping us grow. Our 2024 goal is on track.")
    }

    func testShortKeywordsStillMatchAsWholeWords() {
        assertCode("Your PIN is 7391", "7391")
        assertCode("Your PINs are 7391 and 8264", "7391")
        assertCode("Your codes are 123456 and 654321", "123456")
        assertCode("Use the auth code 246810 to log in.", "246810")
        assertCode("Your OTP: 482913", "482913")
        assertCode("Use 2FA code 135790 now", "135790")
    }

    func testCompoundKeywordsStillMatchInsideLongerWords() {
        // German keywords are often the stem of a compound word.
        assertCode("Ihr Sicherheitscode ist 123456", "123456")
        assertCode("Ihr Verifizierungscode lautet 654321", "654321")
    }

    func testKeywordInsideURLDoesNotEnableExtraction() {
        // "pin" appears only in the link path, so nothing else in the message may become a code.
        assertNoCode("Will you chip in $15 to our campaign? i.example.com/ppiNg4AP\n\nStop2End")
        // "code" appears only in a query parameter name.
        assertNoCode("Chip in today: https://example.com/donate?refcode=abc\n\nSD26")
    }

    func testMessagesWithoutKeywordsAreIgnored() {
        assertNoCode("Hey, meet me at 123456 Main St")
        assertNoCode("Running 15 minutes late, sorry!")
    }
}

// MARK: - NotificationServer

/// The Google Messages bridge listens on a local port. Any web page the user opens can reach
/// that port, so the server must refuse foreign origins and must not listen beyond loopback.
final class NotificationServerTests: XCTestCase {
    private static var nextPort: UInt16 = 28470

    private var server: NotificationServer!
    private var port: UInt16 = 0
    private var received: [(title: String, body: String)] = []

    override func setUp() {
        super.setUp()
        Self.nextPort += 1
        port = Self.nextPort
        received = []
        server = NotificationServer(port: port, allowTLS: false)
        server.onNotificationReceived = { [weak self] title, body, _ in
            self?.received.append((title, body))
        }
        server.start()
        Thread.sleep(forTimeInterval: 0.3)
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }

    /// Sends one raw HTTP request to `host` and returns whatever comes back first.
    private func send(_ request: String, host: String = "127.0.0.1", timeout: TimeInterval = 3) -> String? {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        let done = DispatchSemaphore(value: 0)
        var response: String?
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: request.data(using: .utf8), completion: .contentProcessed { _ in })
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                    response = data.flatMap { String(data: $0, encoding: .utf8) }
                    done.signal()
                }
            case .failed, .cancelled:
                done.signal()
            default:
                break
            }
        }
        connection.start(queue: .global())
        _ = done.wait(timeout: .now() + timeout)
        connection.cancel()
        return response
    }

    private func post(origin: String?, body: String = #"{"title":"Bank","body":"Your code is 123456"}"#) -> String? {
        var lines = ["POST /notification HTTP/1.1", "Host: 127.0.0.1:\(port)", "Content-Type: application/json"]
        if let origin { lines.append("Origin: \(origin)") }
        lines.append("Content-Length: \(body.utf8.count)")
        return send(lines.joined(separator: "\r\n") + "\r\n\r\n" + body)
    }

    private func upgrade(origin: String?) -> String? {
        var lines = ["GET / HTTP/1.1", "Host: 127.0.0.1:\(port)", "Upgrade: websocket", "Connection: Upgrade",
                     "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==", "Sec-WebSocket-Version: 13"]
        if let origin { lines.append("Origin: \(origin)") }
        return send(lines.joined(separator: "\r\n") + "\r\n\r\n")
    }

    private func drainMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
    }

    func testForeignOriginPostIsRejected() {
        let response = post(origin: "https://evil.example")
        XCTAssertTrue(response?.hasPrefix("HTTP/1.1 403") == true, "got: \(response ?? "nil")")
        drainMainQueue()
        XCTAssertTrue(received.isEmpty)
    }

    func testLookalikeOriginIsRejected() {
        for origin in ["https://messages.google.com.evil.example", "http://messages.google.com", "null"] {
            let response = post(origin: origin)
            XCTAssertTrue(response?.hasPrefix("HTTP/1.1 403") == true, "\(origin) got: \(response ?? "nil")")
        }
        drainMainQueue()
        XCTAssertTrue(received.isEmpty)
    }

    func testForeignOriginWebSocketUpgradeIsRejected() {
        let response = upgrade(origin: "https://evil.example")
        XCTAssertTrue(response?.hasPrefix("HTTP/1.1 403") == true, "got: \(response ?? "nil")")
    }

    func testGoogleMessagesOriginWebSocketUpgradeIsAccepted() {
        let response = upgrade(origin: "https://messages.google.com")
        XCTAssertTrue(response?.hasPrefix("HTTP/1.1 101") == true, "got: \(response ?? "nil")")
    }

    func testOriginlessPostStillWorksForCurlTesting() {
        let response = post(origin: nil)
        XCTAssertTrue(response?.hasPrefix("HTTP/1.1 200") == true, "got: \(response ?? "nil")")
        drainMainQueue()
        XCTAssertEqual(received.first?.title, "Bank")
    }

    func testResponsesCarryNoWildcardCORSHeader() {
        let response = post(origin: nil) ?? ""
        XCTAssertFalse(response.lowercased().contains("access-control-allow-origin"), response)
    }

    /// Reads the kernel's view of the listening socket, because dialing the machine's own LAN
    /// address from the test host is blocked by macOS and would pass whatever the server does.
    func testListensOnLoopbackOnly() throws {
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-Fn"]
        let pipe = Pipe()
        lsof.standardOutput = pipe
        try lsof.run()
        lsof.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        let addresses = output.split(separator: "\n").filter { $0.hasPrefix("n") }.map { String($0.dropFirst()) }
        XCTAssertFalse(addresses.isEmpty, "nothing is listening on \(port)")
        for address in addresses {
            XCTAssertTrue(address.hasPrefix("127.0.0.1:") || address.hasPrefix("[::1]:"),
                          "listening beyond loopback: \(address)")
        }
    }
}
