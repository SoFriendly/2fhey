//
//  AppStateManager.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 4/25/22.
//

import Foundation
import ServiceManagement
enum FullDiskAccessStatus {
    case authorized, denied, unknown
}

class AppStateManager {
    static let shared = AppStateManager()
    
    private init() {}
    
    private struct Constants {
        // Helper Application Bundle Identifier
        static let autoLauncherBundleID = "com.sofriendly.2fhey.AutoLauncher"
        
        static let autoLauncherPrefKey = "com.sofriendly.2fhey.shouldAutoLaunch"
        static let globalShortcutEnabledKey = "com.sofriendly.2fhey.globalShortcutEnabled"
        static let restoreContentsDelayTimeKey = "com.sofriendly.2fhey.restoreContentsDelayTime"
        static let restoreContentsEnabledKey = "com.sofriendly.2fhey.restoreContentsEnabledKey"
        static let hasSetupKey = "com.sofriendly.2fhey.hasSetup"
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
    
    // Set to 0 to disable
    var restoreContentsDelayTime: Int {
        get {
            return UserDefaults.standard.integer(forKey: Constants.restoreContentsDelayTimeKey)
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
