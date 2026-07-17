//
//  ThemeManager.swift
//  LaVieKey
//
//  Central theme state: accent color + light/dark override.
//  Root hosting views observe this and apply .tint(); NSApp.appearance
//  is set globally for the light/dark mode.
//

import SwiftUI
import AppKit

// MARK: - UI mapping for theme enums
// The enums themselves live in Core/Models/Preferences.swift because
// Preferences.swift is compiled into BOTH targets (app + LaVieKeyIM);
// only the SwiftUI/AppKit mappings belong here (app target only).

extension AppAppearanceMode {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

extension AccentTheme {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return Color(red: 0x58/255.0, green: 0x56/255.0, blue: 0xD6/255.0)
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .teal: return Color(red: 0x30/255.0, green: 0xB0/255.0, blue: 0xC7/255.0)
        case .graphite: return Color(white: 0.45)
        }
    }
}

// MARK: - Theme manager

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var accent: Color = AccentTheme.blue.color
    @Published private(set) var appearanceMode: AppAppearanceMode = .system

    private init() {}

    /// Apply theme from preferences: updates published accent (root views
    /// re-render) and the app-wide light/dark appearance.
    func apply(_ preferences: Preferences) {
        let newAccent = preferences.accentTheme.color
        let newMode = preferences.appearanceMode

        let update = {
            if self.appearanceMode != newMode {
                self.appearanceMode = newMode
                NSApp.appearance = newMode.nsAppearance
            }
            // Color lacks a cheap stable identity check across dynamic providers;
            // publishing unconditionally is fine (SwiftUI diffs downstream).
            self.accent = newAccent
        }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }
}

// MARK: - Convenience

extension Color {
    /// App accent honoring the user's theme choice. Safe to read in any body:
    /// root views observe ThemeManager, so a change re-renders the whole tree.
    static var appAccent: Color { ThemeManager.shared.accent }
}
