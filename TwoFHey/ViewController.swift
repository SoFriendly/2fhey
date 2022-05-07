//
//  ViewController.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 4/25/22.
//

import Cocoa
import WebKit

class ViewController: NSViewController {
    @IBOutlet var webkitView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        webkitView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        if let path = Bundle.main.path(forResource: "onboarding", ofType: "html") {
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
            print(dir)
            webkitView.loadFileURL(URL(fileURLWithPath: path), allowingReadAccessTo: dir)
        }
        
        let contentController = webkitView.configuration.userContentController
        contentController.add(self, name: "twoFHeyMessageHandler")
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController: WKScriptMessageHandler{
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageText = message.body as? String else {
            return
        }

        if messageText == "open-full-disk-access" {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        } else if messageText == "close-onboarding" {
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [path]
            task.launch()
            exit(0)
        }
    }
}

