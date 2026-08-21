#!/bin/bash

set -e

echo "========================================"
echo "        Z-Linux Boot Configuration"
echo "========================================"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must run as root."
    exit 1
fi

echo "[+] Root user detected"
echo

# Detect boot device
BOOT_DEVICE=$(findmnt -n -o SOURCE /)
if [ -z "$BOOT_DEVICE" ]; then
    echo "[ERROR] Failed to detect boot device."
    exit 1
fi

echo "[+] Boot device: $BOOT_DEVICE"

# Install GRUB bootloader
echo "[*] Installing GRUB bootloader..."
GRUB_DEVICE=$(echo $BOOT_DEVICE | sed 's/[0-9]*$//')

if command -v grub-install >/dev/null 2>&1; then
    grub-install "$GRUB_DEVICE"
    echo "[+] GRUB installed successfully"
else
    echo "[!] grub-install not found. Installing..."
    apt-get update
    apt-get install -y grub-pc
    grub-install "$GRUB_DEVICE"
    echo "[+] GRUB installed successfully"
fi

# Update GRUB configuration
echo "[*] Updating GRUB configuration..."
if command -v update-grub >/dev/null 2>&1; then
    update-grub
    echo "[+] GRUB configuration updated"
else
    echo "[ERROR] update-grub not found"
    exit 1
fi

# Verify bootloader installation
echo
echo "[*] Verifying bootloader installation..."
if [ -f /boot/grub/grub.cfg ]; then
    echo "[+] Boot configuration verified"
    echo "[+] GRUB config location: /boot/grub/grub.cfg"
else
    echo "[!] WARNING: GRUB configuration not found at expected location"
fi

echo
echo "========================================"
echo "     Boot configuration complete"
echo "========================================"
echo
