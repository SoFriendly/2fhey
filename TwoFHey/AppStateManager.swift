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
        static let autoLauncherBundleID = "col.yac.AutoLauncher"
        
        static let autoLauncherPrefKey = "col.yac.TwoFHey.shouldAutoLaunch"
        static let globalShortcutEnabledKey = "col.yac.TwoFHey.globalShortcutEnabled"
    }
    
    func hasFullDiscAccess() -> FullDiskAccessStatus {
        var homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        
        if #available(macOS 10.15, *) {
            homeDirectory.appendPathComponent("Library/Safari/CloudTabs.db")
        } else {
            homeDirectory.appendPathComponent("Library/Safari/Bookmarks.plist")
        }

        let fileExists = FileManager.default.fileExists(atPath: homeDirectory.absoluteString)
        let data = try? Data(contentsOf: homeDirectory)
        if data == nil && fileExists {
            return .denied
        } else if fileExists {
            return .authorized
        }
        
        return .unknown
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
    
}
