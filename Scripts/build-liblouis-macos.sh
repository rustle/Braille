#!/usr/bin/env bash
# build-liblouis-macos.sh — Build liblouis (including liblouis.dylib) on macOS.
#
# Prerequisites (install once):
#   brew install autoconf automake libtool
#
# Usage: (run from anywhere)
#   ./Scripts/build-liblouis-macos.sh            — full clean build
#   ./Scripts/build-liblouis-macos.sh --no-clean — skip autogen/configure if already done

set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${PACKAGE_DIR}/liblouis"
BUILD_DIR="${PACKAGE_DIR}/.build/liblouis"

export PATH="/Users/doug/brew/bin:${PATH}"

# Verify prerequisites
for tool in autoconf aclocal glibtoolize; do
    command -v "${tool}" &>/dev/null || { echo "error: ${tool} not found — run: brew install autoconf automake libtool"; exit 1; }
done

# autogen.sh calls libtoolize; on macOS Homebrew installs it as glibtoolize.
export LIBTOOLIZE=glibtoolize

cd "${REPO_DIR}"

if [[ "${1:-}" != "--no-clean" ]]; then
    echo "==> Running autogen..."
    ./autogen.sh

    echo "==> Configuring..."
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    "${REPO_DIR}/configure" \
        --prefix="${BUILD_DIR}" \
        --disable-nls \
        --disable-ucs4 \
        --enable-shared \
        --disable-static
else
    cd "${BUILD_DIR}"
fi

echo "==> Building ($(sysctl -n hw.logicalcpu) jobs)..."
make -j"$(sysctl -n hw.logicalcpu)"
make install

# Fix install name so rpath-based loading works in Swift packages.
echo "==> Fixing liblouis install name..."
DYLIB="${BUILD_DIR}/lib/liblouis.dylib"
install_name_tool -id "@rpath/liblouis.dylib" "${DYLIB}"

echo ""
echo "==> Build complete."
echo "    liblouis.h: ${BUILD_DIR}/include/liblouis/liblouis.h"
echo "    liblouis:   ${DYLIB}"
echo "    tables:     ${BUILD_DIR}/share/liblouis/tables/"
