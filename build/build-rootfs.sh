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

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

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
# Dependencies
# ------------------------------------------------------------

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
else
    if ! command_exists ar; then
        die "Install bsdtar:

pkg install bsdtar"
    fi

    ARCHIVER="ar"
fi

echo "[+] Dependencies OK."
echo

# ------------------------------------------------------------
# Directories
# ------------------------------------------------------------

mkdir -p "$ROOTFS_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$WORK_DIR"

# ------------------------------------------------------------
# Download debootstrap
# ------------------------------------------------------------

if [ -f "$DEBOOTSTRAP_DEB" ] && [ ! -s "$DEBOOTSTRAP_DEB" ]; then
    echo "[!] Removing empty debootstrap cache..."
    rm -f "$DEBOOTSTRAP_DEB"
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
else
    echo "[+] Using cached debootstrap."
fi

[ -s "$DEBOOTSTRAP_DEB" ] ||
    die "debootstrap download is empty."

echo
echo "[+] debootstrap downloaded."
file "$DEBOOTSTRAP_DEB"
echo

# ------------------------------------------------------------
# Extract Debian package
# ------------------------------------------------------------

echo "[+] Extracting debootstrap package..."

rm -rf "$WORK_DIR/extract"
rm -rf "$DEBOOTSTRAP_DIR"

mkdir -p "$WORK_DIR/extract"
mkdir -p "$DEBOOTSTRAP_DIR"

if [ "$ARCHIVER" = "bsdtar" ]; then
    bsdtar -xf "$DEBOOTSTRAP_DEB" \
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
    die "Could not find data archive inside debootstrap.deb."

echo "[+] Data archive: $(basename "$DATA_ARCHIVE")"

if command_exists bsdtar; then
    bsdtar -xf "$DATA_ARCHIVE" \
        -C "$DEBOOTSTRAP_DIR"
else
    tar -xf "$DATA_ARCHIVE" \
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

echo "[+] debootstrap ready:"
echo "    $DEBOOTSTRAP_BIN"

echo "[+] Support files:"
echo "    $DEBOOTSTRAP_LIB"
echo

# ------------------------------------------------------------
# Check existing rootfs
# ------------------------------------------------------------

if [ -d "$ROOTFS_DIR/usr" ] ||
   [ -d "$ROOTFS_DIR/bin" ] ||
   [ -d "$ROOTFS_DIR/etc" ]; then

    if [ "${ZLINUX_FORCE:-0}" != "1" ]; then
        die "Existing rootfs detected.

For a clean rebuild:

ZLINUX_FORCE=1 ./build-rootfs.sh"
    fi

    echo "[+] Removing existing rootfs..."
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
fi

# ------------------------------------------------------------
# Prepare debootstrap runtime
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Preparing debootstrap"
echo "========================================"
echo

DEBOOTSTRAP_RUNTIME="$WORK_DIR/debootstrap-runtime"

rm -rf "$DEBOOTSTRAP_RUNTIME"

mkdir -p \
    "$DEBOOTSTRAP_RUNTIME/usr/sbin" \
    "$DEBOOTSTRAP_RUNTIME/usr/share"

cp "$DEBOOTSTRAP_BIN" \
    "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap"

cp -a "$DEBOOTSTRAP_LIB" \
    "$DEBOOTSTRAP_RUNTIME/usr/share/"

chmod +x \
    "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap"

echo "[+] Runtime prepared."

# ------------------------------------------------------------
# Debian first stage
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Debian First Stage"
echo "========================================"
echo

echo "[+] Bootstrapping Debian $DEBIAN_SUITE..."
echo "[+] Target architecture: $ARCH"
echo

# debootstrap expects its support files at /usr/share/debootstrap.
#
# proot gives it a temporary filesystem view where:
#
#   /usr/sbin/debootstrap
#   /usr/share/debootstrap/
#
# are available at their expected locations.

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
echo "[+] Debian first stage completed."
echo

# ------------------------------------------------------------
# Verify first stage
# ------------------------------------------------------------

if [ ! -d "$ROOTFS_DIR/debootstrap" ]; then
    die "First stage failed: /debootstrap was not created."
fi

if [ ! -f "$ROOTFS_DIR/debootstrap/debootstrap" ]; then
    die "First stage failed: second-stage script missing."
fi

echo "[+] First-stage rootfs verified."

# ------------------------------------------------------------
# Configure sources
# ------------------------------------------------------------

echo "[+] Creating Debian sources.list..."

mkdir -p "$ROOTFS_DIR/etc/apt"

cat > "$ROOTFS_DIR/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR $DEBIAN_SUITE main
deb $DEBIAN_MIRROR ${DEBIAN_SUITE}-updates main
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
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
# Second stage
# ------------------------------------------------------------

echo
echo "========================================"
echo "       Debian Second Stage"
echo "========================================"
echo

echo "[+] Running second stage through proot..."
echo

PROOT_ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -w /
)

# Android / Termux virtual filesystems
if [ -d /dev ]; then
    PROOT_ARGS+=(
        -b /dev:/dev
    )
fi

if [ -f "$PREFIX/etc/resolv.conf" ]; then
    PROOT_ARGS+=(
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
    )
fi

proot \
    "${PROOT_ARGS[@]}" \
    /debootstrap/debootstrap \
    --second-stage

echo
echo "[+] Debian second stage completed."
echo

# ------------------------------------------------------------
# Configure Debian
# ------------------------------------------------------------

echo "[+] Configuring Debian..."

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
    sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" \
        /etc/locale.gen || true

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
echo "[+] Creating Z-Linux launcher..."

LAUNCHER="$ROOT_DIR/zlinux"

cat > "$LAUNCHER" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "[ERROR] Z-Linux rootfs not found."
    exit 1
fi

if ! command -v proot >/dev/null 2>&1; then
    echo "[ERROR] proot is not installed."
    echo "Run: pkg install proot"
    exit 1
fi

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
echo "       Z-Linux RootFS Complete"
echo "========================================"
echo

echo "[+] RootFS:"
echo "    $ROOTFS_DIR"
echo

echo "[+] Launcher:"
echo "    $LAUNCHER"
echo

echo "[+] Debian architecture:"

proot \
    -0 \
    -r "$ROOTFS_DIR" \
    -w / \
    /bin/bash -c \
    'dpkg --print-architecture'

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
echo "Start Z-Linux with:"
echo
echo "    cd $ROOT_DIR"
echo "    ./zlinux"
echo
