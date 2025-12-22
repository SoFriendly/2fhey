//
//  AppStateManager.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 4/25/22.
//

import Foundation
import ServiceManagement
import ApplicationServices

enum FullDiskAccessStatus {
    case authorized, denied, unknown
}

enum MessagingPlatform: String {
    case iMessage = "imessage"
    case googleMessages = "googlemessages"
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
        static let hasSetupKey = "com.sofriendly.2fhey.hasSetup"
        static let autoPasteEnabledKey = "com.sofriendly.2fhey.autoPasteEnabled"
        static let showNotificationOverlayKey = "com.sofriendly.2fhey.showNotificationOverlay"
        static let useNativeNotificationsKey = "com.sofriendly.2fhey.useNativeNotifications"
        static let markAsReadEnabledKey = "com.sofriendly.2fhey.markAsReadEnabled"
        static let debugLoggingEnabledKey = "com.sofriendly.2fhey.debugLoggingEnabled"
        static let messagingPlatformKey = "com.sofriendly.2fhey.messagingPlatform"
        static let googleMessagesAppInstalledKey = "com.sofriendly.2fhey.googleMessagesAppInstalled"
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

    var messagingPlatform: MessagingPlatform {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Constants.messagingPlatformKey),
               let platform = MessagingPlatform(rawValue: rawValue) {
                return platform
            }
            return .iMessage // Default to iMessage
        }
        set(newValue) {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.messagingPlatformKey)
        }
    }

    var googleMessagesAppInstalled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Constants.googleMessagesAppInstalledKey)
        }
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: Constants.googleMessagesAppInstalledKey)
        }
    }

    func isGoogleMessagesAppInstalled() -> Bool {
        let appPath = "/Applications/Google Messages.app"
        return FileManager.default.fileExists(atPath: appPath)
    }
}
