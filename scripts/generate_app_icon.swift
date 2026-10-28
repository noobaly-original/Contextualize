import Cocoa

@main
struct AppIconGenerator {
    static func main() {
        guard CommandLine.arguments.count > 1 else {
            fputs("Usage: generate_app_icon <output.iconset>\n", stderr)
            exit(1)
        }
        let iconsetPath = CommandLine.arguments[1]
        let fm = FileManager.default
        try? fm.removeItem(atPath: iconsetPath)
        try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

        let specs: [(name: String, pixels: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for spec in specs {
            if let pngData = renderIconPNG(pixels: spec.pixels) {
                let fileURL = URL(fileURLWithPath: iconsetPath).appendingPathComponent(spec.name)
                try? pngData.write(to: fileURL)
            }
        }
    }

    static func renderIconPNG(pixels: Int) -> Data? {
        let size = NSSize(width: pixels, height: pixels)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            ctx.imageInterpolation = .high

            let w = CGFloat(pixels)
            // Standard macOS Big Sur / Sonoma / Sequoia icon padding (~9% inset) & continuous squircle corner radius
            let inset = w * 0.08
            let rect = NSRect(x: inset, y: inset, width: w - inset * 2, height: w - inset * 2)
            let radius = rect.width * 0.225
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

            // Draw gradient matching SettingsWindowView header icon
            let topColor = NSColor(srgbRed: 0.05, green: 0.52, blue: 1.00, alpha: 1.0)
            let bottomColor = NSColor(srgbRed: 0.09, green: 0.30, blue: 0.85, alpha: 1.0)
            if let gradient = NSGradient(starting: topColor, ending: bottomColor) {
                gradient.draw(in: path, angle: -45)
            }

            // Subtle inner highlight border
            NSColor.white.withAlphaComponent(0.22).setStroke()
            path.lineWidth = max(1.0, w * 0.012)
            path.stroke()

            // Draw white `plus.rectangle.on.folder.fill` symbol centered
            if let baseSym = NSImage(systemSymbolName: "plus.rectangle.on.folder.fill", accessibilityDescription: nil) {
                let pointSize = rect.width * 0.48
                let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
                let sym = baseSym.withSymbolConfiguration(config) ?? baseSym

                // Render white symbol onto an offscreen layer and composite
                let symSize = sym.size
                let symRect = NSRect(
                    x: rect.midX - symSize.width / 2.0,
                    y: rect.midY - symSize.height / 2.0,
                    width: symSize.width,
                    height: symSize.height
                )

                let symLayer = NSImage(size: size)
                symLayer.lockFocus()
                sym.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                NSColor.white.setFill()
                NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
                symLayer.unlockFocus()

                symLayer.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
