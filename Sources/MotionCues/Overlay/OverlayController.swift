// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// One transparent, click-through window per screen that floats above everything,
/// including full-screen apps, and hosts the dots.
final class OverlayController {
    var cueProvider: () -> MotionCue = { MotionCue() }

    private var windows: [NSWindow] = []
    private var samplers: [ScreenSampler] = []
    private(set) var isVisible = false

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildWindows() }
        NotificationCenter.default.addObserver(
            forName: Settings.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.updateSamplers()
            self.windows.forEach { ($0.contentView as? DotsView)?.rebuildDots() }
        }
    }

    func setVisible(_ visible: Bool, animated: Bool = true) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible {
            rebuildWindows()
            windows.forEach { $0.alphaValue = 0 }
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = animated ? 0.6 : 0
            windows.forEach { $0.animator().alphaValue = visible ? 1 : 0 }
        }, completionHandler: { [weak self] in
            guard let self, !self.isVisible else { return }
            self.tearDown()
        })
    }

    private func rebuildWindows() {
        guard isVisible else { return }
        let alpha = windows.first?.alphaValue ?? 1
        tearDown()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            // Keep the dots out of screenshots and screen sharing.
            // (Set MOTIONCUES_CAPTURABLE=1 to allow capturing them, e.g. for testing.)
            window.sharingType = ProcessInfo.processInfo.environment["MOTIONCUES_CAPTURABLE"] == nil ? .none : .readOnly
            window.setFrame(screen.frame, display: false)

            let view = DotsView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.cueProvider = { [weak self] in self?.cueProvider() ?? MotionCue() }
            window.contentView = view
            window.alphaValue = alpha
            window.orderFrontRegardless()
            windows.append(window)
        }
        updateSamplers()
    }

    /// Starts one background sampler per screen when the color mode adapts to the background.
    private func updateSamplers() {
        samplers.forEach { $0.stop() }
        samplers.removeAll()
        guard isVisible, Settings.shared.color.isAdaptive else {
            windows.forEach { ($0.contentView as? DotsView)?.sampler = nil }
            return
        }
        ScreenSampler.requestPermissionIfNeeded()
        for window in windows {
            guard let view = window.contentView as? DotsView,
                  let number = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { continue }
            let sampler = ScreenSampler(displayID: CGDirectDisplayID(number.uint32Value))
            sampler.start()
            view.sampler = sampler
            samplers.append(sampler)
        }
    }

    private func tearDown() {
        samplers.forEach { $0.stop() }
        samplers.removeAll()
        for window in windows {
            (window.contentView as? DotsView)?.stopAnimating()
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}
