// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreMedia
import ScreenCaptureKit

/// Keeps a tiny, low-frame-rate luminance map of one display (with our own dots excluded),
/// so each dot can look at the pixels directly behind it and pick a contrasting tone.
///
/// The capture is ~1/16 of the screen resolution at 8 fps, which is cheap. It needs the
/// Screen Recording permission; without it, `luminance(at:)` returns nil and the dots use
/// a fixed tone.
final class ScreenSampler: NSObject, SCStreamOutput, SCStreamDelegate {
    let displayID: CGDirectDisplayID

    // Read on the main thread only.
    private var grid: [Float] = []
    private var cols = 0
    private var rows = 0

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "MotionCues.ScreenSampler", qos: .utility)
    private var stopped = false

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
    }

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// When any sampler last received a frame (system uptime), for the menu's status line.
    static var lastFrameTime: TimeInterval = 0
    static var isReceivingFrames: Bool { ProcessInfo.processInfo.systemUptime - lastFrameTime < 3 }

    private static var didRequestThisLaunch = false

    /// Shows the system prompt at most once per launch if permission hasn't been granted.
    /// (After granting, macOS only reports it as granted once the app is relaunched, so
    /// asking again before then would just nag.)
    static func requestPermissionIfNeeded() {
        guard !didRequestThisLaunch, !CGPreflightScreenCaptureAccess() else { return }
        didRequestThisLaunch = true
        CGRequestScreenCaptureAccess()
    }

    func start() {
        guard Self.hasPermission else {
            NSLog("MotionCues: no Screen Recording permission; dots use a fixed tone")
            return
        }
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, error in
            guard let self, !self.stopped else { return }
            guard let content, let display = content.displays.first(where: { $0.displayID == self.displayID }) else {
                NSLog("MotionCues: screen sampling unavailable: \(String(describing: error))")
                return
            }
            let ourApp = content.applications.filter { $0.processID == getpid() }
            let filter = SCContentFilter(display: display, excludingApplications: ourApp, exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = max(32, display.width / 16)
            config.height = max(32, display.height / 16)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 8)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false
            config.queueDepth = 3

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)
            } catch {
                NSLog("MotionCues: addStreamOutput failed: \(error)")
                return
            }
            stream.startCapture { error in
                if let error { NSLog("MotionCues: startCapture failed: \(error)") }
            }
            DispatchQueue.main.async {
                if self.stopped { stream.stopCapture() } else { self.stream = stream }
            }
        }
    }

    func stop() {
        stopped = true
        stream?.stopCapture()
        stream = nil
    }

    /// Background luminance (0 = black … 1 = white) around a point given in
    /// normalized coordinates with the origin at the top-left. Nil until a frame arrives.
    func luminance(atX x: CGFloat, y: CGFloat) -> CGFloat? {
        guard cols > 1, rows > 1 else { return nil }
        let cx = Int((x * CGFloat(cols)).rounded(.down))
        let cy = Int((y * CGFloat(rows)).rounded(.down))
        // Average a 3×3 cell patch (≈ 48×48 screen pixels) around the dot.
        var sum: Float = 0
        var n: Float = 0
        for dy in -1...1 {
            for dx in -1...1 {
                let px = cx + dx, py = cy + dy
                guard px >= 0, py >= 0, px < cols, py < rows else { continue }
                sum += grid[py * cols + px]
                n += 1
            }
        }
        return n > 0 ? CGFloat(sum / n) : nil
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pixelBuffer = sampleBuffer.imageBuffer else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)

        var lum = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            let row = bytes + y * stride
            for x in 0..<width {
                let p = row + x * 4 // BGRA
                lum[y * width + x] = (0.0722 * Float(p[0]) + 0.7152 * Float(p[1]) + 0.2126 * Float(p[2])) / 255
            }
        }
        DispatchQueue.main.async { [weak self] in
            Self.lastFrameTime = ProcessInfo.processInfo.systemUptime
            self?.grid = lum
            self?.cols = width
            self?.rows = height
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("MotionCues: screen sampling stopped: \(error)")
    }
}
