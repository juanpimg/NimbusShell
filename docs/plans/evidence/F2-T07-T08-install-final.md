# F2-T07/F2-T08 — Instalación Calamares y primer boot (2026-11-01 05:32)

## Hito

- **Calamares completa la instalación**: `All done` (captura
  `spikes/f2-install/20-install-done.png`).
- `exec` arranca, `pacstrap` instala base+linux, `machineid`, `locale`,
  `users`, `nimbus-kernel` (host con `${ROOT}`), `bootloader` GRUB y
  `umount` se ejecutan. Capturas `19-pacstrap-installing.png`,
  `18-pacstrap-progress.png`.
- El disco `/dev/vda` queda con GPT EFI 300 MiB + btrfs 29.7 GiB.

## UEFI / arranque

- GRUB EFI en `/boot/efi/EFI/grub/grubx64.efi` (360 KB) y `grub.cfg`
  generado.
- La VM no traía entrada NVRAM; se creó manualmente con `efibootmgr
  -c -d /dev/vda -p 1 -L NimbusOS -l /EFI/grub/grubx64.efi`
  (Boot0009, primera en BootOrder). **Arranque UEFI correcto**:
  login `nimbusos` (`installed-boot4.png`/`installed-boot5.png`).
- Para la ISO final: añadir copia `EFI/BOOT/BOOTX64.EFI` tras
  `bootloader` para que UEFI arranque sin entrada NVRAM.

## Escritorio

- SDDM arranca (tema Breeze; el tema Nimbus no llegó al target).
- Login `nimbus`/`nimbus` → **Plasma 6.8.2 Wayland** funcionando
  (`21-installed-plasma.png`, `checks1.png`, `term1.png`).
- `plasmashell --version` = 6.8.2; `PlasmaUserFeedback FeedbackLevel=0`
  (telemetría off); `journalctl -p3` solo `virtio_tdx` (VM, inocuo).

## Gaps reales (no ocultar)

1. **`packages` no instaló Plasma**: el target quedó solo con la base de
   `pacstrap`; `sddm`/`plasma-meta` no estaban. Se instalaron manualmente
   con `pacman -S plasma-meta sddm ...` (514 paquetes) para validar el
   escritorio. Hay que corregir el módulo/orden en la ISO final.
2. **`nimbus-installed-setup` no dejó la capa Nimbus**: no existe
   `/usr/local/bin/nimbus-*` en el target; SDDM usa Breeze. El
   shellprocess no ejecutó o falló silenciosamente.
3. **firewalld no quedó instalado/activo** (`not-found`), telemetría sí 0.
4. **Entrada UEFI manual** (ver arriba); no la crea Calamares en esta VM.
5. `kwin_wayland --version` no resuelve en PATH (el escritorio Wayland
   funciona; verificar paquete/binario en la ISO final).
6. La ISO construida a las 04:07 **no incluye** los últimos fixes de
   `pacstrap` (config/keyring/orden); hay que reconstruir.

## Veredicto

- **F2-T07: `[x]` parcial?** El flujo Calamares completa y el boot UEFI
  funciona, pero la selección de paquetes Plasma no se aplicó. Se deja
  `[ ]` hasta corregir `packages` y repetir con la ISO final.
- **F2-T08: `[ ]`** — hay primer boot usable y Plasma, pero la capa
  Nimbus, firewall y SDDM Nimbus faltan; además la instalación requirió
  pasos manuales. Evidencia adjunta para no perder el hito.
