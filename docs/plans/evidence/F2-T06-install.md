# F2-T06 — ISO netinstall construida y booteada (2026-11-01)

## Resultado

- ISO: `nimbusos-2026.11.01-x86_64.iso` (2.343.747.584 bytes, 2,2 GiB).
- SHA256: `12ca2f8fad4184107ba0f0ea8cd231f21a56fac0b71f41e898a6828ab44acbc2`.
- `file`: ISO 9660 bootable, label `NIMBUS_202610`, BIOS (syslinux) + UEFI (systemd-boot).
- Build en VM CachyOS live (4 GiB, disco 40 GB, `/mnt/build`), `mkarchiso` v92, zstd:19.
- Boot UEFI verificado en QEMU/OVMF: menú **NimbusOS live (x86_64, UEFI)** y arranque del live.

## Fixes necesarios durante el build (aplicados en `plasma/f2-iso`)

1. `pacman.conf`: mirrors CachyOS/Arch explícitos, `Architecture = auto`, sin `<SNAPSHOT>`.
2. Perfil archiso: `syslinux/` + `efiboot/` de releng, paquete `syslinux`, `airootfs` releng (shadow, mkinitcpio, `.automated_script.sh`).
3. KF6 del live (6.28) vs repos (6.31): `pacman -Syu` para alinear; `krunner` 6.31.
4. `cachyos-calamares` 3.4.2-4 enlaza Boost 1.91 y el ISO tiene 1.92: se inyectaron las 48 libs `libboost_*1.91.0` extraídas del ISO CachyOS para el test. **Deuda**: usar `extra/calamares` o rebuild del paquete.
5. Calamares no debe pisar `/etc/calamares` en pacstrap: configs en `/usr/share/nimbus/calamares` + wrapper `/usr/local/bin/calamares`.
6. `profiledef.sh` `file_permissions` para todos los binarios/scripts (mkarchiso hace `cp --no-preserve=mode`).
7. Root shell del airootfs era `/usr/bin/zsh` (no instalado) → `/bin/bash`.
8. Branding Nimbus: `branding/nimbus/{branding.desc,images,slideshow}` propio (logo N, sin activos Apple); wrapper copia a `/usr/share/calamares/branding`.

## Evidencia visual

- `spikes/f2-install/01-live-boot.png`: arranque/live (hostname nimbusos).
- `spikes/f2-install/02-live-plasma.png`: Plasma live.
- `spikes/f2-install/02-calamares-branding.png` / `03-calamares-welcome.png`: Calamares con branding Nimbus.

## Veredicto

**F2-T06: OK** — `mkarchiso` produce ISO booteable y hash registrado. La instalación completa se evalúa en F2-T07/T08 (bloqueada; ver evidencias).
