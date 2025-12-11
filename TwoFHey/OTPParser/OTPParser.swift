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

protocol OTPParser {
    func parseMessage(_ message: String) -> ParsedOTP?
}
