// swift-tools-version:5.10
// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "MotionCues",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MotionCues",
            path: "Sources/MotionCues",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("ServiceManagement")]
        )
    ]
)
