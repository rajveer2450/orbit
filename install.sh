#!/usr/bin/env bash
#
# Orbit installer for macOS (Apple Silicon).
#
#   curl -fsSL https://getorbit.tech/install.sh | bash
#
# What it does, in order: downloads the latest DMG from the public GitHub
# release, mounts it, copies ORBIT.app to /Applications, removes the quarantine
# attribute, unmounts, and deletes the download.
#
# Why this exists. Orbit's builds are signed but not notarized, because
# notarization requires a paid Apple Developer account. macOS marks anything a
# BROWSER downloads as quarantined and refuses the first launch with "Apple
# could not verify ORBIT is free of malware", which then takes a trip through
# System Settings to clear. curl does not set that attribute in the first place,
# so an app installed this way simply opens.
#
# This script does not disable or weaken any macOS security feature. It fetches
# the same release the website links to, over HTTPS, from the same GitHub URL.
#
# If you would rather download the DMG by hand, go to https://getorbit.tech and
# use System Settings, Privacy and Security, Open Anyway. Same app, more clicks.
#
# This script installs to /Applications and touches nothing else. Read it
# before you run it; that is the point of it being short.

set -euo pipefail

REPO="rajveer2450/orbit"
ASSET="ORBIT-mac-arm64.dmg"
APP="ORBIT.app"
DEST="/Applications"

red() { printf '\033[31m%s\033[0m\n' "$1" >&2; }
say() { printf '\033[36m→\033[0m %s\n' "$1"; }
ok()  { printf '\033[32m✓\033[0m %s\n' "$1"; }

[ "$(uname -s)" = "Darwin" ] || { red "Orbit's installer is macOS only. Windows: https://getorbit.tech"; exit 1; }
if [ "$(uname -m)" != "arm64" ]; then
  red "This build is Apple Silicon (arm64) only, and this Mac reports $(uname -m)."
  red "An Intel build is not available yet: https://getorbit.tech"
  exit 1
fi

TMP="$(mktemp -d)"
MOUNT="$TMP/mnt"
cleanup() {
  [ -d "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

say "Downloading the latest Orbit release"
curl -fL --progress-bar -o "$TMP/orbit.dmg" \
  "https://github.com/$REPO/releases/latest/download/$ASSET"

# A GitHub error page would also arrive as a 200 with HTML in it.
if ! file "$TMP/orbit.dmg" | grep -qi "disk image\|zlib\|bzip2"; then
  red "That download does not look like a disk image. Try again, or grab it from https://getorbit.tech"
  exit 1
fi

say "Mounting"
mkdir -p "$MOUNT"
hdiutil attach "$TMP/orbit.dmg" -nobrowse -quiet -mountpoint "$MOUNT"
[ -d "$MOUNT/$APP" ] || { red "$APP was not inside the disk image."; exit 1; }

if [ -d "$DEST/$APP" ]; then
  say "Replacing the copy already in $DEST"
  rm -rf "$DEST/$APP"
fi

say "Copying to $DEST"
cp -R "$MOUNT/$APP" "$DEST/$APP"

# curl does not quarantine, so there is normally nothing here to clear. This
# stays only to cover a DMG that arrived carrying the attribute already.
if xattr -p com.apple.quarantine "$DEST/$APP" >/dev/null 2>&1; then
  say "Clearing a quarantine attribute that came with the download"
  xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/$APP/Contents/Info.plist" 2>/dev/null || echo '')"
ok "Orbit ${VERSION:+$VERSION }installed to $DEST"
echo
echo "  Open it:   open -a ORBIT"
echo "  Docs:      https://getorbit.tech/docs/"
echo
echo "Orbit is free and runs entirely on your machine. Your agents use your own"
echo "API keys and Orbit never proxies a request."
