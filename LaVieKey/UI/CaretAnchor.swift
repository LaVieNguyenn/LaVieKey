//
//  CaretAnchor.swift
//  LaVieKey
//
//  Shared positioning for the floating panels that must sit next to the text
//  the user is typing (English suggestions, Japanese candidates).
//
//  Places the panel just below the caret, flips it above when there is no room,
//  and clamps it inside the visible frame. Falls back to the mouse pointer for
//  apps that expose no caret geometry.
//

import AppKit

enum CaretAnchor {

    /// Gap between the caret and the panel edge
    static let gap: CGFloat = 4

    static func origin(for size: NSSize) -> NSPoint {
        let anchor: NSRect
        if let caret = caretRectInCocoaCoordinates() {
            anchor = caret
        } else {
            let mouse = NSEvent.mouseLocation
            anchor = NSRect(x: mouse.x, y: mouse.y - 8, width: 1, height: 16)
        }

        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) }
            ?? NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visible = screen.visibleFrame

        // Below the caret; flipped above when it would fall off the bottom.
        var y = anchor.minY - size.height - gap
        if y < visible.minY {
            y = anchor.maxY + gap
        }
        y = min(max(y, visible.minY), max(visible.minY, visible.maxY - size.height))

        // maxX - width can fall left of minX on a narrow screen, hence the
        // explicit ordering of the two clamps.
        var x = anchor.minX
        x = min(x, visible.maxX - size.width)
        x = max(x, visible.minX)

        return NSPoint(x: x, y: y)
    }

    /// Caret rect in Cocoa (bottom-left origin) screen coordinates.
    static func caretRectInCocoaCoordinates() -> NSRect? {
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
        // screen (frame origin 0,0) — not screens[0], which is merely first in
        // an arbitrary order. Getting this wrong threw panels off-screen on
        // multi-display setups.
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                ?? NSScreen.screens.first
        else { return nil }

        let cocoaY = primary.frame.maxY - rect.maxY
        let caret = NSRect(x: rect.minX, y: cocoaY, width: max(rect.width, 1), height: rect.height)

        // Reject rects that land outside every screen (some apps report stale
        // geometry) — the mouse fallback beats a panel in the void.
        guard NSScreen.screens.contains(where: { $0.frame.intersects(caret) }) else { return nil }
        return caret
    }
}
