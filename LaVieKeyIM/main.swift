//
//  main.swift
//  LaVieKeyIM
//
//  Input Method Kit entry point for LaVieKey Vietnamese
//  This runs as a background service providing native Vietnamese input
//

import Cocoa
import InputMethodKit


// Note: Notification.Name.lavieKeySettingsDidChange is defined in SharedSettings.swift

// MARK: - App Delegate

class LaVieKeyIMAppDelegate: NSObject, NSApplicationDelegate {
    
    /// IMK Server instance
    var server: IMKServer!
    
    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            // Log version info for debugging
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
            IMKitDebugger.shared.log("Starting version \(version) (\(build))", category: "STARTUP")

            // Create IMK server
            // The connection name must match InputMethodConnectionName in Info.plist
            server = IMKServer(
                name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "LaVieKeyIM_Connection",
                bundleIdentifier: Bundle.main.bundleIdentifier!
            )

            IMKitDebugger.shared.log("Input Method server started", category: "STARTUP")
            IMKitDebugger.shared.log("Bundle ID = \(Bundle.main.bundleIdentifier ?? "unknown")", category: "STARTUP")
            
            // Listen for settings changes from main LaVieKey app
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(handleSettingsChanged),
                name: .lavieKeySettingsDidChange,
                object: nil
            )
        }
    }
    
    nonisolated func applicationWillTerminate(_ notification: Notification) {
        NSLog("LaVieKeyIM: Input Method server stopping")
    }
    
    @objc private func handleSettingsChanged(_ notification: Notification) {
        NSLog("LaVieKeyIM: Settings changed, reloading...")
        // Settings will be reloaded by LaVieKeyIMController on next input
    }
}

// MARK: - Main Entry Point

// Create and run the application
let app = NSApplication.shared
let delegate = LaVieKeyIMAppDelegate()
app.delegate = delegate

// Run the app (this blocks until the app terminates)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
