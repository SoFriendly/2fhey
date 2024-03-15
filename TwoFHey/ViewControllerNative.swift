

import Foundation

import Cocoa
import WebKit

class ViewControllerNative: NSViewController {
    

    @IBOutlet weak var imgLogo: NSImageView!
    @IBAction func btnGetStartedAction(_ sender: Any) {
        containerView2.isHidden = false
        // NSView fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            // 1 second animation
            context.duration = 1

            // The view will animate to alphaValue 0
            containerView1.animator().alphaValue = 0
            containerView2.animator().alphaValue = 1
        }) {
            // Handle completion
        }
        // NSView move animation
        NSAnimationContext.runAnimationGroup({ context in
            // 2 second animation
            context.duration = 1
                    
            // Animate the NSView downward 20 points
            var origin = imgLogo.frame.origin
            origin.y += 40

            // The view will animate to the new origin
            imgLogo.animator().frame.origin = origin
        }) {
            // Handle completion
        }
        
    }
    @IBOutlet weak var btnGetStarted: NSButton!
    @IBOutlet weak var viewBtnGetStarted: NSView!
    @IBOutlet weak var containerView1: NSView!
   
    
    @IBOutlet weak var viewStatus1: NSView!
    @IBOutlet weak var containerView2: NSView!
    
    @IBOutlet weak var viewStatus2: NSView!
    
    @IBOutlet weak var btnAccessibility: NSButton!
    @IBAction func btnAccessibiliyAction(_ sender: Any) {
        PermissionsService.acquireAccessibilityPrivileges()
    }
    
    @IBOutlet weak var btnFullDisk: NSButton!
    @IBAction func btnFullDiskAction(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
    
    @IBOutlet weak var containerView: NSView!
    
    @IBOutlet var mainView: NSView!
    @IBOutlet weak var btnRestart: NSButton!
    @IBAction func btnRestartAction(_ sender: Any) {
        // Check if the button title is "Done", which means both permissions are granted
        if btnRestart.title == "Done" {
            // Close the window
            DispatchQueue.main.async { [weak self] in
                self?.view.window?.close()
            }
        } else {
            // Original restart logic (if applicable)
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [path]
            task.launch()
            exit(0)
        }
    }

    private var permissionsService = PermissionsService()
    var timer = Timer()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        btnGetStarted.wantsLayer = true
        btnRestart.wantsLayer = true
        imgLogo.wantsLayer = true
        imgLogo.alphaValue = 0
        containerView1.wantsLayer = true
        viewStatus1.wantsLayer = true
        viewStatus2.wantsLayer = true
        containerView1.alphaValue = 0
        containerView2.alphaValue = 0
        self.animateLogoAndContainer()
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        
    }
    
    func animateLogoAndContainer() {
        
        // Set the scale of the view to 2
        let doubleSize = NSSize(width: 1.5, height: 1.5)
        imgLogo.scaleUnitSquare(to: doubleSize)
                
        // Set the frame to the scaled frame
        imgLogo.frame = CGRect(
            x: imgLogo.frame.origin.x,
            y: imgLogo.frame.origin.y,
            width:   imgLogo.frame.width,
            height:  imgLogo.frame.height
        )

        // Create the scale animation
        let animation = CABasicAnimation()
        let duration = 1

        animation.duration = CFTimeInterval(duration)
        animation.fromValue = CATransform3DMakeScale(1.0, 1.0, 1.0)
        animation.toValue = CATransform3DMakeScale(1.5, 1.5, 1.5)
        imgLogo.animator().alphaValue = 1

        // Trigger the scale animation
        imgLogo.layer?.add(animation, forKey: "transform")
        // NSView fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            // 1 second animation
            context.duration = 2

            // The view will animate to alphaValue 0
            containerView1.animator().alphaValue = 1
            imgLogo.animator().alphaValue = 1
        }) {
            // Handle completion
        }
        
    }
    override func viewWillAppear() {
        mainView.layer?.backgroundColor = .white
//        viewBtnGetStarted.layer?.backgroundColor = NSColor(red: 91/255, green: 195/255, blue: 71/255, alpha: 1).cgColor
        btnGetStarted.layer?.backgroundColor = NSColor(red: 91/255, green: 195/255, blue: 71/255, alpha: 1).cgColor
        btnGetStarted.layer?.cornerRadius = 8
        btnRestart.layer?.backgroundColor = NSColor(red: 91/255, green: 195/255, blue: 71/255, alpha: 1).cgColor
        btnRestart.layer?.cornerRadius = 8
        viewStatus1.layer?.backgroundColor = NSColor(red: 238/255, green: 203/255, blue: 201/255, alpha: 1).cgColor
        viewStatus1.layer?.cornerRadius = 4
        viewStatus2.layer?.backgroundColor = NSColor(red: 238/255, green: 203/255, blue: 201/255, alpha: 1).cgColor
        viewStatus2.layer?.cornerRadius = 4
        
        //box.layer?.setNeedsDisplay()
    }
    
    @objc func timerAction() {
        if AppStateManager.shared.hasRequiredPermissions() {
            // Update UI to indicate permissions are granted
            viewStatus2.layer?.backgroundColor = NSColor(red: 90/255, green: 180/255, blue: 85/255, alpha: 1).cgColor
            viewStatus1.layer?.backgroundColor = NSColor(red: 90/255, green: 180/255, blue: 85/255, alpha: 1).cgColor

            // Disable buttons as permissions are no longer needed
            btnAccessibility.isEnabled = false
            btnFullDisk.isEnabled = false

            // Stop the timer as it's no longer needed
            timer.invalidate()

            // Change the restart button text to "Done" and show it
            DispatchQueue.main.async { [weak self] in
                self?.btnRestart.title = "Done"
                self?.btnRestart.isHidden = false
            }

            return
        }

        // If not all permissions are granted, update the UI accordingly
        let acc = AppStateManager.shared.hasAccessibilityPermission()
        btnAccessibility.isEnabled = !acc
        viewStatus1.layer?.backgroundColor = acc ? NSColor(red: 90/255, green: 180/255, blue: 85/255, alpha: 1).cgColor : NSColor(red: 238/255, green: 203/255, blue: 201/255, alpha: 1).cgColor

        let diskAccess = AppStateManager.shared.hasFullDiscAccess()
        btnFullDisk.isEnabled = diskAccess != .authorized
        viewStatus2.layer?.backgroundColor = diskAccess == .authorized ? NSColor(red: 90/255, green: 180/255, blue: 85/255, alpha: 1).cgColor : NSColor(red: 238/255, green: 203/255, blue: 201/255, alpha: 1).cgColor
    }


    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    


}


