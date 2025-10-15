//
//  SimpleOTPParser.swift
//  2FHey
//
//  Simplified OTP extraction that uses keywords and heuristics instead of strict regex
//

import Foundation

class SimpleOTPParser: OTPParser {

    // Keywords that indicate this is likely an OTP message
    private static let otpKeywords: Set<String> = [
        "code", "verification", "verify", "otp", "pin",
        "authentication", "authenticate", "auth",
        "security", "2fa", "two-factor", "2-factor",
        "confirmation", "confirm", "activate", "activation",
        "passcode", "password", "one-time",
        // Chinese keywords
        "验证码", "驗證碼", "动态码", "校验码", "确认码"
    ]

    // Common words to ignore when extracting service names
    private static let commonWords: Set<String> = [
        "your", "the", "a", "an", "is", "this", "that",
        "here", "use", "enter", "please", "do", "not",
        "share", "will", "be", "valid", "only", "sent"
    ]

    // Patterns to ignore (these are not OTP messages)
    private static let ignorePatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\b(\d{3})[.\-](\d{3})[.\-](\d{4})\b"#), // Phone numbers
        try! NSRegularExpression(pattern: #"\$\d+"#), // Money amounts
        try! NSRegularExpression(pattern: #"\b\d+\s*(am|pm)\b"#, options: .caseInsensitive), // Times
        try! NSRegularExpression(pattern: #"\b\d+\s*(st|nd|rd|th)\b"#, options: .caseInsensitive), // Dates
    ]

    func parseMessage(_ message: String) -> ParsedOTP? {
        let lowercased = message.lowercased()

        // First check: Does this message contain OTP-related keywords?
        let containsOTPKeyword = Self.otpKeywords.contains { keyword in
            lowercased.contains(keyword)
        }

        guard containsOTPKeyword else {
            print("No OTP keywords found in message")
            return nil
        }

        // Special case: Google's G-XXXXXX format
        if let googleCode = extractGoogleCode(from: message) {
            return ParsedOTP(service: "google", code: googleCode)
        }

        // Extract all potential codes from the message
        let potentialCodes = extractPotentialCodes(from: message)

        // Filter out codes that match ignore patterns
        let validCodes = potentialCodes.filter { code in
            !shouldIgnoreCode(code, in: message)
        }

        // If we found valid codes, return the first one
        if let code = validCodes.first {
            let service = extractService(from: lowercased)
            print("✅ Found OTP code: \(code), service: \(service ?? "unknown")")
            return ParsedOTP(service: service, code: code)
        }

        print("No valid OTP codes found")
        return nil
    }

    // Extract potential OTP codes (4-8 digits, possibly with spaces or dashes)
    private func extractPotentialCodes(from message: String) -> [String] {
        var codes: [String] = []

        // Pattern 0: Chinese verification code patterns (highest priority for Chinese messages)
        // Patterns like: 验证码：123456, 验证码是 123456, 验证码为123456, etc.
        let chineseCodePatterns = [
            #"验证码[：:是为]\s*(\d{4,8})"#,  // Simplified Chinese
            #"驗證碼[：:是為]\s*(\d{4,8})"#,  // Traditional Chinese
            #"动态码[：:是为]\s*(\d{4,8})"#,
            #"校验码[：:是为]\s*(\d{4,8})"#,
            #"确认码[：:是为]\s*(\d{4,8})"#
        ]

        for patternString in chineseCodePatterns {
            if let pattern = try? NSRegularExpression(pattern: patternString),
               let match = pattern.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
               let range = Range(match.range(at: 1), in: message) {
                codes.append(String(message[range]))
                // Return early - Chinese patterns are very specific and reliable
                return codes
            }
        }

        // Pattern 1: 4-8 consecutive digits
        let digitPattern = try! NSRegularExpression(pattern: #"\b(\d{4,8})\b"#)
        let digitMatches = digitPattern.matches(in: message, range: NSRange(message.startIndex..., in: message))
        for match in digitMatches {
            if let range = Range(match.range(at: 1), in: message) {
                codes.append(String(message[range]))
            }
        }

        // Pattern 2: Digits with spaces or dashes (e.g., "123 456" or "123-456")
        let spacedPattern = try! NSRegularExpression(pattern: #"\b(\d{3}[\s\-]\d{3,6})\b"#)
        let spacedMatches = spacedPattern.matches(in: message, range: NSRange(message.startIndex..., in: message))
        for match in spacedMatches {
            if let range = Range(match.range(at: 1), in: message) {
                let code = String(message[range]).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                codes.append(code)
            }
        }

        // Pattern 3: Alphanumeric codes (letters + numbers, 4-8 chars, must contain at least one digit)
        let alphanumericPattern = try! NSRegularExpression(pattern: #"\b([A-Za-z]*\d[A-Za-z0-9]{3,7})\b"#)
        let alphanumericMatches = alphanumericPattern.matches(in: message, range: NSRange(message.startIndex..., in: message))
        for match in alphanumericMatches {
            if let range = Range(match.range(at: 1), in: message) {
                codes.append(String(message[range]))
            }
        }

        // Pattern 4: Chinese brackets 【code】 (common in Asian markets)
        let chineseBracketPattern = try! NSRegularExpression(pattern: #"【([\u4e00-\u9fa5\d\w]+)】"#)
        let chineseBracketMatches = chineseBracketPattern.matches(in: message, range: NSRange(message.startIndex..., in: message))
        for match in chineseBracketMatches {
            if let range = Range(match.range(at: 1), in: message) {
                let code = String(message[range])
                // Extract just the digits if mixed with Chinese characters
                let digitsOnly = code.filter { $0.isNumber }
                if digitsOnly.count >= 4 {
                    codes.append(digitsOnly)
                }
            }
        }

        return codes
    }

    // Extract Google's special G-XXXXX format (5 characters, not 6)
    private func extractGoogleCode(from message: String) -> String? {
        let pattern = try! NSRegularExpression(pattern: #"\b(G-[A-Z0-9]{5})\b"#)
        let matches = pattern.matches(in: message, range: NSRange(message.startIndex..., in: message))

        if let match = matches.first, let range = Range(match.range(at: 1), in: message) {
            return String(message[range])
        }
        return nil
    }

    // Check if we should ignore this code (phone number, money, time, etc.)
    private func shouldIgnoreCode(_ code: String, in message: String) -> Bool {
        // Check ignore patterns
        for pattern in Self.ignorePatterns {
            let matches = pattern.matches(in: message, range: NSRange(message.startIndex..., in: message))
            for match in matches {
                if let range = Range(match.range, in: message) {
                    let matchedText = String(message[range])
                    if matchedText.contains(code) {
                        print("Ignoring code '\(code)' - matches ignore pattern")
                        return true
                    }
                }
            }
        }

        // Ignore if code ends with common time/date suffixes
        let lowercased = code.lowercased()
        if lowercased.hasSuffix("am") || lowercased.hasSuffix("pm") ||
           lowercased.hasSuffix("st") || lowercased.hasSuffix("nd") ||
           lowercased.hasSuffix("rd") || lowercased.hasSuffix("th") {
            print("Ignoring code '\(code)' - time/date suffix")
            return true
        }

        return false
    }

    // Try to extract service name from the message (best effort)
    private func extractService(from lowercased: String) -> String? {
        // Method 1: Check for known services FIRST (most reliable)
        for service in OTPParserConstants.knownServices {
            if lowercased.contains(service) {
                return service
            }
        }

        // Method 2: Check at start of message for brackets or "Welcome to"
        // e.g., "[Amazon]", "(Google)", "Welcome to Apple"
        let startPatterns = [
            #"^\[([^\]\d]{3,})\]"#,  // [ServiceName]
            #"^\(([^)\d]{3,})\)"#,    // (ServiceName)
            #"^welcome\s+to\s+([\w\d ]{4,}?)[\s,;.]"#,  // Welcome to ServiceName
        ]

        for patternString in startPatterns {
            if let pattern = try? NSRegularExpression(pattern: patternString),
               let match = pattern.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let range = Range(match.range(at: 1), in: lowercased) {
                let service = String(lowercased[range]).trimmingCharacters(in: .whitespaces)
                if isValidServiceName(service) {
                    return service
                }
            }
        }

        // Method 3: Look for "from [service]" or "verification/code for/from [service]"
        // Note: We removed the "[service] verification/code" pattern as it's too prone to false positives
        let simplePatterns = [
            #"from\s+([a-z0-9 ]+?)(?:\s|$)"#,
            #"(?:verification|code|otp|pin)\s+(?:for|from)\s+([a-z0-9 ]+?)(?:\s|$)"#,
        ]

        for patternString in simplePatterns {
            if let pattern = try? NSRegularExpression(pattern: patternString),
               let match = pattern.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let range = Range(match.range(at: 1), in: lowercased) {
                let service = String(lowercased[range]).trimmingCharacters(in: .whitespaces)
                if isValidServiceName(service) {
                    return service
                }
            }
        }

        return nil
    }

    // Validate that a string is a valid service name (not a common word or keyword)
    private func isValidServiceName(_ service: String) -> Bool {
        let trimmed = service.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.count > 2 &&
               !Self.otpKeywords.contains(trimmed) &&
               !Self.commonWords.contains(trimmed)
    }
}
