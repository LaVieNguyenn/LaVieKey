//
//  SettingsView.swift
//  LaVieKey
//
//  Unified Settings View with Apple-style sidebar navigation
//  Supports macOS 26 Tahoe Liquid Glass design
//  Uses shared components from SettingsSections/
//

import SwiftUI

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
    // Ngôn ngữ
    case general = "Tiếng Việt"
    case japanese = "Tiếng Nhật"
    // Bàn phím
    case quickTyping = "Gõ nhanh"
    case macro = "Macro"
    case excludedApps = "Loại trừ"
    case convertTool = "Chuyển đổi"
    case translation = "Dịch thuật"
    // Ứng dụng
    case appearance = "Giao diện"
    case inputSources = "Input Sources"
    case advanced = "Nâng cao"
    case backupRestore = "Sao lưu"
    case about = "Giới thiệu"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "keyboard"
        case .japanese: return "character.textbox"
        case .quickTyping: return "hare"
        case .advanced: return "slider.horizontal.3"
        case .inputSources: return "globe"
        case .excludedApps: return "app.badge.fill"
        case .macro: return "text.badge.plus"
        case .translation: return "globe.americas"
        case .convertTool: return "arrow.left.arrow.right"
        case .appearance: return "paintbrush"
        case .backupRestore: return "arrow.up.arrow.down.circle"
        case .about: return "info.circle"
        }
    }
}

/// Sidebar groups — the app is heading multi-language, so the sidebar is
/// organized by: typing languages / keyboard features / application.
enum SettingsSidebarGroup: String, CaseIterable, Identifiable {
    case languages = "Ngôn ngữ"
    case keyboard = "Bàn phím"
    case application = "Ứng dụng"

    var id: String { rawValue }

    var sections: [SettingsSection] {
        switch self {
        case .languages: return [.general, .japanese]
        case .keyboard: return [.quickTyping, .macro, .excludedApps, .convertTool, .translation]
        case .application: return [.appearance, .inputSources, .advanced, .backupRestore, .about]
        }
    }
}

// MARK: - Settings Navigator

/// Single source of truth for the active section, shared between the window
/// controller and the view so sections can be switched live without recreating the window.
final class SettingsNavigator: ObservableObject {
    @Published var selectedSection: SettingsSection

    init(_ selectedSection: SettingsSection = .general) {
        self.selectedSection = selectedSection
    }
}

// MARK: - Main Settings View

@available(macOS 13.0, *)
struct SettingsView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @ObservedObject var navigator: SettingsNavigator
    @ObservedObject private var theme = ThemeManager.shared

    var onSave: ((Preferences) -> Void)?

    init(navigator: SettingsNavigator, onSave: ((Preferences) -> Void)? = nil) {
        self.navigator = navigator
        self.onSave = onSave
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar — grouped for multi-language support
            List(selection: $navigator.selectedSection) {
                ForEach(SettingsSidebarGroup.allCases) { group in
                    Section {
                        ForEach(group.sections) { section in
                            Label {
                                Text(LocalizedStringKey(section.rawValue))
                            } icon: {
                                Image(systemName: section.icon)
                            }
                            .tag(section)
                        }
                    } header: {
                        Text(LocalizedStringKey(group.rawValue))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            // Content - Using shared components
            Group {
                switch navigator.selectedSection {
                case .general:
                    GeneralSection(viewModel: viewModel)
                case .japanese:
                    JapaneseSection(viewModel: viewModel)
                case .quickTyping:
                    QuickTypingSection(viewModel: viewModel)
                case .advanced:
                    AdvancedSection(viewModel: viewModel)
                case .inputSources:
                    InputSourcesSection(preferencesViewModel: viewModel)
                case .excludedApps:
                    ExcludedAppsSection(viewModel: viewModel)
                case .macro:
                    MacroSection(prefsViewModel: viewModel)
                case .translation:
                    TranslationSection(viewModel: viewModel)
                case .convertTool:
                    ConvertToolSection()
                case .appearance:
                    AppearanceSection(viewModel: viewModel)
                case .backupRestore:
                    BackupRestoreSection()
                case .about:
                    AboutSection()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 750, minHeight: 550)
        .tint(theme.accent)
        .onReceive(viewModel.objectWillChange) { _ in
            // Auto-save when any preference changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.save()
                onSave?(viewModel.preferences)
            }
        }
    }
}

// MARK: - Preview

@available(macOS 13.0, *)
#Preview {
    SettingsView(navigator: SettingsNavigator())
}
