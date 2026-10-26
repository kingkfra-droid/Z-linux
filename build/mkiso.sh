#!/usr/bin/env bash

# build/mkiso.sh - create a bootable ISO for Z-Linux
# Tries to produce a hybrid BIOS+UEFI ISO using grub-mkrescue when available.
# Falls back to a simple ISO with xorriso/genisoimage if grub-mkrescue isn't present.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$REPO_ROOT/build/iso.conf"

mkdir -p "$REPO_ROOT/$OUT_DIR"

ISO_PATH="$REPO_ROOT/$OUT_DIR/$ISO_NAME"

echo "Building ISO for Z-Linux"
echo "Source tree: $REPO_ROOT/$SOURCE_DIR"
echo "Output: $ISO_PATH"

# Ensure source directory exists
if [ ! -d "$REPO_ROOT/$SOURCE_DIR" ]; then
    echo "ERROR: Source directory '$REPO_ROOT/$SOURCE_DIR' not found."
    echo "Populate the directory with a live filesystem tree, including /boot/vmlinuz and /boot/initrd.img."
    exit 1
fi

# Prefer grub-mkrescue for hybrid ISO (BIOS + UEFI)
if command -v grub-mkrescue >/dev/null 2>&1; then
    echo "Using grub-mkrescue to create a hybrid BIOS+UEFI ISO..."
    # grub-mkrescue will try to embed EFI and BIOS images if available on the system
    if grub-mkrescue -o "$ISO_PATH" "$REPO_ROOT/$SOURCE_DIR"; then
        echo "ISO created at: $ISO_PATH"
        exit 0
    else
        echo "grub-mkrescue failed; falling back to xorriso/genisoimage method..."
    fi
fi

# Fallback to xorriso / genisoimage / mkisofs
if command -v xorriso >/dev/null 2>&1; then
    echo "Using xorriso to create ISO..."
    xorriso -as mkisofs -o "$ISO_PATH" -V "$ISO_LABEL" -J -R "$REPO_ROOT/$SOURCE_DIR"
    echo "ISO created at: $ISO_PATH"
    exit 0
elif command -v genisoimage >/dev/null 2>&1; then
    echo "Using genisoimage to create ISO..."
    genisoimage -o "$ISO_PATH" -V "$ISO_LABEL" -J -R "$REPO_ROOT/$SOURCE_DIR"
    echo "ISO created at: $ISO_PATH"
    exit 0
elif command -v mkisofs >/dev/null 2>&1; then
    echo "Using mkisofs to create ISO..."
    mkisofs -o "$ISO_PATH" -V "$ISO_LABEL" -J -R "$REPO_ROOT/$SOURCE_DIR"
    echo "ISO created at: $ISO_PATH"
    exit 0
else
    echo "ERROR: No ISO creation tool found (grub-mkrescue, xorriso, genisoimage or mkisofs)." >&2
    exit 1
fi
