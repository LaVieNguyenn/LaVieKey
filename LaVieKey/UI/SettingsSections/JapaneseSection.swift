//
//  JapaneseSection.swift
//  LaVieKey
//
//  Japanese input settings (phase 1: romaji → kana)
//

import SwiftUI

struct JapaneseSection: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroup(title: "Chế độ gõ") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "character.textbox")
                                .foregroundColor(.appAccent)
                            Text("Gõ romaji → kana (giai đoạn 1)")
                                .font(.subheadline)
                        }
                        Text("Chọn ngôn ngữ 日本語 trong menu bar (hoặc popover LaVieKey) để bật. Gõ romaji sẽ tự chuyển thành kana: \"konnichiha\" → こんにちは, \"gakkou\" → がっこう, \"kyou\" → きょう.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Chuyển kana → kanji (変換, cửa sổ chọn ứng viên) thuộc giai đoạn 2 — xem docs/JAPANESE_ROADMAP.md.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsGroup(title: "Bảng chữ") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(KanaScript.allCases, id: \.self) { script in
                            SettingsRadioButton(
                                title: LocalizedStringKey(script.displayName),
                                isSelected: viewModel.preferences.kanaScript == script
                            ) {
                                viewModel.preferences.kanaScript = script
                            }
                        }
                        Text("Katakana dùng cho từ mượn: \"ko-hi-\" → コーヒー (phím \"-\" là trường âm ー).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsGroup(title: "Dấu câu") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Dùng dấu câu Nhật (。、？！「」)", isOn: $viewModel.preferences.japanesePunctuation)
                        Text("Khi bật: . → 。   , → 、   ? → ？   ! → ！   [ ] → 「 」")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsGroup(title: "Mẹo gõ") {
                    VStack(alignment: .leading, spacing: 6) {
                        tipRow("nn hoặc n'", "ん (\"shinbun\" → しんぶん)")
                        tipRow("Phụ âm đôi", "っ (\"gakkou\" → がっこう)")
                        tipRow("xtu / ltu", "っ đứng riêng")
                        tipRow("xa xi xu xe xo", "ぁぃぅぇぉ (kana nhỏ)")
                        tipRow("-", "ー (trường âm)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func tipRow(_ keys: String, _ result: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(keys)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(4)
            Text(result)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
