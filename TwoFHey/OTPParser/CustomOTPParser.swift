import Foundation

struct CustomOTPParser {
    let notes: String
    let example: String
    let requiredServiceName: String?
    let canParseMessage: (_ message: String) -> Bool
    let parseMessage: (_ message: String) -> ParsedOTP?
}
