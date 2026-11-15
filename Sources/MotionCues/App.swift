// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import ServiceManagement

@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--auto-test") {
            exit(AutoTest.run() ? 0 : 1)
        }
        if let i = args.firstIndex(of: "--render-demo"), i + 1 < args.count {
            RenderTest.renderDemo(outputDirectory: args[i + 1])
            return
        }
        if let i = args.firstIndex(of: "--render-test"), i + 1 < args.count {
            RenderTest.run(outputDirectory: args[i + 1])
            return
        }
        let app = NSApplication.shared
        let controller = AppController()
        app.delegate = controller
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        app.run()
    }
}

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let sensor = SPUSensor()
    private let processor = MotionProcessor()
    private let overlay = OverlayController()

    private var statusItem: NSStatusItem!
    private var sensorRunning = false
    private var autoTimer: Timer?
    private var quietSince: TimeInterval?
    private var autoActive = false

    // Synthetic motion for "Test Motion".
    private var simulation: (start: TimeInterval, profile: (Double) -> MotionCue?)?

    // Automatic mode turns on only on sustained vehicle-like motion (see
    // MotionProcessor.vehicleMotionDetected), and off after three minutes without motion,
    // so the dots survive red lights, traffic jams and station stops.
    private let autoOffThreshold = 0.014   // g of smoothed activity that still counts as moving
    private let autoOffDelay: TimeInterval = 180

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        applyOrientation()
        sensor.onReading = { [weak self] in self?.processor.process($0) }
        sensorRunning = sensor.start()
        if !sensorRunning { NSLog("MotionCues: motion sensor unavailable") }

        overlay.cueProvider = { [weak self] in self?.currentCue() ?? MotionCue() }

        NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyOrientation()
            self?.updateVisibility()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            SPUSensor.enableReporting()
            self?.processor.reset()
        }

        autoTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }

        let args = CommandLine.arguments
        if args.contains("--log") { startLogging() }
        // Debug: `--simulate drive|speedup|brake|left|right` plays a synthetic motion on launch.
        if let i = args.firstIndex(of: "--simulate"), i + 1 < args.count {
            let profiles: [String: (Double) -> MotionCue?] = [
                "drive": Self.drive, "speedup": Self.pulse(forward: 0.18), "brake": Self.pulse(forward: -0.25),
                "left": Self.pulse(lateral: -0.15, yaw: 25), "right": Self.pulse(lateral: 0.15, yaw: -25),
            ]
            if let profile = profiles[args[i + 1]] { simulate(profile) }
        }
        updateVisibility()
    }

    // MARK: - State

    private func applyOrientation() {
        processor.invertForward = settings.invertForward
        processor.invertLateral = settings.invertLateral
        processor.invertTurn = settings.invertTurn
    }

    private func currentCue() -> MotionCue {
        if let sim = simulation {
            if let cue = sim.profile(ProcessInfo.processInfo.systemUptime - sim.start) { return cue }
            simulation = nil
            DispatchQueue.main.async { self.updateVisibility() }
            return MotionCue()
        }
        return processor.cue
    }

    private func tick() {
        guard settings.mode == .automatic else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if processor.vehicleMotionDetected {
            quietSince = nil
            autoActive = true
        } else if autoActive, !processor.isStill, processor.activity > autoOffThreshold {
            quietSince = nil // still moving along
        } else {
            if quietSince == nil { quietSince = now }
            if let q = quietSince, now - q > autoOffDelay { autoActive = false }
        }
        updateVisibility()
    }

    private func updateVisibility() {
        let visible: Bool
        if simulation != nil {
            visible = true
        } else {
            switch settings.mode {
            case .off: visible = false
            case .on: visible = true
            case .automatic: visible = autoActive && sensorRunning
            }
        }
        overlay.setVisible(visible)
        updateIcon(active: visible)
    }

    private func updateIcon(active: Bool) {
        guard statusItem.button?.image == nil else { return }
        let image = NSImage(systemSymbolName: "car.fill", accessibilityDescription: "Motion Cues")
        image?.isTemplate = true // adapts to light/dark menu bars
        statusItem.button?.image = image
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(disabled("Show Motion Cues"))
        for mode in DisplayMode.allCases {
            let item = action(mode.title) { [weak self] in self?.settings.mode = mode }
            item.state = settings.mode == mode ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }
        menu.addItem(.separator())

        // Everything else lives under Advanced.
        let advanced = NSMenuItem(title: "Advanced", action: nil, keyEquivalent: "")
        let adv = NSMenu()

        if settings.color.isAdaptive, !ScreenSampler.hasPermission {
            adv.addItem(action("Allow Screen Recording (adaptive colors)…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            })
            adv.addItem(action("Relaunch Motion Cues") {
                let path = Bundle.main.bundleURL.path
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/sh")
                task.arguments = ["-c", "sleep 0.5; open \"\(path)\""]
                try? task.run()
                NSApp.terminate(nil)
            })
            adv.addItem(.separator())
        }

        adv.addItem(submenu("Dot Size", DotSize.allCases, current: settings.dotSize, title: \.title) { self.settings.dotSize = $0 })
        adv.addItem(submenu("Dot Density", DotDensity.allCases, current: settings.density, title: \.title) { self.settings.density = $0 })
        adv.addItem(submenu("Dot Color", DotColor.allCases, current: settings.color, title: \.title) { self.settings.color = $0 })
        adv.addItem(submenu("Dot Opacity", DotOpacity.allCases, current: settings.opacity, title: \.title) { self.settings.opacity = $0 })
        adv.addItem(submenu("Sensitivity", Sensitivity.allCases, current: settings.sensitivity, title: \.title) { self.settings.sensitivity = $0 })

        let direction = NSMenuItem(title: "Direction", action: nil, keyEquivalent: "")
        let dirMenu = NSMenu()
        dirMenu.addItem(action("Calibrate…") { [weak self] in self?.calibrate() })
        dirMenu.addItem(.separator())
        let f = action("Invert Front/Back") { [weak self] in self?.settings.invertForward.toggle() }
        f.state = settings.invertForward ? .on : .off
        let l = action("Invert Left/Right") { [weak self] in self?.settings.invertLateral.toggle() }
        l.state = settings.invertLateral ? .on : .off
        let t = action("Invert Turns") { [weak self] in self?.settings.invertTurn.toggle() }
        t.state = settings.invertTurn ? .on : .off
        [f, l, t].forEach(dirMenu.addItem)
        direction.submenu = dirMenu
        adv.addItem(direction)

        let test = NSMenuItem(title: "Test Motion", action: nil, keyEquivalent: "")
        let testMenu = NSMenu()
        testMenu.addItem(action("Speed Up") { [weak self] in self?.simulate(Self.pulse(forward: 0.18)) })
        testMenu.addItem(action("Brake") { [weak self] in self?.simulate(Self.pulse(forward: -0.25)) })
        testMenu.addItem(action("Turn Left") { [weak self] in self?.simulate(Self.pulse(lateral: -0.15, yaw: 25)) })
        testMenu.addItem(action("Turn Right") { [weak self] in self?.simulate(Self.pulse(lateral: 0.15, yaw: -25)) })
        testMenu.addItem(action("Stop-and-Go Drive") { [weak self] in self?.simulate(Self.drive) })
        test.submenu = testMenu
        adv.addItem(test)

        advanced.submenu = adv
        menu.addItem(advanced)

        if Bundle.main.bundleIdentifier != nil {
            menu.addItem(.separator())
            let login = action("Launch at Login") {
                let service = SMAppService.mainApp
                do {
                    if service.status == .enabled { try service.unregister() } else { try service.register() }
                } catch { NSLog("MotionCues: login item error \(error)") }
            }
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
        }

        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        menu.addItem(disabled("Motion Cues \(version)"))
        menu.addItem(action("Check for Updates…") {
            NSWorkspace.shared.open(URL(string: "https://github.com/Spandan2022/MacOS_Motion_Cues/releases/latest")!)
        })
        menu.addItem(NSMenuItem(title: "Quit Motion Cues", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, handler: handler)
        return item
    }

    private func submenu<T: Equatable>(_ title: String, _ options: [T], current: T, title optionTitle: KeyPath<T, String>,
                                       set: @escaping (T) -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for option in options {
            let o = action(option[keyPath: optionTitle]) { set(option) }
            o.state = option == current ? .on : .off
            sub.addItem(o)
        }
        item.submenu = sub
        return item
    }

    // MARK: - Test motion

    private func simulate(_ profile: @escaping (Double) -> MotionCue?) {
        simulation = (ProcessInfo.processInfo.systemUptime, profile)
        updateVisibility()
    }

    /// A 2.5 s push followed by 1.5 s of settling.
    static func pulse(forward: Double = 0, lateral: Double = 0, yaw: Double = 0) -> (Double) -> MotionCue? {
        { t in
            guard t < 4 else { return nil }
            let on = t < 2.5 ? 1.0 : 0.0
            return MotionCue(forward: forward * on, lateral: lateral * on, yawRate: yaw * on)
        }
    }

    static let drive: (Double) -> MotionCue? = { t in
        guard t < 16 else { return nil }
        switch t {
        case ..<3: return MotionCue(forward: 0.15)
        case ..<5: return MotionCue()
        case ..<8: return MotionCue(lateral: -0.12, yawRate: 20)
        case ..<10: return MotionCue()
        case ..<12: return MotionCue(lateral: 0.12, yawRate: -20)
        case ..<14: return MotionCue(forward: -0.25)
        default: return MotionCue()
        }
    }

    // MARK: - Calibration

    private struct CalibrationStep {
        let instruction: String
        let measure: (MotionProcessor) -> Double
        let apply: (Settings, Bool) -> Void
        let threshold: Double
        let integrate: Bool
    }

    private func calibrate() {
        guard sensorRunning else {
            alert("Motion sensor unavailable", "This Mac's motion sensor couldn't be read, so calibration isn't possible.")
            return
        }
        let steps = [
            CalibrationStep(instruction: "Put the laptop on a table. After clicking Start, slide it briskly AWAY from you (about 10 cm), then stop.",
                            measure: { $0.rawForward }, apply: { $0.invertForward = $1 }, threshold: 0.05, integrate: false),
            CalibrationStep(instruction: "After clicking Start, slide the laptop briskly to your RIGHT (about 10 cm), then stop.",
                            measure: { $0.rawLateral }, apply: { $0.invertLateral = $1 }, threshold: 0.05, integrate: false),
            CalibrationStep(instruction: "After clicking Start, rotate the laptop on the table to the LEFT (counter-clockwise, about a quarter turn).",
                            measure: { $0.rawYaw }, apply: { $0.invertTurn = $1 }, threshold: 15, integrate: true),
        ]
        runCalibration(steps, index: 0, results: [])
    }

    private func runCalibration(_ steps: [CalibrationStep], index: Int, results: [String]) {
        guard index < steps.count else {
            alert("Calibration complete", results.joined(separator: "\n"))
            return
        }
        let step = steps[index]
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Calibrate Direction (\(index + 1) of \(steps.count))"
        a.informativeText = step.instruction + "\n\nYou'll have 3 seconds."
        a.addButton(withTitle: "Start")
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }

        // Sample for 3 s: take the sign of the first strong reading (slides) or the integral (turns).
        var sign: Double?
        var integral = 0.0
        let start = ProcessInfo.processInfo.systemUptime
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let v = step.measure(self.processor)
            if step.integrate {
                integral += v * 0.01
            } else if sign == nil, abs(v) > step.threshold {
                sign = v > 0 ? 1 : -1
            }
            guard ProcessInfo.processInfo.systemUptime - start > 3 else { return }
            timer.invalidate()
            if step.integrate, abs(integral) > step.threshold { sign = integral > 0 ? 1 : -1 }
            let names = ["Front/back", "Left/right", "Turns"]
            var results = results
            if let sign {
                step.apply(self.settings, sign < 0)
                results.append("\(names[index]): \(sign < 0 ? "inverted" : "normal")")
                self.runCalibration(steps, index: index + 1, results: results)
            } else {
                self.retry(steps, index: index, results: results)
            }
        }
    }

    private func retry(_ steps: [CalibrationStep], index: Int, results: [String]) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "No clear movement detected"
        a.informativeText = "Try again with a quicker, firmer motion."
        a.addButton(withTitle: "Try Again")
        a.addButton(withTitle: "Cancel")
        if a.runModal() == .alertFirstButtonReturn { runCalibration(steps, index: index, results: results) }
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }

    // MARK: - Debug logging

    private func startLogging() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            let c = self.processor.cue
            print(String(format: "fwd %+.3f  lat %+.3f  yaw %+6.1f | raw f %+.3f l %+.3f y %+6.1f | linear %.3f vib %.4f activity %.4f sign %+.0f auto %@ | aN %.4f gN %.3f still %@ evidence %.1f busy %.2f",
                         c.forward, c.lateral, c.yawRate, self.processor.rawForward, self.processor.rawLateral,
                         self.processor.rawYaw, self.processor.rawLinear, self.processor.vibration, self.processor.activity, self.processor.gyroSign, self.autoActive ? "on" : "off", self.processor.accelNoise, self.processor.gyroNoise, self.processor.isStill ? "Y" : "n", self.processor.motionEvidence, self.processor.vibrationBusy))
            fflush(stdout)
        }
    }
}

/// NSMenuItem that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
