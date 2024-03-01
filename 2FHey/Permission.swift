import Cocoa
import Combine

final class PermissionsService: ObservableObject {
    @Published var isTrusted: Bool = false
    private var checkTimer: Timer?
    
    init() {
        self.isTrusted = AXIsProcessTrustedWithOptions(nil)
    }
    
    // This static method attempts to prompt the user for Accessibility permissions
    static func acquireAccessibilityPrivileges() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func startMonitoringAccessibilityPrivileges() {
        // Immediately check and update the trust status
        self.isTrusted = AXIsProcessTrustedWithOptions(nil)
        
        // Start or restart the timer
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrustStatus()
        }
    }
    
    private func updateTrustStatus() {
        let currentStatus = AXIsProcessTrustedWithOptions(nil)
        if currentStatus != self.isTrusted {
            self.isTrusted = currentStatus
            if currentStatus {
                // Stop the timer if the app is trusted to save resources
                checkTimer?.invalidate()
                checkTimer = nil
            }
        }
    }
    
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
