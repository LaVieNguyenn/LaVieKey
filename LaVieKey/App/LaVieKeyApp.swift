//
//  LaVieKeyApp.swift
//  LaVieKey
//
//  Main app entry point
//

import SwiftUI
import Foundation

@main
struct LaVieKeyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        AppLanguage.applyLanguage()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Bảng điều khiển...") {
                    AppDelegate.shared?.openPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

