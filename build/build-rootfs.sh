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

DEBIAN_SUITE="${DEBIAN_SUITE:-stable}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

DEBOOTSTRAP_VERSION="${DEBOOTSTRAP_VERSION:-1.0.141}"

DEBOOTSTRAP_DEB="$CACHE_DIR/debootstrap.deb"
DEBOOTSTRAP_URL="https://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_${DEBOOTSTRAP_VERSION}_all.deb"

DEBOOTSTRAP_DIR="$WORK_DIR/debootstrap"
DEBOOTSTRAP_RUNTIME="$WORK_DIR/debootstrap-runtime"

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Termux check
# ------------------------------------------------------------

if [ -z "${PREFIX:-}" ]; then
    die "This builder must run inside Termux."
fi

if [ ! -d "$PREFIX" ]; then
    die "Invalid Termux PREFIX: $PREFIX"
fi

# ------------------------------------------------------------
# Architecture
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

echo "========================================"
echo "       Z-Linux RootFS Builder"
echo "========================================"
echo

echo "[+] Termux architecture : ${ZLINUX_TERMUX_ARCH:-unknown}"
echo "[+] Android ABI         : ${ZLINUX_ANDROID_ABI:-unknown}"
echo "[+] Z-Linux architecture: ${ZLINUX_ARCH:-unknown}"
echo "[+] Debian architecture  : $ARCH"
echo "[+] Debian suite         : $DEBIAN_SUITE"
echo "[+] Debian mirror        : $DEBIAN_MIRROR"
echo "[+] RootFS               : $ROOTFS_DIR"
echo

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

echo "[+] Checking dependencies..."

for cmd in bash wget file proot; do
    if ! command_exists "$cmd"; then
        die "Missing command: $cmd

Install it in Termux with:

    pkg install $cmd"
    fi
done

if command_exists bsdtar; then
    ARCHIVER="bsdtar"
elif command_exists ar && command_exists tar; then
    ARCHIVER="ar"
else
    die "No supported archive extractor found.

Install bsdtar:

    pkg install bsdtar"
fi

echo "[+] Dependencies OK."
echo "[+] Archive tool: $ARCHIVER"
echo

# ------------------------------------------------------------
# Directories
# ------------------------------------------------------------

mkdir -p "$ROOTFS_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$WORK_DIR"

# ------------------------------------------------------------
# Existing rootfs
# ------------------------------------------------------------

if [ -d "$ROOTFS_DIR/usr" ] ||
   [ -d "$ROOTFS_DIR/bin" ] ||
   [ -d "$ROOTFS_DIR/etc" ]; then

    if [ "${ZLINUX_FORCE:-0}" != "1" ]; then
        die "Existing rootfs detected.

For a clean rebuild:

    ZLINUX_FORCE=1 ./build/build-rootfs.sh"
    fi

    echo "[+] Removing existing rootfs..."
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
fi

# ------------------------------------------------------------
# Download debootstrap
# ------------------------------------------------------------

if [ -f "$DEBOOTSTRAP_DEB" ] &&
   [ ! -s "$DEBOOTSTRAP_DEB" ]; then

    echo "[!] Removing empty debootstrap cache..."
    rm -f "$DEBOOTSTRAP_DEB"
fi

if [ ! -f "$DEBOOTSTRAP_DEB" ]; then

    echo "========================================"
    echo "       Downloading debootstrap"
    echo "========================================"
    echo

    echo "[+] Version : $DEBOOTSTRAP_VERSION"
    echo "[+] URL     : $DEBOOTSTRAP_URL"
    echo

    wget \
        --https-only \
        --continue \
        -O "$DEBOOTSTRAP_DEB" \
        "$DEBOOTSTRAP_URL"
else
    echo "[+] Using cached debootstrap."
fi

[ -s "$DEBOOTSTRAP_DEB" ] ||
    die "debootstrap package is empty."

echo
echo "[+] debootstrap package:"
file "$DEBOOTSTRAP_DEB"
echo

# ------------------------------------------------------------
# Extract debootstrap package
# ------------------------------------------------------------

echo "========================================"
echo "       Extracting debootstrap"
echo "========================================"
echo

rm -rf "$WORK_DIR/extract"
rm -rf "$DEBOOTSTRAP_DIR"

