#!/data/data/com.termux/files/usr/bin/bash

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"
CACHE_DIR="$ROOT_DIR/.cache"

ARCH="armhf"
DEBIAN_SUITE="stable"
DEBIAN_MIRROR="https://deb.debian.org/debian"

DEBOOTSTRAP_URL="https://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.141_all.deb"
DEBOOTSTRAP_DEB="$CACHE_DIR/debootstrap.deb"

echo "========================================"
echo "          Z-Linux RootFS Builder"
echo "========================================"
echo

mkdir -p "$ROOTFS_DIR" "$CACHE_DIR"

echo "[+] Architecture : $ARCH"
echo "[+] Debian suite  : $DEBIAN_SUITE"
echo "[+] Mirror        : $DEBIAN_MIRROR"
echo

# Remove an invalid cached download.
if [ -f "$DEBOOTSTRAP_DEB" ] && [ ! -s "$DEBOOTSTRAP_DEB" ]; then
    echo "[!] Cached debootstrap file is empty."
    echo "[+] Removing invalid cache..."
    rm -f "$DEBOOTSTRAP_DEB"
fi

if [ ! -f "$DEBOOTSTRAP_DEB" ]; then
    echo "[+] Downloading debootstrap..."
    wget --https-only -O "$DEBOOTSTRAP_DEB" "$DEBOOTSTRAP_URL"
fi

# Verify that wget actually produced data.
if [ ! -s "$DEBOOTSTRAP_DEB" ]; then
    echo "[ERROR] Download failed or produced an empty file."
    rm -f "$DEBOOTSTRAP_DEB"
    exit 1
fi

echo
echo "[+] Download complete."
echo "[+] File: $DEBOOTSTRAP_DEB"
echo

file "$DEBOOTSTRAP_DEB"

echo
echo "[+] Bootstrap download stage complete."

