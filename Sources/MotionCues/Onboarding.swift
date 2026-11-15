// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// First-launch guide: what the app does, and where it lives.
final class OnboardingController: NSObject, NSWindowDelegate {
    static let completedKey = "onboardingCompleted"
    static var isCompleted: Bool { UserDefaults.standard.bool(forKey: completedKey) }
    static let width: CGFloat = 640

    private var window: NSWindow?
    private let model: OnboardingModel

    init(model: OnboardingModel) {
        self.model = model
        super.init()
        model.close = { [weak self] in self?.window?.close() }
    }

    func show() {
        if window == nil {
            let host = NSHostingView(rootView: OnboardingView(model: model))
            let w = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.contentView = host
            w.delegate = self
            w.center()
            window = w
        }
        model.page = 0
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the window counts as seen; the guide is in the menu if needed again.
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }
}

final class OnboardingModel: ObservableObject {
    static let pageCount = 2

    @Published var page = 0
    var close: () -> Void = {}

    func finish() { close() }
}

/// The looping sample drive shown in the guide, with a name for each phase.
enum DemoDrive {
    static let length = 16.0
    /// Set by the page renderer to freeze the demo at one moment.
    static var fixedTime: Double?
    private static let start = ProcessInfo.processInfo.systemUptime

    static var time: Double {
        fixedTime ?? (ProcessInfo.processInfo.systemUptime - start).truncatingRemainder(dividingBy: length)
    }

    static func cue(at t: Double) -> MotionCue { AppController.drive(t) ?? MotionCue() }

    static func label(at t: Double) -> (text: String, symbol: String) {
        let c = cue(at: t)
        if c.yawRate > 1 { return ("Turning left", "arrow.turn.up.left") }
        if c.yawRate < -1 { return ("Turning right", "arrow.turn.up.right") }
        if c.forward > 0.01 { return ("Speeding up", "arrow.up") }
        if c.forward < -0.01 { return ("Braking", "arrow.down") }
        return ("Cruising", "car")
    }
}

