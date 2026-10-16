//
//  OTPParser.swift
//  2FHey
//
//  Extracts one-time codes from message text. Every candidate code must survive
//  the NumberGuard, which rejects anything that looks like a phone number, the
//  sender's own number, money, a time, or a date — so a phone number can never
//  be returned as a code.
//

import Foundation
import AppKit

struct ParsedOTP: Equatable {
    let service: String?
    let code: String

    /// Copies the code to the clipboard and returns the previous contents (for later restore).
    func copyToClipboard() -> String? {
        let original = AppStateManager.shared.restoreContentsEnabled ? NSPasteboard.general.string(forType: .string) : nil
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        return original
    }
}

final class OTPParser {
    private struct LanguageFile: Codable {
        let keywords: [String]
        let patterns: [String]
    }

    private struct CustomPatternsFile: Codable {
        struct Entry: Codable {
            let service: String
            let pattern: String
        }
        let customPatterns: [Entry]
    }

    private struct Configuration {
        var keywords: [String] = []
        var languagePatterns: [NSRegularExpression] = []
        var customPatterns: [(service: String, regex: NSRegularExpression)] = []
    }

    private static let languageFiles = ["en.json", "fr.json", "zh.json", "es.json", "de.json", "pt.json", "he.json"]
    private static let customPatternsFile = "custom-patterns.json"
    static let defaultRemoteBaseURL = URL(string: "https://raw.githubusercontent.com/SoFriendly/2fhey/main/TwoFHey/OTPKeywords")!

    private let remoteBaseURL: URL
    private let cacheDirectory: URL
    private let session: URLSession

    private let lock = NSLock()
    private var _configuration: Configuration
    private var configuration: Configuration {
        lock.lock()
        defer { lock.unlock() }
        return _configuration
    }

    /// The parameters are a test seam; the app uses the defaults.
    init(remoteBaseURL: URL = OTPParser.defaultRemoteBaseURL,
         cacheDirectory: URL = OTPParser.defaultCacheDirectory(),
         session: URLSession = .shared,
         refreshOnInit: Bool = true) {
        self.remoteBaseURL = remoteBaseURL
        self.cacheDirectory = cacheDirectory
        self.session = session
        Self.clearCacheIfAppVersionChanged(in: cacheDirectory)
        _configuration = Self.loadConfiguration(cacheDirectory: cacheDirectory)
        guard refreshOnInit else { return }
        Task.detached(priority: .utility) { [weak self] in
            await self?.refreshFromRemote()
        }
    }

    /// A new build's bundled patterns must not be shadowed by files cached from
    /// an older version, so the cache is cleared on the first launch after an update.
    private static func clearCacheIfAppVersionChanged(in cacheDirectory: URL) {
        let version = [Bundle.main.infoDictionary?["CFBundleShortVersionString"],
                       Bundle.main.infoDictionary?["CFBundleVersion"]]
            .compactMap { $0 as? String }.joined(separator: "-")
        let marker = cacheDirectory.appendingPathComponent("app-version.txt")
        guard (try? String(contentsOf: marker, encoding: .utf8)) != version else { return }
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? version.write(to: marker, atomically: true, encoding: .utf8)
    }

    // MARK: - Pattern loading

    /// Loads each pattern file, preferring a cached copy downloaded from GitHub
    /// and falling back to the bundled copy.
    private static func loadConfiguration(cacheDirectory: URL) -> Configuration {
        var config = Configuration()
        for fileName in languageFiles {
            guard let data = fileData(fileName, cacheDirectory: cacheDirectory),
                  let file = try? JSONDecoder().decode(LanguageFile.self, from: data) else { continue }
            config.keywords.append(contentsOf: file.keywords.map { $0.lowercased() })
            config.languagePatterns.append(contentsOf: file.patterns.compactMap {
                try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
            })
        }
        if let data = fileData(customPatternsFile, cacheDirectory: cacheDirectory),
           let file = try? JSONDecoder().decode(CustomPatternsFile.self, from: data) {
            config.customPatterns = file.customPatterns.compactMap { entry in
                (try? NSRegularExpression(pattern: entry.pattern)).map { (entry.service, $0) }
            }
        }
        return config
    }

