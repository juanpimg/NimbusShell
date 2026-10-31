# F7-T06 nested — Animación slide/zoom 450ms + reduce-motion

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Mismo harness. Capturas
`f7-mc-thumbs.png` (450ms) y `f7-mc-rm.png` (RM).

## R-MC-ANIM

- Entrada: contenido `opacity+scale .96→1`, fila Spaces slide `x -24→0`,
  tiles `opacity+scale .92→1`; `NumberAnimation 450ms OutCubic`
  (§2.5: MC/Spaces 400-500ms). Re-lanzada al abrir, al cambiar de Space
  y vía `/MC replayIntro`.
- Reduce-motion: `--reduce-motion` o `/MC setReduceMotion` → `animMs=150`,
  solo fade (sin escala ni slide). Footer indica el modo
  (`anim 450ms slide/zoom` / `anim 150ms fade (RM)`).

## Medidas

- `fps_intro=23` durante la intro (`fpsProbe`: cuenta `frameSwapped`
  1.2s). Valor honesto en nested software (llvmpipe 1280×800
  fullscreen + 10 thumbs PNG): fluido no acreditable aquí; 60fps queda
  para HW real (F7-T10). Sin tirones lógicos: 0 QML, duraciones en código.
- `rm_rc=0`, `f7-mc-rm.png` OK (mismo grid, footer en modo RM) ✓.
