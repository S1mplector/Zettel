#!/usr/bin/env swift

import AppKit
import Foundation

enum IconGenerationError: LocalizedError {
    case missingOutputPath
    case failedToEncodePNG(String)
    case iconutilFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .missingOutputPath:
            return "Missing output path. Usage: generate-app-icon.swift /path/to/Zettel.icns"
        case .failedToEncodePNG(let name):
            return "Failed to encode PNG for \(name)."
        case .iconutilFailed(let status):
            return "iconutil failed with status \(status)."
        }
    }
}

let iconName = "tree"
let fileManager = FileManager.default

func makeIconImage(size: CGFloat) -> NSImage {
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
    let symbolImage = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
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

func writePNG(named name: String, size: CGFloat, to directoryURL: URL) throws {
    let image = makeIconImage(size: size)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconGenerationError.failedToEncodePNG(name)
    }

    try pngData.write(to: directoryURL.appendingPathComponent(name), options: [.atomic])
}

guard CommandLine.arguments.count >= 2 else {
    throw IconGenerationError.missingOutputPath
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
let iconsetURL = tempDirectoryURL.appendingPathComponent("Zettel.iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in iconFiles {
    try writePNG(named: name, size: size, to: iconsetURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: tempDirectoryURL)

guard process.terminationStatus == 0 else {
    throw IconGenerationError.iconutilFailed(process.terminationStatus)
}