// MARK: - Views

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    /// Gap from the laptop to the heading, and from the text to the step dots.
    static let gap: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.page {
                case 0: WelcomePage()
                default: MenuBarPage()
                }
            }
            .id(model.page)
            .transition(.opacity)

            pageDots
                .frame(maxWidth: .infinity)
                .overlay { buttons.padding(.horizontal, 20) }
                .padding(.top, Self.gap + 7) // the heading has more built-in space above its letters than the text has below
                .padding(.bottom, 30)
        }
        .padding(.top, 40)
        .frame(width: OnboardingController.width)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: model.page)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<OnboardingModel.pageCount, id: \.self) { i in
                Circle()
                    .fill(i == model.page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(model.page + 1) of \(OnboardingModel.pageCount)")
    }

    private var buttons: some View {
        HStack {
            Button("Back") { model.page -= 1 }
                .opacity(model.page > 0 ? 1 : 0)
                .disabled(model.page == 0)
            Spacer()
            if model.page < OnboardingModel.pageCount - 1 {
                Button("Continue") { model.page += 1 }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Get Started") { model.finish() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}

/// Mockup on top, then a title and two lines of text.
private struct Page<Screen: View>: View {
    let title: String
    let text: String
    @ViewBuilder let screen: () -> Screen

    var body: some View {
        VStack(spacing: 0) {
            MacBookMockup(content: screen)
                .frame(width: 560)
                .fixedSize()
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: 440)
            }
            .padding(.top, OnboardingView.gap)
        }
    }
}

// MARK: Mockup

/// A MacBook Pro frame with `content` on its screen. Content is laid out on a virtual
/// 600 × 389 pt screen and scaled to fit.
private struct MacBookMockup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    static var virtualSize: CGSize { CGSize(width: 600, height: 389) }
    // Screen area within the frame image, as fractions of its size.
    private static var screenRect: CGRect { CGRect(x: 0.10270, y: 0.02433, width: 0.79461, height: 0.85397) }

    var body: some View {
        GeometryReader { geo in
            let s = Self.screenRect
            let screen = CGRect(x: geo.size.width * s.minX, y: geo.size.height * s.minY,
                                width: geo.size.width * s.width, height: geo.size.height * s.height)
            ZStack(alignment: .topLeading) {
                content()
                    .frame(width: Self.virtualSize.width, height: Self.virtualSize.height)
                    .scaleEffect(screen.width / Self.virtualSize.width, anchor: .topLeading)
                    .frame(width: screen.width, height: screen.height, alignment: .topLeading)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
                    .offset(x: screen.minX, y: screen.minY)
                if let image = mockupFrameImage {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(1350.0 / 815.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The MacBook frame image (transparent screen), from the app bundle or a source checkout.
private let mockupFrameImage: NSImage? = {
    if let url = Bundle.main.url(forResource: "MacBookFrame", withExtension: "png") {
        return NSImage(contentsOf: url)
    }
    // Running from a source checkout (swift run / .build/debug).
    let source = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/MacBookFrame.png")
    return NSImage(contentsOf: source)
}()

/// Desktop wallpaper for the mock screen.
private struct Wallpaper: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.10, blue: 0.42), Color(red: 0.10, green: 0.22, blue: 0.62),
                                Color(red: 0.20, green: 0.16, blue: 0.48)],
                       startPoint: .top, endPoint: .bottomTrailing)
    }
}

/// The macOS menu bar with the Motion Cues car icon.
private struct MockMenuBar: View {
    /// Shows the car icon pressed, as while its menu is open.
    var selected = false

    private let ink = Color.white

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "apple.logo")
            Text("Finder").fontWeight(.bold)
            Text("File")
            Text("Edit")
            Text("View")
            Spacer()
            Image(systemName: "car.fill")
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(ink.opacity(selected ? 0.22 : 0)))
                .anchorPreference(key: CarIconAnchor.self, value: .bounds) { $0 }
            battery
            Image(systemName: "square.on.square")
            Image(systemName: "wifi")
            Image(systemName: "switch.2")
            Text("Mon 9:41")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ink)
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(Color.black.opacity(0.12))
    }

    /// The battery, as a filled badge with the percentage in it.
    private var battery: some View {
        HStack(spacing: 1) {
            Text("95")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color(red: 0.08, green: 0.14, blue: 0.48))
                .frame(width: 20, height: 11)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(ink))
            RoundedRectangle(cornerRadius: 0.75).fill(ink.opacity(0.5)).frame(width: 1.5, height: 4)
        }
    }
}

private struct CarIconAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}

/// A plain document window.
private struct MockWindow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.8)).frame(width: 7, height: 7) }
            }
            .padding(8)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Color.black.opacity(0.7)).frame(width: 150, height: 9)
                ForEach([0.95, 0.88, 0.92, 0.7, 0.9, 0.85, 0.6, 0.93, 0.8], id: \.self) { w in
                    Capsule().fill(Color.black.opacity(0.13)).frame(width: 300 * w, height: 6)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .frame(width: 360, height: 260)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}

/// The real dot overlay (`DotsView`), playing the looping demo drive.
private struct LiveDots: NSViewRepresentable {
    /// Dot scale relative to a real screen; the mock screen is small, so dots are exaggerated a bit.
    var scale: CGFloat = 0.62

    func makeNSView(context: Context) -> DotsView {
        let view = DotsView(frame: .zero)
        view.cueProvider = { DemoDrive.cue(at: DemoDrive.time) }
        view.scale = scale
        view.colorOverride = .white
        return view
    }

    func updateNSView(_ view: DotsView, context: Context) {}

    static func dismantleNSView(_ view: DotsView, coordinator: ()) { view.stopAnimating() }
}

/// Shows what the demo vehicle is doing right now.
private struct DriveLabel: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            let label = DemoDrive.label(at: DemoDrive.time)
            Label(label.text, systemImage: label.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.black.opacity(0.55)))
                .animation(.easeInOut(duration: 0.2), value: label.text)
        }
    }
}

