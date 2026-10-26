# Basic live filesystem for Z-Linux

This directory is used as the root tree for the ISO image. Populate it with a Linux kernel and initramfs in /boot, and any additional files you want to include on the live image.

Minimum expected files:

- boot/vmlinuz        (kernel image)
- boot/initrd.img     (initramfs / initrd)
- boot/grub/grub.cfg  (GRUB menu configuration)

Example:

livefs/
├─ boot/
│  ├─ vmlinuz
│  ├─ initrd.img
│  └─ grub/
│     └─ grub.cfg
└─ (other system files)

Note: This repository includes a sample grub.cfg that attempts to boot /boot/vmlinuz and /boot/initrd.img. You must provide matching kernel/initrd images for a working ISO.
