// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import IOKit
import IOKit.hid

/// Reads the accelerometer and gyroscope built into Apple Silicon MacBooks.
///
/// They are exposed as `AppleSPUHIDDevice`s (vendor usage page 0xFF00, usage 3 = accel,
/// 9 = gyro) but stay silent until the driver is told to report. Reports are 22 bytes with
/// three little-endian Int32s at offset 6, in 16.16 fixed point (accel in g, gyro in deg/s).
final class SPUSensor: MotionSource {
    var onReading: ((MotionReading) -> Void)?

    private var manager: IOHIDManager?
    private var buffers: [UnsafeMutablePointer<UInt8>] = []
    /// One per device, so the callback knows which sensor fired without a property lookup.
    private var contexts: [DeviceContext] = []

    private final class DeviceContext {
        weak var sensor: SPUSensor?
        let isAccel: Bool
        init(sensor: SPUSensor, isAccel: Bool) { self.sensor = sensor; self.isAccel = isAccel }
    }
    private var watchdog: Timer?
    private(set) var lastSampleTime: TimeInterval = 0

    private static let usagePage = 0xFF00
    private static let accelUsage = 3
    private static let gyroUsage = 9
    private static let reportSize = 64

    /// Whether this Mac exposes the SPU accelerometer at all.
    static var isAvailable: Bool { !driverServices().isEmpty }

    func start() -> Bool {
        guard Self.enableReporting() else { return false }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Any]] = [Self.accelUsage, Self.gyroUsage].map {
            [kIOHIDPrimaryUsagePageKey: Self.usagePage, kIOHIDPrimaryUsageKey: $0, kIOHIDTransportKey: "SPU"]
        }
        IOHIDManagerSetDeviceMatchingMultiple(mgr, matching as CFArray)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        guard IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            NSLog("MotionCues: IOHIDManagerOpen failed")
            return false
        }
        manager = mgr

        let devices = (IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>) ?? []
        for device in devices {
            let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? -1
            guard usage == Self.accelUsage || usage == Self.gyroUsage else { continue }
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.reportSize)
            buffers.append(buf)
            let deviceContext = DeviceContext(sensor: self, isAccel: usage == Self.accelUsage)
            contexts.append(deviceContext)
            IOHIDDeviceRegisterInputReportCallback(device, buf, Self.reportSize, { ctx, _, _, _, _, report, length in
                guard let ctx else { return }
                let dc = Unmanaged<DeviceContext>.fromOpaque(ctx).takeUnretainedValue()
                dc.sensor?.handle(isAccel: dc.isAccel, report: report, length: length)
            }, Unmanaged.passUnretained(deviceContext).toOpaque())
        }
        guard !buffers.isEmpty else { return false }

        // The sensor can go quiet after sleep or if another process changes its state.
        watchdog = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if ProcessInfo.processInfo.systemUptime - self.lastSampleTime > 2 {
                _ = Self.enableReporting()
            }
        }
        return true
    }

    func stop() {
        watchdog?.invalidate()
        watchdog = nil
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        buffers.forEach { $0.deallocate() }
        buffers.removeAll()
        contexts.removeAll()
    }

    private func handle(isAccel: Bool, report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length >= 18 else { return }
        func int32(at offset: Int) -> Double {
            var v: Int32 = 0
            memcpy(&v, report.advanced(by: offset), 4)
            return Double(Int32(littleEndian: v)) / 65536.0
        }
        let v = Vec3(x: int32(at: 6), y: int32(at: 10), z: int32(at: 14))
        let t = ProcessInfo.processInfo.systemUptime
        lastSampleTime = t
        onReading?(isAccel ? .accel(v, t) : .gyro(v, t))
    }

    // MARK: - Driver control

    private static func driverServices() -> [(io_object_t, String)] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDriver"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }
        var result: [(io_object_t, String)] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            let product = IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            if let product, product == "accel" || product == "gyro" {
                result.append((service, product))
            } else {
                IOObjectRelease(service)
            }
        }
        return result
    }

    /// Powers the sensors on and asks for a report every 10 ms (100 Hz keeps latency low).
    @discardableResult
    static func enableReporting() -> Bool {
        let services = driverServices()
        defer { services.forEach { IOObjectRelease($0.0) } }
        var ok = !services.isEmpty
        for (service, _) in services {
            for (key, value) in [("SensorPropertyReportingState", 1), ("SensorPropertyPowerState", 1), ("ReportInterval", 10_000)] {
                if IORegistryEntrySetCFProperty(service, key as CFString, value as CFNumber) != KERN_SUCCESS {
                    ok = false
                }
            }
        }
        return ok
    }
}
