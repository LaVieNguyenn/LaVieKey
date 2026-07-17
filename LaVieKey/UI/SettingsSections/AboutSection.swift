//
//  AboutSection.swift
//  LaVieKey
//
//  Shared About Settings Section
//

import SwiftUI

struct AboutSection: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App Logo
                if let logo = NSImage(named: "LaVieKeyLogo") {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .padding(.top, 20)
                } else {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 50))
                        .foregroundColor(.appAccent)
                        .padding(.top, 20)
                }

                // App Name & Version
                VStack(spacing: 4) {
                    Text("LaVieKey")
                        .font(.system(size: 24, weight: .bold))

                    Text("Bộ gõ tiếng Việt mã nguồn mở cho macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(AppVersion.fullVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                Divider()
                    .padding(.horizontal, 80)

                // Open Source
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appAccent)
                        Text("Phần mềm mã nguồn mở — giấy phép MIT")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Phát triển dựa trên XKey (xmannv), lấy cảm hứng từ OpenKey & Unikey.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // GitHub Links
                HStack(spacing: 20) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/LaVieNguyenn/LaVieKey") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image("GitHubIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                            Text("Mã nguồn")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        if let url = URL(string: "https://github.com/LaVieNguyenn/LaVieKey/issues/new/choose") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image("BugIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                            Text("Báo lỗi")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        if let url = URL(string: "https://github.com/LaVieNguyenn/LaVieKey/releases") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                            Text("Bản phát hành")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 8)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