mkdir -p "$WORK_DIR/extract"
mkdir -p "$DEBOOTSTRAP_DIR"

if [ "$ARCHIVER" = "bsdtar" ]; then

    bsdtar \
        -xf "$DEBOOTSTRAP_DEB" \
        -C "$WORK_DIR/extract"

else

    (
        cd "$WORK_DIR/extract"
        ar x "$DEBOOTSTRAP_DEB"
    )

fi

DATA_ARCHIVE=""

for archive in \
    "$WORK_DIR/extract/data.tar.gz" \
    "$WORK_DIR/extract/data.tar.xz" \
    "$WORK_DIR/extract/data.tar.zst" \
    "$WORK_DIR/extract/data.tar.lz4"
do

    if [ -f "$archive" ]; then
        DATA_ARCHIVE="$archive"
        break
    fi

done

[ -n "$DATA_ARCHIVE" ] ||
    die "Could not find debootstrap data archive."

echo "[+] Data archive: $(basename "$DATA_ARCHIVE")"

if command_exists bsdtar; then

    bsdtar \
        -xf "$DATA_ARCHIVE" \
        -C "$DEBOOTSTRAP_DIR"

else

    tar \
        -xf "$DATA_ARCHIVE" \
        -C "$DEBOOTSTRAP_DIR"

fi

# ------------------------------------------------------------
# Locate debootstrap
# ------------------------------------------------------------

DEBOOTSTRAP_BIN="$DEBOOTSTRAP_DIR/usr/sbin/debootstrap"
DEBOOTSTRAP_LIB="$DEBOOTSTRAP_DIR/usr/share/debootstrap"

[ -f "$DEBOOTSTRAP_BIN" ] ||
    die "debootstrap executable not found."

[ -d "$DEBOOTSTRAP_LIB" ] ||
    die "debootstrap support directory not found."

chmod +x "$DEBOOTSTRAP_BIN"

echo "[+] debootstrap ready."
echo "    $DEBOOTSTRAP_BIN"
echo

# ------------------------------------------------------------
# Prepare runtime
# ------------------------------------------------------------

echo "========================================"
echo "       Preparing Bootstrap Runtime"
echo "========================================"
echo

rm -rf "$DEBOOTSTRAP_RUNTIME"

mkdir -p \
    "$DEBOOTSTRAP_RUNTIME/usr/sbin" \
    "$DEBOOTSTRAP_RUNTIME/usr/share"

cp \
    "$DEBOOTSTRAP_BIN" \
    "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap"

cp -a \
    "$DEBOOTSTRAP_LIB" \
    "$DEBOOTSTRAP_RUNTIME/usr/share/"

chmod +x \
    "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap"

echo "[+] Runtime prepared."
echo

# ------------------------------------------------------------
# First stage
# ------------------------------------------------------------

echo "========================================"
echo "       Debian First Stage"
echo "========================================"
echo

echo "[+] Bootstrapping Debian..."
echo "[+] Suite        : $DEBIAN_SUITE"
echo "[+] Architecture: $ARCH"
echo

proot \
    -0 \
    -r "$DEBOOTSTRAP_RUNTIME" \
    -b "$ROOTFS_DIR:/target" \
    -w / \
    /usr/sbin/debootstrap \
    --foreign \
    --arch="$ARCH" \
    --variant=minbase \
    "$DEBIAN_SUITE" \
    /target \
    "$DEBIAN_MIRROR"

echo
echo "[+] First stage completed."
echo

# ------------------------------------------------------------
# Verify first stage
# ------------------------------------------------------------

[ -d "$ROOTFS_DIR/debootstrap" ] ||
    die "First stage failed: /debootstrap missing."

[ -f "$ROOTFS_DIR/debootstrap/debootstrap" ] ||
    die "First stage failed: second-stage script missing."

echo "[+] First-stage rootfs verified."
echo

# ------------------------------------------------------------
# Configure sources
# ------------------------------------------------------------

echo "[+] Configuring Debian repositories..."

mkdir -p "$ROOTFS_DIR/etc/apt"

cat > "$ROOTFS_DIR/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR $DEBIAN_SUITE main
deb $DEBIAN_MIRROR ${DEBIAN_SUITE}-updates main
deb https://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
EOF

