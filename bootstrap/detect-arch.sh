#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "========================================"
echo "       Z-Linux Architecture Detector"
echo "========================================"
echo

UNAME_ARCH="$(uname -m)"
TERMUX_ARCH="$(dpkg --print-architecture)"
ANDROID_ABI="$(getprop ro.product.cpu.abi 2>/dev/null || true)"

echo "[+] Kernel architecture : $UNAME_ARCH"
echo "[+] Termux architecture : $TERMUX_ARCH"
echo "[+] Android ABI         : $ANDROID_ABI"
echo

case "$TERMUX_ARCH" in
    arm)
        ZLINUX_ARCH="arm"
        ZLINUX_DEBIAN_ARCH="armhf"
        ;;

    arm64)
        ZLINUX_ARCH="arm64"
        ZLINUX_DEBIAN_ARCH="arm64"
        ;;

    amd64)
        ZLINUX_ARCH="amd64"
        ZLINUX_DEBIAN_ARCH="amd64"
        ;;

    i386)
        ZLINUX_ARCH="i386"
        ZLINUX_DEBIAN_ARCH="i386"
        ;;

    *)
        echo "[ERROR] Unsupported Termux architecture: $TERMUX_ARCH"
        exit 1
        ;;
esac

echo "[+] Z-Linux architecture : $ZLINUX_ARCH"
echo "[+] Debian architecture   : $ZLINUX_DEBIAN_ARCH"
echo

export ZLINUX_ARCH
export ZLINUX_DEBIAN_ARCH
