# Evidencia — política y estado (2026-11-02)

Este directorio es la **evidencia canónica** que se versiona. Cada tarea del
ledger debe enlazar aquí una captura y un `.md` con comando, resultado y
límites. Sin captura real no hay “hecho”.

## Regla rápida

- **Captura antes/después** con el mismo encuadre y fondo (wallpaper Nimbus o
  damero de alto contraste para blur/refracción).
- **Medición** cuando aplique: geometría KWin (`windows` probe), píxeles
  (PIL), laplaciano, md5, SHA256.
- **Límites honestos**: nested ≠ VM instalada ≠ PC físico. Escribir qué no se
  probó.
- **No** commitear activos Apple (capturas de macOS ajenas): solo referencias
  locales fuera del repo.

## Nomenclatura

- `F<fase>-T<nn>-<tema>.md` + carpeta de PNGs si hay varias.
- Ejemplos de esta sesión: `F3-T03-bar-transparency.md`,
  `F3-T04-menu-glass.md`, `F3-T05-tahoe-cc.md`,
  `F3-T08-calendar-tahoe.md`, `F3-T09-notifications-tahoe.md`,
  `F11-T02-blur.md`, `F11-T02-glass-spike.md`, `DEV-VM-LOOP.png`.

## `spikes/` (local, no versionado)

`spikes/` contiene capturas/logs de iteraciones nested y ejecuciones
transitorias. Está en `.gitignore`: **no se sube**. Si una captura de
`spikes/` es la evidencia de una tarea, cópiala antes a
`docs/plans/evidence/` con nombre estable.

Documentos históricos (F0/F2/F3 antiguos) aún citan `spikes/...`; esas rutas
existen solo en esta máquina. La evidencia nueva debe estar aquí.

## Estado de evidencias recientes

| Tarea | Evidencia | Estado |
|---|---|---|
| F11-T02 blur | `F11-T02-blur.md` + `F11-T02-blur/` | nested; falta ISO/VM |
| F11-T02 Glass | `F11-T02-glass-spike.md` + `F11-T02-glass/` | spike nested; no ISO |
| F3-T03 barra | `F3-T03-bar-transparency.md` | nested; falta toggle/VM |
| F3-T04 menú | `F3-T04-menu-glass.md` | UI; acciones reales pendientes |
| F3-T05 CC | `F3-T05-tahoe-cc.md` | UI; toggles/VM pendientes |
| F3-T08 calendario | `F3-T08-calendar-tahoe.md` | nested + tests 9/9 |
| F3-T09 notificaciones | `F3-T09-notifications-tahoe.md` | demo; FDO real pendiente |
| Dev VM | `DEV-VM-LOOP.png` + `DEV-VM-WORKFLOW.md` | loop validado |
| ISO out16 | `out16/SHA256SUMS` + `BOOT-WITHOUT-USB.md` | build/boot; Calamares QEMU falla |
