//
//  CandidateWindowController.swift
//  LaVieKey
//
//  Candidate list for Japanese 変換, anchored under the caret:
//
//      ┌──────────────────┐
//      │ 1 漢字        ⏎  │  ← highlighted
//      │ 2 幹事           │
//      │ 3 監事           │
//      │   かんじ  1/12   │
//      └──────────────────┘
//
//  Same window mechanics as SuggestionPanelController (non-activating,
//  click-through, caret-anchored with a mouse fallback) — that positioning
//  logic is shared rather than duplicated.
//

import AppKit
import SwiftUI

private final class CandidateWindowModel: ObservableObject {
    @Published var state: KanaKanjiSession.State?
    @Published var pageStart: Int = 0
}

final class CandidateWindowController {

    static let shared = CandidateWindowController()

    /// How many candidates to show at once
    static let pageSize = 5

    private var panel: NSPanel?
    private var hostingView: NSHostingView<CandidateListView>?
    private let model = CandidateWindowModel()

    private init() {}

    // MARK: - Public API (callable from the event-tap thread)

    func show(_ state: KanaKanjiSession.State) {
        DispatchQueue.main.async { [weak self] in
            self?.render(state)
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }

    // MARK: - Rendering

    private func render(_ state: KanaKanjiSession.State) {
        let panel = ensurePanel()

        // Scroll the page so the highlighted entry is always visible
        let page = (state.selectedIndex / Self.pageSize) * Self.pageSize
        model.state = state
        model.pageStart = page

        let hosting: NSHostingView<CandidateListView>
        if let existing = hostingView {
            hosting = existing
        } else {
            hosting = NSHostingView(rootView: CandidateListView(model: model))
            hostingView = hosting
            panel.contentView = hosting
        }

        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 1 || size.height < 1 {
            size = NSSize(width: 200, height: 120)
        }

        panel.setFrame(NSRect(origin: CaretAnchor.origin(for: size), size: size), display: true)
        panel.orderFrontRegardless()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.panel = panel
        return panel
    }
}

// MARK: - List view

struct CandidateListView: View {
    @ObservedObject fileprivate var model: CandidateWindowModel

    var body: some View {
        if let state = model.state {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(visibleIndices(for: state), id: \.self) { index in
                    row(number: index - model.pageStart + 1,
                        text: state.candidates[index],
                        isSelected: index == state.selectedIndex)
                }

                HStack(spacing: 6) {
                    Text(state.reading)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 8)
                    Text("\(state.selectedIndex + 1)/\(state.candidates.count)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.top, 3)
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .fixedSize()
        }
    }

    private func visibleIndices(for state: KanaKanjiSession.State) -> [Int] {
        let end = min(model.pageStart + CandidateWindowController.pageSize, state.candidates.count)
        guard model.pageStart < end else { return [] }
        return Array(model.pageStart..<end)
    }

    private func row(number: Int, text: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                .frame(width: 12, alignment: .trailing)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .primary)

            Spacer(minLength: 10)

            if isSelected {
                Text("⏎")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 5).fill(Color.appAccent)
                : RoundedRectangle(cornerRadius: 5).fill(Color.clear)
        )
        .padding(.horizontal, 4)
    }
}
