//
//  IMKitDebugger.swift
//  LaVieKeyIM
//
//  Thin wrapper around DebugLogger for LaVieKeyIM-specific logging.
//  Delegates all file I/O to DebugLogger.shared (available in both targets).
//

import Foundation

/// Singleton debugger for IMKit logging - delegates to shared DebugLogger
class IMKitDebugger {
    static let shared = IMKitDebugger()

    private init() {}

    /// Log a message with [LaVieKeyIM] prefix
    func log(_ message: @autoclosure () -> String) {
        DebugLogger.shared.info("[LaVieKeyIM] \(message())")
    }

    /// Log with category
    func log(_ message: @autoclosure () -> String, category: String) {
        DebugLogger.shared.info("[LaVieKeyIM] [\(category)] \(message())")
    }
}
