# scripts/ — utilidades del repo

- `audit.sh` (F0-T01: inventario), `nimbus-progress` (F1-T06: ledger
  ponderado por fase), `ci.sh` (F1-T05: bash -n, shellcheck, qmllint,
  `--check` en seco), `apply-theme` (F2-T04, idempotente y reversible),
  `nimbus-theme` (F3-T11: `light|dark|auto`, `--accent <hex>`,
  `--wallpaper <img>`, `--auto enable|disable|status`, `--check`,
  `--revert`; idempotente, sin root, backup `nimbusshell-backup-*`),
  `nimbus-privacy` (F2-T09: telemetría KDE off + purga UserFeedback),
  `nimbus-flatpak-perms` (F2-T09: política Flatpak por app, no instala),
  `nimbus-bar-preset` (F3-T13: presets de la barra `--list/--apply/--check/
  --reset/--pin-check`, idempotente, sin root, backup
  `nimbusshell-backup-barpreset`).
- **Qué va:** solo scripts con `--help`, `set -u`, mensajes accionables.
  **Qué no:** lógica de instalador (vive en `install.sh` + `lib/`, F1-T03).
