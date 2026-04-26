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

# Parse arguments
NO_CLEAN=0
ARCH=""
for arg in "$@"; do
    case "$arg" in
        --no-clean) NO_CLEAN=1 ;;
        --arch=*) ARCH="${arg#--arch=}" ;;
    esac
done

if [[ -n "$ARCH" && "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo "error: --arch must be arm64 or x86_64" >&2
    exit 1
fi

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="${PACKAGE_DIR}/BRLTTY"
# Arch-specific builds go to .build/brltty-<arch>/; native (unqualified) stays at .build/brltty/.
BUILD_DIR="${PACKAGE_DIR}/.build/brltty${ARCH:+-$ARCH}"

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

if [[ "$NO_CLEAN" -eq 0 ]]; then
    echo "==> Running autogen..."
    ./autogen

    # Arch-specific flags: export as env vars so configure picks them up without
    # requiring an array (arrays with spaces break under bash 3.2 set -u when
    # passed as positional arguments). Configure respects CFLAGS/CXXFLAGS/LDFLAGS
    # from the environment identically to VAR=value command-line arguments.
    # On Apple Silicon, Rosetta 2 runs x86_64 configure-test binaries so
    # --host is not needed; the tests execute natively through Rosetta.
    if [[ -n "$ARCH" ]]; then
        export CFLAGS="-arch ${ARCH}"
        export CXXFLAGS="-arch ${ARCH}"
        export LDFLAGS="-arch ${ARCH}"
    fi

    if [[ "$ARCH" == "x86_64" ]]; then
        # All Homebrew libraries on Apple Silicon are arm64-only. For the x86_64
        # cross-build we only need libbrlapi.dylib, so block the two routes
        # configure uses to discover optional Homebrew packages:
        #   1. pkg-config: clear LIBDIR (replaces compiled-in default) and PATH
        #      so every package query returns "not found" while the binary itself
        #      remains callable (PKG_CONFIG=/usr/bin/false failed the version check)
        #   2. tclsh: set TCLSH to a real binary that produces no output — autoconf
        #      uses a pre-set non-empty TCLSH without searching PATH, and when
        #      BRLTTY runs `false tclcmd config` it gets empty output → TCL_OK=false
        export PKG_CONFIG_LIBDIR=""
        export PKG_CONFIG_PATH=""
        export TCLSH=/usr/bin/false
    fi

    echo "==> Configuring${ARCH:+ (arch=${ARCH})}..."
    rm -rf "${BUILD_DIR}"
    mkdir "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    "${REPO_DIR}/configure" \
        --without-libbraille \
        --without-espeak-ng \
        --without-flite \
        --without-speechd \
        --with-screen-driver=no \
        --with-api-socket-dir=/var/run \
        --disable-x

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
