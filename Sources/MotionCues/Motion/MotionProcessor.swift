// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The motion the dots should react to, in the vehicle's horizontal plane.
struct MotionCue {
    /// Forward acceleration of the vehicle in g (positive = speeding up, negative = braking).
    var forward: Double = 0
    /// Sideways acceleration of the vehicle in g (positive = toward the right, e.g. a right turn).
    var lateral: Double = 0
    /// Turn rate in degrees per second (positive = turning left).
    var yawRate: Double = 0
}

/// Turns raw accelerometer and gyro readings into vehicle motion.
///
/// Gravity is tracked by sensor fusion: the gyro rotates the gravity estimate as the laptop
/// tilts, and the accelerometer only nudges it back slowly (~12 s). This means a train that
/// speeds up or slows down gently for many seconds still registers, instead of being
/// absorbed into "gravity" within a second or two.
///
/// The gyro's sign convention isn't documented, so it is learned automatically: whenever
/// the laptop is tilted, the app checks which direction of rotation explains the change in
/// measured gravity. The result is saved. Until it's known, a shorter filter is used.
///
/// The remaining acceleration is projected onto the horizontal plane: the sensor's x axis
/// (along the keyboard width) gives left/right, and the axis perpendicular to it and to
/// gravity gives front/back.
final class MotionProcessor {
    private(set) var cue = MotionCue()
    /// Combined level of vehicle-like motion (g-equivalent), used for automatic mode.
    private(set) var activity: Double = 0
    /// Low-frequency horizontal acceleration magnitude (debugging).
    private(set) var rawLinear: Double = 0
    /// Vibration level above the sensor noise floor (debugging).
    private(set) var vibration: Double = 0
    /// +1 / -1 once the gyro's sign convention has been learned, 0 before.
    private(set) var gyroSign: Double
    /// High-frequency noise levels, used to detect when the laptop is perfectly still.
    private(set) var accelNoise: Double = 0
    private(set) var gyroNoise: Double = 0
    private var gyroLowPass = Vec3.zero
    private var gyroNoisePower: Double = 0
    /// Seconds the laptop has been perfectly still (no vibration, no rotation).
    private var stillTime: Double = 0
    var isStill: Bool { stillTime > 1.5 }

    /// Seconds of sustained, vehicle-like acceleration (for Automatic mode).
    private(set) var motionEvidence: Double = 0
    /// True once there's been a few seconds of steady acceleration, braking or turning
    /// without the laptop being handled — e.g. a car pulling away, not someone walking.
    var vehicleMotionDetected: Bool { motionEvidence >= requiredEvidence }
    private var sustained = (f: 0.0, l: 0.0)
    private var handlingCooldown: Double = 0
    /// Seconds since the first sample; gravity locks on quickly at first, and Automatic waits.
    private var uptime: Double = 0

    private var gravity: Vec3?
    private var lastAccelTime: TimeInterval?
    private var lastGyroTime: TimeInterval?
    /// Latest bias-corrected rotation rate, rad/s.
    private var omega = Vec3.zero
    /// Rate of rotation around horizontal axes (deg/s), smoothed.
    private var tiltRate: Double = 0
    private var gyroBias = Vec3.zero
    private var filtered = (f: 0.0, l: 0.0)
    /// Recent samples for the spike-rejecting median filter.
    private var recentF: [Double] = []
    private var recentL: [Double] = []
    private let medianWindow = 7          // samples (70 ms at 100 Hz → ~35 ms delay)
    private var smoothAccel: Vec3?
    private var signScore: Double = 0
    private var magnitudeMean: Double = 1
    private var vibrationPower: Double = 0

    // Tuning
    private let fusedGravityTau = 12.0    // s; accel correction when the gyro is tracking tilt
    private let plainGravityTau = 3.0     // s; before the gyro sign is known
    private let handlingGravityTau = 0.4  // s; while the laptop is clearly being moved
    private let tiltThreshold = 20.0      // deg/s of tilting that counts as "laptop being moved"
    private let prefilterTau = 0.1        // s; removes sensor noise (short, for low lag)
        private let deadZone = 0.008          // g; below this (typing, desk bumps) the dots stay still
    private let yawDeadZone = 0.8         // deg/s
    private let activityTau = 2.0         // s
    private let vibrationFloor = 0.02     // g RMS of sensor noise at rest (measured ~0.018)

    private static let signKey = "gyroPropagationSign"