# ------------------------------------------------------------
# Host configuration
# ------------------------------------------------------------

echo "[+] Configuring hostname..."

echo "zlinux" > "$ROOTFS_DIR/etc/hostname"

cat > "$ROOTFS_DIR/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 zlinux

::1 localhost ip6-localhost ip6-loopback
EOF

# ------------------------------------------------------------
# DNS
# ------------------------------------------------------------

echo "[+] Configuring DNS..."

cat > "$ROOTFS_DIR/etc/resolv.conf" <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# ------------------------------------------------------------
# proot arguments
# ------------------------------------------------------------

PROOT_ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -w /
)

# Android / Termux /dev
if [ -d /dev ]; then
    PROOT_ARGS+=(
        -b /dev:/dev
    )
fi

# Termux DNS
if [ -f "$PREFIX/etc/resolv.conf" ]; then
    PROOT_ARGS+=(
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
    )
fi

# ------------------------------------------------------------
# Second stage
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Debian Second Stage"
echo "========================================"
echo

proot \
    "${PROOT_ARGS[@]}" \
    /debootstrap/debootstrap \
    --second-stage

echo
echo "[+] Second stage completed."
echo

# ------------------------------------------------------------
# Debian configuration
# ------------------------------------------------------------

echo "========================================"
echo "       Configuring Debian"
echo "========================================"
echo

proot \
    "${PROOT_ARGS[@]}" \
    /bin/bash -c '

set -e

export DEBIAN_FRONTEND=noninteractive

echo "[+] Updating package lists..."

apt-get update

echo "[+] Installing base utilities..."

apt-get install -y \
    bash \
    coreutils \
    procps \
    iproute2 \
    iputils-ping \
    net-tools \
    curl \
    wget \
    ca-certificates \
    nano \
    vim-tiny \
    less \
    sudo \
    passwd \
    locales \
    tzdata \
    apt-utils

echo "[+] Configuring locale..."

if command -v locale-gen >/dev/null 2>&1; then

    if [ -f /etc/locale.gen ]; then
        sed -i \
            "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" \
            /etc/locale.gen || true
    fi

    locale-gen || true
fi

echo "LANG=en_US.UTF-8" > /etc/default/locale

echo "[+] Cleaning apt cache..."

apt-get clean

rm -rf /var/lib/apt/lists/*

echo "[+] Debian configuration complete."
'

# ------------------------------------------------------------
# Create launcher
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Creating Z-Linux Launcher"
echo "========================================"
echo

LAUNCHER="$ROOT_DIR/zlinux"

cat > "$LAUNCHER" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

[ -d "$ROOTFS_DIR" ] ||
    die "Z-Linux rootfs not found."

command -v proot >/dev/null 2>&1 ||
    die "proot is not installed.

Install it with:

    pkg install proot"

ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -w /root
)

[ -d /dev ] && ARGS+=(
    -b /dev:/dev
)

[ -f "$PREFIX/etc/resolv.conf" ] && ARGS+=(
    -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
)

export HOME=/root
export TERM="${TERM:-xterm-256color}"

exec proot \
    "${ARGS[@]}" \
    /bin/bash \
    --login
EOF

chmod +x "$LAUNCHER"

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Z-Linux RootFS Verification"
echo "========================================"
echo

echo "[+] Expected architecture: $ARCH"

ACTUAL_ARCH="$(
    proot \
        -0 \
        -r "$ROOTFS_DIR" \
        -w / \
        /bin/bash -c \
        'dpkg --print-architecture'
)"

echo "[+] RootFS architecture: $ACTUAL_ARCH"

if [ "$ACTUAL_ARCH" != "$ARCH" ]; then
    die "Architecture mismatch.

Expected : $ARCH
Detected : $ACTUAL_ARCH"
fi

echo
echo "[+] Debian version:"

proot \
    -0 \
    -r "$ROOTFS_DIR" \
    -w / \
    /bin/bash -c \
    'cat /etc/debian_version'

echo
echo "========================================"
echo "              BUILD DONE"
echo "========================================"
echo

echo "[+] RootFS:"
echo "    $ROOTFS_DIR"
echo

echo "[+] Launcher:"
echo "    $LAUNCHER"
echo

echo "Start Z-Linux with:"
echo
echo "    ./zlinux"
echo
