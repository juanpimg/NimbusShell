# F9-T08 — snapshot pre-update + entrada GRUB "volver a ayer" (Calamares/ISO)

> Sin tocar la ISO real (`iso/profile/` intacto): solo documentacion +
> ejemplos. Aplicar en VM al preparar el build (F2-T08).

## Requisitos en el instalado

- `partition.conf` ya usa btrfs con subvolumen `@` (ver cabecera F2-T09).
- Paquetes (anotar en `packages.x86_64` o grupo Calamares, en VM):
  `snapper`, `snap-pac`, `grub-btrfs`.
- Servicios: `snapper-timeline.timer`, `snapper-cleanup.timer`,
  `grub-btrfsd.service` (o regenerar GRUB tras cada snapshot).

## Snapshot pre-update automatico

- `snap-pac` instala el hook pacman que crea snapshot pre/post en cada
  transaccion (descripcion `pacman -Syu`). Ejemplo equivalente manual en
  `iso/calamares/examples/80-snapper-pre-update.hook`.
- `scripts/nimbus-updates --apply` ademas crea su propio snapshot
  `nimbus-pre-update-<fecha>` antes de `pacman -Syu` (doble red: hook +
  script; el rollback usa el mas reciente).

## Entrada GRUB "volver a ayer"

- `grub-btrfs` genera entradas por snapshot en `grub.cfg` (`/.snapshots`).
- Texto que vera el usuario: `NimbusOS snapshot <fecha> (volver a ayer)`.
- Tras revertir (`nimbus-updates --rollback N` o arrancar un snapshot),
  reiniciar; el estado es de solo-lectura hasta `undochange`/rollback.

## Verificacion en VM (pendiente)

1. Instalar con btrfs+snapper, crear snapshot, actualizar, comprobar
   entrada GRUB con el snapshot.
2. Arrancar el snapshot, `--rollback-list`, `--rollback N`, reiniciar.
