#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "========================================"
echo "             Z-Linux Bootstrap"
echo "========================================"
echo

# Check Termux
if [ -z "$PREFIX" ]; then
    echo "[ERROR] This script must run inside Termux."
    exit 1
fi

echo "[+] Termux detected"
echo "[+] PREFIX: $PREFIX"

# Detect architecture
ARCH="$(uname -m)"
TERMUX_ARCH="$(dpkg --print-architecture)"
ANDROID_ABI="$(getprop ro.product.cpu.abi 2>/dev/null || true)"

echo
echo "[+] Kernel architecture : $ARCH"
echo "[+] Termux architecture : $TERMUX_ARCH"
echo "[+] Android ABI         : $ANDROID_ABI"

# Check proot-distro
if command -v proot-distro >/dev/null 2>&1; then
    echo "[+] proot-distro found"
else
    echo "[!] proot-distro is not installed."
    echo
    echo "Install it with:"
    echo "  pkg install proot-distro"
    exit 1
fi

echo
echo "========================================"
echo "       Environment check complete"
echo "========================================"