// MARK: Pages

private struct WelcomePage: View {
    var body: some View {
        Page(title: "Welcome to Motion Cues",
             text: "Vehicle motion cues for your MacBook: work comfortably on the train, bus or car without motion sickness.") {
            ZStack {
                Wallpaper()
                VStack(spacing: 0) {
                    MockMenuBar()
                    Spacer()
                }
                MockWindow().offset(y: -4)
                LiveDots()
                VStack {
                    Spacer()
                    DriveLabel().padding(.bottom, 16)
                }
            }
        }
    }
}

private struct MenuBarPage: View {
    var body: some View {
        Page(title: "Find it in the menu bar",
             text: "Motion Cues lives in your menu bar. Click the car icon to turn the dots on or off and change settings.") {
            ZStack(alignment: .top) {
                Wallpaper()
                MockMenuBar(selected: true)
                    .overlayPreferenceValue(CarIconAnchor.self) { anchor in
                        GeometryReader { geo in
                            if let anchor {
                                let r = geo[anchor]
                                MockMenu()
                                    .offset(x: r.minX - 2, y: r.maxY + 5)
                            }
                        }
                    }
            }
        }
    }
}

/// The app's menu as macOS draws it: dark translucent panel, indented choices, gray headers.
private struct MockMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Show Motion Cues", style: .header)
            row("Off", indent: true)
            row("On", indent: true)
            row("Automatic", indent: true, checked: true)
            separator
            row("Advanced", chevron: true)
            separator
            row("Open at Login")
            row("Check for Updates…")
            row("Quit Motion Cues", shortcut: "⌘Q")
        }
        .padding(.vertical, 5)
        .frame(width: 176)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.24).opacity(0.94), Color(white: 0.18).opacity(0.94)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .font(.system(size: 11.5))
    }

    private enum Style { case normal, header }

    private func row(_ title: String, style: Style = .normal, indent: Bool = false, checked: Bool = false,
                     chevron: Bool = false, shortcut: String? = nil) -> some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if checked {
                    Image(systemName: "checkmark").font(.system(size: 9.5, weight: .semibold))
                }
            }
            .frame(width: indent ? 16 : 0, alignment: .leading)
            Text(title)
                .foregroundStyle(style == .header ? Color.white.opacity(0.38) : Color.white.opacity(0.92))
            Spacer(minLength: 8)
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .semibold))
            }
            if let shortcut {
                Text(shortcut).foregroundStyle(Color.white.opacity(0.38))
            }
        }
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 12)
        .frame(height: 21)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(height: 0.75)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

// MARK: - Debug rendering

extension OnboardingController {
    /// Renders every onboarding page to PNGs (`--render-onboarding <dir>`), for review and docs.
    static func renderPages(outputDirectory: String, appearance: NSAppearance.Name = .aqua) {
        _ = NSApplication.shared
        let model = OnboardingModel()
        let suffix = appearance == .darkAqua ? "-dark" : ""
        // Freeze the demo drive mid-turn, where the dots show the most.
        let frozen = 7.0
        DemoDrive.fixedTime = frozen
        for page in 0..<OnboardingModel.pageCount {
            model.page = page
            let view = NSHostingView(rootView: OnboardingView(model: model).transaction { $0.animation = nil })
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: view.fittingSize),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: appearance)
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            // Play the drive up to the frozen moment so the dots are mid-motion.
            for dots in view.descendants(of: DotsView.self) {
                var t = 0.0
                while t < frozen { dots.advance(by: 1.0 / 60, cue: DemoDrive.cue(at: t)); t += 1.0 / 60 }
            }
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            // The live window paints its background behind the transparent title bar; do the same here.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            view.cacheDisplay(in: view.bounds, to: rep)
            let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent("onboarding-\(page + 1)\(suffix).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            print(url.path)
        }
        DemoDrive.fixedTime = nil
    }
}

private extension NSView {
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { sub -> [T] in ((sub as? T).map { [$0] } ?? []) + sub.descendants(of: type) }
    }
}
