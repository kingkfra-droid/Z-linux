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

# ============================================================
# Profile selection
# ============================================================

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
    local item=""
    local selected=""
    local exists=0

    if [ -n "${ZLINUX_PROFILES:-}" ]; then

        input="$ZLINUX_PROFILES"

        echo "[+] Profiles supplied through ZLINUX_PROFILES:"
        echo "    $input"
        echo

    elif [ "${ZLINUX_NONINTERACTIVE:-0}" = "1" ]; then

        input="1"

        echo "[+] Non-interactive mode."
        echo "[+] Defaulting to Security profile."
        echo

    else

        read -r -p "Select profile(s) [1-5, e.g. 1,2]: " input

    fi

    input="${input// /}"

    if [ "$input" = "5" ]; then

        SELECTED_PROFILES=(
            "$PROFILE_SECURITY"
            "$PROFILE_DEVELOPER"
            "$PROFILE_DOCUMENTATION"
            "$PROFILE_ENTERTAINMENT"
        )

        return 0

    fi

    IFS=',' read -ra selections <<< "$input"

    for selected in "${selections[@]}"; do

        case "$selected" in

            1)
                item="$PROFILE_SECURITY"
                ;;

            2)
                item="$PROFILE_DEVELOPER"
                ;;

            3)
                item="$PROFILE_DOCUMENTATION"
                ;;

            4)
                item="$PROFILE_ENTERTAINMENT"
                ;;

            security|developer|documentation|entertainment)
                item="$selected"
                ;;

            *)
                echo
                echo "[WARN] Invalid profile selection: $selected"
                continue
                ;;
        esac

        exists=0

        for existing in "${SELECTED_PROFILES[@]}"; do
            if [ "$existing" = "$item" ]; then
                exists=1
                break
            fi
        done

        if [ "$exists" -eq 0 ]; then
            SELECTED_PROFILES+=("$item")
        fi

    done

    if [ "${#SELECTED_PROFILES[@]}" -eq 0 ]; then
        die "No profiles selected."
    fi
}
# ============================================================
# Hardware detection
# ============================================================

detect_hardware() {

    CPU_CORES="$(
        getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1
    )"

    case "$CPU_CORES" in
        ''|*[!0-9]*)
            CPU_CORES=1
            ;;
    esac

    if [ -r /proc/meminfo ]; then

        MEMORY_MB="$(
            awk '
                /MemTotal:/ {
                    printf "%d", $2 / 1024
                    exit
                }
            ' /proc/meminfo
        )"

    else
        MEMORY_MB=0
    fi

    case "$MEMORY_MB" in
        ''|*[!0-9]*)
            MEMORY_MB=0
            ;;
    esac

    STORAGE_AVAILABLE=0

    echo "================================================"
    echo "             HARDWARE DETECTION"
    echo "================================================"
    echo
    echo "  Architecture : ${ZLINUX_ARCH:-unknown}"
    echo "  CPU cores    : $CPU_CORES"
    echo "  Memory       : ${MEMORY_MB} MB"
    echo "  Free storage : ${STORAGE_AVAILABLE} MB"
    echo

    if [ "$MEMORY_MB" -gt 0 ] &&
       [ "$MEMORY_MB" -lt 2048 ]; then

        echo "[!] Low-memory device detected."
        echo "[!] Heavy packages may be skipped."
        echo
    fi
}

# ============================================================
# Hardware-aware package filter
# ============================================================

hardware_allows_package() {

    local package="$1"

    if [ "${ZLINUX_HW_AUTO:-1}" = "0" ]; then
        return 0
    fi

    if [ "$MEMORY_MB" -gt 0 ] &&
       [ "$MEMORY_MB" -lt 2048 ]; then

        case "$package" in

            hashcat)
                return 1
                ;;

            wireshark)
                return 1
                ;;

            metasploit-framework)
                return 1
                ;;

            burp-suite-community)
                return 1
                ;;

            *)
                ;;
        esac
    fi

    return 0
}

# ============================================================
# Collect packages from a profile
# ============================================================