    // Stillness (measured at rest: accel noise ≤ 0.005 g, gyro noise ≤ 0.75 °/s).
    private let stillAccelNoise = 0.008
    private let stillGyroNoise = 1.5
    // Automatic-mode trigger.
    private let requiredEvidence = 2.5      // s of sustained motion
    private let sustainedThreshold = 0.035  // g of steady horizontal acceleration
    private let walkingTilt = 8.0           // °/s of tilting = laptop being carried/handled
    private let walkingJolts = 0.08         // g RMS of jolts = footsteps

    var invertForward = false
    var invertLateral = false
    var invertTurn = false

    /// Unsmoothed, un-inverted values, used by calibration.
    private(set) var rawForward: Double = 0
    private(set) var rawLateral: Double = 0
    private(set) var rawYaw: Double = 0

    /// - Parameter learnedGyroSign: override the saved gyro sign (tests pass 0 = not yet learned).
    init(learnedGyroSign: Double? = nil) {
        gyroSign = learnedGyroSign ?? UserDefaults.standard.double(forKey: Self.signKey)
    }

    func reset() {
        gravity = nil
        smoothAccel = nil
        lastAccelTime = nil
        lastGyroTime = nil
        cue = MotionCue()
        filtered = (0, 0)
        sustained = (0, 0)
        motionEvidence = 0
        stillTime = 0
        uptime = 0
        recentF.removeAll()
        recentL.removeAll()
        activity = 0
    }

    func process(_ reading: MotionReading) {
        switch reading {
        case let .accel(a, t): processAccel(a, t)
        case let .gyro(g, t): processGyro(g, t)
        }
    }

    private static func alpha(_ dt: Double, _ tau: Double) -> Double { 1 - exp(-dt / tau) }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func softDeadZone(_ v: Double, _ dz: Double) -> Double {
        let m = abs(v) - dz
        return m > 0 ? (v < 0 ? -m : m) : 0
    }

    private func processAccel(_ a: Vec3, _ t: TimeInterval) {
        guard var g = gravity, let last = lastAccelTime, let s0 = smoothAccel else {
            gravity = a
            smoothAccel = a
            lastAccelTime = t
            return
        }
        let dt = min(max(t - last, 0), 0.1)
        lastAccelTime = t
        guard dt > 0 else { return }
        uptime += dt

        let handling = tiltRate > tiltThreshold

        // Learn the gyro sign: does gravity in the sensor frame turn as g×ω or as ω×g?
        let s1 = s0 + (a - s0) * Self.alpha(dt, 0.05)
        smoothAccel = s1
        if gyroSign == 0 {
            let observed = (s1 - s0) * (1 / dt)
            let predicted = s1.cross(omega)
            if predicted.length > 0.15, observed.length > 0.1 {
                signScore += observed.dot(predicted) / (observed.length * predicted.length) * dt * 10
                if abs(signScore) > 15 {
                    gyroSign = signScore > 0 ? 1 : -1
                    UserDefaults.standard.set(gyroSign, forKey: Self.signKey)
                }
            }
        }

        // Rotate gravity with the gyro, then correct slowly toward the accelerometer.
        if gyroSign != 0 {
            g = g + g.cross(omega) * (gyroSign * dt)
        }
        // When perfectly still, lock gravity to the accelerometer: this removes the slow drift
        // that a tiny gyro bias would otherwise add to the fused estimate.
        // Otherwise correct slowly. Before the gyro's sign is known we can't follow tilts with
        // it, but if it shows no rotation at all, gravity can't have moved, so slow is still safe.
        let tau: Double
        if uptime < 1 { tau = 0.2 }                       // warm-up: lock on fast
        else if isStill { tau = 0.3 }
        else if handling { tau = handlingGravityTau }
        else if gyroSign != 0 || tiltRate < 2 { tau = fusedGravityTau }
        else { tau = plainGravityTau }
        g = g + (a - g) * Self.alpha(dt, tau)
        gravity = g

        let up = g.normalized
        let xAxis = Vec3(x: 1, y: 0, z: 0)
        let lateralAxis = (xAxis - up * up.x).normalized
        let forwardAxis = up.cross(lateralAxis).normalized

        let linear = a - g
        var fwd = linear.dot(forwardAxis)
        var lat = linear.dot(lateralAxis)
        rawForward = fwd
        rawLateral = lat
        if invertForward { fwd = -fwd }
        if invertLateral { lat = -lat }

        // Median first: removes short jolts (keystrokes, taps) without the lag of heavy smoothing.
        recentF.append(fwd); recentL.append(lat)
        if recentF.count > medianWindow { recentF.removeFirst(); recentL.removeFirst() }
        let kf = Self.alpha(dt, prefilterTau)
        filtered.f += (Self.median(recentF) - filtered.f) * kf
        filtered.l += (Self.median(recentL) - filtered.l) * kf
        let horizontal = (filtered.f * filtered.f + filtered.l * filtered.l).squareRoot()
        rawLinear = horizontal

        // Vibration: fast fluctuation of total acceleration (road, rails, engine).
        let mag = a.length
        magnitudeMean += (mag - magnitudeMean) * Self.alpha(dt, 0.3)
        let hp = mag - magnitudeMean
        vibrationPower += (hp * hp - vibrationPower) * Self.alpha(dt, 1.5)
        accelNoise = vibrationPower.squareRoot()
        vibration = max(0, accelNoise - vibrationFloor)

        // While the laptop itself is being handled, don't feed the dots or auto-detection.
        cue.forward = handling ? 0 : Self.softDeadZone(filtered.f, deadZone)
        cue.lateral = handling ? 0 : Self.softDeadZone(filtered.l, deadZone)
        if !handling {
            let level = horizontal + abs(cue.yawRate) / 200 + vibration * 0.8
            activity += (level - activity) * Self.alpha(dt, activityTau)
        }
        updateMotionEvidence(dt)
    }

