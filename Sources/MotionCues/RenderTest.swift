// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Debug helper: renders the dots offscreen and saves PNGs.
/// Usage: MotionCues --render-test <dir>
enum RenderTest {
    static func run(outputDirectory: String) {
        let size = CGSize(width: 900, height: 580)
        // Left half: bright page with a mid-grey band. Right half: dark.
        let cases: [(String, MotionCue, DotColor)] = [
            ("rest-white", MotionCue(), .white),
            ("hard-brake-white", MotionCue(forward: -0.35), .white),
            ("turn-left-yellow", MotionCue(lateral: -0.2, yawRate: 30), .yellow),
            ("rest-black", MotionCue(), .black),
        ]
        for (name, cue, color) in cases {
            let view = DotsView(frame: CGRect(origin: .zero, size: size))
            view.colorOverride = color
            for _ in 0..<60 { view.advance(by: 1.0 / 60, cue: cue) } // 1 s

            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            NSGraphicsContext.saveGraphicsState()
            let ctx = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.current = ctx
            NSColor(white: 0.97, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: size.width / 2, height: size.height).fill()
            NSColor(white: 0.5, alpha: 1).setFill()
            CGRect(x: 0, y: 380, width: size.width / 2, height: 80).fill()
            NSColor(white: 0.06, alpha: 1).setFill()
            CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height).fill()
            view.layer!.render(in: ctx.cgContext)
            NSGraphicsContext.restoreGraphicsState()
            let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(name).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            print("wrote", url.path)
        }
    }

    /// Renders PNG frames of the Stop-and-Go Drive test over a mock screen (light document on
    /// the left, dark photo on the right) for the README demo GIF.
    /// Usage: MotionCues --render-demo <dir>
    static func renderDemo(outputDirectory: String) {
        let size = CGSize(width: 960, height: 600)
        let split = size.width * 0.5
        // Text lines on the light document, as (y, height) bands.
        let lines: [(CGFloat, CGFloat)] = stride(from: 470, to: 60, by: -34).map { (CGFloat($0), 10) }
        func drawBackground() {
            NSColor(white: 0.96, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: split, height: size.height).fill()
            NSColor(white: 0.35, alpha: 1).setFill()
            for (i, line) in lines.enumerated() {
                let width = (split - 110) * (i % 4 == 3 ? 0.6 : 1)
                NSBezierPath(roundedRect: CGRect(x: 70, y: line.0, width: width, height: line.1), xRadius: 4, yRadius: 4).fill()
            }
            NSGradient(starting: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.12, alpha: 1),
                       ending: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.30, alpha: 1))!
                .draw(in: CGRect(x: split, y: 0, width: size.width - split, height: size.height), angle: 90)
        }

        let view = DotsView(frame: CGRect(origin: .zero, size: size))
        view.rebuildDots()
        let fps = 20.0
        var frame = 0
        var t = 0.0
        while let cue = AppController.drive(t) {
            for _ in 0..<3 { view.advance(by: 1.0 / 60, cue: cue) }
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            NSGraphicsContext.saveGraphicsState()
            let ctx = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.current = ctx
            drawBackground()
            view.layer!.render(in: ctx.cgContext)
            NSGraphicsContext.restoreGraphicsState()
            let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(String(format: "frame_%04d.png", frame))
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            frame += 1
            t += 1 / fps
        }
        print("wrote \(frame) frames to \(outputDirectory)")
    }
}
