# How to build an ISO for Z-Linux

This document shows the simplest way to create a bootable ISO from this repository.

Prerequisites
- grub-mkrescue (recommended) OR xorriso/genisoimage/mkisofs
- A prepared live filesystem tree at the path specified in build/iso.conf (default: livefs)
  - The tree should include a kernel and initramfs at livefs/boot/vmlinuz and livefs/boot/initrd.img
  - A GRUB configuration file is expected at livefs/boot/grub/grub.cfg

Steps
1. Populate the livefs directory with a root filesystem and kernel/initrd.

   Example (very minimal):
     mkdir -p livefs/boot/grub
     cp /boot/vmlinuz-$(uname -r) livefs/boot/vmlinuz
     cp /boot/initrd.img-$(uname -r) livefs/boot/initrd.img
     # edit livefs/boot/grub/grub.cfg if needed

2. Build the ISO:

   ./build/mkiso.sh

   - If grub-mkrescue is available, it will be used to create a hybrid BIOS+UEFI ISO.
   - Otherwise the script will use xorriso/genisoimage/mkisofs as a fallback.

Notes and advanced topics
- Embedding both BIOS and UEFI boot loaders: grub-mkrescue is the recommended tool because it can package both BIOS and EFI boot support into the ISO. On Debian/Ubuntu the package providing grub-mkrescue is usually grub-pc-bin and grub-efi-amd64-bin.
- For production-ready ISOs you will want to configure:
  - Proper EFI directory (EFI/BOOT/BOOTX64.EFI)
  - A signed/grubx64.efi, shim, and related files for secure boot (if needed)
  - Persistence or live system init scripts for a true live USB experience
- See upstream docs for GRUB and xorriso for detailed flags to customize hybrid boot behavior.
