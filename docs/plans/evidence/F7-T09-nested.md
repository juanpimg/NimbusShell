# F7-T09 nested — Perf con 20 ventanas (`tests/vm/overview.sh`)

Fecha: 2026-11-01. Rama `plasma/f7-mc`. 20 ventanas pedidas (6 kate +
6 konsole + 4 dolphin + 2 kwrite + 2 kcalc), 4 Spaces. Captura
`spikes/nested/f7-mc-perf.png`, log `spikes/nested/f7mc-perf.log`.

## Medidas

- `open_ms=187` (<300 A7) ✓ con 20 ventanas (el push final contó 20/20;
  una lectura intermedia dio 16 por arranques tardíos bajo carga).
- toggle ×3: 17/28/16ms, rc=0 ✓. Proceso VIVO al inicio y al final:
  **0 crash** ✓. **0 errores QML** ✓.
- `fps_20win=23` (`frameSwapped`/1.2s durante la intro, llvmpipe
  1280×800 + 20 tiles): documentado como suelo software, no como
  objetivo; 60fps queda para HW real.
- Captura: grid con grupos por app (kcalc·2, konsole·6, kwrite·2,
  kate·6…) y footer `20 ventanas · 4 Spaces` ✓.
