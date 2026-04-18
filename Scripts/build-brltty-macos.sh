#!/usr/bin/env bash
# build-brltty-macos.sh — Build BRLTTY (including libbrlapi) on macOS.
#
# Two macOS-specific issues are patched here automatically:
#
#  1. configure uses `expr length` which is a GNU extension not present in
#     BSD expr. Fix: prepend GNU coreutils to PATH.
#
#  2. The darwin* branch in configure emits `-Wl,/usr/lib/dylib1.o` into
#     MKLIB. That file has not existed since macOS 10.7. Fix: strip it from
#     config.mk after configure runs.
#
# Prerequisites (install once):
#   brew install autoconf automake libtool pkg-config coreutils tcl-tk
#
# Usage: (run from anywhere)
#   ./Scripts/build-brltty-macos.sh            — full clean build
#   ./Scripts/build-brltty-macos.sh --no-clean — skip autogen/configure if already done

set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${PACKAGE_DIR}/BRLTTY"
BUILD_DIR="${PACKAGE_DIR}/.build/brltty"

# Homebrew GNU tools on PATH for this script only
GNU_BIN="/Users/doug/brew/opt/coreutils/libexec/gnubin"
TCL_BIN="/Users/doug/brew/opt/tcl-tk/bin"
export PATH="${TCL_BIN}:${GNU_BIN}:${PATH}"

# Verify prerequisites
for tool in autoconf aclocal tclsh expr; do
    command -v "${tool}" &>/dev/null || { echo "error: ${tool} not found — run: brew install autoconf automake libtool coreutils tcl-tk"; exit 1; }
done
expr length "test" &>/dev/null || { echo "error: GNU expr not on PATH (coreutils missing from PATH)"; exit 1; }

cd "${REPO_DIR}"

if [[ "${1:-}" != "--no-clean" ]]; then
    echo "==> Running autogen..."
    ./autogen

    echo "==> Configuring..."
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    "${REPO_DIR}/configure" \
        --without-libbraille \
        --without-espeak-ng \
        --without-flite \
        --without-speechd \
        --with-screen-driver=no \
        --with-api-socket-dir=/var/run

    # Patch 1: strip the non-existent dylib1.o from the MKLIB linker command.
    # configure's darwin* case unconditionally appends it even when it can't
    # find the file.
    echo "==> Patching config.mk (removing dylib1.o)..."
    sed -i '' 's|-Wl,/usr/lib/dylib1.o,|-Wl,|g' config.mk
else
    cd "${BUILD_DIR}"
fi

echo "==> Building ($(sysctl -n hw.logicalcpu) jobs)..."
make -j"$(sysctl -n hw.logicalcpu)"

echo "==> Building test tools (brltest, apitest)..."
make -C "${BUILD_DIR}/Programs" all-brltest all-apitest

# Fix libbrlapi install name so rpath-based loading works in Swift packages.
# BRLTTY's darwin* MKLIB sets a bare install name with no path prefix, which
# means the dynamic linker ignores LC_RPATH entries when resolving it.
echo "==> Fixing libbrlapi install name..."
install_name_tool -id "@rpath/libbrlapi.dylib.0.8" "${BUILD_DIR}/Programs/libbrlapi.dylib"

# Copy companion headers that brlapi.h includes by relative path.
# They live in the source tree's Programs/ and are not copied by make.
echo "==> Copying companion headers to .build/brltty/Programs/..."
for h in brlapi_keycodes.h brlapi_param.h brlapi_protocol.h brlapi_keyranges.h brlapi_common.h; do
    src="${REPO_DIR}/Programs/${h}"
    [ -f "${src}" ] && cp "${src}" "${BUILD_DIR}/Programs/${h}"
done

echo ""
echo "==> Build complete."
echo "    brltty:       ${BUILD_DIR}/Programs/brltty"
echo "    libbrlapi:    ${BUILD_DIR}/Programs/libbrlapi.dylib"
echo "    brlapi.h:     ${BUILD_DIR}/Programs/brlapi.h"
echo "    apitest:      ${BUILD_DIR}/Programs/apitest"
echo "    brltest:      ${BUILD_DIR}/Programs/brltest"
echo ""
echo "Smoke test:"
"${BUILD_DIR}/Programs/brltty" --version 2>&1 | grep "^BRLTTY"
