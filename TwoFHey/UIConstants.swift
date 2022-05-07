//
//  UIConstants.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 5/6/22.
//

import Foundation
import Cocoa

struct UIConstants {
    static let codePopupDuration: TimeInterval = 5
    
    static var codePopupPosition: CGPoint {
        if let screenHeight = NSScreen.main?.frame.height {
            return CGPoint(x: 15, y: screenHeight - 100)
        }
        
        return CGPoint(x: 15, y: 0)
    }
}

