#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

============================================================

Z-Linux Debian RootFS Builder

Termux / Android - rootless proot build



Features:

- Automatic architecture detection

- Debian rootfs bootstrap

- Pre-install profile wizard

- Multi-select profiles

- Hardware-aware package filtering

- Z-Linux "get" package manager

============================================================

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

============================================================

Helpers

============================================================

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

============================================================

Termux validation

============================================================

if [ -z "${PREFIX:-}" ]; then
die "This builder must run inside Termux."
fi

if [ ! -d "$PREFIX" ]; then
die "Invalid Termux PREFIX: $PREFIX"
fi

============================================================

Architecture

============================================================

if [ ! -f "$DETECT_ARCH" ]; then
die "Architecture detector not found:
$DETECT_ARCH"
fi

shellcheck source=/dev/null

source "$DETECT_ARCH"

ARCH="$ZLINUX_DEBIAN_ARCH"

case "$ARCH" in
armhf|arm64|amd64|i386)
;;
*)
die "Unsupported Debian architecture: $ARCH"
;;
esac

============================================================

Banner

============================================================

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

============================================================

Dependencies

============================================================

echo "[+] Checking Termux dependencies..."

for cmd in bash wget file proot; do
if ! command_exists "$cmd"; then
die "Missing command: $cmd

Install with:

pkg install $cmd"  
fi

done

if command_exists bsdtar; then
ARCHIVER="bsdtar"
elif command_exists ar && command_exists tar; then
ARCHIVER="ar"
else
die "No supported archive extractor found.

Install:

pkg install bsdtar"

fi

echo "[+] Dependencies OK."
echo

============================================================

Profile definitions

============================================================

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

============================================================

Profile selection

============================================================

select_profiles() {

echo "================================================"  
echo "            Z-LINUX PROFILE SETUP"  
echo "================================================"  
echo  
echo "Choose what this Z-Linux installation will be"  
echo "optimized for."  
echo  
echo "You can select multiple profiles."  
echo  
echo "  1) Security"  
echo "     Ethical hacking / security research"  
echo  
echo "  2) Developer"  
echo "     Programming / software development"  
echo  
echo "  3) Documentation"  
echo "     Office / technical documentation"  
echo  
echo "  4) Entertainment"  
echo "     Video / audio / graphics / multimedia"  
echo  
echo "  5) All profiles"  
echo  
echo "------------------------------------------------"  
echo  

local input=""  

if [ -n "${ZLINUX_PROFILES:-}" ]; then  

    input="$ZLINUX_PROFILES"  

    echo "[+] Profiles supplied through ZLINUX_PROFILES:"  
    echo "    $input"  
    echo  

elif [ "${ZLINUX_NONINTERACTIVE:-0}" = "1" ]; then  

    input="developer"  

    echo "[+] Non-interactive mode."  
    echo "[+] Default profile: developer"  
    echo  

else  

    while true; do  

        printf "Select profile(s) [1-5, e.g. 1,2]: "  
        read -r input  

        [ -n "$input" ] && break  

        echo  
        echo "[!] Please select at least one profile."  
    done  
fi  

input="$(printf '%s' "$input" | tr ',' ' ')"  

for item in $input; do  

    case "$item" in  

        1)  
            item="security"  
            ;;  

        2)  
            item="developer"  
            ;;  

        3)  
            item="documentation"  
            ;;  

        4)  
            item="entertainment"  
            ;;  

        5|all)  
            SELECTED_PROFILES=(  
                security  
                developer  
                documentation  
                entertainment  
            )  
            return 0  
            ;;  

    esac  

    item="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')"  

    if ! valid_profile "$item"; then  
        die "Unknown profile: $item"  
    fi  

    # Prevent duplicates.  
    local exists=0  

    for selected in "${SELECTED_PROFILES[@]}"; do  
        if [ "$selected" = "$item" ]; then  
            exists=1  
            break  
        fi  
    done  

    if [ "$exists" -eq 0 ]; then  
        SELECTED_PROFILES+=("$item")  
    fi  
done  

