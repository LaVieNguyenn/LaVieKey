//
//  IMKitHelper.swift
//  LaVieKey
//
//  Helper utilities for IMKit integration
//

import Foundation
import AppKit
import Carbon

/// Helper class for managing LaVieKeyIM Input Method
class IMKitHelper {
    
    // MARK: - Singleton
    
    static let shared = IMKitHelper()
    private init() {}
    
    // MARK: - Constants
    
    /// Bundle identifier for LaVieKeyIM
    static let lavieKeyIMBundleId = "lavie.nguyen.inputmethod.LaVieKey"
    
    /// Installation path for Input Methods
    static let inputMethodsPath = "~/Library/Input Methods".expandingTildeInPath
    
    /// LaVieKeyIM app name
    static let lavieKeyIMAppName = "LaVieKeyIM.app"
    
    // MARK: - Installation Check
    
    /// Check if LaVieKeyIM is installed
    static func isLaVieKeyIMInstalled() -> Bool {
        let path = (inputMethodsPath as NSString).appendingPathComponent(lavieKeyIMAppName)
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Check if LaVieKeyIM is enabled in System Settings
    static func isLaVieKeyIMEnabled() -> Bool {
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as CFArray? else {
            return false
        }
        
        let count = CFArrayGetCount(inputSources)
        for i in 0..<count {
            let source = unsafeBitCast(CFArrayGetValueAtIndex(inputSources, i), to: TISInputSource.self)
            
            if let bundleIdPtr = TISGetInputSourceProperty(source, kTISPropertyBundleID) {
                let bundleId = Unmanaged<CFString>.fromOpaque(bundleIdPtr).takeUnretainedValue() as String
                if bundleId == lavieKeyIMBundleId {
                    if let enabledPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) {
                        let enabled = Unmanaged<CFBoolean>.fromOpaque(enabledPtr).takeUnretainedValue()
                        return CFBooleanGetValue(enabled)
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Installation
    
    /// Kill running LaVieKeyIM process
    private static func killLaVieKeyIMProcess() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["LaVieKeyIM"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // Process might not be running, that's okay
        }
    }
    
    /// Install LaVieKeyIM to ~/Library/Input Methods
    /// This also handles reinstallation by killing any running process first
    static func installLaVieKeyIM() {
        // Kill running LaVieKeyIM process first (safe even if not running)
        killLaVieKeyIMProcess()
        
        // Wait for process to fully terminate
        Thread.sleep(forTimeInterval: 0.5)
        
        // Get LaVieKeyIM from app bundle Resources
        guard let lavieKeyIMSource = Bundle.main.path(forResource: "LaVieKeyIM", ofType: "app") else {
            showAlert(
                title: String(localized: "Không tìm thấy LaVieKeyIM"),
                message: String(localized: "LaVieKeyIM.app không có trong bundle. Vui lòng tải phiên bản đầy đủ từ GitHub.")
            )
            return
        }
        
        let destinationPath = (inputMethodsPath as NSString).appendingPathComponent(lavieKeyIMAppName)
        let fileManager = FileManager.default
        
        // First, try direct copy (works if not sandboxed or has permission)
        do {
            // Create Input Methods directory if needed
            if !fileManager.fileExists(atPath: inputMethodsPath) {
                try fileManager.createDirectory(
                    atPath: inputMethodsPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            // Remove old version if exists
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            
            // Copy new version
            try fileManager.copyItem(atPath: lavieKeyIMSource, toPath: destinationPath)
            
            // Register the input source
            registerInputSource(at: destinationPath)
            
            showAlert(
                title: String(localized: "Cài đặt thành công"),
                message: String(localized: "LaVieKeyIM đã được cài đặt.\n\nVui lòng vào System Settings → Keyboard → Input Sources để bật LaVieKey Vietnamese.")
            )
            
            // Open Input Sources settings
            openInputSourcesSettings()
            
        } catch {
            // If direct copy fails, show LaVieKeyIM in Finder for manual installation
            showManualInstallInstructions(lavieKeyIMSource: lavieKeyIMSource)
        }
    }
    
    /// Show manual installation instructions and reveal LaVieKeyIM in Finder
    private static func showManualInstallInstructions(lavieKeyIMSource: String) {
        // Use a loop to keep dialog open until user clicks "Đóng"
        var shouldContinue = true
        
        while shouldContinue {
            let alert = NSAlert()
            alert.messageText = String(localized: "Cài đặt thủ công LaVieKeyIM")
            alert.informativeText = String(localized: "Do giới hạn bảo mật, LaVieKey không thể tự động cài đặt LaVieKeyIM.\n\nVui lòng làm theo các bước sau:\n1. Nhấn \"Mở LaVieKeyIM\" để hiển thị LaVieKeyIM.app\n2. Nhấn \"Mở Input Methods\" để mở thư mục đích\n3. Kéo thả LaVieKeyIM.app vào thư mục Input Methods\n4. Nhấn \"Mở Input Sources\" để thêm LaVieKey Vietnamese")
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "Mở LaVieKeyIM"))
            alert.addButton(withTitle: String(localized: "Mở Input Methods"))
            alert.addButton(withTitle: String(localized: "Mở Input Sources"))
            alert.addButton(withTitle: String(localized: "Đóng"))
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                // Reveal LaVieKeyIM in Finder
                NSWorkspace.shared.selectFile(lavieKeyIMSource, inFileViewerRootedAtPath: "")
                
            case .alertSecondButtonReturn:
                // Open Input Methods folder (create if needed)
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: inputMethodsPath) {
                    try? fileManager.createDirectory(
                        atPath: inputMethodsPath,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                }
                NSWorkspace.shared.open(URL(fileURLWithPath: inputMethodsPath))
                
            case .alertThirdButtonReturn:
                // Open System Settings > Keyboard > Input Sources
                openInputSourcesSettings()
                
            default:
                // "Đóng" button - exit the loop
                shouldContinue = false
            }
        }
    }
    
    /// Uninstall LaVieKeyIM
    static func uninstallLaVieKeyIM() {
        let path = (inputMethodsPath as NSString).appendingPathComponent(lavieKeyIMAppName)
        
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(atPath: path)
            
            showAlert(
                title: String(localized: "Gỡ cài đặt thành công"),
                message: String(localized: "LaVieKeyIM đã được gỡ bỏ.")
            )
        } catch {
            showAlert(
                title: String(localized: "Lỗi"),
                message: String(localized: "Không thể gỡ LaVieKeyIM: \(error.localizedDescription)")
            )
        }
    }
    
    // MARK: - Input Source Registration
    
    /// Register input source with the system
    private static func registerInputSource(at path: String) {
        let url = URL(fileURLWithPath: path) as CFURL
        TISRegisterInputSource(url)
    }
    
    /// Enable LaVieKeyIM input source
    static func enableLaVieKeyIM() {
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as CFArray? else {
            return
        }
        
        let count = CFArrayGetCount(inputSources)
        for i in 0..<count {
            let source = unsafeBitCast(CFArrayGetValueAtIndex(inputSources, i), to: TISInputSource.self)
            
            if let bundleIdPtr = TISGetInputSourceProperty(source, kTISPropertyBundleID) {
                let bundleId = Unmanaged<CFString>.fromOpaque(bundleIdPtr).takeUnretainedValue() as String
                if bundleId == lavieKeyIMBundleId {
                    TISEnableInputSource(source)
                    return
                }
            }
        }
    }
    
    /// Select LaVieKeyIM as current input source
    static func selectLaVieKeyIM() {
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as CFArray? else {
            return
        }
        
        let count = CFArrayGetCount(inputSources)
        for i in 0..<count {
            let source = unsafeBitCast(CFArrayGetValueAtIndex(inputSources, i), to: TISInputSource.self)
            
            if let bundleIdPtr = TISGetInputSourceProperty(source, kTISPropertyBundleID) {
                let bundleId = Unmanaged<CFString>.fromOpaque(bundleIdPtr).takeUnretainedValue() as String
                if bundleId == lavieKeyIMBundleId {
                    TISSelectInputSource(source)
                    return
                }
            }
        }
    }
    
    // MARK: - Open System Settings
    
    /// Open Keyboard Input Sources in System Settings
    static func openInputSourcesSettings() {
        if #available(macOS 13.0, *) {
            // macOS Ventura and later
            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?InputSources") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // Older macOS
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?InputSources") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Helpers
    
    private static func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - String Extension

extension String {
    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }
}
