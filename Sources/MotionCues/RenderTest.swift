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
        func background(_ p: CGPoint) -> CGFloat {
            if p.x < size.width / 2 { return p.y > 380 && p.y < 460 ? 0.5 : 0.97 }
            return 0.06
        }
        let cases: [(String, MotionCue, DotColor)] = [
            ("rest-grey", MotionCue(), .greyscale),
            ("hard-brake-grey", MotionCue(forward: -0.35), .greyscale),
            ("turn-left-yellow", MotionCue(lateral: -0.2, yawRate: 30), .yellow),
            ("rest-blue", MotionCue(), .blue),
        ]
        for (name, cue, color) in cases {
            let view = DotsView(frame: CGRect(origin: .zero, size: size))
            view.rebuildDots()
            for _ in 0..<60 { view.advance(by: 1.0 / 60, cue: cue) } // 1 s
            view.applyBackground(color, background)

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
        func lum(_ p: CGPoint) -> CGFloat {
            if p.x >= split { return 0.08 + 0.10 * (p.y / size.height) }
            if p.x > 70, p.x < split - 40, lines.contains(where: { p.y >= $0.0 && p.y <= $0.0 + $0.1 }) { return 0.35 }
            return 0.96
        }
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
            view.applyBackground(.greyscale, lum)
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
