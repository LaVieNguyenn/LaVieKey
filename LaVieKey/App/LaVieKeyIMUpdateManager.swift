//
//  LaVieKeyIMUpdateManager.swift
//  LaVieKey
//
//  Manages automatic updates for LaVieKeyIM (Input Method Extension)
//  Updates LaVieKeyIM by installing the bundled version from LaVieKey.app/Contents/Resources/
//

import Foundation
import AppKit
import UserNotifications

/// Manager for LaVieKeyIM auto-update functionality
class LaVieKeyIMUpdateManager {
    
    // MARK: - Singleton
    
    static let shared = LaVieKeyIMUpdateManager()
    
    // MARK: - Properties
    
    /// Callback for logging debug messages
    var debugLogCallback: ((String) -> Void)?
    
    /// Path to installed LaVieKeyIM
    private let installedLaVieKeyIMPath = NSHomeDirectory() + "/Library/Input Methods/LaVieKeyIM.app"
    
    /// Path to bundled LaVieKeyIM in LaVieKey.app
    private var bundledLaVieKeyIMPath: String? {
        return Bundle.main.resourcePath.map { $0 + "/LaVieKeyIM.app" }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Version Checking
    
    /// Check if LaVieKeyIM needs update
    /// - Returns: True if bundled version is newer than installed version
    func needsUpdate() -> Bool {
        guard let bundledPath = bundledLaVieKeyIMPath,
              FileManager.default.fileExists(atPath: bundledPath) else {
            logDebug("LaVieKeyIM: No bundled version found in LaVieKey.app/Contents/Resources/")
            return false
        }
        
        // Check if LaVieKeyIM is installed
        guard FileManager.default.fileExists(atPath: installedLaVieKeyIMPath) else {
            logDebug("LaVieKeyIM: Not installed yet, will install bundled version")
            return true
        }
        
        // Compare versions
        let installedVersion = getVersion(at: installedLaVieKeyIMPath)
        let bundledVersion = getVersion(at: bundledPath)
        
        logDebug("LaVieKeyIM Version Check:")
        logDebug("   Installed: \(installedVersion ?? "unknown")")
        logDebug("   Bundled:   \(bundledVersion ?? "unknown")")
        
        guard let installed = installedVersion,
              let bundled = bundledVersion else {
            logDebug("LaVieKeyIM: Could not determine versions")
            return false
        }
        
        // Compare version strings
        let needsUpdate = compareVersions(bundled, installed) == .orderedDescending
        
        if needsUpdate {
            logDebug("LaVieKeyIM: Update available (\(installed) → \(bundled))")
        } else {
            logDebug("LaVieKeyIM: Up to date (\(installed))")
        }
        
        return needsUpdate
    }
    
    /// Get version from LaVieKeyIM.app bundle
    private func getVersion(at path: String) -> String? {
        let infoPlistPath = path + "/Contents/Info.plist"
        
        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }
        
        // Get version and build number
        let version = plist["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = plist["CFBundleVersion"] as? String ?? "0"
        
        return "\(version).\(build)"
    }
    
    /// Compare two version strings (e.g., "1.2.17.20251229")
    /// - Returns: ComparisonResult (.orderedAscending, .orderedSame, .orderedDescending)
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
    
    // MARK: - Installation
    
    /// Install bundled LaVieKeyIM to ~/Library/Input Methods/
    /// - Parameter showNotification: Whether to show user notification after installation
    /// - Returns: True if installation succeeded
    @discardableResult
    func installBundledLaVieKeyIM(showNotification: Bool = true) -> Bool {
        guard let bundledPath = bundledLaVieKeyIMPath,
              FileManager.default.fileExists(atPath: bundledPath) else {
            logDebug("LaVieKeyIM: Cannot install - bundled version not found")
            return false
        }
        
        // Log version info if available
        let bundledVersion = getVersion(at: bundledPath)
        let installedVersion = FileManager.default.fileExists(atPath: installedLaVieKeyIMPath) 
            ? getVersion(at: installedLaVieKeyIMPath) 
            : nil
        
        if let installed = installedVersion, let bundled = bundledVersion {
            logDebug("LaVieKeyIM: Installing bundled version (\(installed) → \(bundled))...")
        } else {
            logDebug("LaVieKeyIM: Installing bundled version...")
        }
        
        // Kill running LaVieKeyIM process if exists
        killLaVieKeyIMProcess()
        
        // Wait a bit for process to fully terminate
        Thread.sleep(forTimeInterval: 0.5)
        
        // Create Input Methods directory if needed
        let inputMethodsDir = NSHomeDirectory() + "/Library/Input Methods"
        do {
            try FileManager.default.createDirectory(atPath: inputMethodsDir, withIntermediateDirectories: true)
        } catch {
            logDebug("LaVieKeyIM: Failed to create Input Methods directory: \(error)")
            return false
        }
        
        // Remove old version
        if FileManager.default.fileExists(atPath: installedLaVieKeyIMPath) {
            do {
                try FileManager.default.removeItem(atPath: installedLaVieKeyIMPath)
                logDebug("Removed old version")
            } catch {
                logDebug("LaVieKeyIM: Failed to remove old version: \(error)")
                // Continue anyway, copyItem might overwrite
            }
        }
        
        // Copy new version
        do {
            try FileManager.default.copyItem(atPath: bundledPath, toPath: installedLaVieKeyIMPath)
            logDebug("Copied new version")
        } catch {
            logDebug("LaVieKeyIM: Failed to copy new version: \(error)")
            return false
        }
        
        // Verify installation
        guard FileManager.default.fileExists(atPath: installedLaVieKeyIMPath) else {
            logDebug("LaVieKeyIM: Installation verification failed")
            return false
        }
        
        let finalVersion = getVersion(at: installedLaVieKeyIMPath)
        logDebug("LaVieKeyIM: Installed successfully (v\(finalVersion ?? "unknown"))")
        
        // Show notification to user
        if showNotification {
            showUpdateNotification(version: finalVersion ?? "unknown")
        }
        
        return true
    }
    
    /// Kill running LaVieKeyIM process
    private func killLaVieKeyIMProcess() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["LaVieKeyIM"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                logDebug("Killed running LaVieKeyIM process")
            }
        } catch {
            // Process might not be running, that's okay
            logDebug("No running LaVieKeyIM process found")
        }
    }
    
    /// Show notification to user about LaVieKeyIM update
    private func showUpdateNotification(version: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = String(localized: "LaVieKeyIM đã được cập nhật")
            content.body = String(localized: "Phiên bản \(version) đã được cài đặt.\n\nVui lòng chuyển sang input method khác rồi quay lại LaVieKey để áp dụng.")
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "laviekeyim-update-\(version)", content: content, trigger: nil)
            center.add(request)
        }
        
        logDebug("LaVieKeyIM: Update notification sent to user")
    }
    
    // MARK: - Auto-Update Check
    
    /// Check and install LaVieKeyIM update if available
    /// Called automatically when LaVieKey app updates
    func checkAndInstallUpdate() {
        logDebug("LaVieKeyIM: Checking for updates...")
        
        if needsUpdate() {
            installBundledLaVieKeyIM(showNotification: true)
        } else {
            logDebug("LaVieKeyIM: Already up to date")
        }
    }
    
    // MARK: - Debug Logging
    
    private func logDebug(_ message: String) {
        // Only use DebugLogger (which writes to file), debugWindowController will read from file
        sharedLogInfo(message)
    }
}
