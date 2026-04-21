import AppKit

enum AppVisualIdentity {
    static let symbolName = "tree"

    static func applicationIconImage(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        let inset = size * 0.08
        let cardRect = rect.insetBy(dx: inset, dy: inset)
        let cornerRadius = size * 0.22

        NSGraphicsContext.current?.imageInterpolation = .high

        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.48, alpha: 0.24)
        shadow.shadowBlurRadius = size * 0.06
        shadow.shadowOffset = NSSize(width: 0, height: -(size * 0.02))
        shadow.set()

        let path = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.19, green: 0.50, blue: 0.95, alpha: 1),
            NSColor(calibratedRed: 0.10, green: 0.31, blue: 0.72, alpha: 1),
        ])!
        gradient.draw(in: path, angle: -35)

        NSColor.white.withAlphaComponent(0.16).setStroke()
        path.lineWidth = max(2, size * 0.01)
        path.stroke()

        let symbolPointSize = size * 0.48
        let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: symbolPointSize, weight: .bold, scale: .large))

        let symbolSize = NSSize(width: symbolPointSize, height: symbolPointSize)
        let symbolRect = NSRect(
            x: (size - symbolSize.width) / 2,
            y: (size - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )

        NSColor.white.set()
        symbolImage?.draw(
            in: symbolRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
