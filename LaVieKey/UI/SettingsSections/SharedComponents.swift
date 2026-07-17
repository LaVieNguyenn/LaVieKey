//
//  SharedComponents.swift
//  LaVieKey
//
//  Shared UI Components for Settings
//

import SwiftUI

// MARK: - Settings Group

struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 2)

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
        }
    }
}

// MARK: - Settings Radio Button

struct SettingsRadioButton: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? .appAccent : .secondary)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
