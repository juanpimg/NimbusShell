# F2-T08 (parcial) — Instalación manual del live en VM y primer boot (2026-11-01)

## Qué se hizo

Ante el bloqueo de Calamares (`sequence.exec` no arranca), se instaló el live a `/dev/vda` con un método manual reproducible:
1. GPT: 512 MiB EFI (vda1) + resto btrfs (vda2); subvols `@`, `@home`, `@snapshots`.
2. `rsync -aHAX` del live al target; kernel/initramfs desde `/nimbus/boot` y ESP.
3. `mkinitcpio` estándar (se eliminó el drop-in `archiso.conf`), `bootctl install`, fstab UUID, locale es, hostname `nimbusos`, usuario `nimbus`, SDDM/NetworkManager/firewalld, root/nimbus con contraseña `nimbus`.
4. Primer boot: **UEFI no encontró la entrada** (bootctl no pudo escribir NVRAM: "Failed to create EFI boot variable entry"); se arrancó el sistema con QEMU `-kernel`/`-initrd` del propio disco (`root=UUID=37c9c638… rootflags=subvol=@`).

## Evidencia

- Serial del sistema instalado: `Arch Linux 7.2.11-arch1-1`, hostname `nimbusos`, SDDM arranca, NetworkManager/firewalld habilitados, `/dev/dri/card0` presente.
- Plasma Wayland arrancado manualmente (`startplasma-wayland` con bus de sesión): escritorio Plasma visible (`spikes/f2-install/07-installed-plasma.png`).
- `nimbus-bar` ejecutado en la sesión instalada: barra 24px con logo N/Nimbus, Wi-Fi/BT/batería/reloj (`09-installed-bar.png`) y **menú Apple completo** (Acerca/Ajustes/Dormir/Bloquear/Cerrar sesión/Reiniciar/Apagar) en `08-installed-bar-menu.png`.
- Panel stock de Plasma presente (la ISO técnica no instala autostart de la barra; F3-T12).

## Gaps / bloqueos

- Calamares sigue sin ejecutar `exec` → F2-T07 `[ ]`.
- UEFI boot del disco no registrado (bootctl/efivars); el ISO arranca por CD y el sistema por kernel directo, pero no hay cadena UEFI→systemd-boot funcional en la VM.
- SDDM X11 fallaba por falta de `xorg-server` en la ISO (se instaló a mano); Wayland greeter no arrancó. Plasma se validó arrancándolo manualmente.
- Sin audio/Bluetooth reales (PipeWire/BlueZ ausentes); barra/CC leen estado limitado.
- El intento de aplicar Klassy en caliente abortó la sesión gráfica; no se usa como evidencia.

## Veredicto

**F2-T08: `[ ]`** — hay primer boot usable y evidencia de escritorio/barra, pero no por el flujo Calamares/UEFI exigido. Deuda: arreglar `sequence.exec` y `bootctl` en la ISO integrada.
