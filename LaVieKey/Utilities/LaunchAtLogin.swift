//
//  LaunchAtLogin.swift
//  LaVieKey
//
//  Utility for managing launch at login
//

import Foundation
import ServiceManagement

class LaunchAtLogin {

    /// Reports registration problems (wired to the debug window by AppDelegate)
    static var logCallback: ((String) -> Void)?

    /// Enable or disable launch at login.
    /// - Returns: true when macOS accepted the change.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            do {
                if enabled {
                    // register() throws if it is already registered; that is a
                    // success from the caller's point of view.
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
                logCallback?("Khởi động cùng hệ thống: \(enabled ? "BẬT" : "TẮT") (trạng thái: \(statusDescription))")
                return true
            } catch {
                // Most common cause: the user disabled the item in System
                // Settings → General → Login Items, which macOS then refuses to
                // re-enable programmatically until they allow it there.
                logCallback?("Không đặt được khởi động cùng hệ thống: \(error.localizedDescription)")
                return false
            }
        } else {
            // Legacy API for macOS 12 and below
            // Note: This should be the helper bundle ID, not the App Group
            return SMLoginItemSetEnabled("lavie.nguyen.LaVieKey.LaunchHelper" as CFString, enabled)
        }
    }

    /// Human-readable registration status (macOS 13+)
    static var statusDescription: String {
        guard #available(macOS 13.0, *) else { return "không rõ (macOS 12)" }
        switch SMAppService.mainApp.status {
        case .enabled: return "đã bật"
        case .notRegistered: return "chưa đăng ký"
        case .notFound: return "không tìm thấy"
        case .requiresApproval: return "chờ người dùng cho phép trong System Settings"
        @unknown default: return "không rõ"
        }
    }
    
    /// Check if launch at login is currently enabled
    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For legacy API, we can't reliably check status
            // Return false as default
            return false
        }
    }
}