collect_profile_packages() {

    local profile="$1"
    local file=""
    local package=""

    file="$(profile_file "$profile")"

    if [ ! -f "$file" ]; then
        die "Profile package file not found:

$file"
    fi

    while IFS= read -r package || [ -n "$package" ]; do

        package="${package#"${package%%[![:space:]]*}"}"
        package="${package%"${package##*[![:space:]]}"}"

        [ -n "$package" ] || continue
        [[ "$package" == \#* ]] && continue

        if hardware_allows_package "$package"; then

            PROFILE_PACKAGES+=("$package")

        else

            echo "[HW] Skipping heavy package: $package"

        fi

    done < "$file"
}

# ============================================================
# Resolve selected profiles
# ============================================================

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

    # --------------------------------------------------------
    # Remove duplicate packages
    # --------------------------------------------------------

    if [ "${#PROFILE_PACKAGES[@]}" -gt 0 ]; then

        mapfile -t PROFILE_PACKAGES < <(
            printf '%s\n' "${PROFILE_PACKAGES[@]}" |
            sort -u
        )

    fi

    echo "[+] Packages selected: ${#PROFILE_PACKAGES[@]}"
    echo
}

# ============================================================
# Show installation plan
# ============================================================

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

    if [ "${#PROFILE_PACKAGES[@]}" -gt 0 ]; then

        printf '%s\n' "${PROFILE_PACKAGES[@]}" |
        sed 's/^/  - /'

    fi

    echo
    echo "------------------------------------------------"

    local answer=""

    if [ "${ZLINUX_NONINTERACTIVE:-0}" = "1" ]; then

        answer="y"

    else

        read -r -p "Continue with this configuration? [Y/n]: " answer

        answer="${answer:-y}"

    fi

    case "$answer" in

        y|Y|yes|YES)
            ;;

        *)
            echo
            echo "[Z-Linux] Installation cancelled."
            exit 0
            ;;

    esac

    echo
}

# ============================================================
# Download debootstrap
# ============================================================

download_debootstrap() {

    echo
    echo "================================================"
    echo "             DEBOOTSTRAP SETUP"
    echo "================================================"
    echo

    mkdir -p "$CACHE_DIR"

    if [ -f "$DEBOOTSTRAP_DEB" ]; then

        echo "[+] Using cached debootstrap."

        return 0
    fi

    echo "[+] Downloading debootstrap $DEBOOTSTRAP_VERSION..."
    echo

    wget \
        -O "$DEBOOTSTRAP_DEB" \
        "$DEBOOTSTRAP_URL"

    if [ ! -s "$DEBOOTSTRAP_DEB" ]; then
        die "Failed to download debootstrap."
    fi

    echo
    echo "[+] debootstrap downloaded successfully."
}

# ============================================================
# Extract debootstrap
# ============================================================

extract_debootstrap() {

    echo "[+] Extracting debootstrap package..."

    rm -rf "$DEBOOTSTRAP_DIR"
    mkdir -p "$DEBOOTSTRAP_DIR"

    local data_archive=""

    case "$ARCHIVER" in

        bsdtar)

            bsdtar -xf \
                "$DEBOOTSTRAP_DEB" \
                -C "$DEBOOTSTRAP_DIR"

            ;;

        ar)

            (
                cd "$DEBOOTSTRAP_DIR"

                ar x "$DEBOOTSTRAP_DEB"
            )

            ;;

    esac

    data_archive="$(
        find "$DEBOOTSTRAP_DIR" \
            -maxdepth 1 \
            -type f \
            \( -name 'data.tar.gz' \
            -o -name 'data.tar.xz' \
            -o -name 'data.tar.zst' \
            \) \
            -print -quit
    )"

    if [ -z "$data_archive" ]; then

        die "Could not find debootstrap data archive."

    fi

    echo "[+] Found: $(basename "$data_archive")"

    rm -rf "$DEBOOTSTRAP_RUNTIME"
    mkdir -p "$DEBOOTSTRAP_RUNTIME"

    case "$data_archive" in

        *.tar.gz)
            tar -xzf "$data_archive" -C "$DEBOOTSTRAP_RUNTIME"
            ;;

        *.tar.xz)
            tar -xJf "$data_archive" -C "$DEBOOTSTRAP_RUNTIME"
            ;;

        *.tar.zst)
            if command_exists unzstd; then
                unzstd -c "$data_archive" |
                    tar -xf - -C "$DEBOOTSTRAP_RUNTIME"
            else
                die "unzstd is required to extract data.tar.zst."
            fi
            ;;

    esac

    if [ ! -f "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap" ]; then
        die "debootstrap executable was not extracted."
    fi

    chmod +x \
        "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap"

    echo "[+] debootstrap extracted successfully."
}

