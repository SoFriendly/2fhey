import Foundation
import AppKit

public struct ParsedOTP {
    public init(service: String?, code: String) {
        self.service = service
        self.code = code
    }
    
    public let service: String?
    public let code: String
    
    func copyToClipboard() -> String?  {
        // Check for setting here to avoid reading from clipboard unnecessarily
        let originalContents = AppStateManager.shared.restoreContentsEnabled ? NSPasteboard.general.string(forType: .string) : nil
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        return originalContents;
    }
}

extension ParsedOTP: Equatable {
    static public func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.service == rhs.service && lhs.code == rhs.code
    }
}

extension String {
    var withNonDigitsRemoved: Self? {
        guard let regExp = try? NSRegularExpression(pattern: #"[^\d.]"#, options: .caseInsensitive) else { return nil }
        let range = NSRange(location: 0, length: self.utf16.count)

        // Replace non-digits and non-decimal points with an empty string
        let cleanedString = regExp.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
        
        // Check if the cleaned string contains a decimal point
        if cleanedString.contains(".") {
            // If it does, return the cleaned string
            return cleanedString
        } else {
            // Otherwise, return nil to indicate that the original string should be used
            return nil
        }
    }
}


protocol OTPParser {
    func parseMessage(_ message: String) -> ParsedOTP?
}

public class TwoFHeyOTPParser: OTPParser {
    var config: OTPParserConfiguration
    
    public init(withConfig config: OTPParserConfiguration) {
        self.config = config
    }
    
    public func parseMessage(_ message: String) -> ParsedOTP? {
        let lowercaseMessage = message.lowercased()
        // Check if the message contains a phone number pattern
        let phoneNumberPattern = #"(?:call\s+)?(\d{3}\.\d{3}\.\d{4})"#
        let phoneNumberRegex = try! NSRegularExpression(pattern: phoneNumberPattern, options: [])
        let phoneNumberMatches = phoneNumberRegex.matches(in: lowercaseMessage, options: [], range: NSRange(location: 0, length: lowercaseMessage.utf16.count))

        // If a phone number pattern is found, return nil to ignore the message
        if !phoneNumberMatches.isEmpty {
            print("Message contains a phone number, ignoring...")
            return nil
        }
        

        print("Lowercase Message: \(lowercaseMessage)")
        
        if let googleOTP = OTPParserConstants.googleOTPRegex.firstCaptureGroupInString(message) {
            print("Google OTP found: \(googleOTP)")
            return ParsedOTP(service: "google", code: googleOTP)
        }
        
        let service = inferServiceFromMessage(message)
        print("Inferred Service: \(service ?? "Unknown")")
        
        let standardRegExps: [NSRegularExpression] = [
            OTPParserConstants.CodeMatchingRegularExpressions.standardFourToEight,
            OTPParserConstants.CodeMatchingRegularExpressions.dashedThreeAndThree,
            OTPParserConstants.CodeMatchingRegularExpressions.alphanumericWordContainingDigits,
        ]
        
        for customPattern in config.customPatterns {
            if let matchedCode = customPattern.matcherPattern.firstCaptureGroupInString(lowercaseMessage) {
                print("Custom pattern matched. Service: \(customPattern.serviceName ?? "Unknown"), Code: \(matchedCode)")
                return ParsedOTP(service: customPattern.serviceName, code: matchedCode)
            }
        }
        
        for regex in standardRegExps {
            let matches = regex.matchesInString(lowercaseMessage)
            for match in matches {
                guard let code = match.firstCaptureGroupInString(lowercaseMessage) else { continue }
                
                print("Standard regex match. Service: \(service ?? "Unknown"), Code: \(code)")
                
                if isValidCodeInMessageContext(message: lowercaseMessage, code: code) {
                    return ParsedOTP(service: service, code: code.withNonDigitsRemoved ?? code)
                } else {
                    print("Invalid context for code: \(code)")
                }
            }
        }
        
        print("No OTP detected.")
        
        let matchedParser = CUSTOM_PARSERS.first { parser in
            if let requiredName = parser.requiredServiceName, requiredName != service {
                return false
            }
            
            guard parser.canParseMessage(message), parser.parseMessage(message) != nil else { return false }
            
            return true
        }
        
        if let matchedParser = matchedParser, let parsedCode = matchedParser.parseMessage(message) {
            return parsedCode
        }
        
        return nil
    }
    
    private func isValidCodeInMessageContext(message: String, code: String) -> Bool {
        guard !code.isEmpty,
              let codeRange = message.range(of: code),
              let codePosition = message.distance(from: message.startIndex, to: codeRange.lowerBound) as Int? else {
            return false
        }
        
        let prevChar: Character
        if codePosition > 0 {
            let prevIndex = message.index(before: codeRange.lowerBound)
            prevChar = message[prevIndex]
        } else {
            prevChar = " " // Placeholder character if code is at the beginning of the string
        }
        
        let nextChar: Character
        if let afterCodeIndex = message.index(codeRange.lowerBound, offsetBy: code.count, limitedBy: message.endIndex), afterCodeIndex < message.endIndex {
            nextChar = message[afterCodeIndex]
        } else {
            nextChar = " " // Placeholder character if code is at the end of the string
        }
        
        if code.hasSuffix("am") || code.hasSuffix("pm") || code.hasSuffix("st") || code.hasSuffix("rd") || code.hasSuffix("th") || code.hasSuffix("nd") {
                print("Invalid context for code: \(code)")
                return false
            }
        
        print("Prev Char: \(prevChar), Next Char: \(nextChar)")
        
        guard !code.isEmpty, let codePosition = message.index(of: code), let afterCodePosition = message.endIndex(of: code) else { return false }
        
        print("Code positions found.")
        
        // Allow codes starting with '-'
        if prevChar != "-" {
            if codePosition > message.startIndex {
                let prev = message[message.index(before: codePosition)]
                if prev == "/" || prev == "\\" || prev == "$" {
                    print("Invalid context for code: \(code)")
                    return false
                }
            }
        }
        
        if afterCodePosition < message.endIndex {
            let next = message[afterCodePosition]
            // make sure next character is whitespace or ending grammar
            if !OTPParserConstants.endingCharacters.contains(next) {
                print("Invalid context for code: \(code)")
                return false
            }
        }
        
        print("Code is valid.")
        return true
    }

    
    private func inferServiceFromMessage(_ message: String) -> String? {
        let lowercaseMessage = message.lowercased()
        for servicePattern in config.servicePatterns {
            guard let possibleServiceName = servicePattern.firstCaptureGroupInString(lowercaseMessage),
                  !possibleServiceName.isEmpty,
                  !OTPParserConstants.authWords.contains(possibleServiceName) else {
                continue
            }
            
            return possibleServiceName
        }
        
        for knownService in config.knownServices {
            if lowercaseMessage.contains(knownService) {
                return knownService
            }
        }
        
        return nil
    }
}
