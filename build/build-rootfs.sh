#!/data/data/com.termux/files/usr/bin/bash

set -e

# ============================================================
# Z-Linux Debian ARMHF RootFS Builder
# Termux / Android - rootless build
# ============================================================

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"
CACHE_DIR="$ROOT_DIR/.cache"
WORK_DIR="$ROOT_DIR/.work"

ARCH="armhf"
DEBIAN_SUITE="stable"
DEBIAN_MIRROR="https://deb.debian.org/debian"

DEBOOTSTRAP_VERSION="1.0.141"
DEBOOTSTRAP_DEB="$CACHE_DIR/debootstrap.deb"
DEBOOTSTRAP_URL="https://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_${DEBOOTSTRAP_VERSION}_all.deb"

DEBOOTSTRAP_DIR="$WORK_DIR/debootstrap"

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

die() {
    echo
    echo "[ERROR] $1"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

cleanup() {
    rm -rf "$WORK_DIR/extract"
}

trap cleanup EXIT

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

clear 2>/dev/null || true

echo "========================================"
echo "       Z-Linux RootFS Builder"
echo "========================================"
echo
echo "[+] Architecture : $ARCH"
echo "[+] Debian suite : $DEBIAN_SUITE"
echo "[+] Mirror       : $DEBIAN_MIRROR"
echo "[+] RootFS       : $ROOTFS_DIR"
echo

# ------------------------------------------------------------
# Check required Termux commands
# ------------------------------------------------------------

echo "[+] Checking Termux dependencies..."

for cmd in bash wget file tar proot; do
    if ! command_exists "$cmd"; then
        die "Missing command: $cmd

Install it with:

pkg install $cmd"
    fi
done

# bsdtar is useful for extracting Debian archives.
if command_exists bsdtar; then
    ARCHIVER="bsdtar"
elif command_exists ar; then
    ARCHIVER="ar"
else
    die "Neither bsdtar nor ar is installed.

Run:

pkg install bsdtar"
fi

echo "[+] Dependencies OK."
echo

# ------------------------------------------------------------
# Create directories
# ------------------------------------------------------------

mkdir -p "$ROOTFS_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$WORK_DIR"

# ------------------------------------------------------------
# Download debootstrap
# ------------------------------------------------------------

if [ -f "$DEBOOTSTRAP_DEB" ]; then
    echo "[+] Cached debootstrap found."

    if [ ! -s "$DEBOOTSTRAP_DEB" ]; then
        echo "[!] Cached file is empty."
        rm -f "$DEBOOTSTRAP_DEB"
    fi
fi

if [ ! -f "$DEBOOTSTRAP_DEB" ]; then

    echo "[+] Downloading debootstrap..."
    echo "[+] URL: $DEBOOTSTRAP_URL"
    echo

    wget \
        --https-only \
        --continue \
        -O "$DEBOOTSTRAP_DEB" \
        "$DEBOOTSTRAP_URL"

fi

[ -s "$DEBOOTSTRAP_DEB" ] ||
    die "debootstrap download is empty."

echo
echo "[+] debootstrap downloaded."
file "$DEBOOTSTRAP_DEB"
echo

# ------------------------------------------------------------
# Extract debootstrap Debian package
# ------------------------------------------------------------

echo "[+] Extracting debootstrap package..."

rm -rf "$WORK_DIR/extract"
mkdir -p "$WORK_DIR/extract"

if [ "$ARCHIVER" = "bsdtar" ]; then

    bsdtar -xf "$DEBOOTSTRAP_DEB" \
        -C "$WORK_DIR/extract"

else

    (
        cd "$WORK_DIR/extract"
        ar x "$DEBOOTSTRAP_DEB"
    )

fi

# Find data archive.
DATA_ARCHIVE=""

for candidate in \
    "$WORK_DIR/extract/data.tar.xz" \
    "$WORK_DIR/extract/data.tar.gz" \
    "$WORK_DIR/extract/data.tar.zst" \
    "$WORK_DIR/extract/data.tar.lz4"
do
    if [ -f "$candidate" ]; then
        DATA_ARCHIVE="$candidate"
        break
    fi
done

if [ -z "$DATA_ARCHIVE" ]; then
    die "Could not find data archive inside debootstrap.deb."
fi

echo "[+] Data archive: $(basename "$DATA_ARCHIVE")"

rm -rf "$DEBOOTSTRAP_DIR"
mkdir -p "$DEBOOTSTRAP_DIR"

if command_exists bsdtar; then
    bsdtar -xf "$DATA_ARCHIVE" \
        -C "$DEBOOTSTRAP_DIR"
else
    tar -xf "$DATA_ARCHIVE" \
        -C "$DEBOOTSTRAP_DIR"
fi

# ------------------------------------------------------------
# Locate debootstrap executable
# ------------------------------------------------------------

DEBOOTSTRAP_BIN=""

if [ -x "$DEBOOTSTRAP_DIR/usr/sbin/debootstrap" ]; then
    DEBOOTSTRAP_BIN="$DEBOOTSTRAP_DIR/usr/sbin/debootstrap"
elif [ -f "$DEBOOTSTRAP_DIR/usr/sbin/debootstrap" ]; then
    chmod +x "$DEBOOTSTRAP_DIR/usr/sbin/debootstrap"
    DEBOOTSTRAP_BIN="$DEBOOTSTRAP_DIR/usr/sbin/debootstrap"
fi

if [ -z "$DEBOOTSTRAP_BIN" ]; then
    die "Could not locate usr/sbin/debootstrap."
fi

echo "[+] debootstrap ready:"
echo "    $DEBOOTSTRAP_BIN"
echo

# ------------------------------------------------------------
# Prevent accidental overwrite
# ------------------------------------------------------------

if [ -d "$ROOTFS_DIR/bin" ] ||
   [ -d "$ROOTFS_DIR/usr" ] ||
   [ -d "$ROOTFS_DIR/etc" ]; then

    echo "[!] Existing rootfs detected."
    echo

    if [ "${ZLINUX_FORCE:-0}" != "1" ]; then
        echo "Set ZLINUX_FORCE=1 if you want to rebuild it:"
        echo
        echo "    ZLINUX_FORCE=1 ./build-rootfs.sh"
        echo
        exit 1
    fi

    echo "[+] Rebuild requested."
    echo "[+] Removing existing rootfs..."

    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
fi

# ------------------------------------------------------------
# First-stage Debian bootstrap
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Debian First Stage"
echo "========================================"
echo

echo "[+] Bootstrapping Debian $DEBIAN_SUITE..."
echo "[+] Target architecture: $ARCH"
echo

"$DEBOOTSTRAP_BIN" \
    --foreign \
    --arch="$ARCH" \
    --variant=minbase \
    "$DEBIAN_SUITE" \
    "$ROOTFS_DIR" \
    "$DEBIAN_MIRROR"

echo
echo "[+] First stage completed."
echo

# ------------------------------------------------------------
# Verify rootfs
# ------------------------------------------------------------

if [ ! -x "$ROOTFS_DIR/debootstrap/debootstrap" ]; then
    die "First stage did not create /debootstrap/debootstrap."
fi

if [ ! -d "$ROOTFS_DIR/usr" ]; then
    die "Debian /usr directory is missing."
fi

# ------------------------------------------------------------
# Configure Debian repositories
# ------------------------------------------------------------

echo "[+] Configuring Debian repositories..."

mkdir -p "$ROOTFS_DIR/etc/apt"

cat > "$ROOTFS_DIR/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR $DEBIAN_SUITE main
deb $DEBIAN_MIRROR ${DEBIAN_SUITE}-updates main
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
EOF

# ------------------------------------------------------------
# Configure hostname
# ------------------------------------------------------------

echo "zlinux" > "$ROOTFS_DIR/etc/hostname"

cat > "$ROOTFS_DIR/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 zlinux

::1 localhost ip6-localhost ip6-loopback
EOF

# ------------------------------------------------------------
# DNS configuration
# ------------------------------------------------------------

echo "[+] Configuring DNS..."

mkdir -p "$ROOTFS_DIR/etc"

cat > "$ROOTFS_DIR/etc/resolv.conf" <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# ------------------------------------------------------------
# Prepare second stage
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Debian Second Stage"
echo "========================================"
echo

echo "[+] Preparing rootless execution..."
echo

# proot does not require Android root.
#
# -0          fake root inside Debian
# -r          root filesystem
# -b          bind host files where needed
# -w          working directory

PROOT_ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -w /
    -b /dev
)