# ============================================================
# Prepare debootstrap runtime
# ============================================================

prepare_debootstrap_runtime() {

    echo "[+] Preparing debootstrap runtime..."

    if [ ! -d "$DEBOOTSTRAP_RUNTIME/usr/share/debootstrap" ]; then
        die "debootstrap runtime directory missing."
    fi

    if [ ! -f \
        "$DEBOOTSTRAP_RUNTIME/usr/share/debootstrap/functions" ]; then

        die "debootstrap functions file missing."
    fi

    mkdir -p "$DEBOOTSTRAP_RUNTIME/bin"

    # Termux bash is used to execute the debootstrap shell script.
    cp \
        "$PREFIX/bin/bash" \
        "$DEBOOTSTRAP_RUNTIME/bin/bash"

    chmod +x \
        "$DEBOOTSTRAP_RUNTIME/bin/bash"

    # Debian debootstrap normally expects its data directory
    # at /usr/share/debootstrap. Keep that path inside the
    # runtime root.
    sed -i \
        "s|^DEBOOTSTRAP_DIR=.*|DEBOOTSTRAP_DIR=\"/usr/share/debootstrap\"|" \
        "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap"

    echo "[+] debootstrap runtime ready."
}

# ============================================================
# Create Debian rootfs
# ============================================================

create_rootfs() {

    echo
    echo "================================================"
    echo "              CREATING DEBIAN ROOTFS"
    echo "================================================"
    echo

    if [ -d "$ROOTFS_DIR/usr" ] ||
       [ -d "$ROOTFS_DIR/etc" ]; then

        if [ "${ZLINUX_FORCE:-0}" != "1" ]; then

            die "Existing rootfs detected. Use ZLINUX_FORCE=1 to rebuild."

        fi

        rm -rf "$ROOTFS_DIR"

    fi

    mkdir -p "$ROOTFS_DIR"

    echo "[+] Debian architecture: $ARCH"
    echo "[+] Suite: $DEBIAN_SUITE"
    echo

    echo "[+] Starting Debian first stage..."

    "$PREFIX/bin/bash" \
        "$DEBOOTSTRAP_RUNTIME/usr/sbin/debootstrap" \
        --foreign \
        --arch="$ARCH" \
        --variant=minbase \
        "$DEBIAN_SUITE" \
        "$ROOTFS_DIR" \
        "$DEBIAN_MIRROR"

    if [ ! -f "$ROOTFS_DIR/debootstrap/debootstrap" ]; then
        die "Debian first stage failed."
    fi

    echo
    echo "[+] Debian first stage complete."
    echo "[+] Starting Debian second stage..."

    rootfs_proot_args

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /debootstrap/debootstrap \
        --second-stage

    echo
    echo "[+] Debian second stage complete."
}
# ============================================================
# Build rootfs proot arguments
# ============================================================

rootfs_proot_args() {

    PROOT_ROOT_ARGS=(
        -0
        -r "$ROOTFS_DIR"
        -w /
    )

    if [ -d "$PREFIX/tmp" ]; then

        PROOT_ROOT_ARGS+=(
            -b "$PREFIX/tmp:/tmp"
        )

    fi

    if [ -f "$PREFIX/etc/resolv.conf" ]; then

        PROOT_ROOT_ARGS+=(
            -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
        )

    fi
}

# ============================================================
# Configure Debian
# ============================================================

