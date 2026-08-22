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

        input="developer"

        echo "[+] Non-interactive mode."
        echo "[+] Default profile: developer"
        echo

    else

        while true; do

            printf "Select profile(s) [1-5, e.g. 1,2]: "
            read -r input

            if [ -n "$input" ]; then
                break
            fi

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

            security|developer|documentation|entertainment)
                ;;

            *)
                die "Unknown profile selection: $item"
                ;;

        esac

        item="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')"

        if ! valid_profile "$item"; then
            die "Unknown profile: $item"
        fi

        exists=0

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

    if command_exists df; then

        STORAGE_AVAILABLE="$(
            df -Pm "$ROOT_DIR" 2>/dev/null |
            awk 'NR==2 {print $4}'
        )"

    else
        STORAGE_AVAILABLE=0
    fi

    if [ -z "$STORAGE_AVAILABLE" ]; then
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

    # --------------------------------------------------------
    # Devices with less than 2 GB RAM
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
    # Single-core devices
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
# ============================================================
# Collect packages from a profile
# ============================================================

collect_profile_packages() {

    local profile="$1"
    local file=""
    local package=""

    file="$(profile_file "$profile")"

    if [ ! -f "$file" ]; then
        die "Profile file missing:

$file"
    fi

    while IFS= read -r package || [ -n "$package" ]; do

        # Remove comments.
        package="${package%%#*}"

        # Remove leading whitespace.
        package="${package#"${package%%[![:space:]]*}"}"

        # Remove trailing whitespace.
        package="${package%"${package##*[![:space:]]}"}"

        # Ignore empty lines.
        [ -n "$package" ] || continue

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

        for package in "${PROFILE_PACKAGES[@]}"; do
            echo "  - $package"
        done

        echo

    fi

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
}# ============================================================
# Create Debian rootfs
# ============================================================

create_rootfs() {

    echo
    echo "================================================"
    echo "              CREATING DEBIAN ROOTFS"
    echo "================================================"
    echo

    # --------------------------------------------------------
    # Check for an existing rootfs
    # --------------------------------------------------------

    if [ -d "$ROOTFS_DIR/usr" ] ||
       [ -d "$ROOTFS_DIR/etc" ]; then

        if [ "${ZLINUX_FORCE:-0}" != "1" ]; then

            die "Existing rootfs detected.

To rebuild it, use:

    ZLINUX_FORCE=1 ./build/build-rootfs.sh"

        fi

        echo "[+] Removing existing rootfs..."

        rm -rf "$ROOTFS_DIR"

    fi

    mkdir -p "$ROOTFS_DIR"

    echo "[+] Debian architecture : $ARCH"
    echo "[+] Debian suite        : $DEBIAN_SUITE"
    echo "[+] Debian mirror       : $DEBIAN_MIRROR"
    echo

    # --------------------------------------------------------
    # First stage
    # --------------------------------------------------------

    echo "[+] Starting Debian first stage..."
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

    if [ ! -f "$ROOTFS_DIR/debootstrap/debootstrap" ]; then

        die "Debian first stage failed."

    fi

    echo
    echo "[+] Debian first stage complete."

    # --------------------------------------------------------
    # Second stage
    # --------------------------------------------------------

    echo
    echo "[+] Starting Debian second stage..."
    echo

    proot \
        -0 \
        -r "$ROOTFS_DIR" \
        -w / \
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

    # --------------------------------------------------------
    # Android / Termux /dev
    # --------------------------------------------------------

    if [ -d /dev ]; then

        PROOT_ROOT_ARGS+=(
            -b /dev:/dev
        )

    fi

    # --------------------------------------------------------
    # Termux DNS configuration
    # --------------------------------------------------------

    if [ -f "$PREFIX/etc/resolv.conf" ]; then

        PROOT_ROOT_ARGS+=(
            -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf"
        )

    fi
}