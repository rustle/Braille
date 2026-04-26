#!/usr/bin/env bash
# Creates BrlAPI.xcframework from the BRLTTY build output.
#
# Usage:
#   ./Scripts/create-brlapi-xcframework.sh            — single-arch (native)
#   ./Scripts/create-brlapi-xcframework.sh --universal — arm64 + x86_64 fat binary
#   ./Scripts/create-brlapi-xcframework.sh --universal --no-clean
#
# Builds BRLTTY for each target architecture automatically unless --no-clean
# is passed (which reuses existing build outputs).
#
# For --universal on Apple Silicon: Rosetta 2 must be installed (it is by
# default) so configure test binaries for x86_64 execute via Rosetta.
#
# Output: BrlAPI.xcframework  +  BrlAPI.xcframework.zip (with SPM checksum)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
TABLES_DIR="$PACKAGE_DIR/liblouis/tables"
STAGING_DIR="$PACKAGE_DIR/.build/xcframework-staging"
OUTPUT="$PACKAGE_DIR/BrlAPI.xcframework"
ZIP_OUTPUT="$PACKAGE_DIR/BrlAPI.xcframework.zip"

UNIVERSAL=0
NO_CLEAN=0
for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=1 ;;
        --no-clean) NO_CLEAN=1 ;;
    esac
done

if [[ ! -d "$TABLES_DIR" ]]; then
    echo "error: liblouis/tables not found. Run 'git submodule update --init'." >&2
    exit 1
fi

# ── Build BRLTTY ──────────────────────────────────────────────────────────────

# Scalar (not array) so bash 3.2 set -u doesn't error on empty expansion.
# Unquoted $EXTRA_ARGS below is intentional: empty string passes no argument.
EXTRA_ARGS=""
[[ "$NO_CLEAN" -eq 1 ]] && EXTRA_ARGS="--no-clean"

if [[ "$UNIVERSAL" -eq 1 ]]; then
    echo "==> Building BRLTTY for arm64..."
    # shellcheck disable=SC2086
    "$SCRIPT_DIR/build-brltty-macos.sh" --arch=arm64 $EXTRA_ARGS
    echo "==> Building BRLTTY for x86_64..."
    # shellcheck disable=SC2086
    "$SCRIPT_DIR/build-brltty-macos.sh" --arch=x86_64 $EXTRA_ARGS
    ARM64_DYLIB="$PACKAGE_DIR/.build/brltty-arm64/Programs/libbrlapi.dylib"
    X86_64_DYLIB="$PACKAGE_DIR/.build/brltty-x86_64/Programs/libbrlapi.dylib"
    HEADERS_DIR="$PACKAGE_DIR/.build/brltty-arm64/Programs"
    for f in "$ARM64_DYLIB" "$X86_64_DYLIB"; do
        [[ -f "$f" ]] || { echo "error: $f not found" >&2; exit 1; }
    done
else
    if [[ "$NO_CLEAN" -eq 0 ]]; then
        echo "==> Building BRLTTY (native arch)..."
        # shellcheck disable=SC2086
        "$SCRIPT_DIR/build-brltty-macos.sh" $EXTRA_ARGS
    fi
    NATIVE_DYLIB="$PACKAGE_DIR/.build/brltty/Programs/libbrlapi.dylib"
    HEADERS_DIR="$PACKAGE_DIR/.build/brltty/Programs"
    [[ -f "$NATIVE_DYLIB" ]] || { echo "error: $NATIVE_DYLIB not found. Run build-brltty-macos.sh first." >&2; exit 1; }
fi

# ── Stage BrlAPI.framework ───────────────────────────────────────────────────

rm -rf "$STAGING_DIR" "$OUTPUT" "$ZIP_OUTPUT"
mkdir -p "$STAGING_DIR"

# macOS frameworks use a versioned bundle layout (Versions/A/), not the flat
# (shallow) layout used on iOS. The validator rejects Info.plist at the root.
FW="$STAGING_DIR/BrlAPI.framework"
FW_VER="$FW/Versions/A"
mkdir -p "$FW_VER/Headers" "$FW_VER/Modules" "$FW_VER/Resources"

# Versioning symlinks required by macOS
ln -s A "$FW/Versions/Current"
ln -s Versions/Current/BrlAPI "$FW/BrlAPI"
ln -s Versions/Current/Headers "$FW/Headers"
ln -s Versions/Current/Modules "$FW/Modules"
ln -s Versions/Current/Resources "$FW/Resources"

# Dylib — renamed to match the framework name; install name updated accordingly.
if [[ "$UNIVERSAL" -eq 1 ]]; then
    echo "==> Creating universal (fat) libbrlapi..."
    lipo -create "$ARM64_DYLIB" "$X86_64_DYLIB" -output "$FW_VER/BrlAPI"
else
    cp "$NATIVE_DYLIB" "$FW_VER/BrlAPI"
fi
install_name_tool -id "@rpath/BrlAPI.framework/BrlAPI" "$FW_VER/BrlAPI"

# Ad-hoc sign so Xcode can re-sign with --preserve-metadata=identifier when
# embedding the framework into the app bundle.
codesign --sign - --force --identifier com.rustle.BrlAPI "$FW_VER/BrlAPI"

# BrlAPI headers.
cp "$HEADERS_DIR"/brlapi*.h "$FW_VER/Headers/"

# Wrapper header: applies BRLAPI_NO_SINGLE_SESSION before including brlapi.h.
cat > "$FW_VER/Headers/CBrlAPI.h" << 'HEADER'
#ifndef CBrlAPI_h
#define CBrlAPI_h
#define BRLAPI_NO_SINGLE_SESSION
#include "brlapi.h"
#endif
HEADER

cat > "$FW_VER/Modules/module.modulemap" << 'MODULEMAP'
framework module BrlAPI {
    header "CBrlAPI.h"
    export *
}
MODULEMAP

cat > "$FW_VER/Resources/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.rustle.BrlAPI</string>
    <key>CFBundleName</key>
    <string>BrlAPI</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>MinimumOSVersion</key>
    <string>13.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
</dict>
</plist>
PLIST

# ── Create XCFramework ────────────────────────────────────────────────────────

echo "==> Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "$FW" \
    -output "$OUTPUT"

# ── Zip and checksum ──────────────────────────────────────────────────────────

(cd "$PACKAGE_DIR" && zip -qr "$ZIP_OUTPUT" BrlAPI.xcframework)

echo ""
echo "Checksum (paste into Package.swift binaryTarget):"
swift package --package-path "$PACKAGE_DIR" compute-checksum "$ZIP_OUTPUT"
echo ""
echo "Created:  $OUTPUT"
echo "Zip:      $ZIP_OUTPUT"
