//
//  AppDelegate.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 4/25/22.
//

import Cocoa
import Combine
import SwiftUI
import ServiceManagement
import HotKey

class OverlayWindow: NSWindow {
    init(line1: String?, line2: String?) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.closable, .fullSizeContentView], backing: .buffered, defer: false)
        makeKeyAndOrderFront(nil)
        isReleasedWhenClosed = false
        styleMask.insert(NSWindow.StyleMask.fullSizeContentView)
        contentView = NSHostingView(rootView: OverlayView(line1: line1, line2: line2))
        
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.close()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var messageManager: MessageManager?
    var configManager: ParserConfigManager?

    var statusBarItem: NSStatusItem!

    private var onboardingWindow: NSWindow?
    private var overlayWindow: OverlayWindow?

    var cancellable: Set<AnyCancellable> = []
    
    var mostRecentMessages: [MessageWithParsedOTP] = []
    var lastNotificationMessage: Message? = nil
    var shouldShowNotificationOverlay = false
    
    var hotKey: HotKey?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "TrayIcon")!
        icon.isTemplate = true

        // Create the status item
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.image = icon

        NSApp.activate(ignoringOtherApps: true)

        if AppStateManager.shared.globalShortcutEnabled {
            setupGlobalKeyShortcut()
        }

        initMessageManager()
        
        if !AppStateManager.shared.hasSetup {
            AppStateManager.shared.shouldLaunchOnLogin = true
            AppStateManager.shared.globalShortcutEnabled = true
            AppStateManager.shared.hasSetup = true
        }
    }
    
    func initMessageManager() {
        let configManager = ParserConfigManager()
        configManager.$config.sink(receiveValue: { [weak self] config in
            guard let config = config else { return }
            let otpParser = TwoFHeyOTPParser(withConfig: config)
            self?.messageManager?.otpParser = otpParser
        }).store(in: &cancellable)
        self.configManager = configManager
            
        let otpParser = TwoFHeyOTPParser(withConfig: configManager.config ?? configManager.DEFAULT_CONFIG)

        messageManager = MessageManager(withOTPParser: otpParser)
        
        startListeningForMesssages()
        
        configManager.downloadLatestServiceConfig()
    }
    
    func startListeningForMesssages() {
        messageManager?.$messages.sink { [weak self] messages in
            guard let weakSelf = self else { return }
            if let newestMessage = messages.last, newestMessage.0 != weakSelf.lastNotificationMessage && weakSelf.shouldShowNotificationOverlay {
                weakSelf.showOverlayForMessage(newestMessage)
            }
            
            weakSelf.mostRecentMessages = messages.suffix(3)
            weakSelf.refreshMenu()
            
            weakSelf.shouldShowNotificationOverlay = true
        }.store(in: &cancellable)
        messageManager?.startListening()
    }

    func showOverlayForMessage(_ message: MessageWithParsedOTP) {
        if let overlayWindow = overlayWindow {
            overlayWindow.close()
            self.overlayWindow = nil
        }
        
        lastNotificationMessage = message.0
        
        let window = OverlayWindow(line1: message.1.code, line2: "Copied to Clipboard")
        
        message.1.copyToClipboard()

        let windowSize = window.frame.size
        let windowPosition = CGPoint(x: 10, y: (NSScreen.main?.frame.height ?? 800) - 80)

        window.setFrame(CGRect(origin: windowPosition, size: windowSize), display: true)
        window.makeKeyAndOrderFront(nil)
        
        overlayWindow = window
    }
    
    func refreshMenu() {
        statusBarItem.menu = createMenuForMessages()
    }
    
    func createOnboardingWindow() -> NSWindow? {
        let storyboard = NSStoryboard(name: "Main", bundle: Bundle(for: ViewController.self))
        let myViewController =  storyboard.instantiateInitialController() as? NSWindowController
        let window = myViewController?.window
//        window?.titleVisibility = .hidden
//        window?.titlebarAppearsTransparent = true
//        window?.styleMask.insert(.fullSizeContentView)
//
//        window?.styleMask.remove(.closable)
//        window?.styleMask.remove(.fullScreen)
//        window?.styleMask.remove(.miniaturizable)
//        window?.styleMask.remove(.resizable)

        return window
    }
    
    func createMenuForMessages() -> NSMenu {
        let statusBarMenu = NSMenu()
        statusBarMenu.addItem(
            withTitle: AppStateManager.shared.hasFullDiscAccess() == .authorized ? "🟢 Connected to iMessage" : "⚠️ Setup 2FHey",
            action: #selector(AppDelegate.onPressSetup),
            keyEquivalent: "")

        statusBarMenu.addItem(NSMenuItem.separator())

        statusBarMenu.addItem(withTitle: "Recent", action: nil, keyEquivalent: "")
        mostRecentMessages.enumerated().forEach { (index, row) in
            let (_, parsedOtp) = row
            let menuItem = NSMenuItem(title: "\(parsedOtp.code) - \(parsedOtp.service ?? "Unknown")", action: #selector(AppDelegate.onPressCode), keyEquivalent: "")
            menuItem.tag = index
            statusBarMenu.addItem(menuItem)
        }
        
        statusBarMenu.addItem(NSMenuItem.separator())

        let resyncItem = NSMenuItem(title: "Resync", action: #selector(AppDelegate.resync), keyEquivalent: "")
        resyncItem.toolTip = "Sometimes iMessage likes to sleep on the job. If 2FHey ever misses a message, use this option to sync recent messages and copy the latest code to your clipboard"
        statusBarMenu.addItem(resyncItem)
        
        let settingsMenu = NSMenu()
        let keyboardShortCutItem = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(AppDelegate.onPressKeyboardShortcuts), keyEquivalent: "")
        keyboardShortCutItem.toolTip = "Disable keyboard shortcuts if 2FHey uses the same keyboard shortcuts as another app"
        keyboardShortCutItem.state = AppStateManager.shared.globalShortcutEnabled ? .on : .off
        settingsMenu.addItem(keyboardShortCutItem)

        let autoLaunchItem = NSMenuItem(title: "Open at Login", action: #selector(AppDelegate.onPressAutoLaunch), keyEquivalent: "")
        autoLaunchItem.state = AppStateManager.shared.shouldLaunchOnLogin ? .on : .off
        settingsMenu.addItem(autoLaunchItem)
        
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        statusBarMenu.addItem(settingsItem)
        
        statusBarMenu.addItem(
            withTitle: "Quit 2FHey",
            action: #selector(AppDelegate.quit),
            keyEquivalent: "")
        return statusBarMenu
    }
    
    func openOnboardingWindow() {
        if onboardingWindow == nil {
            onboardingWindow = createOnboardingWindow()
        }
        
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func resync() {
        shouldShowNotificationOverlay = false
        lastNotificationMessage = nil
        messageManager?.reset()
    }

    @objc func onPressAutoLaunch() {
        AppStateManager.shared.shouldLaunchOnLogin = !AppStateManager.shared.shouldLaunchOnLogin
        refreshMenu()
    }
    
    @objc func onPressKeyboardShortcuts() {
        AppStateManager.shared.globalShortcutEnabled = !AppStateManager.shared.globalShortcutEnabled
        refreshMenu()
        setupGlobalKeyShortcut()
    }
    
    func setupGlobalKeyShortcut() {
        if AppStateManager.shared.globalShortcutEnabled && hotKey == nil {
            // Setup hot key for ⌥⌘R
            hotKey = HotKey(key: .e, modifiers: [.command, .shift])
            hotKey?.keyDownHandler = { [weak self] in
                self?.resync()
            }
        } else if !AppStateManager.shared.globalShortcutEnabled {
            hotKey = nil
        }
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    @objc func onPressSetup() {
        openOnboardingWindow()
    }
    
    @objc func onPressCode(_ sender: Any) {
        guard let index = (sender as? NSMenuItem)?.tag else { return }
        let (_, parsedOtp) = mostRecentMessages[index]
        parsedOtp.copyToClipboard()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

