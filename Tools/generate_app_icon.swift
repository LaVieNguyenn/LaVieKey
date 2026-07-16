import AppKit
import CoreGraphics

// Generates the LaVieKey "LV" keycap app icon:
// - master 1024×1024 PNG (macOS icon grid: 824×824 content, radius 185)
// - blue gradient background + white keycap outline + bold "LV"
// Downscaling to the appiconset sizes is done by the caller (sips).

let canvas: CGFloat = 1024
let content = CGRect(x: 100, y: 100, width: 824, height: 824)

let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
    // Background: rounded rect with vertical blue gradient
    let bgPath = NSBezierPath(roundedRect: content, xRadius: 185, yRadius: 185)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0x25/255.0, green: 0x63/255.0, blue: 0xEB/255.0, alpha: 1),  // #2563EB
        ending: NSColor(calibratedRed: 0x60/255.0, green: 0xA5/255.0, blue: 0xFA/255.0, alpha: 1)     // #60A5FA
    )!
    gradient.draw(in: bgPath, angle: 90)

    // Keycap outline (echoes the menu-bar icon: rounded rect + letters)
    let keyRect = content.insetBy(dx: 88, dy: 88)
    let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: 120, yRadius: 120)
    NSColor(calibratedWhite: 1, alpha: 0.9).setStroke()
    keyPath.lineWidth = 26
    keyPath.stroke()

    // "LV" centered
    let text = "LV" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 330, weight: .bold),
        .foregroundColor: NSColor.white,
        .kern: -6,
    ]
    let textSize = text.size(withAttributes: attributes)
    text.draw(
        in: NSRect(
            x: content.midX - textSize.width / 2,
            y: content.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        ),
        withAttributes: attributes
    )
    return true
}

// Save master PNG
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outPath = scriptDir.appendingPathComponent("laviekey-icon-1024.png")
try! png.write(to: outPath)
print("✅ \(outPath.path) (\(rep.pixelsWide)×\(rep.pixelsHigh))")
