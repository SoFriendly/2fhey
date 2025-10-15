//
//  SimpleOTPParser.swift
//  2FHey
//
//  Simplified OTP extraction that uses keywords and heuristics instead of strict regex
//

import Foundation

class SimpleOTPParser: OTPParser {

    // Structure to decode language files
    private struct LanguageFile: Codable {
        let keywords: [String]
        let patterns: [String]
    }

    // GitHub repository URL for language files
    private static let githubBaseURL = "https://raw.githubusercontent.com/SoFriendly/2fhey/main/TwoFHey/OTPKeywords"

    // Language files to load
    private static let languageFiles = ["en.json", "fr.json", "zh.json", "es.json", "de.json", "pt.json"]

    // Keywords that indicate this is likely an OTP message (loaded from all language files)
    private var otpKeywords: Set<String>

    // Language-specific patterns for extracting codes (loaded from all language files)
    private var languagePatterns: [NSRegularExpression]

    // Common words to ignore when extracting service names
    private static let commonWords: Set<String> = [
        // English
        "your", "the", "a", "an", "is", "this", "that",
        "here", "use", "enter", "please", "do", "not",
        "share", "will", "be", "valid", "only", "sent",
        // French
        "ton", "tu", "vous", "votre", "le", "la", "un", "une", "des",
        "ce", "son", "sa", "de", "du", "lui", "ici", "utiliser", "utilisez",
        "entrer", "entrez", "svp", "merci", "s'il-vous-plaît", "s'il vous plait",
        "ne", "pas", "uniquement", "seulement", "partager", "partagez",
        "va", "sera", "être"
    ]

    // Patterns to ignore (these are not OTP messages)
    private static let ignorePatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\b(\d{3})[.\-](\d{3})[.\-](\d{4})\b"#), // Phone numbers
        try! NSRegularExpression(pattern: #"\$\d+"#), // Money amounts
        try! NSRegularExpression(pattern: #"\b\d+\s*(am|pm)\b"#, options: .caseInsensitive), // Times
        try! NSRegularExpression(pattern: #"\b\d+\s*(st|nd|rd|th)\b"#, options: .caseInsensitive), // Dates
    ]

    init() {
        // Initialize with empty collections
        self.otpKeywords = Set<String>()
        self.languagePatterns = []

        // Load from cache or bundle synchronously (for immediate availability)
        loadLanguageFiles()

        // Update from GitHub in background
        Task {
            await updateLanguageFilesFromGitHub()
        }
    }

    // Load language files from cache or bundle
    private func loadLanguageFiles() {
        var allKeywords = Set<String>()
        var allPatterns: [NSRegularExpression] = []

        // Try to load from cached files first
        let cacheURL = getCacheDirectory()
        var loadedFromCache = false

        for fileName in Self.languageFiles {
            let cacheFileURL = cacheURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: cacheFileURL.path) {
                if let (keywords, patterns) = loadLanguageFile(from: cacheFileURL) {
                    allKeywords.formUnion(keywords)
                    allPatterns.append(contentsOf: patterns)
                    loadedFromCache = true
                }
            }
        }

        // Fall back to bundled files if cache is empty
        if !loadedFromCache {
            for fileName in Self.languageFiles {
                let resourceName = fileName.replacingOccurrences(of: ".json", with: "")

                // Try subdirectory first (folder reference)
                var fileURL = Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "OTPKeywords")

                // If not found, try root level (group)
                if fileURL == nil {
                    fileURL = Bundle.main.url(forResource: resourceName, withExtension: "json")
                }

                if let fileURL = fileURL {
                    if let (keywords, patterns) = loadLanguageFile(from: fileURL) {
                        allKeywords.formUnion(keywords)
                        allPatterns.append(contentsOf: patterns)
                    }
                }
            }
        }

        self.otpKeywords = allKeywords
        self.languagePatterns = allPatterns
    }

    // Load a single language file and return keywords and patterns
    private func loadLanguageFile(from url: URL) -> (keywords: Set<String>, patterns: [NSRegularExpression])? {
        do {
            let data = try Data(contentsOf: url)
            let languageFile = try JSONDecoder().decode(LanguageFile.self, from: data)

            var patterns: [NSRegularExpression] = []
            for patternString in languageFile.patterns {
                if let regex = try? NSRegularExpression(pattern: patternString) {
                    patterns.append(regex)
                }
            }

            return (Set(languageFile.keywords), patterns)
        } catch {
            // Silently fail - avoid spamming logs
            return nil
        }
    }

    // Get cache directory for language files
    private func getCacheDirectory() -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let otpCacheDir = cacheDir.appendingPathComponent("OTPKeywords")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: otpCacheDir, withIntermediateDirectories: true)

        return otpCacheDir
    }

    // Update language files from GitHub
    private func updateLanguageFilesFromGitHub() async {
        var updatedKeywords = Set<String>()
        var updatedPatterns: [NSRegularExpression] = []
        var updatedAny = false

        let cacheDir = getCacheDirectory()

        for fileName in Self.languageFiles {
            let urlString = "\(Self.githubBaseURL)/\(fileName)"
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                // Validate the JSON before saving
                let languageFile = try JSONDecoder().decode(LanguageFile.self, from: data)

                // Save to cache
                let cacheFileURL = cacheDir.appendingPathComponent(fileName)
                try data.write(to: cacheFileURL)

                // Merge keywords and patterns
                updatedKeywords.formUnion(languageFile.keywords)
                for patternString in languageFile.patterns {
                    if let regex = try? NSRegularExpression(pattern: patternString) {
                        updatedPatterns.append(regex)
                    }
                }

                updatedAny = true
            } catch {
                // Silently fail - network errors are expected
            }
        }

        // Update the in-memory collections if we successfully downloaded any files
        if updatedAny {
            self.otpKeywords = updatedKeywords
            self.languagePatterns = updatedPatterns
        }
    }

    func parseMessage(_ message: String) -> ParsedOTP? {
        let lowercased = message.lowercased()

        // First check: Does this message contain OTP-related keywords?
        let containsOTPKeyword = otpKeywords.contains { keyword in
            lowercased.contains(keyword)
        }

        guard containsOTPKeyword else {
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
            return ParsedOTP(service: service, code: code)
        }

        return nil
    }

    // Extract potential OTP codes (4-8 digits, possibly with spaces or dashes)
    private func extractPotentialCodes(from message: String) -> [String] {
        var codes: [String] = []

        // Pattern 0: Language-specific patterns (highest priority, loaded from language files)
        // These are context-specific patterns like "验证码：123456" or "code: 123456"
        for pattern in languagePatterns {
            if let match = pattern.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: message) {
                var code = String(message[range])
                // Clean up the code (remove spaces and dashes)
                code = code.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                codes.append(code)
                // Return early - language-specific patterns are very reliable
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
               !otpKeywords.contains(trimmed) &&
               !Self.commonWords.contains(trimmed)
    }
}
