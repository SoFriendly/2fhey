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

enum FullDiskAccessStatus {
    case authorized, denied, unknown
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
}
