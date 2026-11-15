// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Feeds synthetic sensor data through MotionProcessor and checks whether Automatic mode
/// triggers when it should (vehicle motion) and not when it shouldn't (walking, typing, still).
/// Deterministic (seeded noise), so it can run in CI.
///
/// Usage: MotionCues --auto-test   (exit code 0 = all scenarios pass)
enum AutoTest {
    /// Small deterministic RNG (SplitMix64) so results are reproducible.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Returns true if every scenario behaves as expected.
    static func run() -> Bool {
        var allPassed = true
        var rng = SeededGenerator(state: 42)
        func noise(_ amp: Double) -> Double { Double.random(in: -amp...amp, using: &rng) }

        /// accel(t) in g, gyro(t) in °/s, sensor frame: gravity along -z, forward along +y.
        func scenario(_ name: String, expectTrigger: Bool, seconds: Double,
                      accel: (Double) -> Vec3, gyro: (Double) -> Vec3) {
            let p = MotionProcessor(learnedGyroSign: 0)
            var detectedAt: Double?
            var t = 0.0
            while t < seconds {
                p.process(.gyro(gyro(t), t))
                p.process(.accel(accel(t), t))
                if detectedAt == nil, p.vehicleMotionDetected { detectedAt = t }
                if ProcessInfo.processInfo.environment["AUTOTEST_TRACE"] == name, Int(t * 100) % 50 == 0 {
                    print(String(format: "  t=%.1f lin=%.4f evid=%.2f still=%@ aN=%.4f f=%.4f l=%.4f yaw=%.1f",
                                 t, p.rawLinear, p.motionEvidence, p.isStill ? "Y" : "n", p.accelNoise, p.cue.forward, p.cue.lateral, p.cue.yawRate))
                }
                t += 0.01
            }
            let result = detectedAt.map { String(format: "triggers after %.1f s", $0) } ?? "does not trigger"
            let passed = (detectedAt != nil) == expectTrigger
            allPassed = allPassed && passed
            print(passed ? "PASS" : "FAIL", name.padding(toLength: 44, withPad: " ", startingAt: 0), result)
        }

        let g = Vec3(x: 0, y: 0, z: -1)
        // Car/train: 5 s still, then gentle 0.06 g acceleration with road vibration.
        scenario("Car accelerating gently (0.06 g)", expectTrigger: true, seconds: 15, accel: { t in
            let a = t > 5 ? 0.06 : 0
            return g + Vec3(x: noise(0.02), y: a + noise(0.02), z: noise(0.02))
        }, gyro: { _ in Vec3(x: noise(1.5), y: noise(1.5), z: noise(1.5)) })

        scenario("Car turning (12°/s, 0.05 g sideways)", expectTrigger: true, seconds: 15, accel: { t in
            let a = t > 5 ? -0.05 : 0
            return g + Vec3(x: a + noise(0.02), y: noise(0.02), z: noise(0.02))
        }, gyro: { t in Vec3(x: noise(1.5), y: noise(1.5), z: (t > 5 ? -12 : 0) + noise(1.5)) })

        // Train pulling away: very gentle 0.025 g push with rail vibration, no turning.
        scenario("Train accelerating very gently (0.025 g)", expectTrigger: true, seconds: 25, accel: { t in
            let a = t > 5 ? 0.025 : 0
            return g + Vec3(x: noise(0.02), y: a + noise(0.02), z: noise(0.02))
        }, gyro: { _ in Vec3(x: noise(1.5), y: noise(1.5), z: noise(1.5)) })

        // Train cruising at constant speed: only continuous rail vibration.
        scenario("Train cruising (rail vibration only)", expectTrigger: true, seconds: 40, accel: { _ in
            g + Vec3(x: noise(0.015), y: noise(0.015), z: noise(0.025))
        }, gyro: { _ in Vec3(x: noise(1.5), y: noise(1.5), z: noise(1.5)) })

        // Walking with the laptop: 2 Hz steps, 0.15 g fore/aft bob, swaying tilt.
        scenario("Walking around carrying the laptop", expectTrigger: false, seconds: 30, accel: { t in
            let step = 0.15 * sin(2 * .pi * 2 * t)
            return g + Vec3(x: 0.05 * sin(2 * .pi * t) + noise(0.03), y: step + noise(0.03), z: 0.1 * sin(2 * .pi * 4 * t))
        }, gyro: { t in Vec3(x: 15 * sin(2 * .pi * 2 * t), y: 10 * sin(2 * .pi * t), z: 20 * sin(0.5 * t)) })

        scenario("Sitting perfectly still", expectTrigger: false, seconds: 30, accel: { _ in
            g + Vec3(x: noise(0.004), y: noise(0.004), z: noise(0.004))
        }, gyro: { _ in Vec3(x: 0.08 + noise(0.4), y: noise(0.4), z: noise(0.4)) })

        scenario("Typing on a desk (taps, no steady push)", expectTrigger: false, seconds: 30, accel: { t in
            let tap = (Int(t * 100) % 23 == 0) ? 0.05 : 0
            return g + Vec3(x: tap + noise(0.006), y: noise(0.006), z: tap + noise(0.006))
        }, gyro: { _ in Vec3(x: noise(0.6), y: noise(0.6), z: noise(0.6)) })
        // Direction: the forward cue must follow real acceleration and never flip to "braking"
        // while the vehicle speeds up or just after. Quiet sensor data, like a smooth EV or train.
        // In this synthetic frame (gravity along -z, keyboard along x) forward is -y.
        print("")
        func direction(_ name: String, gyroSign: Double, bumpy: Bool = false, accel: @escaping (Double) -> Double) {
            let n = bumpy ? 0.02 : 0.003
            let p = MotionProcessor(learnedGyroSign: gyroSign)
            var t = 0.0, peak = 0.0, worst = 0.0, firstSeen: Double?
            while t < 40 {
                p.process(.gyro(Vec3(x: noise(0.5), y: noise(0.5), z: noise(0.5)), t))
                p.process(.accel(g + Vec3(x: noise(n), y: -accel(t) + noise(n), z: noise(n)), t))
                if ProcessInfo.processInfo.environment["AUTOTEST_TRACE"] == name, Int(t * 100) % 50 == 0 {
                    print(String(format: "  t=%4.1f f=%+.4f rawF=%+.4f still=%@ aN=%.4f", t, p.cue.forward, p.rawForward, p.isStill ? "Y" : "n", p.accelNoise))
                }
                if t > 8 {
                    peak = max(peak, p.cue.forward)
                    worst = min(worst, p.cue.forward)
                    if firstSeen == nil, p.cue.forward > 0.01 { firstSeen = t - 8 }
                }
                t += 0.01
            }
            // Picks up the push within 1.5 s, reaches at least half of it, never reads as braking.
            let passed = (firstSeen ?? 99) < 1.5 && peak > 0.5 * accel(12) && worst > -0.01
            allPassed = allPassed && passed
            print(passed ? "PASS" : "FAIL", name.padding(toLength: 44, withPad: " ", startingAt: 0),
                  String(format: "seen after %.1f s, peak %.3f g, most reverse %.3f g", firstSeen ?? -1, peak, worst))
        }
        // 8 s stopped at a light, then speeding up for 8 s, then cruising.
        let pullAway: (Double) -> Double = { t in t > 8 && t < 16 ? 0.06 * min(1, (t - 8) / 1.5) : 0 }
        let gentle: (Double) -> Double = { t in t > 8 && t < 20 ? 0.03 * min(1, (t - 8) / 2) : 0 }
        direction("Pull away from a stop (0.06 g, 8 s)", gyroSign: 1, accel: pullAway)
        direction("Pull away, gyro sign not learned yet", gyroSign: 0, accel: pullAway)
        direction("Train: gentle 0.03 g for 12 s", gyroSign: 1, accel: gentle)
        // A long merge on a bumpy road: slow gravity correction used to soak this up and then
        // play it back as braking.
        let merge: (Double) -> Double = { t in t > 8 && t < 20 ? 0.1 * min(1, (t - 8) / 2) : 0 }
        direction("Long merge on a bumpy road (0.1 g, 12 s)", gyroSign: 1, bumpy: true, accel: merge)
        return allPassed
    }
}