[ "${#SELECTED_PROFILES[@]}" -gt 0 ] ||  
    die "No profiles selected."

}

============================================================

Hardware detection

============================================================

detect_hardware() {

CPU_CORES="$(  
    getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1  
)"  

if [ -r /proc/meminfo ]; then  
    MEMORY_MB="$(  
        awk '/MemTotal:/ {  
            printf "%d", $2 / 1024  
        }' /proc/meminfo  
    )"  
else  
    MEMORY_MB=0  
fi  

if command_exists df; then  
    STORAGE_AVAILABLE="$(  
        df -Pm "$ROOT_DIR" 2>/dev/null |  
        awk 'NR==2 {print $4}'  
    )"  
else  
    STORAGE_AVAILABLE=0  
fi  

echo "================================================"  
echo "             HARDWARE DETECTION"  
echo "================================================"  
echo  
echo "  Architecture : ${ZLINUX_ARCH:-unknown}"  
echo "  CPU cores    : $CPU_CORES"  
echo "  Memory       : ${MEMORY_MB} MB"  
echo "  Free storage : ${STORAGE_AVAILABLE} MB"  
echo  

if [ "$MEMORY_MB" -gt 0 ] && [ "$MEMORY_MB" -lt 2048 ]; then  
    echo "[!] Low-memory device detected."  
    echo "[!] Heavy desktop packages may be skipped."  
    echo  
fi

}

============================================================

Package hardware filter

============================================================

hardware_allows_package() {

local package="$1"  

# Allow disabling hardware filtering.  
if [ "${ZLINUX_HW_AUTO:-1}" = "0" ]; then  
    return 0  
fi  

# --------------------------------------------------------  
# RAM < 2 GB  
# --------------------------------------------------------  

if [ "$MEMORY_MB" -gt 0 ] &&  
   [ "$MEMORY_MB" -lt 2048 ]; then  

    case "$package" in  
        blender)  
            return 1  
            ;;  

        kdenlive)  
            return 1  
            ;;  

        obs-studio)  
            return 1  
            ;;  

        libreoffice)  
            return 1  
            ;;  

        docker.io)  
            return 1  
            ;;  

        docker-compose)  
            return 1  
            ;;  
    esac  
fi  

# --------------------------------------------------------  
# Single-core systems  
# --------------------------------------------------------  

if [ "$CPU_CORES" -lt 2 ]; then  

    case "$package" in  
        blender)  
            return 1  
            ;;  

        kdenlive)  
            return 1  
            ;;  

        obs-studio)  
            return 1  
            ;;  

        docker.io)  
            return 1  
            ;;  
    esac  
fi  

return 0

}

============================================================

Profile package resolver

============================================================

collect_profile_packages() {

local profile="$1"  
local file  

file="$(profile_file "$profile")"  

[ -f "$file" ] ||  
    die "Profile file missing:

$file"

while IFS= read -r package || [ -n "$package" ]; do  

    # Remove comments.  
    package="${package%%#*}"  

    # Trim whitespace.  
    package="$(printf '%s' "$package" |  
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"  

    [ -n "$package" ] || continue  

    if hardware_allows_package "$package"; then  

        PROFILE_PACKAGES+=("$package")  

    else  

        echo "[HW] Skipping heavy package: $package"  
    fi  

done < "$file"

}

============================================================

Resolve selected profiles

============================================================

resolve_profiles() {

PROFILE_PACKAGES=()  

echo "================================================"  
echo "             PROFILE RESOLUTION"  
echo "================================================"  
echo  

for profile in "${SELECTED_PROFILES[@]}"; do  

    echo "[+] $profile"  
    echo "    $(profile_description "$profile")"  

    collect_profile_packages "$profile"  

    echo  
done  

# Deduplicate package list.  
if [ "${#PROFILE_PACKAGES[@]}" -gt 0 ]; then  

    mapfile -t PROFILE_PACKAGES < <(  
        printf '%s\n' "${PROFILE_PACKAGES[@]}" |  
        sort -u  
    )  
fi  

echo "[+] Packages selected: ${#PROFILE_PACKAGES[@]}"  
echo

}