# Bind Termux DNS resolver if available.
if [ -f "$PREFIX/etc/resolv.conf" ]; then
    PROOT_ARGS+=(
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
    )
fi

echo "[+] Running Debian second stage..."
echo

proot "${PROOT_ARGS[@]}" \
    /debootstrap/debootstrap \
    --second-stage

echo
echo "[+] Debian second stage completed."
echo

# ------------------------------------------------------------
# Basic Debian configuration through proot
# ------------------------------------------------------------

echo "[+] Performing initial Debian configuration..."

proot "${PROOT_ARGS[@]}" \
    /bin/bash -c '

set -e

export DEBIAN_FRONTEND=noninteractive

echo "[+] Updating package indexes..."

apt-get update

echo "[+] Installing essential packages..."

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
    dialog \
    apt-utils

echo "[+] Generating locale..."

if command -v locale-gen >/dev/null 2>&1; then
    sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" \
        /etc/locale.gen || true

    locale-gen || true
fi

echo "LANG=en_US.UTF-8" > /etc/default/locale

echo "[+] Setting hostname..."

echo "zlinux" > /etc/hostname

echo "[+] Cleaning package cache..."

apt-get clean

rm -rf /var/lib/apt/lists/*

echo "[+] Debian configuration complete."
'

# ------------------------------------------------------------
# Create Z-Linux launcher
# ------------------------------------------------------------

echo "[+] Creating Z-Linux launcher..."

LAUNCHER="$ROOT_DIR/zlinux"

cat > "$LAUNCHER" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "[ERROR] Z-Linux rootfs does not exist."
    exit 1
fi

command -v proot >/dev/null 2>&1 || {
    echo "[ERROR] proot is not installed."
    echo "Run: pkg install proot"
    exit 1
}

PROOT_ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -w /root
    -b /dev
)

if [ -d /proc ]; then
    PROOT_ARGS+=(
        -b /proc:/proc
    )
fi

if [ -d /sys ]; then
    PROOT_ARGS+=(
        -b /sys:/sys
    )
fi

if [ -f "$PREFIX/etc/resolv.conf" ]; then
    PROOT_ARGS+=(
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
    )
fi

exec proot \
    "${PROOT_ARGS[@]}" \
    /bin/bash \
    --login
EOF

chmod +x "$LAUNCHER"

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Z-Linux RootFS Complete"
echo "========================================"
echo

echo "[+] RootFS:"
echo "    $ROOTFS_DIR"
echo

echo "[+] Launcher:"
echo "    $LAUNCHER"
echo

echo "[+] Checking Debian..."

proot \
    -0 \
    -r "$ROOTFS_DIR" \
    -w / \
    /bin/bash -c '
echo "Debian: $(cat /etc/debian_version 2>/dev/null || echo unknown)"
echo "Architecture: $(dpkg --print-architecture 2>/dev/null || echo unknown)"
echo "Kernel: $(uname -r)"
'

echo
echo "========================================"
echo "              BUILD DONE"
echo "========================================"
echo
echo "Start Z-Linux with:"
echo
echo "    $ROOT_DIR/zlinux"
echo
echo "If you want a completely fresh rebuild:"
echo
echo "    ZLINUX_FORCE=1 ./build-rootfs.sh"
echo
