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
# ============================================================
# Dependency checks
# ============================================================

echo "[+] Checking Termux dependencies..."

for cmd in bash wget file proot; do
    if ! command_exists "$cmd"; then
        die "Missing command: $cmd

Install it with:

    pkg install $cmd"
    fi
done

if command_exists bsdtar; then
    ARCHIVER="bsdtar"
elif command_exists ar && command_exists tar; then
    ARCHIVER="ar"
else
    die "No supported archive extractor found.

Install bsdtar with:

    pkg install bsdtar"
fi

echo "[+] Dependencies OK."
echo

# ============================================================
# Profile definitions
# ============================================================

PROFILE_SECURITY="security"
PROFILE_DEVELOPER="developer"
PROFILE_DOCUMENTATION="documentation"
PROFILE_ENTERTAINMENT="entertainment"

SELECTED_PROFILES=()

profile_description() {
    case "$1" in
        security)
            echo "Ethical hacking, penetration testing and security research"
            ;;
        developer)
            echo "Programming, software engineering and development"
            ;;
        documentation)
            echo "Office work, technical writing and documentation"
            ;;
        entertainment)
            echo "Video editing, graphics, audio and multimedia"
            ;;
        *)
            echo "Unknown profile"
            ;;
    esac
}

profile_file() {
    case "$1" in
        security)
            echo "$EDITIONS_DIR/security.txt"
            ;;
        developer)
            echo "$EDITIONS_DIR/developer.txt"
            ;;
        documentation)
            echo "$EDITIONS_DIR/documentation.txt"
            ;;
        entertainment)
            echo "$EDITIONS_DIR/entertainment.txt"
            ;;
        *)
            return 1
            ;;
    esac
}

valid_profile() {
    case "$1" in
        security|developer|documentation|entertainment)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}