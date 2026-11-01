#!/bin/bash
# NimbusOS: kernel del ISO + initramfs estándar en el target (host).
# Uso: nimbus-kernel.sh <ROOT>   (ROOT = punto de montaje del target)
set -u
ROOT="${1:-/}"
[ -d "$ROOT" ] || { echo "ERROR: ROOT no existe: $ROOT" >&2; exit 1; }
rm -f "$ROOT/etc/mkinitcpio.conf.d/archiso.conf"
cat > "$ROOT/etc/mkinitcpio.conf" <<'CONF'
MODULES=(btrfs)
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems)
CONF
SRC=/run/archiso/bootmnt/nimbus/boot/x86_64/vmlinuz-linux
if [ -f "$SRC" ]; then
    mkdir -p "$ROOT/boot"
    cp "$SRC" "$ROOT/boot/vmlinuz-linux" || { echo "ERROR: copia kernel" >&2; exit 1; }
fi
# El setup post-instalación corre en chroot: hay que copiarlo al target.
if [ -f /usr/local/bin/nimbus-installed-setup ]; then
    install -Dm755 /usr/local/bin/nimbus-installed-setup "$ROOT/usr/local/bin/nimbus-installed-setup"
fi
chroot "$ROOT" mkinitcpio -P
