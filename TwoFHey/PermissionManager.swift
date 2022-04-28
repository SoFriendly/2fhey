//
//  PermissionManager.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 4/25/22.
//

import Foundation

enum FullDiskAccessStatus {
    case authorized, denied, unknown
}

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
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
    
}
