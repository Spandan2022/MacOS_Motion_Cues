#!/bin/zsh
# Motion Cues — vehicle motion cues for macOS
# Copyright (C) 2026 Spandan2022 and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds build/MotionCues.app (menu-bar only) and installs it to ~/Applications.
#
#   scripts/bundle.sh               build, sign, install to ~/Applications
#   scripts/bundle.sh --no-install  build and sign only (used for releases)
#
# Signing: uses $CODESIGN_IDENTITY if set, otherwise the first Developer ID / Apple Development
# identity in your keychain, otherwise an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

VERSION="$(cat VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
BUNDLE_ID="io.github.spandan2022.motioncues"

swift build -c release
APP=build/MotionCues.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MotionCues "$APP/Contents/MacOS/MotionCues"
[[ -f Resources/AppIcon.icns ]] || swift scripts/make_icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/MacBookFrame.png "$APP/Contents/Resources/MacBookFrame.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Motion Cues</string>
  <key>CFBundleDisplayName</key><string>Motion Cues</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>MotionCues</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Spandan2022 and contributors. GPL-3.0-or-later.</string>
</dict>
</plist>
PLIST

# Sign with a real identity if one exists, so macOS settings tied to the app (like Open at Login)
# survive rebuilds. Ad-hoc signatures change every build, so macOS treats each build as a new app.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -p codesigning -v 2>/dev/null | grep -m1 -oE '"(Developer ID Application|Apple Development)[^"]*"' | tr -d '"' || true)}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  echo "Signed with: $IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "Signed ad-hoc (no signing identity found)."
fi

if [[ $INSTALL == 1 ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/MotionCues.app
  cp -R "$APP" ~/Applications/
  echo "Installed ~/Applications/MotionCues.app (version ${VERSION})"
fi