============================================================

Show installation plan

============================================================

show_installation_plan() {

echo "================================================"  
echo "              INSTALLATION PLAN"  
echo "================================================"  
echo  

echo "Profiles:"  
for profile in "${SELECTED_PROFILES[@]}"; do  
    echo "  [+] $profile"  
done  

echo  
echo "Packages: ${#PROFILE_PACKAGES[@]}"  
echo  

if [ "${ZLINUX_AUTO_CONFIRM:-0}" = "1" ]; then  
    return 0  
fi  

if [ "${ZLINUX_NONINTERACTIVE:-0}" = "1" ]; then  
    return 0  
fi  

printf "Continue with this configuration? [Y/n]: "  
read -r answer  

case "${answer:-Y}" in  
    n|N|no|NO)  
        echo  
        echo "[Z-Linux] Installation cancelled."  
        exit 0  
        ;;  
esac  

echo

}

============================================================

Bootstrap Debian

============================================================

prepare_directories() {

mkdir -p "$ROOTFS_DIR"  
mkdir -p "$CACHE_DIR"  
mkdir -p "$WORK_DIR"

}

download_debootstrap() {

echo "================================================"  
echo "             DEBOOTSTRAP SETUP"  
echo "================================================"  
echo  

if [ ! -f "$DEBOOTSTRAP_DEB" ]; then  

    echo "[+] Downloading debootstrap..."  
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

}

extract_debootstrap() {

rm -rf "$WORK_DIR/extract"  
rm -rf "$DEBOOTSTRAP_DIR"  

mkdir -p "$WORK_DIR/extract"  
mkdir -p "$DEBOOTSTRAP_DIR"  

echo "[+] Extracting debootstrap..."  

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

if command_exists bsdtar; then  

    bsdtar \  
        -xf "$DATA_ARCHIVE" \  
        -C "$DEBOOTSTRAP_DIR"  

else  

    tar \  
        -xf "$DATA_ARCHIVE" \  
        -C "$DEBOOTSTRAP_DIR"  

fi

}

prepare_debootstrap_runtime() {

DEBOOTSTRAP_BIN="$DEBOOTSTRAP_DIR/usr/sbin/debootstrap"  
DEBOOTSTRAP_LIB="$DEBOOTSTRAP_DIR/usr/share/debootstrap"  

[ -f "$DEBOOTSTRAP_BIN" ] ||  
    die "debootstrap executable not found."  

[ -d "$DEBOOTSTRAP_LIB" ] ||  
    die "debootstrap support files not found."  

chmod +x "$DEBOOTSTRAP_BIN"  

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

}

============================================================

Rootfs creation

============================================================

create_rootfs() {

echo  
echo "================================================"  
echo "              CREATING DEBIAN ROOTFS"  
echo "================================================"  
echo  

if [ -d "$ROOTFS_DIR/usr" ] ||  
   [ -d "$ROOTFS_DIR/etc" ]; then  

    if [ "${ZLINUX_FORCE:-0}" != "1" ]; then  

        die "Existing rootfs detected.

Use:

ZLINUX_FORCE=1 ./build/build-rootfs.sh"  

    fi  

    rm -rf "$ROOTFS_DIR"  
    mkdir -p "$ROOTFS_DIR"  
fi  

echo "[+] Debian architecture: $ARCH"  
echo "[+] Suite: $DEBIAN_SUITE"  
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

[ -f "$ROOTFS_DIR/debootstrap/debootstrap" ] ||  
    die "Debian first stage failed."  

echo  
echo "[+] Debian first stage complete."  

proot \  
    -0 \  
    -r "$ROOTFS_DIR" \  
    -w / \  
    /debootstrap/debootstrap \  
    --second-stage  

echo  
echo "[+] Debian second stage complete."

}

============================================================

proot rootfs arguments

============================================================