    private static func fileData(_ fileName: String, cacheDirectory: URL) -> Data? {
        let cached = cacheDirectory.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: cached) {
            return data
        }
        let resource = (fileName as NSString).deletingPathExtension
        let bundle = Bundle(for: OTPParser.self)
        let url = bundle.url(forResource: resource, withExtension: "json", subdirectory: "OTPKeywords")
            ?? bundle.url(forResource: resource, withExtension: "json")
        return url.flatMap { try? Data(contentsOf: $0) }
    }

    static func defaultCacheDirectory() -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OTPKeywords")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Downloads updated pattern files from GitHub so new patterns can ship
    /// without an app update. Each file is validated before it is cached; on any
    /// failure the existing cached or bundled copy stays in use.
    func refreshFromRemote() async {
        var updatedAny = false
        for fileName in Self.languageFiles + [Self.customPatternsFile] {
            guard let data = await download(remoteBaseURL.appendingPathComponent(fileName)),
                  Self.isAcceptable(data, fileName: fileName) else { continue }

            do {
                try data.write(to: cacheDirectory.appendingPathComponent(fileName))
                updatedAny = true
            } catch {
                DebugLogger.shared.log("Failed to cache pattern file", category: "PARSER", data: fileName)
            }
        }

        if updatedAny {
            let refreshed = Self.loadConfiguration(cacheDirectory: cacheDirectory)
            lock.lock()
            _configuration = refreshed
            lock.unlock()
            DebugLogger.shared.log("Pattern files refreshed from GitHub", category: "PARSER")
        }
    }

    // MARK: - Remote file limits

    private static let maxFileBytes = 64 * 1024
    private static let maxEntries = 200
    private static let maxPatternLength = 300

    /// Reads at most `maxFileBytes`, so a hostile or broken host cannot make us buffer an unbounded body.
    private func download(_ url: URL) async -> Data? {
        guard let (bytes, response) = try? await session.bytes(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count > Self.maxFileBytes { return nil }
            }
        } catch {
            return nil
        }
        return data
    }

    /// A file is cached whole or not at all: one bad entry rejects the file, so a partial
    /// update never mixes trusted and untrusted patterns.
    private static func isAcceptable(_ data: Data, fileName: String) -> Bool {
        let decoder = JSONDecoder()
        if fileName == customPatternsFile {
            guard let file = try? decoder.decode(CustomPatternsFile.self, from: data) else { return false }
            return file.customPatterns.count <= maxEntries && file.customPatterns.allSatisfy { isSafe(pattern: $0.pattern) }
        }
        guard let file = try? decoder.decode(LanguageFile.self, from: data) else { return false }
        return file.keywords.count <= maxEntries && file.patterns.count <= maxEntries && file.patterns.allSatisfy { isSafe(pattern: $0) }
    }

    /// NSRegularExpression backtracks and has no time limit, so a pattern such as `(a+)+$` can freeze
    /// the app on a short message. Reject any group repeated without a bound (`)+`, `)*`, `){n,}`).
    /// The bundled patterns use none, and bounded repeats such as `(\d{3}){2}` stay allowed.
    private static func isSafe(pattern: String) -> Bool {
        guard pattern.count <= maxPatternLength else { return false }
        let characters = Array(pattern)
        var escaped = false
        var inClass = false
        for (index, character) in characters.enumerated() {
            if escaped { escaped = false; continue }
            if character == "\\" { escaped = true; continue }
            if inClass { inClass = character != "]"; continue }
            if character == "[" { inClass = true; continue }
            if character == ")" && repeatsWithoutBound(characters[(index + 1)...]) { return false }
        }
        return true
    }

    private static func repeatsWithoutBound(_ rest: ArraySlice<Character>) -> Bool {
        guard let next = rest.first else { return false }
        if next == "+" || next == "*" { return true }
        return next == "{" && String(rest).range(of: #"^\{\d+,\}"#, options: .regularExpression) != nil
    }

    /// Parses a message body for a one-time code. `sender` (a handle, phone number,
    /// or notification title) is never searched for codes — it is only used to make
    /// sure the sender's own number is never returned.
    func parse(_ text: String, sender: String? = nil) -> ParsedOTP? {
        let config = configuration
        let senderDigits = sender.map { String($0.filter(\.isNumber)) } ?? ""

        // 1. Service-specific patterns are the most precise signal we have.
        let fullGuard = NumberGuard(text: text, senderDigits: senderDigits)
        for (service, regex) in config.customPatterns {
            guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { continue }
            for group in 1..<match.numberOfRanges {
                guard let range = Range(match.range(at: group), in: text) else { continue }
                let code = Self.normalize(text[range])
                if Self.isPlausibleCode(code, allowLongNumeric: true), fullGuard.allows(range, code: code) {
                    return ParsedOTP(service: service.lowercased(), code: code)
                }
            }
        }

        // 2. Google's G-XXXXX format. The G- prefix can't be part of a phone number.
        if let range = Self.googlePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
            .flatMap({ Range($0.range(at: 1), in: text) }) {
            return ParsedOTP(service: "google", code: String(text[range]))
        }

        // 3. Everything below requires an OTP keyword somewhere in the message.
        let lowercased = text.lowercased()
        guard config.keywords.contains(where: lowercased.contains) else { return nil }

        // URLs are stripped so their path segments can't be mistaken for codes.
        let searchText = Self.stripURLs(from: text)
        let guarded = NumberGuard(text: searchText, senderDigits: senderDigits)
        let service = extractService(from: lowercased, keywords: config.keywords)

        // 3a. Anchored language patterns ("code is 123456", "验证码：123456", ...).
        for pattern in config.languagePatterns {
            let matches = pattern.matches(in: searchText, range: NSRange(searchText.startIndex..., in: searchText))
            for match in matches where match.numberOfRanges > 1 {
                guard let range = Range(match.range(at: 1), in: searchText) else { continue }
                let code = Self.normalize(searchText[range])
                if code.contains(where: \.isNumber), Self.isPlausibleCode(code), guarded.allows(range, code: code) {
                    return ParsedOTP(service: service, code: code)
                }
            }
        }

        // 3b. Fallback: standalone tokens in order of appearance — plain digit runs,
        // spaced/dashed 3+3 groups, and mixed alphanumeric tokens.
        for pattern in Self.fallbackPatterns {
            let matches = pattern.matches(in: searchText, range: NSRange(searchText.startIndex..., in: searchText))
            for match in matches {
                guard let range = Range(match.range(at: 1), in: searchText) else { continue }
                let code = Self.normalize(searchText[range])
                if Self.isPlausibleCode(code), guarded.allows(range, code: code) {
                    return ParsedOTP(service: service, code: code)
                }
            }
        }

        return nil
    }

    // MARK: - Candidate validation

    /// Collapses a raw match to its alphanumeric characters (drops spaces/dashes/newlines).
    private static func normalize(_ raw: Substring) -> String {
        raw.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }

    /// A plausible code is 4-8 digits, or 4-10 characters when mixed with letters.
    /// Purely numeric strings longer than 8 digits look like phone/account numbers,
    /// so only explicitly whitelisted custom patterns may return them.
    private static func isPlausibleCode(_ code: String, allowLongNumeric: Bool = false) -> Bool {
        guard code.count >= 4, code.count <= 10, code.contains(where: \.isNumber) else { return false }
        if code.allSatisfy(\.isNumber) && !allowLongNumeric {
            return code.count <= 8
        }
        return true
    }

    private static let googlePattern = try! NSRegularExpression(pattern: #"\b(G-[A-Z0-9]{5,8})\b"#)

    private static let fallbackPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\b(\d{4,8})\b"#),
        try! NSRegularExpression(pattern: #"\b(\d{3}[\s\-]\d{3})\b"#),
        try! NSRegularExpression(pattern: #"\b([A-Za-z0-9]*\d[A-Za-z0-9]*)\b"#),
    ]

    private static let urlPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"https?://\S+"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"[a-zA-Z0-9][-a-zA-Z0-9]*(?:\.[a-zA-Z0-9][-a-zA-Z0-9]*)+/\S*"#),
    ]

    private static func stripURLs(from text: String) -> String {
        urlPatterns.reduce(text) { result, pattern in
            pattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
    }

    // MARK: - Service name extraction (best effort)

    private static let knownServices = [
        "td ameritrade", "coinbase", "ally", "schwab", "id.me", "bofa", "wise.com", "paypal",
        "venmo", "verizon", "kotak bank", "weibo", "wechat", "whatsapp", "viber", "snapchat",
        "slack", "signal", "telegram", "kakaotalk", "skype", "facebook", "microsoft", "google",
        "twitter", "instagram", "sony", "apple", "ubereats", "uber", "lyft", "postmates",
        "doordash", "chipotle", "amazon", "tencent", "alibaba", "taobao", "baidu", "yandex",
        "ebay", "intel", "cisco", "oracle", "ibm", "foursquare", "hotmail", "outlook", "yahoo",
        "netflix", "spotify", "nike", "adidas", "shopify", "wordpress", "yelp", "grubhub",
        "seamless", "github", "flickr", "etsy", "bank of america", "zocdoc", "twilio", "xbox",
        "kayak", "grab", "moonpay", "robinhood", "cater allen", "apple pay", "bill.com", "amex",
        "fanduel", "ca dmv", "chase", "digitalocean", "geico", "dbs bank", "onelogin", "usps",
        "migov", "pf-bank", "vodafone", "mygov", "bforbank", "idcat mobil", "revolut",
        "fnz bank", "sofi", "aeroplan", "truist", "link",
    ]

    private static let commonWords: Set<String> = [
        "your", "the", "this", "that", "here", "use", "enter", "please", "not", "share",
        "will", "valid", "only", "sent", "ton", "vous", "votre", "une", "des", "ici",
        "utilisez", "entrez", "merci", "pas", "uniquement", "seulement", "partagez", "sera",
    ]

    private static let servicePatterns: [NSRegularExpression] = [
        #"^\[([^\]\d]{3,})\]"#,
        #"^\(([^)\d]{3,})\)"#,
        #"^welcome\s+to\s+([\w ]{4,}?)[\s,;.]"#,
        #"from\s+([a-z0-9 ]+?)(?:\s|$)"#,
        #"(?:verification|code|otp|pin)\s+(?:for|from)\s+([a-z0-9 ]+?)(?:\s|$)"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    private func extractService(from lowercased: String, keywords: [String]) -> String? {
        if let known = Self.knownServices.first(where: lowercased.contains) {
            return known
        }
        for pattern in Self.servicePatterns {
            guard let match = pattern.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
                  let range = Range(match.range(at: 1), in: lowercased) else { continue }
            let service = lowercased[range].trimmingCharacters(in: .whitespaces)
            if service.count > 2, !keywords.contains(service), !Self.commonWords.contains(service) {
                return service
            }
        }
        return nil
    }
}

// MARK: - NumberGuard

/// Identifies every range of a message that must never be treated as a code:
/// phone numbers in any common format, numbers being dialed or texted, money,
/// decimals, times, dates, and ordinals. Also rejects any candidate whose digits
/// appear in the sender's own number.
private struct NumberGuard {
    private static let forbiddenPatterns: [NSRegularExpression] = [
        // International numbers: +1 415 555 2671, +447911123456, ...
        #"\+\d[\d\s().\-]{5,}\d"#,
        // NANP: 555-123-4567, (555) 123-4567, 555.123.4567
        #"\(?\b\d{3}\)?[-. ]\d{3}[-. ]\d{4}\b"#,
        // Seven-digit local numbers: 555-1234
        #"\b\d{3}[-.]\d{4}\b"#,
        // Digit runs too long to be codes (account and phone numbers).
        #"\d{9,}"#,
        // Numbers you're told to call or text are contact numbers, not codes.
        #"(?i)\b(?:call|text|dial|sms|fax)\b[^\d\n]{0,20}[+(]?\d[\d ().\-]*"#,
        // Money, decimals, times, meridiem times, ordinals, and dates.
        #"[$€£₹¥]\s?\d[\d,.]*"#,
        #"\b\d+[.,]\d+\b"#,
        #"\b\d{1,2}:\d{2}\b"#,
        #"(?i)\b\d+\s?(?:am|pm)\b"#,
        #"(?i)\b\d+(?:st|nd|rd|th)\b"#,
        #"\b\d{1,4}[-/]\d{1,2}[-/]\d{1,4}\b"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    private let forbidden: [Range<String.Index>]
    private let senderDigits: String

    init(text: String, senderDigits: String) {
        self.senderDigits = senderDigits
        let fullRange = NSRange(text.startIndex..., in: text)
        forbidden = Self.forbiddenPatterns.flatMap { pattern in
            pattern.matches(in: text, range: fullRange).compactMap { match -> Range<String.Index>? in
                guard let range = Range(match.range, in: text) else { return nil }
                // Extend forbidden zones through digits touching either end of the
                // match, so fragments of long numbers can't slip out either side.
                return Self.extend(range, in: text)
            }
        }
    }

    private static func extend(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var lower = range.lowerBound
        while lower > text.startIndex, text[text.index(before: lower)].isNumber {
            lower = text.index(before: lower)
        }
        var upper = range.upperBound
        while upper < text.endIndex, text[upper].isNumber {
            upper = text.index(after: upper)
        }
        return lower..<upper
    }

    func allows(_ range: Range<String.Index>, code: String) -> Bool {
        if forbidden.contains(where: { $0.overlaps(range) }) { return false }
        let digits = String(code.filter(\.isNumber))
        if digits.count >= 4, senderDigits.contains(digits) { return false }
        return true
    }
}
