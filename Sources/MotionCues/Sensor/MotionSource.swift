// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A 3-axis vector in the sensor's own frame.
struct Vec3 {
    var x: Double, y: Double, z: Double

    static let zero = Vec3(x: 0, y: 0, z: 0)

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vec3, s: Double) -> Vec3 { Vec3(x: a.x * s, y: a.y * s, z: a.z * s) }

    func dot(_ b: Vec3) -> Double { x * b.x + y * b.y + z * b.z }
    func cross(_ b: Vec3) -> Vec3 {
        Vec3(x: y * b.z - z * b.y, y: z * b.x - x * b.z, z: x * b.y - y * b.x)
    }
    var length: Double { dot(self).squareRoot() }
    var normalized: Vec3 { let l = length; return l > 1e-9 ? self * (1 / l) : .zero }
}

/// Raw readings delivered by a motion source.
enum MotionReading {
    /// Accelerometer, in g (includes gravity).
    case accel(Vec3, TimeInterval)
    /// Gyroscope, in degrees per second.
    case gyro(Vec3, TimeInterval)
}

protocol MotionSource: AnyObject {
    var onReading: ((MotionReading) -> Void)? { get set }
    /// Returns false if the source could not be started.
    func start() -> Bool
    func stop()
}
