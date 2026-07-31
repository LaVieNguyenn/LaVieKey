//
//  AppearanceSection.swift
//  LaVieKey
//
//  Shared Appearance Settings Section
//

import SwiftUI

struct AppearanceSection: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var showRestartAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroup(title: "Chủ đề") {
                    VStack(alignment: .leading, spacing: 14) {
                        // Light/dark mode
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Chế độ hiển thị:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("", selection: $viewModel.preferences.appearanceMode) {
                                ForEach(AppAppearanceMode.allCases, id: \.self) { mode in
                                    Text(LocalizedStringKey(mode.displayName)).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 320)
                        }

                        // Accent color swatches + free colour picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Màu nhấn:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 10) {
                                ForEach(AccentTheme.presets, id: \.self) { theme in
                                    Button {
                                        viewModel.preferences.accentTheme = theme
                                    } label: {
                                        swatch(theme.color, isSelected: viewModel.preferences.accentTheme == theme)
                                    }
                                    .buttonStyle(.plain)
                                    .help(LocalizedStringKey(theme.displayName))
                                }

                                Divider().frame(height: 20)

                                // Free choice — click the well to open the macOS colour picker
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: viewModel.preferences.accentCustomHex) ?? .blue },
                                    set: { newColor in
                                        viewModel.preferences.accentCustomHex = newColor.hexString
                                        viewModel.preferences.accentTheme = .custom
                                    }
                                ), supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 26, height: 22)
                                .help(LocalizedStringKey("Tuỳ chỉnh"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(
                                            viewModel.preferences.accentTheme == .custom
                                                ? Color.primary.opacity(0.6) : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                        }

                        Text("Màu nhấn áp dụng cho cửa sổ cài đặt, menu và các thanh công cụ của LaVieKey.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsGroup(title: "Thanh menu") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biểu tượng menubar:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                                SettingsRadioButton(
                                    title: LocalizedStringKey(style.displayName),
                                    isSelected: viewModel.preferences.menuBarIconStyle == style
                                ) {
                                    viewModel.preferences.menuBarIconStyle = style
                                }
                            }
                        }
                        .padding(.leading, 8)

                        Text("Emoji sẽ hiển thị 🇻🇳 khi ở tiếng Việt và 🇬🇧 khi ở tiếng Anh.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                SettingsGroup(title: "Dock") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Hiển thị biểu tượng trên thanh Dock", isOn: $viewModel.preferences.showDockIcon)
                        
                        Text("Khi bật, LaVieKey sẽ hiển thị icon trên Dock như các ứng dụng thông thường")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                SettingsGroup(title: "Ngôn ngữ") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $viewModel.preferences.appLanguage) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                        .onChange(of: viewModel.preferences.appLanguage) { _ in
                            viewModel.save()
                            showRestartAlert = true
                        }
                    }
                }
                .alert(String(localized: "Khởi động lại LaVieKey?"), isPresented: $showRestartAlert) {
                    Button(String(localized: "Khởi động lại"), role: .destructive) {
                        restartApp()
                    }
                    Button(String(localized: "Để sau"), role: .cancel) {}
                } message: {
                    Text("Ngôn ngữ mới sẽ được áp dụng sau khi khởi động lại ứng dụng.")
                }

                SettingsGroup(title: "Khởi động") {
                    Toggle("Khởi động cùng hệ thống", isOn: $viewModel.preferences.startAtLogin)
                    Toggle("Tự động kiểm tra bản cập nhật", isOn: $viewModel.preferences.autoCheckForUpdates)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func swatch(_ color: Color, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .overlay(
            Circle().strokeBorder(isSelected ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }

    private func restartApp() {
        let bundlePath = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        // Pass bundle path as argv $1 (not string interpolated) so paths with quotes/$ are safe.
        let script = """
        while kill -0 \(pid) 2>/dev/null; do
            sleep 0.1
        done
        open "$1"
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", script, "--", bundlePath]
        do {
            try task.run()
        } catch {
            NSLog("LaVieKey restartApp: failed to launch relaunch helper: \(error)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
}
