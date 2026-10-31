# tests/ — verificación con evidencia en VM

Toda tarea UI exige evidencia en VM (captura antes/después + interacción +
`qdbus6`/`kwshot`). Sin evidencia no está hecha (R-TEST).

- **Subdirectorios:** `vm/` (harness de instalación/aceptación por
  superficie), `golden/` (referencias propias + `screenshot-diff`,
  umbrales), `interaction/` (pointer lab, teclado, multi-monitor/HiDPI),
  `progress/` (tests del ledger), más `perf/`, `soak/`, `kcm/` según fase.
- **Qué va:** scripts reproducibles + evidencias en
  `docs/plans/evidence/<ID>.md`. **Qué no:** goldens de macOS ajenos
  (R-APPLE: capturas propias, no se distribuyen).
