#!/bin/zsh
# Motion Cues — vehicle motion cues for macOS
# Copyright (C) 2026 Spandan2022 and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Cuts a release: sets VERSION, turns the "Unreleased" section of CHANGELOG.md into the new
# version, commits and tags v<version>. With --push it also pushes main and the tag, which
# makes .github/workflows/release.yml build the DMG/zip and publish the GitHub release.
#
#   scripts/release.sh 0.2.0           prepare the commit and tag locally
#   scripts/release.sh 0.2.0 --push    ...and publish
#
# Versions follow Semantic Versioning: bump the patch for fixes, the minor for new features
# or behavior changes, the major for breaking changes.
set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
PUSH=0
[[ "${2:-}" == "--push" ]] && PUSH=1

fail() { print -u2 "Error: $*"; exit 1; }

[[ "$NEW" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || fail "usage: scripts/release.sh <major.minor.patch> [--push]"
OLD="$(cat VERSION)"
[[ "$NEW" != "$OLD" ]] || fail "VERSION is already $NEW"
[[ "$(printf '%s\n%s\n' "$OLD" "$NEW" | sort -V | tail -1)" == "$NEW" ]] || fail "$NEW is lower than the current $OLD"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "release from main"
[[ -z "$(git status --porcelain)" ]] || fail "working tree has uncommitted changes"
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null && fail "tag v$NEW already exists"

# The Unreleased section must say what changed.
NOTES="$(awk '/^## \[Unreleased\]/ { on = 1; next } on && /^## \[/ { exit } on' CHANGELOG.md | grep -v '^[[:space:]]*$' || true)"
[[ -n "$NOTES" ]] || fail "CHANGELOG.md has nothing under [Unreleased]"

echo "Checking build and Automatic-mode scenarios…"
swift build >/dev/null
.build/debug/MotionCues --auto-test

echo "$NEW" > VERSION
TODAY="$(date +%Y-%m-%d)"
REPO_URL="https://github.com/Spandan2022/MacOS_Motion_Cues"
awk -v v="$NEW" -v d="$TODAY" '
  /^## \[Unreleased\]/ { print; print ""; print "## [" v "] - " d; next }
  { print }' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
# Keep the comparison links at the bottom current, if the changelog has them.
if grep -q '^\[Unreleased\]:' CHANGELOG.md; then
  if git rev-parse -q --verify "refs/tags/v$OLD" >/dev/null; then
    LINK="$REPO_URL/compare/v$OLD...v$NEW"
  else
    LINK="$REPO_URL/releases/tag/v$NEW"
  fi
  sed -i '' "s|^\[Unreleased\]:.*|[Unreleased]: $REPO_URL/compare/v$NEW...HEAD\\
[$NEW]: $LINK|" CHANGELOG.md
fi

git add VERSION CHANGELOG.md
git commit -q -m "Release $NEW"
git tag -a "v$NEW" -m "Motion Cues $NEW"
echo "Committed and tagged v$NEW."

if [[ $PUSH == 1 ]]; then
  git push origin main "v$NEW"
  echo "Pushed. The release will appear at $REPO_URL/releases/tag/v$NEW once the workflow finishes."
else
  echo "To publish: git push origin main v$NEW"
fi
