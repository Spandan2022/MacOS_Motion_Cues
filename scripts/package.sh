#!/bin/zsh
# Motion Cues — vehicle motion cues for macOS
# Copyright (C) 2026 Spandan2022 and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds release downloads into dist/:
#   MotionCues-<version>.dmg   drag-to-Applications disk image
#   MotionCues-<version>.zip   zipped app
#   MotionCues.dmg             same DMG under a fixed name, so
#                              releases/latest/download/MotionCues.dmg always works
#
# If NOTARY_PROFILE is set (a `xcrun notarytool store-credentials` profile) and the app is
# signed with a Developer ID, the app and DMG are notarized and stapled, so they open
# without Gatekeeper warnings.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
scripts/bundle.sh --no-install

APP=build/MotionCues.app
DIST=dist
rm -rf "$DIST" && mkdir -p "$DIST"
ZIP="$DIST/MotionCues-${VERSION}.zip"
DMG="$DIST/MotionCues-${VERSION}.dmg"

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

SIGNED_WITH_DEVELOPER_ID=0
codesign -dv "$APP" 2>&1 | grep -q "Authority=Developer ID Application" && SIGNED_WITH_DEVELOPER_ID=1

if [[ -n "${NOTARY_PROFILE:-}" && $SIGNED_WITH_DEVELOPER_ID == 1 ]]; then
  echo "Notarizing app…"
  ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
  notarize "$DIST/notarize.zip"
  rm "$DIST/notarize.zip"
  xcrun stapler staple "$APP"
fi

ditto -c -k --keepParent "$APP" "$ZIP"

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Motion Cues" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [[ -n "${NOTARY_PROFILE:-}" && $SIGNED_WITH_DEVELOPER_ID == 1 ]]; then
  codesign --force --timestamp --sign "$(codesign -dv "$APP" 2>&1 | sed -n 's/^Authority=\(Developer ID Application.*\)/\1/p' | head -1)" "$DMG"
  echo "Notarizing DMG…"
  notarize "$DMG"
  xcrun stapler staple "$DMG"
fi
cp "$DMG" "$DIST/MotionCues.dmg"

echo "Built:"
ls -lh "$DIST"