rootfs_proot_args() {

PROOT_ROOT_ARGS=(  
    -0  
    -r "$ROOTFS_DIR"  
    -w /  
)  

if [ -d /dev ]; then  
    PROOT_ROOT_ARGS+=(  
        -b /dev:/dev  
    )  
fi  

if [ -f "$PREFIX/etc/resolv.conf" ]; then  
    PROOT_ROOT_ARGS+=(  
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"  
    )  
fi

}

============================================================

Base Debian configuration

============================================================

configure_debian() {

rootfs_proot_args  

echo  
echo "================================================"  
echo "              CONFIGURING DEBIAN"  
echo "================================================"  
echo  

mkdir -p "$ROOTFS_DIR/etc/apt"  

cat > "$ROOTFS_DIR/etc/apt/sources.list" <<EOF

deb $DEBIAN_MIRROR $DEBIAN_SUITE main
deb $DEBIAN_MIRROR ${DEBIAN_SUITE}-updates main
deb https://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
EOF

echo "zlinux" > "$ROOTFS_DIR/etc/hostname"  

cat > "$ROOTFS_DIR/etc/hosts" <<EOF

127.0.0.1 localhost
127.0.1.1 zlinux
::1 localhost ip6-localhost ip6-loopback
EOF

cat > "$ROOTFS_DIR/etc/resolv.conf" <<EOF

nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

proot \  
    "${PROOT_ROOT_ARGS[@]}" \  
    /bin/bash -c '

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update

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

echo "LANG=en_US.UTF-8" > /etc/default/locale

if command -v locale-gen >/dev/null 2>&1; then
sed -i \
"s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" \
/etc/locale.gen || true

locale-gen || true

fi
'
}

============================================================

Install Z-Linux "get"

============================================================

install_get() {

echo  
echo "================================================"  
echo "          INSTALLING Z-LINUX PACKAGE MANAGER"  
echo "================================================"  
echo  

if [ ! -f "$GET_SCRIPT" ]; then  
    die "Z-Linux get script not found:

$GET_SCRIPT"
fi

mkdir -p "$ROOTFS_DIR/usr/local/bin"  

cp \  
    "$GET_SCRIPT" \  
    "$ROOTFS_DIR/usr/local/bin/get"  

chmod +x \  
    "$ROOTFS_DIR/usr/local/bin/get"  

echo "[+] Installed:"  
echo "    /usr/local/bin/get"

}

==============================
# ============================================================
# Install selected profile packages
# ============================================================