configure_debian() {

    echo
    echo "================================================"
    echo "              CONFIGURING DEBIAN"
    echo "================================================"
    echo

    rootfs_proot_args

    mkdir -p "$ROOTFS_DIR/etc/apt"

    # --------------------------------------------------------
    # APT sources
    # --------------------------------------------------------

    cat > "$ROOTFS_DIR/etc/apt/sources.list" <<EOF
deb $DEBIAN_MIRROR $DEBIAN_SUITE main
deb $DEBIAN_MIRROR ${DEBIAN_SUITE}-updates main
deb https://security.debian.org/debian-security ${DEBIAN_SUITE}-security main
EOF

    # --------------------------------------------------------
    # Hostname
    # --------------------------------------------------------

    echo "zlinux" > "$ROOTFS_DIR/etc/hostname"

    cat > "$ROOTFS_DIR/etc/hosts" <<'EOF'
127.0.0.1       localhost
127.0.1.1       zlinux

::1             localhost ip6-localhost ip6-loopback
EOF

    # --------------------------------------------------------
    # DNS
    # --------------------------------------------------------

    mkdir -p "$ROOTFS_DIR/etc"

    if [ -f "$PREFIX/etc/resolv.conf" ]; then

        cp \
            "$PREFIX/etc/resolv.conf" \
            "$ROOTFS_DIR/etc/resolv.conf"

    else

        cat > "$ROOTFS_DIR/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

    fi

    # --------------------------------------------------------
    # APT configuration
    # --------------------------------------------------------

    mkdir -p "$ROOTFS_DIR/etc/apt/apt.conf.d"

    cat > "$ROOTFS_DIR/etc/apt/apt.conf.d/99zlinux" <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Retries "3";
Dpkg::Use-Pty "0";
EOF

    # --------------------------------------------------------
    # Base packages
    # --------------------------------------------------------

    echo "[+] Updating Debian package lists..."

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
set -e

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
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
    tzdata

rm -rf /var/lib/apt/lists/*
'

    # --------------------------------------------------------
    # Locale
    # --------------------------------------------------------

    echo "[+] Configuring locale..."

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
set -e

if [ -f /etc/locale.gen ]; then

    sed -i \
        "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" \
        /etc/locale.gen

    locale-gen

fi

cat > /etc/default/locale <<EOF
LANG=en_US.UTF-8
LANGUAGE=en_US:en
LC_ALL=en_US.UTF-8
EOF
'

    # --------------------------------------------------------
    # Timezone
    # --------------------------------------------------------

    echo "[+] Configuring timezone..."

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
set -e

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

echo "UTC" > /etc/timezone

dpkg-reconfigure -f noninteractive tzdata
'

    echo
    echo "[APT] Base Debian configuration complete."
    echo
    echo "[+] Debian configuration complete."
}

# ============================================================
# Install Z-Linux "get"
# ============================================================

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

# ============================================================
# Configure Z-Linux "get"
# ============================================================

configure_get() {

    echo
    echo "================================================"
    echo "             CONFIGURING Z-LINUX GET"
    echo "================================================"
    echo

    if [ ! -x "$ROOTFS_DIR/usr/local/bin/get" ]; then
        die "Z-Linux get is not executable."
    fi

    rootfs_proot_args

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
set -e

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if command -v get >/dev/null 2>&1; then
    echo "[GET] Z-Linux package manager available."
else
    echo "[GET] Warning: get command could not be validated."
fi
'

    echo
    echo "[+] Z-Linux get configured."
}

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

    printf '%s\n' "${PROFILE_PACKAGES[@]}" \
        > "$ROOTFS_DIR/tmp/zlinux-packages.txt"

    echo "[+] Installing ${#PROFILE_PACKAGES[@]} packages..."

    proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
set -e

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

if [ ! -s /tmp/zlinux-packages.txt ]; then
    exit 0
fi

apt-get update

while IFS= read -r package || [ -n "$package" ]; do

    [ -n "$package" ] || continue

    echo
    echo "[APT] Installing: $package"

    if apt-get install -y \
        --no-install-recommends \
        "$package"; then

        echo "[APT] Installed: $package"

    else

        echo "[WARN] Failed to install: $package"
        echo "[WARN] Continuing with remaining packages."

    fi

done < /tmp/zlinux-packages.txt

rm -rf /var/lib/apt/lists/*
'

    rm -f "$ROOTFS_DIR/tmp/zlinux-packages.txt"

    echo
    echo "[+] Profile packages processed."
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
# Z-Linux configuration

ZLINUX=1
ZLINUX_VERSION="0.1"
ZLINUX_ARCH="$ARCH"
ZLINUX_DEBIAN_SUITE="$DEBIAN_SUITE"
ZLINUX_DEBIAN_MIRROR="$DEBIAN_MIRROR"

ZLINUX_DEBOOTSTRAP_VERSION="$DEBOOTSTRAP_VERSION"

ZLINUX_CPU_CORES="$CPU_CORES"
ZLINUX_MEMORY_MB="$MEMORY_MB"

ZLINUX_PROFILE_COUNT="${#SELECTED_PROFILES[@]}"
EOF

    printf '%s\n' "${SELECTED_PROFILES[@]}" \
        > "$ROOTFS_DIR/etc/zlinux/profiles"

    echo "[+] Z-Linux configuration created."
}

# ============================================================
# Create default Z-Linux user
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

USERNAME="zlinux"
USER_HOME="/home/$USERNAME"

if ! id "$USERNAME" >/dev/null 2>&1; then

    useradd \
        -m \
        -s /bin/bash \
        "$USERNAME"

fi

mkdir -p "$USER_HOME"

chown -R "$USERNAME:$USERNAME" \
    "$USER_HOME"

if [ -f /etc/sudoers ]; then

    if ! grep -q "^$USERNAME " /etc/sudoers; then

        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" \
            >> /etc/sudoers

    fi

fi

mkdir -p /etc/zlinux

echo "$USERNAME" > /etc/zlinux/default-user

echo "[+] User created: $USERNAME"
'

    echo "[+] Default Z-Linux user configured."
}

# ============================================================
# Configure shell environment
# ============================================================

configure_shell_environment() {

    echo
    echo "================================================"
    echo "            CONFIGURING SHELL ENVIRONMENT"
    echo "================================================"
    echo

    mkdir -p "$ROOTFS_DIR/etc/profile.d"

    cat > "$ROOTFS_DIR/etc/profile.d/zlinux.sh" <<'EOF'
# Z-Linux shell environment

export ZLINUX=1

export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"

if [ -f /etc/zlinux/zlinux.conf ]; then
    . /etc/zlinux/zlinux.conf 2>/dev/null || true
fi

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

if command -v zlinux-info >/dev/null 2>&1; then
    :
fi
EOF

    echo
    echo "[+] Shell environment configured."
}

# ============================================================
# Create Z-Linux helper commands
# ============================================================

create_rootfs_helpers() {

    echo
    echo "================================================"
    echo "              CREATING Z-LINUX HELPERS"
    echo "================================================"
    echo

    mkdir -p \
        "$ROOTFS_DIR/usr/local/bin" \
        "$ROOTFS_DIR/usr/local/sbin"

    # --------------------------------------------------------
    # zlinux-info
    # --------------------------------------------------------

    cat > "$ROOTFS_DIR/usr/local/bin/zlinux-info" <<'EOF'
#!/bin/bash

echo
echo "=============================================="
echo "                 Z-LINUX"
echo "=============================================="
echo

if [ -f /etc/zlinux/zlinux.conf ]; then
    cat /etc/zlinux/zlinux.conf
fi

echo
echo "Profiles:"

if [ -f /etc/zlinux/profiles ]; then
    sed 's/^/  - /' /etc/zlinux/profiles
fi

echo
EOF

    chmod +x \
        "$ROOTFS_DIR/usr/local/bin/zlinux-info"

    # --------------------------------------------------------
    # zlinux-update
    # --------------------------------------------------------

    cat > "$ROOTFS_DIR/usr/local/bin/zlinux-update" <<'EOF'
#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

echo "[Z-Linux] Updating package lists..."

apt-get update

echo
echo "[Z-Linux] Upgrading installed packages..."

apt-get upgrade -y

echo
echo "[Z-Linux] Update complete."
EOF

    chmod +x \
        "$ROOTFS_DIR/usr/local/bin/zlinux-update"

    echo "[+] Helper commands created:"
    echo "    zlinux-info"
    echo "    zlinux-update"
}

# ============================================================
# Create Z-Linux launcher
# ============================================================

create_launcher() {

    echo
    echo "================================================"
    echo "             CREATING Z-LINUX LAUNCHER"
    echo "================================================"
    echo

    mkdir -p "$ROOT_DIR/launch"

    cat > "$ROOT_DIR/launch/zlinux" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS_DIR="$ROOT_DIR/rootfs"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "[ERROR] Z-Linux rootfs not found:"
    echo "        $ROOTFS_DIR"
    exit 1
fi

if ! command -v proot >/dev/null 2>&1; then
    echo "[ERROR] proot is not installed."
    echo
    echo "Install it with:"
    echo "    pkg install proot"
    exit 1
fi

PROOT_ARGS=(
    -0
    -r "$ROOTFS_DIR"
    -b "$PREFIX/tmp:/tmp"
    -w /root
)

if [ -f "$PREFIX/etc/resolv.conf" ]; then
    PROOT_ARGS+=(
        -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
    )
fi

mkdir -p "$ROOTFS_DIR/root"

exec proot \
    "${PROOT_ARGS[@]}" \
    /bin/bash \
    -l
EOF

    chmod +x "$ROOT_DIR/launch/zlinux"

    echo "[+] Launcher created:"
    echo "    $ROOT_DIR/launch/zlinux"
}

# ============================================================
# Create Termux convenience launcher
# ============================================================

create_termux_launcher() {

    echo
    echo "[+] Creating Termux launcher..."

    mkdir -p "$ROOT_DIR/bin"

    cat > "$ROOT_DIR/bin/zlinux" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

exec "$ROOT_DIR/launch/zlinux" "$@"
EOF

    chmod +x "$ROOT_DIR/bin/zlinux"

    echo "[+] Termux launcher created:"
    echo "    $ROOT_DIR/bin/zlinux"
}
# ============================================================
# Validate rootfs
# ============================================================

validate_rootfs() {

    echo
    echo "================================================"
    echo "              VALIDATING Z-LINUX"
    echo "================================================"
    echo

    local failed=0

    echo "[+] Checking rootfs directories..."

    for directory in \
        "$ROOTFS_DIR/bin" \
        "$ROOTFS_DIR/etc" \
        "$ROOTFS_DIR/usr" \
        "$ROOTFS_DIR/var"
    do

        if [ -d "$directory" ]; then

            echo "    [OK] $directory"

        else

            echo "    [FAIL] $directory"
            failed=1

        fi

    done

    echo
    echo "[+] Checking required files..."

    for file in \
        "$ROOTFS_DIR/etc/hostname" \
        "$ROOTFS_DIR/etc/hosts" \
        "$ROOTFS_DIR/etc/apt/sources.list" \
        "$ROOTFS_DIR/etc/zlinux/zlinux.conf" \
        "$ROOTFS_DIR/etc/zlinux/profiles" \
        "$ROOTFS_DIR/usr/local/bin/get" \
        "$ROOTFS_DIR/usr/local/bin/zlinux-info" \
        "$ROOTFS_DIR/usr/local/bin/zlinux-update"
    do

        if [ -f "$file" ]; then

            echo "    [OK] $file"

        else

            echo "    [FAIL] $file"
            failed=1

        fi

    done

    echo

    if [ "$failed" -ne 0 ]; then
        die "Rootfs validation failed."
    fi

    echo "[+] Rootfs structure looks good."

    echo
    echo "[+] Testing Debian shell..."

    rootfs_proot_args

    if proot \
        "${PROOT_ROOT_ARGS[@]}" \
        /bin/bash -c '
            set -e
            echo "[TEST] Debian rootfs:"
            cat /etc/debian_version 2>/dev/null || true
            echo "[TEST] Architecture:"
            dpkg --print-architecture 2>/dev/null || true
            echo "[TEST] Shell:"
            command -v bash
        '
    then

        echo
        echo "[+] Debian shell test passed."

    else

        die "Debian shell test failed."

    fi
}

# ============================================================
# Cleanup build files
# ============================================================

cleanup_build() {

    echo
    echo "================================================"
    echo "              CLEANING BUILD FILES"
    echo "================================================"
    echo

    if [ "${ZLINUX_KEEP_WORK:-0}" = "1" ]; then

        echo "[+] Keeping temporary build files."
        echo "    ZLINUX_KEEP_WORK=1"

        return 0

    fi

    echo "[+] Removing temporary debootstrap files..."

    rm -rf "$DEBOOTSTRAP_DIR"

    echo "[+] Build cleanup complete."
}

# ============================================================
# Final build summary
# ============================================================

print_summary() {

    echo
    echo "================================================"
    echo "             Z-LINUX BUILD COMPLETE"
    echo "================================================"
    echo

    echo "Architecture:"
    echo "  Termux : ${ZLINUX_TERMUX_ARCH:-unknown}"
    echo "  Android: ${ZLINUX_ANDROID_ABI:-unknown}"
    echo "  Z-Linux: ${ZLINUX_ARCH:-unknown}"
    echo "  Debian : $ARCH"
    echo

    echo "Debian:"
    echo "  Suite : $DEBIAN_SUITE"
    echo "  Mirror: $DEBIAN_MIRROR"
    echo

    echo "Hardware:"
    echo "  CPU cores: $CPU_CORES"
    echo "  Memory   : ${MEMORY_MB} MB"
    echo

    echo "Profiles:"

    for profile in "${SELECTED_PROFILES[@]}"; do
        echo "  [+] $profile"
    done

    echo
    echo "Packages selected: ${#PROFILE_PACKAGES[@]}"
    echo

    echo "Rootfs:"
    echo "  $ROOTFS_DIR"
    echo

    echo "Launcher:"
    echo "  $ROOT_DIR/launch/zlinux"
    echo "  $ROOT_DIR/bin/zlinux"
    echo

    echo "Start Z-Linux with:"
    echo
    echo "    $ROOT_DIR/launch/zlinux"
    echo
    echo "Or:"
    echo
    echo "    $ROOT_DIR/bin/zlinux"
    echo

    echo "Useful commands inside Z-Linux:"
    echo
    echo "    zlinux-info"
    echo "    zlinux-update"
    echo "    get"
    echo

    echo "================================================"
}

# ============================================================
# Main build process
# ============================================================

main() {

    echo
    echo "[Z-Linux] Starting build..."
    echo

    # --------------------------------------------------------
    # Initial setup
    # --------------------------------------------------------

    prepare_directories

    # --------------------------------------------------------
    # Hardware and profiles
    # --------------------------------------------------------

    detect_hardware

    select_profiles

    resolve_profiles

    show_installation_plan

    # --------------------------------------------------------
    # Debian bootstrap
    # --------------------------------------------------------

    download_debootstrap

    extract_debootstrap

    prepare_debootstrap_runtime

    create_rootfs

    # --------------------------------------------------------
    # Debian configuration
    # --------------------------------------------------------

    configure_debian

    # --------------------------------------------------------
    # Z-Linux package manager
    # --------------------------------------------------------

    install_get

    configure_get

    # --------------------------------------------------------
    # Profile packages
    # --------------------------------------------------------

    install_profile_packages

    # --------------------------------------------------------
    # Z-Linux configuration
    # --------------------------------------------------------

    create_zlinux_config

    create_zlinux_user

    configure_shell_environment

    create_rootfs_helpers

    # --------------------------------------------------------
    # Launchers
    # --------------------------------------------------------

    create_launcher

    create_termux_launcher

    # --------------------------------------------------------
    # Validation
    # --------------------------------------------------------

    validate_rootfs

    # --------------------------------------------------------
    # Cleanup
    # --------------------------------------------------------

    cleanup_build

    # --------------------------------------------------------
    # Final output
    # --------------------------------------------------------

    print_summary
}

# ============================================================
# Entry point
# ============================================================

main "$@"