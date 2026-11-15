# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.1] - 2026-11-15

### Changed
- Releases are signed with a Developer ID and notarized by Apple, so the app opens without the "Open Anyway" step.
- `scripts/bundle.sh` prefers a Developer ID identity over Apple Development when both are installed.

### Fixed
- The uninstaller now refers to "Open at Login" (the menu item's current name).

## [0.3.0] - 2026-11-15

### Added
- First-launch Welcome Guide: a live preview of the dots on a sample drive, and where the app lives in the menu bar. Reopen it from Advanced ▸ Welcome Guide….

### Changed
- The menu's "Launch at Login" is now "Open at Login", next to Check for Updates…; the version number moved to the bottom of Advanced. If macOS holds the login item for approval, the app now says so and offers to open System Settings (the item shows a dash until it's approved), and errors are shown instead of failing silently.

### Removed
- Adaptive dot colors, and with them the Screen Recording permission. Motion Cues no longer looks at the screen at all. Dot Color is now a fixed White, Grey (default), Black, Blue, Yellow, Green, Red or Purple.

### Fixed
- Dots sometimes flowed the wrong way (up while speeding up). Pulling away from a stop, the sensor still counted as "at rest" and absorbed the acceleration into its gravity estimate, then played it back as braking; long pushes were slowly absorbed the same way. Gravity now only follows the accelerometer when the laptop is truly at rest, and pauses during a sustained push without tilting.
- Gentle, smooth acceleration (EVs, trains) is picked up instead of being absorbed.

## [0.2.0] - 2026-11-15

### Changed
- Automatic mode detects trains better: gentle acceleration (≥0.018 g) and steady rail/road vibration now count as motion, just more slowly than a firm push.
- Automatic mode keeps the dots on for 3 minutes without motion (was 1 minute), so they survive red lights and station stops.

## [0.1.0] - 2026-11-13

First public release.

### Added
- Menu-bar app that shows vehicle motion cues: endless dot columns on the left and right screen edges.
- Reads the built-in accelerometer and gyroscope of Apple Silicon MacBooks (no root, no extra hardware).
- Sensor fusion with automatic gyro-sign learning, stillness lock and gyro bias learning.
- Flow-based dot motion for speeding up and braking, opposite-side flow for turns, a sideways spring, and a second column on strong motion.
- Dots grow in and shrink out at the top and bottom edges.
- Per-dot adaptive color (Greyscale or colored) from background sampling, plus fixed White and Black.
- Automatic mode that triggers on sustained vehicle-like motion, not on walking, typing or handling.
- Settings for size, density, color, opacity, sensitivity, direction calibration and test motions.
- One-line installer (`install.sh`) with `--from-source` and `--uninstall`.
- `start.sh`, a DMG/zip packaging script, CI, and a release workflow.

[Unreleased]: https://github.com/Spandan2022/MacOS_Motion_Cues/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/Spandan2022/MacOS_Motion_Cues/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Spandan2022/MacOS_Motion_Cues/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Spandan2022/MacOS_Motion_Cues/releases/tag/v0.2.0
[0.1.0]: https://github.com/Spandan2022/MacOS_Motion_Cues/releases/tag/v0.1.0
