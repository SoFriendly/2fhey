//
//  Message.swift
//  ohtipi
//
//  Created by Drew Pomerleau on 4/24/22.
//

import Foundation
import SQLite

struct Message: Equatable {
    let guid: String
    let text: String
    let handle: String
    let group: String?
    let fromMe: Bool
}
