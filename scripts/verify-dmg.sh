#!/bin/bash
# Verify the actual disk image, including after an Actions artifact download.
set -Eeuo pipefail
trap 'status=$?; echo "::error file=scripts/verify-dmg.sh,line=$LINENO::DMG verification failed ($status): $BASH_COMMAND"; exit "$status"' ERR

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_PATH="${1:?Usage: verify-dmg.sh path/to/BrowserOpener-version.dmg}"
MOUNT_POINT=$(mktemp -d "${TMPDIR:-/tmp}/browseropener-verify.XXXXXX")
MOUNTED=false
cleanup() {
    if "$MOUNTED"; then
        hdiutil detach "$MOUNT_POINT"
    fi
    rmdir "$MOUNT_POINT"
}
trap cleanup EXIT

hdiutil verify "$DMG_PATH"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -noautoopen -mountpoint "$MOUNT_POINT"
MOUNTED=true
APP="$MOUNT_POINT/BrowserOpener.app"
BIN="$APP/Contents/MacOS/BrowserOpener"
test -x "$BIN"
test -d "$APP/Contents/Resources"
test "$(readlink "$MOUNT_POINT/Applications")" = /Applications
cmp "$PROJECT_ROOT/Info.plist" "$APP/Contents/Info.plist"
test "$(lipo -archs "$BIN")" = arm64
codesign --verify --strict --verbose=2 "$APP"
SIGNATURE=$(codesign --display --verbose=4 "$APP" 2>&1)
printf '%s\n' "$SIGNATURE"
grep -qx 'Signature=adhoc' <<< "$SIGNATURE"
grep -qx 'TeamIdentifier=not set' <<< "$SIGNATURE"

python3 - "$APP" "$PROJECT_ROOT" <<'PY'
import pathlib
import plistlib
import re
import subprocess
import sys

app, root = map(pathlib.Path, sys.argv[1:])
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleIdentifier'] == 'com.blood72.browseropener'
assert info['CFBundleExecutable'] == 'BrowserOpener'
assert info['CFBundlePackageType'] == 'APPL'
assert re.fullmatch(r'\d+\.\d+\.\d+', info['CFBundleShortVersionString'])
assert info['CFBundleVersion']
assert info['LSUIElement'] is True
schemes = {s for item in info['CFBundleURLTypes'] for s in item['CFBundleURLSchemes']}
assert schemes == {'http', 'https'}, schemes
assert info['LSMinimumSystemVersion'] == '13.0', info['LSMinimumSystemVersion']
assert '.macOS(.v13)' in (root / 'Package.swift').read_text()
binary = app / 'Contents/MacOS/BrowserOpener'
build = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(binary)], text=True)
print(build)
assert re.search(r'platform\s+MACOS\b', build), build
minimums = re.findall(r'^\s*minos\s+(\S+)', build, re.M)
assert minimums == ['13.0'], minimums
libraries = subprocess.check_output(['otool', '-L', str(binary)], text=True)
print(libraries)
for line in libraries.splitlines()[1:]:
    dependency = line.strip().split(' (', 1)[0]
    assert dependency.startswith(('/System/Library/', '/usr/lib/', '@rpath/')), dependency
print(f"Verified app {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}), "
      'arm64, deployment target macOS 13.0, ad-hoc signature; no notarization claim.')
PY
