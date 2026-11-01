# F2-T07 — Validación del `exec` de Calamares (2026-11-01 03:44)

## Resultado

- Calamares abre con branding y textos Nimbus en español (Locale Español,
  Madrid, teclado ES, borrar disco, usuario nimbus/nimbus, hostname nimbusos).
- Al pulsar **Instalar ahora**, el `exec` **sí arranca**: barra de progreso 2%,
  mensaje «Creando una nueva partición root en /dev/vda…».
- Capturas: `spikes/f2-install/13-install-start.png` (resumen),
  `14-install-progress.png` (exec en curso).

## Siguiente fallo (esperado, ya corregido en la ISO final)

- `unpackfs` intenta copiar `/run/archiso/bootmnt/arch/x86_64/airootfs.sfs`,
  que no existe en un netinstall (el root se instala por paquetes).
- Captura: `spikes/f2-install/15-install-unpackfs.png`.
- Corrección aplicada en `iso/calamares/settings.conf`:
  - se elimina `unpackfs` del `exec`;
  - `packages`/`netinstall` van antes de `shellprocess@nimbus-kernel` y
    `bootloader`;
  - `packages.conf` instala `base`, `linux`, `linux-firmware`, `mkinitcpio`,
    `grub`, `efibootmgr`, `btrfs-progs`, `snapper`, `xorg-server`,
    `xcb-util-cursor`, PipeWire/BlueZ/CUPS y fuentes.
- La ISO final en construcción incluye estos cambios; la instalación completa
  se valida en F2-T08.

## Conclusión

El bloqueo histórico «Finish sin jobs» queda cerrado: era `finished` dentro del
primer `show` (R-CALAMARES-EXEC). El test actual sirve como evidencia del
arranque del `exec`; la instalación E2E queda pendiente de la ISO final.
