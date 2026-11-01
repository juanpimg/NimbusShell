#!/bin/bash
# Copia GRUB al fallback UEFI para arrancar sin entrada NVRAM.
set -u
ROOT="${1:-/}"
mkdir -p "$ROOT/boot/efi/EFI/BOOT"
cp "$ROOT/boot/efi/EFI/grub/grubx64.efi" "$ROOT/boot/efi/EFI/BOOT/BOOTX64.EFI" || {
    echo "ERROR: no se pudo copiar grubx64.efi" >&2; exit 1; }
