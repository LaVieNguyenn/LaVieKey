//
//  JapaneseSection.swift
//  LaVieKey
//
//  Japanese input settings (phase 1: romaji → kana)
//

import SwiftUI

struct JapaneseSection: View {
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var dictionaryStatus: String = ""
    @State private var newReading = ""
    @State private var newCandidate = ""
    @State private var userEntryRefresh = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroup(title: "Chế độ gõ") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "character.textbox")
                                .foregroundColor(.appAccent)
                            Text("Chọn 日本語 trên menu bar để bật")
                                .font(.subheadline)
                        }
                        Text("Gõ romaji sẽ tự thành kana: \"konnichiha\" → こんにちは, \"gakkou\" → がっこう.")
                            .font(.caption)
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

                SettingsGroup(title: "Chữ Hán (Kanji)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Bật chuyển kana → kanji (Space để chuyển)", isOn: $viewModel.preferences.kanjiConversionEnabled)
                            .disabled(!SKKDictionary.shared.isDownloaded)

                        HStack(spacing: 8) {
                            Image(systemName: SKKDictionary.shared.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                .foregroundColor(SKKDictionary.shared.isDownloaded ? .green : .appAccent)
                            Text(dictionaryStatus.isEmpty
                                 ? (SKKDictionary.shared.isDownloaded
                                    ? "Từ điển đã sẵn sàng"
                                    : "Chưa tải từ điển (khoảng 4 MB)")
                                 : dictionaryStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if isDownloading {
                            ProgressView(value: downloadProgress)
                                .frame(maxWidth: 260)
                        } else {
                            Button(SKKDictionary.shared.isDownloaded ? "Tải lại từ điển" : "Tải từ điển") {
                                downloadDictionary()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text("Gõ kana rồi bấm Space: ↑↓ chọn · 1–9 chọn nhanh · Enter xác nhận · Esc huỷ.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsGroup(title: "Từ điển cá nhân") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("Cách đọc (kana)", text: $newReading)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 130)
                            TextField("Chữ muốn hiện", text: $newCandidate)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 130)
                            Button("Thêm") {
                                JapaneseLearning.shared.addUserEntry(reading: newReading, candidate: newCandidate)
                                newReading = ""; newCandidate = ""
                                userEntryRefresh += 1
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(newReading.isEmpty || newCandidate.isEmpty)
                        }

                        let entries = JapaneseLearning.shared.allUserEntries()
                        if entries.isEmpty {
                            Text("Thêm tên riêng hoặc từ hay dùng để chúng luôn hiện đầu danh sách.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(entries, id: \.reading) { entry in
                                    HStack {
                                        Text(entry.reading).font(.system(size: 12))
                                        Text("→").foregroundColor(.secondary)
                                        Text(entry.candidates.joined(separator: " / ")).font(.system(size: 12))
                                        Spacer()
                                        Button {
                                            JapaneseLearning.shared.removeUserEntry(reading: entry.reading)
                                            userEntryRefresh += 1
                                        } label: {
                                            Image(systemName: "trash").font(.system(size: 10))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .id(userEntryRefresh)
                        }

                        Divider()

                        Button("Xoá dữ liệu đã học") {
                            JapaneseLearning.shared.resetLearned()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Text("Chữ bạn hay chọn sẽ tự nổi lên đầu danh sách.")
                            .font(.caption2)
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

    private func downloadDictionary() {
        isDownloading = true
        downloadProgress = 0
        dictionaryStatus = "Đang tải…"
        SKKDictionary.shared.download(
            progress: { downloadProgress = $0 },
            completion: { ok, message in
                isDownloading = false
                if ok {
                    dictionaryStatus = "Đã tải xong — \(SKKDictionary.shared.entryCount) mục"
                    viewModel.preferences.kanjiConversionEnabled = true
                } else {
                    dictionaryStatus = "Tải thất bại: \(message ?? "không rõ lý do")"
                }
            }
        )
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
