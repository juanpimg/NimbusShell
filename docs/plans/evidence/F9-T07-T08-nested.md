# Evidencia F9-T07/T08 (nested, sin VM)

## Qué se hizo
- `scripts/nimbus-updates` (`set -u`, sin root salvo `--apply`, `--check`
  dry-run idempotente): lista llana via `checkupdates`/`pacman -Qu`,
  `--apply` crea snapshot `snapper -c root create` + `pacman -Syu` + reporte,
  `--rollback-list`/`--rollback N` con `undochange` o instrucciones.
- `dotfiles/.config/discoverrc` (solo `CompactMode=true`, clave real) +
  `discover-notifierrc` (ASUMIDO, pendiente VM).
- `iso/calamares/modules/snapper-grub-btrfs.md` + ejemplo
  `examples/80-snapper-pre-update.hook` (sin tocar `iso/profile/`).
- `tests/updates/test_updates.sh`: 15/15 ok con fakes en PATH.

## Simulado (no real)
- `--apply`, snapshot snapper y upgrade pacman: solo con fakes en el test.
  En host solo se corrio `--check` real (solo lectura): 17 pendientes, exit 0.
- Discover/notificador, hook pacman, entrada GRUB "volver a ayer": sin
  verificar (sin snapper/btrfs/Discover en host).

## Queda para VM
- Discover real: corregir claves si difieren + captura antes/despues.
- Ciclo btrfs: snapshot pre-update, upgrade, entrada GRUB, arranque
  snapshot, `--rollback N`, reinicio verde.
- `bash -n` + `shellcheck -S warning` cero (nested ok).
