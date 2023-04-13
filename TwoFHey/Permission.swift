//
//  Permission.swift
//  TwoFHey
//
//  Created by Umang Loriya on 08/03/23.
//


import Cocoa

// I had a lot of problems getting all this setup so that the Accessibility permissions were clear and prompted to the user.
// macOS and Xcode have some 'interesting' quirks that impeade the development of this. Mainly that Xcode by default will run
//  in sandboxed mode, meaning native macOS permissions prompts won't fire until thats dissabled in the applications entitlements
//  file. The other is that macOS will not reset or apply the permissions to a new build of the app as the app signature changes
//  for each build, which makes sense but its annoying there isn't a way to automate this during development. The only 'solution'
//  I have yet found is to just use `tccutil` to reset the permissions for the $PRODUCT_BUNDLE_IDENTIFIER as an Xcode build script
//  with the annoyance being that you have to apply the permissions on each app build...
// See: https://stackoverflow.com/a/61890478/4494375



final class PermissionsService: ObservableObject {
    // Store the active trust state of the app.
    @Published var isTrusted: Bool = AXIsProcessTrusted()

    // Poll the accessibility state every 1 second to check
    //  and update the trust status.
    func pollAccessibilityPrivileges() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isTrusted = AXIsProcessTrusted()

            if !self.isTrusted {
                self.pollAccessibilityPrivileges()
            }
        }
    }

    // Request accessibility permissions, this should prompt
    //  macOS to open and present the required dialogue open
    //  to the correct page for the user to just hit the add
    //  button.
    static func acquireAccessibilityPrivileges() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
