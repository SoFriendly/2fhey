//
//  TwoFHeyTests.swift
//  TwoFHeyTests
//
//  Parser tests: every supported message format must parse, and no phone
//  number may ever be returned as a code.
//

import XCTest
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

    func testMessagesWithoutKeywordsAreIgnored() {
        assertNoCode("Hey, meet me at 123456 Main St")
        assertNoCode("Running 15 minutes late, sorry!")
    }
}

// MARK: - Remote pattern updates

/// Pattern files are fetched from GitHub at runtime and cached on disk, where they outlive the
/// session. A file that is huge, or holds a regex that backtracks catastrophically, would freeze
/// the app on every incoming message, so such a file must never reach the cache.
final class RemotePatternTests: XCTestCase {
    private final class StubProtocol: URLProtocol {
        static var bodies: [String: Data] = [:]

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let url = request.url!
            let body = Self.bodies[url.lastPathComponent]
            let response = HTTPURLResponse(url: url, statusCode: body == nil ? 404 : 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body ?? Data())
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private var cache: URL!
    private var parser: OTPParser!

    override func setUpWithError() throws {
        cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        StubProtocol.bodies = [:]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        parser = OTPParser(remoteBaseURL: URL(string: "https://patterns.test/OTPKeywords")!,
                           cacheDirectory: cache,
                           session: URLSession(configuration: configuration),
                           refreshOnInit: false)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cache)
    }

    private func languageFile(keywords: [String] = ["code"], patterns: [String] = [#"\b\d{6}\b"#]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["keywords": keywords, "patterns": patterns])
    }

    private func customFile(patterns: [String]) -> Data {
        let entries = patterns.map { ["service": "Example", "pattern": $0] }
        return try! JSONSerialization.data(withJSONObject: ["customPatterns": entries])
    }

    private func isCached(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: cache.appendingPathComponent(name).path)
    }

    private func assertRejected(_ body: Data, as name: String = "en.json", _ message: String,
                                file: StaticString = #filePath, line: UInt = #line) async {
        StubProtocol.bodies[name] = body
        await parser.refreshFromRemote()
        XCTAssertFalse(isCached(name), message, file: file, line: line)
    }

    func testWellFormedUpdateIsCached() async {
        StubProtocol.bodies["en.json"] = languageFile()
        await parser.refreshFromRemote()
        XCTAssertTrue(isCached("en.json"))
    }

    func testBundledFilesPassTheSameChecks() async throws {
        let bundle = Bundle(for: OTPParser.self)
        for name in ["en", "fr", "zh", "es", "de", "pt", "he", "custom-patterns"] {
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json", subdirectory: "OTPKeywords")
                                    ?? bundle.url(forResource: name, withExtension: "json"), name)
            StubProtocol.bodies["\(name).json"] = try Data(contentsOf: url)
        }
        await parser.refreshFromRemote()
        for name in ["en", "fr", "zh", "es", "de", "pt", "he", "custom-patterns"] {
            XCTAssertTrue(isCached("\(name).json"), "\(name).json was rejected")
        }
    }

    func testOversizedFileIsRejected() async {
        await assertRejected(languageFile(keywords: [String(repeating: "a", count: 200_000)]), "200 KB file was cached")
    }

    func testTooManyEntriesAreRejected() async {
        await assertRejected(languageFile(patterns: Array(repeating: #"\d{6}"#, count: 500)), "500 patterns were cached")
        await assertRejected(languageFile(keywords: Array(repeating: "code", count: 500)), "500 keywords were cached")
    }

    func testOverlongPatternIsRejected() async {
        await assertRejected(languageFile(patterns: [String(repeating: "a", count: 2_000)]), "2,000 character pattern was cached")
    }

    func testCatastrophicBacktrackingPatternsAreRejected() async {
        for pattern in ["(a+)+$", #"(\d+)*x"#, "(a|aa)+$", #"(?:\d{3,})+z"#, #"(.*a)+x"#] {
            await assertRejected(languageFile(patterns: [pattern]), "\(pattern) was cached")
            await assertRejected(customFile(patterns: [pattern]), as: "custom-patterns.json", "\(pattern) was cached as a custom pattern")
        }
    }

    func testHarmlessLookalikesAreStillAccepted() async {
        // An escaped parenthesis, a parenthesis inside a character class, and a group with a bounded repeat.
        StubProtocol.bodies["en.json"] = languageFile(patterns: [#"code\)+ (\d{6})"#, #"[)]+(\d{6})"#, #"(\d{3}){2}"#])
        await parser.refreshFromRemote()
        XCTAssertTrue(isCached("en.json"))
    }

    func testOneBadFileDoesNotBlockTheGoodOnes() async {
        StubProtocol.bodies["en.json"] = languageFile(patterns: ["(a+)+$"])
        StubProtocol.bodies["fr.json"] = languageFile()
        await parser.refreshFromRemote()
        XCTAssertFalse(isCached("en.json"))
        XCTAssertTrue(isCached("fr.json"))
    }

    func testRejectedUpdateLeavesThePreviousCachedCopyAlone() async throws {
        let previous = languageFile(keywords: ["previous"])
        try previous.write(to: cache.appendingPathComponent("en.json"))
        StubProtocol.bodies["en.json"] = languageFile(patterns: ["(a+)+$"])
        await parser.refreshFromRemote()
        XCTAssertEqual(try Data(contentsOf: cache.appendingPathComponent("en.json")), previous)
    }
}
