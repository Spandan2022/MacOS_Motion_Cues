# Motion Cues for Mac

*Vehicle motion cues for your MacBook: work comfortably on the train, bus or car without motion sickness.*

<p>
  <a href="https://github.com/Spandan2022/MacOS_Motion_Cues/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/Spandan2022/MacOS_Motion_Cues?include_prereleases&style=for-the-badge&label=release&labelColor=1f2328&color=2f6fe4"></a>
  <a href="LICENSE"><img alt="License: GPLv3" src="https://img.shields.io/badge/license-GPLv3-2f6fe4?style=for-the-badge&labelColor=1f2328"></a>
  <a href="#requirements"><img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-2f6fe4?style=for-the-badge&logo=apple&logoColor=white&labelColor=1f2328"></a>
  <a href="#requirements"><img alt="Apple Silicon MacBook" src="https://img.shields.io/badge/Apple%20Silicon-MacBook-2f6fe4?style=for-the-badge&labelColor=1f2328"></a>
  <a href="https://swift.org"><img alt="Swift 5.10 or later" src="https://img.shields.io/badge/Swift-5.10%2B-2f6fe4?style=for-the-badge&logo=swift&logoColor=white&labelColor=1f2328"></a>
</p>

[Install](#install) · [Download](https://github.com/Spandan2022/MacOS_Motion_Cues/releases/latest) · [Features](#features) · [Settings](#settings) · [FAQ](#faq) · [Report a bug](https://github.com/Spandan2022/MacOS_Motion_Cues/issues/new/choose)

<img src="docs/images/demo.gif" alt="Screen recording of Motion Cues on a MacBook: turning it on from the menu bar, then the dot columns moving along both edges of the screen" width="760">

<sub>Motion Cues running on a MacBook Pro: switched on from the menu bar, with the dots moving along both screen edges.</sub>

---

Motion sickness happens when your eyes and your inner ear disagree. You feel the car speed up, brake and turn,
but the screen in front of you stays perfectly still. Motion Cues brings the idea behind the iPhone's *Vehicle
Motion Cues* to the Mac. Dots along the edges of your screen move with the vehicle, so what you see matches what
you feel.

It runs on the **accelerometer and gyroscope already inside Apple Silicon MacBooks**. You don't need a phone, extra
hardware or an account, and nothing leaves your Mac.

> [!NOTE]
> Motion Cues is an independent open-source project and is not affiliated with Apple.

## Install

Paste this into **Terminal**:

```bash
curl -fsSL https://raw.githubusercontent.com/Spandan2022/MacOS_Motion_Cues/main/install.sh | bash
```

It checks that your Mac is supported, installs the latest release into Applications and opens it. On first launch a
short **Welcome Guide** shows what the dots do and where the app lives (the **car icon** in the menu bar). Turn on
**Open at Login** from that menu, and leave **Show Motion Cues** on **Automatic** so the dots appear by themselves
once you're moving. You can reopen the guide from **Advanced ▸ Welcome Guide…**.

Running the same command again updates to the newest version. To remove the app, run it with `bash -s -- --uninstall`.

### Requirements

- An **Apple Silicon MacBook** (Air or Pro). Desktop and Intel Macs have no built-in motion sensor.
- **macOS 14** Sonoma or later.

### Other ways to install

**Download the DMG.** [**⬇ Download MotionCues.dmg**](https://github.com/Spandan2022/MacOS_Motion_Cues/releases/latest/download/MotionCues.dmg)
(always the latest version; older versions are on the
[releases page](https://github.com/Spandan2022/MacOS_Motion_Cues/releases)), open it and drag Motion Cues into
Applications. Releases are signed and notarized by Apple, so it opens like any other app.

**Build from source.** This needs Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Spandan2022/MacOS_Motion_Cues.git
cd MacOS_Motion_Cues
./start.sh
```

`start.sh` builds the app, installs it to `~/Applications` and opens it. After that you can close Terminal.

## Features

- **Uses the sensors you already have.** It reads the MacBook's built-in accelerometer and gyroscope 100 times a
  second. Sensor fusion keeps gentle, sustained motion visible, like a train slowly pulling out of a station.
- **Endless, flowing dots.** Speeding up and braking make the dot columns flow down and up. Dots slide off one edge
  of the screen and grow back in at the other.
- **Turns you can see.** In a turn, the two sides flow in opposite directions, like the scenery rotating around you,
  and the columns lean sideways. Strong motion brings in a second column.
- **No permissions needed.** It only reads the motion sensor, so there's nothing to approve in System Settings.
- **Automatic mode that knows the difference.** It turns on after a few seconds of vehicle motion, including the
  gentle pull of a train, and stays on through red lights and station stops. Walking around with your laptop,
  typing or sitting still won't set it off.
- **Stays out of the way.** It lives in the menu bar, lets every click through, and works on all displays and
  Spaces, including full-screen apps. It stays out of screenshots and uses about 2% CPU.

### How the dots respond

| When the vehicle… | the dots… |
|---|---|
| speeds up | flow **down**, like being pressed back into your seat |
| brakes | flow **up** |
| turns left | flow up on the left and down on the right, and shift right |
| turns right | do the opposite |
| moves hard | grow slightly, and a second inner column fades in |
| stops | stop where they are |

Picking up or tilting the laptop is detected with the gyroscope and ignored.

## Settings

Everything is in the menu-bar menu. Appearance and tuning are under **Advanced**.

| Setting | Options | Default |
|---|---|---|
| Show Motion Cues | Off, On, Automatic | Automatic |
| Dot Size | Small, Medium, Large | Medium |
| Dot Density | Low, Medium, High | Medium |
| Dot Color | White, Grey, Black, Blue, Yellow, Green, Red, Purple | Grey |
| Dot Opacity | 35%, 50%, 75%, 100% | 75% |
| Sensitivity | Low, Medium, High, Max | Medium |
| Direction | Calibrate, or invert front/back, left/right and turns | — |
| Test Motion | Speed up, brake, turn left/right, stop-and-go drive | — |

**Grey** reads on both light and dark windows. Pick **White** if you mostly use dark mode, or **Black** for bright
documents and web pages.

## Privacy

- Motion Cues **never connects to the internet**. **Check for Updates…** just opens the releases page in your
  browser.
- The motion sensor is read locally and needs no permission.
- It never looks at your screen, so it doesn't ask for Screen Recording permission.

## FAQ

<details>
<summary><b>Will it work on my Mac?</b></summary>

<br>

It needs an Apple Silicon MacBook (Air or Pro) on macOS 14 or later. It was developed on an M2 Pro MacBook Pro, and
other Apple Silicon MacBooks should work too. If you try it, please
[send a ride report](https://github.com/Spandan2022/MacOS_Motion_Cues/issues/new/choose). iMac, Mac mini, Mac Studio,
Mac Pro and Intel Macs don't have the motion sensor.
</details>

<details>
<summary><b>The dots move the wrong way</b></summary>

<br>

Run **Advanced ▸ Direction ▸ Calibrate…** with the laptop on a table, or flip the invert options by hand. The dots
assume you're facing the same way as the keyboard.
</details>

<details>
<summary><b>The dots are hard to see</b></summary>

<br>

Change **Advanced ▸ Dot Color** to stand out against what's on screen (**Black** on bright pages, **White** in dark
mode), or raise **Dot Opacity** or **Dot Size**.
</details>

<details>
<summary><b>Automatic mode doesn't turn on</b></summary>

<br>

It turns on after about 2.5 seconds of firm acceleration, braking or turning, about 6 seconds of gentle acceleration,
or about 20 seconds of steady road or rail vibration. A very smooth ride at constant speed can stay below all three;
switch to **On** for that trip. If it turns on when you're *not* moving, please
[open a ride report](https://github.com/Spandan2022/MacOS_Motion_Cues/issues/new/choose).
</details>

## Known limitations

- macOS has no public API for the MacBook motion sensor, so a future macOS update could break access to it.
- The sensitivity and Automatic thresholds are tuned from desk tests and simulated drives. Real rides will refine them.

## Development

Motion Cues is a single Swift package with no dependencies.

```bash
swift build                                  # debug build
.build/debug/MotionCues --log                # live motion readout
.build/debug/MotionCues --auto-test          # Automatic-mode and direction scenarios (also run in CI)
.build/debug/MotionCues --simulate drive     # drive, speedup, brake, left, right
.build/debug/MotionCues --render-test <dir>  # dot renders as PNGs
.build/debug/MotionCues --render-demo <dir>  # frames for the demo GIF
.build/debug/MotionCues --onboarding         # show the Welcome Guide again
.build/debug/MotionCues --render-onboarding <dir>  # Welcome Guide pages as PNGs
scripts/package.sh                           # release DMG and zip in dist/
scripts/release.sh 0.3.0 --push              # bump version, tag, publish a GitHub release
```

<details>
<summary><b>How it works</b></summary>

<br>

- **Sensor access.** The accelerometer and gyroscope appear as `AppleSPUHIDDevice` services (vendor usage page
  `0xFF00`, usages 3 and 9). They stay silent until the driver's `SensorPropertyReportingState`,
  `SensorPropertyPowerState` and `ReportInterval` properties are set. After that, each 22-byte report holds three
  little-endian `Int32` values at offset 6, in 16.16 fixed point (g, or degrees per second).
- **Gravity tracking.** Gravity can only change direction when the laptop rotates, so it is rotated with the gyro
  and only nudged toward the accelerometer to remove drift: over about 3 seconds when the laptop is perfectly still,
  over about 12 seconds otherwise, and not at all (for up to 20 seconds) during a sustained push without tilting, so
  speeding up or braking is never mistaken for gravity. The gyro's sign is learned from the first few tilts, and its
  bias is re-learned whenever the laptop is still.
- **Vehicle frame.** The acceleration left over is projected onto the horizontal plane. The sensor's x axis is
  left/right, and the axis perpendicular to it and to gravity is front/back.
- **Automatic mode.** It builds up evidence of vehicle motion: fastest from steady acceleration of 0.035 g or more
  or a steady turn (about 2.5 seconds), slower from gentle acceleration of 0.018 g or more (about 6 seconds) and
  slowest from continuous road or rail vibration (about 20 seconds). Tilting or footstep jolts reset it. It turns
  off after 3 minutes without motion.

</details>

<details>
<summary><b>Project layout</b></summary>

<br>

```
Sources/MotionCues/
├── App.swift                       Menu bar, Automatic mode, test motions, calibration
├── Onboarding.swift                Welcome Guide window
├── Settings.swift                  Preferences and dot colors
├── Sensor/SPUSensor.swift          Reads the accelerometer and gyro through IOKit HID
├── Motion/MotionProcessor.swift    Fusion, filtering, stillness, vehicle-motion detection
├── Overlay/DotsView.swift          Dot layout and animation
├── Overlay/OverlayController.swift Click-through window on each screen
├── AutoTest.swift                  Synthetic Automatic-mode scenarios
└── RenderTest.swift                Offscreen renders and demo frames
Resources/                          App icon and the Welcome Guide's MacBook frame
scripts/                            Build, package, release and icon scripts
install.sh                          One-line installer
start.sh                            Build and launch for development
```

</details>

## Contributing

Contributions are welcome. The most useful one right now is a
[ride report](https://github.com/Spandan2022/MacOS_Motion_Cues/issues/new/choose): how the dots felt in a real car,
bus or train, on your Mac. See [CONTRIBUTING.md](CONTRIBUTING.md) to get set up, and [CHANGELOG.md](CHANGELOG.md)
for what's changed.

## License

Copyright © 2026 Spandan2022 and contributors. Released under the
[GNU General Public License v3.0 or later](LICENSE).
