//
//  AppStateManager.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 4/25/22.
//

import Foundation
import ServiceManagement
import SwiftUI
import ApplicationServices
import AppleScriptObjC

enum FullDiskAccessStatus {
    case authorized, denied, unknown
}

enum MailAutomationStatus {
    case granted
    case denied
    case requiresConsent
    case notRunning
    case unknown(Int)
}

enum NotificationPosition: Int {
    case leftEdgeTop, leftEdgeBottom, rightEdgeTop, rightEdgeBottom
    
    static let defaultValue: NotificationPosition = .leftEdgeTop
    
    static let all: [NotificationPosition] = [.leftEdgeTop, .leftEdgeBottom, .rightEdgeTop, .rightEdgeBottom]
    
    var name: String {
        switch self {
        case .leftEdgeTop:
            return "Left Edge, Top"
        case .leftEdgeBottom:
            return "Left Edge, Bottom"
        case .rightEdgeTop:
            return "Right Edge, Top"
        case .rightEdgeBottom:
            return "Right Edge, Bottom"
        }
    }
}

class AppStateManager {
    static let shared = AppStateManager()
    
    private init() {}
    
    private struct Constants {
        // Helper Application Bundle Identifier
        static let autoLauncherBundleID = "com.sofriendly.2fhey.AutoLauncher"
        
        static let autoLauncherPrefKey = "com.sofriendly.2fhey.shouldAutoLaunch"
        static let globalShortcutEnabledKey = "com.sofriendly.2fhey.globalShortcutEnabled"
        static let notificationPositionKey = "com.sofriendly.2fhey.notificationPosition"
        static let restoreContentsDelayTimeKey = "com.sofriendly.2fhey.restoreContentsDelayTime"
        static let restoreContentsEnabledKey = "com.sofriendly.2fhey.restoreContentsEnabledKey"
        static let hasSetupKey = "com.sofriendly.2fhey.hasSetup"
        static let autoPasteEnabledKey = "com.sofriendly.2fhey.autoPasteEnabled"
        static let showNotificationOverlayKey = "com.sofriendly.2fhey.showNotificationOverlay"
        static let useNativeNotificationsKey = "com.sofriendly.2fhey.useNativeNotifications"
        static let markAsReadEnabledKey = "com.sofriendly.2fhey.markAsReadEnabled"
        static let debugLoggingEnabledKey = "com.sofriendly.2fhey.debugLoggingEnabled"
    }
    
    func hasFullDiscAccess() -> FullDiskAccessStatus {
        var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        homeDirectory.appendPathComponent("/Library/Messages/chat.db")

        let fileExists = FileManager.default.fileExists(atPath: homeDirectory.path)
        let data = try? Data(contentsOf: homeDirectory)
        if data == nil && fileExists {
            return .denied
        } else if fileExists {
            return .authorized
        }
        
        return .unknown
    }
    
    func hasAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        let status = AXIsProcessTrustedWithOptions(options)

