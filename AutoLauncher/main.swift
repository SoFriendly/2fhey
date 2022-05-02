//
//  main.swift
//  AutoLauncher
//
//  Created by Drew Pomerleau on 5/1/22.
//

import Foundation
import Cocoa

let delegate = AutoLauncherAppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
