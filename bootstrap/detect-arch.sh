#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

echo "========================================"
echo "       Z-Linux Architecture Detector"
echo "========================================"
echo

die() {
    echo
    echo "[ERROR] $*" >&2
    exit 1
}

command -v uname >/dev/null 2>&1 || die "uname is unavailable."
command -v dpkg >/dev/null 2>&1 || die "dpkg is unavailable. Install Termux base packages first."

UNAME_ARCH="$(uname -m 2>/dev/null || true)"
TERMUX_ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
ANDROID_ABI="$(getprop ro.product.cpu.abi 2>/dev/null || true)"
ANDROID_ABI2="$(getprop ro.product.cpu.abi2 2>/dev/null || true)"

echo "[+] Kernel architecture : ${UNAME_ARCH:-unknown}"
echo "[+] Termux architecture : ${TERMUX_ARCH:-unknown}"
echo "[+] Android ABI         : ${ANDROID_ABI:-unknown}"
[ -n "$ANDROID_ABI2" ] && \
    echo "[+] Android ABI 2       : $ANDROID_ABI2"
echo

ZLINUX_ARCH=""
ZLINUX_DEBIAN_ARCH=""

# Prefer Termux's package architecture because it describes
# the architecture of the userspace actually running in Termux.
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
        # Fallback to uname/Android ABI.
        case "$UNAME_ARCH" in
            armv7l|armv8l|arm)
                ZLINUX_ARCH="arm"
                ZLINUX_DEBIAN_ARCH="armhf"
                ;;

            aarch64)
                ZLINUX_ARCH="arm64"
                ZLINUX_DEBIAN_ARCH="arm64"
                ;;

            x86_64)
                ZLINUX_ARCH="amd64"
                ZLINUX_DEBIAN_ARCH="amd64"
                ;;

            i686|i386)
                ZLINUX_ARCH="i386"
                ZLINUX_DEBIAN_ARCH="i386"
                ;;

            *)
                case "$ANDROID_ABI" in
                    armeabi-v7a)
                        ZLINUX_ARCH="arm"
                        ZLINUX_DEBIAN_ARCH="armhf"
                        ;;

                    arm64-v8a)
                        ZLINUX_ARCH="arm64"
                        ZLINUX_DEBIAN_ARCH="arm64"
                        ;;

                    x86_64)
                        ZLINUX_ARCH="amd64"
                        ZLINUX_DEBIAN_ARCH="amd64"
                        ;;

                    x86)
                        ZLINUX_ARCH="i386"
                        ZLINUX_DEBIAN_ARCH="i386"
                        ;;

                    *)
                        die "Unsupported architecture.

Kernel : ${UNAME_ARCH:-unknown}
Termux : ${TERMUX_ARCH:-unknown}
ABI    : ${ANDROID_ABI:-unknown}"
                        ;;
                esac
                ;;
        esac
        ;;
esac

echo "[+] Z-Linux architecture : $ZLINUX_ARCH"
echo "[+] Debian architecture   : $ZLINUX_DEBIAN_ARCH"
echo

# Export variables so scripts that source this file can use them.
export ZLINUX_ARCH
export ZLINUX_DEBIAN_ARCH
export ZLINUX_TERMUX_ARCH="$TERMUX_ARCH"
export ZLINUX_ANDROID_ABI="$ANDROID_ABI"

# Also print machine-readable values when requested.
if [ "${ZLINUX_ARCH_OUTPUT:-0}" = "1" ]; then
    printf 'ZLINUX_ARCH=%s\n' "$ZLINUX_ARCH"
    printf 'ZLINUX_DEBIAN_ARCH=%s\n' "$ZLINUX_DEBIAN_ARCH"
fi