install_profile_packages() {

    echo
    echo "================================================"
    echo "          INSTALLING PROFILE PACKAGES"
    echo "================================================"
    echo

    if [ "${#PROFILE_PACKAGES[@]}" -eq 0 ]; then
        echo "[!] No profile packages selected."
        return 0
    fi

    rootfs_proot_args

    # Create a temporary package list inside the rootfs.
    : > "$ROOTFS_DIR/tmp/zlinux-packages.txt"

    printf '%s\n' "${PROFILE_PACKAGES[@]}" \
        > "$ROOTFS_DIR/tmp/zlinux-packages.txt"

    echo "[+] Package list:"
    echo

    sed 's/^/    /' \
        "$ROOTFS_DIR/tmp/zlinux-packages.txt"

    echo

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '

set -e

export DEBIAN_FRONTEND=noninteractive

if [ ! -s /tmp/zlinux-packages.txt ]; then
    exit 0
fi

echo "[+] Refreshing package lists..."
apt-get update

echo
echo "[+] Installing selected packages..."

while IFS= read -r package; do

    [ -n "$package" ] || continue

    echo
    echo "------------------------------------------------"
    echo "[GET] Installing: $package"
    echo "------------------------------------------------"

    if apt-cache show "$package" >/dev/null 2>&1; then

        apt-get install -y \
            --no-install-recommends \
            "$package"

    else

        echo "[WARN] Package not available: $package"
        echo "[WARN] Continuing..."
    fi

done < /tmp/zlinux-packages.txt

apt-get clean

rm -rf \
    /var/lib/apt/lists/*

echo
echo "[+] Profile package installation complete."
'

    rm -f "$ROOTFS_DIR/tmp/zlinux-packages.txt"
}

# ============================================================
# Create Z-Linux configuration
# ============================================================

create_zlinux_config() {

    echo
    echo "================================================"
    echo "          CREATING Z-LINUX CONFIGURATION"
    echo "================================================"
    echo

    mkdir -p \
        "$ROOTFS_DIR/etc/zlinux" \
        "$ROOTFS_DIR/var/lib/zlinux"

    cat > "$ROOTFS_DIR/etc/zlinux/zlinux.conf" <<EOF
# ============================================================
# Z-Linux configuration
# ============================================================

ZLINUX_NAME="Z-Linux"
ZLINUX_VERSION="1.0"
ZLINUX_ARCH="$ARCH"
ZLINUX_DEBIAN_SUITE="$DEBIAN_SUITE"

ZLINUX_CPU_CORES="$CPU_CORES"
ZLINUX_MEMORY_MB="$MEMORY_MB"

ZLINUX_MIRROR="$DEBIAN_MIRROR"

ZLINUX_HW_AUTO="${ZLINUX_HW_AUTO:-1}"
EOF

    {
        echo "# Selected Z-Linux profiles"
        for profile in "${SELECTED_PROFILES[@]}"; do
            echo "$profile"
        done
    } > "$ROOTFS_DIR/etc/zlinux/profiles"

    {
        echo "# Z-Linux package manifest"
        printf '%s\n' "${PROFILE_PACKAGES[@]}"
    } > "$ROOTFS_DIR/etc/zlinux/packages"

    cat > "$ROOTFS_DIR/etc/zlinux/build-info" <<EOF
ZLINUX_BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
ZLINUX_ARCH="$ARCH"
ZLINUX_SUITE="$DEBIAN_SUITE"
ZLINUX_DEBOOTSTRAP_VERSION="$DEBOOTSTRAP_VERSION"
ZLINUX_CPU_CORES="$CPU_CORES"
ZLINUX_MEMORY_MB="$MEMORY_MB"
EOF

    echo "[+] Configuration written."
}

# ============================================================
# Configure Z-Linux get
# ============================================================

configure_get() {

    echo
    echo "================================================"
    echo "             CONFIGURING Z-LINUX GET"
    echo "================================================"
    echo

    [ -f "$ROOTFS_DIR/usr/local/bin/get" ] ||
        die "get was not installed."

    rootfs_proot_args

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '

set -e

GET="/usr/local/bin/get"

if [ ! -x "$GET" ]; then
    chmod +x "$GET"
fi

# Make get available to normal users.
ln -sf /usr/local/bin/get /usr/bin/get

# Create a basic shell completion directory.
mkdir -p /etc/bash_completion.d

if grep -q "Z-Linux get" "$GET" 2>/dev/null; then
    :
fi
'

    echo "[+] get configured."
}

# ============================================================
# Create Z-Linux user
# ============================================================

create_zlinux_user() {

    echo
    echo "================================================"
    echo "             CREATING Z-LINUX USER"
    echo "================================================"
    echo

    rootfs_proot_args

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '

set -e

USERNAME="${ZLINUX_USER:-zlinux}"

if ! id "$USERNAME" >/dev/null 2>&1; then

    useradd \
        -m \
        -s /bin/bash \
        "$USERNAME"

fi

# Give the Z-Linux user a useful home directory.
mkdir -p "/home/$USERNAME"

chown -R "$USERNAME:$USERNAME" \
    "/home/$USERNAME" 2>/dev/null || true

# Add sudo support if available.
if command -v usermod >/dev/null 2>&1; then
    usermod -aG sudo "$USERNAME" 2>/dev/null || true
fi

# Disable password authentication by default.
passwd -d "$USERNAME" 2>/dev/null || true

echo "$USERNAME" > /etc/zlinux/default-user
'

    echo "[+] Default user: zlinux"
}

# ============================================================
# Shell environment
# ============================================================

configure_shell_environment() {

    echo
    echo "================================================"
    echo "            CONFIGURING SHELL ENVIRONMENT"
    echo "================================================"
    echo

    mkdir -p "$ROOTFS_DIR/etc/profile.d"

    cat > "$ROOTFS_DIR/etc/profile.d/zlinux.sh" <<'EOF'
# ============================================================
# Z-Linux shell environment
# ============================================================

export ZLINUX=1

export ZLINUX_CONFIG="/etc/zlinux/zlinux.conf"

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

export EDITOR="${EDITOR:-nano}"

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

if command -v get >/dev/null 2>&1; then
    export ZLINUX_GET="/usr/local/bin/get"
fi
EOF

    cat > "$ROOTFS_DIR/etc/bash.bashrc" <<'EOF'
# /etc/bash.bashrc

[ -z "$PS1" ] && return

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

if [ -f /etc/zlinux/zlinux.conf ]; then
    . /etc/zlinux/zlinux.conf
fi

echo
echo "---------------------------------------------"
echo "              Z-LINUX"
echo "---------------------------------------------"
echo " Type 'get help' for package management."
echo "---------------------------------------------"
echo
EOF

    echo "[+] Shell environment configured."
}

# ============================================================
# Configure DNS
# ============================================================

configure_dns() {

    echo
    echo "================================================"
    echo "                 CONFIGURING DNS"
    echo "================================================"
    echo

    mkdir -p "$ROOTFS_DIR/etc"

    cat > "$ROOTFS_DIR/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

    echo "[+] DNS configured."
}

# ============================================================
# Configure APT
# ============================================================

configure_apt() {

    echo
    echo "================================================"
    echo "                 CONFIGURING APT"
    echo "================================================"
    echo

    mkdir -p "$ROOTFS_DIR/etc/apt/apt.conf.d"

    cat > "$ROOTFS_DIR/etc/apt/apt.conf.d/99zlinux" <<'EOF'
Acquire::Retries "3";
Acquire::http::Pipeline-Depth "0";
Acquire::Languages "none";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

    echo "[+] APT optimized for Z-Linux."
}

# ============================================================
# Configure timezone
# ============================================================

configure_timezone() {

    echo
    echo "================================================"
    echo "              CONFIGURING TIMEZONE"
    echo "================================================"
    echo

    rootfs_proot_args

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '

set -e

if [ -d /usr/share/zoneinfo/Africa/Nairobi ]; then

    ln -sf \
        /usr/share/zoneinfo/Africa/Nairobi \
        /etc/localtime

    echo "Africa/Nairobi" > /etc/timezone

fi
'

    echo "[+] Timezone configured."
}

# ============================================================
# Create launcher
# ============================================================

create_launcher() {

    echo
    echo "================================================"
    echo "             CREATING Z-LINUX LAUNCHER"
    echo "================================================"
    echo

    mkdir -p "$ROOT_DIR"

    cat > "$ROOT_DIR/start-zlinux.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "[ERROR] Z-Linux rootfs not found:"
    echo "$ROOTFS_DIR"
    exit 1
fi

if ! command -v proot >/dev/null 2>&1; then
    echo "[ERROR] proot is not installed."
    echo
    echo "Install it with:"
    echo
    echo "    pkg install proot"
    exit 1
fi

ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -w /root
)

# Termux / Android pseudo-filesystems.
if [ -d /dev ]; then
    ARGS+=(
        -b /dev:/dev
    )
fi

if [ -d /proc ]; then
    ARGS+=(
        -b /proc:/proc
    )
fi

if [ -d /sys ]; then
    ARGS+=(
        -b /sys:/sys
    )
fi

if [ -f "$PREFIX/etc/resolv.conf" ]; then
    ARGS+=(
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
    )
fi

# Give Z-Linux access to the current Termux home.
if [ -d "$HOME" ]; then
    mkdir -p "$ROOTFS_DIR/mnt/termux"

    ARGS+=(
        -b "$HOME:/mnt/termux"
    )
fi

# Android temporary directory.
if [ -d /tmp ]; then
    ARGS+=(
        -b /tmp:/tmp
    )
fi

exec proot \
    "${ARGS[@]}" \
    /bin/bash \
    --login
EOF

    chmod +x "$ROOT_DIR/start-zlinux.sh"

    echo "[+] Launcher created:"
    echo "    $ROOT_DIR/start-zlinux.sh"
}

# ============================================================
# Create rootfs helper
# ============================================================

create_rootfs_helpers() {

    echo
    echo "================================================"
    echo "              CREATING ROOTFS HELPERS"
    echo "================================================"
    echo

    mkdir -p \
        "$ROOTFS_DIR/usr/local/sbin" \
        "$ROOTFS_DIR/usr/local/bin"

    cat > "$ROOTFS_DIR/usr/local/bin/zlinux-info" <<'EOF'
#!/bin/bash

echo
echo "=============================================="
echo "                 Z-LINUX"
echo "=============================================="

if [ -f /etc/zlinux/zlinux.conf ]; then
    cat /etc/zlinux/zlinux.conf
fi

echo
echo "Profiles:"
if [ -f /etc/zlinux/profiles ]; then
    grep -v '^#' /etc/zlinux/profiles
fi

echo
echo "Architecture:"
dpkg --print-architecture 2>/dev/null || true

echo
echo "Kernel:"
uname -a

echo
EOF

    chmod +x \
        "$ROOTFS_DIR/usr/local/bin/zlinux-info"

    cat > "$ROOTFS_DIR/usr/local/bin/zlinux-update" <<'EOF'
#!/bin/bash

set -e

echo "[+] Updating Z-Linux package indexes..."

apt-get update

echo
echo "[+] Upgrading installed packages..."

apt-get upgrade -y

echo
echo "[+] Cleaning package cache..."

apt-get clean

echo
echo "[+] Z-Linux update complete."
EOF

    chmod +x \
        "$ROOTFS_DIR/usr/local/bin/zlinux-update"

    echo "[+] Helper commands created:"
    echo "    zlinux-info"
    echo "    zlinux-update"
}

# ============================================================
# Remove temporary build files
# ============================================================

cleanup_rootfs() {

    echo
    echo "================================================"
    echo "                ROOTFS CLEANUP"
    echo "================================================"
    echo

    rm -rf \
        "$ROOTFS_DIR/tmp/"* \
        "$ROOTFS_DIR/var/tmp/"* 2>/dev/null || true

    rm -rf \
        "$ROOTFS_DIR/var/cache/apt/archives/"*.deb 2>/dev/null || true

    rm -rf \
        "$ROOTFS_DIR/var/lib/apt/lists/"* 2>/dev/null || true

    rm -f \
        "$ROOTFS_DIR/root/.bash_history" 2>/dev/null || true

    echo "[+] Rootfs cleanup complete."
}

# ============================================================
# Validate rootfs
# ============================================================

validate_rootfs() {

    echo
    echo "================================================"
    echo "               ROOTFS VALIDATION"
    echo "================================================"
    echo

    local failed=0

    local required_paths=(
        "$ROOTFS_DIR/bin"
        "$ROOTFS_DIR/etc"
        "$ROOTFS_DIR/usr"
        "$ROOTFS_DIR/var"
        "$ROOTFS_DIR/etc/apt"
        "$ROOTFS_DIR/usr/bin/bash"
        "$ROOTFS_DIR/usr/bin/apt-get"
        "$ROOTFS_DIR/usr/local/bin/get"
        "$ROOTFS_DIR/etc/zlinux/zlinux.conf"
    )

    for path in "${required_paths[@]}"; do

        if [ -e "$path" ]; then

            echo "[OK] $path"

        else

            echo "[FAIL] Missing: $path"
            failed=1

        fi

    done

    echo

    if [ "$failed" -ne 0 ]; then
        die "Rootfs validation failed."
    fi

    rootfs_proot_args

    echo "[+] Testing rootfs execution..."

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
set -e

echo "[TEST] bash: OK"
echo "[TEST] dpkg architecture: $(dpkg --print-architecture)"
echo "[TEST] get: $(command -v get)"
echo "[TEST] zlinux-info: $(command -v zlinux-info)"
'

    echo
    echo "[+] Rootfs validation successful."
}

# ============================================================
# Generate build manifest
# ============================================================

generate_manifest() {

    echo
    echo "================================================"
    echo "              GENERATING MANIFEST"
    echo "================================================"
    echo

    mkdir -p "$ROOT_DIR"

    {
        echo "================================================"
        echo "Z-LINUX BUILD MANIFEST"
        echo "================================================"
        echo
        echo "Build date:"
        date -u '+%Y-%m-%dT%H:%M:%SZ'
        echo
        echo "Architecture:"
        echo "$ARCH"
        echo
        echo "Debian suite:"
        echo "$DEBIAN_SUITE"
        echo
        echo "Debian mirror:"
        echo "$DEBIAN_MIRROR"
        echo
        echo "CPU cores:"
        echo "$CPU_CORES"
        echo
        echo "Memory:"
        echo "${MEMORY_MB} MB"
        echo
        echo "Profiles:"
        for profile in "${SELECTED_PROFILES[@]}"; do
            echo "  - $profile"
        done
        echo
        echo "Packages:"
        for package in "${PROFILE_PACKAGES[@]}"; do
            echo "  - $package"
        done
        echo
        echo "================================================"
    } > "$ROOT_DIR/Z-Linux-build-manifest.txt"

    echo "[+] Manifest:"
    echo "    $ROOT_DIR/Z-Linux-build-manifest.txt"
}

# ============================================================
# Rootfs size
# ============================================================

show_rootfs_size() {

    echo
    echo "================================================"
    echo "                ROOTFS SIZE"
    echo "================================================"
    echo

    if command_exists du; then

        du -sh "$ROOTFS_DIR" 2>/dev/null ||
            true

    fi

    echo
}

# ============================================================
# Final summary
# ============================================================

final_summary() {

    echo
    echo "================================================"
    echo "             Z-LINUX BUILD COMPLETE"
    echo "================================================"
    echo

    echo "Architecture : $ARCH"
    echo "Debian suite : $DEBIAN_SUITE"
    echo "Profiles     : ${#SELECTED_PROFILES[@]}"
    echo "Packages     : ${#PROFILE_PACKAGES[@]}"
    echo

    echo "Rootfs:"
    echo "  $ROOTFS_DIR"
    echo

    echo "Launcher:"
    echo "  $ROOT_DIR/start-zlinux.sh"
    echo

    echo "Manifest:"
    echo "  $ROOT_DIR/Z-Linux-build-manifest.txt"
    echo

    echo "------------------------------------------------"
    echo "To start Z-Linux:"
    echo
    echo "    ./start-zlinux.sh"
    echo
    echo "Inside Z-Linux:"
    echo
    echo "    zlinux-info"
    echo "    get help"
    echo "    zlinux-update"
    echo "------------------------------------------------"
    echo

    echo "[+] Z-Linux is ready."
}

# ============================================================
# Build cleanup
# ============================================================

cleanup_build_workspace() {

    echo
    echo "[+] Cleaning temporary bootstrap files..."

    rm -rf \
        "$WORK_DIR/extract" \
        "$DEBOOTSTRAP_DIR" \
        "$DEBOOTSTRAP_RUNTIME"

    echo "[+] Build workspace cleaned."
}

# ============================================================
# Main build sequence
# ============================================================

main() {

    prepare_directories

    select_profiles

    detect_hardware

    resolve_profiles

    show_installation_plan

    download_debootstrap

    extract_debootstrap

    prepare_debootstrap_runtime

    create_rootfs

    configure_debian

    configure_apt

    configure_dns

    configure_timezone

    install_get

    configure_get

    install_profile_packages

    create_zlinux_config

    create_zlinux_user

    configure_shell_environment

    create_rootfs_helpers

    create_launcher

    cleanup_rootfs

    validate_rootfs

    generate_manifest

    show_rootfs_size

    cleanup_build_workspace

    final_summary
}

# ============================================================
# Execute
# ============================================================

main "$@"