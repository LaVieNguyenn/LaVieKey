//
//  SuggestionPanelController.swift
//  LaVieKey
//
//  Floating suggestion list anchored to the text caret:
//
//      ┌──────────────────┐
//      │ origin        ⇥  │  ← selected (accent background)
//      │ original         │
//      │ originally       │
//      └──────────────────┘
//
//  Non-activating, click-through, never takes focus. Positioned from the AX
//  caret rect (below the caret, flipped above when there is no room); falls
//  back to the mouse pointer when the app exposes no caret.
//

import AppKit
import SwiftUI

final class SuggestionPanelController {

    static let shared = SuggestionPanelController()

    private var panel: NSPanel?

    /// Gap between the caret and the panel edge
    private let caretGap: CGFloat = 4

    private init() {}

    // MARK: - Public API (callable from the event-tap thread)

    func show(_ set: SuggestionSet) {
        DispatchQueue.main.async { [weak self] in
            self?.render(set)
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }

    // MARK: - Rendering (main thread)

    private func render(_ set: SuggestionSet) {
        let panel = ensurePanel()

        let hosting = NSHostingView(rootView: SuggestionListView(set: set))
        panel.contentView = hosting
        // Force layout before measuring: fittingSize on a freshly attached
        // hosting view can still be zero, which produced a mis-placed (often
        // half-off-screen) panel.
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 1 || size.height < 1 {
            size = NSSize(width: 180, height: 60)
        }

        panel.setFrame(NSRect(origin: origin(for: size), size: size), display: true)
        panel.orderFrontRegardless()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true            // click-through
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.panel = panel
        return panel
    }

    // MARK: - Positioning

    /// Directly below the character being typed; flipped above the caret when
    /// the panel would fall off the bottom of that screen. Falls back to the
    /// mouse pointer for apps that expose no caret geometry.
    private func origin(for size: NSSize) -> NSPoint {
        let anchor: NSRect
        if let caret = caretRectInCocoaCoordinates() {
            anchor = caret
        } else {
            // No caret geometry: treat the mouse pointer as a zero-width caret
            let mouse = NSEvent.mouseLocation
            anchor = NSRect(x: mouse.x, y: mouse.y - 8, width: 1, height: 16)
        }

        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) }
            ?? NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visible = screen.visibleFrame

        // Vertical: below the caret, flipped above when there is no room.
        var y = anchor.minY - size.height - caretGap
        if y < visible.minY {
            y = anchor.maxY + caretGap
        }
        // Final clamp so the panel is never partially off-screen either way.
        y = min(max(y, visible.minY), max(visible.minY, visible.maxY - size.height))

        // Horizontal: anchored to the caret, clamped inside the visible frame.
        // maxX - width can fall left of minX on a narrow screen, hence the
        // explicit ordering of the two clamps.
        var x = anchor.minX
        x = min(x, visible.maxX - size.width)
        x = max(x, visible.minX)

        return NSPoint(x: x, y: y)
    }

    /// Caret rect in Cocoa (bottom-left origin) screen coordinates.
    /// AX reports top-left origin, so the Y axis is flipped against the
    /// primary screen.
    private func caretRectInCocoaCoordinates() -> NSRect? {
        guard let element = AXHelper.getFocusedElement(),
              let range = AXHelper.getRange(element, attribute: kAXSelectedTextRangeAttribute)
        else { return nil }

        var cfRange = CFRange(location: range.location, length: max(range.length, 1))
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }

        var boundsRef: CFTypeRef?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsRef
        )
        guard err == .success, let boundsRef else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &rect),
              rect.height > 0, rect.height < 200,      // sanity: a caret, not a page
              rect.width >= 0
        else { return nil }

        // AX reports top-left-origin coordinates measured from the PRIMARY
        // screen (the one whose frame origin is 0,0) — not from screens[0],
        // which is merely the first in an arbitrary order. Getting this wrong
        // threw the panel off-screen on multi-display setups.
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                ?? NSScreen.screens.first
        else { return nil }

        let cocoaY = primary.frame.maxY - rect.maxY
        let caret = NSRect(x: rect.minX, y: cocoaY, width: max(rect.width, 1), height: rect.height)

        // Reject caret rects that land outside every screen (some apps report
        // stale or bogus geometry) — the mouse fallback is better than a panel
        // in the void.
        guard NSScreen.screens.contains(where: { $0.frame.intersects(caret) }) else { return nil }
        return caret
    }
}

// MARK: - List view

private struct SuggestionListView: View {
    let set: SuggestionSet

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(set.candidates.enumerated()), id: \.offset) { index, candidate in
                row(candidate, isSelected: index == set.selectedIndex)
            }
            if set.candidates.count > 1 {
                Text("↑↓ chọn · ⇥ chấp nhận")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 1)
            }
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

    private func row(_ candidate: Suggestion, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            (
                Text(candidate.displayWord.prefix(candidate.typedPrefix.count))
                    .foregroundColor(isSelected ? .white : .primary)
                + Text(candidate.displayWord.dropFirst(candidate.typedPrefix.count))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
            )
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

            Spacer(minLength: 12)

            if isSelected {
                Text("⇥")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 5).fill(Color.appAccent)
                : RoundedRectangle(cornerRadius: 5).fill(Color.clear)
        )
        .padding(.horizontal, 4)
    }
}
