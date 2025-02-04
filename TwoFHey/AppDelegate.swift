import Cocoa
import Combine
import SwiftUI
import ServiceManagement
import HotKey
import ApplicationServices

class OverlayWindow: NSWindow {
    init(line1: String?, line2: String?, position: NotificationPosition = .defaultValue) {
        let position = AppStateManager.shared.notificationPosition
        let windowSize = UIConstants.codePopupWindowSize
        let margin = UIConstants.codePopupMargin
        var windowRect: NSRect
        let mainScreenRect = NSScreen.main?.visibleFrame ?? NSRect()
        
        switch position {
        case .leftEdgeTop:
            windowRect = NSRect(x: margin, y: mainScreenRect.maxY - margin - windowSize.height, width: windowSize.width, height: windowSize.height)
        case .leftEdgeBottom:
            windowRect = NSRect(x: margin, y: margin, width: windowSize.width, height: windowSize.height)
        case .rightEdgeTop:
            windowRect = NSRect(x: mainScreenRect.maxX - margin - windowSize.width, y: mainScreenRect.maxY - margin - windowSize.height, width: windowSize.width, height: windowSize.height)
        case .rightEdgeBottom:
            windowRect = NSRect(x: mainScreenRect.maxX - margin - windowSize.width, y: margin, width: windowSize.width, height: windowSize.height)
        }
        
        super.init(contentRect: windowRect, styleMask: [.closable, .fullSizeContentView, .borderless], backing: .buffered, defer: false)

        makeKeyAndOrderFront(nil)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        contentView = NSHostingView(rootView: OverlayView(line1: line1, line2: line2))
        styleMask.insert(NSWindow.StyleMask.borderless)
    
        Timer.scheduledTimer(withTimeInterval: UIConstants.codePopupDuration, repeats: false) { [weak self] _ in
            self?.close()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var messageManager: MessageManager?
    var configManager: ParserConfigManager?
    private var permissionsService = PermissionsService()

    var statusBarItem: NSStatusItem!

    private var onboardingWindow: NSWindow?
    private var overlayWindow: OverlayWindow?

    var cancellable: Set<AnyCancellable> = []
    
    var mostRecentMessages: [MessageWithParsedOTP] = []
    var lastNotificationMessage: Message? = nil
    var shouldShowNotificationOverlay = false
    var originalClipboardContents: String? = nil
    
    var hotKey: HotKey?
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let icon = NSImage(named: "TrayIcon")!
        icon.isTemplate = true
        print("App Launched")

        // Create the status item
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.image = icon

        NSApp.activate(ignoringOtherApps: true)

        if AppStateManager.shared.globalShortcutEnabled {
            setupGlobalKeyShortcut()
        }

        initMessageManager()
        setupKeyboardListener()
        
        if !AppStateManager.shared.hasSetup {
            AppStateManager.shared.shouldLaunchOnLogin = true
            AppStateManager.shared.globalShortcutEnabled = true
            AppStateManager.shared.hasSetup = true
            openOnboardingWindow()
        } else if AppStateManager.shared.hasFullDiscAccess() != .authorized || !AppStateManager.shared.hasAccessibilityPermission() {
            openOnboardingWindow()
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
            
        let otpParser = TwoFHeyOTPParser(withConfig: configManager.config ?? ParserConfigManager.DEFAULT_CONFIG)

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
        
        self.originalClipboardContents = message.1.copyToClipboard()
        
        if AppStateManager.shared.autoPasteEnabled && AppStateManager.shared.hasAccessibilityPermission() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let source = CGEventSource(stateID: .combinedSessionState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                keyDown?.flags = .maskCommand
                keyUp?.flags = .maskCommand
                keyDown?.post(tap: .cgAnnotatedSessionEventTap)
                keyUp?.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
        
        restoreClipboardContents(withDelay: AppStateManager.shared.restoreContentsDelayTime)

        window.makeKeyAndOrderFront(nil)
        window.level = NSWindow.Level.statusBar
        
        overlayWindow = window
    }

    func refreshMenu() {
        statusBarItem.menu = createMenuForMessages()
    }
    
    func createOnboardingWindow() -> NSWindow? {
        let storyboard = NSStoryboard(name: "Main", bundle: Bundle(for: ViewControllerNative.self))
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
        
        let notificationPositionMenu = NSMenu()
        let positions = NotificationPosition.all
        positions.forEach { position in
            let item = NSMenuItem(title: position.name, action: #selector(AppDelegate.onPressNotificationPosition), keyEquivalent: "")
            item.representedObject = position
            item.state = AppStateManager.shared.notificationPosition == position ? .on : .off
            notificationPositionMenu.addItem(item)
        }
        
        let notificationPositionItem = NSMenuItem(title: "Notification Position", action: nil, keyEquivalent: "")
        notificationPositionItem.toolTip = "Select where notifications will appear on the screen"
        notificationPositionItem.state = .off
        notificationPositionItem.submenu = notificationPositionMenu
        settingsMenu.addItem(notificationPositionItem)
        
        let keyboardShortCutItem = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(AppDelegate.onPressKeyboardShortcuts), keyEquivalent: "")
        keyboardShortCutItem.toolTip = "Disable keyboard shortcuts if 2FHey uses the same keyboard shortcuts as another app"
        keyboardShortCutItem.state = AppStateManager.shared.globalShortcutEnabled ? .on : .off
        settingsMenu.addItem(keyboardShortCutItem)

        let autoPasteItem = NSMenuItem(title: "Auto-Paste Codes", action: #selector(AppDelegate.onPressAutoPaste), keyEquivalent: "")
        autoPasteItem.toolTip = "Automatically paste codes into focused text field (requires accessibility permissions)"
        autoPasteItem.state = AppStateManager.shared.autoPasteEnabled ? .on : .off
        settingsMenu.addItem(autoPasteItem)

        let restoreContentsMenu = NSMenu()
        let delayTimes = [0, 5, 10, 15, 20]
        delayTimes.forEach { delayTime in
            let item = NSMenuItem(title: "\(String(describing: delayTime)) sec", action: #selector(AppDelegate.onPressRestoreClipboardContents), keyEquivalent: "")
            if (delayTime == 0) {
                item.title = "Disabled"
            }
            item.representedObject = delayTime
            item.state = AppStateManager.shared.restoreContentsDelayTime == delayTime ? .on : .off
            restoreContentsMenu.addItem(item)
        }
        
        let restoreContentsItem = NSMenuItem(title: "Restore Clipboard Contents", action: #selector(AppDelegate.onPressRestoreClipboardContents), keyEquivalent: "")
        restoreContentsItem.toolTip = "Disable restore clipboard contents if you don't want 2FHey to restore your clipboard to what it was before receiving a code"
        restoreContentsItem.state = AppStateManager.shared.restoreContentsEnabled ? .on : .off
        restoreContentsItem.submenu = restoreContentsMenu
        settingsMenu.addItem(restoreContentsItem)

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
    
    func setupKeyboardListener() {
        if (AppStateManager.shared.restoreContentsEnabled) {
            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .systemDefined, .appKitDefined]) { (event) in
                // If command + V pressed, race restoring the clipboard contents between this listener and the default delay interval
                if (event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command && event.keyCode == 9) {
                    self.restoreClipboardContents(withDelay: 5)
                }
            }
        }
    }
    
    func openOnboardingWindow() {
        if onboardingWindow == nil {
            onboardingWindow = createOnboardingWindow()
        }
        
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func resync() {
        shouldShowNotificationOverlay = false
        lastNotificationMessage = nil
        originalClipboardContents = nil
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
    
    @objc func onPressRestoreClipboardContents(sender: NSMenuItem) {
        let newDelayTime = sender.representedObject == nil ? 0 : sender.representedObject as! Int;
        AppStateManager.shared.restoreContentsDelayTime = newDelayTime
        refreshMenu()
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
    
    @objc func onPressNotificationPosition(sender: NSMenuItem) {
        if let newNotificationPosition = sender.representedObject as? NotificationPosition {
            AppStateManager.shared.notificationPosition = newNotificationPosition
            refreshMenu()
        }
    }
    
    @objc func onPressAutoPaste() {
        AppStateManager.shared.autoPasteEnabled = !AppStateManager.shared.autoPasteEnabled
        refreshMenu()
    }
    
    private func getAccessibilityPermission(prompt: Bool) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: prompt]
        let status = AXIsProcessTrustedWithOptions(options)
        return status
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
        self.originalClipboardContents = parsedOtp.copyToClipboard()
        restoreClipboardContents(withDelay: AppStateManager.shared.restoreContentsDelayTime)
    }
    
    // Restores clipboard contents after a provided delay in seconds
    // Meant to be called any number of times, each call will race between each other and only
    // restore contents when contents are set
    func restoreClipboardContents(withDelay delaySeconds: Int) {
        let delayTimeInterval = DispatchTimeInterval.seconds(delaySeconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTimeInterval) {
            if (self.originalClipboardContents != nil) {
                let window = OverlayWindow(line1: "Clipboard Restored", line2: nil)
                self.overlayWindow = window
                NSPasteboard.general.setString(self.originalClipboardContents!, forType: .string)
                self.originalClipboardContents = nil
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
}

