import Cocoa

final class PermissionsService {
    // This static method attempts to prompt the user for Accessibility permissions
    static func acquireAccessibilityPrivileges() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
