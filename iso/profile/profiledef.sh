#!/usr/bin/env bash
# NimbusOS — perfil netinstall (archiso/CachyOS pinneado, F2-T06).
# Fuente: docs/plans/research/F2-base.md §4a y §8. Snapshot CachyOS 2026-10;
# los pins de versión se congelan en F2-T01 tras validar en VM (R-CACHYOS).
# Nada usa `latest`. Sin AUR no fijado (klassy queda fuera, ver packages.x86_64).

iso_name="nimbusos"
iso_label="NIMBUS_$(date +%Y%m)"
iso_publisher="NimbusOS <https://nimbusos.local>"
iso_application="NimbusOS Plasma netinstall"
iso_version="2026.11.01"
install_dir="nimbus"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
locale_name="es_ES.UTF-8"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-b' '1M' '-Xcompression-level' '19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/calamares"]="0:0:755"
  ["/usr/local/bin/nimbus-installed-setup"]="0:0:755"
  ["/usr/local/bin/nimbus-live-user"]="0:0:755"
  ["/usr/local/bin/nimbus-live-installer"]="0:0:755"
  ["/etc/systemd/system/nimbus-live-user.service"]="0:0:644"
  ["/etc/sudoers.d/10-nimbus-live"]="0:0:440"
  ["/etc/xdg/autostart/nimbus-installer.desktop"]="0:0:644"
  ["/usr/local/bin/nimbus-bar"]="0:0:755"
  ["/usr/local/bin/nimbus-bar-start"]="0:0:755"
  ["/etc/skel/.config/systemd/user/nimbus-bar.service"]="0:0:644"
  ["/etc/skel/.config/autostart/nimbus-bar.desktop"]="0:0:755"
  ["/etc/skel/.config/plasma-workspace/env/nimbus-bar.sh"]="0:0:644"
  ["/usr/local/bin/nimbus-apps"]="0:0:755"
  ["/usr/local/bin/nimbus-spotlight"]="0:0:755"
  ["/usr/local/bin/nimbus-theme"]="0:0:755"
  ["/usr/local/bin/nimbus-privacy"]="0:0:755"
  ["/usr/local/bin/nimbus-flatpak-perms"]="0:0:755"
  ["/usr/local/bin/apply-theme"]="0:0:755"
  ["/usr/local/bin/nimbus-hide-panel"]="0:0:755"
  ["/usr/local/bin/nimbus-keys"]="0:0:755"
  ["/usr/share/nimbus/bar/pins.txt"]="0:0:644"
  ["/usr/share/nimbus/calamares/scripts/nimbus-assets.sh"]="0:0:755"
  ["/usr/share/nimbus/calamares/scripts/pacstrap_calamares"]="0:0:755"
  ["/usr/share/nimbus/calamares/scripts/nimbus-kernel.sh"]="0:0:755"
  ["/usr/share/nimbus/calamares/scripts/nimbus-efi-fallback.sh"]="0:0:755"
  ["/usr/share/nimbus/calamares/scripts/nimbus-pacstrap-patch.sh"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
