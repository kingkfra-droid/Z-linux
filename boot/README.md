# Z-Linux Boot Components

This directory contains boot-related configuration files and scripts for Z-Linux.

## Files

### `boot.sh`
Main boot configuration script that:
- Detects the boot device
- Installs and configures GRUB bootloader
- Updates the boot configuration
- Verifies the bootloader installation

**Usage:**
```bash
sudo bash boot.sh
```

### `grub.cfg`
GRUB bootloader configuration file containing:
- Boot menu entries for Z-Linux
- Recovery mode entry
- Kernel and initrd parameters

This file is typically installed to `/boot/grub/grub.cfg` by the boot.sh script.

### `fstab`
Static filesystem table defining:
- Root filesystem mount point and options
- Virtual filesystems (proc, sysfs, devpts)
- Temporary filesystems (tmpfs)

**Note:** Update device names (e.g., `/dev/sda1`) according to your system configuration.

## Quick Start

1. Ensure you have root privileges
2. Run the boot configuration script:
   ```bash
   sudo bash boot.sh
   ```
3. Verify GRUB installation:
   ```bash
   sudo grub-install --version
   ```
4. Reboot to test:
   ```bash
   sudo reboot
   ```

## Requirements

- GRUB2 bootloader support
- Debian-based Linux distribution
- Root/sudo access

## Notes

- The `fstab` file should be customized for your system's partition layout
- Device names are examples and should be updated based on your disk configuration
- The boot script will automatically install GRUB if not already present
