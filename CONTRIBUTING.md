# Contributing to Motion Cues

Thanks for helping! Bug reports, real-ride tuning reports and pull requests are all welcome.

## Ride reports are the most useful contribution

The motion thresholds were tuned on one MacBook (an M2 Pro) and on synthetic data. Reports from real cars, buses
and trains on other Macs help the most. Open a **Ride report** issue and include:

- Mac model, chip and macOS version
- Vehicle type (car, bus, train…) and where the laptop was (lap, tray table…)
- What felt wrong: too sensitive, too slow, wrong direction, Automatic not triggering, and so on
- A short log if you can:
  ```bash
  ./start.sh --log > ride-log.txt   # Ctrl-C to stop
  ```

## Development setup

Requirements: an Apple Silicon MacBook, macOS 14+, and Xcode or the Command Line Tools.

```bash
git clone https://github.com/Spandan2022/MacOS_Motion_Cues.git
cd MacOS_Motion_Cues
swift build
.build/debug/MotionCues --log        # live sensor/processing readout
./start.sh                           # build, install to ~/Applications and launch
```

See [Development](README.md#development) in the README for the code layout and debug commands.

## Before opening a pull request

1. `swift build` succeeds with no new warnings.
2. `.build/debug/MotionCues --auto-test` passes. If you change the motion pipeline, the walking, typing and still
   scenarios must not trigger, and the vehicle scenarios must. Add a scenario for any new behavior you tune for.
3. For visual changes, attach a before/after. `--render-test <dir>` and `--render-demo <dir>` render the dots
   offscreen (screen recordings hide the dots unless `MOTIONCUES_CAPTURABLE=1` is set).
4. Keep the app dependency-free and network-free.
5. Add an entry under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).

New source files should start with the license header:

```swift
// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
```

By contributing, you agree that your contributions are licensed under the [GPL-3.0-or-later](LICENSE).

## Releasing (maintainers)

1. Update `VERSION` and move the **Unreleased** changelog entries under the new version.
2. Commit, then tag and push: `git tag v0.2.0 && git push origin main v0.2.0`.
3. The **Release** workflow builds the DMG and zip and creates a draft release. Review it and publish.
