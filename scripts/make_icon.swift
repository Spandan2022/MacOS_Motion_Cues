// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

// Renders Resources/AppIcon.icns: the SF Symbol car.fill in white on a blue rounded-square tile.
// Run: swift scripts/make_icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024

    // Apple's macOS icon grid: 824×824 tile centered in 1024, corner radius ~185.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)

    // Soft drop shadow under the tile.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.3)
    shadow.shadowBlurRadius = 20 * s
    shadow.shadowOffset = NSSize(width: 0, height: -8 * s)
    shadow.set()
    NSColor(calibratedRed: 0.13, green: 0.40, blue: 0.92, alpha: 1).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Blue gradient, lighter at the top.
    NSGradient(starting: NSColor(calibratedRed: 0.30, green: 0.62, blue: 1.0, alpha: 1),
               ending: NSColor(calibratedRed: 0.09, green: 0.33, blue: 0.86, alpha: 1))!
        .draw(in: path, angle: -90)

    // White car.fill glyph, centered.
    let config = NSImage.SymbolConfiguration(pointSize: 420 * s, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let car = NSImage(systemSymbolName: "car.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = car.size
        let rect = NSRect(x: (CGFloat(px) - size.width) / 2, y: (CGFloat(px) - size.height) / 2 - 6 * s,
                          width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        let glyphShadow = NSShadow()
        glyphShadow.shadowColor = NSColor(white: 0, alpha: 0.18)
        glyphShadow.shadowBlurRadius = 10 * s
        glyphShadow.shadowOffset = NSSize(width: 0, height: -6 * s)
        glyphShadow.set()
        car.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try fm.createDirectory(at: root.appendingPathComponent("Resources"), withIntermediateDirectories: true)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try task.run()
task.waitUntilExit()
try render(1024).write(to: root.appendingPathComponent("build/AppIcon-preview.png"))
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
