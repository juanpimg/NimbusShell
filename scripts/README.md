# scripts/ — utilidades del repo

- `audit.sh` (F0-T01: inventario), `nimbus-progress` (F1-T06: ledger
  ponderado por fase), `ci.sh` (F1-T05: bash -n, shellcheck, qmllint,
  `--check` en seco), `apply-theme` (F2-T04, idempotente y reversible).
- **Qué va:** solo scripts con `--help`, `set -u`, mensajes accionables.
  **Qué no:** lógica de instalador (vive en `install.sh` + `lib/`, F1-T03).
