#!/bin/zsh
# Motion Cues — vehicle motion cues for macOS
# Copyright (C) 2026 Spandan2022 and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Start Motion Cues from the terminal.
#
#   ./start.sh            build (if the source changed), install, and launch in the menu bar
#   ./start.sh --log      same, but run in this terminal and print live motion data (Ctrl-C to quit)
#   ./start.sh --stop     quit the running app
set -euo pipefail
cd "$(dirname "$0")"

APP="$HOME/Applications/MotionCues.app"
BIN="$APP/Contents/MacOS/MotionCues"

stop_running() {
  if pgrep -f "MotionCues.app/Contents/MacOS/MotionCues" >/dev/null; then
    pkill -f "MotionCues.app/Contents/MacOS/MotionCues" || true
    sleep 0.5
  fi
}

if [[ "${1:-}" == "--stop" ]]; then
  stop_running
  echo "Motion Cues stopped."
  exit 0
fi

# Rebuild only when the installed app is missing or older than any source file.
if [[ ! -x "$BIN" ]] || [[ -n "$(find Sources Resources Package.swift scripts/bundle.sh -newer "$BIN" -print -quit)" ]]; then
  echo "Building Motion Cues…"
  ./scripts/bundle.sh
fi

stop_running

if [[ "${1:-}" == "--log" ]]; then
  echo "Running with live motion log (Ctrl-C to quit)…"
  exec "$BIN" --log
fi

open "$APP"
echo "Motion Cues is running. Look for the car icon in the menu bar."
