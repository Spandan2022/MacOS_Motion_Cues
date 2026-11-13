# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/Spandan2022/MacOS_Motion_Cues/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Spandan2022/MacOS_Motion_Cues/releases/tag/v0.1.0
