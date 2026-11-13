#!/bin/bash
# Motion Cues — vehicle motion cues for macOS
# Copyright (C) 2026 Spandan2022 and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/Spandan2022/MacOS_Motion_Cues/main/install.sh | bash
#
# Options (pass after `bash -s --` when piping, e.g. `... | bash -s -- --uninstall`):
#   --from-source   build from source instead of downloading a release (needs Xcode Command Line Tools)
#   --uninstall     quit and remove Motion Cues and its settings
#
# Environment overrides (mainly for testing):
#   MOTIONCUES_ZIP_URL   install from this zip URL instead of the latest GitHub release
#   MOTIONCUES_DEST      install directory (default: /Applications if writable, else ~/Applications)
set -euo pipefail

REPO="Spandan2022/MacOS_Motion_Cues"
APP_NAME="MotionCues.app"
BUNDLE_ID="io.github.spandan2022.motioncues"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

quit_running() {
  if pgrep -f "$APP_NAME/Contents/MacOS/MotionCues" >/dev/null 2>&1; then
    osascript -e "quit app id \"$BUNDLE_ID\"" >/dev/null 2>&1 || true
    sleep 1
    pkill -f "$APP_NAME/Contents/MacOS/MotionCues" >/dev/null 2>&1 || true
  fi
}

remove_existing() {
  for dir in /Applications "$HOME/Applications"; do
    if [ -d "$dir/$APP_NAME" ]; then
      rm -rf "${dir:?}/$APP_NAME" 2>/dev/null || fail "Couldn't remove $dir/$APP_NAME (try: sudo rm -rf \"$dir/$APP_NAME\")"
    fi
  done
}

# --- Uninstall ------------------------------------------------------------------------------
if [ "${1:-}" = "--uninstall" ]; then
  bold "Uninstalling Motion Cues…"
  quit_running
  remove_existing
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
  info "Removed the app, its settings and its Screen Recording permission."
  info "If you had turned on Launch at Login, remove it in System Settings ▸ General ▸ Login Items."
  exit 0
fi

# --- Checks ---------------------------------------------------------------------------------
bold "Installing Motion Cues"

[ "$(uname -s)" = "Darwin" ] || fail "Motion Cues runs on macOS only."
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MACOS_MAJOR" -ge 14 ] || fail "Motion Cues needs macOS 14 Sonoma or later (you have $(sw_vers -productVersion))."
[ "$(uname -m)" = "arm64" ] || fail "Motion Cues needs an Apple Silicon MacBook (Intel Macs have no motion sensor)."
SENSORS="$(ioreg -r -c AppleSPUHIDDevice -l 2>/dev/null || true)"
if [[ "$SENSORS" != *'"Product" = "accel"'* ]]; then
  printf '\033[33mWarning:\033[0m no built-in motion sensor found. Motion Cues needs a MacBook (Air or Pro);\n' >&2
  printf '         it will install, but the dots will only work with Test Motion.\n' >&2
fi

if [ -n "${MOTIONCUES_DEST:-}" ]; then
  DEST="$MOTIONCUES_DEST"
elif [ -w /Applications ]; then
  DEST="/Applications"
else
  DEST="$HOME/Applications"
fi
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Get the app ----------------------------------------------------------------------------
if [ "${1:-}" = "--from-source" ]; then
  command -v swift >/dev/null 2>&1 || fail "Swift not found. Install the Command Line Tools first: xcode-select --install"
  command -v git >/dev/null 2>&1 || fail "git not found. Install the Command Line Tools first: xcode-select --install"
  info "Cloning and building (this takes a minute)…"
  git clone --depth 1 "https://github.com/$REPO.git" "$TMP/src" >/dev/null 2>&1 || fail "Couldn't clone https://github.com/$REPO"
  (cd "$TMP/src" && scripts/bundle.sh --no-install >/dev/null) || fail "Build failed."
  cp -R "$TMP/src/build/$APP_NAME" "$TMP/$APP_NAME"
else
  ZIP_URL="${MOTIONCUES_ZIP_URL:-}"
  if [ -z "$ZIP_URL" ]; then
    info "Finding the latest release…"
    ZIP_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | grep -oE '"browser_download_url": *"[^"]+\.zip"' | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')" || true
    [ -n "$ZIP_URL" ] || fail "No release found. Install from source instead:
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash -s -- --from-source"
  fi
  info "Downloading $(basename "$ZIP_URL")…"
  curl -fsSL "$ZIP_URL" -o "$TMP/MotionCues.zip" || fail "Download failed: $ZIP_URL"
  ditto -x -k "$TMP/MotionCues.zip" "$TMP" || fail "Couldn't unpack the download."
  [ -d "$TMP/$APP_NAME" ] || fail "The download didn't contain $APP_NAME."
fi

# --- Install --------------------------------------------------------------------------------
quit_running
remove_existing
cp -R "$TMP/$APP_NAME" "$DEST/$APP_NAME" || fail "Couldn't copy to $DEST"
# Files fetched with curl aren't quarantined, but clear the flag in case the zip carried one.
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

VERSION="$(defaults read "$DEST/$APP_NAME/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "?")"
info "Installed Motion Cues $VERSION to $DEST"
open "$DEST/$APP_NAME"

bold "Done! Motion Cues is running. Look for the car icon in the menu bar."
info "First time? In its menu choose Advanced ▸ Direction ▸ Calibrate…, then turn on Launch at Login."
info "To uninstall later: curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash -s -- --uninstall"
