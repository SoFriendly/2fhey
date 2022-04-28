import Foundation
import Cocoa

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

extension NSTextCheckingResult {
    func firstCaptureGroupInString(_ string: String) -> String? {
        guard numberOfRanges > 0 else { return nil }
        let matchRange = range(at: 1)
        guard let substringRange = Range(matchRange, in: string) else { return nil }
        
        return String(string[substringRange])
    }
}

extension NSRegularExpression {
    func firstMatchInString(_ string: String) -> NSTextCheckingResult? {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range)
    }
    
    func matchesInString(_ string: String) -> [NSTextCheckingResult] {
        let range = NSRange(location: 0, length: string.utf16.count)
        return matches(in: string, range: range)
    }
    
    func firstCaptureGroupInString(_ string: String) -> String? {
        guard let match = firstMatchInString(string) else { return nil }
        
        return match.firstCaptureGroupInString(string)
    }
}

public struct ParsedOTP {
    let service: String?
    let code: String
    
    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
    }
}

public class OTPParserUtils {
    private static func isValidCodeInMessageContext(message: String, code: String) -> Bool {
        guard !code.isEmpty, let codePosition = message.index(of: code), let afterCodePosition = message.endIndex(of: code) else { return false }
        
        
        if codePosition > message.startIndex {
            let prev = message[message.index(before: codePosition)]
            if prev == "-" || prev == "/" || prev == "\\" || prev == "$" {
                return false
            }
        }
        
        if afterCodePosition < message.endIndex {
            let next = message[message.index(after: afterCodePosition)]
            // make sure next character is whitespace or ending grammar
            if !OTPParserConstants.endingCharacters.contains(next) {
                return false
            }
        }
        
        return true
    }
    
    public static func parseMessage(_ message: String) -> ParsedOTP? {
        let lowercaseMessage = message.lowercased()
        
        if let googleOTP = OTPParserConstants.googleOTPRegex.firstCaptureGroupInString(message) {
            return ParsedOTP(service: "google", code: googleOTP)
        }
        
        let service = inferServiceFromMessage(message)
        
        if let possibleCode = OTPParserConstants.CodeMatchingRegularExpressions.standardFourToEight.firstCaptureGroupInString(lowercaseMessage) {
            return ParsedOTP(service: service, code: possibleCode)
        }
        
        let standardRegExps: [NSRegularExpression] = [
            OTPParserConstants.CodeMatchingRegularExpressions.standardFourToEight,
            OTPParserConstants.CodeMatchingRegularExpressions.dashedThreeAndThree,
        ]

        for regex in standardRegExps {
            let matches = regex.matchesInString(lowercaseMessage)
            for match in matches {
                guard let code = match.firstCaptureGroupInString(lowercaseMessage) else { continue }

                if isValidCodeInMessageContext(message: lowercaseMessage, code: code) {
                    return ParsedOTP(service: service, code: code)
                }
            }
        }
        
        return nil
    }
    
    private static func inferServiceFromMessage(_ message: String) -> String? {
        let lowercaseMessage = message.lowercased()
        for servicePattern in OTPParserConstants.servicePatterns {
            guard let possibleServiceName = servicePattern.firstCaptureGroupInString(lowercaseMessage),
                  !possibleServiceName.isEmpty,
                  !OTPParserConstants.authWords.contains(possibleServiceName) else {
                continue
            }
            
            return possibleServiceName
        }
        
        for knownService in OTPParserConstants.knownServices {
            if lowercaseMessage.contains(knownService) {
                return knownService
            }
        }
        
        return nil
    }
}
