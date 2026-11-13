// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

enum DisplayMode: String, CaseIterable {
    case off, on, automatic
    var title: String {
        switch self {
        case .off: "Off"
        case .on: "On"
        case .automatic: "Automatic"
        }
    }
}

enum DotSize: String, CaseIterable {
    case small, medium, large
    var title: String { rawValue.capitalized }
    var points: CGFloat {
        switch self {
        case .small: 10.4
        case .medium: 13.3
        case .large: 17.8
        }
    }
}

enum DotDensity: String, CaseIterable {
    case low, medium, high
    var title: String { rawValue.capitalized }
    /// Distance between neighbouring dots in a column, as a multiple of the dot size.
    var spacingFactor: CGFloat {
        switch self {
        case .low: 15.9
        case .medium: 12.7
        case .high: 9.9
        }
    }
}

enum DotOpacity: String, CaseIterable {
    case faint, light, medium, solid
    var title: String {
        switch self {
        case .faint: "Faint (35%)"
        case .light: "Light (50%)"
        case .medium: "Medium (75%)"
        case .solid: "Solid (100%)"
        }
    }
    var value: Float {
        switch self {
        case .faint: 0.35
        case .light: 0.5
        case .medium: 0.75
        case .solid: 1
        }
    }
}

enum DotColor: String, CaseIterable {
    case greyscale, blue, yellow, green, red, purple, white, black

    var title: String {
        switch self {
        case .greyscale: "Greyscale (adaptive)"
        case .white: "White (fixed)"
        case .black: "Black (fixed)"
        default: rawValue.capitalized
        }
    }

    /// Whether the dots adapt to the background behind each one (needs screen sampling).
    var isAdaptive: Bool { self != .white && self != .black }

    /// Base hue for the colored options.
    var hue: CGFloat? {
        switch self {
        case .blue: 0.60
        case .yellow: 0.14
        case .green: 0.37
        case .red: 0.0
        case .purple: 0.78
        default: nil
        }
    }

    /// The dot's color for a background luminance (0 = black … 1 = white), or nil if unknown.
    ///
    /// Greyscale flips between light and dark tones against the background. Colored dots keep
    /// their hue: deeper and more saturated on bright backgrounds, brighter and slightly
    /// desaturated on dark ones.
    func color(onBackground lum: CGFloat?) -> NSColor {
        switch self {
        case .white: return NSColor(white: 1, alpha: 1)
        case .black: return NSColor(white: 0, alpha: 1)
        default: break
        }
        guard let lum else {
            // No screen sampling: a light tone that reads on most backgrounds.
            if let hue { return NSColor(hue: hue, saturation: 0.6, brightness: 1, alpha: 1) }
            return NSColor(white: 0.92, alpha: 1)
        }
        // 0 on dark backgrounds → 1 on bright ones, with a short crossover around mid-grey.
        let c = min(max((lum - 0.46) / 0.08, 0), 1)
        let t = c * c * (3 - 2 * c)
        if let hue {
            let saturation = 0.5 + 0.5 * t
            let brightness = 1.0 - 0.45 * t
            // Yellow drifts toward amber when deepened, like iOS.
            let h = self == .yellow ? hue - 0.04 * t : hue
            return NSColor(hue: h, saturation: saturation, brightness: brightness, alpha: 1)
        }
        let onDark = min(0.95, max(0.85, lum + 0.5))
        let onBright = min(0.38, max(0.18, lum - 0.55))
        return NSColor(white: onDark + (onBright - onDark) * t, alpha: 1)
    }
}

enum Sensitivity: String, CaseIterable {
    case low, medium, high, max
    var title: String { rawValue.capitalized }
    var gain: Double {
        switch self {
        case .low: 0.6
        case .medium: 1.0
        case .high: 1.6
        case .max: 2.5
        }
    }
}

/// User preferences, persisted in UserDefaults. Observers are notified on any change.
final class Settings {
    static let shared = Settings()

    static let didChange = Notification.Name("MotionCuesSettingsDidChange")

    private let defaults = UserDefaults.standard

    private func value<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
        defaults.string(forKey: key).flatMap(T.init(rawValue:)) ?? fallback
    }

    private func set<T: RawRepresentable>(_ key: String, _ newValue: T) where T.RawValue == String {
        defaults.set(newValue.rawValue, forKey: key)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    var mode: DisplayMode {
        get { value("mode", .automatic) }
        set { set("mode", newValue) }
    }
    var dotSize: DotSize {
        get { value("dotSize", .medium) }
        set { set("dotSize", newValue) }
    }
    var density: DotDensity {
        get { value("density", .medium) }
        set { set("density", newValue) }
    }
    var color: DotColor {
        get { value("color", .greyscale) }
        set { set("color", newValue) }
    }
    var opacity: DotOpacity {
        get { value("opacity", .medium) }
        set { set("opacity", newValue) }
    }
    var sensitivity: Sensitivity {
        get { value("sensitivity", .medium) }
        set { set("sensitivity", newValue) }
    }
    var invertForward: Bool {
        get { defaults.bool(forKey: "invertForward") }
        set { defaults.set(newValue, forKey: "invertForward"); NotificationCenter.default.post(name: Self.didChange, object: self) }
    }
    var invertTurn: Bool {
        get { defaults.bool(forKey: "invertTurn") }
        set { defaults.set(newValue, forKey: "invertTurn"); NotificationCenter.default.post(name: Self.didChange, object: self) }
    }
    var invertLateral: Bool {
        get { defaults.bool(forKey: "invertLateral") }
        set { defaults.set(newValue, forKey: "invertLateral"); NotificationCenter.default.post(name: Self.didChange, object: self) }
    }
}
