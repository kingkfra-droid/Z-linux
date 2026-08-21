#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT_ARCH="$ROOT_DIR/bootstrap/detect-arch.sh"

echo "========================================"
echo "             Z-Linux Bootstrap"
echo "========================================"
echo

die() {
    echo
    echo "[ERROR] $*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# Verify Termux
# ------------------------------------------------------------

if [ -z "${PREFIX:-}" ]; then
    die "This script must run inside Termux."
fi

if [ ! -d "$PREFIX" ]; then
    die "Termux PREFIX does not exist: $PREFIX"
fi

echo "[+] Termux detected"
echo "[+] PREFIX: $PREFIX"

# ------------------------------------------------------------
# Check basic Termux tools
# ------------------------------------------------------------

echo
echo "[+] Checking Termux environment..."

REQUIRED_COMMANDS=(
    bash
    dpkg
    uname
)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command_exists "$cmd"; then
        die "Required command missing: $cmd"
    fi
done

echo "[+] Basic Termux environment OK."

# ------------------------------------------------------------
# Architecture
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Detecting Architecture"
echo "========================================"
echo

if [ ! -f "$DETECT_ARCH" ]; then
    die "Architecture detector not found:
$DETECT_ARCH"
fi

# shellcheck source=/dev/null
source "$DETECT_ARCH"

# ------------------------------------------------------------
# Build dependencies
# ------------------------------------------------------------

echo "========================================"
echo "       Checking Build Dependencies"
echo "========================================"
echo

MISSING=()

for cmd in bash wget proot file; do
    if ! command_exists "$cmd"; then
        MISSING+=("$cmd")
    fi
done

# We can use bsdtar or ar + tar depending on what Termux provides.
if command_exists bsdtar; then
    ARCHIVE_TOOL="bsdtar"
elif command_exists ar && command_exists tar; then
    ARCHIVE_TOOL="ar"
else
    MISSING+=("bsdtar")
    ARCHIVE_TOOL=""
fi

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "[!] Missing Termux packages/tools:"
    printf '    %s\n' "${MISSING[@]}"
    echo
    echo "Install the common dependencies with:"
    echo
    echo "    pkg update"
    echo "    pkg install bash wget proot file bsdtar"
    echo
    echo "Note:"
    echo "Z-Linux does NOT require proot-distro."
    exit 1
fi

echo "[+] proot       : $(command -v proot)"
echo "[+] wget        : $(command -v wget)"
echo "[+] file        : $(command -v file)"
echo "[+] archive     : $ARCHIVE_TOOL"

# ------------------------------------------------------------
# Optional tools
# ------------------------------------------------------------

echo
echo "[+] Checking optional tools..."

if command_exists getprop; then
    echo "[+] Android getprop: available"
else
    echo "[!] Android getprop: unavailable"
fi

if command_exists termux-info; then
    echo "[+] termux-info: available"
else
    echo "[!] termux-info: unavailable"
fi

# ------------------------------------------------------------
# Storage
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Storage / Environment"
echo "========================================"
echo

if command_exists df; then
    df -h "$ROOT_DIR" 2>/dev/null || true
fi

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Environment Check Complete"
echo "========================================"
echo

echo "[+] Z-Linux architecture : $ZLINUX_ARCH"
echo "[+] Debian architecture   : $ZLINUX_DEBIAN_ARCH"
echo "[+] Termux architecture   : ${ZLINUX_TERMUX_ARCH:-unknown}"
echo "[+] Android ABI           : ${ZLINUX_ANDROID_ABI:-unknown}"
echo

echo "Ready to build Z-Linux."
echo
echo "Run:"
echo
echo "    ./build/build-rootfs.sh"
echo
