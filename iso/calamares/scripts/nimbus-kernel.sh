#!/bin/bash
# NimbusOS: copia el kernel del ISO y genera un initramfs estándar en el target.
set -u
rm -f /etc/mkinitcpio.conf.d/archiso.conf
cat > /etc/mkinitcpio.conf <<'CONF'
MODULES=(btrfs)
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems)
CONF
SRC=/run/archiso/bootmnt/nimbus/boot/x86_64/vmlinuz-linux
if [ -f "$SRC" ]; then
    cp "$SRC" /boot/vmlinuz-linux
fi
mkdir -p /boot
mkinitcpio -P
