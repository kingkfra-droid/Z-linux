#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

# ============================================================
# Z-Linux Debian RootFS Builder
# Termux / Android - rootless proot build
# ============================================================

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

ROOTFS_DIR="$ROOT_DIR/rootfs"
CACHE_DIR="$ROOT_DIR/.cache"
WORK_DIR="$ROOT_DIR/.work"

BOOTSTRAP_DIR="$ROOT_DIR/bootstrap"
DETECT_ARCH="$BOOTSTRAP_DIR/detect-arch.sh"

EDITIONS_DIR="$ROOT_DIR/editions"
GET_SCRIPT="$ROOT_DIR/scripts/get"

DEBIAN_SUITE="${DEBIAN_SUITE:-stable}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

DEBOOTSTRAP_VERSION="${DEBOOTSTRAP_VERSION:-1.0.141}"

DEBOOTSTRAP_DEB="$CACHE_DIR/debootstrap.deb"

DEBOOTSTRAP_URL="https://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_${DEBOOTSTRAP_VERSION}_all.deb"

DEBOOTSTRAP_DIR="$WORK_DIR/debootstrap"
DEBOOTSTRAP_RUNTIME="$WORK_DIR/debootstrap-runtime"

export DEBIAN_FRONTEND=noninteractive

# ============================================================
# Helpers
# ============================================================

die() {
    echo
    echo "[ERROR] $*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

cleanup_on_error() {
    echo
    echo "[ERROR] Z-Linux rootfs build failed."
    echo "[ERROR] Check the message above."
}

trap cleanup_on_error ERR

# ============================================================
# Termux validation
# ============================================================

if [ -z "${PREFIX:-}" ]; then
    die "This builder must run inside Termux."
fi

if [ ! -d "$PREFIX" ]; then
    die "Invalid Termux PREFIX: $PREFIX"
fi

# ============================================================
# Architecture detection
# ============================================================

if [ ! -f "$DETECT_ARCH" ]; then
    die "Architecture detector not found:
$DETECT_ARCH"
fi

# shellcheck source=/dev/null
source "$DETECT_ARCH"

ARCH="$ZLINUX_DEBIAN_ARCH"

case "$ARCH" in
    armhf|arm64|amd64|i386)
        ;;
    *)
        die "Unsupported Debian architecture: $ARCH"
        ;;
esac

# ============================================================
# Banner
# ============================================================

clear 2>/dev/null || true

echo "================================================"
echo "                 Z-LINUX BUILDER"
echo "================================================"
echo
echo "  Debian-based Linux environment for Android"
echo
echo "------------------------------------------------"
echo "  Termux architecture : ${ZLINUX_TERMUX_ARCH:-unknown}"
echo "  Android ABI         : ${ZLINUX_ANDROID_ABI:-unknown}"
echo "  Z-Linux architecture: ${ZLINUX_ARCH:-unknown}"
echo "  Debian architecture : $ARCH"
echo "  Debian suite        : $DEBIAN_SUITE"
echo "------------------------------------------------"
echo