        return status
    }

    private func checkMailAutomationStatus() -> MailAutomationStatus {
        return determineMailPermission(ask: false)
    }

    func hasMailAutomationPermission() -> Bool {
        let status = checkMailAutomationStatus()

        switch status {
        case .granted:
            DebugLogger.shared.log("Mail automation permission: GRANTED", category: "MAIL_PERMISSION")
            return true
        case .denied:
            DebugLogger.shared.log("Mail automation permission: DENIED", category: "MAIL_PERMISSION")
            return false
        case .requiresConsent:
            DebugLogger.shared.log("Mail automation permission: REQUIRES CONSENT", category: "MAIL_PERMISSION")
            return false
        case .notRunning:
            DebugLogger.shared.log("Mail automation permission: Mail.app NOT RUNNING", category: "MAIL_PERMISSION")
            return false
        case .unknown(let code):
            DebugLogger.shared.log("Mail automation permission: UNKNOWN", category: "MAIL_PERMISSION", data: ["statusCode": code])
            return false
        }
    }

    private func determineMailPermission(ask: Bool) -> MailAutomationStatus {
        let errAEEventWouldRequireUserConsent = OSStatus(-1744)

        guard var addressDesc = NSAppleEventDescriptor(bundleIdentifier: "com.apple.mail").aeDesc?.pointee else {
            DebugLogger.shared.log("Failed to create Apple Event descriptor for Mail.app", category: "MAIL_PERMISSION")
            return .unknown(-999)
        }

        let appleScriptPermission = AEDeterminePermissionToAutomateTarget(&addressDesc, typeWildCard, typeWildCard, ask)
        AEDisposeDesc(&addressDesc)

        switch appleScriptPermission {
        case noErr:
            return .granted
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case errAEEventWouldRequireUserConsent:
            return .requiresConsent
        case OSStatus(procNotFound):
            return .notRunning
        default:
            return .unknown(Int(appleScriptPermission))
        }
    }

    /// Requests Mail Automation permission and triggers the system permission dialog
    /// This is the explicit action that shows the permission prompt to the user
    func requestMailAutomationPermission() {
        DebugLogger.shared.log("Requesting Mail automation permission...", category: "MAIL_PERMISSION")

        let mailApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first
        if mailApp == nil {
            DebugLogger.shared.log("Mail.app not running, launching it...", category: "MAIL_PERMISSION")

            // Use modern API to launch Mail.app
            if let mailURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail") {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false

                NSWorkspace.shared.openApplication(at: mailURL, configuration: configuration) { app, error in
                    if let error = error {
                        DebugLogger.shared.log("Failed to launch Mail.app", category: "MAIL_PERMISSION", data: ["error": error.localizedDescription])
                    }
                }

                Thread.sleep(forTimeInterval: 1.5)
            }
        }

        let status = determineMailPermission(ask: true)

        switch status {
        case .granted:
            DebugLogger.shared.log("Mail automation permission GRANTED by user", category: "MAIL_PERMISSION")
        case .denied:
            DebugLogger.shared.log("Mail automation permission DENIED by user", category: "MAIL_PERMISSION")
            // Open System Settings so user can manually grant permission
            DispatchQueue.main.async {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        case .requiresConsent:
            DebugLogger.shared.log("Mail automation permission requires user consent (dialog should have appeared)", category: "MAIL_PERMISSION")
        case .notRunning:
            DebugLogger.shared.log("Mail.app not running after launch attempt", category: "MAIL_PERMISSION")
        case .unknown(let code):
            DebugLogger.shared.log("Unknown permission status", category: "MAIL_PERMISSION", data: ["statusCode": code])
        }
    }


    var hasSetup: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Constants.hasSetupKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.hasSetupKey)
        }
    }
    
    var shouldLaunchOnLogin: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Constants.autoLauncherPrefKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.autoLauncherPrefKey)
            SMLoginItemSetEnabled(Constants.autoLauncherBundleID as CFString, newValue)
        }
    }
    
    var globalShortcutEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Constants.globalShortcutEnabledKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.globalShortcutEnabledKey)
        }
    }
    
    var autoPasteEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Constants.autoPasteEnabledKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.autoPasteEnabledKey)
        }
    }

    var showNotificationOverlay: Bool {
        get {
            // Default to true (show overlay) if not set
            if UserDefaults.standard.object(forKey: Constants.showNotificationOverlayKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Constants.showNotificationOverlayKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.showNotificationOverlayKey)
        }
    }

    var useNativeNotifications: Bool {
        get {
            // Default to false (use custom overlay)
            return UserDefaults.standard.bool(forKey: Constants.useNativeNotificationsKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.useNativeNotificationsKey)
        }
    }

    var markAsReadEnabled: Bool {
        get {
            // Default to false (don't mark as read)
            return UserDefaults.standard.bool(forKey: Constants.markAsReadEnabledKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.markAsReadEnabledKey)
        }
    }

    func hasRequiredPermissions() -> Bool {
        let fullDiskAccess = hasFullDiscAccess()
        let accessibilityPermission = hasAccessibilityPermission()
        
        // Check if both permissions are authorized
        return fullDiskAccess == .authorized && accessibilityPermission
    }

    
    var notificationPosition: NotificationPosition {
        get {
            if let storedRawValue = UserDefaults.standard.value(forKey: Constants.notificationPositionKey) as? Int {
                return NotificationPosition(rawValue: storedRawValue) ?? NotificationPosition.defaultValue
            } else {
                return NotificationPosition.defaultValue
            }
        }
        set(newValue) {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.notificationPositionKey)
        }
    }
    
    // Set to 0 to disable
    var restoreContentsDelayTime: Int {
        get {
            let value = UserDefaults.standard.value(forKey: Constants.restoreContentsDelayTimeKey)
            if (value == nil) {
                // Default value
                return 5;
            } else {
                return value as! Int
            }
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.restoreContentsDelayTimeKey)
        }
    }
    
    var restoreContentsEnabled: Bool {
        get {
            return self.restoreContentsDelayTime > 0
        }
    }

    var debugLoggingEnabled: Bool {
        get {
            // Default to false (don't log)
            return UserDefaults.standard.bool(forKey: Constants.debugLoggingEnabledKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.debugLoggingEnabledKey)
            if newValue {
                DebugLogger.shared.log("Debug logging enabled", category: "SYSTEM")
            }
        }
    }
}
