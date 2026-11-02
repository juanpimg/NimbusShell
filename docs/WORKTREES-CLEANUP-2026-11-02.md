# Limpieza de worktrees — 2026-11-02

Antes había **61 worktrees** `NimbusShell-*` en
`/home/jp/Escritorio/Proyectos` (migración, features F0-F11, ISO, etc.).

- **Todas las ramas estaban fusionadas** en `plasma-migration`
  (`git branch --no-merged plasma-migration` → 0).
- Se conservó un único repo canónico:
  **`/home/jp/Escritorio/Proyectos/NimbusShell`** (rama `plasma-migration`).
- Se eliminaron los 60 worktrees físicos; **las ramas siguen en git**.
- `spikes/` (evidencia local, 161 MB) se conservó en el repo canónico e está
  ignorado por `.gitignore`; la evidencia canónica sigue en
  `docs/plans/evidence/`.
- `archive/` guarda restos antiguos (`f6perf`, `pid.txt`) y también está
  ignorado.
- Lista exacta previa: `docs/plans/evidence/WORKTREES-2026-11-02.txt`.

No se perdió ningún commit: el repo canónico está en GitHub en `da29f77`
(`main` y `plasma-migration`).