    /// Builds up evidence of real vehicle motion: steady acceleration in one direction (or a
    /// steady turn) lasting a few seconds. Walking around with the laptop doesn't count: steps
    /// are back-and-forth jolts that average out, and carrying the laptop tilts it.
    private func updateMotionEvidence(_ dt: Double) {
        let k = Self.alpha(dt, 1.5)
        sustained.f += (filtered.f - sustained.f) * k
        sustained.l += (filtered.l - sustained.l) * k

        if tiltRate > walkingTilt || accelNoise > walkingJolts {
            // Being carried or handled: start over, and ignore the next couple of seconds.
            handlingCooldown = 2
            motionEvidence = 0
            return
        }
        if handlingCooldown > 0 || uptime < 3 {
            handlingCooldown -= dt
            return
        }
        let steady = (sustained.f * sustained.f + sustained.l * sustained.l).squareRoot()
        let turning = abs(cue.yawRate) > 6 && abs(sustained.l) > 0.02
        if (steady > sustainedThreshold || turning) && !isStill {
            motionEvidence = min(motionEvidence + dt, requiredEvidence + 1)
        } else {
            motionEvidence = max(0, motionEvidence - dt * 2)
        }
    }

    private func processGyro(_ raw: Vec3, _ t: TimeInterval) {
        let dt: Double
        if let last = lastGyroTime { dt = min(max(t - last, 0), 0.1) } else { dt = 0.02 }
        lastGyroTime = t

        // Stillness: almost no vibration and no rotation.
        if accelNoise < stillAccelNoise, gyroNoise < stillGyroNoise, (raw - gyroBias).length < 3 {
            stillTime += dt
        } else {
            stillTime = 0
        }
        // Learn the gyro bias only while still, so a long gentle curve isn't absorbed.
        if isStill {
            gyroBias = gyroBias + (raw - gyroBias) * Self.alpha(dt, 3)
        }
        gyroLowPass = gyroLowPass + (raw - gyroLowPass) * Self.alpha(dt, 0.5)
        let jitter = (raw - gyroLowPass).length
        gyroNoisePower += (jitter * jitter - gyroNoisePower) * Self.alpha(dt, 1.0)
        gyroNoise = gyroNoisePower.squareRoot()

        let w = raw - gyroBias
        omega = w * (Double.pi / 180)

        guard let g = gravity else { return }
        let up = g.normalized
        var yaw = w.dot(up)
        // Rotation around horizontal axes = the laptop being tilted or picked up.
        // Vehicle turns are pure yaw, so they don't count.
        let tilt = (w - up * yaw).length
        tiltRate += (tilt - tiltRate) * Self.alpha(dt, 0.08)
        rawYaw = yaw
        if invertTurn { yaw = -yaw }
        let target = tiltRate > tiltThreshold ? 0 : Self.softDeadZone(yaw, yawDeadZone)
        cue.yawRate += (target - cue.yawRate) * Self.alpha(dt, 0.05)
    }
}
